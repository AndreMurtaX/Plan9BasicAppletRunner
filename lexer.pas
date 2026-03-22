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
unit lexer;

interface

uses
  System.SysUtils, System.Character,
  UnitUtils;

const
  // Character sets for lexer validation
  validIdentChars: array[0..65] of char = ('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
                                           'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z',
                                           '0','1','2','3','4','5','6','7','8','9','_','$','#',':');
  identChars: array[0..26] of char = ('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','_');
  digitChars: array[0..9] of char = ('0','1','2','3','4','5','6','7','8','9');
  typeChars: array[0..1] of char = ('$','#');  // $ = String, # = Pointer

  // Memory allocation limits
  MAXINSTR = 100000;     // Maximum instructions allowed in a program
  INITINSTRSIZE = 1000;  // Initial allocation size for tokenized program

  // Numeric limits for integer type
  MAX_INTEGER_VALUE = 2147483647.0;  // Values above this become float

type
  TBasicLexer = class;

  //****************************************************************************
  // Types definitions
  // Begin
  //****************************************************************************
  //
  //BASIC tokens
  TBasToken = (
    {A}
    btkAnd, btkAmpersand, btkAssert, btkAt,
    {B}
    btkBreak, btkBreakPoint,
    {C}
    btkCall, btkCase, btkCharArray, btkCRLF,
    btkCls, btkColon, btkComma, btkContinue, btkCurlyClose, btkCurlyOpen,
    {D}
    btkData, btkDo, btkDoubleSquareClose, btkDoubleSquareOpen, btkDump,
    {E}
    btkElse, btkEnd, btkEndFor, btkEndFunction, btkEndIf, btkEndSelect,
    btkEndWhile, btkEqual,
    {F}
    btkFalse, btkFloat, btkFor, btkFunction,
    {G}
    btkGoto, btkGreater, btkGreaterEqual, btkGosub,
    {H}
    {I}
    btkIdentifier, btkIf, btkIndirectCallPtr, btkIndirectCallStr, btkInput,
    btkInteger,
    {J}
    btkJsonNull,
    {K}
    {L}
    btkLabel, btkLet, btkLocal, btkLoop, btkLower, btkLowerEqual,
    {M}
    btkMax, btkMin, btkMinus, btkMod,
    {N}
    btkNext, btkNone, btkNot, btkNotEqual, btkNull, btkNumFunction,
    {O}
    btkOn, btkOr,
    {P}
    btkPipe, btkPlus, btkPointerArray, btkPointerArrayStr, btkPointerArrayPtr, btkPointerFunction, btkPointerIdentifier, btkPower,
    btkPrint, btkPrintLn,
    {Q}
    {R}
    btkRem, btkRead, btkRepeat, btkReturn, btkRoundClose, btkRoundOpen,
    btkRefreshRate, btkRestore,
    {S}
    btkSelect, btkSemiColon, btkSlash, btkSquareClose, btkSquareOpen, btkStar,
    btkStep, btkStrArray, btkStrFunction, btkStrIdentifier,
    btkString, btkSymbol,
    {T}
    btkThen, btkTo, btkTrace, btkTraceOff, btkTraceOn, btkTrue,
    {U}
    btkUnknown, btkUntil, btkUnwatch,
    {V}
    {W}
    btkWatch, btkWhile
    {X}
    {Y}
    {Z}
  );

  //BASIC tokenized instructions
  TBasInstr = record
    id: TBasToken; //Token type
    pos, len: Integer; //position, length
    n: Extended; //Numeric constant value or string code for the token
  end;
  TBasInstrArray = array of TBasInstr;

  //***********
  //TBasicLexer
  //***********
  //
  //Breaks the BASIC source code in tokens
  //
  TBasicLexer = class(TObject)
  private
    FError: Boolean;
    FErrorMessage: String;
    prog: TBasInstrArray;
    IP, idx: Integer;
    pSource: PChar;
    tokCount: Cardinal; //Total of processed tokens
    //Distinguish identifiers from keywords
    function BasIdentKind(tokStr: String): TBasToken;
    //BASIC language tokenizer
    procedure BasGetToken(var tokenStr: String; var tokenPos, tokenLen: Integer; var tok: TBasToken);
  public
    constructor Create();
    destructor Destroy(); override;
    //Load and tokenize a BASIC program
    procedure LoadProg(source: PChar);
    procedure Advance(); //Advance one token
    procedure PutBack(); //get back to the anterior token
    function CurrS(): String; //String representation of token
    function CurrN(): Extended; //Numeric representation of token
    function CurrPos(): Integer; //Current position
    function CurrTok(): TBasToken; //Current token
    function PrevTok(): TBasToken; //Previous token
    function NextTok(): TBasToken; //Next token
    procedure GotoToken(n: Integer); //Goto a specific token index
    function TotalTokens: Int64; //Total of processed tokens
    function TokenInfo(n: Integer): TBasInstr; //Return the data about an expecific token

    property Error: Boolean read FError;
    property ErrorMessage: String read FErrorMessage;
    property CurrIP: Integer read IP;
  end;

implementation

{ TBasicLexer }

constructor TBasicLexer.Create();
begin
  inherited Create();

  FError := false; //No error during creation
  try
    SetLength(prog, INITINSTRSIZE+1); //Allocate initial size for the tokenized program
  except
    on E:Exception do
    begin
      FError := true;
      FErrorMessage := E.Message;
    end;
  end;
end;

destructor TBasicLexer.Destroy();
begin
  inherited Destroy();
end;

procedure TBasicLexer.Advance();
begin
  Inc(IP);
end;

procedure TBasicLexer.BasGetToken(var tokenStr: String; var tokenPos, tokenLen: Integer; var tok: TBasToken);
var
  d: Extended;
  ok: Boolean;
  iVal: Integer;
  escapeSequence: String;
  isEscaped: Boolean;

  // Função auxiliar para converter caractere escapado em seu valor real
  // Helper function to convert escaped character to its real value
  function ConvertEscapeSequence(ch: Char): String;
  begin
    case ch of
      '"': Result := '"';   // \"  -> "
      '\': Result := '\';   // \\  -> \
      'n': Result := #10;   // \n  -> newline (LF)
      'r': Result := #13;   // \r  -> carriage return (CR)
      't': Result := #9;    // \t  -> horizontal tab
      '0': Result := #0;    // \0  -> null character
      'b': Result := #8;    // \b  -> backspace
      'f': Result := #12;   // \f  -> form feed
      'v': Result := #11;   // \v  -> vertical tab
      'a': Result := #7;    // \a  -> alert/bell
      else Result := '\' + ch; // Invalid sequence, keep as-is
    end;
  end;

  function ValidIdentifier(const token: String): Boolean;
  var
    i: Integer;
    endToken: Boolean;
  begin
    Result := true;
    endToken := false;

    if not token.Chars[0].ToUpper().IsInArray(identChars) then
      Exit(false);

    if token.Length > 1 then
      for i := 1 to token.Length-1 do
      begin
        if token.Chars[i].IsInArray(typeChars) then
          endToken := true;
        if endToken and (i < token.Length-1) then
          Exit(false);
      end;
  end;

begin
  //Skip blanks
  while pSource[idx].IsInArray([#8,#9,#32]) do
    Inc(idx);
  tokenLen := 1; //token initial size
  tokenPos := idx; //token initial position
  case pSource[idx] of
    'A' .. 'Z', 'a' .. 'z', '_': //identifier / keyword
    begin
      tokenPos := idx;
      Inc(idx);
      while pSource[idx].IsInArray(validIdentChars) do
        Inc(idx); //inc idx

      tokenLen := idx - tokenPos; //calculate token length
      SetString(tokenStr, pSource+tokenPos, tokenLen); //update tokenStr

      case pSource[idx-1] of
        '$': tok := btkStrIdentifier; //ended with $, it's a string identifier
        '#': tok := btkPointerIdentifier; //ended with #, it's an pointer identifier
        ':': tok := btkLabel; //ended with a :, it's a label
        else
          tok := BasIdentKind(tokenStr); //or it's a identifier or command
      end;

      //Skip blanks
      while pSource[idx].IsInArray([#8,#9,#32]) do
        Inc(idx);

      if pSource[idx] = '(' then //If it's an identifier succeeded by '(', we have a subroutine
      begin
        case tok of
          btkIdentifier: // Identifier without an ending id char are float by default
          begin
            Inc(idx);
            tok := btkNumFunction;
            Exit();
          end;
          btkPointerIdentifier: //pointer
          begin
            Inc(idx);
            tok := btkPointerFunction;
            Exit();
          end;
          btkStrIdentifier: //String
          begin
            Inc(idx);
            tok := btkStrFunction;
            Exit();
          end;
        end;
      end
      else if (pSource[idx] = '[') then //If it's an identifier succeeded by '[', we have an array
      begin
        case tok of
          btkStrIdentifier: //String
          begin
            if pSource[idx-2] = '#' then
            begin
              Inc(idx);
              tok := btkPointerArrayStr;
            end
            else if pSource[idx+1] = '[' then // name$[[index]] is the char at the position in 'index'
            begin
              Inc(idx, 2);
              tok := btkCharArray;
            end
            else
            begin
              Inc(idx);
              tok := btkStrArray;
            end;
            Exit();
          end;
          btkPointerIdentifier:
          begin
            if pSource[idx-2] = '#' then
            begin
              Inc(idx);
              tok := btkPointerArrayPtr;
            end
            else
            begin
              Inc(idx);
              tok := btkPointerArray;
            end;
            Exit();
          end
          else
          begin
            Inc(idx);
            tok := btkUnknown;
            Exit();
          end;
        end;
      end
      else
      begin
        if not ValidIdentifier(tokenStr) then
          tok := btkUnknown;
      end;
    end;
    '0' .. '9', '.': //number
    begin
      d := 0; // Initialize to prevent "might not have been initialized" warning
      tokenPos := idx;
      Inc(idx);
      tok := btkInteger; //An Integer, at first
      while pSource[idx].IsInArray(['0','1','2','3','4','5','6','7','8','9','.']) do
      begin
        if pSource[idx] = '.' then
          tok := btkFloat; //if there is a '.' it's a floating point number
        Inc(idx);
      end;
      // CRITICAL FIX: Handle scientific notation properly
      if pSource[idx].IsInArray(['e','E']) then
      begin
        tok := btkFloat;
        Inc(idx); // Skip 'e' or 'E'
        // Handle optional sign after exponent
        if pSource[idx].IsInArray(['+','-']) then
          Inc(idx);
        // There must be at least one digit after exponent
        if not pSource[idx].IsInArray(['0','1','2','3','4','5','6','7','8','9']) then
        begin
          tok := btkUnknown;
        end
        else
        begin
          // Continue reading exponent digits
          while pSource[idx].IsInArray(['0','1','2','3','4','5','6','7','8','9']) do
            Inc(idx);
        end;
      end;
      tokenLen := idx - tokenPos;
      SetString(tokenStr, pSource + tokenPos, tokenLen);
      if pSource[tokenPos] = '.' then
      begin
        tok := btkFloat;
        //Allows interpretation of floating numbers started by the dot, like:
        // '.5' or '.9'
        tokenStr := '0' + tokenStr;
      end;
      if tok <> btkUnknown then
      begin
        d := TUtils.StrToFloat2(tokenStr, ok); //conversion
        if not ok then tok := btkUnknown; //not ok, returns unknown type
      end;
      if (tok = btkInteger) and ((pSource[idx] = 'b') or (pSource[idx] = 'B')) then
      begin
        Inc(idx);
        if TryStrToInt(tokenStr, iVal) and ((iVal >= 0) and (iVal <= 255))then
          tok := btkInteger {btkByte}
        else
          tok := btkUnknown;
      end;
      if (tok <> btkUnknown) and (d > MAX_INTEGER_VALUE) then tok := btkFloat; //it's a floating
    end;
    //If want to convert this project to a different platforms:
    //
    // end of line in MS-Windows: #13#10
    // in UNIX: #10
    // in OS-X: #13
    #10: //CRLF
    begin
      tok := btkCRLF;
      tokenStr := System.sLineBreak;
      tokenPos := idx;
      Inc(idx);
    end;
    #13: //CRLF
    begin
      tok := btkCRLF;
      tokenStr := System.sLineBreak;
      tokenPos := idx;
      Inc(idx);
      if pSource[idx] = #10 then
        Inc(idx);
    end;
    //Symbols
    '%', '&'..'-', '/', ':' .. '@', '[' .. '^', '{'..'~':
    begin
      tokenPos := idx;
      case pSource[idx] of
        #39: tok := btkRem;
        '|': tok := btkPipe;
        '@': tok := btkAt;
        '&': if pSource[idx+1] = '#' then
             begin
               Inc(idx);
               tok := btkIndirectCallPtr;
             end
             else if pSource[idx+1] = '$' then
             begin
               Inc(idx);
               tok := btkIndirectCallStr;
             end
             else tok := btkAmpersand;
        '=': tok := btkEqual;
        '(': tok := btkRoundOpen;
        ')': tok := btkRoundClose;
        '[': tok := btkSquareOpen;
        ']': if pSource[idx + 1] = ']' then
             begin
               Inc(idx);
               tok := btkDoubleSquareClose;
             end
             else tok := btkSquareClose;
        '{': tok := btkCurlyOpen;
        '}': tok := btkCurlyClose;
        ',': tok := btkComma;
        ';': tok := btkSemiColon;
        '*': tok := btkStar;
        '/': tok := btkSlash;
        '+': tok := btkPlus;
        ':': tok := btkColon;
        '^': tok := btkPower;
        '-': tok := btkMinus;
        '?': if pSource[idx + 1] = '>' then
             begin
               Inc(idx);
               tok := btkMax; //Example: (5 ?> 4) or (4 ?> 5) returns 5
             end
             else if pSource[idx + 1] = '<' then
             begin
               Inc(idx);
               tok := btkMin;  //Example: (5 ?< 4) or (4 ?< 5) returns 4
             end
             else
               tok := btkSymbol;
        '<': if pSource[idx + 1]  = '=' then
             begin
               Inc(idx);
               tok := btkLowerEqual; // lower equal '<='
             end
             else if pSource[idx + 1] = '>' then
             begin
               Inc(idx);
               tok := btkNotEqual; // difference '<>'
             end
             else
               tok := btkLower;    // lower '<'
        '>': if pSource[idx + 1] = '=' then
             begin
               Inc(idx);
               tok := btkGreaterEqual; // greater equal '>='
             end
             else
               tok := btkGreater; // greater '>'
        else
          tok := btkSymbol; //if none of above
      end;
      Inc(idx); //increment idx
      tokenLen := idx - tokenPos; //calculate token size
      SetString(tokenStr, pSource + tokenPos, tokenLen);
    end;
    '"': //It's a string constant
    begin
      tok := btkString;
      tokenStr := '';
      isEscaped := False;
      repeat
        case pSource[idx] of
          #0, #10, #13:
          begin
            Dec(idx);
            tok := btkUnknown;
            break;
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
              escapeSequence := ConvertEscapeSequence(pSource[idx]);
              tokenStr := tokenStr + escapeSequence;
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
      tokenLen := idx - tokenPos - 1;
    end;
    #0: //null = end of program
    begin
      tok := btkNull;
      tokenStr := '';
      tokenPos := idx;
    end;
    else
    begin //if none of the above tests were satisfied...
      tokenPos := idx;  //...token unknown
      Inc(idx); //increment idx
      tok := btkUnknown; //óbvio
      tokenLen := idx - tokenPos; //unknown token size
      SetString(tokenStr, pSource + tokenPos, tokenLen);
    end;
  end;
end;

function TBasicLexer.BasIdentKind(tokStr: String): TBasToken;
var
  HashCode: Integer;
begin
  Result := btkIdentifier;
  tokStr := UpperCase(tokStr);
  HashCode := TUtils.StringCode(tokStr);

  if (HashCode < 143) or (HashCode > 829) then
    Exit();

  case HashCode of
    143: if tokStr = 'IF' then Result := btkIf;
    147: if tokStr = 'DO' then Result := btkDo;
    157: if tokStr = 'ON' then Result := btkOn;
    161: if tokStr = 'OR' then Result := btkOr;
    163: if tokStr = 'TO' then Result := btkTo;
    211: if tokStr = 'AND' then Result := btkAnd;
    215: if tokStr = 'END' then Result := btkEnd;
    224: if tokStr = 'MOD' then Result := btkMod;
    228: if tokStr = 'REM' then Result := btkRem;
    226: if tokStr = 'CLS' then Result := btkCls;
    229: if tokStr = 'LET' then Result := btkLet;
    231: if tokStr = 'FOR' then Result := btkFor;
    241: if tokStr = 'NOT' then Result := btkNot;
    282: if tokStr = 'DATA' then Result := btkData;
    284:
    begin
      if tokStr = 'CALL' then Result := btkCall
      else if tokStr = 'CASE' then Result := btkCase
      else if tokStr = 'READ' then Result := btkRead;
    end;
    297: if tokStr = 'ELSE' then Result := btkElse;
    302: if tokStr = 'WEND' then Result := btkEndWhile;
    303: if tokStr = 'THEN' then Result := btkThen;
    310: if tokStr = 'DUMP' then Result := btkDump;
    313: if tokStr = 'GOTO' then Result := btkGoto;
    314: if tokStr = 'LOOP' then Result := btkLoop;
    315: if tokStr = 'NULL' then Result := btkJsonNull;
    316: if tokStr = 'STEP' then Result := btkStep;
    319: if tokStr = 'NEXT' then Result := btkNext;
    320: if tokStr = 'TRUE' then Result := btkTrue;
    357: if tokStr = 'BREAK' then Result := btkBreak;
    358: if tokStr = 'ENDIF' then Result := btkEndif;
    363:
    begin
      if tokStr = 'LOCAL' then Result := btkLocal
      else if tokStr = 'FALSE' then Result := btkFalse;
    end;
    367: if tokStr = 'TRACE' then Result := btkTrace;
    375: if tokStr = 'WATCH' then Result := btkWatch;
    377: if tokStr = 'WHILE' then Result := btkWhile;
    384: if tokStr = 'GOSUB' then Result := btkGosub;
    396: if tokStr = 'UNTIL' then Result := btkUntil;
    397: if tokStr = 'PRINT' then Result := btkPrint;
    400: if tokStr = 'INPUT' then Result := btkInput;
    446: if tokstr = 'ENDFOR' then Result := btkEndFor;
    448: if tokStr = 'SELECT' then Result := btkSelect;
    449: if tokStr = 'REPEAT' then Result := btkRepeat;
    466: if tokStr = 'ASSERT' then Result := btkAssert;
    480: if tokStr = 'RETURN' then Result := btkReturn;
    524: if tokStr = 'TRACEON' then Result := btkTraceOn;
    538: if tokStr = 'UNWATCH' then Result := btkUnwatch;
    548: if tokStr = 'RESTORE' then Result := btkRestore;
    551: IF TOKsTR = 'PRINTLN' then Result := btkPrintLn;
    586: if tokStr = 'TRACEOFF' then Result := btkTraceOff;
    592: if tokStr = 'ENDWHILE' then Result := btkEndWhile;
    613: if tokStr = 'CONTINUE' then Result := btkContinue;
    614: if tokStr = 'FUNCTION' then Result := btkFunction;
    663: if tokStr = 'ENDSELECT' then Result := btkEndSelect;
    751: if tokStr = 'BREAKPOINT' then Result := btkBreakpoint;
    827: if tokStr = 'REFRESHRATE' then Result := btkRefreshRate;
    829: if tokStr = 'ENDFUNCTION' then Result := btkEndFunction;
  end;
end;

function TBasicLexer.CurrN(): Extended;
begin
  Result := prog[IP].n; //Numeric constant value or string code for the token
end;

function TBasicLexer.CurrPos(): Integer;
begin
  Result := prog[IP].pos; //token position
end;

function TBasicLexer.CurrS(): String;
begin
  SetString(Result, (pSource + prog[IP].pos), prog[IP].len);
end;

function TBasicLexer.CurrTok(): TBasToken;
begin
  Result := TBasToken(prog[IP].id); //token id
end;

procedure TBasicLexer.GotoToken(n: Integer);
begin
  if (n < 0) then
    Exit();
  IP := n;
end;

procedure TBasicLexer.LoadProg(source: PChar);
var
  ok: Boolean;
  data: String;
  id: TBasToken;
  tokPos, tokLen: Integer;
  skipComments: Boolean;
  instruction: Integer;
begin
  pSource := source;
  instruction := INITINSTRSIZE;
  try
    SetLength(prog, instruction + 1);
  except
    on E:Exception do
    begin
      FError := true;
      FErrorMessage := E.Message;
    end;
  end;
  skipComments := False;
  idx := 0;
  IP := 1; //Instruction pointer
  tokCount := 0; //incremented after each token read
  repeat
    //Get next token
    BasGetToken(data, tokPos, tokLen, id);
    Inc(tokCount);
    if id = btkRem then
      skipComments := True; //If it is a comment, just ignore it.
//    if skipComments then
//    begin
//      // Only CRLF ends a comment, NOT colon
//      if id = btkCRLF then
//        skipComments := False;
//      Continue;  // Always skip tokens while in comment mode
//    end;
    if skipComments then
    begin
      if id = btkCRLF then
        skipComments := False
      else
        Continue;  // Only skip non-CRLF tokens
    end;

    prog[IP].id := id;
    prog[IP].pos := tokPos;
    prog[IP].len := tokLen; //Keep the token length
    if (id = btkInteger) or (id = btkFloat) then //If a numeric constant...
      prog[IP].n := TUtils.StrToFloat2(data, ok) //...store the value in 'n'...
    else
      prog[IP].n := TUtils.StringCode(UpperCase(data)); //...otherwise, keeps the string code, the string must be in "uppercase"
    Inc(IP); //Next instruction pointer
    if IP = instruction then //test the need to increase "prog" area
    begin
      instruction := instruction * 2; //Double the space
      try
        SetLength(prog, (instruction + 1)); //"Reallocate" 'prog' with the increased space
      except
        on E:Exception do
        begin
          FError := true;
          FErrorMessage := E.Message;
        end;
      end;
    end;
  until (id = btkNull) or (IP = MAXINSTR) or FError;

  //Keep end of program representation
  prog[IP].id := btkNull;
  prog[IP].pos := tokPos;

  // PHASE 4: Trim excess memory - array was over-allocated during parsing
  // IP+1 is the actual number of tokens used (including the null terminator)
  if (not FError) and (IP + 1 < Length(prog)) then
  begin
    try
      SetLength(prog, IP + 1);
    except
      // Ignore trimming errors - not critical, just optimization
    end;
  end;

  IP := 0; //reset ProgIP
  prog[0].id := btkCRLF; //Just formality
  GotoToken(0); //Position back to the first token after the list is built
end;

function TBasicLexer.NextTok(): TBasToken;
begin
  Result := TBasToken(prog[IP + 1].id);
end;

function TBasicLexer.PrevTok(): TBasToken;
begin
  if IP > 0 then
    Result := TBasToken(prog[IP - 1].id)
  else
    Result := btkNone;
end;

procedure TBasicLexer.PutBack();
begin
  Dec(IP);
end;

function TBasicLexer.TokenInfo(n: Integer): TBasInstr;
begin
  if (n < 0) then
    Exit();
  Result := prog[n];
end;

function TBasicLexer.TotalTokens(): Int64;
begin
  Result := tokCount;
end;

end.

