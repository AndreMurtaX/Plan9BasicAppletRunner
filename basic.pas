{******************************************************************************
  Plan9Basic Interpreter Engine

  MIT License
  Copyright (c) 2026 André Murta

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
******************************************************************************}
unit basic;

interface

uses
  System.Classes, System.SysUtils, System.Character, System.Math,
  lexer, parser, exec, UnitUtils;

type
  // Event fired after each PRINT output, allowing UI to refresh
  TPrintOutputEvent = procedure(Sender: TObject; const Text: String; IsClear: Boolean) of object;

  //****************************************************************************
  // Classes definitions
  // Begin
  //****************************************************************************
  //
  //************
  //TBasicEngine
  //************
  //
  //Interface between the language engine and the host application
  //
  TBasicEngine = class
  private
    output: TStrings;
    INTSource, ASMSource: TStringTokens;
    errPos, errLine: Integer;
    errMessage, FRTExceptionMsg: String;
    FRTException: Boolean;
    FFunctions: TFunctionsDictionary; //Dictionary with registered functions
    FOnPrintOutput: TPrintOutputEvent;
    //Store data for all UDFs in the "compiled" source code.
    //Could be accessed after source code compilation to call for a specific
    //function in the host application
    UserFunctionsTable: TUserFunctionsDictionary;
    //Table with signatures and entry points for all functions available in the
    //BASIC program.
    //Can be used after source code compilation to get the signatures and entry
    //points for all these available functions.
    LibFunctionsTable: TFunctionsDictionary;

    //--------------------------------------------------------------------------
    // The variables below are used solely by the functions to support the
    // compiler engine object.
    //--------------------------------------------------------------------------
    //ArgStack: Array of TAsmData; //Function call parameters
    //LastCallResult: TAsmData; //Keep result of last function call
    //LastCallType: TExprKind; //Keep return type of last function call
    //--------------------------------------------------------------------------

    FScriptTimeOut: Int64; //Maximum script execution time
    procedure PrintProc(p: PChar); //PRINT management function
    procedure SetScriptTimeOut(const Value: Int64);
  public
    Parser: TBasicParser; //parser object
    //An event that could be triggered between the execution of each instruction
    //in the stack machine.
    //It's useful for debugging.
    OnProgress: TNotifyEvent;
    This: TObject;
    constructor Create();
    destructor Destroy(); override;
    function Compile(source: TStrings): Integer; overload;
    function Compile(source: PChar): Integer; overload;
    function LoadIntermediate(source: TStrList): Integer;
    function TotalTokens: Cardinal; //Total of tokens in BASIC source
    function UserFunctionExists(Signature: String): Boolean;
    procedure ExecuteUserFunction( //exec. an user defined function only
      stdout: TStrings; //output (PRINT command)
      FunctionSignature: String;
      Parameters: Array of TAsmData;
      out RetType: TExprKind;
      out RetValue: TAsmData
    );
    procedure ExecuteProgram(stdout: TStrings); //exec. entire program
    procedure Stop(); //Stop execution
    function GetGlobalNum(const name: String; out index: Integer): Extended;
    function GetGlobalPtr(const name: String; out index: Integer): Pointer;
    function GetGlobalStr(const name: String; out index: Integer): String;

    property INTCode: TStringTokens read INTSource;
    property ASMCode: TStringTokens read ASMSource;
    property ErrorPos: Integer read errPos;
    property ErrorLine: Integer read errLine;
    property ErrorMessage: String read errMessage;
    //Used to keep the registered functions
    property Functions: TFunctionsDictionary read FFunctions write FFunctions;
    property UserFunctions: TUserFunctionsDictionary read UserFunctionsTable;
    //property LibFunctions: TFunctionsDictionary read LibFunctionsTable;
    //Indicates if a runtime exception ocurred during the script execution of a
    //self contained engine.
    property RuntimeException: Boolean read FRTException;
    //Keep last runtime exception message if such exception ocurred during a
    //self contained engine script execution. This text could be useful when
    //runing Basic from Basic
    property RuntimeExceptionMsg: String read FRTExceptionMsg write FRTExceptionMsg;
    //Script execution time limit (in seconds)
    property ScriptTimeOut: Int64 read FScriptTimeOut write SetScriptTimeOut;
    // PRINT instruction callback
    property OnPrintOutput: TPrintOutputEvent read FOnPrintOutput write FOnPrintOutput;
  end;

implementation

{ TBasicEngine }

//Compile a BASIC program
function TBasicEngine.Compile(source: TStrings): Integer;
var
  Key: String;
begin
  //Call the method in the parser object to do the real job
  Result := Parser.Compile(PChar(source.Text), nil, INTSource, ASMSource, FFunctions);
  if Result = 0 then //It means no errors
  begin
    errPos := 0;
    errLine := 0;
    errMessage := '';

    //Get the UDFs
    UserFunctionsTable.Clear;
    for Key in Parser.UserFunctionsTable.Keys do
      UserFunctionsTable.Add(Key, Parser.UserFunctionsTable[Key]);

    //Get all functions signatures and entry points
    LibFunctionsTable.Clear;
    for Key in Parser.LibFunctionsTable.Keys do
      LibFunctionsTable.Add(Key, Parser.LibFunctionsTable[Key]);

    Parser.exec.LoadSource(ASMSource);
  end
  else //there is an error
  begin
    errPos := Parser.errPos; //pos
    errLine := Parser.errLine; //line
    errMessage := Parser.lastErr; //error message
  end;
end;

//Same as "Compile" but using PChar type
function TBasicEngine.Compile(source: PChar): Integer;
var
  Key: String;
begin
  Result := Parser.Compile(source, nil, INTSource, ASMSource, FFunctions);
  if Result = 0 then
  begin
    errPos := 0;
    errLine := 0;
    errMessage := '';

    UserFunctionsTable.Clear();
    for Key in Parser.UserFunctionsTable.Keys do
      UserFunctionsTable.Add(Key, Parser.UserFunctionsTable[Key]);

    LibFunctionsTable.Clear();
    for Key in Parser.LibFunctionsTable.Keys do
      LibFunctionsTable.Add(Key, Parser.LibFunctionsTable[Key]);

    Parser.exec.LoadSource(ASMSource);
  end
  else
  begin
    errPos := Parser.errPos;
    errLine := Parser.errLine;
    errMessage := Parser.lastErr;
  end;
end;

constructor TBasicEngine.Create();
begin
  FFunctions := TFunctionsDictionary.Create();
  Parser := TBasicParser.Create(); //Creates the parser
  INTSource := TStringTokens.Create(); //Holds intermediate postfix code
  ASMSource := TStringTokens.Create(); //Holds final postfix code
  //Allow following program execution
  OnProgress := nil;
  //Pointer to the main object in BASIC
  This := nil;
  //UDFs data
  UserFunctionsTable := TUserFunctionsDictionary.Create();
  //All functions entry points
  LibFunctionsTable := TFunctionsDictionary.Create();
  FScriptTimeOut := 30; //In seconds
end;

destructor TBasicEngine.Destroy();
begin
  if Assigned(LibFunctionsTable) then FreeAndNil(LibFunctionsTable);
  if Assigned(UserFunctionsTable) then FreeAndNil(UserFunctionsTable);
  if Assigned(ASMSource) then FreeAndNil(ASMSource);
  if Assigned(INTSource) then FreeAndNil(INTSource);
  if Assigned(Parser) then FreeAndNil(Parser);
  if Assigned(FFunctions) then FreeAndNil(FFunctions);

  inherited Destroy();
end;

//Execute the program from the first instruction
procedure TBasicEngine.ExecuteProgram(stdout: TStrings);
begin
  Parser.exec.CallbackObj := nil;
  if Assigned(OnProgress) then
    Parser.exec.CallbackObj := Self;
  output := stdout;
  Parser.exec.TimeOut := FScriptTimeOut;
  Parser.exec.TagObject := This;
  Parser.exec.PrintProc := PrintProc;
  Parser.exec.CallbackProc := OnProgress; // Debugger
  Parser.exec.GlobalVarNames := Parser.GlobalVars;
  Parser.exec.ExecuteProgram();
end;

//Execute a user defined function present at the compiled BASIC code
procedure TBasicEngine.ExecuteUserFunction(stdout: TStrings; FunctionSignature: String; Parameters: array of TAsmData; out RetType: TExprKind; out RetValue: TAsmData);
var
  wFunction: TFunctionData;

  function ReturnType(signature: String; out rType: TExprKind): Boolean;
  var
    sepPos: Integer;
  begin
    //minimum valid signature name is 1 alpha char + the @ char, like: 'f@'
    if signature.Length < 2 then
      Exit(false);
    sepPos := signature.IndexOf('@'); //find position of '@'
    if (sepPos <= 0) then
      Exit(false);
    case signature.Chars[sepPos-1] of //find type
      '$': rType := ekString;
      '#': rType := ekPointer;
      else rType := ekNumber;
    end;
    Result := true;
  end;

begin
  //Tries to locate de function signature...
  if not UserFunctionsTable.ContainsKey(FunctionSignature) then
    Exit(); //... if not found, just do nothing.

  //wFunction holds the located function data
  wFunction := UserFunctionsTable[FunctionSignature];

  //Find function return type.
  //If there is a problem with the signature syntax, leave with no action.
  //But this should never take place.
  if not ReturnType(FunctionSignature, RetType) then
    Exit();

  Parser.exec.CallbackObj := nil;

  if Assigned(OnProgress) then
    Parser.exec.CallbackObj := Self; //Callback obj
  output := stdout; //"standard output"
  Parser.exec.TimeOut := FScriptTimeOut; //Set timeout
  Parser.exec.TagObject := This; //sets TAG object
  Parser.exec.PrintProc := PrintProc; //Output object
  Parser.exec.CallbackProc := OnProgress; //Callback proc (Debugger)
  Parser.exec.GlobalVarNames := Parser.GlobalVars; //Update global vars info
  Parser.exec.ExecuteFunction(
    wFunction.Entry,
    wFunction.ArgCount,
    wFunction.ArgType,
    Parameters,
    RetType,
    RetValue //set after method call
  );
end;

function TBasicEngine.GetGlobalNum(const name: String; out index: Integer): Extended;
begin
  Result := NaN;
  index := Parser.GlobalVars.IndexOf(name);
  if index >= 0 then
    Result := Parser.exec.GetGlobalNum(index);
end;

function TBasicEngine.GetGlobalPtr(const name: String; out index: Integer): Pointer;
begin
  Result := nil;

  if name.Chars[Pred(name.Length)] <> '#' then
    index := Parser.GlobalVars.IndexOf(name+'#')
  else
    index := Parser.GlobalVars.IndexOf(name);

  if index >= 0 then
    Result := Parser.exec.GetGlobalPtr(index);
end;

function TBasicEngine.GetGlobalStr(const name: String; out index: Integer): String;
begin
  Result := '';

  if name.Chars[Pred(name.Length)] <> '$' then
    index := Parser.GlobalVars.IndexOf(name+'$')
  else
    index := Parser.GlobalVars.IndexOf(name);

  if index >= 0 then
    Result := Parser.exec.GetGlobalStr(index);
end;

function TBasicEngine.LoadIntermediate(source: TStrList): Integer;
var
  i: Integer;
  Key: String;
  PFCode: TStringTokens;
  Token: TStringToken;
begin
  //Convert the intermediate code from strings to the proper notation
  PFCode := TStringTokens.Create();
  for i := 0 to Source.Count-1 do
  begin
    Token.Str := Source[i];
    PFCode.Add(Token);
  end;
  //Call the method in the parser object to do the real job
  Result := Parser.ProcessPostfixCode(PFCode, ASMSource, FFunctions, nil);
  if Result = 0 then //It means no errors
  begin
    errPos := 0;
    errLine := 0;
    errMessage := '';

    //Get the UDFs
    UserFunctionsTable.Clear();
    for Key in Parser.UserFunctionsTable.Keys do
      UserFunctionsTable.Add(Key, Parser.UserFunctionsTable[Key]);

    //Get all functions signatures and entry points
    LibFunctionsTable.Clear();
    for Key in Parser.LibFunctionsTable.Keys do
      LibFunctionsTable.Add(Key, Parser.LibFunctionsTable[Key]);

    //Calls the stack machine and load the assembly code produced
    Parser.exec.LoadSource(ASMSource);
  end
  else //there is an error
  begin
    errPos := Parser.errPos; //pos
    errLine := Parser.errLine; //line
    errMessage := Parser.lastErr; //error message
  end;
//  {$IFDEF MSWINDOWS}
  FreeAndNil(PFCode);
//  {$ELSE}
//  PFCode := nil;
//  {$ENDIF}
end;

//Auxiliary to the PRINT command. Adds the text in "p" to the output list
//procedure TBasicEngine.PrintProc(p: PChar);
//begin
//  if output = nil then
//    Exit();
//  if p = nil then
//    output.Clear()
//  else
//    output.Text := output.Text + StrPas(p);
//    //output.Add(StrPas(p));
//end;
//Auxiliary to the PRINT command. Adds the text in "p" to the output list
procedure TBasicEngine.PrintProc(p: PChar);
var
  Text: String;
  Lines: TArray<String>;
  I, LastIndex: Integer;
begin
  if output = nil then Exit();
  if p = nil then begin output.Clear(); Exit(); end;

  Text := StrPas(p);
  if Text = '' then Exit();

  Lines := Text.Split([#13#10, #10, #13], TStringSplitOptions.None);
  if Length(Lines) = 0 then Exit();

  // Primeira parte: concatena à última linha ou cria nova
  if output.Count = 0 then
    output.Add(Lines[0])
  else
  begin
    LastIndex := output.Count - 1;
    output[LastIndex] := output[LastIndex] + Lines[0];
  end;

  // Linhas adicionais (de quebras de linha no texto)
  for I := 1 to High(Lines) do
    output.Add(Lines[I]);

  // Dispara evento AQUI - após o texto já estar no output
  if Assigned(FOnPrintOutput) then
    FOnPrintOutput(Self, Text, False);
end;

//Set the script timeout
procedure TBasicEngine.SetScriptTimeOut(const Value: Int64);
begin
  if Value < 0 then
    FScriptTimeOut := 0
  else
    FScriptTimeOut := Value;
end;

procedure TBasicEngine.Stop();
begin
  Parser.exec.Stop();
end;

function TBasicEngine.TotalTokens: Cardinal;
begin
  Result := Parser.lexer.TotalTokens;
end;

function TBasicEngine.UserFunctionExists(Signature: String): Boolean;
begin
  Result := false;
  if UserFunctionsTable.ContainsKey(Signature) then
    Result := true;
end;

end.

