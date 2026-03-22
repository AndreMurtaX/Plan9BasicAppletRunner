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
unit StdLib;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Variants, System.Math,
  FMX.Forms,
  exec;

procedure RegisterStdFuncs(Lib: TFunctionsDictionary);

implementation

//----------------------------------------------------------
// Standard library methods
//----------------------------------------------------------

function s_classname(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.s := TObject(Args[0].p).ClassName;
end;

function n_pause(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Sleep(Trunc(Args[0].n * 1000));
  Result.n := 0;
end;

function n_number(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := NativeInt(Args[0].p);
end;

function p_pointer(var Args: Array of TAsmData): TAsmData;
var
  i: NativeInt;
begin
  Result := Default(TAsmData);
  i := Trunc(Args[0].n);
  Result.p := Pointer(NativeInt(i));
end;

function n_pnttonum(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  if Assigned(Args[0].p) then
    Result.n := NativeInt(Args[0].p)
  else
    Result.n := 0;
end;

function n_isnan(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := Ord(IsNan(Args[0].n));
end;

function n_isnull(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := 0;
  if (Args[0].s = Null) or (Args[0].s = #0) then
    Result.n := 1;
end;

function n_isassigned(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := Ord(Assigned(Args[0].p));
end;

function n_formatset(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := 1;
  {
    CurrencyString: String;
    CurrencyFormat: Byte;
    CurrencyDecimals: Byte;
    DateSeparator: Char;
    TimeSeparator: Char;
    ListSeparator: Char;
    ShortDateFormat: String;
    LongDateFormat: String;
    TimeAMString: String;
    TimePMString: String;
    ShortTimeFormat: String;
    LongTimeFormat: String;
    ThousandSeparator: Char;
    DecimalSeparator: Char;
    'TwoDigitYearCenturyWindow: Word;
    NegCurrFormat: Byte;
  }
  {
    ShortMonthNames: array[1..12] of String;
    LongMonthNames: array[1..12] of String;
    ShortDayNames: array[1..7] of String;
    LongDayNames: array[1..7] of String;
  }
  if Lowercase(Args[0].s) = 'currencystring' then //not used
    FormatSettings.CurrencyString := Args[1].s
  else if Lowercase(Args[0].s) = 'currencyformat' then //not used
    FormatSettings.CurrencyFormat := Byte(StrToInt(Args[1].s[1]))
  else if Lowercase(Args[0].s) = 'currencydecimals' then //not used
    FormatSettings.CurrencyDecimals := Byte(StrToInt(Args[1].s[1]))
  else if Lowercase(Args[0].s) = 'dateseparator' then
    FormatSettings.DateSeparator := Args[1].s[1]
  else if Lowercase(Args[0].s) = 'timeseparator' then
    FormatSettings.TimeSeparator := Args[1].s[1]
  else if Lowercase(Args[0].s) = 'listseparator' then //not used
    FormatSettings.ListSeparator := Args[1].s[1]
  else if Lowercase(Args[0].s) = 'shortdateformat' then
    FormatSettings.ShortDateFormat := Args[1].s
  else if Lowercase(Args[0].s) = 'longdateformat' then
    FormatSettings.LongDateFormat := Args[1].s
  else if Lowercase(Args[0].s) = 'timeamstring' then
    FormatSettings.TimeAMString := Args[1].s
  else if Lowercase(Args[0].s) = 'timepmstring' then
    FormatSettings.TimePMString := Args[1].s
  else if Lowercase(Args[0].s) = 'shorttimeformat' then
    FormatSettings.ShortTimeFormat := Args[1].s
  else if Lowercase(Args[0].s) = 'longtimeformat' then
    FormatSettings.LongTimeFormat := Args[1].s
  else if Lowercase(Args[0].s) = 'thousandseparator' then //not used
    FormatSettings.ThousandSeparator := Args[1].s[1]
  else if Lowercase(Args[0].s) = 'decimalseparator' then
    FormatSettings.DecimalSeparator := Args[1].s[1]
  else if Lowercase(Args[0].s) = 'negcurrformat' then
    FormatSettings.NegCurrFormat := Byte(StrToInt(Args[1].s[1])) //not used
  else
    Result.n := 0;
end;

function s_formatget(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.s := '';
  {
    CurrencyString: String;
    CurrencyFormat: Byte;
    CurrencyDecimals: Byte;
    DateSeparator: Char;
    TimeSeparator: Char;
    ListSeparator: Char;
    ShortDateFormat: String;
    LongDateFormat: String;
    TimeAMString: String;
    TimePMString: String;
    ShortTimeFormat: String;
    LongTimeFormat: String;
    ThousandSeparator: Char;
    DecimalSeparator: Char;
    'TwoDigitYearCenturyWindow: Word;
    NegCurrFormat: Byte;
  }
  {
    ShortMonthNames: array[1..12] of String;
    LongMonthNames: array[1..12] of String;
    ShortDayNames: array[1..7] of String;
    LongDayNames: array[1..7] of String;
  }
  if Lowercase(Args[0].s) = 'currencystring' then //not used
    Result.s := FormatSettings.CurrencyString
  else if Lowercase(Args[0].s) = 'currencyformat' then //not used
    Result.s := IntToStr(FormatSettings.CurrencyFormat)
  else if Lowercase(Args[0].s) = 'currencydecimals' then //not used
    Result.s := IntToStr(FormatSettings.CurrencyDecimals)
  else if Lowercase(Args[0].s) = 'dateseparator' then
    Result.s := FormatSettings.DateSeparator
  else if Lowercase(Args[0].s) = 'timeseparator' then
    Result.s := FormatSettings.TimeSeparator
  else if Lowercase(Args[0].s) = 'listseparator' then //not used
    Result.s := FormatSettings.ListSeparator
  else if Lowercase(Args[0].s) = 'shortdateformat' then
    Result.s := FormatSettings.ShortDateFormat
  else if Lowercase(Args[0].s) = 'longdateformat' then
    Result.s := FormatSettings.LongDateFormat
  else if Lowercase(Args[0].s) = 'timeamstring' then
    Result.s := FormatSettings.TimeAMString
  else if Lowercase(Args[0].s) = 'timepmstring' then
    Result.s := FormatSettings.TimePMString
  else if Lowercase(Args[0].s) = 'shorttimeformat' then
    Result.s := FormatSettings.ShortTimeFormat
  else if Lowercase(Args[0].s) = 'longtimeformat' then
    Result.s := FormatSettings.LongTimeFormat
  else if Lowercase(Args[0].s) = 'thousandseparator' then //not used
    Result.s := FormatSettings.ThousandSeparator
  else if Lowercase(Args[0].s) = 'decimalseparator' then
    Result.s := FormatSettings.DecimalSeparator
  else if Lowercase(Args[0].s) = 'negcurrformat' then
    Result.s := IntToStr(FormatSettings.NegCurrFormat) //not used
  else
    Result.s := '';
end;

function n_processmessages(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := 1;
  Application.ProcessMessages();
end;

function n_handlemessage(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := 1;
  Application.HandleMessage();
end;

function n_isinfinite(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := Ord(IsInfinite(Args[0].n));
end;

function n_sign(var Args: Array of TAsmData): TAsmData;
begin
  Result := Default(TAsmData);
  Result.n := Sign(Args[0].n);
end;

procedure RegisterStdFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData := Default(TLinkFunction);
  FnData.FarCall := True;

  FnData.Entry := s_classname; Lib.Add('classname$@#', FnData);
  FnData.Entry := n_pause; Lib.Add('pause@n', FnData);
  FnData.Entry := n_number; Lib.Add('number@#', FnData);
  FnData.Entry := p_pointer; Lib.Add('pointer#@n', FnData);
  FnData.Entry := n_pnttonum; Lib.Add('pnttonum@#', FnData);
  FnData.Entry := n_formatset; Lib.Add('formatsettings@$$', FnData);
  FnData.Entry := s_formatget; Lib.Add('formatsettings$@$', FnData);
  FnData.Entry := n_processmessages; Lib.Add('processmessages@', FnData);
  FnData.Entry := n_handlemessage; Lib.Add('handlemessage@', FnData);
  FnData.Entry := n_isnan; Lib.Add('isnan@n', FnData);
  FnData.Entry := n_isnull; Lib.Add('isnull@$', FnData);
  FnData.Entry := n_isassigned; Lib.Add('isassigned@#', FnData);
  FnData.Entry := n_isinfinite; Lib.Add('isinfinite@n', FnData);
  FnData.Entry := n_sign; Lib.Add('sign@n', FnData);
end;

end.
