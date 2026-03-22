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
unit exec;

interface

uses
  System.Classes, System.SysUtils, System.Character, System.Generics.Collections,
  System.TypInfo, System.Math, System.Diagnostics, System.UITypes, System.SyncObjs,

  FMX.Types, FMX.Platform, FMX.Controls, FMX.Forms, FMX.Graphics,

  FMX.Dialogs, FMX.DialogService, FMX.DialogService.Async,

  UnitUtils, lexer, UnitGC;

const
  // Stack and memory limits
  MAXSTACK = 16384;   // Maximum stack items (both main and auxiliary)
  MAXLOCALS = 259;    // (256 args && locals) + 3 local registers (@3 @4 @5)
  MAXVARS = 515;      // 512 global vars + 3 generic registers (@0 @1 @2)
  INITASMSIZE = 1000; // Asm program initial allocation size

  // Default execution timeout in seconds (0 = no timeout)
  DEFAULT_TIMEOUT = 30;

  // Numeric limits for integer type
  MAX_INTEGER_VALUE = 2147483647.0;  // Values above this become float

  // UI refresh throttling for PRINT statements (in milliseconds)
  // Lower = more responsive but slower execution
  // Higher = faster execution but less responsive UI
  // 0 = refresh on every PRINT (original behavior)
  DEFAULT_UI_REFRESH_INTERVAL = 50;

type
  //Assembly tokens
  TAsmToken = (
    {A}
    atkAdd, atkAddCRLFS, atkAddS, atkAnd, atkAssert,
    {B}
    atkBreak, atkBreakpoint, atkCRLF, atkCallFar, atkCallFarP, atkCallFarS, atkCallNear,
    atkCls, atkComma, atkComment, atkContinue,
    {C}
    atkCaseEnd, atkCaseElse, atkCaseStart,
    {D}
    atkData, atkDataS, atkDiv, atkDoStart, atkDoUntil, atkDoWhile, atkDump,
    {E}
    atkElse, atkElseIfBody, atkElseIfTest, atkEnd, atkEndFunction, atkEndIf,
    atkEndWhile, atkEq, atkEqs, atkErr, atkExit,
    {F}
    atkFloat, {atkFnAddress,} atkForCycle, atkFunction,
    {G}
    atkGe, atkGeS, atkGt, atkGtS,
    {H}
    {I}
    atkIdentifier, atkIf, atkIndirectCall, atkInitFunc, atkInput, atkInputS,
    atkInteger, atkInv,
    {J}
    atkJsonObj, atkJump,
    {K}
    {L}
    atkLabel, atkLe, atkLeS, atkLoopEnd, atkLoopUntil, atkLoopWhile, atkLt, atkLtS,
    {M}
    atkMax, atkMin, atkMod, atkMul,
    {N}
    atkNe, atkNeS, atkNext, atkNone, atkNop, atkNot, atkNull,
    {O}
    atkOnCallFar, atkOnCallFarP, atkOnCallFarS, atkOnGoto, atkOnGosub, atkOr,
    {P}
    atkPause, atkPointerFunction, atkPointerIdentifier, atkPop, atkPopAux,
    atkPopStore, atkPopStorePtr, atkPopStoreS, atkPopnCall, atkPopnJump, atkPopnJump_CRLF,
    atkPopnJump_EndIf, atkPow, atkPrint, atkPush, atkPushAux, atkPushAuxS, atkPushAuxTOS,
    atkPushC, atkPushCS, atkPushPtr, atkPushPtrTag, atkPushS,
    {Q}
    {R}
    atkRead, atkReadS, atkRefreshRate, atkRepeat, atkRetFunction, atkReturn, atkRestore,
    {S}
    atkStrIdentifier, atkString, atkSub, atkSubS, atkSymbol,
    {T}
    atkTo, atkTrace, atkTraceOff, atkTraceOn,
    {U}
    atkUnknown, atkUntil, atkUnwatch,
    {V}
    {W}
    atkWatch, atkWhile
    {X}
    {Y}
    {Z}
  );

  //TAsmDataType = (dtNum, dtPtr, dtStr);
  TAsmData = record //Data cell format
    n: Extended;
    p: Pointer;
    s: String;
  end;

  //Type for functions that will be integrated into the basic engine
  TBindFunction = function(var Args: Array of TAsmData): TAsmData;
  TLinkFunction = record //Functions call type and entry point
    FarCall: Boolean; //True: imported from Delphi / False: user defined
    Entry: TBindFunction; //Function header if imported
  end;
  //The function signature is the dictionary index
  TFunctionsDictionary = TDictionary<String, TLinkFunction>;

  //Function type
  TExeFunc = procedure of object;
  //PRINT function type
  TPrintProc = procedure(p: PChar) of object;
  //BASIC tokenized instructions
  TBasInstr = record
    id: TBasToken; //Token type
    pos, len: Integer; //position, length
    n: Extended; //Numeric constant value
  end;
  TBasArray = array of TBasInstr;

  //Assembly tokenized instructions
  TInstr = record
    proc: TExeFunc; //Delphi function associated to the ASM instruction
    token: TAsmToken; //The token identification
    i: Integer; //string offset, variable index
    n: Extended; //Numeric constant value
  end;
  TInstrArray = array of TInstr;

  //Type used by the DATA/READ statements
  TDataItem = record
    DataType: AnsiChar; //String '$' or numeric 'n'
    DataPos: Integer; //Position at the code
  end;
  TDataItems = TList<TDataItem>;

  //Token identification
  TStringToken = record
    Str: String; //Textual representation of the token
    Token: TAsmToken; //Token 'id'
  end;
  TStringTokens = TList<TStringToken>;

  //Types of expresion
  TExprKind = (ekNumber, ekPointer, ekString);

  //Stack machine execution status
  TExecStatus = (esRun, esIdle);

  //Runtime errors
  TRTErrors = (
    rteStackOverflow, rteStackUnderflow, rteStackTypeMismatch, rteInvalidParams,
    rteDimIndexBound, rtePrintStackOverflow, rtePrintSyntaxMismatch,
    rteAuxStackTypeMismatch, rteAuxStackOverflow, rteAuxStackUnderflow,
    rteDivisionByZero, rteStringSize, rteUnknownInstr, rteUserMessage
  );

  TStrList = TList<String>; //Type for a list of strings

  //*********
  //TAsmLexer
  //*********
  //
  //Intermediate code lexer.
  //Used by the compiler and stack machine to tokenize postfix code.
  //
  TAsmLexer = class(TObject)
  private
    pSource: PChar;
    idx: Integer;
    //Identify assembly instructions
    function AsmIdentKind(orig: TAsmToken; tokstr: String): TAsmToken;
    //Postfix tokenizer
    procedure AsmGetToken(var tokenstr: String; var tokenPos: Integer; var tok: TAsmToken);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadLine(p: PChar);
    //Get the second argument of an instruction
    function SecondArg(s: String): String;
    //get the String representation of the next token
    function NextString(): String;
    //Advance to the next token. After execution "data" holds the token string
    //representation, "tokenPos" holds the token start position, "tok" holds the
    //token label.
    procedure Advance(var data: String; var tokenPos: Integer; var tok: TAsmToken);
  end;

  //TExec
  //*****
  //
  // Stack machine for the final assembly code
  //
  TExec = class
  private
    PRG_IP, //current instruction index
    STKP, //top of stack
    BASEP: Integer; //functions and jumps control
    AuxStackIdx: Integer; //SELECT CASE top of stack
    //Keeps the last error message
    FErrorMessage: String;
    //Keeps the relationship between the Asm instructions and the BASIC source
    //code lines responsible for its generation.
    srcLine: Integer;
    FPrintProc: TPrintProc;
    strConst: String;
    sourceAlloc, ended: Boolean;
    asmLexer: TAsmLexer;
    asmProg: TInstrArray; //List of Asm code to exec
    FTotInsts: Integer; //Total of Asm instructions
    FCallbackProc: TNotifyEvent;
    FCallbackObj: TObject;
    FTimeOut: Int64; //Exec timeout
    ExecStatus: TExecStatus;
    FTraceLevel: Integer; //Debug trace level (0=off, 1=basic, 2=standard, 3=verbose)
    FWatchList: TStringList; //List of variables to watch during trace
    FCurrentFunction: String; //Name of current function being executed
    FGlobalVarNames: TStrList; //Variable names list (for WATCH value lookup)
    //UI refresh throttling for PRINT statements
    FUIRefreshInterval: Integer; //Minimum ms between UI refreshes (0=every print)
    FLastUIRefresh: Cardinal; //Tick count of last UI refresh
    //FTraceEnabled: Boolean; //Debug trace mode flag
    //--------------------------------------------------------------------------
    //Data comes from TCompiler
    //--------------------------------------------------------------------------
    HeapMem: array [0 .. MAXVARS] of TAsmData; //Global data area
    StackMem: array [0 .. MAXSTACK] of TAsmData; //Local vars stack
    TypeStack: array [0 .. MAXSTACK] of TExprKind; //Local vars types
    AuxStack: array[0 .. MAXSTACK] of TAsmData; //Auxiliary stack
    AuxStackTypes: array [0 .. MAXSTACK] of TExprKind; //Auxiliary stack types
    //auxiliary functions
    procedure PushAsmData(const dt: TAsmData; st: TExprKind);
    function PopAsmData(checkType: TExprKind): TAsmData;
    procedure Pop();
    function TokenToFunc(tk: TAsmToken): TExeFunc;
    function ICallReturnType(signature: String): String;
    function ICallGetParams(signature: String): String;
    //Stack machine assembly instructions
    procedure fPop(); //decrease top of stack.
    procedure fPush(); //push numeric variable content
    procedure fPushPtr(); //push pointer variable content
    procedure fPushPtrTag(); //Push pointer TAG constant
    procedure fPushC(); //push(n)
    procedure fPushS(); //push string variable content
    procedure fPushSC(); //push(s)
    procedure fAdd(); //pop(n1), pop(n2), push(n1+n2)
    procedure fSub(); //pop(n1), pop(n2), push(n1-n2)
    procedure fMul(); //pop(n1), pop(n2), push(n1*n2)
    procedure fDiv(); //pop(n1), pop(n2), push(n1/n2)
    procedure fMod(); //pop(n1), pop(n2), push(n1%n2)
    procedure fInv(); //pop(n1), push(inv(n1))
    procedure fMin(); //pop(n1), pop(n2), (n1<n2)?push(n1):push(n2)
    procedure fMax(); //pop(n1), pop(n2), (n1>n2)?push(n1):push(n2)
    procedure fPow(); //pop(n1), pop(n2), push(n1^n2)
    procedure fNot(); //pop(n1), (n1==0)?push(1):push(0)
    procedure fGE(); //pop(n1), pop(n2), (n1>=n2)?push(1):push(0)
    procedure fGT(); //pop(n1), pop(n2), (n1>n2)?push(1):push(0)
    procedure fLE(); //pop(n1), pop(n2), (n1<=n2)?push(1):push(0)
    procedure fLT(); //pop(n1), pop(n2), (n1<n2)?push(1):push(0)
    procedure fNE(); //pop(n1), pop(n2), (n1!=n2)?push(1):push(0)
    procedure fEQ(); //pop(n1), pop(n2), (n1==n2)?push(1):push(0)
    procedure fGES(); //pop(s1), pop(s2), (s1>=s2)?push(1):push(0)
    procedure fGTS(); //pop(s1), pop(s2), (s1>s2)?push(1):push(0)
    procedure fLES(); //pop(s1), pop(s2), (s1<=s2)?push(1):push(0)
    procedure fLTS(); //pop(s1), pop(s2), (s1<s2)?push(1):push(0)
    procedure fNES(); //pop(s1), pop(s2), (s1!=s2)?push(1):push(0)
    procedure fEQS(); //pop(s1), pop(s2), (s1==s2)?push(1):push(0)
    procedure fAddS(); //pop(s1), pop(s2), push(s1+s2)
    procedure fSubS(); //pop(n1), pop(s1), push(s1[0,length(s1)-n1])
    procedure fAddCRLFS(); //pop(s1), pop(s2), push(s1+'/n'+s2)
    procedure fRead();
    procedure fReadS();
    procedure fRefreshRate(); //Set UI refresh interval
    procedure fRestore();
    procedure fInput();
    procedure fInputS();
    procedure fForCycle();
    procedure fPopStore(); //pop(n)
    procedure fPopStoreS(); //pop(s)
    procedure fPopStorePtr(); //pop(p)
    procedure fCallNear(); //push(p)
    procedure fCallFar(); //pop(n), push(n)
    procedure fCallFarS(); //pop(n), push(s)
    procedure fCallFarP(); //pop(n), push(p)
    procedure fOnCallFar(); //pop(n), pop(n), pop(s), push(n)
    procedure fOnCallFarS(); //pop(n), pop(s), pop(s), push(s)
    procedure fOnCallFarP(); //pop(n), pop(p), pop(s), push(p)
    procedure fJump();
    procedure fPopNCall();
    procedure fPopNJump();
    procedure fReturn(); //pop(p)
    procedure fInitFunc(); //push(p)
    procedure fRetFunction(); //pop(p), pop(p), pop(n)
    procedure fNOp();
    procedure fEnd();
    procedure fCls();
    procedure fPrint(); //pop(?)[,pop(?)]*
    procedure fErr();
    procedure fComma();
    //procedure fFnAddr; //pop(s), push(n)
    procedure fIndirectCall();
    procedure fPushAuxStack();
    procedure fPushAuxStackS();
    procedure fPopAuxStack();
    procedure fPushAuxTOS();
    //Debug instructions
    procedure fAssert();      //assert condition with message
    procedure fBreakpoint();  //breakpoint (only when trace enabled)
    procedure fDump();        //dump all global variables
    procedure fTrace();       //set trace level
    procedure fTraceOn();     //enable trace mode (legacy)
    procedure fTraceOff();    //disable trace mode (legacy)
    procedure fWatch();       //add variables to watch list
    procedure fUnwatch();     //remove variables from watch list
    //Debug helper functions
    function GetTraceEnabled(): Boolean;
    function GetVariableValue(const varName: String): String;
    function GetWatchedVariablesInfo(): String;
  public
    //Entry point for every function available to the running program.
    ProgramFunctions: TFunctionsDictionary;
    //--------------------------------------------------------------------------
    DataStmts: TDataItems; //DATA statements type and position
    ReadIdx: Integer; //READ statement index
    //--------------------------------------------------------------------------
    TagObject: Pointer;

    constructor Create();
    destructor Destroy(); override;
    procedure Clear();
    procedure LoadSource(ls: TStringTokens);
    procedure ExecuteFunction(
      Entry: Integer; //function entry point
      ParamCount: Integer; //total arguments
      ParamType: Array of TExprKind; //arguments type
      Params: Array of TAsmData; //parameters value
      RetType: TExprKind; //function return type
      out RetValue: TAsmData //function return value
    );
    //execute from the beginning
    procedure ExecuteProgram();
    //Get global var contents
    function GetGlobalNum(const Index: Integer): Extended;
    function GetGlobalPtr(const Index: Integer): Pointer;
    function GetGlobalStr(const Index: Integer): String;
    //Runtime error
    procedure RTError(msg: TRTErrors; unkInstr: TAsmToken; auxMsg: String='');
    procedure Stop(); //Immediately stops the VM

    property ErrorMessage: String read FErrorMessage;
    property TotalASMInst: Integer Read FTotInsts;
    property IP: Integer read PRG_IP;
    property SourceLine: Integer read srcLine;
    property PrintProc: TPrintProc read FPrintProc write FPrintProc;
    property CallbackProc: TNotifyEvent read FCallbackProc write FCallbackProc;
    property CallbackObj: TObject read FCallbackObj write FCallbackObj;
    property TimeOut: Int64 read FTimeOut write FTimeOut;
    property TraceLevel: Integer read FTraceLevel write FTraceLevel;
    property TraceEnabled: Boolean read GetTraceEnabled; //Legacy - returns TraceLevel > 0
    property WatchList: TStringList read FWatchList;
    property GlobalVarNames: TList<String> read FGlobalVarNames write FGlobalVarNames;
    property UIRefreshInterval: Integer read FUIRefreshInterval write FUIRefreshInterval;
  end;

implementation

uses
  TimerLib;  //For PauseAllTimers/ResumeAllTimers in breakpoint handling

{ TAsmLexer }

procedure TAsmLexer.Advance(var data: String; var tokenPos: Integer; var tok: TAsmToken);
begin
  AsmGetToken(data, tokenPos, tok);
end;

procedure TAsmLexer.AsmGetToken(var tokenstr: String; var tokenPos: Integer; var tok: TAsmToken);
var
  d: Double;
  ok: Boolean;
  ch: Char;
  isEscaped: Boolean;
begin
  ch := pSource[idx];
  while ch.IsInArray([#8, #9, #32]) do //skip blanks
  begin
    Inc(idx);
    ch := pSource[idx];
  end;
  tokenPos := idx;
  case pSource[idx] of
    ';': //comment
    begin
      tokenPos := idx;
      {$IFDEF ANDROID}
      while (pSource[idx] <> System.sLineBreak) do
      {$ENDIF}
      {$IFDEF MSWINDOWS}
      while (pSource[idx] <> #0) do
      {$ENDIF}
        Inc(idx);
      SetString(tokenStr, pSource + tokenPos, idx - tokenPos);
      tok := atkComment;
    end;
    'A' .. 'Z', 'a' .. 'z', '_', '@': //identifier
    begin
      tokenPos := idx;
      Inc(idx);
      Ch := pSource[idx];
      while Ch.IsInArray(['A','B','C','D','E','F','G','H','I','J','K','L','M',
                          'N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
                          'a','b','c','d','e','f','g','h','i','j','k','l','m',
                          'n','o','p','q','r','s','t','u','v','w','x','y','z',
                          '0','1','2','3','4','5','6','7','8','9',
                          '_','$','#','@','.']) do
      begin
        Inc(idx);
        Ch := pSource[idx];
      end;
      setstring(tokenStr, pSource + tokenPos, idx - tokenPos);
      tok := atkIdentifier;
      case pSource[idx - 1] of
        '$': tok := atkStrIdentifier;
        '#': tok := atkPointerIdentifier;
      end;
      tok := AsmIdentKind(tok, tokenStr)
    end;
    '-', '0' .. '9', '.': //number
    begin
      tokenPos := idx;
      Inc(idx);
      tok := atkInteger;
      Ch := pSource[idx];
      while Ch.IsInArray(['0','1','2','3','4','5','6','7','8','9','.','e','E']) do
      begin
        case pSource[idx] of
          '.': tok := atkFloat;
          'e', 'E':
          begin
            Inc(idx);
            Ch := pSource[idx];
            tok := atkFloat;
          end;
        end;
        Inc(idx);
        Ch := pSource[idx];
      end;
      SetString(tokenStr, pSource + tokenPos, idx - tokenPos);
      if pSource[tokenPos] = '.' then
      begin
        tok := atkFloat;
        tokenStr := '0' + tokenStr;
      end;
      d := TUtils.StrToFloat2(tokenStr, ok);
      if not ok then tok := atkUnknown;
      if d > MAX_INTEGER_VALUE then tok := atkFloat;
      if pSource[idx] = '#' then Inc(idx);
    end;
    #10: //CRLF
    begin
      tok := atkCRLF;
      tokenStr := System.sLineBreak;
      tokenPos := idx;
      Inc(idx);
    end;
    #13: //CRLF
    begin
      tok := atkCRLF;
      tokenStr := System.sLineBreak;
      tokenPos := idx;
      Inc(idx);
      if pSource[idx] = Char(#10) then
        Inc(idx);
    end;
    '%', '/', '&', '('..',', ':', '<'..'?', '['..'^', '{'..'~': //operator
    begin
      tokenPos := idx;
      tok := atkSymbol;
      if pSource[idx] = ',' then tok := atkComma;
      Inc(idx);
      SetString(tokenStr, pSource + tokenPos, idx - tokenPos);
    end;
    '"': //It's a string constant
    begin
      tok := atkString;
      tokenStr := '';
      isEscaped := False;
      repeat
        case pSource[idx] of
          #0, #10, #13:
          begin
            Dec(idx);
            tok := atkUnknown;
            Break;
          end;
          '\':
          begin
            if isEscaped then
            begin
              tokenStr := tokenStr + '\';
              isEscaped := False;
            end
            else
              isEscaped := True;
          end;
          else
          begin
            if isEscaped then
            begin
              case pSource[idx] of
                '"': tokenStr := tokenStr + '"';   // \"  -> "
                '\': tokenStr := tokenStr + '\';   // \\  -> \
                'n': tokenStr := tokenStr + #10;   // \n  -> newline (LF)
                'r': tokenStr := tokenStr + #13;   // \r  -> carriage return (CR)
                't': tokenStr := tokenStr + #9;    // \t  -> horizontal tab
                '0': tokenStr := tokenStr + #0;    // \0  -> null character
                'b': tokenStr := tokenStr + #8;    // \b  -> backspace
                'f': tokenStr := tokenStr + #12;   // \f  -> form feed
                'v': tokenStr := tokenStr + #11;   // \v  -> vertical tab
                'a': tokenStr := tokenStr + #7;    // \a  -> alert/bell
                else tokenStr := tokenStr + '\' + pSource[idx]; // Invalid sequence
              end;
              isEscaped := False;
            end
            else if pSource[idx] <> '"' then
              tokenStr := tokenStr + pSource[idx];
          end;
        end;
        Inc(idx);
      until (not isEscaped) and (pSource[idx] = '"');
      Inc(idx);
      tokenPos := tokenPos + 1;
    end;
    #0:
    begin
      tok := atkNull;
      tokenStr := '';
      tokenPos := idx;
    end;
    else
    begin
      tokenPos := idx;
      Inc(idx);
      tok := atkUnknown;
      SetString(tokenStr, pSource + tokenPos, idx - tokenPos);
    end;
  end;
end;

function TAsmLexer.AsmIdentKind(orig: TAsmToken; tokstr: String): TAsmToken;
var
  code: Integer;
begin
  result := orig;
  tokstr := UpperCase(tokstr);
  code := TUtils.StringCode(tokstr);
  if (code < 140) or (code > 1086) then
    Exit();
  case code of
    140: if tokStr = 'GE' then Result := atkGe;
    145: if tokStr = 'LE' then Result := atkLe;
    147: if tokStr = 'NE' then Result := atkNe;
    150: if tokStr = 'EQ' then Result := atkEq;
    155: if tokStr = 'GT' then Result := atkGt;
    160: if tokStr = 'LT' then Result := atkLt;
    161: if tokStr = 'OR' then Result := atkOr;
    176: if tokStr = 'GE$' then Result := atkGeS;
    181: if tokStr = 'LE$' then Result := atkLeS;
    183: if tokStr = 'NE$' then Result := atkNeS;
    186: if tokStr = 'EQ$' then Result := atkEqS;
    191: if tokStr = 'GT$' then Result := atkGtS;
    196: if tokStr = 'LT$' then Result := atkLtS;
    201: if tokStr = 'ADD' then Result := atkAdd;
    211: if tokStr = 'AND' then Result := atkAnd;
    215: if tokStr = 'END' then Result := atkEnd;
    224: if tokStr = 'MOD' then Result := atkMod;
    226: if tokStr = 'CLS' then Result := atkCls;
    227: if tokStr = 'DIV' then Result := atkDiv;
    228: if tokStr = 'MIN' then Result := atkMin;
    230: if tokStr = 'MAX' then Result := atkMax;
    233: if tokStr = 'ERR' then Result := atkErr;
    234: if tokStr = 'SUB' then Result := atkSub;
    237:
    begin
      if tokStr = 'INV' then Result := atkInv
      else if tokStr = 'NOP' then Result := atkNop
      else if tokStr = 'ADD$' then Result := atkAddS;
    end;
    238: if tokStr = 'MUL' then Result := atkMul;
    239: if tokStr = 'POP' then Result := atkPop;
    241: if tokStr = 'NOT' then Result := atkNot;
    246: if tokStr = 'POW' then Result := atkPow;
    270: if tokStr = 'SUB$' then Result := atkSubS;
    282: if tokStr = 'DATA' then Result := atkData;
    //283: if tokStr = 'ADDR' then Result := atkFnAddress;
    284:
    begin
      if tokStr = 'CALL' then Result := atkCallNear
      else if tokStr = 'READ' then Result := atkRead;
    end;
    297: if tokStr = 'ELSE' then Result := atkElse;
    310: if tokStr = 'DUMP' then Result := atkDump;
    314: if tokStr = 'EXIT' then Result := atkExit;
    316: if tokStr = 'JUMP' then Result := atkJump;
    318: if tokStr = 'DATA$' then Result := atkDataS;
    319: if tokStr = 'NEXT' then Result := atkNext;
    320:
    begin
      if tokStr = 'PUSH' then Result := atkPush
      else if tokStr = 'READ$' then Result := atkReadS;
    end;
    355: if tokStr = 'PUSH#' then Result := atkPushPtr;
    356: if tokStr = 'PUSH$' then Result := atkPushS;
    357: if tokStr = 'BREAK' then Result := atkBreak;
    358: if tokStr = 'ENDIF' then Result := atkEndIf;
    367: if tokStr = 'TRACE' then Result := atkTrace;
    375: if tokStr = 'WATCH' then Result := atkWatch;
    377: if tokStr = 'WHILE' then Result := atkWhile;
    382: if tokStr = 'PAUSE' then Result := atkPause;
    387: if tokStr = 'PUSHC' then Result := atkPushC;
    396: if tokStr = 'UNTIL' then Result := atkUntil;
    397: if tokStr = 'PRINT' then Result := atkPrint;
    400: if tokStr = 'INPUT' then Result := atkInput;
    423: if tokStr = 'PUSHC$' then Result := atkPushCS;
    436: if tokStr = 'INPUT$' then Result := atkInputS;
    441: if tokStr = 'CALLEX' then Result := atkCallFar;
    449: if tokStr = 'REPEAT' then Result := atkRepeat;
    452: if tokStr = 'I_CALL' then Result := atkIndirectCall;
    466: if tokStr = 'ASSERT' then Result := atkAssert;
    470: if tokStr = 'ONGOTO' then Result := atkOnGoto;
    476: if tokStr = 'CALLEX#' then Result := atkCallFarP;
    477:
    begin
      if tokStr = 'CALLEX$' then Result := atkCallFarS
      else if tokStr = 'POPAUX' then Result := atkPopAux;
    end;
    480: if tokStr = 'RETURN' then Result := atkReturn;
    499: if tokStr = 'CASEEND' then Result := atkCaseEnd;
    524: if tokStr = 'TRACEON' then Result := atkTraceOn;
    532: if tokStr = 'ADDCRLF$' then Result := atkAddCRLFS;
    538: if tokStr = 'UNWATCH' then Result := atkUnwatch;
    541: if tokStr = 'ONGOSUB' then Result := atkOnGosub;
    548: if tokStr = 'RESTORE' then Result := atkRestore;
    558: if tokStr = 'PUSHAUX' then Result := atkPushAux;
    581: if tokStr = 'CASEELSE' then Result := atkCaseElse;
    586: if tokStr = 'TRACEOFF' then Result := atkTraceOff;
    592: if tokStr = 'ENDWHILE' then Result := atkEndWhile;
    594: if tokStr = 'PUSHAUX$' then Result := atkPushAuxS;
    598: if tokStr = 'ONCALLEX' then Result := atkOnCallFar;
    599: if tokStr = 'FORCYCLE' then Result := atkForCycle;
    601: if tokStr = 'POPNCALL' then Result := atkPopnCall;
    608: if tokStr = 'INITFUNC' then Result := atkInitFunc;
    613: if tokStr = 'CONTINUE' then Result := atkContinue;
    614: if tokStr = 'FUNCTION' then Result := atkFunction;
    619: if tokStr = 'DO_WHILE' then Result := atkDoWhile;
    624: if tokStr = 'LOOP_END' then Result := atkLoopEnd;
    633: if tokStr = 'POPNJUMP' then Result := atkPopNJump;
    636: if tokStr = 'POPSTORE' then Result := atkPopStore;
    638: if tokStr = 'DO_UNTIL' then Result := atkDoUntil;
    640: if tokStr = 'DO_START' then Result := atkDoStart;
    670: if tokStr = 'PUSH#_TAG' then Result := atkPushPtrTag;
    671: if tokStr = 'POPSTORE#' then Result := atkPopStorePtr;
    672: if tokStr = 'POPSTORE$' then Result := atkPopStoreS;
    682: if tokStr = 'CASESTART' then Result := atkCaseStart;
    742: if tokStr = 'ELSEIFBODY' then Result := atkElseIfBody;
    751: if tokStr = 'BREAKPOINT' then Result := atkBreakpoint;
    760: if tokStr = 'ELSEIFTEST' then Result := atkElseIfTest;
    786: if tokStr = 'LOOP_WHILE' then Result := atkLoopWhile;
    804: if tokStr = 'PUSHAUXTOS' then Result := atkPushAuxTOS;
    805: if tokStr = 'LOOP_UNTIL' then Result := atkLoopUntil;
    827: if tokStr = 'REFRESHRATE' then Result := atkRefreshRate;
    829: if tokStr = 'ENDFUNCTION' then Result := atkEndfunction;
    849: if tokStr = 'RETFUNCTION' then Result := atkRetFunction;
    1023: if tokStr = 'POPNJUMP_CRLF' then Result := atkPopNJump_CRLF;
    1086: if tokStr = 'POPNJUMP_ENDIF' then Result := atkPopNJump_EndIf;
  end;
end;

constructor TAsmLexer.Create();
begin
  inherited Create();
end;

destructor TAsmLexer.Destroy();
begin
  inherited Destroy();
end;

procedure TAsmLexer.LoadLine(p: PChar);
begin
  pSource := p;
  idx := 0;
end;

function TAsmLexer.NextString(): String;
var
  p: Integer;
  tk: TAsmToken;
begin
  Result := '';
  Advance(Result, p, tk);
end;

function TAsmLexer.SecondArg(s: String): String;
var
  p: Integer;
  tk: TAsmToken;
begin
  LoadLine(PChar(s));
  Advance(result, p, tk);
  Advance(result, p, tk);
end;

{ TExec }

procedure TExec.Clear();
var
  i: Integer;
begin
  // FIX #6: Changed MAXVARS-1 to MAXVARS to clear ALL elements.
  // HeapMem is array[0..MAXVARS] (indices 0..515). The loop previously
  // skipped index 515. A program with 513+ globals would see stale data
  // in the last variable slot after re-running.
  for i := 0 to MAXVARS do
  begin
    HeapMem[i].n := 0; // Classic BASIC: uninitialized numbers default to 0
    HeapMem[i].p := nil;
    HeapMem[i].s := '';
  end;
  FErrorMessage := '';
  STKP := 0;
  PRG_IP := 0;
  BASEP := 0; // HIGH PRIORITY FIX: Initialize base pointer
  AuxStackIdx := 0; // HIGH PRIORITY FIX: Initialize auxiliary stack index
  ended := false;
end;

constructor TExec.Create();
begin
  TagObject := nil;
  sourceAlloc := false;
  FTraceLevel := 0; //Debug trace mode disabled by default
  FCurrentFunction := ''; //No function being executed
  FWatchList := TStringList.Create; //Create watch list for debug
  FWatchList.Duplicates := dupIgnore; //Ignore duplicate variable names
  //This dictionary contains the BASIC program available functions. Those
  //imported from Delphi and those declared by the user in the BASIC program
  //source code.
  //This information is sent to the stack machine by the parser and by the
  //preprocessor.
  ProgramFunctions := TFunctionsDictionary.Create();
  //Holds the position and type for each compiled DATA statement.
  DataStmts := TDataItems.Create;
  //Holds the index for the READ statements
  ReadIdx := 0;
  //Stack machine execution timeout
  FTimeOut := DEFAULT_TIMEOUT;
  //UI refresh throttling
  FUIRefreshInterval := DEFAULT_UI_REFRESH_INTERVAL;
  FLastUIRefresh := 0;
  asmLexer := TAsmLexer.Create();
  try
    SetLength(asmProg, INITASMSIZE + 1);
  except
    on E:Exception do
    begin
      FErrorMessage := 'ERROR. Unable to allocate memory for program execution: '+E.Message;
      ended := true;
    end;
  end;
  Self.Clear();
end;

destructor TExec.Destroy();
begin
  if Assigned(FWatchList) then FreeAndNil(FWatchList);
  if Assigned(asmLexer) then FreeAndNil(asmLexer);
  if Assigned(DataStmts) then FreeAndNil(DataStmts);
  if Assigned(ProgramFunctions) then FreeAndNil(ProgramFunctions);

  inherited Destroy();
end;

//Executes a user defined function (called directly only for callbacks)
//Normal function calls within the main program use fCallNear instead.
//CRITICAL: This method MUST run callbacks in a completely isolated stack
//environment to prevent corrupting the main program's stack state.
procedure TExec.ExecuteFunction(Entry, ParamCount: Integer; ParamType: array of TExprKind; Params: array of TAsmData; RetType: TExprKind; out RetValue: TAsmData);
var
  deltaTicks: Int64;
  Timer: TStopWatch;
  innerProc, i, TmpIP, TmpSTKP, TmpBASEP, TmpAuxStackIdx: Integer;
  dt: TAsmData;
  WasEnded, HadError: Boolean;
begin
  //Starts with 1, because the execution point in the assembly code will always
  //start in a function
  innerProc := 1;
  HadError := false;

  //CRITICAL FIX: ALWAYS save the COMPLETE VM state before callback execution.
  //This method is called directly only for callbacks (via ExecuteUserFunction).
  //Normal function calls go through fCallNear within ExecuteProgram.
  //Without saving state, callbacks fired during main program execution
  //(e.g., from property setters like switch_ischecked#) would corrupt the stack.
  WasEnded := ended;
  TmpIP := PRG_IP;
  TmpSTKP := STKP;
  TmpBASEP := BASEP;
  // FIX: Save AuxStackIdx to prevent SELECT/CASE corruption during callbacks.
  // If a callback fires while the main program is inside a SELECT/CASE block,
  // and the callback also uses SELECT/CASE, the auxiliary stack would be corrupted.
  TmpAuxStackIdx := AuxStackIdx;

  //Use try/finally to GUARANTEE state restoration even if exceptions occur
  try
    //CRITICAL FIX: Do NOT reset STKP to 0!
    //Callbacks can fire during main program execution (e.g., OnSelChanged triggers
    //while PopulateData sets cell values). If we reset STKP to 0, the callback
    //writes its parameters and locals over positions 1..N, DESTROYING the main
    //program's live stack data. After restoring STKP, the main program finds
    //corrupted TypeStack entries => "Stack type mismatch".
    //
    //Instead, build the callback's stack frame ON TOP of the existing stack.
    //After the callback completes, we restore STKP/BASEP to discard the
    //callback's frame, leaving the main program's stack memory untouched.
    if ended then
      ended := false;
    PRG_IP := 0;
    //STKP stays at current value - callback builds on top of existing stack
    //BASEP stays at current value - will be saved/restored by fInitFunc/fRetFunction

    for i := 0 to ParamCount-1 do //Push parameters
      PushAsmData(Params[i], ParamType[i]);
    dt.n := ParamCount;
    PushAsmData(dt, ekNumber); //Push total of passed parameters.
    // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
    dt.p := Pointer(NativeInt(PRG_IP)); //Record the entry point.
    PushAsmData(dt, ekPointer); //Push function entry point.
    PRG_IP := Entry; //Move index to the function's entry point.
    //It must be an "atkInitFunc" instruction
    if (asmProg[PRG_IP].token <> atkInitFunc) then
    begin
      RTError(rteUserMessage, atkNull, 'Entry point is not a function address in function call by address.');
      Exit(); //finally will still run and restore state
    end;
    deltaTicks := FTimeOut * 1000; //Timeout in milliseconds
    Timer := TStopWatch.StartNew; //Create watch
    try
      repeat //run function's body
        if (asmProg[PRG_IP].token = atkCallNear) then Inc(innerProc);
        if (asmProg[PRG_IP].token = atkRetFunction) then Dec(innerProc);
        asmProg[PRG_IP].proc(); //call proc linked to the instruction
        Inc(PRG_IP); //move to next instruction
        //If there is a callback, run it.
        if (callBackObj <> nil) then CallBackProc(callBackObj);
        //Check for the script timeout
        if FTimeOut > 0 then //0 = no timeout (be careful)
        begin
          Timer.Stop(); //Stop watch
          if Timer.ElapsedMilliseconds > deltaTicks then //Check for timeout
          begin
            HadError := true;
            Break; //Exit loop instead of raising exception
          end;
          Timer.Start(); //Restart the watch
        end;
      until (ended or (innerProc = 0));
    finally
      Timer.Stop(); //Stop watch
    end;
    //Track if an error occurred during callback execution
    if ended then HadError := true;
    // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
    PRG_IP := NativeInt(dt.p);
    //After running, pop function result from stack (only if no error occurred)
    if not HadError then
    begin
      case RetType of
        ekNumber: RetValue.n := PopAsmData(ekNumber).n;
        ekPointer: RetValue.p := PopAsmData(ekPointer).p;
        ekString: RetValue.s := PopAsmData(ekString).s;
      end;
    end;
  finally
    //ALWAYS restore VM state after callback completes - this is CRITICAL
    //Restoring STKP effectively discards the callback's entire stack frame,
    //leaving the main program's stack data intact below.
    ended := WasEnded;
    PRG_IP := TmpIP;
    STKP := TmpSTKP;
    BASEP := TmpBASEP;
    AuxStackIdx := TmpAuxStackIdx; // Restore auxiliary stack (SELECT/CASE)
  end;
end;

//Execute the entire program
procedure TExec.ExecuteProgram();
const
  TIMEOUT_CHECK_INTERVAL = 10000; // Check timeout every N instructions
var
  deltaTicks: Int64;
  Timer: TStopWatch;
  instructionCount: Integer;
begin
  ExecStatus := TExecStatus.esRun; //Change status to 'running'
  Self.Clear(); //Reset the stack machine
  deltaTicks := FTimeOut * 1000; //Timeout in milliseconds
  Timer := TStopWatch.StartNew(); //Create watch
  instructionCount := 0; // HIGH PRIORITY FIX: Counter for optimized timeout checking

  repeat //for each instruction...
    if ExecStatus <> TExecStatus.esRun then
    begin
      Application.ProcessMessages();
      // FIX #10: Prevent 100% CPU usage during breakpoint/pause.
      // Without sleep, this tight loop burns all CPU resources.
      // On mobile devices this drains battery and can trigger
      // Android ANR or iOS watchdog. 16ms ≈ 60fps refresh rate.
      TThread.Sleep(16);
      continue;
    end;
    // FIX #12: Wrap instruction execution in try/except to catch unexpected
    // exceptions from library functions. Without this, an unhandled exception
    // propagates with PRG_IP/STKP/BASEP in potentially inconsistent state,
    // causing incorrect error line reporting. We catch it here and set the
    // error state cleanly before re-raising.
    try
      asmProg[PRG_IP].proc(); //Exec instr.
    except
      on E: Exception do
      begin
        // If ended is already set (e.g. by fErr or RTError), the error
        // was expected and handled — just re-raise to exit the loop.
        if not ended then
        begin
          FErrorMessage := 'Unexpected error at ASM[' + IntToStr(PRG_IP) +
            '] Source[' + IntToStr(srcLine) + ']: ' + E.Message;
          ended := true;
        end;
        raise;
      end;
    end;
    Inc(PRG_IP); //Increment instruction pointer
    //Check for callback object, If assigned process it.
    if (callBackObj <> nil) then CallBackProc(callBackObj);
    // HIGH PRIORITY FIX: Optimized timeout checking - only check every N instructions
    if FTimeOut > 0 then //0 = no timeout (be careful)
    begin
      Inc(instructionCount);
      if instructionCount >= TIMEOUT_CHECK_INTERVAL then
      begin
        instructionCount := 0;
        if Timer.ElapsedMilliseconds > deltaTicks then //Check for timeout
        begin
          ended := true;
          Timer.Stop();
          raise Exception.Create('Script timeout');
        end;
      end;
    end;
  until ended;
  Timer.Stop(); //Stop watch
end;

procedure TExec.fAdd();
begin
  Pop();
  StackMem[STKP].n := StackMem[STKP].n + StackMem[STKP + 1].n;
end;

procedure TExec.fAddCRLFS();
begin
  Pop();
  StackMem[STKP].s := StackMem[STKP].s + System.sLineBreak + StackMem[STKP + 1].s;
end;

procedure TExec.fAddS();
begin
  Pop();
  StackMem[STKP].s := StackMem[STKP].s + StackMem[STKP + 1].s;
end;

//Debug: ASSERT condition, "message"
procedure TExec.fAssert();
var
  assertMsg: String;
  condition: Extended;
begin
  //Pop the message first (was pushed last)
  assertMsg := PopAsmData(ekString).s;

  //Pop the condition result
  condition := PopAsmData(ekNumber).n;

  //Only execute assertion check if trace is enabled
  if FTraceLevel > 0 then
  begin
    if condition = 0 then
    begin
      //Assertion failed
      if Assigned(FPrintProc) then
        FPrintProc(PChar('[ASSERT FAILED] Line ' + IntToStr(srcLine) + ': ' + assertMsg + System.sLineBreak));

      //Stop execution
      ended := true;
    end;
  end;
end;

//Numerical far call
procedure TExec.fCallFar();
var
  n,i: Integer;
  numF: TLinkFunction;
  Args: Array of TAsmData;
  dt: TAsmData;
  farFuncSign: String;
begin
  farFuncSign := StrPas(PChar(strConst) + asmProg[PRG_IP].i);
  if not ProgramFunctions.ContainsKey(farFuncSign) then
  begin
    RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
    Exit();
  end;
  numF.Entry := ProgramFunctions[farFuncSign].Entry; //get entry point
  n := Trunc(PopAsmData(ekNumber).n);
  try
    SetLength(Args, n); //allocate parameters
  except
    RTError(rteUserMessage, atkNull, 'Out of memory');
    Exit();
  end;

  if n > 0 then
    for i := n - 1 downto 0 do //for each parameter...
    begin
      Pop;
      case TypeStack[STKP + 1] of
        ekNumber:
        begin
          Args[i].n := StackMem[STKP + 1].n;
          Args[i].p := nil;
          Args[i].s := '';
        end;
        ekPointer:
        begin
          Args[i].n := 0;
          Args[i].p := Pointer(StackMem[STKP + 1].p);
          Args[i].s := '';
        end;
        ekString:
        begin
          Args[i].n := 0;
          Args[i].p := nil;
          Args[i].s := StackMem[STKP + 1].s;
        end;
      end;
    end;
  //Calls 'numF' and push the result
  try
    dt := numF.Entry(args);
  except
    on E: Exception do
    begin
      RTError(rteUserMessage, atkNull, 'Far call error (' + farFuncSign + '): ' + E.Message);
      Exit;
    end;
  end;
  PushAsmData(dt, ekNumber);
end;

//Pointer far call
procedure TExec.fCallFarP();
var
  n,i: Integer;
  ptrF: TLinkFunction;
  Args: Array of TAsmData;
  dt: TAsmData;
  farFuncSign: String;
begin
  farFuncSign := StrPas(PChar(strConst) + asmProg[PRG_IP].i);
  if not ProgramFunctions.ContainsKey(farFuncSign) then
  begin
    RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
    Exit;
  end;
  ptrF.Entry := ProgramFunctions[farFuncSign].Entry; //get entry point
  n := Trunc(PopAsmData(ekNumber).n);
  try
    SetLength(Args, n); //allocate parameters
  except
    RTError(rteUserMessage, atkNull, 'Out of memory');
    Exit();
  end;

  if n > 0 then
    for i := n - 1 downto 0 do //for each parameter
    begin
      Pop;
      case TypeStack[STKP + 1] of
        ekNumber:
        begin
          Args[i].n := StackMem[STKP + 1].n;
          Args[i].p := nil;
          Args[i].s := '';
        end;
        ekPointer:
        begin
          Args[i].n := 0;
          Args[i].p := Pointer(StackMem[STKP + 1].p);
          Args[i].s := '';
        end;
        ekString:
        begin
          Args[i].n := 0;
          Args[i].p := nil;
          Args[i].s := StackMem[STKP + 1].s;
        end;
      end;
    end;
  //Calls 'ptrF' and push the result
  try
    dt := ptrF.Entry(args);
  except
    on E: Exception do
    begin
      RTError(rteUserMessage, atkNull, 'Far call error (' + farFuncSign + '): ' + E.Message);
      Exit;
    end;
  end;
  PushAsmData(dt, ekPointer);
end;

//String far call
procedure TExec.fCallFarS();
var
  n,i: Integer;
  strF: TLinkFunction;
  Args: Array of TAsmData;
  dt: TAsmData;
  farFuncSign: String;
begin
  farFuncSign := StrPas(PChar(strConst) + asmProg[PRG_IP].i);
  if not ProgramFunctions.ContainsKey(farFuncSign) then
  begin
    RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
    Exit;
  end;
  strF.Entry := ProgramFunctions[farFuncSign].Entry; //get entry point
  n := Trunc(PopAsmData(ekNumber).n);
  try
    SetLength(Args, n); //allocate parameters
  except
    RTError(rteUserMessage, atkNull, 'Out of memory');
    Exit;
  end;

  if n > 0 then
    for i := n - 1 downto 0 do //for each parameter
    begin
      Pop;
      case TypeStack[STKP + 1] of
        ekNumber:
        begin
          Args[i].n := StackMem[STKP + 1].n;
          Args[i].p := nil;
          Args[i].s := '';
        end;
        ekPointer:
        begin
          Args[i].n := 0;
          Args[i].p := Pointer(StackMem[STKP + 1].p);
          Args[i].s := '';
        end;
        ekString:
        begin
          Args[i].n := 0;
          Args[i].p := nil;
          Args[i].s := StackMem[STKP + 1].s;
        end;
      end;
    end;
  //Calls 'strF' and push the result
  try
    dt := strF.Entry(Args);
  except
    on E: Exception do
    begin
      RTError(rteUserMessage, atkNull, 'Far call error (' + farFuncSign + '): ' + E.Message);
      Exit;
    end;
  end;
  PushAsmData(dt, ekString);
end;

//User Defined Function (near) call
procedure TExec.fCallNear();
var
  dt: TAsmData;
begin
  // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
  dt.p := Pointer(NativeInt(PRG_IP + 1));
  PushAsmData(dt, ekPointer);
  PRG_IP := asmProg[PRG_IP].i - 1;
end;

procedure TExec.fCls();
begin
  FPrintProc(nil);
end;

procedure TExec.fComma();
var
  traceMsg: String;
begin
  srcLine := asmProg[PRG_IP].i;
  //Output trace info when trace mode is enabled
  if (FTraceLevel > 0) and Assigned(FPrintProc) then
  begin
    case FTraceLevel of
      1: //Basic: Line number only
        traceMsg := '[TRACE] Line ' + IntToStr(srcLine);
      2: //Standard: Line + function name
        begin
          traceMsg := '[TRACE] Line ' + IntToStr(srcLine);
          if FCurrentFunction <> '' then
            traceMsg := traceMsg + ' | Function: ' + FCurrentFunction;
        end;
      3: //Verbose: Line + function + watched variables
        begin
          traceMsg := '[TRACE] Line ' + IntToStr(srcLine);
          if FCurrentFunction <> '' then
            traceMsg := traceMsg + ' | Function: ' + FCurrentFunction;
          if FWatchList.Count > 0 then
            traceMsg := traceMsg + GetWatchedVariablesInfo();
        end;
    else
      traceMsg := '[TRACE] Line ' + IntToStr(srcLine);
    end;
    traceMsg := traceMsg + System.sLineBreak;
    FPrintProc(PChar(traceMsg));
  end;
end;

procedure TExec.fDiv();
begin
  Pop();
  if StackMem[STKP + 1].n = 0 then
  begin
    RTError(rteDivisionByZero, atkNull);
    Exit;
  end;
  StackMem[STKP].n := StackMem[STKP].n / StackMem[STKP + 1].n;
end;

//Debug: DUMP ["label"] - show all global variables with actual values
procedure TExec.fDump();
var
  dumpLabel: String;
  i: Integer;
  varName, varValue, varLine, displayName: String;
begin
  //Pop the label (empty string if not provided)
  dumpLabel := PopAsmData(ekString).s;

  //Only execute if trace is enabled
  if FTraceLevel > 0 then
  begin
    if Assigned(FPrintProc) then
    begin
      if dumpLabel <> '' then
        FPrintProc(PChar('[DUMP] ' + dumpLabel + ' (Line ' + IntToStr(srcLine) + ')' + System.sLineBreak))
      else
        FPrintProc(PChar('[DUMP] Line ' + IntToStr(srcLine) + System.sLineBreak));

      //Show all global variables if GlobalVarNames is available
      if Assigned(FGlobalVarNames) then
      begin
        for i := 3 to FGlobalVarNames.Count - 1 do  //Skip registers @0, @1, @2
        begin
          varName := FGlobalVarNames[i];

          //Skip only the internal registers @0, @1, @2 (already skipped by starting at 3)
          //But also skip if somehow they appear
          if (varName = '@0') or (varName = '@1') or (varName = '@2') then
            Continue;

          //Remove @ prefix for display
          if varName.StartsWith('@') then
            displayName := Copy(varName, 2, Length(varName) - 1)
          else
            displayName := varName;

          //Get value based on type (check the displayName for suffix)
          if displayName.EndsWith('$') then
            varValue := '"' + HeapMem[i].s + '"'
          else if displayName.EndsWith('#') then
          begin
            if HeapMem[i].p = nil then
              varValue := 'nil'
            else
              varValue := '$' + IntToHex(NativeInt(HeapMem[i].p), 8);
          end
          else
            varValue := FloatToStr(HeapMem[i].n);

          varLine := '  ' + displayName + ' = ' + varValue;
          FPrintProc(PChar(varLine + System.sLineBreak));
        end;
      end
      else
        FPrintProc(PChar('  (GlobalVarNames not available)' + System.sLineBreak));
    end;
  end;
end;

procedure TExec.fEnd();
begin
  srcLine := 0;
  ended := true;
end;

//Debug: Enable trace mode (legacy - same as TRACE 1)
procedure TExec.fTraceOn();
begin
  FTraceLevel := 1;
  if Assigned(FPrintProc) then
    FPrintProc(PChar('[TRACE] Trace mode enabled (level 1)' + System.sLineBreak));
end;

//Debug: Set trace level
procedure TExec.fTrace();
var
  level: Integer;
begin
  level := Round(asmProg[PRG_IP].n);
  FTraceLevel := level;
  if Assigned(FPrintProc) then
  begin
    case level of
      0: FPrintProc(PChar('[TRACE] Trace disabled' + System.sLineBreak));
      1: FPrintProc(PChar('[TRACE] Trace level 1 (basic)' + System.sLineBreak));
      2: FPrintProc(PChar('[TRACE] Trace level 2 (standard)' + System.sLineBreak));
      3: FPrintProc(PChar('[TRACE] Trace level 3 (verbose)' + System.sLineBreak));
    end;
  end;
end;

//Debug: UNWATCH [var1, var2, ...] - remove variables from watch list
procedure TExec.fUnwatch();
var
  varCount, i, idx: Integer;
  varName: String;
begin
  varCount := Round(asmProg[PRG_IP].n);

  if varCount = 0 then
  begin
    //Clear all watches
    FWatchList.Clear;
    if (FTraceLevel > 0) and Assigned(FPrintProc) then
      FPrintProc(PChar('[UNWATCH] Cleared all watched variables' + System.sLineBreak));
  end
  else
  begin
    //Remove specific variables
    for i := varCount - 1 downto 0 do
    begin
      varName := PopAsmData(ekString).s;
      idx := FWatchList.IndexOf(varName);
      if idx >= 0 then
        FWatchList.Delete(idx);
    end;
    if (FTraceLevel > 0) and Assigned(FPrintProc) then
      FPrintProc(PChar('[UNWATCH] Removed ' + IntToStr(varCount) + ' variable(s) from watch list' + System.sLineBreak));
  end;
end;

//Debug: WATCH var1, var2, ... - add variables to watch list
procedure TExec.fWatch();
var
  varCount, i: Integer;
  varName: String;
begin
  varCount := Round(asmProg[PRG_IP].n);

  //Pop variable names in reverse order, but insert at beginning to preserve order
  for i := varCount - 1 downto 0 do
  begin
    varName := PopAsmData(ekString).s;
    FWatchList.Insert(0, varName);  // Insert at beginning to preserve original order
  end;

  if (FTraceLevel > 0) and Assigned(FPrintProc) then
    FPrintProc(PChar('[WATCH] Added ' + IntToStr(varCount) + ' variable(s) to watch list' + System.sLineBreak));
end;

//Debug: Disable trace mode (legacy - same as TRACE 0)
procedure TExec.fTraceOff();
begin
  FTraceLevel := 0;
  if Assigned(FPrintProc) then
    FPrintProc(PChar('[TRACE] Trace mode disabled' + System.sLineBreak));
end;

//Debug: Breakpoint (only executes when trace is enabled)
procedure TExec.fBreakpoint();
var
  varCount, i: Integer;
  bkptMsg, varInfo, dialogMsg: String;
  varValue: TAsmData;
  varType: TExprKind;
  varNames: array of String;
  varValues: array of String;
begin
  //Only execute if trace mode is enabled
  if FTraceLevel = 0 then
  begin
    //Still need to clean the stack even when not tracing
    varCount := Round(asmProg[PRG_IP].n);
    //Pop all variable values and names
    for i := 0 to varCount - 1 do
    begin
      Pop(); //value
      Pop(); //name
    end;
    Pop(); //message
    Exit();
  end;

  //Get the variable count from the instruction
  varCount := Round(asmProg[PRG_IP].n);

  //Allocate arrays for variable info
  SetLength(varNames, varCount);
  SetLength(varValues, varCount);

  //Pop variables in reverse order (LIFO)
  for i := varCount - 1 downto 0 do
  begin
    //Pop variable value first (was pushed last for this var)
    varType := TypeStack[STKP];
    case varType of
      ekNumber:
      begin
        varValue := PopAsmData(ekNumber);
        varValues[i] := FloatToStr(varValue.n);
      end;
      ekString:
      begin
        varValue := PopAsmData(ekString);
        varValues[i] := '"' + varValue.s + '"';
      end;
      ekPointer:
      begin
        varValue := PopAsmData(ekPointer);
        if varValue.p = nil then
          varValues[i] := 'nil'
        else
          varValues[i] := '$' + IntToHex(NativeInt(varValue.p), 8);
      end;
    end;
    //Pop variable name
    varNames[i] := PopAsmData(ekString).s;
  end;

  //Now pop the breakpoint message (was pushed first)
  bkptMsg := PopAsmData(ekString).s;

  //Build variable info string
  varInfo := '';
  for i := 0 to varCount - 1 do
    varInfo := varInfo + '  ' + varNames[i] + ' = ' + varValues[i] + System.sLineBreak;

  //Build dialog message
  dialogMsg := 'BREAKPOINT at Line ' + IntToStr(srcLine) + System.sLineBreak;
  if bkptMsg <> '' then
    dialogMsg := dialogMsg + System.sLineBreak + 'Message: ' + bkptMsg + System.sLineBreak;
  if varInfo <> '' then
    dialogMsg := dialogMsg + System.sLineBreak + 'Variables:' + System.sLineBreak + varInfo;
  dialogMsg := dialogMsg + System.sLineBreak + 'Press YES to continue, NO to stop execution.';

  //Pause all timers
  PauseAllTimers();

  //Output to trace
  if Assigned(FPrintProc) then
    FPrintProc(PChar('[BREAKPOINT] ' + bkptMsg + ' (Line ' + IntToStr(srcLine) + ')' + System.sLineBreak));

  //Pause execution until dialog is closed
  ExecStatus := TExecStatus.esIdle;

  //Show dialog and wait for user response using async dialog service
  TDialogServiceAsync.MessageDialog(
    dialogMsg,
    TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbYes,
    0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrNo then
      begin
        //User chose to stop execution
        ended := true;
        if Assigned(FPrintProc) then
          FPrintProc(PChar('[BREAKPOINT] Execution stopped by user' + System.sLineBreak));
      end
      else
      begin
        //User chose to continue - resume timers
        ResumeAllTimers();
        if Assigned(FPrintProc) then
          FPrintProc(PChar('[BREAKPOINT] Execution resumed' + System.sLineBreak));
      end;
      //Resume execution
      ExecStatus := TExecStatus.esRun;
    end
  );
end;

procedure TExec.fEQ();
begin
  Pop();
  //if StackMem[STKP].n = StackMem[STKP + 1].n then
  if CompareValue(StackMem[STKP].n, StackMem[STKP + 1].n) = 0 then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fEQS();
begin
  Pop();
  if StackMem[STKP].s = StackMem[STKP + 1].s then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
  TypeStack[STKP] := ekNumber;
end;

//Assembly instruction 'ERR'
procedure TExec.fErr();
begin
  FErrorMessage := 'RUNTIME ERROR: '+StrPas(PChar(strConst)+asmProg[PRG_IP].i);
  // FIX #4: Set ended BEFORE raise. The raise transfers control immediately,
  // making any code after it unreachable. Setting ended first ensures the VM
  // stops even if the exception is caught by a callback's try/except block.
  ended := true;
  raise Exception.Create(FErrorMessage);
end;

procedure TExec.fForCycle();
var
  i: Integer;
begin
  i := asmProg[PRG_IP].i;
  if i < 0 then
  begin
    i := i + MAXLOCALS + BASEP;
    StackMem[i].n := StackMem[i].n + StackMem[STKP].n;
    StackMem[STKP].n := StackMem[i].n
  end
  else
  begin
    HeapMem[i].n := HeapMem[i].n + StackMem[STKP].n;
    StackMem[STKP].n := HeapMem[i].n;
  end;
end;

procedure TExec.fGE();
begin
  Pop();
  if StackMem[STKP].n >= StackMem[STKP + 1].n then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fGES();
begin
  Pop();
  if StackMem[STKP].s >= StackMem[STKP + 1].s then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
  TypeStack[STKP] := ekNumber;
end;

procedure TExec.fGT();
begin
  Pop();
  if StackMem[STKP].n > StackMem[STKP + 1].n then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fGTS();
begin
  Pop();
  if StackMem[STKP].s > StackMem[STKP + 1].s then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
  TypeStack[STKP] := ekNumber;
end;

//Call a function (near or far) using its signature
procedure TExec.fIndirectCall();
var
  dt: TAsmData;
  FnSignt, FnParams: String;
  n,i: Integer;
  farF: TLinkFunction;
  Args, Params: Array of TAsmData;
begin
  n := Trunc(PopAsmData(ekNumber).n); //Get total of parameters
  if (STKP < n) or (n = 0) then //Stack pointer must be compatible with the total of parameters
  begin
    RTError(rteStackUnderflow, atkNull);
    Exit();
  end;

  try
    SetLength(Params, n-1); //allocate parameters array
  except
    RTError(rteUserMessage, atkNull, 'Out of memory');
    Exit();
  end;

  if n-1 > 0 then
    for i := n - 1 downto 1 do //set the type for each parameter
    begin
      Pop;
      case TypeStack[STKP+1] of
        ekNumber:
        begin
          Params[i-1].n := StackMem[STKP+1].n;
          Params[i-1].p := nil;
          Params[i-1].s := '';
        end;
        ekPointer:
        begin
          Params[i-1].n := 0;
          Params[i-1].p := Pointer(StackMem[STKP+1].p);
          Params[i-1].s := '';
        end;
        ekString:
        begin
          Params[i-1].n := 0;
          Params[i-1].p := nil;
          Params[i-1].s := StackMem[STKP+1].s;
        end;
      end;
    end;
  FnSignt := PopAsmData(ekString).s; //Get the function's signature
  if programFunctions.ContainsKey(FnSignt) then //Check if function exists at the dictionary
  begin
    FnParams := ICallGetParams(FnSignt); //Get the parameters part of the signature
    for i := 0 to FnParams.Length-1 do //For each char...
    begin
      case FnParams.Chars[i] of
        'n': //number
        begin
          dt.n := Params[i].n;
          PushAsmData(dt, ekNumber);
        end;
        '#': //pointer
        begin
          dt.p := Params[i].p;
          PushAsmData(dt, ekPointer);
        end;
        '$': //string
        begin
          dt.s := Params[i].s;
          PushAsmData(dt, ekString);
        end;
      end;
    end;
    dt.n := FnParams.Length; //get the total of parameters pushed
    if Trunc(dt.n) <> n-1 then //validate
    begin
      RTError(rteUserMessage, atkNull, 'Total of arguments mismatch in ICALL instruction');
      Exit();
    end;
    PushAsmData(dt, ekNumber); //Push the total of parameters

    if not programFunctions[FnSignt].FarCall then //"near" function
    begin
      // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
      dt.p := Pointer(NativeInt(PRG_IP + 1)); //Get the next instruction pointer
      PushAsmData(dt, ekPointer); //Push next instruction pointer into the stack (function return)
      PRG_IP := NativeInt(@programFunctions[FnSignt].Entry); //Move PRG_IP to the function entry point
      Exit();
    end;

    //If we reach this point, that's because the function signature points to a
    //"FAR" function.
    farF.Entry := programFunctions[FnSignt].Entry;
    //Value pushed during "FnParams" formation (few lines above)
    n := Trunc(PopAsmData(ekNumber).n);
    try
      SetLength(Args, n); //allocate parameters
    except
      RTError(rteUserMessage, atkNull, 'Out of memory');
      Exit;
    end;
    if (n > 0) then
      for i := n-1 downto 0 do
      begin
        Pop;
        case TypeStack[STKP+1] of
          ekNumber: Args[i].n := StackMem[STKP+1].n;
          ekPointer: Args[i].p := StackMem[STKP+1].p;
          ekString: Args[i].s := StackMem[STKP+1].s;
       end;
      end;
    //Call the FAR function, store result in "dt"
    try
      dt := farF.Entry(Args);
    except
      on E: Exception do
      begin
        RTError(rteUserMessage, atkNull, 'Far call error (' + FnSignt + '): ' + E.Message);
        Exit;
      end;
    end;
    case ICallReturnType(FnSignt).Chars[0] of
      'n': PushAsmData(dt, ekNumber);
      '#': PushAsmData(dt, ekPointer);
      '$': PushAsmData(dt, ekString);
    end;
    Exit();
  end;
  RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
end;

//procedure TExec.fInitFunc();
//var
//  dt: TAsmData;
//begin
//  dt.p := pointer(BASEP);
//  PushAsmData(dt, ekPointer);
//  BASEP := STKP;
//  Inc(STKP, asmProg[PRG_IP].i);
//end;
procedure TExec.fInitFunc();
var
  dt: TAsmData;
  i, localCount: Integer;
begin
  dt.p := pointer(BASEP);
  PushAsmData(dt, ekPointer);
  BASEP := STKP;
  localCount := asmProg[PRG_IP].i;

  // FIX #3: Bounds check — prevent writing past StackMem/TypeStack arrays.
  // Deep recursion or functions with many locals could overflow MAXSTACK.
  if BASEP + localCount >= MAXSTACK then
  begin
    RTError(rteStackOverflow, atkNull);
    Exit;
  end;

  // Local variables start at BASEP+1 (BASEP holds saved old BASEP).
  // Stack layout: [BASEP] = saved old BASEP, [BASEP+1..] = local variables
  for i := 1 to localCount do
  begin
    StackMem[BASEP + i].n := 0;   // Numbers default to 0
    StackMem[BASEP + i].p := nil; // Pointers default to nil
    StackMem[BASEP + i].s := '';  // Strings default to ""
    TypeStack[BASEP + i] := ekNumber; // FIX #9: Init TypeStack for locals
  end;
  Inc(STKP, localCount);
end;

procedure TExec.fInput();
var
  dt, ret: TAsmData;
  SCaption, FnSignt, stmp: String;
  Value: Extended;
  Args, Params: Array of TAsmData;
  farF: TLinkFunction;
  ALabels, AValues: array of string;
begin
  FnSignt := PopAsmData(ekString).s; //Function signature
  Value := PopAsmData(ekNumber).n; //Numeric default value
  SetLength(AValues, 1); AValues[0] := FloatToStr(Value);
  SetLength(ALabels, 1); ALabels[0] := PopAsmData(ekString).s; //Popup filed label
  sCaption := PopAsmData(ekString).s; //Popup caption

  if programFunctions.ContainsKey(FnSignt) then //Check if function exists at the dictionary
  begin
    try
      try
        FMX.DialogService.Async.TDialogServiceAsync.InputQuery(sCaption, ALabels, AValues,
          procedure(const AResult: TModalResult; const AValues: array of string)
          begin
            if AResult = mrOk then
            begin
              if not TryStrToFloat(AValues[0], Value) then
                Value := 0.0;

              if not programFunctions[FnSignt].FarCall then //"near" function
              begin
                try
                  SetLength(Params, 1); //allocate parameters array (INPUT command numerical value)
                except
                  RTError(rteUserMessage, atkNull, 'Out of memory');
                  Exit();
                end;
                Params[0].n := Value;
                Params[0].p := nil;
                Params[0].s := '';

                try
                  // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
                  ExecuteFunction(NativeInt(@programFunctions[FnSignt].Entry)+1, 1, [TExprKind.ekNumber], Params, TExprKind.ekNumber, ret);
                  //Push function return value back into the stack
                  PushAsmData(ret, ekNumber);
                except
                  On E: Exception do
                  begin
                    stmp := '*** Exception catched ***'+System.sLineBreak;
                    stmp := stmp + 'Instruction Pointer: [' + IntToStr(PRG_IP) + ']'+System.sLineBreak;
                    stmp := stmp + 'Function entry: [' + IntToStr(NativeInt(@programFunctions[FnSignt].Entry)) + ']'+System.sLineBreak;
                    stmp := stmp + 'Line: ' + IntToStr(SourceLine)+System.sLineBreak;
                    stmp := stmp + 'Exception: "' + E.Message + '"';
                    if Assigned(FPrintProc) then
                      FPrintProc(PChar(stmp));
                  end;
                end;

                Exit(); //End this function
              end;

              //If we reach this point, that's because the function signature points to a
              //"FAR" function.
              farF.Entry := programFunctions[FnSignt].Entry;
              try
                SetLength(Args, 1); //allocate parameters
              except
                RTError(rteUserMessage, atkNull, 'Out of memory');
                Exit();
              end;
              Args[0].n := Value;
              //Call the FAR function, store result in "dt"
              dt := farF.Entry(Args);
              //Push function return value into the stack
              PushAsmData(dt, ekNumber);
            end;
          end);
      except
        on E:Exception do
          RTError(rteUserMessage, atkNull, E.Message);
        on E:EInvalidFmxHandle do
          RTError(rteUserMessage, atkNull, E.Message);
      end;
    finally
      SetLength(AValues, 0);
      SetLength(ALabels, 0);
    end;

    Exit();
  end;
  RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
end;

procedure TExec.fInputS();
var
  dt, ret: TAsmData;
  SCaption, FnSignt, stmp: String;
  Args, Params: Array of TAsmData;
  farF: TLinkFunction;
  ALabels, AValues: array of string;
begin
  FnSignt := PopAsmData(ekString).s;
  SetLength(AValues, 1); AValues[0] := PopAsmData(ekString).s;
  SetLength(ALabels, 1); ALabels[0] := PopAsmData(ekString).s;
  sCaption := PopAsmData(ekString).s;

  if programFunctions.ContainsKey(FnSignt) then //Check if function exists at the dictionary
  begin
    try
      try
        FMX.DialogService.Async.TDialogServiceAsync.InputQuery(sCaption, ALabels, AValues,
          procedure(const AResult: TModalResult; const AValues: array of string)
          begin
            if AResult = mrOk then
            begin
              if not programFunctions[FnSignt].FarCall then //"near" function
              begin
                try
                  SetLength(Params, 1); //allocate parameters array (INPUT command numerical value)
                except
                  RTError(rteUserMessage, atkNull, 'Out of memory');
                  Exit();
                end;
                Params[0].n := 0;
                Params[0].p := nil;
                Params[0].s := AValues[0];

                try
                  // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
                  ExecuteFunction(NativeInt(@programFunctions[FnSignt].Entry)+1, 1, [TExprKind.ekString], Params, TExprKind.ekString, ret);
                  //Push function return value back into the stack
                  PushAsmData(ret, ekString);
                except
                  on E: Exception do
                  begin
                    stmp := '*** Exception catched ***'+System.sLineBreak;
                    stmp := stmp + 'Instruction Pointer: [' + IntToStr(PRG_IP) + ']'+System.sLineBreak;
                    stmp := stmp + 'Function entry: [' + IntToStr(NativeInt(@programFunctions[FnSignt].Entry)) + ']'+System.sLineBreak;
                    stmp := stmp + 'Line: ' + IntToStr(SourceLine)+System.sLineBreak;
                    stmp := stmp + 'Exception: "' + E.Message + '"';
                    if Assigned(FPrintProc) then
                      FPrintProc(PChar(stmp));
                  end;
                end;

                Exit(); //End this function
              end;

              //If we reach this point, that's because the function signature points to a
              //"FAR" function.
              farF.Entry := programFunctions[FnSignt].Entry;
              try
                SetLength(Args, 1); //allocate parameters
              except
                RTError(rteUserMessage, atkNull, 'Out of memory');
                Exit();
              end;
              Args[0].s := AValues[0];
              //Call the FAR function, store result in "dt"
              dt := farF.Entry(Args);
              //Push function return value into the stack
              PushAsmData(dt, ekString);
            end;
          end);
      except
        on E:Exception do
          RTError(rteUserMessage, atkNull, E.Message);
        on E:EInvalidFmxHandle do
          RTError(rteUserMessage, atkNull, E.Message);
      end;
    finally
      SetLength(AValues, 0);
      SetLength(ALabels, 0);
    end;

    Exit();
  end;
  RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
end;

procedure TExec.fInv();
begin
  StackMem[STKP].n := -StackMem[STKP].n;
end;

procedure TExec.fJump();
begin
  PRG_IP := asmProg[PRG_IP].i - 1;
end;

procedure TExec.fLE();
begin
  Pop();
  if StackMem[STKP].n <= StackMem[STKP + 1].n then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fLES();
begin
  Pop();
  if StackMem[STKP].s <= StackMem[STKP + 1].s then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
  TypeStack[STKP] := ekNumber;
end;

procedure TExec.fLT();
begin
  Pop();
  if StackMem[STKP].n < StackMem[STKP + 1].n then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fLTS();
begin
  Pop();
  if StackMem[STKP].s < StackMem[STKP + 1].s then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
  TypeStack[STKP] := ekNumber;
end;

procedure TExec.fMax();
begin
  Pop();
  if StackMem[STKP + 1].n > StackMem[STKP].n then
    StackMem[STKP].n := StackMem[STKP + 1].n;
end;

procedure TExec.fMin();
begin
  Pop();
  if StackMem[STKP + 1].n < StackMem[STKP].n then
    StackMem[STKP].n := StackMem[STKP + 1].n;
end;

procedure TExec.fMod();
begin
  Pop();
  // CRITICAL FIX: Check for division by zero
  if StackMem[STKP + 1].n = 0 then
  begin
    RTError(rteDivisionByZero, atkNull);
    Exit;
  end;
  StackMem[STKP].n := Frac(StackMem[STKP].n / StackMem[STKP + 1].n) * StackMem[STKP + 1].n;
end;

procedure TExec.fMul();
begin
  Pop();
  StackMem[STKP].n := StackMem[STKP].n * StackMem[STKP + 1].n;
end;

procedure TExec.fNE();
begin
  Pop();
  //if StackMem[STKP].n <> StackMem[STKP + 1].n then
  if CompareValue(StackMem[STKP].n, StackMem[STKP + 1].n) <> 0 then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fNES();
begin
  Pop();
  if StackMem[STKP].s <> StackMem[STKP + 1].s then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
  TypeStack[STKP] := ekNumber;
end;

procedure TExec.fNOp();
begin
  // 'N'ot 'OP'erational
end;

procedure TExec.fNot();
begin
  if StackMem[STKP].n = 0 then
    StackMem[STKP].n := 1
  else
    StackMem[STKP].n := 0;
end;

procedure TExec.fOnCallFar();
var
  dt: TAsmData;
  FnSignt, FnParams: String;
  Args, Params: Array of TAsmData;
  farF: TLinkFunction;
  i, n: Integer;
  Test: Boolean;
begin
  n := Trunc(PopAsmData(ekNumber).n); //Get total of parameters
  FnSignt := PopAsmData(ekString).s; //Get the function signature

  if (STKP < n) or (n = 0) then //Stack pointer must be compatible with the total of parameters
  begin
    RTError(rteStackUnderflow, atkNull);
    Exit();
  end;

  try
    SetLength(Params, n-1); //allocate parameters array
  except
    RTError(rteUserMessage, atkNull, 'Out of memory');
    Exit();
  end;

  if n-1 > 0 then
    for i := n - 1 downto 1 do //set the type for each parameter
    begin
      Pop;
      case TypeStack[STKP+1] of
        ekNumber:
        begin
          Params[i-1].n := StackMem[STKP+1].n;
          Params[i-1].p := nil;
          Params[i-1].s := '';
        end;
        ekPointer:
        begin
          Params[i-1].n := 0;
          Params[i-1].p := Pointer(StackMem[STKP+1].p);
          Params[i-1].s := '';
        end;
        ekString:
        begin
          Params[i-1].n := 0;
          Params[i-1].p := nil;
          Params[i-1].s := StackMem[STKP+1].s;
        end;
      end;
    end;

  Test := PopAsmData(ekNumber).n = 0; //ON..CALL test result

  if programFunctions.ContainsKey(FnSignt) then //Check if function exists at the dictionary
  begin
    FnParams := ICallGetParams(FnSignt); //Get the parameters part of the signature
    for i := 0 to FnParams.Length-1 do //For each char...
    begin
      case FnParams.Chars[i] of
        'n': //number
        begin
          dt.n := Params[i].n;
          PushAsmData(dt, ekNumber);
        end;
        '#': //pointer
        begin
          dt.p := Params[i].p;
          PushAsmData(dt, ekPointer);
        end;
        '$': //string
        begin
          dt.s := Params[i].s;
          PushAsmData(dt, ekString);
        end;
      end;
    end;
    dt.n := FnParams.Length; //get the total of parameters pushed
    if Trunc(dt.n) <> n-1 then //validate
    begin
      RTError(rteUserMessage, atkNull, 'Total of arguments mismatch in ICALL instruction');
      Exit();
    end;

    PushAsmData(dt, ekNumber); //Push the total of parameters

    if not programFunctions[FnSignt].FarCall then //"near" function
    begin
      if Test then
      begin
        // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
        dt.p := Pointer(NativeInt(PRG_IP + 1)); //Get the next instruction pointer
        PushAsmData(dt, ekPointer); //Push next instruction pointer into the stack (function return)
        PRG_IP := NativeInt(@programFunctions[FnSignt].Entry); //Move PRG_IP to the function entry point
      end;
      Exit();
    end;

    //If we reach this point, that's because the function signature points to a
    //"FAR" function.
    farF.Entry := programFunctions[FnSignt].Entry;
    //Value pushed during "FnParams" formation (few lines above)
    n := Trunc(PopAsmData(ekNumber).n);
    try
      SetLength(Args, n); //allocate parameters
    except
      RTError(rteUserMessage, atkNull, 'Out of memory');
      Exit;
    end;
    if (n > 0) then
      for i := n-1 downto 0 do
      begin
        Pop;
        case TypeStack[STKP+1] of
          ekNumber: Args[i].n := StackMem[STKP+1].n;
          ekPointer: Args[i].p := StackMem[STKP+1].p;
          ekString: Args[i].s := StackMem[STKP+1].s;
       end;
      end;

    if Test then
    begin
      //Call the FAR function, store result in "dt"
      try
        dt := farF.Entry(Args);
      except
        on E: Exception do
        begin
          RTError(rteUserMessage, atkNull, 'Far call error (' + FnSignt + '): ' + E.Message);
          Exit;
        end;
      end;
      case ICallReturnType(FnSignt).Chars[0] of
        'n': PushAsmData(dt, ekNumber);
        '#': PushAsmData(dt, ekPointer);
        '$': PushAsmData(dt, ekString);
      end;
    end;
    Exit();
  end;
  RTError(rteUserMessage, atkNull, 'There is no function with such arguments.');
end;

// FIX #5: Replaced empty stubs with explicit error messages.
// Previously these were silent no-ops — if ever triggered, they would
// silently discard the ON..CALL without any feedback. The parser
// currently only generates ONCALLEX (numeric), but these prevent
// silent data loss if the language is later extended.
procedure TExec.fOnCallFarP();
begin
  RTError(rteUserMessage, atkNull,
    'ON..CALL for pointer-returning functions is not yet implemented');
end;

procedure TExec.fOnCallFarS();
begin
  RTError(rteUserMessage, atkNull,
    'ON..CALL for string-returning functions is not yet implemented');
end;

procedure TExec.fPop();
begin
  if STKP = 0 then
  begin
    RTError(rteStackUnderflow, atkNull);
    Exit;
  end;
  Dec(STKP);
end;

//Pop SELECT aux stack
procedure TExec.fPopAuxStack();
begin
  if AuxStackIdx = 0 then
  begin
    RTError(rteAuxStackUnderflow, atkNull);
    Exit;
  end;
  Dec(AuxStackIdx);
end;

procedure TExec.fPopNCall();
var
  dt: TAsmData;
begin
  if PopAsmData(ekNumber).n = 0 then
  begin
    // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
    dt.p := Pointer(NativeInt(PRG_IP + 1));
    PushAsmData(dt, ekPointer);
    PRG_IP := asmProg[PRG_IP].i - 1;
  end;
end;

procedure TExec.fPopNJump();
begin
  if PopAsmData(ekNumber).n = 0 then
    PRG_IP := asmProg[PRG_IP].i - 1;
end;

procedure TExec.fPopStore();
var
  i: Integer;
  dt: TAsmData;
begin
  dt := PopAsmData(ekNumber);
  i := asmProg[PRG_IP].i;
  if i < 0 then
    StackMem[BASEP + i + MAXLOCALS].n := dt.n //local
  else
    HeapMem[i].n := dt.n; //global
end;

procedure TExec.fPopStorePtr();
var
  i: Integer;
  dt: TAsmData;
begin
  dt := PopAsmData(ekPointer);
  i := asmProg[PRG_IP].i;
  if i < 0 then
    StackMem[BASEP + i + MAXLOCALS].p := dt.p //local
  else
    HeapMem[i].p := dt.p; //global
end;

procedure TExec.fPopStoreS();
var
  i: Integer;
  dt: TAsmData;
begin
  dt := PopAsmData(ekString);
  i := asmProg[PRG_IP].i;
  if i < 0 then
    StackMem[BASEP + i + MAXLOCALS].s := dt.s //local
  else
    HeapMem[i].s := dt.s; //global
end;

// FIX #8: Added domain validation for power operations.
// Power(negative, fractional) → NaN, Power(0, negative) → Infinity.
// Without this, special values silently propagate through all
// subsequent arithmetic, causing confusing behavior.
procedure TExec.fPow();
var
  base, exponent, r: Extended;
begin
  Pop;
  base := StackMem[STKP].n;
  exponent := StackMem[STKP + 1].n;
  try
    r := Power(base, exponent);
    if IsNan(r) or IsInfinite(r) then
    begin
      RTError(rteUserMessage, atkNull, 'Invalid power operation');
      Exit;
    end;
  except
    on E: Exception do
    begin
      RTError(rteUserMessage, atkNull, 'Invalid power operation: ' + E.Message);
      Exit;
    end;
  end;
  StackMem[STKP].n := r;
end;

procedure TExec.fPrint();
var
  n, i, l: Integer;
  s, sr, st: String;
begin
  n := Round(PopAsmData(ekNumber).n);
  if n = 0 then
  begin
    FPrintProc(PChar(''));
    Exit();
  end;
  if STKP < n then
  begin
    RTError(rtePrintStackOverflow, atkNull);
    Exit();
  end;
  Dec(STKP, n);
  sr := '';
  i := 1;
  repeat
    if i > n then //todos os valores impressos, termina
      break;
    if TypeStack[STKP + i] = ekString then
      st := StackMem[STKP + i].s
    else
      //st := ' ' + FloatToStrF(StackMem[STKP + i].n, ffgeneral, 13, 0) + ' ';
      st := FloatToStrF(StackMem[STKP + i].n, ffgeneral, 13, 0);
    sr := sr + st;
    Inc(i);
    if i > n then
      break;
    s := StackMem[STKP + i].s;
    if (s <> ',') and (s <> ';') then
    begin
      RTError(rtePrintSyntaxMismatch, atkNull);
      Exit;
    end;
    Inc(i);
    if s = ';' then
      Continue;
    //l := 14 - Length(st);
    l := 5 - Length(st);
    while (l < 0) do
      //Inc(l, 14);
      Inc(l, 5);
    sr := sr + format('%-*s', [l, '']);
  until false;

  //Output text first
  FPrintProc(PChar(sr));

  //Throttled UI refresh for better performance in loops with many PRINTs
  //Only refresh if enough time has passed since last refresh
  if not unitGC.SkipProcessMessages then
  begin
    if (FUIRefreshInterval = 0) or
       (TThread.GetTickCount - FLastUIRefresh >= Cardinal(FUIRefreshInterval)) then
    begin
      Application.ProcessMessages();
      FLastUIRefresh := TThread.GetTickCount;
    end;
  end;
end;

//Push numerical var (local or global)
procedure TExec.fPush();
var
  i: Integer;
begin
  i := asmProg[PRG_IP].i;
  if i < 0 then
    PushAsmData(StackMem[BASEP + i + MAXLOCALS], ekNumber) //local var
  else
    PushAsmData(HeapMem[i], ekNumber); //global var
end;

//Push numeric value into SELECT aux stack
procedure TExec.fPushAuxStack();
begin
  // CRITICAL FIX: Check BEFORE incrementing to prevent buffer overrun
  if AuxStackIdx >= MAXSTACK - 1 then
  begin
    RTError(rteAuxStackOverflow, atkNull);
    Exit;
  end;
  Inc(AuxStackIdx);
  if TypeStack[STKP]<> ekNumber then
  begin
    RTError(rteAuxStackTypeMismatch, atkNull);
    Dec(AuxStackIdx); // Rollback increment on type mismatch
    Exit();
  end;
  AuxStack[AuxStackIdx].n := StackMem[STKP].n;
  Pop();
  AuxStackTypes[AuxStackIdx] := TExprKind.ekNumber;
end;

//Push string value into SELECT aux stack
procedure TExec.fPushAuxStackS();
begin
  // CRITICAL FIX: Check BEFORE incrementing to prevent buffer overrun
  if AuxStackIdx >= MAXSTACK - 1 then
  begin
    RTError(rteAuxStackOverflow, atkNull);
    Exit;
  end;
  Inc(AuxStackIdx);
  if TypeStack[STKP] <> ekString then
  begin
    RTError(rteAuxStackTypeMismatch, atkNull);
    Dec(AuxStackIdx); // Rollback increment on type mismatch
    Exit();
  end;
  AuxStack[AuxStackIdx].s := StackMem[STKP].s;
  Pop();
  AuxStackTypes[AuxStackIdx] := TExprKind.ekString;
end;

//Push the SELECT aux stack TOS into the data stack. This method **DO NOT** pop
//the SELECT aux stack TOS
procedure TExec.fPushAuxTOS();
var
  dt: TAsmData;
begin
  if AuxStackTypes[AuxStackIdx] = TExprKind.ekNumber then
  begin
    dt.n := AuxStack[AuxStackIdx].n;
    PushAsmData(dt, ekNumber);
  end
  else
  begin
    dt.s := AuxStack[AuxStackIdx].s;
    PushAsmData(dt, ekString);
  end;
end;

//Push numerical constant
procedure TExec.fPushC();
var
  dt: TAsmData;
begin
  dt.n := asmProg[PRG_IP].n;
  PushAsmData(dt, ekNumber);
end;

//Push pointer var (local or global)
procedure TExec.fPushPtr();
var
  i: Integer;
begin
  i := asmProg[PRG_IP].i;
  if i < 0 then
    PushAsmData(StackMem[BASEP + i + MAXLOCALS], ekPointer) //local var
  else
    PushAsmData(HeapMem[i], ekPointer); //global var
end;

//Push "THIS" object pointer
procedure TExec.fPushPtrTag();
var
  dt: TAsmData;
begin
  dt.p := TagObject;
  PushAsmData(dt, ekPointer);
end;

//Push string var (local or global)
procedure TExec.fPushS();
var
  i: Integer;
begin
  i := asmProg[PRG_IP].i;
  if i < 0 then
    PushAsmData(StackMem[BASEP + i + MAXLOCALS], ekString)
  else
    PushAsmData(HeapMem[i], ekString);
end;

//Push string constant
procedure TExec.fPushSC();
var
  dt: TAsmData;
begin
  dt.s := StrPas(PChar(strConst) + asmProg[PRG_IP].i);
  PushAsmData(dt, ekString);
end;

procedure TExec.fRead();
var
  i: Integer;
begin
  if ReadIdx >= DataStmts.Count then
  begin
    RTError(rteUserMessage, atkNull, 'READ past DATA');
    Exit();
  end;

  if DataStmts[ReadIdx].DataType <> 'n' then
  begin
    RTError(rteUserMessage, atkNull, 'Invalid data type for READ instruction');
    Exit();
  end;

  i := asmProg[PRG_IP].i;
  if i < 0 then
    StackMem[BASEP + i + MAXLOCALS].n := asmProg[DataStmts[ReadIdx].DataPos].n //local
  else
    HeapMem[i].n := asmProg[DataStmts[ReadIdx].DataPos].n; //global
  Inc(ReadIdx);
end;

procedure TExec.fReadS();
var
  i: Integer;
begin
  if ReadIdx >= DataStmts.Count then
  begin
    RTError(rteUserMessage, atkNull, 'READ past DATA');
    Exit;
  end;

  if DataStmts[ReadIdx].DataType <> '$' then
  begin
    RTError(rteUserMessage, atkNull, 'Invalid data type for READ instruction');
    Exit;
  end;

  i := asmProg[PRG_IP].i;
  if i < 0 then
    StackMem[BASEP + i + MAXLOCALS].s := StrPas(PChar(strConst) + asmProg[DataStmts[ReadIdx].DataPos].i) //local
  else
    HeapMem[i].s := StrPas(PChar(strConst) + asmProg[DataStmts[ReadIdx].DataPos].i); //global

  Inc(ReadIdx);
end;

//-----------------------------------------------------------------------------
// REFRESHRATE n - Set UI refresh interval in milliseconds
//-----------------------------------------------------------------------------
procedure TExec.fRefreshRate();
begin
  FUIRefreshInterval := asmProg[PRG_IP].i;
  FLastUIRefresh := 0; //Reset the timer to apply new setting immediately
end;

procedure TExec.fRestore();
begin
  ReadIdx := 0; //Restore READ index
end;

procedure TExec.fRetFunction();
var
  SP, n: Integer;
begin
  SP := STKP;
  STKP := BASEP;
  // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
  //DEFENSIVE FIX: Check for errors after each critical pop to prevent cascading failures
  BASEP := NativeInt(PopAsmData(ekPointer).p);
  if ended then Exit; //Stop if error occurred during pop
  PRG_IP := NativeInt(PopAsmData(ekPointer).p) - 1;
  if ended then Exit; //Stop if error occurred during pop
  n := Round(PopAsmData(ekNumber).n);
  if ended then Exit; //Stop if error occurred during pop
  Dec(STKP, n);
  Inc(STKP);
  TypeStack[STKP] := TypeStack[SP];
  StackMem[STKP] := StackMem[SP];
end;

procedure TExec.fReturn();
begin
  // HIGH PRIORITY FIX: Use NativeInt for 64-bit compatibility
  PRG_IP := NativeInt(PopAsmData(ekPointer).p) - 1;
end;

procedure TExec.fSub();
begin
  Pop();
  StackMem[STKP].n := StackMem[STKP].n - StackMem[STKP + 1].n;
end;

procedure TExec.fSubS();
var
  i, l: Integer;
begin
  Pop();
  i := Round(StackMem[STKP + 1].n);
  l := Length(StackMem[STKP].s);
  if i > l then
    i := l;
  Delete(StackMem[STKP].s, 1 + l - i, i);
end;

function TExec.GetGlobalNum(const Index: Integer): Extended;
begin
  Result := HeapMem[Index].n;
end;

function TExec.GetGlobalPtr(const Index: Integer): Pointer;
begin
  Result := HeapMem[Index].p;
end;

function TExec.GetGlobalStr(const Index: Integer): String;
begin
  Result := HeapMem[Index].s;
end;

//Debug: Get trace enabled (for legacy compatibility)
function TExec.GetTraceEnabled(): Boolean;
begin
  Result := FTraceLevel > 0;
end;

//Debug: Get variable value as string (actual value, not just type)
function TExec.GetVariableValue(const varName: String): String;
var
  varIndex: Integer;
  lowerName{, displayName}: String;
begin
  Result := '?';

  //Need GlobalVarNames to be set
  if not Assigned(FGlobalVarNames) then
    Exit;

  //Variable names are stored in lowercase with @ prefix
  lowerName := '@' + LowerCase(varName);  // Add @ prefix for lookup

  //Find variable index in GlobalVarNames
  varIndex := FGlobalVarNames.IndexOf(lowerName);

  if varIndex < 0 then
  begin
    Result := '(not found)';
    Exit;
  end;

  //Get value based on variable type (determined by suffix)
  if varName.EndsWith('$') then
  begin
    //String variable
    Result := '"' + HeapMem[varIndex].s + '"';
  end
  else if varName.EndsWith('#') then
  begin
    //Pointer variable
    if HeapMem[varIndex].p = nil then
      Result := 'nil'
    else
      Result := '$' + IntToHex(NativeInt(HeapMem[varIndex].p), 8);
  end
  else
  begin
    //Numeric variable
    Result := FloatToStr(HeapMem[varIndex].n);
  end;
end;

//Debug: Get watched variables info string
function TExec.GetWatchedVariablesInfo(): String;
var
  i: Integer;
  varName, varValue: String;
begin
  Result := '';
  if FWatchList.Count = 0 then
    Exit;

  Result := ' | ';
  for i := 0 to FWatchList.Count - 1 do
  begin
    if i > 0 then
      Result := Result + ', ';
    varName := FWatchList[i];
    varValue := GetVariableValue(varName);
    Result := Result + varName + '=' + varValue;
  end;
end;

//Auxiliary method. Return function arguments types
function TExec.ICallGetParams(signature: String): String;
var
  sepPos: Integer;
begin
  sepPos := signature.IndexOf('@');
  if sepPos < 1 then Exit('');
  Exit(signature.Substring(sepPos+1).ToLower());
end;

//Auxiliary method. Get function return type based on signature
function TExec.ICallReturnType(signature: String): String;
var
  sepPos: Integer;
begin
  sepPos := signature.IndexOf('@'); //find position of '@'
  if sepPos < 1 then Exit('');
  case signature.Chars[sepPos-1] of
    '#':
    begin
      Result := '#';
      if (sepPos < 2) then Result := '';
    end;
    '$':
    begin
      Result := '$';
      if (sepPos < 2) then Result := '';
    end;
    else Result := 'n';
  end;
end;

procedure TExec.LoadSource(ls: TStringTokens);
var
  ok: Boolean;
  p: Integer;
  s: String;
  atk: TAsmToken;
  i, n: Integer;
begin
  strConst := ''; s := '';
  n := ls.count;
  FTotInsts := n; //used by property 'TotalASMInst'

  // PHASE 4: Always allocate to exact size needed (n+1 for END instruction)
  // This replaces the conditional allocation and ensures no wasted memory
  try
    SetLength(asmProg, n + 1);
  except
    on E:Exception do
    begin
      FErrorMessage := 'ERROR. Not enough memory for program execution: '+E.Message;
      ended := true;
      Exit;
    end;
  end;

  asmProg[n].token := atkEnd;
  asmProg[n].proc := fEnd;
  if n = 0 then Exit;
  for i := 0 to n - 1 do
  begin
    asmLexer.LoadLine(PChar(ls[i].Str));
    asmLexer.Advance(s, p, atk);
    asmProg[i].token := atk;
    asmProg[i].proc := TokenToFunc(atk);
    asmLexer.Advance(s, p, atk);
    if atk in [atkInteger, atkFloat] then
      asmProg[i].n := TUtils.StrToFloat2(s, ok)
    else
      asmProg[i].n := 0;

    if atk = atkInteger then
      asmProg[i].i := StrToInt(s)
    else
      asmProg[i].i := 0;

    if atk = atkString then
    begin
      asmProg[i].i := Length(strConst);
      strConst := strConst + s + #0;
    end;
  end;
end;

//Pop and discard
procedure TExec.Pop();
begin
  if STKP = 0 then
  begin
    RTError(rteStackUnderflow, atkNull);
    Exit;
  end;
  // NOTE: Do NOT clear StackMem[STKP] here! Many instructions (fAddS, fEQS,
  // fGES, fSubS, etc.) call Pop() to combine two stack values and then read
  // the old top-of-stack at StackMem[STKP+1] immediately after. Clearing
  // the string field here would destroy the operand before it can be used.
  Dec(STKP);
end;

//Pop a data cell (TAsmData) from stack. Uses "TypeStack" to validate the type
//of the popped information.
function TExec.PopAsmData(checkType: TExprKind): TAsmData;
begin
  //DEFENSIVE FIX: Check for underflow BEFORE reading the stack
  //This prevents returning garbage data and helps identify stack issues
  if STKP = 0 then
  begin
    Result.n := 0;
    Result.p := nil;
    Result.s := '';
    RTError(rteStackUnderflow, atkNull);
    Exit;
  end;
  Result := StackMem[STKP];
  if TypeStack[STKP] <> checkType then
  begin
    RTError(rteStackTypeMismatch, atkNull);
    Exit;
  end;
  Dec(STKP);
end;

//Push a data cell (TAsmdata) into the stack
procedure TExec.PushAsmData(const dt: TAsmData; st: TExprKind);
begin
  // CRITICAL FIX: Check BEFORE incrementing to prevent buffer overrun
  if STKP >= MAXSTACK - 1 then
  begin
    RTError(rteStackOverflow, atkNull);
    Exit;
  end;
  Inc(STKP);
  StackMem[STKP] := dt;
  TypeStack[STKP] := st;
end;

procedure TExec.RTError(msg: TRTErrors; unkInstr: TAsmToken; auxMsg: String);
var
  ErrMsg: array[TRTErrors] of String;
  ErrLine: String;
begin
  ErrMsg[rteStackOverflow] := 'Stack overflow';
  ErrMsg[rteStackUnderflow] := 'Stack underflow';
  ErrMsg[rteStackTypeMismatch] := 'Stack type mismatch';
  ErrMsg[rteInvalidParams] := 'Invalid parameters during instruction call';
  ErrMsg[rteDimIndexBound] := 'Index out of bounds';
  ErrMsg[rtePrintStackOverflow] := 'Print stack overflow';
  ErrMsg[rtePrintSyntaxMismatch] := 'PRINT syntax mismatch';
  ErrMsg[rteAuxStackTypeMismatch] := 'Type mismatch in auxiliary stack';
  ErrMsg[rteAuxStackOverflow] := 'Auxiliary stack overflow';
  ErrMsg[rteAuxStackUnderflow] := 'Auxiliary stack underflow';
  ErrMsg[rteDivisionByZero] := 'Division by zero';
  ErrMsg[rteUnknownInstr] := 'Unknown instruction';
  ErrMsg[rteStringSize] := 'Invalid string size';
  ErrMsg[rteUserMessage] := auxMsg;
  ErrLine := '*** RUNTIME ERROR ***' + System.SlineBreak + 'ASM[' + IntToStr(PRG_IP) + '] BP['+IntToStr(BASEP)+'] ' + 'Source[' + IntToStr(srcLine) + ']' +' - "' + ErrMsg[msg]+'"';

  if msg = rteUnknownInstr then
    ErrLine := ErrLine+' : unknown instruction:['+IntToStr(Integer(unkInstr))+']';
  FErrorMessage := ErrLine;
  ended := true;

  if Assigned(FPrintProc) then
    FPrintProc(PChar(ErrLine));
end;

procedure TExec.Stop();
begin
  ended := true;
end;

function TExec.TokenToFunc(tk: TAsmToken): TExeFunc;
begin
  Result := fNOp;
  case tk of
    atkPush: Result := fPush;
    atkInitFunc: Result := fInitFunc;
    atkPushC: Result := fPushC;
    atkPushS: Result := fPushS;
    atkPushCS: Result := fPushSC;
    atkPushPtr: Result := fPushPtr;
    atkPushPtrTag: Result := fPushPtrTag;
    atkPop: Result := fPop;
    atkAdd: Result := fAdd;
    atkSub: Result := fSub;
    atkMul: Result := fMul;
    atkDiv: Result := fDiv;
    atkMin: Result := fMin;
    atkMax: Result := fMax;
    atkPow: Result := fPow;
    atkInv: Result := fInv;
    atkMod: Result := fMod;
    atkGe: Result := fGE;
    atkGt: Result := fGT;
    atkLe: Result := fLE;
    atkLt: Result := fLT;
    atkNe: Result := fNE;
    atkEq: Result := fEQ;
    atkNot: Result := fNot;
    atkOr: Result := fAdd;
    atkAnd: Result := fMul;
    atkGes: Result := fGES;
    atkGts: Result := fGTS;
    atkLes: Result := fLES;
    atkLts: Result := fLTS;
    atkNes: Result := fNES;
    atkEqs: Result := fEQS;
    atkAdds: Result := fAddS;
    atkSubs: Result := fSubS;
    atkAddcrlfs: Result := fAddCRLFS;
    atkRead: Result := fRead;
    atkReadS: Result := fReadS;
    atkRefreshRate: Result := fRefreshRate;
    atkRestore: Result := fRestore;
    atkPopStore: Result := fPopStore;
    atkPopstoreS: Result := fPopStoreS;
    atkPopStorePtr: Result := fPopStorePtr;
    atkRetFunction: Result := fRetFunction;
    atkForcycle: Result := fForCycle;
    atkCallNear: Result := fCallNear;
    atkCallFar: Result := fCallFar;
    atkCallFarP: Result := fCallFarP;
    atkCallFarS: Result := fCallFarS;
    atkOnCallFar: Result := fOnCallFar;
    atkOnCallFarP: Result := fOnCallFarP;
    atkOnCallFarS: Result := fOnCallFarS;
    atkReturn: Result := fReturn;
    atkJump: Result := fJump;
    atkPopnCall: Result := fPopNCall;
    atkPopnjump: Result := fPopNJump;
    atkPrint: Result := fPrint;
    atkErr: Result := fErr;
    atkComma: Result := fComma;
    // FIX #15: Added atkPause to NOP list. Token was defined and recognized
    // by the asm lexer but unmapped, causing rteUnknownInstr if triggered.
    atkComment, atkNop, atkPause, atkInteger, atkEndIf, atkRepeat, atkEndFunction: Result := fNop;
    atkEnd: Result := fEnd;
    atkCls: Result := fCls;
    //atkFnAddress: Result := fFnAddr;
    atkIndirectCall: Result := fIndirectCall;
    atkPushAux: Result := fPushAuxStack;
    atkPushAuxS: Result := fPushAuxStackS;
    atkPopAux: Result := fPopAuxStack;
    atkPushAuxTOS: Result := fPushAuxTOS;
    atkInput: Result := fInput;
    atkInputS: Result := fInputS;
    //Debug instructions
    atkAssert: Result := fAssert;
    atkBreakpoint: Result := fBreakpoint;
    atkDump: Result := fDump;
    atkTrace: Result := fTrace;
    atkTraceOn: Result := fTraceOn;
    atkTraceOff: Result := fTraceOff;
    atkWatch: Result := fWatch;
    atkUnwatch: Result := fUnwatch;
  else
    RTError(rteUnknownInstr, tk);
  end;
end;

end.

