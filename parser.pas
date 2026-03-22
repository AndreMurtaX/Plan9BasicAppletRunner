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
unit parser;

interface

uses
  System.SysUtils, System.Character, System.StrUtils,
  System.Generics.Collections, System.TypInfo,
  UnitUtils, lexer, exec;

const
  // Local registers string representation for intermediate code generation
  // Functions have 3 local registers (@3 @4 @5) for internal use
  LOCAL_REG_STR = '3 4 5';

type
  //program status
  TBasStatus = (BasReady, BasRunning, BasTerminated);
  //BASIC source code compiling results
  TCompResult = (
    compOk, compLabel, compVariable, compFunction, compDupFunction, compDupVar,
    compFncParm, compUnbalancedIfElse, compUnbalancedCases, compMispCaseElse,
    compMispElse, compMispElseIf
  );

  //User created functions
  TFunctionData = record
    funcSignature: String; //Function signature 'name@...'
    Entry: Integer; //Function entry point
    ArgCount: Word; //Total of arguments
    ArgType: Array[0..MAXLOCALS] of TExprKind; //Type of each argument
  end;
  TUserFunctionsDictionary = TDictionary<String, TFunctionData>; //Type for the user functions dictionary

  TStrList = TList<String>; //Type for a list of strings

  //************
  //TBasicParser
  //************
  //
  //Process the tokens extracted by the lexer validating them semantically.
  //If parsing completes OK, a list with the intermediate code instructions
  //is produced to the compiler class.
  //
  TBasicParser = class
  private
    status: TBasStatus;
    TMPOutput: TStringTokens;
    forCnt, ifCnt, whileCnt, repeatCnt, selectCnt, doCnt, fError: Integer;
    forVarStack: array[0..MAXSTACK] of String; //Stack to track FOR loop control variables
    inFunction: Boolean;
    lastFunc: TBasToken; //Info about the current function
    selType: array[0..MAXSTACK] of TExprKind; //Last SELECT/CASE type
    //Used to check if the last select has a CASE ELSE statement
    selCaseElse: array[0..MAXSTACK] of Boolean;
    errCompStr: array [TCompResult] of String; //preprocessing errors list
    FGlobalVars: TStrList;
    FDoubleCloseConsumed: Boolean;  // JSON: tracks ]] token consumption for nested arrays

    //Indirect pointer array
    procedure ParsePointerArrayNumGet();
    procedure ParsePointerArrayStrGet();
    procedure ParsePointerArrayPtrGet();
    //Indirect call manager
    procedure ParseIndirectCall(CallType: TExprKind);
    //--------------------------------------------------------------
    //Logic expressions
    //--------------------------------------------------------------
    procedure NextLogicExpression();
    procedure NextLogicArith();
    procedure NextLogicValue();
    function IsLogicalGrouping(): Boolean;  // Lookahead helper for parenthesized expressions
    //--------------------------------------------------------------
    //Pointer expressions
    //--------------------------------------------------------------
    procedure NextPointerExpression();
    //--------------------------------------------------------------
    //Numerical expressions
    //--------------------------------------------------------------
    procedure NextNumericExpression();
    procedure NextArith();
    procedure NextFactor();
    procedure NextValue();
    //--------------------------------------------------------------
    //String expressions
    //--------------------------------------------------------------
    procedure NextStringExpression();
    procedure NextStringValue();
    //--------------------------------------------------------------
    // JSON literal parsing support
    //--------------------------------------------------------------
    procedure ParseJsonArray();      // Parses JSON array literal [...]
    procedure ParseJsonObject();     // Parses JSON object literal {...}
    procedure ParseJsonValue();      // Parses a single JSON value (for array elements)
    procedure ParseJsonKeyValue();   // Parses a key-value pair (for object properties)
    function EscapeJsonString(const s: String): String;  // Escapes string for intermediate code
    //--------------------------------------------------------------
    function GetError(): Boolean;
    procedure AssignNum(); //Numeric assignment
    procedure AssignStr(); //String assignment
    procedure AssignPtr(); //Pointer assignment
    procedure AssignPointerArrayNum(); //id#[...] = numeric expression
    procedure AssignPointerArrayStr(); //id#$[...] = string expression
    procedure AssignPointerArrayPtr(); //id##[...] = pointer expression
    procedure ParseData(); //DATA
    procedure ParseRead(); //READ
    procedure ParseRefreshRate(); //REFRESHRATE
    procedure ParseRestore(); //RESTORE
    procedure ParseFunction(); //FUNCTION
    procedure ParseEndFunction(); //ENDFUNCTION
    procedure ParseReturn(); //RETURN
    procedure ParseUnassignedNumFunction(); //fnc(...)
    procedure ParseUnassignedStrFunction(); //fnc$(...)
    procedure ParseUnassignedPtrFunction(); //fnc#(...)
    procedure ParseNext(); //NEXT
    procedure ParseFor(); //FOR [ .. NEXT]
    procedure ParseIf(); //IF
    procedure ParseElse(); //ELSE
    procedure ParseEndif(); //ENDIF
    procedure ParseWhile(); //WHILE
    procedure ParseEndWhile(); //ENDWHILE
    procedure ParseRepeat(); //REPEAT
    procedure ParseUntil(); //UNTIL
    procedure ParseDo(); //DO [WHILE|UNTIL]
    procedure ParseLoop(); //LOOP [WHILE|UNTIL]
    procedure ParseBreak(); //BREAK
    procedure ParseContinue(); //CONTINUE
    procedure ParsePrint(); //PRINT
    procedure ParsePrintLn(); //PRINTLN
    procedure ParseEnd(); //END
    procedure ParseInput(); //INPUT
    procedure ParseCls(); //CLS
    procedure ParseSelect(); //SELECT
    procedure ParseCase(); //CASE
    procedure ParseEndSelect(); //ENDSELECT
    procedure ParseLabel(); //integer beginning a line
    procedure ParseGoto(); //GOTO
    procedure ParseGosub(); //GOSUB
    procedure ParseOn(); //ON
    //Debug commands
    procedure ParseAssert(); //ASSERT
    procedure ParseBreakpoint(); //BREAKPOINT
    procedure ParseDump(); //DUMP
    procedure ParseTrace(); //TRACE
    procedure ParseTraceOn(); //TRACEON
    procedure ParseTraceOff(); //TRACEOFF
    procedure ParseWatch(); //WATCH
    procedure ParseUnwatch(); //UNWATCH
    procedure NextCommand();
    function SafeRound(d: Double; imin, imax: Integer): Integer;
    function GetParams(): String;
    procedure ClearCounts();
    function CheckCounters(): Boolean;
    function ExpressionKind(tok: TBasToken): TExprKind;
    procedure Clear();
    procedure Emmit(s: String);
    procedure NextInstruction();
    procedure SetError(err: String);
  public
    UserFunctionsTable: TUserFunctionsDictionary; //UDFs table
    LibFunctionsTable: TFunctionsDictionary; //All functions available
    errPos, errLine: Integer;
    lastErr: String;
    lexer: TBasicLexer; //lexer
    exec: TExec; //stack machine

    constructor Create();
    destructor Destroy(); override;
    function Compile(input: PChar; debug: TStrList; var INTOutput, ASMOutput: TStringTokens; var libFuncs: TFunctionsDictionary): Integer;
    function ProcessPostfixCode(PostFix: TStringTokens; var ASMOutput: TStringTokens; var libFuncs: TFunctionsDictionary; debug: TStrList): Integer;

    property Error: String read lastErr;
    property ErrorPos: Integer read errPos;
    property ErrorLine: Integer read errLine;
    property CompileStatus: TBasStatus read status;
    property GlobalVars: TStrList read FGlobalVars;
  end;

  //*********
  //TCompiler
  //*********
  //
  //Executes a series of passes through the intermediate code produced by the
  //parser and generates the final assembly instructions to be executed by the
  //stack machine.
  //
  TCompiler = class
  private
    compResult: TCompResult; //The result of the intermediate code compilation
    postfixCode: TStringTokens; //Intermediate code to analyze
    errLine: Integer;
    asmLexer: TAsmLexer; //Postfix tokenizer
    FGlobalVars: TStrList; //Keep track of global variables
    //List with entry points for all function available to the program (UDFs and
    //imported)
    ProgramFunctions: TFunctionsDictionary;
    //Table to hold UDFs data
    //Used in classes TBasic and TBasicParser
    UserFunctionsTable: TUserFunctionsDictionary;
    //List to hold the contents of each DATA statement at the source code
    DataStmts: TDataItems;
    //--------------------------------------------------------------------------
    //Compiler methods
    //--------------------------------------------------------------------------
    procedure AssignLabels(); //label declarations
    procedure AssignTokens(); //label each token in the intermediary code
    procedure AssignCommas(); //relationship between BASIC source and instructions
    procedure EnumVarsFuncs(); //position of globals, locals, functions
    procedure AssignIfCRLF(); //one line IF
    procedure AssignIf(); //multiline IF
    procedure AssignBreak(); //BREAK
    procedure AssignContinue(); //CONTINUE
    procedure AssignRepeat(); //REPEAT
    procedure AssignWhile(); //WHILE
    procedure AssignDo(); //DO...LOOP
    procedure AssignFuncs(); //functions entry points
    procedure SkipFuncs(); //additional functions processing
    procedure AssignData(); //Find the position of each DATA command at the source
    procedure AssignSelect(); //SELECT .. CASE
    //--------------------------------------------------------------------------
    procedure FindErrline();
    function StrItem(str: String; value: TAsmToken): TStringToken;
  public
    ErrDetail: String; //Detailed error message (includes variable/function name)
    constructor Create();
    destructor Destroy(); override;
    function Compile(source: TStringTokens; funcs: TFunctionsDictionary): TCompResult;
    function ReturnRegisteredFunctions: TUserFunctionsDictionary;
    function RegisterFuncData(source: String; out Signature: String; out ParamCount: Word; out ParamType: Array of TExprKind): Boolean;
  end;

implementation

{ TBasicParser }

procedure TBasicParser.AssignNum();
var
  s: String;
begin
  s := lexer.CurrS(); //variable to store numerical expression result.
  if lexer.NextTok() <> btkEqual then
  begin
    status := BasTerminated;
    SetError('Expected numeric assignment');
    Exit;
  end;
  lexer.Advance; //skip identifier
  lexer.Advance(); //skip '=' or ':=' operator
  NextNumericExpression(); //numeric expression
  Emmit('POPSTORE @' + s); //store at the indicated var
end;

procedure TBasicParser.AssignPointerArrayNum();
var
  s: String;
  i: Integer;
begin
  i := 0;
  s := lexer.CurrS();
  Emmit('PUSH# @'+s);
  Inc(i);
  lexer.Advance(); //skips the '['
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekNumber then
  begin
    Status := BasTerminated;
    SetError('Numeric expression expected');
    Exit();
  end;
  NextNumericExpression();
  Inc(i);
  if (lexer.CurrTok() <> btkComma) and (lexer.CurrTok() <> btkSquareClose) then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end;
  if lexer.CurrTok() <> btkSquareClose then
    repeat
      lexer.Advance();
      NextNumericExpression();
      Inc(i);
    until lexer.CurrTok() <> btkComma;
  if lexer.CurrTok() <> btkSquareClose then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end;
  lexer.Advance(); //skip the ']'
  if lexer.CurrTok() <> btkEqual then
  begin
    status := BasTerminated;
    SetError('Expected numeric assignment');
    Exit();
  end;
  lexer.Advance(); //skip the '='
  NextNumericExpression(); //numeric expression
  Inc(i);
  Emmit('PUSHC '+IntToStr(i));
  Emmit('CALLEX# "narr_set#@#'+System.StrUtils.DupeString('n',i-1)+'"'); //store at the indicated var
  Emmit('POP'); //discard the returned pointer (stack cleanup)
end;

procedure TBasicParser.AssignPointerArrayPtr();
var
  s: String;
  i: Integer;
begin
  i := 0;
  s := lexer.CurrS().Substring(0, lexer.CurrS().Length-1);
  Emmit('PUSH# @'+s);
  Inc(i);
  lexer.Advance(); //skips the '['
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekNumber then
  begin
    Status := BasTerminated;
    SetError('Numeric expression expected');
    Exit();
  end;
  NextNumericExpression();
  Inc(i);
  if (lexer.CurrTok() <> btkComma) and (lexer.CurrTok() <> btkSquareClose) then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end;
  if lexer.CurrTok() <> btkSquareClose then
    repeat
      lexer.Advance();
      NextNumericExpression();
      Inc(i);
    until lexer.CurrTok() <> btkComma;
  if lexer.CurrTok() <> btkSquareClose then
  begin
    s := lexer.CurrS();
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end;
  lexer.Advance(); //skip the ']'
  if lexer.CurrTok() <> btkEqual then
  begin
    status := BasTerminated;
    SetError('Expected numeric assignment');
    Exit();
  end;
  lexer.Advance(); //skip the '='
  NextPointerExpression(); //pointer expression
  Inc(i);
  Emmit('PUSHC '+IntToStr(i));
  Emmit('CALLEX# "parr_set#@#'+System.StrUtils.DupeString('n',i-2)+'#"'); //store at the indicated var
  Emmit('POP'); //discard the returned pointer (stack cleanup)
end;

procedure TBasicParser.AssignPointerArrayStr();
var
  s: String;
  i: Integer;
begin
  i := 0;
  s := lexer.CurrS().Substring(0, lexer.CurrS().Length-1);
  Emmit('PUSH# @'+s);
  Inc(i);
  lexer.Advance(); //skips the '['
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekNumber then
  begin
    Status := BasTerminated;
    SetError('Numeric expression expected');
    Exit();
  end;
  NextNumericExpression();
  Inc(i);
  if (lexer.CurrTok() <> btkComma) and (lexer.CurrTok() <> btkSquareClose) then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end;
  if lexer.CurrTok() <> btkSquareClose then
    repeat
      lexer.Advance();
      NextNumericExpression();
      Inc(i);
    until lexer.CurrTok() <> btkComma;

  if lexer.CurrTok() <> btkSquareClose then
  begin
    s := lexer.CurrS();
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end;
  lexer.Advance(); //skip the ']'
  if lexer.CurrTok() <> btkEqual then
  begin
    status := BasTerminated;
    SetError('Expected numeric assignment');
    Exit();
  end;
  lexer.Advance(); //skip the '='
  NextStringExpression(); //string expression
  Inc(i);
  Emmit('PUSHC '+IntToStr(i));
  Emmit('CALLEX# "sarr_set#@#'+System.StrUtils.DupeString('n',i-2)+'$"'); //store at the indicated var
  Emmit('POP'); //discard the returned pointer (stack cleanup)
end;

procedure TBasicParser.AssignPtr();
var
  s: String;
begin
  s := lexer.CurrS().ToLower(); //save pointer identifier name
  if lexer.NextTok = btkEqual then // ptr# = ...
  begin
    lexer.Advance(); //skip the pointer identifier
    lexer.Advance(); //skip the '=' operator

    // JSON SUPPORT - Check for JSON literal syntax
    case lexer.CurrTok() of
      btkSquareOpen:  // JSON array literal [...]
      begin
        ParseJsonArray();
        Emmit('POPSTORE# @' + s);
      end;
      btkCurlyOpen:   // JSON object literal {...}
      begin
        ParseJsonObject();
        Emmit('POPSTORE# @' + s);
      end;
      else
      begin
        // Regular pointer expression
        NextPointerExpression();
        Emmit('POPSTORE# @' + s);
      end;
    end;
  end
  else
  begin
    status := BasTerminated;
    SetError('Expected a pointer assignment');
    Exit();
  end;
end;

//All possible string attributions
procedure TBasicParser.AssignStr();
var
  s: String;
begin
  s := lexer.CurrS();
  if lexer.CurrTok() = btkCharArray then //var$[[index]] = expression$
  begin
    Emmit('PUSH$ @'+s);

    lexer.Advance(); //skip variable
    NextNumericExpression(); //numerical index between brackets [ ]
    //Store the index at internal register (0)
    Emmit('POPSTORE @0');
    if lexer.CurrTok() <> btkDoubleSquareClose then
    begin
      status := BasTerminated;
      SetError(']] expected');
      Exit();
    end;
    if lexer.NextTok <> btkEqual then
    begin
      status := BasTerminated;
      SetError('Expected char assignment');
      Exit();
    end;
    lexer.Advance(); //skip square close

    Emmit('PUSH @0'); //get index back on the stack
    lexer.Advance(); //skip the assignment token
    NextStringExpression(); //assignment
    Emmit('PUSHC 3');
    Emmit('CALLEX$ "chr$@$n$"     ');
    Emmit('POPSTORE$ @' + s);
  end
  else if lexer.CurrTok() = btkStrArray then //var$[index] = expression$
  begin
    Emmit('PUSH$ @'+s);

    lexer.Advance(); //skip variable
    NextNumericExpression(); //numerical index between brackets [ ]
    //Store the index at internal register (0)
    Emmit('POPSTORE @0');
    if lexer.CurrTok() <> btkSquareClose then
    begin
      status := BasTerminated;
      SetError('] expected');
      Exit();
    end;
    if lexer.NextTok <> btkEqual then
    begin
      status := BasTerminated;
      SetError('Expected line assignment');
      Exit();
    end;
    lexer.Advance(); //skip the ']'
    Emmit('PUSH @0'); //get index back on the stack
    lexer.Advance(); //skip the '='
    NextStringExpression(); //attribution
    Emmit('PUSHC 3');
    Emmit('CALLEX$ "line$@$n$"     ');
    Emmit('POPSTORE$ @' + s);
  end
  else
  begin
    if lexer.NextTok <> btkEqual then
    begin
      status := BasTerminated;
      SetError('Expected string assignment');
      Exit;
    end;
    lexer.Advance(); //skip square close
    lexer.Advance(); //skip '=' operator
    NextStringExpression(); //String expression
    Emmit('POPSTORE$ @' + s); //store at the indicated var
  end;
end;

//------------------------------------------------------------------------------
// JSON SUPPORT - Helper function to escape strings for intermediate code
//------------------------------------------------------------------------------
function TBasicParser.EscapeJsonString(const s: String): String;
var
  i: Integer;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(s) do
  begin
    ch := s[i];
    case ch of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #10:  Result := Result + '\n';
      #13:  Result := Result + '\r';
      #9:   Result := Result + '\t';
      else  Result := Result + ch;
    end;
  end;
end;

//------------------------------------------------------------------------------
// JSON SUPPORT - Parse JSON array literal [...]
//------------------------------------------------------------------------------
procedure TBasicParser.ParseJsonArray();
begin
  // Create empty JSON array
  Emmit('PUSHC 0');  // 0 arguments for json_array#()
  Emmit('CALLEX# "json_array#@"     ');

  lexer.Advance(); // Skip '['

  // Skip any newlines after opening bracket
  while lexer.CurrTok() = btkCRLF do
    lexer.Advance();

  // Handle empty array []
  if lexer.CurrTok() = btkSquareClose then
  begin
    lexer.Advance(); // Skip ']'
    Exit;
  end;

  // Parse first element
  ParseJsonValue();
  if GetError then Exit;  // Propagate error from nested parse

  // Skip any newlines after element
  while lexer.CurrTok() = btkCRLF do
    lexer.Advance();

  // Parse remaining elements
  while lexer.CurrTok() = btkComma do
  begin
    lexer.Advance(); // Skip ','
    // Skip any newlines after comma
    while lexer.CurrTok() = btkCRLF do
      lexer.Advance();

    // Check for trailing comma (comma followed by ])
    if lexer.CurrTok() = btkSquareClose then
    begin
      status := BasTerminated;
      SetError('Trailing comma not allowed in JSON array');
      Exit;
    end;

    ParseJsonValue();
    if GetError then Exit;  // Propagate error from nested parse

    // Skip any newlines after element
    while lexer.CurrTok() = btkCRLF do
      lexer.Advance();
  end;

  // Expect closing bracket - handle both ] and ]] tokens
  // The lexer combines ]] into btkDoubleSquareClose (used for str$[[index]])
  // For nested JSON arrays, we need to handle this specially
  if lexer.CurrTok() = btkSquareClose then
  begin
    lexer.Advance(); // Normal case: single ]
  end
  else if lexer.CurrTok() = btkDoubleSquareClose then
  begin
    // ]] token: represents two closing brackets
    // Use flag to track consumption - first consumer doesn't advance,
    // second consumer advances past the entire ]] token
    if FDoubleCloseConsumed then
    begin
      lexer.Advance();  // Second consumer: advance past ]]
      FDoubleCloseConsumed := False;
    end
    else
      FDoubleCloseConsumed := True;  // First consumer: mark as consumed, don't advance
  end
  else
  begin
    status := BasTerminated;
    if lexer.CurrTok() = btkCurlyClose then
      SetError('Mismatched bracket: found "}" but expected "]" in JSON array')
    else if lexer.CurrTok() = btkNull then
      SetError('Unexpected end of program inside JSON array - missing "]"')
    else
      SetError('] expected in JSON array, found "' + lexer.CurrS() + '"');
    Exit;
  end;
end;

//------------------------------------------------------------------------------
// JSON SUPPORT - Parse JSON object literal {...}
//------------------------------------------------------------------------------
procedure TBasicParser.ParseJsonObject();
begin
  // Create empty JSON object
  Emmit('PUSHC 0');  // 0 arguments for json_object#()
  Emmit('CALLEX# "json_object#@"     ');

  lexer.Advance(); // Skip '{'

  // Skip any newlines after opening brace
  while lexer.CurrTok() = btkCRLF do
    lexer.Advance();

  // Handle empty object {}
  if lexer.CurrTok() = btkCurlyClose then
  begin
    lexer.Advance(); // Skip '}'
    Exit;
  end;

  // Parse first key-value pair
  ParseJsonKeyValue();
  if GetError then Exit;  // Propagate error from nested parse

  // Skip any newlines after key-value pair
  while lexer.CurrTok() = btkCRLF do
    lexer.Advance();

  // Parse remaining pairs
  while lexer.CurrTok() = btkComma do
  begin
    lexer.Advance(); // Skip ','
    // Skip any newlines after comma
    while lexer.CurrTok() = btkCRLF do
      lexer.Advance();

    // Check for trailing comma (comma followed by })
    if lexer.CurrTok() = btkCurlyClose then
    begin
      status := BasTerminated;
      SetError('Trailing comma not allowed in JSON object');
      Exit;
    end;

    ParseJsonKeyValue();
    if GetError then Exit;  // Propagate error from nested parse

    // Skip any newlines after key-value pair
    while lexer.CurrTok() = btkCRLF do
      lexer.Advance();
  end;

  // Expect closing brace
  if lexer.CurrTok() <> btkCurlyClose then
  begin
    status := BasTerminated;
    if lexer.CurrTok() = btkSquareClose then
      SetError('Mismatched bracket: found "]" but expected "}" in JSON object')
    else if lexer.CurrTok() = btkNull then
      SetError('Unexpected end of program inside JSON object - missing "}"')
    else if lexer.CurrTok() = btkString then
      SetError('Missing comma before key "' + lexer.CurrS() + '" in JSON object')
    else
      SetError('} expected in JSON object, found "' + lexer.CurrS() + '"');
    Exit;
  end;
  lexer.Advance(); // Skip '}'
end;

//------------------------------------------------------------------------------
// JSON SUPPORT - Parse a single JSON value (for array elements)
//------------------------------------------------------------------------------
procedure TBasicParser.ParseJsonValue();
var
  st: String;
begin
  case lexer.CurrTok() of
    btkSquareOpen:  // Nested array [...]
    begin
      ParseJsonArray();
      // Array is on stack, push it to parent array
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_push#@##"     ');
    end;

    btkCurlyOpen:   // Nested object {...}
    begin
      ParseJsonObject();
      // Object is on stack, push it to parent array
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_push#@##"     ');
    end;

    btkString:      // String literal "..."
    begin
      st := lexer.CurrS();
      Emmit('PUSHC$ "' + EscapeJsonString(st) + '"');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushs#@#$"     ');
      lexer.Advance();
    end;

    btkInteger, btkFloat:  // Numeric literal
    begin
      Emmit('PUSHC ' + TUtils.FloatToStr2(lexer.CurrN));
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushn#@#n"     ');
      lexer.Advance();
    end;

    btkMinus:  // Negative number
    begin
      lexer.Advance();
      if (lexer.CurrTok() = btkInteger) or (lexer.CurrTok() = btkFloat) then
      begin
        Emmit('PUSHC ' + TUtils.FloatToStr2(-lexer.CurrN));
        Emmit('PUSHC 2');
        Emmit('CALLEX# "json_pushn#@#n"     ');
        lexer.Advance();
      end
      else
      begin
        status := BasTerminated;
        SetError('Number expected after minus in JSON');
        Exit;
      end;
    end;

    btkTrue:  // true keyword
    begin
      Emmit('PUSHC 1');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushb#@#n"     ');
      lexer.Advance();
    end;

    btkFalse:  // false keyword
    begin
      Emmit('PUSHC 0');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushb#@#n"     ');
      lexer.Advance();
    end;

    btkJsonNull:  // null keyword
    begin
      Emmit('PUSHC 1');
      Emmit('CALLEX# "json_pushnull#@#"     ');
      lexer.Advance();
    end;

    btkIdentifier:  // Numeric variable
    begin
      Emmit('PUSH @' + lexer.CurrS().ToLower());
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushn#@#n"     ');
      lexer.Advance();
    end;

    btkStrIdentifier:  // String variable
    begin
      Emmit('PUSH$ @' + lexer.CurrS().ToLower());
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushs#@#$"     ');
      lexer.Advance();
    end;

    btkPointerIdentifier:  // Pointer variable (nested JSON)
    begin
      Emmit('PUSH# @' + lexer.CurrS().ToLower());
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_push#@##"     ');
      lexer.Advance();
    end;

    btkNumFunction:  // Numeric function call
    begin
      st := LowerCase(lexer.CurrS());
      lexer.Advance();
      Emmit('CALLEX "'+st+'@'+GetParams+'"     ');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushn#@#n"     ');
    end;

    btkStrFunction:  // String function call
    begin
      st := LowerCase(lexer.CurrS());
      lexer.Advance();
      Emmit('CALLEX$ "'+st+'@'+GetParams+'"     ');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_pushs#@#$"     ');
    end;

    btkPointerFunction:  // Pointer function call
    begin
      st := LowerCase(lexer.CurrS());
      lexer.Advance();
      Emmit('CALLEX# "'+st+'@'+GetParams+'"     ');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_push#@##"     ');
    end;

    btkCRLF:  // Unexpected newline
    begin
      status := BasTerminated;
      SetError('Unexpected end of line - JSON value expected');
      Exit;
    end;

    btkComma:  // Unexpected comma (e.g., [1,,2])
    begin
      status := BasTerminated;
      SetError('Unexpected comma - JSON value expected');
      Exit;
    end;

    btkSquareClose:  // Unexpected ] (e.g., [1,])
    begin
      status := BasTerminated;
      SetError('Unexpected "]" - JSON value expected (trailing comma?)');
      Exit;
    end;

    btkCurlyClose:  // Unexpected }
    begin
      status := BasTerminated;
      SetError('Unexpected "}" - JSON value expected (trailing comma?)');
      Exit;
    end;

    btkNull:  // End of program
    begin
      status := BasTerminated;
      SetError('Unexpected end of program inside JSON literal');
      Exit;
    end;

    else
    begin
      status := BasTerminated;
      SetError('Invalid JSON value: "' + lexer.CurrS() + '"');
      Exit;
    end;
  end;
end;

//------------------------------------------------------------------------------
// JSON SUPPORT - Parse a key-value pair (for object properties)
//------------------------------------------------------------------------------
procedure TBasicParser.ParseJsonKeyValue();
var
  keyStr, st: String;
begin
  // Key must be a string literal
  if lexer.CurrTok() <> btkString then
  begin
    status := BasTerminated;
    if lexer.CurrTok() = btkIdentifier then
      SetError('JSON object key must be a quoted string, not identifier "' + lexer.CurrS() + '"')
    else if lexer.CurrTok() = btkInteger then
      SetError('JSON object key must be a quoted string, not a number')
    else if lexer.CurrTok() = btkCurlyClose then
      SetError('Unexpected "}" - expected key or trailing comma not allowed')
    else
      SetError('String key expected in JSON object, found "' + lexer.CurrS() + '"');
    Exit;
  end;

  keyStr := lexer.CurrS();
  lexer.Advance(); // Skip key

  // Expect colon
  if lexer.CurrTok() <> btkColon then
  begin
    status := BasTerminated;
    if lexer.CurrTok() = btkComma then
      SetError('Missing value for key "' + keyStr + '" - found comma instead of colon')
    else if lexer.CurrTok() = btkEqual then
      SetError('Use ":" not "=" after key "' + keyStr + '" in JSON object')
    else
      SetError('":" expected after key "' + keyStr + '" in JSON object');
    Exit;
  end;
  lexer.Advance(); // Skip ':'

  // Skip any newlines after colon
  while lexer.CurrTok() = btkCRLF do
    lexer.Advance();

  // Parse value based on its type
  case lexer.CurrTok() of
    btkSquareOpen:  // Nested array
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');  // Push key FIRST
      ParseJsonArray();  // Then parse array (pushes array pointer)
      if GetError then Exit;  // Propagate error from nested parse
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_set#@#$#"     ');
    end;

    btkCurlyOpen:   // Nested object
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');  // Push key FIRST
      ParseJsonObject();  // Then parse object (pushes object pointer)
      if GetError then Exit;  // Propagate error from nested parse
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_set#@#$#"     ');
    end;

    btkString:      // String value
    begin
      st := lexer.CurrS();
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSHC$ "' + EscapeJsonString(st) + '"');
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_sets#@#$$"     ');
      lexer.Advance();
    end;

    btkInteger, btkFloat:  // Numeric value
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSHC ' + TUtils.FloatToStr2(lexer.CurrN));
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_setn#@#$n"     ');
      lexer.Advance();
    end;

    btkMinus:  // Negative number
    begin
      lexer.Advance();
      if (lexer.CurrTok() = btkInteger) or (lexer.CurrTok() = btkFloat) then
      begin
        Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
        Emmit('PUSHC ' + TUtils.FloatToStr2(-lexer.CurrN));
        Emmit('PUSHC 3');
        Emmit('CALLEX# "json_setn#@#$n"     ');
        lexer.Advance();
      end
      else
      begin
        status := BasTerminated;
        SetError('Number expected after minus in JSON');
        Exit;
      end;
    end;

    btkTrue:  // true
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSHC 1');
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_setb#@#$n"     ');
      lexer.Advance();
    end;

    btkFalse:  // false
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSHC 0');
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_setb#@#$n"     ');
      lexer.Advance();
    end;

    btkJsonNull:  // null
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSHC 2');
      Emmit('CALLEX# "json_setnull#@#$"     ');
      lexer.Advance();
    end;

    btkIdentifier:  // Numeric variable
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSH @' + lexer.CurrS().ToLower());
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_setn#@#$n"     ');
      lexer.Advance();
    end;

    btkStrIdentifier:  // String variable
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSH$ @' + lexer.CurrS().ToLower());
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_sets#@#$$"     ');
      lexer.Advance();
    end;

    btkPointerIdentifier:  // Pointer variable (nested JSON)
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      Emmit('PUSH# @' + lexer.CurrS().ToLower());
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_set#@#$#"     ');
      lexer.Advance();
    end;

    btkNumFunction:  // Numeric function
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      st := LowerCase(lexer.CurrS());
      lexer.Advance();
      Emmit('CALLEX "'+st+'@'+GetParams+'"     ');
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_setn#@#$n"     ');
    end;

    btkStrFunction:  // String function
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      st := LowerCase(lexer.CurrS());
      lexer.Advance();
      Emmit('CALLEX$ "'+st+'@'+GetParams+'"     ');
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_sets#@#$$"     ');
    end;

    btkPointerFunction:  // Pointer function
    begin
      Emmit('PUSHC$ "' + EscapeJsonString(keyStr) + '"');
      st := LowerCase(lexer.CurrS());
      lexer.Advance();
      Emmit('CALLEX# "'+st+'@'+GetParams+'"     ');
      Emmit('PUSHC 3');
      Emmit('CALLEX# "json_set#@#$#"     ');
    end;

    btkCRLF:  // Unexpected newline after colon
    begin
      status := BasTerminated;
      SetError('Missing value for key "' + keyStr + '" in JSON object');
      Exit;
    end;

    btkComma:  // Unexpected comma
    begin
      status := BasTerminated;
      SetError('Missing value for key "' + keyStr + '" - found comma');
      Exit;
    end;

    btkCurlyClose:  // Unexpected }
    begin
      status := BasTerminated;
      SetError('Missing value for key "' + keyStr + '" - found "}"');
      Exit;
    end;

    btkNull:  // End of program
    begin
      status := BasTerminated;
      SetError('Unexpected end of program - missing value for key "' + keyStr + '"');
      Exit;
    end;

    else
    begin
      status := BasTerminated;
      SetError('Invalid value for key "' + keyStr + '": "' + lexer.CurrS() + '"');
      Exit;
    end;
  end;
end;

function TBasicParser.CheckCounters(): Boolean;
begin
  Result := (forCnt + ifCnt + whileCnt + repeatCnt + selectCnt + doCnt) = 0;
  if Result then Exit;
  if forCnt > 0 then SetError('Unfinished FOR command');
  if ifCnt > 0 then SetError('Unfinished IF command');
  if whileCnt > 0 then SetError('Unfinished WHILE command (missing ENDWHILE/WEND)');
  if repeatCnt > 0 then SetError('Unfinished REPEAT command');
  if selectCnt > 0 then SetError('Unfinished SELECT command');
  if doCnt > 0 then SetError('Unfinished DO command');
end;

procedure TBasicParser.Clear();
var
  i: Integer;
begin
  ClearCounts();
  inFunction := False;
  status := BasReady;
  lastErr := '';
  fError := 0;
  errPos := 0;
  FDoubleCloseConsumed := False;  // JSON: reset ]] tracking
  //CRITICAL FIX: Init the SELECT/CASE type array
  for i := Low(selType) to High(selType) do
    selType[i] := TExprKind.ekNumber; // Default to numeric
  //Init the "CASE ELSE present" list with all false
  for i := Low(selCaseElse) to High(selCaseElse) do
    selCaseElse[i] := False;
end;

procedure TBasicParser.ClearCounts();
begin
  forCnt := 0;
  ifCnt := 0;
  whileCnt := 0;
  repeatCnt := 0;
  selectCnt := 0;
  doCnt := 0;
end;

function TBasicParser.Compile(input: PChar; debug: TStrList; var INTOutput, ASMOutput: TStringTokens; var libFuncs: TFunctionsDictionary): Integer;
var
  comp: TCompiler;
  compRes: TCompResult; //preprocessing result
  TmpFunctionsTable: TUserFunctionsDictionary;
  i: Integer;
  Key: String;
begin
  Result := 0;
  Self.Clear(); //Reset the environment from a new program
  lexer.LoadProg(Input); //Load and tokenize BASIC source
  lexer.GotoToken(0); //Set index to the first token
  if lexer.TotalTokens >= MAXINSTR then SetError('Source code too big');
  TMPOutput.Clear; //Reset TMPOutput before scan

  //parse input code, set intermediate code at TMPOutput
  repeat
    NextInstruction();
    if GetError() then //Exit if error
    begin
      Result := -TUtils.FindLine(input, errPos);
      errLine := -Result;
      Exit();
    end;
  until (status = BasTerminated);

  //Check commands balance
  if not CheckCounters() then
  begin
    Result := -1;
    Exit();
  end;

  //Now, INTOutput holds the intermediate assembly code
  INTOutput.Clear;
  for i := 0 to TMPOutput.Count-1 do
    INTOutput.Add(TMPOutput[i]);

  //Initiate the compiler
  comp := TCompiler.Create();

  //Compile the intermediate code
  compRes := comp.Compile(TMPOutput, libFuncs);
  if compRes <> compOk then //if it's not ok
  begin
    Result := comp.errLine;
    errLine := Result;
    if comp.ErrDetail <> '' then
      lastErr := comp.ErrDetail
    else
      lastErr := errCompStr[compRes];
  end;

  //Now, ASMOutput holds the final assembly code
  ASMOutput.Clear; //Clean any anterior information
  for i := 0 to TMPOutput.Count-1 do
    ASMOutput.Add(TMPOutput[i]);

  //Reset READ index
  exec.ReadIdx := 0;

  //Update the stack machine with the informations about the DATA statements
  exec.DataStmts.Clear;
  for i := 0 to comp.DataStmts.Count-1 do
    exec.DataStmts.Add(comp.DataStmts[i]);

  //Update stack machine with the types (near/far) and entry point for all
  //functions available to the program
  exec.ProgramFunctions.Clear(); //Clean any anterior information
  for Key in comp.ProgramFunctions.Keys do
    exec.ProgramFunctions.Add(Key, comp.ProgramFunctions[Key]);

  //If debug list is defined, copy the final assembly instructions to it.
  if Assigned(debug) then
  begin
    debug.Clear; //Clean any anterior information
    // FIX #2: Changed TMPOutput.Count to TMPOutput.Count-1.
    // TList valid indices are 0..Count-1. Accessing [Count] causes
    // EArgumentOutOfRangeException, crashing debug-mode compilation.
    for i := 0 to TMPOutput.Count-1 do
      debug.Add(TMPOutput[i].Str);
  end;

  //Holds the UDFs (User Defined Functions).
  //Just to remember:
  //-> function signature
  //-> function entry point
  //-> function total of parameters
  //-> function parameters values array
  TmpFunctionsTable := comp.ReturnRegisteredFunctions;
  UserFunctionsTable.Clear; //Clean any anterior information
  for Key in TmpFunctionsTable.Keys do
    UserFunctionsTable.Add(Key, TmpFunctionsTable[Key]);

  //Update global variables access list
  FGlobalVars.Clear();
  for i := 0 to Pred(comp.FGlobalVars.Count) do
    FGlobalVars.Add(comp.FGlobalVars[i]);
  FreeAndNil(comp); //Compilation done. Free before exit.
end;

constructor TBasicParser.Create();
begin
  UserFunctionsTable := TUserFunctionsDictionary.Create();
  LibFunctionsTable := TFunctionsDictionary.Create();
  TMPOutput := TStringTokens.Create();
  lexer := TBasicLexer.Create();
  exec := TExec.Create();
  FGlobalVars := TStrList.Create();
  Clear();

  //preprocessing errors
  errCompStr[compOk] := 'Ok'; //Actually... this means 'no error'
  errCompStr[compLabel] := 'Invalid label';
  errCompStr[compVariable] := 'Unknown variable';
  errCompStr[compFunction] := 'There is no function with such arguments';
  errCompStr[compDupFunction] := 'Duplicated function. Signature must change for overloading';
  errCompStr[compDupVar] := 'Duplicated variable';
  errCompStr[compFncParm] := 'Up to 256 params/local vars in function declaration';
  errCompStr[compUnbalancedIfElse] := 'Unbalanced ELSEIFTEST/ELSEIFBODY';
  errCompStr[compUnbalancedCases] := 'Unbalanced CASESTART/CASEEND';
  errCompStr[compMispCaseElse] := 'Misplaced CASE ELSE';
  //***** ATTENTION *****
  //The 'ERR ' string represents an assembly command
  errCompStr[compMispElse] := 'ERR "Misplaced ELSE"';
  errCompStr[compMispElseIf] := 'ERR "Misplaced ELSE IF"';
end;

destructor TBasicParser.Destroy();
begin
  if Assigned(FGlobalVars) then FreeAndNil(FGlobalVars);
  if Assigned(exec) then FreeAndNil(exec);
  if Assigned(lexer) then FreeAndNil(lexer);
  if Assigned(TMPOutput) then FreeAndNil(TMPOutput);
  if Assigned(LibFunctionsTable) then FreeAndNil(LibFunctionsTable);
  if Assigned(UserFunctionsTable) then FreeAndNil(UserFunctionsTable);
  inherited Destroy();
end;

procedure TBasicParser.Emmit(s: String);
var
  Line: TStringToken;
begin
  Line.Str := s + '   ';
  TMPOutput.Add(Line);
end;

function TBasicParser.ExpressionKind(tok: TBasToken): TExprKind;
begin
  case tok of
    // JSON SUPPORT - [ and { indicate JSON literals (pointer type)
    btkPointerIdentifier, btkPointerFunction, btkIndirectCallPtr, btkPointerArrayPtr,
    btkSquareOpen, btkCurlyOpen: Result := ekPointer;
    btkString, btkStrIdentifier, btkStrFunction, btkIndirectCallStr, btkCharArray, btkStrArray, btkPointerArrayStr: Result := ekString;
    else Result := ekNumber;
  end;
end;

function TBasicParser.GetError(): Boolean;
begin
  Result := fError > 0
end;

function TBasicParser.GetParams(): String;
var
  i: Integer;
  isError: Boolean;
begin
  isError := True; //it changes if finished well
  Result := '';
  i := -1;
  if lexer.currTok() = btkRoundClose then //No argument function
  begin
    Emmit('PUSHC 0');
    Exit;
  end;
  //Maximum 512 arguments pushed.
  repeat
    Inc(i);
    if lexer.CurrTok=btkRoundClose then //found the ')', quit
    begin
      isError := False;
      Break;
    end;
    case ExpressionKind(lexer.CurrTok) of
      ekPointer:
      begin
        Result := Result + '#'; //pointer argument
        NextPointerExpression();
      end;
      ekString:
      begin
        Result := Result + '$'; //string argument
        NextStringExpression();
      end;
      else
      begin
        Result := Result + 'n'; //numeric argument
        NextNumericExpression();
      end;
    end;
    //if the ')' was found, change "isError" status to false
    if lexer.currTok() = btkRoundClose then isError := False
    //if next token is a comma, we have to deal with more arguments
    else if lexer.currTok() = btkComma then
      lexer.Advance //skip to next argument
    else
      Break; //if not, finishes the loop
  until i >= MAXLOCALS;
  Emmit('PUSHC ' + IntToStr(Length(Result))); //arguments total
  if IsError and not GetError then
    SetError('Error in function parameters declaration');
end;

procedure TBasicParser.NextArith();
begin
  NextFactor();
  repeat
    case lexer.currTok() of
      btkStar: { * }
      begin
        lexer.Advance();
        NextFactor();
        Emmit('MUL');
      end;
      btkSlash: { / }
      begin
        lexer.Advance();
        NextFactor();
        Emmit('DIV');
      end;
      btkMod: { mod }
      begin
        lexer.Advance();
        NextFactor();
        Emmit('MOD');
      end;
      else
        Break;
    end;
  until False;
end;

procedure TBasicParser.NextCommand();
begin
  status := BasRunning;

  //CRLF = ,line
  if (lexer.CurrTok() = btkCRLF) or (lexer.currTok() = btkColon) then
    Emmit(',    ');

  lexer.Advance();

  //Caso a linha comece com um número do tipo ponto flutuante
  if (lexer.CurrTok() = btkFloat) then
  begin
    status := BasTerminated;
    SetError('Only integer type labels are allowed.');
    Exit();
  end;

  if (lexer.CurrTok() = btkInteger) and (lexer.PrevTok = btkCrlf) then
  begin
    Emmit(IntToStr(Round(lexer.CurrN())));
    lexer.Advance();
  end;

  case lexer.currTok() of
    btkIdentifier: AssignNum();
    btkPointerIdentifier: AssignPtr();
    btkStrIdentifier, btkCharArray, btkStrArray: AssignStr();
    btkPointerArray: AssignPointerArrayNum();
    btkPointerArrayStr: AssignPointerArrayStr();
    btkPointerArrayPtr: AssignPointerArrayPtr();
    btkLet:
    begin
      lexer.Advance();
      case lexer.currTok() of
        btkIdentifier: AssignNum();
        btkPointerIdentifier: AssignPtr();
        btkStrIdentifier, btkCharArray, btkStrArray: AssignStr();
        btkPointerArray: AssignPointerArrayNum();
        btkPointerArrayStr: AssignPointerArrayStr();
        btkPointerArrayPtr: AssignPointerArrayPtr();
        else
        begin
          status := BasTerminated;
          SetError('Syntax error in LET');
          Exit();
        end;
      end;
    end;
    btkData: ParseData();
    btkRead: ParseRead();
    btkRefreshRate: ParseRefreshRate();
    btkRestore: ParseRestore();
    btkFunction: ParseFunction();
    btkEndFunction: ParseEndFunction();
    btkReturn: ParseReturn();
    btkNumFunction: ParseUnassignedNumFunction();
    btkStrFunction: ParseUnassignedStrFunction();
    btkPointerFunction: ParseUnassignedPtrFunction();
    btkNext, btkEndFor: ParseNext();
    btkFor: ParseFor();
    btkIf: ParseIf();
    btkElse: ParseElse();
    btkEndIf: ParseEndif();
    btkWhile: ParseWhile();
    btkEndWhile: ParseEndWhile();
    btkRepeat: ParseRepeat();
    btkUntil: ParseUntil();
    btkDo: ParseDo();
    btkLoop: ParseLoop();
    btkBreak: ParseBreak();
    btkContinue: ParseContinue();
    btkPrint: ParsePrint();
    btkPrintLn: ParsePrintLn();
    btkEnd: ParseEnd();
    btkInput: ParseInput();
    btkCls: ParseCls();
    btkSelect: ParseSelect();
    btkCase: ParseCase();
    btkEndSelect: ParseEndSelect();
    btkInteger, btkLabel: ParseLabel();
    btkGoto: ParseGoto();
    btkGosub: ParseGosub();
    btkOn: ParseOn();
    //Debug commands
    btkAssert: ParseAssert();
    btkBreakpoint: ParseBreakpoint();
    btkDump: ParseDump();
    btkTrace: ParseTrace();
    btkTraceOn: ParseTraceOn();
    btkTraceOff: ParseTraceOff();
    btkWatch: ParseWatch();
    btkUnwatch: ParseUnwatch();
    btkCRLF: ;
    btkColon: ;
    btkNull:
    begin
      status := BasTerminated;
      if inFunction then
      begin
        status := BasTerminated;
        SetError('Function not completed by the end of the program');
        Exit;
      end;
      Emmit('END');
    end;
    else
    begin
      status := BasTerminated;
      SetError('Invalid instruction: "'+lexer.CurrS()+'"');
      Exit;
    end;
  end;
end;

procedure TBasicParser.NextFactor();
begin
  NextValue();
  lexer.Advance();
  if lexer.currTok() = btkPower then { ^ }
  begin
    lexer.Advance();
    NextFactor();
    Emmit('POW');
  end;
end;

procedure TBasicParser.NextInstruction();
var
  id: TBasToken;
begin
  NextCommand;
  id := lexer.CurrTok;
  if (id <> btkCRLF) and (id <> btkColon) and (id <> btkThen) and
     (id <> btkNull) and (id <> btkInteger) and (id <> btkLabel) then
    if not GetError then
      SetError('Syntax error');
end;

procedure TBasicParser.NextLogicArith();
begin
  NextLogicValue();
  repeat
    case lexer.CurrTok() of
      btkAnd: // and
      begin
        lexer.Advance();
        NextLogicValue();
        Emmit('AND');
      end;
      else
        Break;
    end;
  until False;
end;

procedure TBasicParser.NextLogicExpression();
begin
  NextLogicArith();
  repeat
    case lexer.CurrTok() of
      btkOr: // or
      begin
        lexer.Advance();
        NextLogicArith();
        Emmit('OR');
      end;
      // Valid terminators for a logical expression:
      // btkThen - IF condition THEN
      // btkCRLF - WHILE condition (end of line)
      // btkColon - multiline statements
      // btkNull - end of program
      // btkComma - ASSERT condition, "message"
      // btkRoundClose - parenthesized logical expressions: (a > 1 AND b < 2)
      btkThen, btkCRLF, btkColon, btkNull, btkComma, btkRoundClose:
      begin
        Break;
      end;
      else
        SetError('Condition expected')
    end;
  until GetError();
end;

//------------------------------------------------------------------------------
// IsLogicalGrouping
// Determines if a parenthesized expression starting at current position
// is a logical grouping (a > b AND c < d) or numeric grouping (a + b).
// Uses lookahead: if ')' is followed by comparison operator, it's numeric.
//------------------------------------------------------------------------------
function TBasicParser.IsLogicalGrouping(): Boolean;
var
  savedIP: Integer;
  parenDepth: Integer;
  tok: TBasToken;
begin
  Result := True;  // Default to logical grouping

  // Must be called when positioned at '('
  if lexer.CurrTok() <> btkRoundOpen then
    Exit(False);

  // Save current position for restoration
  savedIP := lexer.CurrIP;
  parenDepth := 1;

  // Skip the opening '('
  lexer.Advance();

  // Scan forward to find the matching ')'
  while parenDepth > 0 do
  begin
    tok := lexer.CurrTok();
    case tok of
      btkRoundOpen:
        Inc(parenDepth);
      btkRoundClose:
        Dec(parenDepth);
      btkNull, btkCRLF:
      begin
        // Unexpected end of expression - restore and let normal parsing handle error
        lexer.GotoToken(savedIP);
        Exit(False);
      end;
    end;
    if parenDepth > 0 then
      lexer.Advance();
  end;

  // Now we're at the matching ')' - look at what follows
  lexer.Advance();
  tok := lexer.CurrTok();

  // If followed by comparison operator, it's numeric grouping
  case tok of
    btkEqual, btkNotEqual, btkGreater, btkGreaterEqual,
    btkLower, btkLowerEqual:
      Result := False;  // Numeric grouping: (a + b) > c
    else
      Result := True;   // Logical grouping: (a > b AND c < d)
  end;

  // Restore position back to the opening '('
  lexer.GotoToken(savedIP);
end;

procedure TBasicParser.NextLogicValue();
var
  isString: Boolean;
begin
  //----------------------------------------------------------------------------
  // Handle parenthesized logical expressions FIRST
  // This must come before the NOT handling and numeric/string expression handling
  //----------------------------------------------------------------------------
  if lexer.CurrTok() = btkRoundOpen then
  begin
    if IsLogicalGrouping() then
    begin
      // This is a logical grouping: (a > b AND c < d)
      lexer.Advance();           // Skip '('
      NextLogicExpression();     // Recursively parse inner logical expression

      if GetError() then
        Exit();

      if lexer.CurrTok() <> btkRoundClose then
      begin
        SetError(') expected in logical expression');
        Exit();
      end;

      lexer.Advance();           // Skip ')'
      Exit();                    // Inner expression already produced boolean result
    end;
    // If not logical grouping, fall through to numeric/string handling below
    // The parentheses will be handled by NextNumericExpression -> NextValue
  end;

  //----------------------------------------------------------------------------
  // Handle NOT operator
  //----------------------------------------------------------------------------
  if lexer.CurrTok() = btkNot then
  begin
    lexer.Advance();
    NextLogicValue();            // Recursively parse the negated value
    Emmit('NOT');
    Exit();
  end;

  //----------------------------------------------------------------------------
  // Handle comparison expressions: expr1 op expr2
  //----------------------------------------------------------------------------
  // Check if next token is an operator, a function or a constant
  // (numerical/string)
  isString := ExpressionKind(lexer.CurrTok) = ekString;
  if isString then
    NextStringExpression()       // String expression
  else
    NextNumericExpression();     // Numerical expression

  if GetError() then
    Exit();

  // Now expect a comparison operator
  case lexer.CurrTok() of
    btkEqual: // =
    begin
      lexer.Advance();
      if isString then
      begin
        NextStringExpression();
        Emmit('EQ$');
      end
      else
      begin
        NextNumericExpression();
        Emmit('EQ');
      end;
    end;
    btkNotEqual: // <>
    begin
      lexer.Advance();
      if isString then
      begin
        NextStringExpression();
        Emmit('NE$');
      end
      else
      begin
        NextNumericExpression();
        Emmit('NE');
      end;
    end;
    btkGreater: // >
    begin
      lexer.Advance();
      if isString then
      begin
        NextStringExpression();
        Emmit('GT$');
      end
      else
      begin
        NextNumericExpression();
        Emmit('GT');
      end;
    end;
    btkGreaterEqual: // >=
    begin
      lexer.Advance();
      if isString then
      begin
        NextStringExpression();
        Emmit('GE$');
      end
      else
      begin
        NextNumericExpression();
        Emmit('GE');
      end;
    end;
    btkLower: // <
    begin
      lexer.Advance();
      if isString then
      begin
        NextStringExpression();
        Emmit('LT$');
      end
      else
      begin
        NextNumericExpression();
        Emmit('LT');
      end;
    end;
    btkLowerEqual: // <=
    begin
      lexer.Advance();
      if isString then
      begin
        NextStringExpression();
        Emmit('LE$');
      end
      else
      begin
        NextNumericExpression();
        Emmit('LE');
      end;
    end;
    else
      SetError('Logic operator expected');
  end;
end;

procedure TBasicParser.NextNumericExpression();
begin
  try
    NextArith();
    repeat
      case lexer.CurrTok() of
        btkPlus: // +
        begin
          lexer.Advance();
          NextArith();
          Emmit('ADD');
        end;
        btkMinus: // -
        begin
          lexer.Advance();
          NextArith();
          Emmit('SUB');
        end;
        btkMin: // ?<
        begin
          lexer.Advance();
          NextArith();
          Emmit('MIN');
        end;
        btkMax: // ?>
        begin
          lexer.Advance();
          NextArith();
          Emmit('MAX');
        end;
        //after an expression, token must be one of the listed below
        btkCRLF, btkThen, btkColon, btkRoundClose, btkSquareClose,
        btkDoubleSquareClose, btkEqual, btkNotEqual, btkLower, btkComma,
        btkLowerEqual, btkGreater, btkGreaterEqual, btkAnd, btkOr, btkTo,
        btkStep, btkNull, btkSemiColon, btkGoto, btkGosub, btkCall:
          Break;
        else
          SetError('Arithmetic operator expected');
      end;
    until GetError;
  except
    SetError('Arithmetic overflow');
  end;
end;

procedure TBasicParser.NextPointerExpression();
var
  st: String;
begin
  try
    case lexer.CurrTok() of
      btkRoundOpen: // (
      begin
        lexer.Advance();
        NextPointerExpression();
        if lexer.CurrTok <> btkRoundClose then
          SetError(') expected');
      end;
      // JSON SUPPORT - Handle JSON literals in pointer expressions
      btkSquareOpen: // JSON array literal [...]
      begin
        ParseJsonArray();
        Exit; // Don't advance - ParseJsonArray already did
      end;
      btkCurlyOpen: // JSON object literal {...}
      begin
        ParseJsonObject();
        Exit; // Don't advance - ParseJsonObject already did
      end;
      btkIndirectCallPtr: ParseIndirectCall(TExprKind.ekPointer);
      btkPointerArrayPtr: ParsePointerArrayPtrGet();
      btkPointerIdentifier: { # }
      begin
        if lexer.CurrS().ToUpper() = 'THIS#' then //this#
          Emmit('PUSH#_TAG')
        else //ptr#
          Emmit('PUSH# @' + lexer.CurrS().ToLower());
      end;
      btkPointerFunction: // fnc#(...)
      begin
        st := lexer.CurrS().ToLower(); //function name in "st"
        lexer.Advance();
        Emmit('CALLEX# "'+st+'@'+GetParams+'"     ');
      end;
      else
        SetError('Pointer expected');
    end;
  except
    SetError('Arithmetic overflow');
  end;
  lexer.Advance();
end;

procedure TBasicParser.NextStringExpression();
var
  i: Integer;
begin
  try
    NextStringValue();
    repeat
      lexer.Advance();
      case lexer.CurrTok() of
        btkPlus: // +
        begin
          lexer.Advance();
          NextStringValue();
          Emmit('ADD$');
        end;
        btkSlash: // /
        begin
          lexer.Advance();
          NextStringValue();
          Emmit('ADDCRLF$');
        end;
        btkMinus: // -
        begin
          lexer.Advance();
          i := -1;
          if lexer.CurrTok() = btkInteger then
            i := SafeRound(lexer.CurrN, 0, 1000);
          if i < 0 then
            SetError('Invalid number')
          else
          begin
            Emmit('PUSHC ' + IntToStr(i));
            Emmit('SUB$');
          end;
        end;
        //token after a string expression must be one of the following
        btkNull, btkCRLF, btkColon, btkSemiColon, btkRoundClose, btkSquareClose,
        btkNotEqual, btkEqual, btkAnd, btkOr, btkThen, btkComma, btkLower,
        btkLowerEqual, btkGreater, btkGreaterEqual:
          Break;
        else
          SetError('String operator expected')
      end;
    until GetError();
  except
    SetError('Arithmetic overflow');
  end;
end;

procedure TBasicParser.NextStringValue();
var
  st: String;
begin
  case lexer.CurrTok() of
    btkRoundOpen: // (
    begin
      lexer.Advance();
      NextStringExpression();
      if lexer.CurrTok() <> btkRoundClose then
        SetError(') expected');
    end;
    btkCharArray: // ident$[[
    begin
      //String representation does not include the '[' character
      Emmit('PUSH$ @' + lexer.CurrS());
      lexer.Advance();
      NextNumericExpression();
      if lexer.CurrTok() <> btkDoubleSquareClose then
      begin
        status := BasTerminated;
        SetError(']] expected');
        Exit();
      end;
      Emmit('PUSHC 2');
      Emmit('CALLEX$ "chr$@$n"     ');
    end;
    btkStrArray: //ident$[
    begin
      //String representation does not include the '[' character
      Emmit('PUSH$ @' + lexer.CurrS());
      lexer.Advance();
      NextNumericExpression();
      if lexer.CurrTok() <> btkSquareClose then
      begin
        Status := BasTerminated;
        SetError('] expected');
        Exit();
      end;
      Emmit('PUSHC 2');
      Emmit('CALLEX$ "line$@$n"     ');
    end;
    btkStrFunction: { fnc$(...) }
    begin
      st := LowerCase(lexer.CurrS()); //Function name in "st"
      lexer.Advance;
      Emmit('CALLEX$ "'+st+'@'+GetParams()+'"     ');
    end;
    btkPointerArrayStr: ParsePointerArrayStrGet();
    btkIndirectCallStr: ParseIndirectCall(TExprKInd.ekString);
    btkStrIdentifier: Emmit('PUSH$ @' + lexer.CurrS());
    btkString: Emmit('PUSHC$ "'+lexer.CurrS()+'"');
    else
      SetError('String expected');
  end;
end;

procedure TBasicParser.NextValue();
var
  st: String;
begin
  case lexer.currTok() of
    btkMinus: { - }
    begin
      lexer.Advance;
      NextValue;
      Emmit('INV');
    end;
    btkRoundOpen: { ( }
    begin
      lexer.Advance();
      NextNumericExpression();
      if lexer.currTok() <> btkRoundClose then SetError(') expected');
    end;
    btkNumFunction: { fnc(... }
    begin
      st := LowerCase(lexer.CurrS()); //function name in "st"
      lexer.Advance();
      Emmit('CALLEX "'+st+'@'+GetParams+'"     ');
    end;
    (*
    btkAt:
    begin
      lexer.Advance; //skip the '(' and go to function signature
      NextStringExpression;
      Emmit('ADDR');
      lexer.PutBack; //return last token
    end;
    *)
    btkPointerArray: ParsePointerArrayNumGet();
    btkAmpersand: ParseIndirectCall(TExprKind.ekNumber);
    btkIdentifier: Emmit('PUSH @' + lexer.CurrS());
    btkInteger, btkFloat: Emmit('PUSHC ' + TUtils.FloatToStr2(lexer.CurrN));
    else
      SetError('Value expected');
  end;
end;

//-----------------------------------------------------------------------------
// ASSERT condition, "message"
// Only executes when trace mode is enabled
// Stops execution if condition is false
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseAssert();
begin
  lexer.Advance(); //skip ASSERT keyword

  //Parse the logical condition (now supports full OR expressions)
  NextLogicExpression();

  //Check for error during condition parsing
  if GetError() then
    Exit();

  //Expect comma
  if lexer.CurrTok() <> btkComma then
  begin
    status := BasTerminated;
    SetError('Comma expected after ASSERT condition');
    Exit();
  end;
  lexer.Advance(); //skip comma

  //Parse the message string
  NextStringExpression();

  //Check for error during message parsing
  if GetError() then
    Exit();

  //Emit ASSERT instruction
  Emmit('ASSERT');
end;

procedure TBasicParser.ParseBreak();
begin
  if forCnt + repeatCnt + whileCnt + doCnt = 0 then
  begin
    status := BasTerminated;
    SetError('Misplaced BREAK');
    Exit();
  end;
  Emmit('BREAK');
  lexer.Advance();
end;

procedure TBasicParser.ParseCase();
begin
  lexer.Advance(); //skip CASE
  if (selectCnt < 1) then
  begin
    status := BasTerminated;
    SetError('Misplaced CASE');
    Exit;
  end;
  Emmit('CASESTART');
  case lexer.CurrTok() of
    btkElse:
    begin
      //When there is a "CASE ELSE" statement, we cannot include another CASE
      //test in the same SELECT.
      //"selCaseElse" stack is used to check this condition.
      selCaseElse[selectCnt-1] := True;
      Emmit('CASEELSE');
      lexer.Advance();
    end;
    btkString, btkStrIdentifier, btkCharArray, btkStrArray, btkStrFunction:
    begin
      if selType[selectCnt-1] <> TExprKind.ekString then
      begin
        status := BasTerminated;
        SetError('Invalid expression type');
        Exit();
      end;

      if selCaseElse[selectCnt-1] then
      begin
        status := BasTerminated;
        SetError('Misplaced CASE');
        Exit();
      end;

      NextStringExpression();
      Emmit('PUSHAUXTOS');
      Emmit('EQ$');
      if lexer.CurrTok() = btkComma then
        repeat
          lexer.Advance();
          NextStringExpression();
          Emmit('PUSHAUXTOS');
          Emmit('EQ$');
          Emmit('OR');
        until lexer.CurrTok() <> btkComma;
    end
    else
    begin
      if selType[selectCnt-1] <> TExprKind.ekNumber then
      begin
        status := BasTerminated;
        SetError('Invalid expression type');
        Exit();
      end;

      if selCaseElse[selectCnt-1] then
      begin
        status := BasTerminated;
        SetError('Misplaced CASE');
        Exit;
      end;

      NextNumericExpression();
      Emmit('PUSHAUXTOS');
      Emmit('EQ');
      if lexer.CurrTok = btkComma then
        repeat
          lexer.Advance();
          NextNumericExpression();
          Emmit('PUSHAUXTOS');
          Emmit('EQ');
          Emmit('OR');
        until lexer.CurrTok() <> btkComma;
    end;
  end;
  Emmit('CASEEND');
  if (lexer.CurrTok() <> btkCRLF) and (lexer.CurrTok() <> btkColon) then
  begin
    status := BasTerminated;
    SetError('Syntax error in CASE');
    Exit();
  end;
end;

procedure TBasicParser.ParseCls();
begin
  Emmit('CLS');
  lexer.Advance();
end;

procedure TBasicParser.ParseContinue();
begin
  if forCnt + repeatCnt + whileCnt + doCnt = 0 then
  begin
    status := BasTerminated;
    SetError('Misplaced CONTINUE');
    Exit();
  end;
  Emmit('CONTINUE');
  lexer.Advance();
end;

procedure TBasicParser.ParseData();
var
  id: TBasToken;
begin
  if inFunction then
  begin
    status := BasTerminated;
    SetError('Misplaced DATA (cannot be inside functions)');
    Exit;
  end;

  lexer.Advance; //skip DATA command
  case lexer.currTok() of
    btkMinus:
      if (lexer.NextTok = btkInteger) or (lexer.NextTok = btkFloat) then
      begin
        lexer.Advance;
        Emmit('DATA -'+lexer.CurrS());
      end
      else
      begin
        status := BasTerminated;
        SetError('Invalid data constant');
        Exit;
      end;
    btkInteger, btkFloat:
      Emmit('DATA '+lexer.CurrS());
    btkString:
      Emmit('DATA$ "'+lexer.CurrS()+'"');
    else
    begin
      status := BasTerminated;
      SetError('Invalid data constant');
      Exit;
    end;
  end;
  lexer.Advance(); //Skip last constant
  if lexer.currTok() = btkComma then
  begin
    repeat
      lexer.Advance; //Skip comma
      case lexer.CurrTok() of
        btkMinus:
          if (lexer.NextTok = btkInteger) or (lexer.NextTok = btkFloat) then
          begin
            lexer.Advance();
            Emmit('DATA -'+lexer.CurrS());
          end
          else
          begin
            status := BasTerminated;
            SetError('Invalid data constant');
            Exit();
          end;
        btkInteger, btkFloat:
          Emmit('DATA '+lexer.CurrS());
        btkString:
          Emmit('DATA$ "'+lexer.CurrS()+'"');
        else
        begin
          status := BasTerminated;
          SetError('Invalid data constant');
          Exit();
        end;
      end;
      lexer.Advance(); //skip last constant
      id := lexer.CurrTok();
    until id <> btkComma;
  end;
end;

procedure TBasicParser.ParseDo();
var
  i: Integer;
begin
  Inc(doCnt);
  i := TMPOutput.Count;
  lexer.Advance(); //skip DO

  case lexer.CurrTok() of
    btkWhile: //DO WHILE condition ... LOOP
    begin
      lexer.Advance(); //skip WHILE
      NextLogicExpression();
      //POPNJUMP jumps when 0 (false), which is what we want for WHILE
      Emmit('DO_WHILE ' + IntToStr(i));
    end;
    btkUntil: //DO UNTIL condition ... LOOP
    begin
      lexer.Advance(); //skip UNTIL
      NextLogicExpression();
      //UNTIL exits when TRUE (1). POPNJUMP jumps when 0.
      //So we invert: NOT makes 1->0 (jump out), 0->1 (don't jump)
      Emmit('NOT');
      Emmit('DO_UNTIL ' + IntToStr(i));
    end;
    btkCRLF, btkColon: //DO ... LOOP (infinite or with post-test)
    begin
      Emmit('DO_START ' + IntToStr(i));
    end;
    else
    begin
      status := BasTerminated;
      SetError('Syntax error in DO');
      Exit();
    end;
  end;
end;

//-----------------------------------------------------------------------------
// DUMP ["label"]
// Only executes when trace mode is enabled
// Displays all global variables
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseDump();
begin
  lexer.Advance(); //skip DUMP keyword

  //Check for optional label string
  if lexer.CurrTok() = btkString then
  begin
    Emmit('PUSHC$ "' + lexer.CurrS() + '"');
    lexer.Advance();
  end
  else
  begin
    //No label - push empty string
    Emmit('PUSHC$ ""');
  end;

  //Emit DUMP instruction
  Emmit('DUMP');
end;

procedure TBasicParser.ParseLoop();
var
  i: Integer;
begin
  if doCnt < 1 then
  begin
    status := BasTerminated;
    SetError('LOOP without DO');
    Exit();
  end;
  Dec(doCnt);
  i := TMPOutput.Count;
  lexer.Advance(); //skip LOOP

  case lexer.CurrTok() of
    btkWhile: //DO ... LOOP WHILE condition
    begin
      lexer.Advance(); //skip WHILE
      NextLogicExpression();
      //LOOP WHILE: continue (jump back) when TRUE (1). POPNJUMP jumps when 0.
      //So we invert: NOT makes 1->0 (jump back), 0->1 (don't jump, exit)
      Emmit('NOT');
      Emmit('LOOP_WHILE ' + IntToStr(i));
    end;
    btkUntil: //DO ... LOOP UNTIL condition
    begin
      lexer.Advance(); //skip UNTIL
      NextLogicExpression();
      //LOOP UNTIL: exit when TRUE (1), continue when FALSE (0).
      //POPNJUMP jumps when 0 - perfect for jumping back!
      Emmit('LOOP_UNTIL ' + IntToStr(i));
    end;
    btkCRLF, btkColon: //DO [WHILE|UNTIL] ... LOOP (ends pre-tested loop)
    begin
      Emmit('LOOP_END ' + IntToStr(i));
    end;
    else
    begin
      status := BasTerminated;
      SetError('Syntax error in LOOP');
      Exit();
    end;
  end;
end;

procedure TBasicParser.ParseElse();
begin
  if (ifCnt < 1) then
  begin
    status := BasTerminated;
    SetError('Misplaced ELSE');
    Exit();
  end;
  if lexer.NextTok() = btkIf then
  begin
    lexer.Advance(); //skip ELSE
    lexer.Advance(); //skip IF
    Emmit('ELSEIFTEST'); //pre test label
    NextLogicExpression(); //logic expression (the test)
    Emmit('ELSEIFBODY'); //pos test label
    if lexer.CurrTok <> btkThen then
    begin
      status := BasTerminated;
      SetError('THEN expected');
      Exit();
    end;
    Exit();
  end;
  Emmit('ELSE');
  lexer.Advance();
end;

procedure TBasicParser.ParseEnd();
begin
  case lexer.NextTok() of
    btkIf:
    begin
      lexer.Advance(); //Jump END
      ParseEndIf();
    end;
    btkWhile:
    begin
      lexer.Advance(); //Jump END
      ParseEndWhile();
    end;
    btkFunction:
    begin
      lexer.Advance(); //Jump END
      ParseEndFunction();
    end;
    btkFor:
    begin
      lexer.Advance(); //Jump END
      ParseNext();
    end;
    btkSelect:
    begin
      lexer.Advance(); //Jump END
      ParseEndSelect();
    end;
    btkCRLF, btkColon:
    begin
      Emmit('END');
      lexer.Advance();
    end
    else
    begin
      status := BasTerminated;
      SetError('Syntax error in END');
      Exit();
    end;
  end;
end;

procedure TBasicParser.ParseEndFunction();
begin
  if not inFunction then
  begin
    status := BasTerminated;
    SetError('Misplaced ENDFUNCTION');
    Exit();
  end
  else if not CheckCounters() then
  begin
    //"SetError" was configured inside CheckCounters
    status := BasTerminated;
    Exit();
  end;

  lexer.Advance();
  case lastFunc of
    btkNumFunction: Emmit('PUSHC 0');
    btkStrFunction: Emmit('PUSHC$ ""');
    btkPointerFunction: Emmit('PUSHC 0');
  end;
  inFunction := False;
  Emmit('RETFUNCTION');
  Emmit('ENDFUNCTION');
end;

procedure TBasicParser.ParseEndif();
begin
  if ifCnt < 1 then
  begin
    status := BasTerminated;
    SetError('Misplaced ENDIF');
    Exit;
  end;
  Dec(ifCnt);
  Emmit('ENDIF');
  lexer.Advance(); //Jump IF
end;

procedure TBasicParser.ParseEndSelect();
begin
  lexer.Advance();
  selCaseElse[selectCnt-1] := False;  // Reset CASE ELSE flag for this SELECT level
  Dec(selectCnt);
  if selectCnt < 0 then
  begin
    status := BasTerminated;
    SetError('Misplaced ENDSELECT');
    Exit();
  end;
  Emmit('POPAUX');
end;

procedure TBasicParser.ParseEndWhile();
begin
  if (whileCnt < 1) then
  begin
    status := BasTerminated;
    SetError('Misplaced ENDWHILE/WEND');
    Exit();
  end;
  Dec(whileCnt);
  Emmit('ENDWHILE');
  lexer.Advance();
end;

procedure TBasicParser.ParseFor();
var
  s: String;
  i: Integer;
  d: Double;
  TokenRep: TStringToken;
begin
  Inc(forCnt);
  lexer.Advance(); // Skip the "FOR"
  // HIGH PRIORITY FIX: Validate FOR loop variable type
  if lexer.CurrTok = btkStrIdentifier then
  begin
    status := BasTerminated;
    SetError('FOR loop variable cannot be a string');
    Exit();
  end;
  if lexer.CurrTok = btkPointerIdentifier then
  begin
    status := BasTerminated;
    SetError('FOR loop variable cannot be a pointer');
    Exit();
  end;
  if lexer.CurrTok <> btkIdentifier then
  begin
    status := BasTerminated;
    SetError('Numeric variable expected in FOR loop');
    Exit();
  end;
  s := lexer.CurrS();
  // Store the control variable name in the stack for NEXT validation
  forVarStack[forCnt - 1] := s.ToLower();
  lexer.Advance();
  if lexer.CurrTok() <> btkEqual then
  begin
    status := BasTerminated;
    SetError('= expected after FOR variable');
    Exit();
  end;
  lexer.Advance();
  NextNumericExpression();
  Emmit('??????????'); //updated below
  Emmit('SUB');
  Emmit('POPSTORE @' + s);
  i := TMPOutput.Count;
  if lexer.CurrTok() <> btkTo then
  begin
    status := BasTerminated;
    SetError('TO expected in FOR loop');
    Exit;
  end;
  lexer.Advance();
  NextNumericExpression();
  d := 1;
  //if using 'STEP'
  if lexer.CurrTok() = btkStep then
  begin
    lexer.Advance();
    if lexer.CurrTok() = btkMinus then
    begin
      d := -1;
      lexer.Advance();
    end;
    if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok() <> btkFloat) then
    begin
      status := BasTerminated;
      SetError('Numeric STEP value expected');
      Exit();
    end;
    d := d * lexer.CurrN();
    if d = 0 then
    begin
      status := BasTerminated;
      SetError('STEP value cannot be zero');
      Exit();
    end;
    lexer.Advance();
  end;
  Emmit('PUSHC ' + TUtils.FloatToStr2(d));
  Emmit('FORCYCLE @' + s);
  if d > 0 then
    Emmit('GE')
  else
    Emmit('LE');
  Emmit('WHILE ' + IntToStr(i) + '   ');
  TokenRep.Str := 'PUSHC ' + TUtils.FloatToStr2(d);
  TMPOutput[i - 3] := TokenRep; //overwrites the '??????????'
end;

procedure TBasicParser.ParseFunction();
var
  i: Integer;
  s, st: String;
begin
  if inFunction then
  begin
    status := BasTerminated;
    SetError('Nested functions not allowed');
    Exit;
  end;
  if not CheckCounters() then
  begin
    //"SetError" is configured inside CheckCounters
    status := BasTerminated;
    Exit;
  end;

  inFunction := True;
  lexer.Advance;
  lastFunc := lexer.CurrTok;
  if not (lastFunc in [btkNumFunction, btkStrFunction, btkPointerFunction]) then
  begin
    status := BasTerminated;
    SetError('Error in function declaration');
    Exit;
  end;
  st := lexer.CurrS().ToLower() + '@';
  lexer.Advance;
  i := 0;
  s := '';
  while lexer.CurrTok <> btkRoundClose do
  begin
    if i > 0 then
      if (lexer.CurrTok <> btkComma) then
      begin
        status := BasTerminated;
        SetError('Error in function parameters declaration');
        Exit;
      end
      else lexer.Advance;
    case lexer.CurrTok of
      btkIdentifier: st := st + 'n';
      btkStrIdentifier: st := st + '$';
      btkPointerIdentifier: st := st + '#';
      else
      begin
        status := BasTerminated;
        SetError('Error in function parameters declaration');
        Exit;
      end;
    end;
    Inc(i);
    s := lexer.CurrS().ToLower() + ' ' + s;
    lexer.Advance;
    if GetError then Break;
  end;
  //Store header "FUNCTION fnc@..."
  Emmit('FUNCTION ' + st);
  lexer.Advance;
  st := '';
  i := 0;
  if lexer.CurrTok = btklocal then
    repeat
      lexer.Advance;
      if lexer.CurrTok in [btkIdentifier, btkStrIdentifier, btkPointerIdentifier] then
        st := lexer.CurrS() + ' ' + st
      else
      begin
        status := BasTerminated;
        SetError('Expected a variable');
        Exit;
      end;
      lexer.Advance;
      Inc(i); //holds the total of local vars
    until lexer.CurrTok <> btkComma;
  // * : initial marker
  // i : total of local vars
  // st : local vars list
  // LOCAL_REG_STR : base registers (local to each function)
  // s : function arguments
  // * : final marker
  Emmit('* ' + IntToStr(i) + ' ' + st + ' ' + LOCAL_REG_STR + ' ' + s + '*');
end;

procedure TBasicParser.ParseGosub();
var
  //i: Integer;
  i: LongWord;
begin
  if inFunction then
  begin
    status := BasTerminated;
    SetError('GOSUB inside a function');
    Exit();
  end;

  lexer.Advance();

  if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok <> btkIdentifier) then
  begin
    status := BasTerminated;
    SetError('Label expected');
    Exit();
  end;

  if lexer.CurrTok() = btkInteger then
  begin
    i := Round(lexer.CurrN);
    if i = 0 then
    begin
      status := BasTerminated;
      SetError('Unknown label');
      Exit();
    end;
  end
  else //It must be a btkIdentifier
  begin
    i := TUtils.GPTStrHash(lexer.CurrS().ToUpper()+':');
    if i = 0 then
    begin
      status := BasTerminated;
      SetError('Unknown label');
      Exit();
    end;
  end;

  Emmit('CALL ' + UIntToStr(i));
  //Emmit('CALL ' + IntToStr(i));
  lexer.Advance();
end;

procedure TBasicParser.ParseGoto();
var
  //i: Integer;
  i: LongWord;
begin
  if inFunction then
  begin
    status := BasTerminated;
    SetError('GOTO inside a function');
    Exit();
  end;

  lexer.Advance();

  if (lexer.CurrTok <> btkInteger) and (lexer.CurrTok <> btkIdentifier) then
  begin
    status := BasTerminated;
    SetError('Label expected');
    Exit();
  end;

  if lexer.CurrTok = btkInteger then
  begin
    i := Round(lexer.CurrN);
    if i = 0 then
    begin
      status := BasTerminated;
      SetError('Unknown label');
      Exit();
    end;
  end
  else //it must be a btkIdentifier
  begin
    i := TUtils.GPTStrHash(lexer.CurrS().ToUpper()+':');
    if i = 0 then
    begin
      status := BasTerminated;
      SetError('Unknown label');
      Exit();
    end;
  end;

  Emmit('JUMP ' + UIntToStr(i));
  //Emmit('JUMP ' + IntToStr(i));
  lexer.Advance();
end;

procedure TBasicParser.ParseIf();
begin
  lexer.Advance(); //skip the "IF"
  NextLogicExpression();
  if lexer.CurrTok() <> btkThen then
  begin
    status := BasTerminated;
    SetError('THEN expected');
    Exit();
  end;
  if (lexer.NextTok = btkCRLF) or (lexer.NextTok = btkColon) then
  begin
    Emmit('POPNJUMP_ENDIF');
    Inc(ifCnt);
  end
  else
    Emmit('POPNJUMP_CRLF');
end;

//The indirect call operator does not check for the called function return type.
//When using indirect calls as part of a numerical or string expressions, it's
//necessary to help the compiler to know what kind of type is being handled.
//using the ($) char after the indirect call operator, informs the compiler that
//the function called is expected to return a string. If the (#) char is used,
//the function is expected to return a pointer. Otherwise it is a numerical
//function. For example:
//
// &('sin@n', 90) --numerical result expected
// &$('ucase$@$', 'uppercase string') --String result expected
// &#('dict_new#@n', 0) --pointer result expected
//
procedure TBasicParser.ParseIndirectCall(CallType: TExprKind);
var
  i: Integer;
begin
  i := 0;
  lexer.Advance(); //skip the '&[$#]'
  if lexer.CurrTok() <> btkRoundOpen then
  begin
    Status := BasTerminated;
    SetError('( expected');
    Exit;
  end;
  lexer.Advance(); //skips the '('
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekString then
  begin
    Status := BasTerminated;
    SetError('Syntax error in the indirect call. Function signature must be a string expression');
    Exit();
  end;

  NextStringExpression();
  Inc(i);
  if lexer.CurrTok() <> btkComma then
    if lexer.CurrTok() <> btkRoundClose then
    begin
      Status := BasTerminated;
      SetError(') expected');
      Exit();
    end
    else
    begin
      Emmit('PUSHC '+IntToStr(i));
      Emmit('I_CALL');
      Exit();
    end;
  repeat
    lexer.Advance();
    case lexer.CurrTok() of
      btkString, btkStrIdentifier, btkStrArray, btkStrFunction:
      begin
        NextStringExpression();
        Inc(i);
      end;
      btkPointerIdentifier, btkPointerFunction:
      begin
        NextPointerExpression();
        Inc(i);
      end;
      else
      begin
        NextNumericExpression();
        Inc(i);
      end;
    end;
  until (lexer.CurrTok <> btkComma);
  if lexer.CurrTok <> btkRoundClose then
  begin
    Status := BasTerminated;
    SetError(') expected');
    Exit();
  end;
  Emmit('PUSHC '+IntToStr(i));
  Emmit('I_CALL');
end;

procedure TBasicParser.ParseInput();
var
  ExpKind: TExprKind;
begin
  lexer.Advance(); //skip INPUT statement

  //Process the text caption
  if ExpressionKind(lexer.CurrTok) <> ekString then
  begin
    status := BasTerminated;
    SetError('String expected as caption');
    Exit();
  end;
  NextStringExpression(); //Caption
  if lexer.CurrTok() <> btkComma then
  begin
    status := BasTerminated;
    SetError(', expected');
    Exit();
  end;
  lexer.Advance();

  //Process the text label
  if ExpressionKind(lexer.CurrTok) <> ekString then
  begin
    status := BasTerminated;
    SetError('String expected as label');
    Exit();
  end;
  NextStringExpression(); //Label
  if lexer.CurrTok() <> btkComma then
  begin
    status := BasTerminated;
    SetError(', expected');
    Exit();
  end;
  lexer.Advance();

  //Process the default value
  if ExpressionKind(lexer.CurrTok) = ekString then
  begin
    NextStringExpression(); //String default value
    ExpKind := ekString;
  end
  else if ExpressionKind(lexer.CurrTok) = ekNumber then
  begin
    NextNumericExpression(); //Numeric default value
    ExpKind := ekNumber;
  end
  else
  begin
    status := BasTerminated;
    SetError('Default value must be numeric or string');
    Exit();
  end;

  if lexer.CurrTok() <> btkComma then
  begin
    status := BasTerminated;
    SetError(', expected');
    Exit();
  end;
  lexer.Advance();

  // Process the callback
  if (lexer.CurrTok() <> btkIdentifier) and (lexer.CurrTok() <> btkStrIdentifier) then
  begin
    status := BasTerminated;
    SetError('Function name expected');
    Exit();
  end;
  if (lexer.CurrTok = btkStrIdentifier) and (ExpKind = ekString) then
  begin
    Emmit('PUSHC$ "'+lexer.CurrS().ToLower()+'@$"');
    Emmit('INPUT$')
  end
  else if (lexer.CurrTok = btkIdentifier) and (ExpKind = ekNumber) then
  begin
    Emmit('PUSHC$ "'+lexer.CurrS().ToLower()+'@n"');
    Emmit('INPUT');
  end
  else
  begin
    status := BasTerminated;
    SetError('Syntax error');
    Exit();
  end;
  lexer.Advance();

  //---------------------------------------------------------------------------------
  // The code below was discarded because it is specific to synchronous environments
  // like MS Windows, Mac OSX and Linux.
  //---------------------------------------------------------------------------------
//  if lexer.CurrTok() <> btkComma then
//  begin
//    status := BasTerminated;
//    SetError(', expected');
//    Exit();
//  end;
//  lexer.Advance();
//
//  // Result variable (This syntax works only under Windows)
//  if (lexer.CurrTok() <> btkIdentifier) and (lexer.CurrTok() <> btkStrIdentifier) then
//  begin
//    status := BasTerminated;
//    SetError('Variable name expected');
//    Exit();
//  end;
//  if (lexer.CurrTok = btkStrIdentifier) and (ExpKind = ekString) then
//    Emmit('POPSTORE$ @'+lexer.CurrS())
//  else if (lexer.CurrTok = btkIdentifier) and (ExpKind = ekNumber) then
//    Emmit('POPSTORE @'+lexer.CurrS())
//  else
//  begin
//    status := BasTerminated;
//    SetError('Syntax error');
//    Exit();
//  end;
//  lexer.Advance();
end;

procedure TBasicParser.ParseLabel();
var
  i: LongWord;
begin
  if lexer.PrevTok() <> btkThen then
  begin
    if lexer.CurrTok() = btkInteger then
      Emmit(IntToStr(Round(lexer.CurrN)))
    else
      Emmit(UIntToStr(TUtils.GPTStrHash(lexer.CurrS().ToUpper())));
  end
  else //THEN 10 <=> THEN GOTO 10
  begin
    if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok <> btkLabel) then
    begin
      status := BasTerminated;
      SetError('Label expected');
    end;

    if lexer.CurrTok() = btkInteger then
    begin
      i := Round(lexer.CurrN);
      if i = 0 then
      begin
        status := BasTerminated;
        SetError('Unknown label');
      end
      else Emmit('JUMP '+UIntToStr(i));
    end
    else
    begin
      Emmit('JUMP '+UIntToStr(TUtils.GPTStrHash(lexer.CurrS().ToUpper)));
    end;
  end;
end;

procedure TBasicParser.ParseNext();
var
  expectedVar, providedVar: String;
begin
  if forCnt < 1 then
  begin
    status := BasTerminated;
    SetError('NEXT/ENDFOR without FOR');
    Exit();
  end;

  // Get the expected variable from the stack (before decrementing)
  expectedVar := forVarStack[forCnt - 1];
  Dec(forCnt);
  lexer.Advance();

  // Allow optional control variable after NEXT (for compatibility with traditional BASIC)
  // If provided, validate it matches the FOR loop control variable
  if lexer.CurrTok() = btkIdentifier then
  begin
    providedVar := lexer.CurrS().ToLower();
    // Validate that the provided variable matches the FOR loop variable
    if providedVar <> expectedVar then
    begin
      status := BasTerminated;
      SetError('NEXT variable does not match FOR variable');
      Exit();
    end;
    lexer.Advance();
  end;

  // Now we must be at end of statement (CRLF or colon)
  if (lexer.CurrTok() <> btkCRLF) and (lexer.CurrTok() <> btkColon) then
  begin
    status := BasTerminated;
    SetError('Syntax error in NEXT/ENDFOR');
    Exit();
  end;
  Emmit('ENDWHILE    ');
end;

procedure TBasicParser.ParseOn();
var
  i: Integer;
  labelValue: LongWord;

  // Helper function to get label value from current token
  function GetLabelValue(): LongWord;
  begin
    Result := 0;
    if lexer.CurrTok() = btkInteger then
      Result := Round(lexer.CurrN)
    else if lexer.CurrTok() = btkIdentifier then
      Result := TUtils.GPTStrHash(lexer.CurrS().ToUpper()+':');
  end;

begin
  lexer.Advance(); //skip the ON command
  NextNumericExpression();
  //Store the expression at internal register (0)
  Emmit('POPSTORE @0');
  if (lexer.CurrTok <> btkGoto) and (lexer.CurrTok <> btkGosub) and (lexer.CurrTok <> btkCall) then
  begin
    status := BasTerminated;
    SetError('GOTO, GOSUB or CALL expected');
    Exit();
  end;
  // ON .. GOTO
  if lexer.CurrTok = btkGoto then
  begin
    lexer.Advance(); //skip GOTO
    i := 1; //First label
    // FIX: Accept both btkInteger AND btkIdentifier
    if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok() <> btkIdentifier) then
    begin
      status := BasTerminated;
      SetError('Label expected');
      Exit();
    end;
    labelValue := GetLabelValue();
    if labelValue = 0 then
    begin
      status := BasTerminated;
      SetError('Invalid label');
      Exit();
    end;
    Emmit('PUSH @0');
    Emmit('PUSHC '+IntToStr(i));
    Emmit('NE');
    Emmit('ONGOTO '+UIntToStr(labelValue));
    repeat
      lexer.Advance(); //Skip the label
      if lexer.CurrTok() <> btkComma then
      begin
        Inc(i);
        // FIX: Accept both btkInteger AND btkIdentifier
        if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok() <> btkIdentifier) then
        begin
          status := BasTerminated;
          SetError('Label expected');
          Exit();
        end;
        labelValue := GetLabelValue();
        if labelValue = 0 then
        begin
          status := BasTerminated;
          SetError('Invalid label');
          Exit();
        end;
        Emmit('PUSH @0');
        Emmit('PUSHC '+IntToStr(i));
        Emmit('NE');
        Emmit('ONGOTO '+UIntToStr(labelValue));
        lexer.Advance();
      end;
    until (lexer.CurrTok <> btkComma);
  end
  // ON .. GOSUB
  else if lexer.CurrTok = btkGosub then
  begin
    lexer.Advance(); //skip GOSUB
    i := 1; //First label
    // FIX: Accept both btkInteger AND btkIdentifier
    if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok() <> btkIdentifier) then
    begin
      status := BasTerminated;
      SetError('Label expected');
      Exit();
    end;
    labelValue := GetLabelValue();
    if labelValue = 0 then
    begin
      status := BasTerminated;
      SetError('Invalid label');
      Exit();
    end;
    Emmit('PUSH @0');
    Emmit('PUSHC '+IntToStr(i));
    Emmit('NE');
    Emmit('ONGOSUB '+UIntToStr(labelValue));
    repeat
      lexer.Advance(); //Skip the label
      if lexer.CurrTok() <> btkComma then
      begin
        Inc(i);
        // FIX: Accept both btkInteger AND btkIdentifier
        if (lexer.CurrTok() <> btkInteger) and (lexer.CurrTok() <> btkIdentifier) then
        begin
          status := BasTerminated;
          SetError('Label expected');
          Exit();
        end;
        labelValue := GetLabelValue();
        if labelValue = 0 then
        begin
          status := BasTerminated;
          SetError('Invalid label');
          Exit();
        end;
        Emmit('PUSH @0');
        Emmit('PUSHC '+IntToStr(i));
        Emmit('NE');
        Emmit('ONGOSUB '+UIntToStr(labelValue));
        lexer.Advance();
      end;
    until (lexer.CurrTok() <> btkComma);
  end
  // ON .. CALL
  else if lexer.CurrTok() = btkCall then
  begin
    lexer.Advance(); //skip CALL
    i := 1; //Index
    if lexer.CurrTok() <> btkIdentifier then
    begin
      status := BasTerminated;
      SetError('Function name expected');
      Exit();
    end;
    Emmit('PUSH @0');
    Emmit('PUSHC '+IntToStr(i));
    Emmit('NE');
    Emmit('PUSH @0'); //Push register content to be passed as an argument to the function
    Emmit('PUSHC$ "'+lexer.CurrS().ToLower()+'@n"'); //Push function name
    Emmit('PUSHC 2'); //Total of parameters (always 2 in ON .. CALL)
    Emmit('ONCALLEX');
    repeat
      lexer.Advance(); //Skip the label
      if lexer.CurrTok() <> btkComma then
      begin
        Inc(i);
        if lexer.CurrTok() <> btkIdentifier then
        begin
          status := BasTerminated;
          SetError('Function name expected');
          Exit();
        end;
        Emmit('PUSH @0');
        Emmit('PUSHC '+IntToStr(i));
        Emmit('NE');
        Emmit('PUSH @0'); //Push register content to be passed as an argument to the function
        Emmit('PUSHC$ "'+lexer.CurrS().ToLower()+'@n"'); //Push function name
        Emmit('PUSHC 2'); //Total of parameters (always 2 in ON .. CALL: test value + signature)
        Emmit('ONCALLEX');
        lexer.Advance();
      end;
    until (lexer.CurrTok() <> btkComma);
  end;
end;

//-----------------------------------------------------------------------------
// TRACEON - Enable trace mode
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseTraceOn();
begin
  Emmit('TRACE 1');
  lexer.Advance();
end;

//-----------------------------------------------------------------------------
// TRACE n - Set trace level (0=off, 1=basic, 2=standard, 3=verbose)
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseTrace();
var
  level: Integer;
begin
  lexer.Advance(); //skip TRACE keyword

  //Expect an integer for the trace level
  if lexer.CurrTok() = btkInteger then
  begin
    level := Round(lexer.CurrN());
    if (level < 0) or (level > 3) then
    begin
      status := BasTerminated;
      SetError('TRACE level must be 0, 1, 2, or 3');
      Exit();
    end;
    Emmit('TRACE ' + IntToStr(level));
    lexer.Advance();
  end
  else
  begin
    status := BasTerminated;
    SetError('Integer expected for TRACE level');
    Exit();
  end;
end;

//-----------------------------------------------------------------------------
// TRACEOFF - Disable trace mode
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseTraceOff();
begin
  Emmit('TRACE 0');
  lexer.Advance();
end;

//-----------------------------------------------------------------------------
// BREAKPOINT ["message"] [, var1, var2$, var3#, ...]
// Only executes when trace mode is enabled
// Shows dialog with message and variable values
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseBreakpoint();
var
  varCount: Integer;
  varName: String;
begin
  varCount := 0;
  lexer.Advance(); //skip BREAKPOINT keyword

  //Check for optional message string
  if lexer.CurrTok() = btkString then
  begin
    //Push the message string
    Emmit('PUSHC$ "' + lexer.CurrS() + '"');
    lexer.Advance();
  end
  else
  begin
    //No message - push empty string
    Emmit('PUSHC$ ""');
  end;

  //Check for comma (variables follow)
  while lexer.CurrTok() = btkComma do
  begin
    lexer.Advance(); //skip comma

    //Expect a variable identifier
    case lexer.CurrTok() of
      btkIdentifier:
      begin
        //Numeric variable - use variable name directly
        varName := lexer.CurrS();
        //Push variable name as string constant
        Emmit('PUSHC$ "' + varName + '"');
        //Push variable value using the variable name
        Emmit('PUSH @' + varName);
        Inc(varCount);
        lexer.Advance();
      end;
      btkStrIdentifier:
      begin
        //String variable - use variable name directly
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Emmit('PUSH$ @' + varName);
        Inc(varCount);
        lexer.Advance();
      end;
      btkPointerIdentifier:
      begin
        //Pointer variable - use variable name directly
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Emmit('PUSH# @' + varName);
        Inc(varCount);
        lexer.Advance();
      end;
      else
      begin
        status := BasTerminated;
        SetError('Variable identifier expected in BREAKPOINT');
        Exit();
      end;
    end;
  end;

  //Emit BREAKPOINT instruction with variable count
  Emmit('BREAKPOINT ' + IntToStr(varCount));
end;

procedure TBasicParser.ParsePointerArrayNumGet();
var
  i: Integer;
  arrayName: String;
begin
  i := 0;
  arrayName := lexer.CurrS(); //Keeps  the variable name arr#[...] => arr#
  Emmit('PUSH# @'+arrayName);
  Inc(i);
  lexer.Advance(); //skips the '['
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekNumber then
  begin
    Status := BasTerminated;
    SetError('Numeric expression expected');
    Exit();
  end;

  NextNumericExpression();
  Inc(i);
  if lexer.CurrTok() <> btkComma then
    if lexer.CurrTok() <> btkSquareClose then
    begin
      Status := BasTerminated;
      SetError('] expected');
      Exit();
    end
    else
    begin
      Emmit('PUSHC '+IntToStr(i)); //Total of parameters
      Emmit('CALLEX "narr_get@#n"'); //Call 'narr_get'
      Exit();
    end;

  repeat
    lexer.Advance();
    NextNumericExpression();
    Inc(i);
  until lexer.CurrTok() <> btkComma;
  if lexer.CurrTok() <> btkSquareClose then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end
  else
  begin
    Emmit('PUSHC '+IntToStr(i));
    Emmit('CALLEX "narr_get@#'+System.StrUtils.DupeString('n',i-1)+'"');
    Exit();
  end;
end;

procedure TBasicParser.ParsePointerArrayPtrGet();
var
  i: Integer;
  arrayName: String;
begin
  i := 0;
  arrayName := lexer.CurrS(); //Keeps  the variable name arr##[...] => arr#
  Emmit('PUSH# @'+arrayName.Substring(0, arrayName.Length-1)); //Remove the last '#'
  Inc(i);
  lexer.Advance(); //skips the '['
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekNumber then
  begin
    Status := BasTerminated;
    SetError('Numeric expression expected');
    Exit();
  end;

  NextNumericExpression();
  Inc(i);
  if lexer.CurrTok() <> btkComma then
    if lexer.CurrTok() <> btkSquareClose then
    begin
      Status := BasTerminated;
      SetError('] expected');
      Exit();
    end
    else
    begin
      Emmit('PUSHC '+IntToStr(i)); //Total of parameters
      Emmit('CALLEX# "parr_get#@#n"'); //Call 'parr_get#'
      Exit();
    end;

  repeat
    lexer.Advance();
    NextNumericExpression();
    Inc(i);
  until lexer.CurrTok() <> btkComma;
  if lexer.CurrTok() <> btkSquareClose then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end
  else
  begin
    Emmit('PUSHC '+IntToStr(i));
    Emmit('CALLEX$ "parr_get#@#'+System.StrUtils.DupeString('n',i-1)+'"');
    Exit();
  end;
end;

procedure TBasicParser.ParsePointerArrayStrGet();
var
  i: Integer;
  arrayName: String;
begin
  i := 0;
  arrayName := lexer.CurrS(); //Keeps  the variable name arr#$[...] => arr#
  Emmit('PUSH# @'+arrayName.Substring(0, arrayName.Length-1)); //Remove the last '$'
  Inc(i);
  lexer.Advance(); //skips the '['
  if ExpressionKind(lexer.CurrTok) <> TExprKind.ekNumber then
  begin
    Status := BasTerminated;
    SetError('Numeric expression expected');
    Exit();
  end;

  NextNumericExpression();
  Inc(i);
  if lexer.CurrTok() <> btkComma then
    if lexer.CurrTok() <> btkSquareClose then
    begin
      Status := BasTerminated;
      SetError('] expected');
      Exit();
    end
    else
    begin
      Emmit('PUSHC '+IntToStr(i)); //Total of parameters
      Emmit('CALLEX$ "sarr_get$@#n"'); //Call 'sarr_get$'
      Exit();
    end;

  repeat
    lexer.Advance();
    NextNumericExpression();
    Inc(i);
  until lexer.CurrTok() <> btkComma;
  if lexer.CurrTok() <> btkSquareClose then
  begin
    Status := BasTerminated;
    SetError('] expected');
    Exit();
  end
  else
  begin
    Emmit('PUSHC '+IntToStr(i));
    Emmit('CALLEX$ "sarr_get$@#'+System.StrUtils.DupeString('n',i-1)+'"');
    Exit();
  end;
end;

procedure TBasicParser.ParsePrint();
var
  i: Integer;
  id: TBasToken;
  bool: Boolean;
begin
  i := 0;
  bool := False;
  repeat
    lexer.Advance();
    case lexer.CurrTok of
      btkCRLF, btkNull, btkColon:
      if lexer.prevtok() = btkprint then
      begin
        Emmit('PUSHC 0');
        Emmit('PRINT');
        Exit;
      end;
      btkString, btkStrIdentifier, btkCharArray, btkStrArray, btkStrFunction, btkIndirectCallStr, btkPointerArrayStr:
      begin
        NextStringExpression();
        bool := False;
      end;
      else
      begin
        NextNumericExpression();
        bool := False;
      end;
    end;

    id := lexer.CurrTok();
    if id = btkComma then
    begin
      Emmit('PUSHC$ ","');
      Inc(i);
      bool := True;
    end;
    if id = btkSemiColon then
    begin
      Emmit('PUSHC$ ";"');
      Inc(i);
      bool := True;
    end;
    Inc(i);
  until (id <> btkComma) and (id <> btkSemiColon);
  if bool then Emmit('PUSHC$ ""');
  Emmit('PUSHC ' + IntToStr(i));
  Emmit('PRINT');
end;

procedure TBasicParser.ParsePrintLn();
var
  i: Integer;
  id: TBasToken;
  bool: Boolean;
begin
  i := 0;
  bool := False;
  repeat
    lexer.Advance();
    case lexer.CurrTok of
      btkCRLF, btkNull, btkColon:
      if lexer.prevtok() = btkPrintLn then
      begin
        // Emit empty print (prints nothing)
        Emmit('PUSHC 0');
        Emmit('PRINT');
        // Emit CRLF (this is println, not print)
        Emmit('PUSHC 13');
        Emmit('PUSHC 1');
        Emmit('CALLEX$ "chr$@n"');
        Emmit('PUSHC 10');
        Emmit('PUSHC 1');
        Emmit('CALLEX$ "chr$@n"');
        Emmit('ADD$');
        Emmit('PUSHC 1');
        Emmit('PRINT');
        Exit();
      end;
      btkString, btkStrIdentifier, btkCharArray, btkStrArray, btkStrFunction, btkIndirectCallStr, btkPointerArrayStr:
      begin
        NextStringExpression();
        bool := False;
      end;
      else
      begin
        NextNumericExpression();
        bool := False;
      end;
    end;

    id := lexer.CurrTok();
    if id = btkComma then
    begin
      Emmit('PUSHC$ ","');
      Inc(i);
      bool := True;
    end;
    if id = btkSemiColon then
    begin
      Emmit('PUSHC$ ";"');
      Inc(i);
      bool := True;
    end;
    Inc(i);
  until (id <> btkComma) and (id <> btkSemiColon);
  if bool then Emmit('PUSHC$ ""');
  // PrintLn - add CRLF to the end of the command
  Emmit('PUSHC ' + IntToStr(i));
  Emmit('PRINT');
  Emmit('PUSHC 13'); // Windows end of line
  Emmit('PUSHC 1');
  Emmit('CALLEX$ "chr$@n"');
  Emmit('PUSHC 10'); // Windows end of line
  Emmit('PUSHC 1');
  Emmit('CALLEX$ "chr$@n"');
  Emmit('ADD$');
  Emmit('PUSHC 1');
  Emmit('PRINT');
end;

procedure TBasicParser.ParseRead();
var
  id: TBasToken;
begin
  lexer.Advance(); //skip READ command
  case lexer.CurrTok() of
    btkIdentifier: Emmit('READ @'+lexer.CurrS());
    btkStrIdentifier: Emmit('READ$ @'+lexer.CurrS());
    else
    begin
      status := BasTerminated;
      SetError('Invalid read identifier');
      Exit();
    end;
  end;
  lexer.Advance(); //Skip last identifier
  if lexer.CurrTok() = btkComma then
  begin
    repeat
      lexer.Advance; //Skip comma
      case lexer.CurrTok() of
        btkIdentifier: Emmit('READ @'+lexer.CurrS());
        btkStrIdentifier: Emmit('READ$ @'+lexer.CurrS());
        else
        begin
          status := BasTerminated;
          SetError('Invalid read identifier');
          Exit();
        end;
      end;
      lexer.Advance(); //skip last identifier
      id := lexer.CurrTok();
    until id <> btkComma;
  end;
end;

procedure TBasicParser.ParseRepeat();
begin
  Inc(repeatCnt);
  Emmit('REPEAT');
  lexer.Advance();
end;


//-----------------------------------------------------------------------------
// REFRESHRATE n - Set UI refresh interval in milliseconds
// 0 = refresh on every PRINT (maximum responsiveness, slower execution)
// Higher values = faster execution but less responsive UI updates
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseRefreshRate();
var
  interval: Integer;
begin
  lexer.Advance(); //skip REFRESHRATE keyword

  //Expect an integer for the refresh interval
  if lexer.CurrTok() = btkInteger then
  begin
    interval := Round(lexer.CurrN());
    if interval < 0 then
    begin
      status := BasTerminated;
      SetError('REFRESHRATE interval must be >= 0');
      Exit();
    end;
    Emmit('REFRESHRATE ' + IntToStr(interval));
    lexer.Advance();
  end
  else
  begin
    status := BasTerminated;
    SetError('Integer expected for REFRESHRATE interval');
    Exit();
  end;
end;

procedure TBasicParser.ParseRestore();
begin
  lexer.Advance();
  Emmit('RESTORE');
end;

procedure TBasicParser.ParseReturn();
begin
  lexer.Advance();
  if not inFunction then
    Emmit('RETURN')
  else
  begin
    // Check if there's a return value - functions must return a value
    if (lexer.CurrTok = btkCRLF) or (lexer.CurrTok = btkColon) then
    begin
      SetError('Return value expected');
      Exit();
    end;
    // Parse the return value expression
    case lastFunc of
      btkNumFunction: NextNumericExpression();
      btkStrFunction: NextStringExpression();
      btkPointerFunction: NextPointerExpression();
    end;
    Emmit('RETFUNCTION');
  end;
end;

procedure TBasicParser.ParseSelect();
begin
  lexer.Advance(); //skip SELECT
  if lexer.CurrTok = btkCase then
    lexer.Advance(); //skip optional CASE

  if lexer.CurrTok in [btkString, btkStrIdentifier, btkCharArray, btkStrArray, btkStrFunction] then
  begin
    selType[selectCnt] := TExprKind.ekString; //string expression
    NextStringExpression();
    Emmit('PUSHAUX$');
  end
  else if lexer.CurrTok in [btkInteger, btkFloat, btkIdentifier, btkNumFunction] then
  begin
    selType[selectCnt] := TExprKind.ekNumber; //numerical expression
    NextNumericExpression();
    Emmit('PUSHAUX');
  end
  else //Pointers cannot be used in the SELECT command for the moment
  begin
    status := BasTerminated;
    SetError('Syntax error in SELECT');
    Exit();
  end;

  if (lexer.CurrTok <> btkCRLF) and (lexer.CurrTok <> btkColon) then
  begin
    status := BasTerminated;
    SetError('Syntax error in SELECT');
    Exit();
  end;
  if (lexer.CurrTok = btkCRLF) and (lexer.NextTok = btkInteger) then
    Emmit(',    '); //Emmit the comma if it is a real new line
  lexer.Advance; //Skip the CRLF or colon
  if lexer.CurrTok() = btkInteger then
  begin
    Emmit(IntToStr(Round(lexer.CurrN)));
    lexer.Advance(); //Skip the line number
  end;
  if lexer.CurrTok() <> btkCase then
  begin
    status := BasTerminated;
    SetError('Expected a CASE');
    Exit();
  end
  else lexer.PutBack(); //Move back to the CRLF or colon

  Inc(selectCnt);
end;

procedure TBasicParser.ParseUnassignedNumFunction();
begin
  NextNumericExpression(); //numerical function call, result discarded
  Emmit('POP');
end;

procedure TBasicParser.ParseUnassignedPtrFunction();
begin
  NextPointerExpression(); //pointer function call, result discarded
  Emmit('POP');
end;

procedure TBasicParser.ParseUnassignedStrFunction();
begin
  NextStringExpression(); //string function call, result discarded
  Emmit('POP');
end;

procedure TBasicParser.ParseUntil();
var
  i: Integer;
begin
  if (repeatCnt < 1) then
  begin
    status := BasTerminated;
    SetError('Misplaced UNTIL');
    Exit();
  end;
  i := TMPOutput.Count;
  Dec(repeatCnt);
  lexer.Advance();
  NextLogicExpression();
  Emmit('UNTIL ' + IntToStr(i));
end;

//-----------------------------------------------------------------------------
// UNWATCH [var1, var2$, ...]
// Removes variables from watch list, or clears all if no variables specified
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseUnwatch();
var
  varCount: Integer;
  varName: String;
begin
  varCount := 0;
  lexer.Advance(); //skip UNWATCH keyword

  //Check if there are variables to remove, or clear all
  while lexer.CurrTok() in [btkIdentifier, btkStrIdentifier, btkPointerIdentifier] do
  begin
    case lexer.CurrTok() of
      btkIdentifier:
      begin
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Inc(varCount);
        lexer.Advance();
      end;
      btkStrIdentifier:
      begin
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Inc(varCount);
        lexer.Advance();
      end;
      btkPointerIdentifier:
      begin
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Inc(varCount);
        lexer.Advance();
      end;
    end;

    //Check for comma (more variables follow)
    if lexer.CurrTok() = btkComma then
      lexer.Advance()
    else
      Break;
  end;

  //Emit UNWATCH instruction with variable count (0 = clear all)
  Emmit('UNWATCH ' + IntToStr(varCount));
end;

//-----------------------------------------------------------------------------
// WATCH var1, var2$, var3#, ...
// Adds variables to the watch list
//-----------------------------------------------------------------------------
procedure TBasicParser.ParseWatch();
var
  varCount: Integer;
  varName: String;
begin
  varCount := 0;
  lexer.Advance(); //skip WATCH keyword

  //Parse variable list
  repeat
    case lexer.CurrTok() of
      btkIdentifier:
      begin
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Inc(varCount);
        lexer.Advance();
      end;
      btkStrIdentifier:
      begin
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Inc(varCount);
        lexer.Advance();
      end;
      btkPointerIdentifier:
      begin
        varName := lexer.CurrS();
        Emmit('PUSHC$ "' + varName + '"');
        Inc(varCount);
        lexer.Advance();
      end;
      else
      begin
        if varCount = 0 then
        begin
          status := BasTerminated;
          SetError('Variable identifier expected in WATCH');
          Exit();
        end;
        Break;
      end;
    end;

    //Check for comma (more variables follow)
    if lexer.CurrTok() = btkComma then
      lexer.Advance()
    else
      Break;
  until False;

  if varCount = 0 then
  begin
    status := BasTerminated;
    SetError('At least one variable required for WATCH');
    Exit();
  end;

  //Emit WATCH instruction with variable count
  Emmit('WATCH ' + IntToStr(varCount));
end;

procedure TBasicParser.ParseWhile();
var
  i: Integer;
begin
  Inc(whileCnt);
  i := TMPOutput.Count;
  lexer.Advance();
  NextLogicExpression();
  Emmit('WHILE ' + IntToStr(i));
end;

function TBasicParser.ProcessPostfixCode(PostFix: TStringTokens; var ASMOutput: TStringTokens; var libFuncs: TFunctionsDictionary; debug: TStrList): Integer;
var
  comp: TCompiler;
  compRes: TCompResult; //preprocessing result
  TmpFunctionsTable: TUserFunctionsDictionary;
  i: Integer;
  Key: String;
begin
  Result := 0;
  Clear;
  //Assign the postfix code to TMPOutput. During the source code compiling, this
  //would be done by the lexer using the procedure WriteLine.
  //We are skiping the source code compiling phase, by providing a postfix code
  //directly to the compiler.
  TMPOutput.Clear;
  for i := 0 to PostFix.Count-1 do
    TMPOutput.Add(PostFix[i]);

  //Initiate the compiler
  comp := TCompiler.Create();

  //Compile the intermediate code to the final assembly code
  compRes := comp.Compile(TMPOutput, libFuncs);
  if compRes <> compOk then //if it's not ok
  begin
    Result := comp.errLine;
    errLine := Result;
    lastErr := errCompStr[compRes];
  end;

  //Now, ASMOutput holds the final assembly code
  ASMOutput.Clear;
  for i := 0 to TMPOutput.Count-1 do
    ASMOutput.Add(TMPOutput[i]);

  //Reset READ index
  exec.ReadIdx := 0;

  //Update the stack machine with the informations about the DATA statements
  exec.DataStmts.Clear();
  for i := 0 to comp.DataStmts.Count-1 do
    exec.DataStmts.Add(comp.DataStmts[i]);

  //Update stack machine with the types (near/far) and entry point for all
  //functions available to the program
  exec.ProgramFunctions.Clear;
  for Key in comp.ProgramFunctions.Keys do
    exec.ProgramFunctions.Add(Key, comp.ProgramFunctions[Key]);

  //If debug list is defined, copy the final assembly instructions to it.
  if Assigned(debug) then
  begin
    debug.Clear;
    // FIX #2: Changed TMPOutput.Count to TMPOutput.Count-1.
    // Same off-by-one as in the other compilation path (see Fix #2a).
    for i := 0 to TMPOutput.Count-1 do
      debug.Add(TMPOutput[i].Str);
  end;

  //Holds the UDFs.
  //Just to remember:
  //-> function signature
  //-> function entry point
  //-> function total of parameters
  //-> function parameters values array
  TmpFunctionsTable := comp.ReturnRegisteredFunctions;
  UserFunctionsTable.Clear();
  for Key in TmpFunctionsTable.Keys do
    UserFunctionsTable.Add(Key, TmpFunctionsTable[Key]);
  FreeAndNil(comp); //Pre processing done. Free before exit.
end;

function TBasicParser.SafeRound(d: Double; imin, imax: Integer): Integer;
begin
  Result := iMin;
  if (d < iMin) or (d > iMax) then
    SetError('Parameter out of bounds')
  else
    Result := Round(d);
end;

procedure TBasicParser.SetError(err: String);
begin
  if err = '' then Dec(fError)
  else
  begin
    lastErr := err;
    Inc(fError);
  end;
  errPos := lexer.Currpos;
end;

{ TCompiler }

//Substitute BREAK commands
procedure TCompiler.AssignBreak();
var
  i, p, counter: Integer;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals only with "BREAK"
    if (postfixCode[i].Token <> atkBreak) then
      Continue;
    p := i; //p = line where the "BREAK" instruction was found
    counter := 1;
    //counter = 0: indicates end of loop
    repeat
      Inc(p);
      //A "BREAK" command makes sense only inside the "FOR", "WHILE", "REPEAT"
      //or "DO" commands.
      case postfixCode[p].Token of
        atkWhile, atkRepeat, atkDoStart, atkDoWhile, atkDoUntil: Inc(counter);
        atkEndWhile, atkUntil, atkLoopEnd, atkLoopWhile, atkLoopUntil: Dec(counter);
      end;
    until (p = (postfixCode.Count - 1)) or (counter = 0);
    postfixCode[i] := StrItem('JUMP ' + IntToStr(p + 1), atkJump);
  end;
end;

//In the postfix code, the commas are followed by the BASIC source line number
//that generates the subsequent instructions
procedure TCompiler.AssignCommas();
var
  i, line: Integer;
begin
  errLine := 0;
  line := 0;
  //scan each postfix code line
  for i := 0 to postfixCode.Count - 1 do
  begin
    if postfixCode[i].Token <> atkComma then
      Continue;
    Inc(line);
    postfixCode[i] := StrItem(', ' + IntToStr(line), atkComma);
  end;
end;

//Substitute CONTINUE commands
procedure TCompiler.AssignContinue();
var
  i, p, r, counter: Integer;
begin
  r := 0;
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals only with "CONTINUE"
    if (postfixCode[i].Token <> atkContinue) then
      Continue;
    p := i; //p = line where the "CONTINUE" instruction was found
    counter := 1;
    //counter = 0: indicates end of loop
    repeat
      Inc(p);
      //A "CONTINUE" command makes sense only inside a "FOR", "WHILE",
      //"REPEAT" or "DO" command.
      case postfixCode[p].Token of
        atkWhile, atkRepeat, atkDoStart, atkDoWhile, atkDoUntil: Inc(counter);
        atkEndWhile: //found "ENDWHILE"
        begin
          Dec(counter);
          //Store the line where the "ENDWHILE" command was found
          r := p;
        end;
        atkUntil: //found "UNTIL"
        begin
          Dec(counter); //Decrementa counter
          //"r" holds the command jump address
          r := StrToInt(asmLexer.SecondArg(postfixCode[p].Str));
        end;
        atkLoopEnd, atkLoopWhile, atkLoopUntil: //found LOOP variants
        begin
          Dec(counter);
          //For DO...LOOP, CONTINUE jumps to the LOOP instruction itself
          //so the condition (if any) gets re-evaluated
          r := p;
        end;
      end;
    until (p = postfixCode.Count - 1) or (counter = 0);
    //jumps to the instruction that originated the loop
    postfixCode[i] := StrItem('JUMP ' + IntToStr(r), atkJump);
  end;
end;

//Find the position of each data command at the source code. Feed the control
//list with the position and type of the DATA instruction and replaces it by a
//NOP instruction
procedure TCompiler.AssignData();
var
  i: Integer;
  s: String;
  DataItem: TDataItem;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    if (postfixCode[i].Token <> atkData) and (postfixCode[i].Token <> atkDataS) then
      Continue;
    //Get the value of the parameter
    s := asmLexer.SecondArg(postfixCode[i].Str);
    //Get the DATA statement index
    DataItem.DataPos := i;
    if postfixCode[i].Token = atkData then
    begin
      DataItem.DataType := 'n';
      postfixCode[i] := StrItem('NOP ' + s, atkNop);
    end;
    if postfixCode[i].Token = atkDataS then
    begin
      DataItem.DataType := '$';
      postfixCode[i] := StrItem('NOP "'+s+'"', atkNop);
    end;

    DataStmts.Add(DataItem);
  end;
end;

//Substitute functions addresses
procedure TCompiler.AssignFuncs();
var
  i: Integer;
  ftk, tk: TAsmToken;
  p: Integer;
  s: String;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    ftk := postfixCode[i].Token;
    //Deals only with function calls where functions are defined in the program
    if (ftk <> atkCallFar) and (ftk <> atkCallFarS) and (ftk <> atkCallFarP) then
      Continue;

    //ShowMessage(postfixCode[i].Str + ' : ' + GetEnumName(TypeInfo(TAsmToken), Integer(ftk)));
    asmLexer.LoadLine(PChar(postfixCode[i].Str));
    asmLexer.Advance(s, p, tk); //skip instruction
    asmLexer.Advance(s, p, tk); //skip function address
    if tk <> atkString then
    begin
      //ShowMessage(postfixCode[i].Str + ' : ' + GetEnumName(TypeInfo(TAsmToken), Integer(ftk)));
      postfixCode[i] := StrItem('ERR "Syntax error in CALL"', atkErr);
      errLine := i+1;
      Continue;
    end;

    //Try to find function address
    if ProgramFunctions.ContainsKey(s) then //if so
    begin
      //Locates function address and update current postfix code line to the
      //final call instruction.
      if not ProgramFunctions[s].FarCall then //is it a "near" function?
        // FIX #17: Use NativeInt instead of Integer for 64-bit safety.
        // On 64-bit targets, Integer truncates to 32 bits. NativeInt is
        // consistent with the pattern used in fCallNear, fIndirectCall, etc.
        postfixCode[i] := StrItem('CALL ' + IntToStr(NativeInt(@ProgramFunctions[s].Entry) + 1), atkCallNear)
      else //if not it is "far"
        case ftk of
          atkCallFar: postfixCode[i] := StrItem('CALLEX "'+s+'"', atkCallFar);
          atkCallFarS: postfixCode[i] := StrItem('CALLEX$ "'+s+'"', atkCallFarS);
          atkCallFarP: postfixCode[i] := StrItem('CALLEX# "'+s+'"', atkCallFarP);
        end;
      Continue; //Did it, go to next one.
    end;
    //If the code below is reached, the function cannot be located.
    postfixCode[i] := StrItem('ERR "There is no function with such arguments: ' +
      Copy(s, 1, Pos('@', s) - 1) + '"', atkErr);
    ErrDetail := 'There is no function with such arguments: ' + Copy(s, 1, Pos('@', s) - 1);
    errLine := i+1;
    compResult := compFunction;
    Exit;
  end;
end;

//Substitute "IF"/"ELSE IF"/"ELSE"/"ENDIF"
procedure TCompiler.AssignIf();
var
  i, j, p, counter, elsePos: integer;
  eiBodyArr, eiTestArr: TList<Integer>;
  elseFound: TList<Boolean>;
begin
  eiTestArr := TList<Integer>.Create();
  eiBodyArr := TList<Integer>.Create();
  elseFound := TList<Boolean>.Create();
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals only with "POPNJUMP_ENDIF"
    if (postfixCode.Items[i].Token <> atkPopNJump_EndIf) then
      Continue;
    elseFound.Add(false);
    p := i;
    {
      "counter" is used to control the "IF", "ELSE IF", "ELSE" and "ENDIF"
      commands.
      These commands can be nested.
      When "counter" equals to one, that's because we are at the command current
      level, for example
      a := math.abs(10)
      if a > 0 and a <= 3 then              --(counter = 1)
        print 'a entre 0 e três'
      else if a > 3 and a <= 6 then         --(counter = 1)
        print 'a entre 4 e 6'
      else if a > 6  and a <= 9 then        --(counter = 1)
        print 'a entre 6 e 9'
        b := math.abs(5)
        if b < 5 then                       --(counter = 2)
          print 'b < 5'
        else if b = 5 then                  --(counter = 2)
          print 'b = 5'
        else                                --(counter = 2)
          print 'b > 5'
        endif                               --(counter = 2)
      else if a = 10 then                   --(counter = 1)
        print 'a = 10'
      else                                  --(counter = 1)
        print 'a > 10'
      endif                                 --(counter = 1)
    }
    counter := 1;
    elsePos := -1; //"ELSE" does not exist for the moment
    repeat
      Inc(p); //next line
      //"ENDIF" descrements counter
      if postfixCode.Items[p].Token = atkEndIf then
        Dec(counter);
      //If in current command and an instruction "ELSEIFTEST" was found, add it
      //to the "eiTestArr"
      if (counter = 1) and (postfixCode.Items[p].Token = atkElseIfTest) then
      begin
        //if there's already an "ELSE" for this "IF", we have an error.
        if elseFound[Pred(elseFound.Count)] then
        begin
          FreeAndNil(eiTestArr);
          FreeAndNil(eiBodyArr);
          FreeAndNil(elseFound);
          postfixCode[p] := StrItem('ERR "Misplaced ELSE IF"', atkErr);
          compResult := compMispElseIf;
          errLine := p;
          Exit;
        end;

        eiTestArr.Add(p);
      end;
      //If in current command and an instruction "ELSEIFBODY" was found, add it
      //to the "eiBodyArr"
      if (counter = 1) and (postfixCode.Items[p].Token = atkElseIfBody) then
      begin
        //if there's already an "ELSE" for this "IF", we have an error.
        if elseFound[Pred(elseFound.Count)] then
        begin
          FreeAndNil(eiTestArr);
          FreeAndNil(eiBodyArr);
          FreeAndNil(elseFound);
          postfixCode[p] := StrItem('ERR "Misplaced ELSE IF"', atkErr);
          compResult := compMispElseIf;
          errLine := p;
          Exit;
        end;

        eiBodyArr.Add(p);
      end;
      //If in current command and an instruction "ELSE" was found, updates the
      //variable "elsePos" with its position.
      //to the "eiTestArr"
      if (counter = 1) and (postfixCode.Items[p].Token = atkElse) then
      begin
        //if there's already an "ELSE" for this "IF", we have an error.
        if elseFound[Pred(elseFound.Count)] then
        begin
          FreeAndNil(eiTestArr);
          FreeAndNil(eiBodyArr);
          FreeAndNil(elseFound);
          postfixCode[p] := StrItem('ERR "Misplaced ELSE"', atkErr);
          compResult := compMispElse;
          errLine := p;
          Exit;
        end;
        elsePos := p;
        elseFound[Pred(elseFound.Count)] := true; //"IF" has an "ELSE"
      end;

      //Found "POPNJUMP_ENDIF", we have a new "IF" command, icrements "counter"
      if postfixCode.Items[p].Token = atkPopNJump_EndIf then
        Inc(counter);
      //If "counter" equals to zero, we are not in any "IF" command, this
      //finishes the loop.
      if counter = 0 then
        Break;
    until p >= postfixCode.Count - 1;
    //if there is no balance between the lists "eiTestArr" and "eiBodyArr",
    //we have a serious error.
    //Technically, this cannot happens if the intermediate code was generated by
    //the BASIC parser and it was not externally edited.
    if (eiTestArr.Count <> eiBodyArr.Count) then
    begin
      postfixCode.Insert(0, StrItem('ERR "Unbalanced ELSEIFTEST/ELSEIFBODY"', atkErr));
      errLine := 1;
      compResult := compUnbalancedIfElse;
      Exit;
    end;
    //"ELSE IF" tests are replaced by a jump to the "ENDIF".
    //An "ELSE IF" command can only exist after an "IF" command or after another
    //"ELSE IF" command. If the instruction pointer reaches this part of the
    //postfix code, that's because the "IF" command test or the preceding
    //"ELSE IF" command test were evaluated to true.
    //In that case, it wouldn't be necessary to continue with the subsequent
    //tests.
    if eiTestArr.Count > 0 then
      for j := 0 to eiTestArr.Count-1 do
        postfixCode[eiTestArr[j]] := StrItem('JUMP '+ IntToStr(p), atkJump);
    //Each item in "eiBodyArr" must be replaced by a jump instruction to the
    //next pertinent command ("ELSE IF", "ELSE" or "ENDIF")
    if eiBodyArr.Count > 0 then
    begin
      for j := 0 to eiBodyArr.Count-1 do
        if j < eiBodyArr.Count-1 then //If we still have "ELSE IF" commands
        begin
          {jump to the next "ELSE IF"}
          postfixCode[eiBodyArr[j]] := StrItem('POPNJUMP '+IntToStr(eiTestArr[j+1]+1), atkPopNJump);
        end
        else
        begin
          if elsePos > 0 then
          begin
            //If there is an "ELSE" command, redirects to the instructions after
            //it. This occurs if no anterior "IF" or "ELSE IF" was evaluated to
            //true.
            postfixCode[eiBodyArr[j]] := StrItem('POPNJUMP ' + IntToStr(elsePos+1), atkPopNJump);
          end
          else
          begin
            //Jumps to the "ENDIF". This will occur if none of the  preceding
            //"IF" or "ELSE IF" tests were evaluated to true and there is no
            //"ELSE" command present.
            postfixCode[eiBodyArr[j]] := StrItem('POPNJUMP '+IntToStr(p), atkPopNJump);
          end;
        end;
    end;
    //If there is an "ELSE"
    if elsePos > 0 then
    begin
      //Update the line where the "ELSE" instruction is located to the jump
      //instruction to the "ENDIF" command.
      postfixCode[elsePos] := StrItem('JUMP ' + IntToStr(p), atkJump);
      p := elsePos + 1; //esta é a posição logo após o comando "else"
    end;
    if eiTestArr.Count > 0 then
    begin
      //If there is an "ELSE IF", jump to it (first one)
      postfixCode[i] := StrItem('POPNJUMP '+IntToStr(eiTestArr[0]+1), atkPopNJump);
    end
    else
      postfixCode[i] := StrItem('POPNJUMP '+IntToStr(p), atkPopNJump);
    eiTestArr.Clear;
    eiBodyArr.Clear;
  end;
  FreeAndNil(eiTestArr);
  FreeAndNil(eiBodyArr);
  FreeAndNil(elseFound);
end;

//Substitute the single line IF commands
procedure TCompiler.AssignIfCRLF();
var
  i, p: Integer;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals only with 'POPNJUMP_CRLF'
    if (postfixCode[i].Token <> atkPopNJump_CRLF) then
      Continue;
    p := i;
    repeat
      Inc(p); //Start from next line
      if postfixCode[p].Token = atkComma then
        Break;
    until p >= postfixCode.Count - 1;
    //Updates line address
    postfixCode[i] := StrItem('POPNJUMP ' + IntToStr(p), atkPopNJump);
  end;
end;

procedure TCompiler.AssignLabels();
var
  i,k,lblIndex,tokenPos: Integer;
  labels: TList<Integer>;
  asmTokenType, tokenType: TAsmToken;
  tokenStr: string;
begin
  labels := TList<Integer>.Create();

  //First pass... create list of existing labels
  for k := 0 to postfixCode.count-1 do
  begin
    if postfixCode[k].Token = atkInteger then
    begin
      asmLexer.LoadLine(pchar(postfixCode[k].Str));
      asmLexer.Advance(tokenStr, tokenPos, tokenType);
      i := StrToInt(tokenStr);
      if i > 0 then
      begin
        labels.Add(i);
        labels.add(-k);
      end;
    end;
  end;

  //Second pass... substitution
  for k := 0 to postfixCode.count-1 do
  begin
    asmTokenType := TAsmToken(postfixCode[k].Token);
    if (asmTokenType = atkJump) or (asmTokenType = atkOnGoto) or (asmTokenType = atkOnGosub) or (asmTokenType = atkCallNear) then
    begin
      tokenStr := asmLexer.SecondArg(postfixCode[k].Str);
      i := StrToInt(tokenStr);
      lblIndex := labels.IndexOf(i);
      if lblIndex < 0 then
      begin
        postfixCode[k+1] := StrItem('ERR "Label not found: ' + inttostr(k) + '"', atkErr);
        compResult := compLabel;
        errline := k+1;
      end
      else
      case asmTokenType of
        atkJump: postfixCode[k] := StrItem('JUMP ' + IntToStr(-Integer(labels[lblIndex+1])), atkJump);
        atkCallNear: postfixCode[k] := StrItem('CALL ' + IntToStr(-Integer(labels[lblIndex+1])), atkCallNear);
        atkOnGosub: postfixCode[k] := StrItem('POPNCALL ' + IntToStr(-Integer(labels[lblIndex+1])), atkPopNCall);
        atkOnGoto: postfixCode[k] := StrItem('POPNJUMP ' + IntToStr(-Integer(labels[lblIndex+1])), atkPopNJump);
      end;
    end;
  end;

  //Free labels list
  FreeAndNil(labels);
end;

//Substitute "REPEAT" commands
procedure TCompiler.AssignRepeat();
var
  i, p, counter: Integer;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals onlye eith "REPEAT"
    if (postfixCode[i].Token <> atkRepeat) then
      Continue;
    p := i; //p = line where instruction was found.
    counter := 1;
    repeat
      Inc(p); //Line after the instruction
      if postfixCode[p].Token = atkUntil then Dec(counter);
      if postfixCode[p].Token = atkRepeat then Inc(counter);
    until (p = postfixCode.Count - 1) or (counter = 0);
    //updates postfix code line
    postfixCode[p] := StrItem('POPNJUMP ' + IntToStr(i), atkPopNJump);
  end;
end;

procedure TCompiler.AssignSelect();
var
  i, j, p, counter, caseElsePos: Integer;
  caseEndArr, caseStartArr: TList<Integer>;
  function TestElsePos(position: integer): boolean;
  begin
    Result := True;
    if caseStartArr.Count = 0 then Exit;
    if caseStartArr[caseStartArr.Count - 1] >= position then
      Result := false;
  end;
begin
  caseEndArr := TList<Integer>.Create;
  caseStartArr := TList<Integer>.Create;
  for i := 0 to postfixCode.Count - 1 do
  begin
    //deals only with "PUSHAUX" ou "PUSHAUX$"
    if (postfixCode.Items[i].Token <> atkPushAux) and (postfixCode.Items[i].Token <> atkPushAuxS) then
      Continue;
    //if in here that's because we found one of the instructions above
    p := i; //save instruction line
    counter := 1;
    caseElsePos := -1;
    repeat
      Inc(p);
      //If found "POPAUX", decrements counter
      if postfixCode.Items[p].Token = atkPopAux then
        Dec(counter);
      //found "CASESTART", add its position to the "caseStartArr"
      if (counter = 1) and (postfixCode.Items[p].Token = atkCaseStart) then
        caseStartArr.Add(p);
      //found "CASEEND", add its position to the "caseEndArr"
     if (counter = 1) and (postfixCode.Items[p].Token = atkCaseEnd) then
        caseEndArr.Add(p);
      //found "CASEELSE", updates "caseElsePos" with the instruction position
      if (counter = 1) and (postfixCode.Items[p].Token = atkCaseElse) then
        caseElsePos := p;
      //if found "PUSHAUX" or "PUSHAUX$", it means we have a new SELECT command,
      //increments counter
      if (postfixCode.Items[p].Token = atkPushAux) or (postfixCode.Items[p].Token = atkPushAuxS) then
        Inc(counter);
      //if "counter" equals to zero, we are out of any SELECT command, in that
      //case it's possible to finish the loop.
      if counter = 0 then
        Break;
    until p >= postfixCode.Count - 1;
    //if there is no balance between the lists "caseStartArr" and "caseEndArr",
    //we have a serious error.
    //Technically, this cannot happens if the intermediate code was generated by
    //the BASIC parser and it was not externally edited.
    if (caseStartArr.Count <> caseEndArr.Count) then
    begin
      FreeAndNil(caseStartArr);
      FreeAndNil(caseEndArr);
      postfixCode.Insert(0, StrItem('ERR "Unbalanced CASESTART/CASEEND"', atkErr));
      errLine := 1;
      compResult := compUnbalancedCases;
      Exit;
    end;
    //"CASESTART" instructions are replaced by a jump to the "POPAUX"
    //instruction (the end of the "SELECT" command) with the exception of the
    //first one, which is replaced by a "NOp" only to make sure the first test
    //will be executed.
    //A "CASE" command can only exist after a "SELECT" command or after another
    //"CASE" command. If the instruction pointer reaches this part of the
    //postfix code, that's because it's evaluating the first "CASE" command,
    //or because the preceding "CASE" test was validated.
    //In that case, it wouldn't be necessary to continue with the subsequent
    //"CASE" tests.
    if caseStartArr.Count > 0 then
      for j := 0 to caseStartArr.Count-1 do
        if j = 0 then
        begin
          postfixCode[caseStartArr[j]] :=  StrItem(';First CASE', atkComment);
        end
        else
        begin
          postfixCode[caseStartArr[j]] := StrItem('JUMP '+ IntToStr(p),atkJump);
        end;
    //Each item in "caseEndArr" must be replaced by a jump instruction to the
    //next existing "CASE" command.
    if caseEndArr.Count > 0 then
    begin
      for j := 0 to caseEndArr.Count-1 do
        if j < caseEndArr.Count-1 then //if we still have "CASE" commands
        begin
          //jump to the next one
          postfixCode[caseEndArr[j]] := StrItem('POPNJUMP ' + IntToStr(caseStartArr[j+1]+1), atkPopNJump);
        end
        else
        begin
          if caseElsePos > 0 then
          begin
            //otherwise, if we have a "CASE ELSE" command, we just continue to
            //the code after it. This can only happens if no anterior "CASE"
            //test was validated.
            postfixCode[caseEndArr[j]] := StrItem(';End CASEs', atkComment);
          end
          else
          begin
            //or jump to "POPAUX". This will happens if none of the  "CASE"
            //tests were validated and there is no "CASE ELSE" present
            postfixCode[caseEndArr[j]] := StrItem('POPNJUMP ' + IntToStr(p), atkPopNJump);
          end;
        end;
    end;
    //If there is a "CASEELSE" instruction, it must be replaced by a "NOp"
    //instruction. The "CASEELSE" instruction is just a label to indicate the
    //beginning of the code that must be executed if all "CASE" tests have
    //failed.
    if caseElsePos > 0 then
    begin
      if not TestElsePos(caseElsePos) then
      begin
        FreeAndNil(caseStartArr);
        FreeAndNil(caseEndArr);
        postfixCode[caseElsePos] := StrItem('ERR "Misplaced CASE ELSE"', atkErr);
        errLine := caseElsePos;
        compResult := compMispCaseElse;
        Exit;
      end
      else
        postfixCode[caseElsePos] := StrItem(';Else CASE', atkComment); //CASEELSE = NOP
    end;
    caseStartArr.Clear;
    caseEndArr.Clear;
  end;
  //Returns the memory allocated at the beginning of the method.
  FreeAndNil(caseStartArr);
  FreeAndNil(caseEndArr);
end;

//Link the string token with the 'enum' code in the postfix code
procedure TCompiler.AssignTokens();
var
  i: Integer;
  tokenPos: Integer;
  tokenType: TAsmToken;
  tokenStr: String;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //read a line from the intermediate code
    asmLexer.LoadLine(PChar(postfixCode[i].Str));
    //Process the last read line
    asmLexer.Advance(tokenStr, tokenPos, tokenType);
    //Store the instruction label together with the string
    postfixCode[i] := StrItem(postfixCode[i].Str, tokenType);
  end;
end;

//Substitute "WHILE" commands
procedure TCompiler.AssignWhile();
var
  l, i, p, start, counter: Integer;
  s: String;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals only with "WHILE"
    if (postfixCode[i].Token <> atkWhile) then
      Continue;
    //"s" holds the jump address of a "WHILE" instruction
    s := asmLexer.SecondArg(postfixCode[i].Str);
    //"start" holds the address numeric representation
    start := StrToInt(s);
    p := i; //current line
    l := i; //current line
    counter := 1;
    //if "counter" equals to zero, that's because we reached the final
    //instruction of the "WHILE" block of instructions.
    //This control is necessaru because "WHILE" commands can be nested.
    repeat
      Inc(p); //next line
      if postfixCode[p].Token = atkWhile then Inc(counter);
      if postfixCode[p].Token = atkEndWhile then Dec(counter);
    until (p = postfixCode.Count - 1) or (counter = 0);
    //update line instructions
    postfixCode[l] := StrItem('POPNJUMP ' + IntToStr(p + 1), atkPopnJump);
    postfixCode[p] := StrItem('JUMP ' + IntToStr(start), atkJump);
  end;
end;

//Substitute "DO...LOOP" commands
procedure TCompiler.AssignDo();
var
  i, p, start, counter: Integer;
  s: String;
  startToken: TAsmToken;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //Deals only with DO tokens
    startToken := postfixCode[i].Token;
    if not (startToken in [atkDoStart, atkDoWhile, atkDoUntil]) then
      Continue;

    //"s" holds the jump address (start position) of a DO instruction
    s := asmLexer.SecondArg(postfixCode[i].Str);
    start := StrToInt(s);
    p := i; //current line
    counter := 1;

    //Find matching LOOP
    repeat
      Inc(p);
      case postfixCode[p].Token of
        atkDoStart, atkDoWhile, atkDoUntil: Inc(counter);
        atkLoopEnd, atkLoopWhile, atkLoopUntil: Dec(counter);
      end;
    until (p = postfixCode.Count - 1) or (counter = 0);

    //Transform DO based on variant
    case startToken of
      atkDoStart:
        //DO ... LOOP: Just a marker, becomes NOP
        postfixCode[i] := StrItem(';DO_START', atkComment);

      atkDoWhile, atkDoUntil:
        //DO WHILE/UNTIL expr ... LOOP: POPNJUMP to after LOOP
        //(NOT already emitted by parser for UNTIL)
        postfixCode[i] := StrItem('POPNJUMP ' + IntToStr(p + 1), atkPopnJump);
    end;

    //Transform LOOP based on its variant
    case postfixCode[p].Token of
      atkLoopEnd:
        //LOOP (end of pre-tested or infinite loop): jump back to start
        postfixCode[p] := StrItem('JUMP ' + IntToStr(start), atkJump);

      atkLoopWhile, atkLoopUntil:
        //LOOP WHILE/UNTIL expr: POPNJUMP back to start
        //(NOT already emitted by parser for WHILE)
        postfixCode[p] := StrItem('POPNJUMP ' + IntToStr(start), atkPopnJump);
    end;
  end;
end;

//The method below scans the intermediate code generated by the parser, and
//emits the final assembly code that can be executed by the stack machine.
//The "funcs" dictionary holds the references to the libraries included in the
//host application;
function TCompiler.Compile(source: TStringTokens; funcs: TFunctionsDictionary): TCompResult;
var
  Key: String;
begin
  compResult := compOk;
  Result := compResult;
  ProgramFunctions.Clear(); //Clean any anterior information
  for Key in funcs.Keys do
    ProgramFunctions.Add(Key, funcs[Key]);
  postfixCode := source;
  if postfixCode.Count < 2 then
  begin
    postfixCode.clear();
    postfixCode.Add(StrItem('END', atkEnd));
    Exit;
  end;
  AssignTokens();
  if compResult = compOk then AssignCommas();
  if compResult = compOk then EnumVarsFuncs();
  if compResult = compOk then AssignLabels();
  if compResult = compOk then AssignIfCRLF();
  if compResult = compOk then AssignIf();
  if compResult = compOk then AssignSelect();
  if compResult = compOk then AssignBreak();
  if compResult = compOk then AssignContinue();
  if compResult = compOk then AssignRepeat();
  if compResult = compOk then AssignWhile();
  if compResult = compOk then AssignDo();
  if compResult = compOk then AssignFuncs();
  if compResult = compOk then SkipFuncs();
  if compResult = compOk then AssignData();
  Result := compResult;
  if Result <> compOk then
    FindErrline();
end;

constructor TCompiler.Create();
//var
  //i: Integer;
begin
  ProgramFunctions := TFunctionsDictionary.Create();
  UserFunctionsTable := TUserFunctionsDictionary.Create();
  asmLexer := TAsmLexer.Create();
  DataStmts := TDataItems.Create();
  FGlobalVars := TStrList.Create();
end;

destructor TCompiler.Destroy();
begin
  if Assigned(FGlobalVars) then FreeAndNil(FGlobalVars);
  if Assigned(DataStmts) then FreeAndNil(DataStmts);
  if Assigned(asmLexer) then FreeAndNil(asmLexer);
  if Assigned(UserFunctionsTable) then FreeAndNil(UserFunctionsTable);
  if Assigned(ProgramFunctions) then FreeAndNil(ProgramFunctions);

  inherited Destroy();
end;

//Updates variables and functions addresses
procedure TCompiler.EnumVarsFuncs();
var
  localVarList: TStrList;
  i, varIndex, position, localVarCount: Integer;
  s, sInstr: String;
  tokenType: TAsmToken;
  inFunc, duplicate: Boolean;
  funcData: TFunctionData;
  FmDt: TLinkFunction;
begin
  localVarCount := 0;
  duplicate := false;
  inFunc := False;

  FGlobalVars.Add('@0'); //global register '0'
  FGlobalVars.Add('@1'); //global register '1'
  FGlobalVars.Add('@2'); //global register '2'

  //Due to the registers. The first global var will always have the index [3].
  //*******************
  //Step 1: Global vars
  //*******************
  for i := 0 to postfixCode.Count - 1 do //for each line...
  begin
    //Jump any instruction that does not use variables
    //Check for FUNCTION and ENDFUNCTION to make sure we are going to deal only
    //with global vars at this point.
    if not (postfixCode[i].Token in [atkFunction, atkEndFunction, atkPopStore, atkPopStorePtr, atkPopStoreS, atkRead, atkReadS]) then
      Continue;
    if postfixCode[i].Token = atkFunction then
      inFunc := true;
    if postfixCode[i].Token = atkEndFunction then
      inFunc := false;
    //Get the instruction parameter (var name).
    //If we are not inside a function, add it to global vars list.
    if not InFunc then
    begin
      s := asmLexer.SecondArg(postfixCode[i].Str);
      varIndex := FGlobalVars.IndexOf(s.ToLower());
      if varIndex >= 0 then
        FGlobalVars[varIndex] := s.ToLower()
      else
        FGlobalVars.Add(s.ToLower()); //add new global var to the list
    end;
  end;

  //local vars control list
  localVarList := TStrList.Create();

  //******************************************
  //Step 2: Function parameters and local vars
  //******************************************
  for i := 0 to postfixCode.Count - 1 do //Again, for each line...
  begin
    tokenType := postfixCode[i].Token;
    case tokenType of
      atkFunction: //inside a function...
      begin
        asmLexer.LoadLine(PChar(postfixCode[i].Str)); //Get line
        s := asmLexer.NextString(); //Skip the "FUNCTION" token

        //Now, we must have the function signature "name@params", store it at "s"
        s := asmLexer.NextString();

        //functions overloading are valid, but the parameters must be different
        //among the functions declarations or we will have a duplicated
        //function.
        if ProgramFunctions.ContainsKey(s) then
        begin
          FreeAndNil(localVarList);
          postfixCode[i+1] := StrItem('ERR "Function overloading must change arguments type"', atkErr);
          compResult := compDupFunction;
          errLine := i+1;
          Exit();
        end;

        //Break the signature informations in "s" to "interruptData"
        RegisterFuncData(s, funcData.funcSignature, funcData.ArgCount, funcData.ArgType);
        funcData.Entry := i+1; //Entry point

        //Register the function data in the UDF table
        UserFunctionsTable.Add(funcData.funcSignature, funcData);

        //Add the new function to the "programFunctions" list, where we store
        //the type of function (near or far) and the entry point to it in the
        //program code.
        FmDt.FarCall := false; //it's a NEAR function
        FmDt.Entry := TBindFunction(i); //Entry point in the adequate format (but it will be used as an Integer)
        ProgramFunctions.Add(s, FmDt);

        //read the next line which have the list of parameters and local
        //variables
        //
        //For example, the following function declaration
        //
        // function test(num1, num2) local a,b
        // ...
        //
        //would produce the following postfix code:
        //
        // FUNCTION test@nn
        // * 2 b a 3 4 5 num2 num1 *
        //
        //Where:
        //
        // * = initial marker
        // 2 = total of local vars
        // {b a} = the local vars
        // {3 4 5} = local registers (used internally as @3, @4 and @5)
        // {num2 num1} = function parameters
        // * = end marker
        //
        asmLexer.LoadLine(PChar(postfixCode[i+1].Str));
        s := asmLexer.NextString(); //"s" now have the initial "*"
        //localVarCount keeps the total of local vars
        localVarCount := StrToInt(asmLexer.NextString);

        repeat
          s := asmLexer.NextString(); //next token
          if s = '*' then Break; //"*" = we are at the end of the instruction
          //Check if the variable already exists in the list of local vars
          if localVarList.IndexOf('@' + s.ToLower()) >= 0 then
          begin
            duplicate := true; //Error, duplicity
            Break;
          end;
          localVarList.add('@' + s.ToLower()); //add local var to the list
          if localVarList.Count > MAXLOCALS then
          begin
            FreeAndNil(localVarList);
            postfixCode[i+1] := StrItem('ERR "Overflow of parameters and local variables in a function declaration"', atkErr);
            compResult := compFncParm;
            errLine := i+1;
            Exit();
          end
        until false;

        if duplicate then
        begin
          FreeAndNil(localVarList);
          postfixCode[i+1] := StrItem('ERR "Duplicated variable"', atkErr);
          compResult := compDupVar;
          errLine := i+1;
          Exit();
        end;
        postfixCode[i+1] := StrItem('INITFUNC '+IntToStr(localVarCount), atkInitFunc);
      end;
      atkEndFunction:
      begin
        //Clear the local vars list when finds the last "end function"
        //instruction
        localVarList.Clear();
        localVarCount := 0;
        duplicate := false;
      end;
      //All instructions that uses variables
      atkPush, atkPopStore, atkPushPtr, atkPopStorePtr, atkPushS, atkPopStoreS,
      atkForCycle, atkRead, atkReadS:
      begin
        asmLexer.LoadLine(PChar(postfixCode[i].Str));
        sInstr := asmLexer.NextString(); //Instruction
        s := asmLexer.NextString(); //var address
        //Try to find the variable address first in the local vars list.
        //If "localVarCount" is greater than zero, that's because we have a
        //function with local vars declarations. In such case, the value in
        //"position" must be less or equal to ("localVarCount" - MAXLOCALS).
        position := localVarCount-MAXLOCALS-localVarList.IndexOf(s.ToLower());
        if position > (localVarCount - MAXLOCALS) then //Global variable
        begin
          //Try find var in global list
          position := FGlobalVars.IndexOf(s.ToLower());
          if position < 0 then //not found
          begin
            FreeAndNil(localVarList);
            postfixCode[i] := StrItem('ERR "Unknown variable: ' + s + '"', atkErr);
            compResult := compVariable;
            ErrDetail := 'Unknown variable: ' + s;
            errLine := i;
            Exit;
          end;
          //Update the postfix code
          postfixCode[i] := StrItem(sInstr+' '+IntToStr(position), TAsmToken(GetEnumValue(TypeInfo(TAsmToken), sInstr)));
        end
        else
        begin
          //Update the postfix code
          postfixCode[i] := StrItem(sInstr+' '+IntToStr(position), TAsmToken(GetEnumValue(TypeInfo(TAsmToken), sInstr)));
        end;
      end;
    end;
  end;
  FreeAndNil(localVarList);
end;

procedure TCompiler.FindErrline();
var
  i, line: Integer;
begin
  line := 0;
  for i := 0 to errLine do
    if postfixCode[i].Token = atkComma then
      Inc(line);
  errLine := line;
end;

function TCompiler.RegisterFuncData(source: String; out Signature: String; out ParamCount: Word; out ParamType: array of TExprKind): Boolean;
var
  sepPos, i: Integer;
  parameters: String;
begin
  Result := False;
  //If <= 2, it's an error.
  //Minimum possible signature for a function will have 2 chars: 'f@'
  //(one char function name plus the '@' separator)
  if source.Length <= 2 then Exit;
  sepPos := source.IndexOf('@');
  if sepPos < 0 then
  begin
    Signature := '';
    ParamCount := 0;
    // FIX #1: Changed to Length(ParamType)-1. The original used Length(ParamType)
    // which writes index Length (one past the last valid index), corrupting
    // whatever memory follows ArgType in the TFunctionData record.
    for i := 0 to Length(ParamType)-1 do
      ParamType[i] := ekNumber;
    Exit; //Error. Separator '@' must be present
  end;
  //Function has no arguments, but this isn't an error
  if sepPos+1 = source.Length then
  begin
    Signature := source.ToLower(); //FN@n$# => 'fn@n$#'
    ParamCount := 0;
    for i := 0 to Length(ParamType)-1 do
      ParamType[i] := ekNumber;
    Result := True;
    Exit();
  end;
  Signature := source.ToLower(); //fn@n$# => 'fn@n$#'
  parameters := source.Substring(sepPos+1);
  ParamCount := parameters.Length;
  for i := 0 to ParamCount-1 do
    case parameters.Chars[i] of
      '#': ParamType[i] := ekPointer;
      '$': ParamType[i] := ekString;
      'n': ParamType[i] := ekNumber;
    end;
  Result := True;
end;

function TCompiler.ReturnRegisteredFunctions(): TUserFunctionsDictionary;
begin
  Result := UserFunctionsTable;
end;

//Make sure the code inside functions is executed only during a function call.
procedure TCompiler.SkipFuncs();
var
  i, p: Integer;
begin
  for i := 0 to postfixCode.Count - 1 do
  begin
    //If it isn't a function declaration, proceed to next instruction.
    if postfixCode[i].Token <> atkFunction then
      Continue;
    //Ok, we have a function
    p := i; //p = current instruction index
    repeat
      Inc(p); //next instruction
      //If it is an "ENDFUNCTION" instruction, decrement "nestedFnc. If it is
      //zero, we are at the end of the most outer function, exit.
      if postfixCode[p].Token = atkEndFunction then Break;
    until p >= postfixCode.Count - 1;
    //Every function declaration is preceded by a jump straight to the
    //instruction just after the function body.
    //This is necessary to make sure the function body is executed only during a
    //function call, which sets the index PRG_IP to the address relative to the
    //function entry point.
    //This technique allows functions to be declared anywere in the source code,
    //except inside loops or inside other functions.
    postfixCode[i] := StrItem('JUMP '+IntToStr(p), atkJump);
  end;
end;

function TCompiler.StrItem(str: String; value: TAsmToken): TStringToken;
begin
  Result.Str := str;
  Result.Token := value;
end;

end.

