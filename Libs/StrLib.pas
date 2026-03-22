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
unit StrLib;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.StrUtils, System.Rtti,
  System.Character,
  FMX.Types, FMX.Platform, FMX.Forms,
  exec, UnitUtils;

procedure RegisterStrFuncs(Lib: TFunctionsDictionary);

implementation

var
  valcode: Integer;
  lastError: Integer;  // Error code for last operation (0 = success)

const
  ERR_NONE = 0;
  ERR_INDEX_OUT_OF_BOUNDS = 1;
  ERR_INVALID_ARGUMENT = 2;
  ERR_STRING_EMPTY = 3;
  ERR_FILE_ERROR = 4;
  ERR_CLIPBOARD_ERROR = 5;

//----------------------------------------------------------
// Helper functions
//----------------------------------------------------------

// Converts encoding name string to TEncoding object
// Supported names: utf8, utf7, ascii, ansi, unicode, unicode-be
// Default: UTF-8 (for maximum compatibility)
function ParseEncoding(const EncodingName: String): TEncoding;
var
  LowerName: String;
begin
  LowerName := EncodingName.ToLower().Trim();

  if (LowerName = 'utf7') or (LowerName = 'utf-7') then
    Result := TEncoding.UTF7
  else if (LowerName = 'utf8') or (LowerName = 'utf-8') then
    Result := TEncoding.UTF8
  else if LowerName = 'ansi' then
    Result := TEncoding.ANSI
  else if LowerName = 'ascii' then
    Result := TEncoding.ASCII
  else if (LowerName = 'big endian unicode') or (LowerName = 'utf-16be') then
    Result := TEncoding.BigEndianUnicode
  else if (LowerName = 'unicode') or (LowerName = 'utf-16') or (LowerName = 'utf-16le') then
    Result := TEncoding.Unicode
  else
    Result := TEncoding.UTF8; // Default to UTF-8 (modern standard)
end;

// Converts TEncoding object to standardized name string
function GetEncodingName(Encoding: TEncoding): String;
begin
  if Encoding = TEncoding.UTF7 then
    Result := 'utf-7'
  else if Encoding = TEncoding.UTF8 then
    Result := 'utf-8'
  else if Encoding = TEncoding.ANSI then
    Result := 'ansi'
  else if Encoding = TEncoding.ASCII then
    Result := 'ascii'
  else if Encoding = TEncoding.BigEndianUnicode then
    Result := 'utf-16be'
  else if Encoding = TEncoding.Unicode then
    Result := 'utf-16le'
  else
    Result := Encoding.EncodingName.ToLower(); // Default
end;

function ClampToInt(Value: Extended): Integer;
begin
  if Value < Low(Integer) then
    Result := Low(Integer)
  else if Value > High(Integer) then
    Result := High(Integer)
  else
    Result := System.Trunc(Value);
end;

//----------------------------------------------------------
// Error handling function
//----------------------------------------------------------

function n_strerror(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := lastError;
end;

//----------------------------------------------------------
// String library methods
//----------------------------------------------------------

function s_lcase(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.LowerCase(Args[0].s);
end;

function s_alcase(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.AnsiLowerCase(Args[0].s);
end;

function s_ucase(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.UpperCase(Args[0].s);
end;

function s_aucase(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.AnsiUpperCase(Args[0].s);
end;

function s_ltrim(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.TrimLeft(Args[0].s);
end;

function s_rtrim(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.TrimRight(Args[0].s);
end;

// trim$@$ - Trim both sides
function s_trim(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.Trim(Args[0].s);
end;

// NEW: proper$@$ - Capitalize first letter of each word (title case)
function s_proper(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
  ResultStr: String;
  NewWord: Boolean;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.s := '';
    Exit;
  end;

  ResultStr := Args[0].s.ToLower;
  NewWord := True;

  for i := 1 to ResultStr.Length do
  begin
    c := ResultStr[i];
    if c.IsLetter then
    begin
      if NewWord then
      begin
        ResultStr[i] := c.ToUpper;
        NewWord := False;
      end;
    end
    else if c.IsWhiteSpace or (c = '-') or (c = '''') then
    begin
      NewWord := True;
    end;
  end;

  Result.s := ResultStr;
end;

// NEW: swapcase$@$ - Swap uppercase to lowercase and vice versa
function s_swapcase(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
  ResultStr: String;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.s := '';
    Exit;
  end;

  ResultStr := Args[0].s;

  for i := 1 to ResultStr.Length do
  begin
    c := ResultStr[i];
    if c.IsUpper then
      ResultStr[i] := c.ToLower
    else if c.IsLower then
      ResultStr[i] := c.ToUpper;
  end;

  Result.s := ResultStr;
end;

function s_chr(var Args: Array of TAsmData): TAsmData;
var
  CharCode: Integer;
begin
  lastError := ERR_NONE;
  CharCode := ClampToInt(Args[0].n);

  // Validate ASCII/Unicode range (0-65535 for wide chars)
  if (CharCode < 0) or (CharCode > 65535) then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Result.s := '';
    Exit;
  end;

  Result.s := Chr(CharCode);
end;

function s_chrget(var Args: Array of TAsmData): TAsmData;
var
  Index: Integer;
begin
  lastError := ERR_NONE;
  Result.s := '';

  if Args[0].s.Length = 0 then
  begin
    lastError := ERR_STRING_EMPTY;
    Exit;
  end;

  Index := ClampToInt(Args[1].n);

  // Bounds check (0-based indexing)
  if (Index < 0) or (Index > Args[0].s.Length - 1) then
  begin
    lastError := ERR_INDEX_OUT_OF_BOUNDS;
    Exit;
  end;

  Result.s := Args[0].s[Index + 1];
end;

function s_chrset(var Args: Array of TAsmData): TAsmData;
var
  Index: Integer;
begin
  lastError := ERR_NONE;
  Result.s := Args[0].s;

  if Args[0].s.Length = 0 then
  begin
    lastError := ERR_STRING_EMPTY;
    Exit;
  end;

  Index := ClampToInt(Args[1].n);

  // Bounds check
  if (Index < 0) or (Index > Args[0].s.Length - 1) then
  begin
    lastError := ERR_INDEX_OUT_OF_BOUNDS;
    Exit;
  end;

  // Check replacement string is not empty
  if Args[2].s.Length = 0 then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;

  Result.s[Index + 1] := Args[2].s.Chars[0];
end;

function s_hex(var Args: Array of TAsmData): TAsmData;
var
  IntVal: Int64;
begin
  lastError := ERR_NONE;
  IntVal := System.Trunc(Args[0].n);

  // Handle negative numbers
  if IntVal < 0 then
    Result.s := '-' + System.SysUtils.IntToHex(-IntVal, 1)
  else
    Result.s := System.SysUtils.IntToHex(IntVal, 1);
end;

// hex$@nn - Hex with specified minimum digits
function s_hex2(var Args: Array of TAsmData): TAsmData;
var
  IntVal: Int64;
  Digits: Integer;
begin
  lastError := ERR_NONE;
  IntVal := System.Trunc(Args[0].n);
  Digits := ClampToInt(Args[1].n);

  if Digits < 1 then Digits := 1;
  if Digits > 16 then Digits := 16;

  if IntVal < 0 then
    Result.s := '-' + System.SysUtils.IntToHex(-IntVal, Digits)
  else
    Result.s := System.SysUtils.IntToHex(IntVal, Digits);
end;

function s_oct(var Args: Array of TAsmData): TAsmData;
var
  IntVal: Int64;
  rest: Integer;
  oct: String;
  IsNegative: Boolean;
begin
  lastError := ERR_NONE;
  oct := '';
  IntVal := System.Trunc(Args[0].n);

  // Handle zero
  if IntVal = 0 then
  begin
    Result.s := '0';
    Exit;
  end;

  // Handle negative
  IsNegative := IntVal < 0;
  if IsNegative then IntVal := -IntVal;

  while IntVal <> 0 do
  begin
    rest := IntVal mod 8;
    IntVal := IntVal div 8;
    oct := System.SysUtils.IntToStr(rest) + oct;
  end;

  if IsNegative then
    Result.s := '-' + oct
  else
    Result.s := oct;
end;

function s_bin(var Args: Array of TAsmData): TAsmData;
var
  IntVal: Int64;
  bin: String;
  IsNegative: Boolean;
begin
  lastError := ERR_NONE;
  bin := '';
  IntVal := System.Trunc(Args[0].n);

  // Handle zero
  if IntVal = 0 then
  begin
    Result.s := '0';
    Exit;
  end;

  // Handle negative
  IsNegative := IntVal < 0;
  if IsNegative then IntVal := -IntVal;

  while IntVal > 0 do
  begin
    if (IntVal and 1) = 1 then
      bin := '1' + bin
    else
      bin := '0' + bin;
    IntVal := IntVal shr 1;
  end;

  if IsNegative then
    Result.s := '-' + bin
  else
    Result.s := bin;
end;

function s_str(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.SysUtils.FloatToStr(Args[0].n);
end;

// str$@nn - Number to string with decimal places (locale-aware)
function s_str2(var Args: Array of TAsmData): TAsmData;
var
  Decimals: Integer;
begin
  lastError := ERR_NONE;
  Decimals := ClampToInt(Args[1].n);
  if Decimals < 0 then Decimals := 0;
  if Decimals > 18 then Decimals := 18;

  Result.s := System.SysUtils.FloatToStrF(Args[0].n, ffFixed, 18, Decimals);
end;

// stri$@n - Number to string (invariant - always uses period)
function s_stri(var Args: Array of TAsmData): TAsmData;
var
  InvariantFormat: TFormatSettings;
begin
  lastError := ERR_NONE;
  InvariantFormat := TFormatSettings.Create('en-US');
  InvariantFormat.DecimalSeparator := '.';
  Result.s := System.SysUtils.FloatToStr(Args[0].n, InvariantFormat);
end;

// stri$@nn - Number to string with decimal places (invariant - always uses period)
function s_stri2(var Args: Array of TAsmData): TAsmData;
var
  Decimals: Integer;
  InvariantFormat: TFormatSettings;
begin
  lastError := ERR_NONE;
  Decimals := ClampToInt(Args[1].n);
  if Decimals < 0 then Decimals := 0;
  if Decimals > 18 then Decimals := 18;

  InvariantFormat := TFormatSettings.Create('en-US');
  InvariantFormat.DecimalSeparator := '.';
  Result.s := System.SysUtils.FloatToStrF(Args[0].n, ffFixed, 18, Decimals, InvariantFormat);
end;

// mid$@$n - Get substring from position to end
function s_mid(var Args: Array of TAsmData): TAsmData;
var
  StartPos: Integer;
  StrLen: Integer;
begin
  lastError := ERR_NONE;
  StrLen := Args[0].s.Length;
  StartPos := ClampToInt(Args[1].n);

  // Handle empty string
  if StrLen = 0 then
  begin
    Result.s := '';
    Exit;
  end;

  // Clamp start position to valid range
  if StartPos < 0 then StartPos := 0;
  if StartPos >= StrLen then
  begin
    Result.s := '';
    Exit;
  end;

  Result.s := Args[0].s.Substring(StartPos, StrLen - StartPos);
end;

// mid$@$nn - Get substring from position with length
function s_mid2(var Args: Array of TAsmData): TAsmData;
var
  StartPos, Length: Integer;
  StrLen: Integer;
begin
  lastError := ERR_NONE;
  StrLen := Args[0].s.Length;
  StartPos := ClampToInt(Args[1].n);
  Length := ClampToInt(Args[2].n);

  // Handle empty string or zero/negative length
  if (StrLen = 0) or (Length <= 0) then
  begin
    Result.s := '';
    Exit;
  end;

  // Clamp start position
  if StartPos < 0 then StartPos := 0;
  if StartPos >= StrLen then
  begin
    Result.s := '';
    Exit;
  end;

  // Clamp length to remaining characters
  if StartPos + Length > StrLen then
    Length := StrLen - StartPos;

  Result.s := Args[0].s.Substring(StartPos, Length);
end;

function s_ltab(var Args: Array of TAsmData): TAsmData;
var
  TotalWidth, ContentLen, PadLen: Integer;
  TrimmedStr: String;
begin
  lastError := ERR_NONE;
  TrimmedStr := Args[0].s.Trim();
  ContentLen := TrimmedStr.Length;
  TotalWidth := ClampToInt(Args[1].n);

  // Calculate padding (ensure non-negative)
  PadLen := TotalWidth - ContentLen;
  if PadLen < 0 then PadLen := 0;

  Result.s := System.StringOfChar(' ', PadLen) + TrimmedStr;
end;

function s_rtab(var Args: Array of TAsmData): TAsmData;
var
  TotalWidth, ContentLen, PadLen: Integer;
  TrimmedStr: String;
begin
  lastError := ERR_NONE;
  TrimmedStr := Args[0].s.Trim();
  ContentLen := TrimmedStr.Length;
  TotalWidth := ClampToInt(Args[1].n);

  PadLen := TotalWidth - ContentLen;
  if PadLen < 0 then PadLen := 0;

  Result.s := TrimmedStr + System.StringOfChar(' ', PadLen);
end;

function s_lfill(var Args: Array of TAsmData): TAsmData;
var
  TotalWidth, ContentLen, PadLen: Integer;
  FillChar: Char;
  TrimmedStr: String;
begin
  lastError := ERR_NONE;
  TrimmedStr := Args[0].s.Trim();
  ContentLen := TrimmedStr.Length;
  TotalWidth := ClampToInt(Args[1].n);
  FillChar := System.Chr(ClampToInt(Args[2].n) and $FFFF);

  PadLen := TotalWidth - ContentLen;
  if PadLen < 0 then PadLen := 0;

  Result.s := System.StringOfChar(FillChar, PadLen) + TrimmedStr;
end;

function s_rfill(var Args: Array of TAsmData): TAsmData;
var
  TotalWidth, ContentLen, PadLen: Integer;
  FillChar: Char;
  TrimmedStr: String;
begin
  lastError := ERR_NONE;
  TrimmedStr := Args[0].s.Trim();
  ContentLen := TrimmedStr.Length;
  TotalWidth := ClampToInt(Args[1].n);
  FillChar := System.Chr(ClampToInt(Args[2].n) and $FFFF);

  PadLen := TotalWidth - ContentLen;
  if PadLen < 0 then PadLen := 0;

  Result.s := TrimmedStr + System.StringOfChar(FillChar, PadLen);
end;

// left$@$n - Get n characters from left
function s_left(var Args: Array of TAsmData): TAsmData;
var
  Count, StrLen: Integer;
begin
  lastError := ERR_NONE;
  StrLen := Args[0].s.Length;
  Count := ClampToInt(Args[1].n);

  // Handle edge cases
  if (StrLen = 0) or (Count <= 0) then
  begin
    Result.s := '';
    Exit;
  end;

  // Clamp to string length
  if Count > StrLen then Count := StrLen;

  Result.s := Args[0].s.SubString(0, Count);
end;

// left$@$ - Get first character
function s_left1(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if Args[0].s.Length = 0 then
  begin
    Result.s := '';
    Exit;
  end;
  Result.s := Args[0].s.SubString(0, 1);
end;

// right$@$n - Get n characters from right
function s_right(var Args: Array of TAsmData): TAsmData;
var
  Count, StrLen: Integer;
begin
  lastError := ERR_NONE;
  StrLen := Args[0].s.Length;
  Count := ClampToInt(Args[1].n);

  if (StrLen = 0) or (Count <= 0) then
  begin
    Result.s := '';
    Exit;
  end;

  if Count > StrLen then Count := StrLen;

  Result.s := Args[0].s.SubString(StrLen - Count, Count);
end;

// right$@$ - Get last character
function s_right1(var Args: Array of TAsmData): TAsmData;
var
  StrLen: Integer;
begin
  lastError := ERR_NONE;
  StrLen := Args[0].s.Length;
  if StrLen = 0 then
  begin
    Result.s := '';
    Exit;
  end;
  Result.s := Args[0].s.SubString(StrLen - 1, 1);
end;

// NEW: insert$@$$n - Insert string at position (0-based)
function s_insert(var Args: Array of TAsmData): TAsmData;
var
  SourceStr, InsertStr: String;
  Position, StrLen: Integer;
begin
  lastError := ERR_NONE;

  SourceStr := Args[0].s;
  InsertStr := Args[1].s;
  Position := ClampToInt(Args[2].n);
  StrLen := SourceStr.Length;

  // Clamp position
  if Position < 0 then Position := 0;
  if Position > StrLen then Position := StrLen;

  // Build result
  Result.s := SourceStr.Substring(0, Position) + InsertStr + SourceStr.Substring(Position);
end;

// NEW: delete$@$nn - Delete characters at position (0-based)
function s_delete(var Args: Array of TAsmData): TAsmData;
var
  SourceStr: String;
  Position, Count, StrLen: Integer;
begin
  lastError := ERR_NONE;

  SourceStr := Args[0].s;
  Position := ClampToInt(Args[1].n);
  Count := ClampToInt(Args[2].n);
  StrLen := SourceStr.Length;

  // Handle edge cases
  if (StrLen = 0) or (Count <= 0) then
  begin
    Result.s := SourceStr;
    Exit;
  end;

  // Clamp position
  if Position < 0 then Position := 0;
  if Position >= StrLen then
  begin
    Result.s := SourceStr;
    Exit;
  end;

  // Clamp count
  if Position + Count > StrLen then
    Count := StrLen - Position;

  // Build result
  Result.s := SourceStr.Substring(0, Position) + SourceStr.Substring(Position + Count);
end;

// NEW: center$@$n - Center string in field of given width
function s_center(var Args: Array of TAsmData): TAsmData;
var
  SourceStr: String;
  Width, StrLen, TotalPad, LeftPad, RightPad: Integer;
begin
  lastError := ERR_NONE;

  SourceStr := Args[0].s;
  Width := ClampToInt(Args[1].n);
  StrLen := SourceStr.Length;

  // If string is already >= width, return as-is
  if StrLen >= Width then
  begin
    Result.s := SourceStr;
    Exit;
  end;

  TotalPad := Width - StrLen;
  LeftPad := TotalPad div 2;
  RightPad := TotalPad - LeftPad;

  Result.s := System.StringOfChar(' ', LeftPad) + SourceStr + System.StringOfChar(' ', RightPad);
end;

// NEW: center$@$nn - Center string in field with custom fill character
function s_center2(var Args: Array of TAsmData): TAsmData;
var
  SourceStr: String;
  Width, StrLen, TotalPad, LeftPad, RightPad: Integer;
  FillChar: Char;
begin
  lastError := ERR_NONE;

  SourceStr := Args[0].s;
  Width := ClampToInt(Args[1].n);
  FillChar := System.Chr(ClampToInt(Args[2].n) and $FFFF);
  StrLen := SourceStr.Length;

  // If string is already >= width, return as-is
  if StrLen >= Width then
  begin
    Result.s := SourceStr;
    Exit;
  end;

  TotalPad := Width - StrLen;
  LeftPad := TotalPad div 2;
  RightPad := TotalPad - LeftPad;

  Result.s := System.StringOfChar(FillChar, LeftPad) + SourceStr + System.StringOfChar(FillChar, RightPad);
end;

function n_len(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.n := Args[0].s.Length;
end;

function n_asc(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if Args[0].s = '' then
  begin
    lastError := ERR_STRING_EMPTY;
    Result.n := 0;
  end
  else
    Result.n := System.Ord(Args[0].s.Chars[0]);
end;

function n_val(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  System.Val(Args[0].s, Result.n, valcode);
  if valcode <> 0 then
    lastError := ERR_INVALID_ARGUMENT;
end;

function n_valcode(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := valcode;
end;

// NEW: isnumeric@$ - Check if string represents a valid number
function n_isnumeric(var Args: Array of TAsmData): TAsmData;
var
  TestVal: Extended;
  Code: Integer;
  TrimStr: String;
begin
  lastError := ERR_NONE;
  TrimStr := Trim(Args[0].s);

  if TrimStr.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  System.Val(TrimStr, TestVal, Code);
  if Code = 0 then
    Result.n := 1
  else
    Result.n := 0;
end;

// NEW: isalpha@$ - Check if string contains only alphabetic characters
function n_isalpha(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  for i := 0 to Args[0].s.Length - 1 do
  begin
    c := Args[0].s.Chars[i];
    if not c.IsLetter then
    begin
      Result.n := 0;
      Exit;
    end;
  end;

  Result.n := 1;
end;

// NEW: isalnum@$ - Check if string contains only alphanumeric characters
function n_isalnum(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  for i := 0 to Args[0].s.Length - 1 do
  begin
    c := Args[0].s.Chars[i];
    if not c.IsLetterOrDigit then
    begin
      Result.n := 0;
      Exit;
    end;
  end;

  Result.n := 1;
end;

// NEW: isdigits@$ - Check if string contains only digits (0-9)
function n_isdigits(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  for i := 0 to Args[0].s.Length - 1 do
  begin
    c := Args[0].s.Chars[i];
    if not c.IsDigit then
    begin
      Result.n := 0;
      Exit;
    end;
  end;

  Result.n := 1;
end;

// NEW: isspace@$ - Check if string contains only whitespace
function n_isspace(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  for i := 0 to Args[0].s.Length - 1 do
  begin
    c := Args[0].s.Chars[i];
    if not c.IsWhiteSpace then
    begin
      Result.n := 0;
      Exit;
    end;
  end;

  Result.n := 1;
end;

// NEW: islower@$ - Check if all alphabetic chars are lowercase
function n_islower(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
  hasLetter: Boolean;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  hasLetter := False;
  for i := 0 to Args[0].s.Length - 1 do
  begin
    c := Args[0].s.Chars[i];
    if c.IsLetter then
    begin
      hasLetter := True;
      if c.IsUpper then
      begin
        Result.n := 0;
        Exit;
      end;
    end;
  end;

  // Return 1 only if there's at least one letter and all are lowercase
  if hasLetter then
    Result.n := 1
  else
    Result.n := 0;
end;

// NEW: isupper@$ - Check if all alphabetic chars are uppercase
function n_isupper(var Args: Array of TAsmData): TAsmData;
var
  i: Integer;
  c: Char;
  hasLetter: Boolean;
begin
  lastError := ERR_NONE;

  if Args[0].s.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  hasLetter := False;
  for i := 0 to Args[0].s.Length - 1 do
  begin
    c := Args[0].s.Chars[i];
    if c.IsLetter then
    begin
      hasLetter := True;
      if c.IsLower then
      begin
        Result.n := 0;
        Exit;
      end;
    end;
  end;

  // Return 1 only if there's at least one letter and all are uppercase
  if hasLetter then
    Result.n := 1
  else
    Result.n := 0;
end;

// instr@$$ - Find position of substring (0-based, -1 if not found)
function n_instr(var Args: Array of TAsmData): TAsmData;
var
  Pos: Integer;
begin
  lastError := ERR_NONE;
  Pos := System.Pos(Args[1].s, Args[0].s);
  if Pos = 0 then
    Result.n := Pos  // Not found
  else
    Result.n := 1;  // substring in string
end;

// instr@$$n - Find position of substring starting from position
function n_instr2(var Args: Array of TAsmData): TAsmData;
var
  Pos, StartPos: Integer;
  SearchIn: String;
begin
  lastError := ERR_NONE;
  StartPos := ClampToInt(Args[2].n);

  if (StartPos < 0) or (StartPos >= Args[0].s.Length) then
  begin
    Result.n := -1;
    Exit;
  end;

  // Search from the specified position
  SearchIn := Args[0].s.Substring(StartPos);
  Pos := System.Pos(Args[1].s, SearchIn);

  if Pos = 0 then
    Result.n := -1
  else
    Result.n := StartPos + Pos - 1;  // Adjust to original string position (0-based)
end;

// NEW: instrrev@$$ - Find LAST position of substring (0-based, -1 if not found)
function n_instrrev(var Args: Array of TAsmData): TAsmData;
var
  SourceStr, FindStr: String;
  SourceLen, FindLen, i: Integer;
begin
  lastError := ERR_NONE;
  Result.n := -1;

  SourceStr := Args[0].s;
  FindStr := Args[1].s;
  SourceLen := SourceStr.Length;
  FindLen := FindStr.Length;

  // Handle edge cases
  if (SourceLen = 0) or (FindLen = 0) or (FindLen > SourceLen) then
    Exit;

  // Search from the end
  for i := SourceLen - FindLen downto 0 do
  begin
    if SourceStr.Substring(i, FindLen) = FindStr then
    begin
      Result.n := i;
      Exit;
    end;
  end;
end;

// NEW: instrrev@$$n - Find LAST position of substring starting from position (searching backwards)
function n_instrrev2(var Args: Array of TAsmData): TAsmData;
var
  SourceStr, FindStr: String;
  SourceLen, FindLen, StartPos, i: Integer;
begin
  lastError := ERR_NONE;
  Result.n := -1;

  SourceStr := Args[0].s;
  FindStr := Args[1].s;
  StartPos := ClampToInt(Args[2].n);
  SourceLen := SourceStr.Length;
  FindLen := FindStr.Length;

  // Handle edge cases
  if (SourceLen = 0) or (FindLen = 0) or (FindLen > SourceLen) then
    Exit;

  // Clamp start position
  if StartPos < 0 then StartPos := 0;
  if StartPos > SourceLen - FindLen then StartPos := SourceLen - FindLen;

  // Search backwards from start position
  for i := StartPos downto 0 do
  begin
    if SourceStr.Substring(i, FindLen) = FindStr then
    begin
      Result.n := i;
      Exit;
    end;
  end;
end;

// NEW: countstr@$$ - Count occurrences of substring (case-sensitive)
function n_countstr(var Args: Array of TAsmData): TAsmData;
var
  SourceStr, FindStr: String;
  SourceLen, FindLen, Count, Pos: Integer;
begin
  lastError := ERR_NONE;
  Result.n := 0;

  SourceStr := Args[0].s;
  FindStr := Args[1].s;
  SourceLen := SourceStr.Length;
  FindLen := FindStr.Length;

  // Handle edge cases
  if (SourceLen = 0) or (FindLen = 0) or (FindLen > SourceLen) then
    Exit;

  Count := 0;
  Pos := System.Pos(FindStr, SourceStr);

  while Pos > 0 do
  begin
    Inc(Count);
    SourceStr := Copy(SourceStr, Pos + FindLen, Length(SourceStr));
    Pos := System.Pos(FindStr, SourceStr);
  end;

  Result.n := Count;
end;

// NEW: strcmp@$$ - Compare two strings, returns -1, 0, or 1 (case-sensitive)
function n_strcmp(var Args: Array of TAsmData): TAsmData;
var
  cmp: Integer;
begin
  lastError := ERR_NONE;
  cmp := System.SysUtils.CompareStr(Args[0].s, Args[1].s);
  if cmp < 0 then
    Result.n := -1
  else if cmp > 0 then
    Result.n := 1
  else
    Result.n := 0;
end;

// NEW: strcmpi@$$ - Compare two strings, returns -1, 0, or 1 (case-insensitive)
function n_strcmpi(var Args: Array of TAsmData): TAsmData;
var
  cmp: Integer;
begin
  lastError := ERR_NONE;
  cmp := System.SysUtils.CompareText(Args[0].s, Args[1].s);
  if cmp < 0 then
    Result.n := -1
  else if cmp > 0 then
    Result.n := 1
  else
    Result.n := 0;
end;

function n_containsstr(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if System.StrUtils.ContainsStr(Args[0].s, Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

function n_containstext(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if System.StrUtils.ContainsText(Args[0].s, Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

function s_dupestring(var Args: Array of TAsmData): TAsmData;
var
  Count: Integer;
begin
  lastError := ERR_NONE;
  Count := ClampToInt(Args[1].n);

  if Count < 0 then Count := 0;
  if Count > 1000000 then Count := 1000000;  // Reasonable limit

  Result.s := System.StrUtils.DupeString(Args[0].s, Count);
end;

function n_endsstr(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if System.StrUtils.EndsStr(Args[0].s, Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

function n_endstext(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if System.StrUtils.EndsText(Args[0].s, Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

function s_replacestr(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.StrUtils.ReplaceStr(Args[0].s, Args[1].s, Args[2].s);
end;

function s_replacetext(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.StrUtils.ReplaceText(Args[0].s, Args[1].s, Args[2].s);
end;

function s_reversestring(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.s := System.StrUtils.ReverseString(Args[0].s);
end;

function n_startsstr(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if System.StrUtils.StartsStr(Args[0].s, Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

function n_startstext(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  if System.StrUtils.StartsText(Args[0].s, Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

function s_stuffstring(var Args: Array of TAsmData): TAsmData;
var
  Index, DelCount, StrLen: Integer;
begin
  lastError := ERR_NONE;
  StrLen := Args[0].s.Length;
  Index := ClampToInt(Args[1].n);
  DelCount := ClampToInt(Args[2].n);

  // StuffString uses 1-based indexing
  // Validate parameters
  if Index < 1 then Index := 1;
  if Index > StrLen + 1 then Index := StrLen + 1;
  if DelCount < 0 then DelCount := 0;

  try
    Result.s := System.StrUtils.StuffString(Args[0].s, Index, DelCount, Args[3].s);
  except
    on E: Exception do
    begin
      lastError := ERR_INVALID_ARGUMENT;
      Result.s := Args[0].s;
    end;
  end;
end;

function s_line1(var Args: Array of TAsmData): TAsmData;
var
  LineNum: Integer;
begin
  lastError := ERR_NONE;
  LineNum := ClampToInt(Args[1].n);

  if LineNum < 0 then
  begin
    lastError := ERR_INDEX_OUT_OF_BOUNDS;
    Result.s := '';
    Exit;
  end;

  Result.s := TUtils.StrLine(PChar(Args[0].s), LineNum);
end;

function s_line2(var Args: Array of TAsmData): TAsmData;
var
  Str: TStringList;
  Index: Integer;
begin
  lastError := ERR_NONE;
  Result.s := Args[0].s;
  Index := ClampToInt(Args[1].n);

  Str := TStringList.Create;
  try
    Str.Text := Args[0].s;

    if (Index < 0) or (Index >= Str.Count) then
    begin
      lastError := ERR_INDEX_OUT_OF_BOUNDS;
      Exit;
    end;

    Str.Strings[Index] := Args[2].s;
    Result.s := Str.Text;
  finally
    Str.Free;
  end;
end;

function n_count(var Args: Array of TAsmData): TAsmData;
begin
  lastError := ERR_NONE;
  Result.n := TUtils.CountRows(PChar(Args[0].s));
end;

function s_opentext(var Args: Array of TAsmData): TAsmData;
var
  Enc: TEncoding;
begin
  lastError := ERR_NONE;
  Enc := ParseEncoding(Args[1].s);

  if not TUtils.OpenStr(Args[0].s, Enc, Result.s) then
  begin
    lastError := ERR_FILE_ERROR;
    Result.s := '';
  end;
end;

function s_savetext(var Args: Array of TAsmData): TAsmData;
var
  Enc: TEncoding;
begin
  lastError := ERR_NONE;
  Enc := ParseEncoding(Args[1].s);

  if TUtils.SaveStr(Args[0].s, Enc, Args[2].s) then
    Result.s := Args[2].s
  else
  begin
    lastError := ERR_FILE_ERROR;
    Result.s := '';
  end;
end;

function s_copytext(var Args: Array of TAsmData): TAsmData;
var
  Clipboard: IFMXClipboardService;
  Data: TValue;
begin
  lastError := ERR_NONE;
  Result.s := '';

  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, IInterface(Clipboard)) then
  begin
    try
      Data := TValue.From(Args[0].s);
      Clipboard.SetClipboard(Data);
      Result.s := Args[0].s;
    except
      lastError := ERR_CLIPBOARD_ERROR;
    end;
  end
  else
    lastError := ERR_CLIPBOARD_ERROR;
end;

function s_pastetext(var Args: Array of TAsmData): TAsmData;
var
  Clipboard: IFMXClipboardService;
  Data: TValue;
begin
  lastError := ERR_NONE;
  Result.s := '';

  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, IInterface(Clipboard)) then
  begin
    try
      Data := Clipboard.GetClipboard;
      Result.s := Data.AsString;
    except
      lastError := ERR_CLIPBOARD_ERROR;
    end;
  end
  else
    lastError := ERR_CLIPBOARD_ERROR;
end;

// word$@$n$ - Extract word at position from delimited string
// Position is 1-based. Returns empty string if position is out of bounds.
// Example: word$("apple,banana,cherry", 2, ",") returns "banana"
function s_word(var Args: Array of TAsmData): TAsmData;
var
  SourceStr, Delimiter: String;
  Position, CurrentPos, StartIdx, EndIdx, StrLen, DelimLen: Integer;
begin
  lastError := ERR_NONE;
  Result.s := '';

  SourceStr := Args[0].s;
  Position := ClampToInt(Args[1].n);
  Delimiter := Args[2].s;

  // Validate position (1-based)
  if Position < 1 then
  begin
    lastError := ERR_INDEX_OUT_OF_BOUNDS;
    Exit;
  end;

  // Handle empty source string
  if SourceStr.Length = 0 then
  begin
    if Position = 1 then
      Result.s := ''  // First word of empty string is empty string
    else
      lastError := ERR_INDEX_OUT_OF_BOUNDS;
    Exit;
  end;

  // Handle empty delimiter - return entire string if position is 1
  if Delimiter.Length = 0 then
  begin
    if Position = 1 then
      Result.s := SourceStr
    else
      lastError := ERR_INDEX_OUT_OF_BOUNDS;
    Exit;
  end;

  StrLen := SourceStr.Length;
  DelimLen := Delimiter.Length;
  CurrentPos := 0;
  StartIdx := 1;

  // Find the start of the requested word
  while CurrentPos < Position - 1 do
  begin
    EndIdx := Pos(Delimiter, Copy(SourceStr, StartIdx, StrLen));
    if EndIdx = 0 then
    begin
      // No more delimiters found - position is out of bounds
      lastError := ERR_INDEX_OUT_OF_BOUNDS;
      Exit;
    end;
    StartIdx := StartIdx + EndIdx + DelimLen - 1;
    Inc(CurrentPos);
  end;

  EndIdx := Pos(Delimiter, Copy(SourceStr, StartIdx, StrLen)); // Find the end of the requested word
  if EndIdx = 0 then
    Result.s := Copy(SourceStr, StartIdx, StrLen) // Last word - take everything from StartIdx
  else
    Result.s := Copy(SourceStr, StartIdx, EndIdx - 1); // Take from StartIdx to just before the delimiter
end;

// wordcount@$$ - Count words in delimited string
// Example: wordcount("apple,banana,cherry", ",") returns 3
function n_wordcount(var Args: Array of TAsmData): TAsmData;
var
  SourceStr, Delimiter: String;
  Count, Idx, DelimLen: Integer;
begin
  lastError := ERR_NONE;
  Result.n := 0;

  SourceStr := Args[0].s;
  Delimiter := Args[1].s;

  // Empty string has 0 words
  if SourceStr.Length = 0 then
  begin
    Result.n := 0;
    Exit;
  end;

  // Empty delimiter means entire string is one word
  if Delimiter.Length = 0 then
  begin
    Result.n := 1;
    Exit;
  end;

  // Count delimiters + 1 = word count
  Count := 1;
  DelimLen := Delimiter.Length;
  Idx := Pos(Delimiter, SourceStr);

  while Idx > 0 do
  begin
    Inc(Count);
    SourceStr := Copy(SourceStr, Idx + DelimLen, Length(SourceStr));
    Idx := Pos(Delimiter, SourceStr);
  end;

  Result.n := Count;
end;

// space$@n - Create string of n spaces
function s_space(var Args: Array of TAsmData): TAsmData;
var
  Count: Integer;
begin
  lastError := ERR_NONE;
  Count := ClampToInt(Args[0].n);

  if Count < 0 then Count := 0;
  if Count > 1000000 then Count := 1000000;

  Result.s := System.StringOfChar(' ', Count);
end;

// string$@nn - Create string of n characters with ASCII code
function s_string(var Args: Array of TAsmData): TAsmData;
var
  Count, CharCode: Integer;
begin
  lastError := ERR_NONE;
  Count := ClampToInt(Args[0].n);
  CharCode := ClampToInt(Args[1].n);

  if Count < 0 then Count := 0;
  if Count > 1000000 then Count := 1000000;
  if CharCode < 0 then CharCode := 0;
  if CharCode > 65535 then CharCode := 65535;

  Result.s := System.StringOfChar(Chr(CharCode), Count);
end;

//------------------------------------------------------------------------------
// The method below register all string related functions to the BASIC engine.
//------------------------------------------------------------------------------
procedure RegisterStrFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;

  // Error handling
  FnData.Entry := n_strerror; Lib.Add('strerror@', FnData);

  // Case conversion
  FnData.Entry := s_lcase; Lib.Add('lcase$@$', FnData);
  FnData.Entry := s_alcase; Lib.Add('alcase$@$', FnData);
  FnData.Entry := s_ucase; Lib.Add('ucase$@$', FnData);
  FnData.Entry := s_aucase; Lib.Add('aucase$@$', FnData);
  FnData.Entry := s_proper; Lib.Add('proper$@$', FnData);      // NEW: title case
  FnData.Entry := s_swapcase; Lib.Add('swapcase$@$', FnData);  // NEW: swap case

  // Trimming
  FnData.Entry := s_ltrim; Lib.Add('ltrim$@$', FnData);
  FnData.Entry := s_rtrim; Lib.Add('rtrim$@$', FnData);
  FnData.Entry := s_trim; Lib.Add('trim$@$', FnData);

  // Character operations
  FnData.Entry := s_chr; Lib.Add('chr$@n', FnData);
  FnData.Entry := s_chrget; Lib.Add('chr$@$n', FnData);
  FnData.Entry := s_chrset; Lib.Add('chr$@$n$', FnData);

  // Number to string conversion
  FnData.Entry := s_hex; Lib.Add('hex$@n', FnData);
  FnData.Entry := s_hex2; Lib.Add('hex$@nn', FnData);
  FnData.Entry := s_oct; Lib.Add('oct$@n', FnData);
  FnData.Entry := s_bin; Lib.Add('bin$@n', FnData);
  FnData.Entry := s_str; Lib.Add('str$@n', FnData);
  FnData.Entry := s_str2; Lib.Add('str$@nn', FnData);
  FnData.Entry := s_stri; Lib.Add('stri$@n', FnData);
  FnData.Entry := s_stri2; Lib.Add('stri$@nn', FnData);

  // Substring operations
  FnData.Entry := s_mid; Lib.Add('mid$@$n', FnData);
  FnData.Entry := s_mid2; Lib.Add('mid$@$nn', FnData);
  FnData.Entry := s_left; Lib.Add('left$@$n', FnData);
  FnData.Entry := s_left1; Lib.Add('left$@$', FnData);
  FnData.Entry := s_right; Lib.Add('right$@$n', FnData);
  FnData.Entry := s_right1; Lib.Add('right$@$', FnData);
  FnData.Entry := s_insert; Lib.Add('insert$@$$n', FnData);    // NEW: insert at position 2026-01-21
  FnData.Entry := s_delete; Lib.Add('delete$@$nn', FnData);    // NEW: delete at position 2026-01-21

  // Padding and filling
  FnData.Entry := s_ltab; Lib.Add('ltab$@$n', FnData);
  FnData.Entry := s_rtab; Lib.Add('rtab$@$n', FnData);
  FnData.Entry := s_lfill; Lib.Add('lfill$@$nn', FnData);
  FnData.Entry := s_rfill; Lib.Add('rfill$@$nn', FnData);
  FnData.Entry := s_space; Lib.Add('space$@n', FnData);
  FnData.Entry := s_string; Lib.Add('string$@nn', FnData);
  FnData.Entry := s_center; Lib.Add('center$@$n', FnData);     // NEW: center with spaces 2026-01-21
  FnData.Entry := s_center2; Lib.Add('center$@$nn', FnData);   // NEW: center with fill char 2026-01-21

  // String info
  FnData.Entry := n_len; Lib.Add('len@$', FnData);
  FnData.Entry := n_asc; Lib.Add('asc@$', FnData);
  FnData.Entry := n_val; Lib.Add('val@$', FnData);
  FnData.Entry := n_valcode; Lib.Add('valcode@', FnData);

  // String validation (NEW)
  FnData.Entry := n_isnumeric; Lib.Add('isnumeric@$', FnData);  // NEW: is numeric? 2026-01-21
  FnData.Entry := n_isalpha; Lib.Add('isalpha@$', FnData);      // NEW: all letters? 2026-01-21
  FnData.Entry := n_isalnum; Lib.Add('isalnum@$', FnData);      // NEW: alphanumeric? 2026-01-21
  FnData.Entry := n_isdigits; Lib.Add('isdigits@$', FnData);    // NEW: all digits? 2026-01-21
  FnData.Entry := n_isspace; Lib.Add('isspace@$', FnData);      // NEW: all whitespace? 2026-01-21
  FnData.Entry := n_islower; Lib.Add('islower@$', FnData);      // NEW: all lowercase? 2026-01-21
  FnData.Entry := n_isupper; Lib.Add('isupper@$', FnData);      // NEW: all uppercase? 2026-01-21

  // Search operations
  FnData.Entry := n_instr; Lib.Add('instr@$$', FnData);
  FnData.Entry := n_instr2; Lib.Add('instr@$$n', FnData);
  FnData.Entry := n_instrrev; Lib.Add('instrrev@$$', FnData);   // NEW: find last occurrence 2026-01-21
  FnData.Entry := n_instrrev2; Lib.Add('instrrev@$$n', FnData); // NEW: find last from position 2026-01-21
  FnData.Entry := n_countstr; Lib.Add('countstr@$$', FnData);   // NEW: count occurrences 2026-01-21
  FnData.Entry := n_containsstr; Lib.Add('containsstr@$$', FnData);
  FnData.Entry := n_containstext; Lib.Add('containstext@$$', FnData);
  FnData.Entry := n_startsstr; Lib.Add('startsstr@$$', FnData);
  FnData.Entry := n_startstext; Lib.Add('startstext@$$', FnData);
  FnData.Entry := n_endsstr; Lib.Add('endsstr@$$', FnData);
  FnData.Entry := n_endstext; Lib.Add('endstext@$$', FnData);

  // String comparison (NEW)
  FnData.Entry := n_strcmp; Lib.Add('strcmp@$$', FnData);       // NEW: compare (case-sensitive) 2026-01-21
  FnData.Entry := n_strcmpi; Lib.Add('strcmpi@$$', FnData);     // NEW: compare (case-insensitive) 2026-01-21

  // String manipulation
  FnData.Entry := s_dupestring; Lib.Add('mulstring$@$n', FnData);
  FnData.Entry := s_replacestr; Lib.Add('replacestr$@$$$', FnData);
  FnData.Entry := s_replacetext; Lib.Add('replacetext$@$$$', FnData);
  FnData.Entry := s_reversestring; Lib.Add('reverse$@$', FnData);
  FnData.Entry := s_stuffstring; Lib.Add('stuffstring$@$nn$', FnData);

  // Multi-line string operations
  FnData.Entry := n_count; Lib.Add('count@$', FnData);
  FnData.Entry := s_line1; Lib.Add('line$@$n', FnData);
  FnData.Entry := s_line2; Lib.Add('line$@$n$', FnData);

  // Delimited string operations (word extraction)
  FnData.Entry := s_word; Lib.Add('word$@$n$', FnData);
  FnData.Entry := n_wordcount; Lib.Add('wordcount@$$', FnData);

  // File operations
  FnData.Entry := s_opentext; Lib.Add('opentext$@$$', FnData);
  FnData.Entry := s_savetext; Lib.Add('savetext$@$$$', FnData);

  // Clipboard operations
  FnData.Entry := s_copytext; Lib.Add('copytext$@$', FnData);
  FnData.Entry := s_pastetext; Lib.Add('pastetext$@', FnData);
end;

end.
