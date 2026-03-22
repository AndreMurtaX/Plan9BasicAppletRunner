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
unit UnitUtils;

interface

uses
  System.Types, System.Classes, System.SysUtils, System.StrUtils,
  System.Generics.Collections, System.TypInfo, System.Rtti, System.Variants,
  System.Net.HttpClientComponent, System.DateUtils, System.UITypes,
  System.IOUtils,
  Data.DB,
  FMX.Graphics, FMX.Types;

type
  TUtils = class
    class function StringCode(s: String): integer;
    class function LimitRound(var d: Extended; mn, mx: integer): integer;
    class function StrLine(Arr: PChar; n: integer): String;
    class function CountRows(arr: String): integer;
    class function StrToFloat2(const s: String; out ok: boolean): Extended;
    class function FloatToStr2(d: Extended): String;
    class function FindLine(p: PChar; n: integer): integer;
    class function OpenStr(filename: String; Enc: TEncoding; out s: String): boolean;
    class function SaveStr(const filename: String; Enc: TEncoding; s: String): boolean;
    class function IsItem(aItem: String; oLst: TList<String>): Boolean;
    class function LinearIndex(const dim, idx: array of Integer): Integer;
    class function IntToBool(Value: Integer): Boolean;
    class function BoolToInt(Value: Boolean): Integer;
    class function GetProperty(Obj: TObject; Path: String): Variant;
    class function GetClassProperty(Obj: TObject; Path: String): TObject;
    class procedure SetProperty(Obj: TObject; Prop: String; Value: Variant);
    class procedure SetClassProperty(Obj: TObject; Prop: String; Value: TObject);
    class function GetTSetPropertyNames(AObject: TObject): TStringList;
    class function LoadImageFromWeb(url: String; Bitmap: TBitmap): Boolean;
    class function LoadFromWeb(url: String; Code: TStringList): Boolean;
    class function ShiftStateToString(ss: TShiftState): String;
    class function GPTStrHash(const Str: string): Integer;
    class function AdjustFieldType(const AType: TFieldType): TFieldType;
    class function ToDateTime(const ADate: String): TDateTime;
    class function SToBool(const AValue: String): Boolean;
    class function BToStr(const AValue: Boolean): String;
    class function ValidProperty(AName: String; ValidProps: TStringDynArray): Boolean;
    class function ValidMethod(AObj: TFMXObject; AMethod: String): Boolean;
    class function ColorToAlphaColor(const ColorStr: String): TAlphaColor;
    class function AlphaColorToStr(const Color: TAlphaColor): String;
    /// <summary>Resolve a relative data path to an absolute writable path.
    /// On mobile (Android/iOS) combines with TPath.GetDocumentsPath.
    /// On desktop returns the path unchanged (relative to exe dir).</summary>
    class function ResolveDataPath(const SubPath: String): String;
    /// <summary>Returns True if running on a mobile platform (Android/iOS).</summary>
    class function IsMobilePlatform: Boolean;
  end;

implementation

{ TUtils }

//Calculate string code
class function TUtils.StringCode(s: String): integer;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Pred(s.Length) do
    Result := Result + Ord(s.Chars[i]);
end;

//Check for numeric limits
class function TUtils.LimitRound(var d: Extended; mn, mx: integer): integer;
begin
  Result := round(d);
  if result < mn then result := mn;
  if result > mx then result := mx;
end;

//Returns a specific line in a multiline text
class function TUtils.StrLine(Arr: PChar; n: integer): String;
var
  Str: TStringList;
  Line: String;
begin
  Result := '';
  if (n < 0) or (arr[0] = #0) then Exit();
  Str := TStringList.Create();
  try
    Str.Text := String(Arr);
    if (n < 0) or (n >= Str.Count) then
      Exit();
    Line := Str.Strings[n];
  finally
    FreeAndNil(Str);
  end;
  Result := Line;
end;

class function TUtils.ColorToAlphaColor(const ColorStr: String): TAlphaColor;
var
  R, G, B, A: Byte;
  S: String;
begin
  Result := TAlphaColorRec.Black;
  S := Trim(ColorStr);

  // Handle hex format: #RRGGBB or #AARRGGBB
  if (Length(S) > 0) and (S[1] = '#') then
  begin
    S := Copy(S, 2, Length(S) - 1);
    if Length(S) = 6 then
      S := 'FF' + S;
    if Length(S) = 8 then
    begin
      A := StrToIntDef('$' + Copy(S, 1, 2), 255);
      R := StrToIntDef('$' + Copy(S, 3, 2), 0);
      G := StrToIntDef('$' + Copy(S, 5, 2), 0);
      B := StrToIntDef('$' + Copy(S, 7, 2), 0);
      Result := (TAlphaColor(A) shl 24) or (TAlphaColor(R) shl 16) or
                (TAlphaColor(G) shl 8) or TAlphaColor(B);
    end;
    Exit;
  end;

  // Handle named colors (case-insensitive)
  // Basic colors
  if SameText(S, 'black') then Result := TAlphaColorRec.Black
  else if SameText(S, 'white') then Result := TAlphaColorRec.White
  else if SameText(S, 'red') then Result := TAlphaColorRec.Red
  else if SameText(S, 'green') then Result := TAlphaColorRec.Green
  else if SameText(S, 'blue') then Result := TAlphaColorRec.Blue
  else if SameText(S, 'yellow') then Result := TAlphaColorRec.Yellow
  else if SameText(S, 'cyan') then Result := TAlphaColorRec.Cyan
  else if SameText(S, 'magenta') then Result := TAlphaColorRec.Magenta
  else if SameText(S, 'gray') or SameText(S, 'grey') then Result := TAlphaColorRec.Gray
  else if SameText(S, 'silver') then Result := TAlphaColorRec.Silver
  else if SameText(S, 'maroon') then Result := TAlphaColorRec.Maroon
  else if SameText(S, 'olive') then Result := TAlphaColorRec.Olive
  else if SameText(S, 'navy') then Result := TAlphaColorRec.Navy
  else if SameText(S, 'purple') then Result := TAlphaColorRec.Purple
  else if SameText(S, 'teal') then Result := TAlphaColorRec.Teal
  else if SameText(S, 'orange') then Result := TAlphaColorRec.Orange
  else if SameText(S, 'pink') then Result := TAlphaColorRec.Pink
  else if SameText(S, 'brown') then Result := TAlphaColorRec.Brown
  else if SameText(S, 'lime') then Result := TAlphaColorRec.Lime
  else if SameText(S, 'aqua') then Result := TAlphaColorRec.Aqua
  else if SameText(S, 'fuchsia') then Result := TAlphaColorRec.Fuchsia
  // Extended colors
  else if SameText(S, 'gold') then Result := TAlphaColorRec.Gold
  else if SameText(S, 'coral') then Result := TAlphaColorRec.Coral
  else if SameText(S, 'crimson') then Result := TAlphaColorRec.Crimson
  else if SameText(S, 'indigo') then Result := TAlphaColorRec.Indigo
  else if SameText(S, 'ivory') then Result := TAlphaColorRec.Ivory
  else if SameText(S, 'khaki') then Result := TAlphaColorRec.Khaki
  else if SameText(S, 'lavender') then Result := TAlphaColorRec.Lavender
  else if SameText(S, 'salmon') then Result := TAlphaColorRec.Salmon
  else if SameText(S, 'skyblue') then Result := TAlphaColorRec.Skyblue
  else if SameText(S, 'tan') then Result := TAlphaColorRec.Tan
  else if SameText(S, 'tomato') then Result := TAlphaColorRec.Tomato
  else if SameText(S, 'turquoise') then Result := TAlphaColorRec.Turquoise
  else if SameText(S, 'violet') then Result := TAlphaColorRec.Violet
  else if SameText(S, 'wheat') then Result := TAlphaColorRec.Wheat
  // Light/Dark variants
  else if SameText(S, 'dodgerblue') then Result := TAlphaColorRec.Dodgerblue
  else if SameText(S, 'lightblue') then Result := TAlphaColorRec.Lightblue
  else if SameText(S, 'lightgreen') then Result := TAlphaColorRec.Lightgreen
  else if SameText(S, 'lightgray') or SameText(S, 'lightgrey') then Result := TAlphaColorRec.Lightgray
  else if SameText(S, 'darkgray') or SameText(S, 'darkgrey') then Result := TAlphaColorRec.Darkgray
  else if SameText(S, 'darkblue') then Result := TAlphaColorRec.Darkblue
  else if SameText(S, 'darkgreen') then Result := TAlphaColorRec.Darkgreen
  else if SameText(S, 'darkred') then Result := TAlphaColorRec.Darkred
  else if SameText(S, 'hotpink') then Result := TAlphaColorRec.Hotpink
  else if SameText(S, 'deeppink') then Result := TAlphaColorRec.Deeppink
  else if SameText(S, 'orangered') then Result := TAlphaColorRec.Orangered
  else if SameText(S, 'greenyellow') then Result := TAlphaColorRec.Greenyellow
  else if SameText(S, 'seagreen') then Result := TAlphaColorRec.Seagreen
  else if SameText(S, 'mediumseagreen') then Result := TAlphaColorRec.Mediumseagreen
  else if SameText(S, 'slategray') or SameText(S, 'slategrey') then Result := TAlphaColorRec.Slategray
  else if SameText(S, 'steelblue') then Result := TAlphaColorRec.Steelblue
  else if SameText(S, 'royalblue') then Result := TAlphaColorRec.Royalblue
  else if SameText(S, 'midnightblue') then Result := TAlphaColorRec.Midnightblue
  else if SameText(S, 'chocolate') then Result := TAlphaColorRec.Chocolate
  else if SameText(S, 'sienna') then Result := TAlphaColorRec.Sienna
  else if SameText(S, 'peru') then Result := TAlphaColorRec.Peru
  else if SameText(S, 'beige') then Result := TAlphaColorRec.Beige
  else if SameText(S, 'linen') then Result := TAlphaColorRec.Linen
  else if SameText(S, 'snow') then Result := TAlphaColorRec.Snow
  else if SameText(S, 'honeydew') then Result := TAlphaColorRec.Honeydew
  else if SameText(S, 'mintcream') then Result := TAlphaColorRec.Mintcream
  else if SameText(S, 'aliceblue') then Result := TAlphaColorRec.Aliceblue
  // Transparency
  else if SameText(S, 'transparent') or SameText(S, 'null') then Result := TAlphaColorRec.Null;
end;

class function TUtils.AlphaColorToStr(const Color: TAlphaColor): String;
begin
  Result := '#' + IntToHex(TAlphaColorRec(Color).A, 2) +
            IntToHex(TAlphaColorRec(Color).R, 2) +
            IntToHex(TAlphaColorRec(Color).G, 2) +
            IntToHex(TAlphaColorRec(Color).B, 2);
end;

//Returns the total of lines in a multiline text
class function TUtils.CountRows(arr: String): integer;
var
  sl: TStringList;
begin
  sl := TSTringList.Create();
  try
    try
      sl.Text := arr;
      Result := sl.Count
    except
      Result := -1;
    end;
  finally
    FreeAndNil(sl);
  end;
end;

class function TUtils.SToBool(const AValue: String): Boolean;
begin
  SetLength(TrueBoolStrs, 2);
  TrueBoolStrs[0] := 'True';
  TrueBoolStrs[1] := '1';
  SetLength(FalseBoolStrs, 3);
  FalseBoolStrs[0] := 'False';
  FalseBoolStrs[1] := '0';
  FalseBoolStrs[2] := '';
  Result := StrToBool(AValue);
end;

class function TUtils.ToDateTime(const ADate: String): TDateTime;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result := System.SysUtils.StrToDateTime(ADate, fs);
end;

class function TUtils.ValidMethod(AObj: TFMXObject; AMethod: String): Boolean;
var
  Contexto: TRttiContext;
  Tipo: TRttiType;
  Method: TRttiMethod;
begin
  Result := false;
  Contexto := TRttiContext.Create;
  try
    Tipo := Contexto.GetType(AObj.ClassType);
    Method := Tipo.GetMethod(AMethod);

    if Assigned(Method) then
      Result := true;
    //begin
      // O método existe
      //Metodo.Invoke(Controle, []); // Pode invocar o método
    //end
    //else
    //begin
      // O método não está disponível
    //end;
  finally
    Contexto.Free();
  end;
end;

class function TUtils.ValidProperty(AName: String; ValidProps: TStringDynArray): Boolean;
var
  i: Integer;
begin
  Result := false;
  for i := Low(validProps) to High(validProps) do
    if AName.ToLower().CompareTo(validProps[i].ToLower()) = 0 then
      Exit(true);
end;

//Customized conversion from string to float.
class function TUtils.StrToFloat2(const s: String; out ok: boolean): Extended;
var
  d: Extended;
  i: integer;
  s2: String;
begin
  s2 := '';
  if s.Length > 0 then
    for i := 0 to s.Length-1 do
      if s.Chars[i] = FormatSettings.DecimalSeparator then
        s2 := s2 + '.'
      else
        s2 := s2 + s.Chars[i];
  Val(s2, d, i);
  ok := i = 0;
  result := d;
end;

//Customized conversion from float to string.
class function TUtils.FloatToStr2(d: Extended): String;
var
  i: integer;
  Tmp: String;
begin
  Result := '';
  Tmp := System.SysUtils.FloatToStr(d);
  if Tmp.Length > 0 then
    for i := 0 to Tmp.Length-1 do
      if Tmp.Chars[i] = FormatSettings.DecimalSeparator then
        Result := Result + '.'
      else
        Result := Result + Tmp.Chars[i];
end;

class function TUtils.GetClassProperty(Obj: TObject; Path: String): TObject;
const
  SKIP_PROP_TYPES = [tkUnknown, tkInterface, tkMethod];
type
  TTokenPath = record
    Current, Next: String;
  end;
var
  tk: TTokenPath;
  Ctx: TRttiContext;
  T: TRttiType;
  P: TRttiProperty;

  function CurrentPath(PropPath: String): TTokenPath;
  begin
    Result.Current := ''; Result.Next := '';

    if PropPath.Length = 0 then
      Exit();

    if not PropPath.Contains('.') then
    begin
      if IsValidIdent(PropPath, false) then
      begin
        Result.Current := PropPath;
        Result.Next := '';
      end;
    end
    else
    begin
      if IsValidIdent(PropPath.Substring(0, PropPath.IndexOf('.')), false) then
        Result.Current := PropPath.Substring(0, PropPath.IndexOf('.'))
      else
        Result.Current := '';

      if IsValidIdent(PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt), true) then
        Result.Next := PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt)
      else
        Result.Next := '';
    end;
  end;

begin
  Result := nil;
  tk := CurrentPath(Path);
  if (tk.Current.Length > 0) and (tk.Next.Length > 0) then //Temos uma propriedade atual e uma próxima...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsReadable) and (P.PropertyType.TypeKind = tkClass) then
      Result := GetClassProperty(TObject(P.GetValue(Obj).AsObject), tk.Next)
    else
      Exit(nil);
  end
  else if (tk.Current.Length > 0) and (tk.Next.Length = 0) then //Chegamos na propriedade que queremos o valor...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsReadable) and not (P.PropertyType.TypeKind in SKIP_PROP_TYPES) then
    begin
      case P.PropertyType.TypeKind of
        tkClass: Result := P.GetValue(Obj).AsObject;
        else Result := nil;
      end;
    end;
  end;
end;

class function TUtils.GetProperty(Obj: TObject; Path: String): Variant;
const
  SKIP_PROP_TYPES = [tkUnknown, tkInterface, tkMethod];
type
  TTokenPath = record
    Current, Next: String;
  end;
var
  tk: TTokenPath;
  Ctx: TRttiContext;
  T: TRttiType;
  P: TRttiProperty;

  function CurrentPath(PropPath: String): TTokenPath;
  begin
    Result.Current := ''; Result.Next := '';

    if PropPath.Length = 0 then
      Exit();

    if not PropPath.Contains('.') then
    begin
      if IsValidIdent(PropPath, false) then
      begin
        Result.Current := PropPath;
        Result.Next := '';
      end;
    end
    else
    begin
      if IsValidIdent(PropPath.Substring(0, PropPath.IndexOf('.')), false) then
        Result.Current := PropPath.Substring(0, PropPath.IndexOf('.'))
      else
        Result.Current := '';

      if IsValidIdent(PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt), true) then
        Result.Next := PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt)
      else
        Result.Next := '';
    end;
  end;

  function ReturnSet(const v: TValue): String; // v contains a value from a set type
  var
    enumType: PTypeInfo;
    enumData: PTypeData;
    buffer: set of Byte; // biggest possible set type
    i: Integer;
  begin
    Result := '[';
    buffer := [];
    v.ExtractRawData(@buffer);
    enumType := v.TypeInfo.TypeData.CompType^;
    enumData := enumType.TypeData;
    for i := enumData.MinValue to enumData.MaxValue do
      //***DEBUG***
      //Result := Result + GetEnumName(enumType, i) + ' = ' + (i in buffer).ToString(TUseBoolStrs.True).ToLower()+System.sLineBreak;
      if i in buffer then
        Result := Result + GetEnumName(enumType, i) + ',';
    if (Result.Length > 1) and (Result.Chars[Result.Length-1] = ',') then
      Result := Result.Substring(0, Result.Length-1);
    Result := Result+']';
  end;

begin
  Result := Null;
  tk := CurrentPath(Path);
  if (tk.Current.Length > 0) and (tk.Next.Length > 0) then //Temos uma propriedade atual e uma próxima...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsReadable) and (P.PropertyType.TypeKind = tkClass) then
    begin
      Result := GetProperty(TObject(P.GetValue(Obj).AsObject), tk.Next);
    end
    else
    begin
      Exit(Null);
    end;
  end
  else if (tk.Current.Length > 0) and (tk.Next.Length = 0) then //Chegamos na propriedade que queremos o valor...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsReadable) and not (P.PropertyType.TypeKind in SKIP_PROP_TYPES) then
    begin
      case P.PropertyType.TypeKind of
        tkInteger, tkInt64: Result := P.GetValue(Obj).AsInt64;
        tkEnumeration: Result := P.GetValue(Obj).ToString();
        tkFloat: Result := P.GetValue(Obj).AsExtended;
        tkString, tkChar, tkWChar, tkLString, tkWString, tkUString: Result := P.GetValue(Obj).AsString;
        tkSet: Result := ReturnSet(P.GetValue(Obj));
        else Result := Null;
      end;
    end;
  end;
end;

class function TUtils.GetTSetPropertyNames(AObject: TObject): TStringList;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  PropList: TStringList;
begin
  PropList := TStringList.Create();
  try
    Context := TRttiContext.Create();
    try
      RttiType := Context.GetType(AObject.ClassType);
      for Prop in RttiType.GetProperties do
      begin
        if Prop.PropertyType.TypeKind = tkSet then
          PropList.Add(Prop.Name);
      end;
    finally
      Context.Free();
    end;
    Result := PropList;
  except
    PropList.Free();
    raise;
  end;
end;

//Returns the line number where the specified text position "n" is located.
class function TUtils.FindLine(p: PChar; n: integer): integer;
var
  i: integer;
begin
  result := 1;
  if n = 0 then Exit();
  for i := 0 to n - 1 do
    {$IFDEF MSWINDOWS}
    if (p[i] = #13) and (p[i+1] = #10) then Inc(result);
    {$ELSE}
    if (p[i] = #13) or (p[i] = #10) then Inc(result);
    {$ENDIF}
end;

//Load a text file into memory.
//Specify file encoding type.
//Returns "true" if file was loaded, "false" otherwise.
//Read text is returned in out var "s"
class function TUtils.OpenStr(filename: String; Enc: TEncoding; out s: String): boolean;
var
  Strings: TStrings;
begin
  Strings := TStringList.Create();
  try
    Result := True;
    Strings.LoadFromFile(filename, Enc);
  except
    Result := False;
    Exit;
  end;
  s := Strings.Text;
  Strings.Free();
end;

//Save a text file from memory to disk.
//Specify file encoding type.
//Returns "true" if file was saved, "false" otherwise.
//Text to save is defined in var "s"
class function TUtils.SaveStr(const filename: String; Enc: TEncoding; s: String): boolean;
var
  Strings: TStrings;
begin
  Strings := TStringList.Create();
  try
    Result := True;
    Strings.Text := s;
    Strings.SaveToFile(filename, Enc);
  except
    Result := false;
  end;
  Strings.Free();
end;

class procedure TUtils.SetClassProperty(Obj: TObject; Prop: String; Value: TObject);
const
  SKIP_PROP_TYPES = [tkUnknown, tkInterface, tkMethod];
type
  TTokenPath = record
    Current, Next: String;
  end;
var
  Ctx: TRttiContext;
  T: TRttiType;
  P: TRttiProperty;
  //E: TRttiEnumerationType;
  //N: Integer;
  //V: TValue;
  tk: TTokenPath;

  function CurrentPath(PropPath: String): TTokenPath;
  begin
    Result.Current := ''; Result.Next := '';

    if PropPath.Length = 0 then
      Exit();

    if not PropPath.Contains('.') then
    begin
      if IsValidIdent(PropPath, false) then
      begin
        Result.Current := PropPath;
        Result.Next := '';
      end;
    end
    else
    begin
      if IsValidIdent(PropPath.Substring(0, PropPath.IndexOf('.')), false) then
        Result.Current := PropPath.Substring(0, PropPath.IndexOf('.'))
      else
        Result.Current := '';

      if IsValidIdent(PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt), true) then
        Result.Next := PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt)
      else
        Result.Next := '';
    end;
  end;

begin
  tk := CurrentPath(Prop);
  if (tk.Current.Length > 0) and (tk.Next.Length > 0) then //Temos uma propriedade atual e uma próxima...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsReadable) and (P.PropertyType.TypeKind = tkClass) then
      SetClassProperty(TObject(P.GetValue(Obj).AsObject), tk.Next, TObject(Value))
    else
      Exit();
  end
  else if (tk.Current.Length > 0) and (tk.Next.Length = 0) then //Chegamos na propriedade que queremos o valor...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsWritable) and not (P.PropertyType.TypeKind in SKIP_PROP_TYPES) then
      case P.PropertyType.TypeKind of
        tkClass: P.SetValue(Obj, TObject(Value));
      end;
  end;
end;

class procedure TUtils.SetProperty(Obj: TObject; Prop: String; Value: Variant);
const
  SKIP_PROP_TYPES = [tkUnknown, tkInterface, tkMethod];
type
  TTokenPath = record
    Current, Next: String;
  end;
var
  Ctx: TRttiContext;
  T: TRttiType;
  P: TRttiProperty;
  //E: TRttiEnumerationType;
  N: Integer;
  V: TValue;
  tk: TTokenPath;

  function CurrentPath(PropPath: String): TTokenPath;
  begin
    Result.Current := ''; Result.Next := '';

    if PropPath.Length = 0 then
      Exit();

    if not PropPath.Contains('.') then
    begin
      if IsValidIdent(PropPath, false) then
      begin
        Result.Current := PropPath;
        Result.Next := '';
      end;
    end
    else
    begin
      if IsValidIdent(PropPath.Substring(0, PropPath.IndexOf('.')), false) then
        Result.Current := PropPath.Substring(0, PropPath.IndexOf('.'))
      else
        Result.Current := '';

      if IsValidIdent(PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt), true) then
        Result.Next := PropPath.Substring(PropPath.IndexOf('.')+1, MaxInt)
      else
        Result.Next := '';
    end;
  end;

begin
  tk := CurrentPath(Prop);
  if (tk.Current.Length > 0) and (tk.Next.Length > 0) then //Temos uma propriedade atual e uma próxima...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsReadable) and (P.PropertyType.TypeKind = tkClass) then
    begin
      SetProperty(TObject(P.GetValue(Obj).AsObject), tk.Next, Value);
    end
    else
    begin
      Exit();
    end;
  end
  else if (tk.Current.Length > 0) and (tk.Next.Length = 0) then //Chegamos na propriedade que queremos o valor...
  begin
    Ctx := TRttiContext.Create(); //Obtain the RTTI context
    T := Ctx.GetType(Obj.ClassInfo);
    P := T.GetProperty(tk.Current);
    if Assigned(P) and (P.IsWritable) and not (P.PropertyType.TypeKind in SKIP_PROP_TYPES) then
    begin
      case P.PropertyType.TypeKind of
        tkInteger, tkInt64: P.SetValue(Obj, Integer(Value));
        tkEnumeration:
        begin
          N := GetEnumValue(P.PropertyType.Handle, String(Value));
          TValue.Make(N, P.PropertyType.Handle, V);
          P.SetValue(Obj, V);
        end;
        tkFloat: P.SetValue(Obj, Double(Value));
        tkString, tkChar, tkWChar, tkLString, tkWString, tkUString: P.SetValue(Obj, String(Value));
        tkSet: SetSetProp(Obj, P.Name, String(Value));
      end;
    end;
  end;
end;

class function TUtils.ShiftStateToString(ss: TShiftState): String;
begin
  Result := '';
  if ssShift in ss then
    Result := Result + 'ssShift|';
  if ssAlt in ss then
    Result := Result + 'ssAlt|';
  if ssCtrl in ss then
    Result := Result + 'ssCtrl|';
  if ssLeft in ss then
    Result := Result + 'ssLeft|';
  if ssRight in ss then
    Result := Result + 'ssRight|';
  if ssMiddle in ss then
    Result := Result + 'ssMiddle|';
  if ssDouble in ss then
    Result := Result + 'ssDouble|';
  if ssTouch in ss then
    Result := Result + 'ssTouch|';
  if ssPen in ss then
    Result := Result + 'ssPen|';
  if ssCommand in ss then
    Result := Result + 'ssCommand|';
  if ssHorizontal in ss then
    Result := Result + 'ssHorizontal|';

  if (Result.Length > 0) and (Result.Chars[Result.Length-1] = '|') then
  begin
    Result := Result.Substring(0, Result.Length-1);
    Result := ReplaceText(Result, '|', System.sLineBreak);
  end;
end;

class function TUtils.IsItem(aItem: String; oLst: TList<String>): Boolean;
begin
  Result := oLst.Contains(aItem);
end;

class function TUtils.LinearIndex(const dim, idx: array of Integer): Integer;
var
  i,index,mult: Integer;
begin
  //Make sure the "dimensions" vector has the same size of the "indexes" vector
  if Length(dim) <> Length(idx) then
    Exit(-1); //-1 = different vector sizes
  if not (Length(dim) > 0) then
    Exit(-2); //-2 = Length(0) vectors make no sense

  //Check bounds
  for i := 0 to Length(dim)-1 do
    if (idx[i] < 1) or (idx[i] > dim[i]) then
      Exit(-3); //-3 = index out of bounds

  //If all the tests above passed. Calculate the linear index
  index := 0; mult := 1;
  for i := 0 to High(dim) do
  begin
    index := index + (idx[i]-1) * mult;
    mult := mult * dim[i];
  end;

  result := index;
end;

class function TUtils.LoadImageFromWeb(url: String; Bitmap: TBitmap): Boolean;
var
  ms: TMemoryStream;
  httpCli: TNetHTTPClient;
begin
  Result := true;

  httpCli := TNetHTTPClient.Create(nil);
  ms := TMemoryStream.Create();
  try
    try
      httpCli.Get(url, ms);
      ms.Position := 0;
      Bitmap.LoadFromStream(ms);
    except
      Result := false;
    end;
  finally
    ms.Free();
    httpCli.Free();
  end;
end;

class function TUtils.LoadFromWeb(url: String; Code: TStringList): Boolean;
var
  ms: TMemoryStream;
  httpCli: TNetHTTPClient;
begin
  Result := true;

  httpCli := TNetHTTPClient.Create(nil);
  ms := TMemoryStream.Create();
  try
    try
      httpCli.Get(url, ms);
      ms.Position := 0;
      Code.LoadFromStream(ms);
    except
      Result := false;
    end;
  finally
    ms.Free();
    httpCli.Free();
  end;
end;

class function TUtils.IntToBool(Value: Integer): Boolean;
begin
  Result := true;
  if Value = 0 then
    Result := false;
end;

class function TUtils.GPTStrHash(const Str: string): Integer;
const
  FNVOffsetBasis = 2166136261;
  FNVPrime = 16777619;
var
  I: Integer;
  Hash: UInt64; // Use UInt64 to avoid overflow during calculation
begin
  Hash := FNVOffsetBasis;
  for I := 1 to Length(Str) do
  begin
    Hash := Hash xor Ord(Str[I]);
    Hash := Hash * FNVPrime;
    Hash := Hash mod $7FFFFFFF; // Ensure the result stays within the bounds of a 32-bit integer
  end;
  Result := Integer(Hash);
end;

class function TUtils.AdjustFieldType(const AType: TFieldType): TFieldType;
begin
  //  TFieldType = (ftUnknown, ftString, ftSmallint, ftInteger, ftWord, // 0..4
  //    ftBoolean, ftFloat, ftCurrency, ftBCD, ftDate, ftTime, ftDateTime, // 5..11
  //    ftBytes, ftVarBytes, ftAutoInc, ftBlob, ftMemo, ftGraphic, ftFmtMemo, // 12..18
  //    ftParadoxOle, ftDBaseOle, ftTypedBinary, ftCursor, ftFixedChar, ftWideString, // 19..24
  //    ftLargeint, ftADT, ftArray, ftReference, ftDataSet, ftOraBlob, ftOraClob, // 25..31
  //    ftVariant, ftInterface, ftIDispatch, ftGuid, ftTimeStamp, ftFMTBcd, // 32..37
  //    ftFixedWideChar, ftWideMemo, ftOraTimeStamp, ftOraInterval, // 38..41
  //    ftLongWord, ftShortint, ftByte, ftExtended, ftConnection, ftParams, ftStream, //42..48
  //    ftTimeStampOffset, ftObject, ftSingle); //49..51

  //Currently supported field types are:
  //ftString, ftSmallint, ftInteger, ftWord, ftBoolean, ftFloat, ftCurrency, ftDate, ftTime
  //ftDateTime, ftBytes, ftVarBytes, ftAutoInc, ftBlob, ftMemo, ftGraphic, ftFmtMemo,
  //ftFixedChar, ftWideString, ftLargeint, ftFixedWideChar, ftWideMemo, ftLongWord, ftShortint,
  //ftByte, ftExtended, ftStream, ftSingle

  Result := AType;
  case Result of
    ftUnknown: ;
    ftString: ;
    ftSmallint: ;
    ftInteger: ;
    ftWord: ;
    ftBoolean: ;
    ftFloat: ;
    ftCurrency: ;
    ftBCD: Result := ftUnknown;
    ftDate: ;
    ftTime: ;
    ftDateTime: ;
    ftBytes: ;
    ftVarBytes: ;
    ftAutoInc: ;
    ftBlob: ;
    ftMemo: ;
    ftGraphic: ;
    ftFmtMemo: ;
    ftParadoxOle: Result := ftUnknown;
    ftDBaseOle: Result := ftUnknown;
    ftTypedBinary: Result := ftUnknown;
    ftCursor: Result := ftUnknown;
    ftFixedChar: ;
    ftWideString: ;
    ftLargeint: ;
    ftADT: Result := ftUnknown;
    ftArray: Result := ftUnknown;
    ftReference: Result := ftUnknown;
    ftDataSet: Result := ftUnknown;
    ftOraBlob: Result := ftUnknown;
    ftOraClob: Result := ftUnknown;
    ftVariant: Result := ftUnknown;
    ftInterface: Result := ftUnknown;
    ftIDispatch: Result := ftUnknown;
    ftGuid: Result := ftUnknown;
    ftTimeStamp: Result := ftUnknown;
    ftFMTBcd: Result := ftUnknown;
    ftFixedWideChar: ;
    ftWideMemo: ;
    ftOraTimeStamp: Result := ftUnknown;
    ftOraInterval: Result := ftUnknown;
    ftLongWord: ;
    ftShortint: ;
    ftByte: ;
    ftExtended: ;
    ftConnection: Result := ftUnknown;
    ftParams: Result := ftUnknown;
    ftStream: ;
    ftTimeStampOffset: Result := ftUnknown;
    ftObject: Result := ftUnknown;
    ftSingle: ;
    else Result := ftUnknown;
  end;
end;

class function TUtils.BoolToInt(Value: Boolean): Integer;
begin
  Result := 0;
  if Value then
    Result := 1;
end;

class function TUtils.BToStr(const AValue: Boolean): String;
begin
  SetLength(TrueBoolStrs, 2);
  TrueBoolStrs[0] := 'True';
  TrueBoolStrs[1] := '1';
  SetLength(FalseBoolStrs, 3);
  FalseBoolStrs[0] := 'False';
  FalseBoolStrs[1] := '0';
  FalseBoolStrs[2] := '';
  Result := BoolToStr(AValue, True);
end;

class function TUtils.IsMobilePlatform: Boolean;
begin
  {$IF DEFINED(ANDROID) OR DEFINED(IOS)}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

class function TUtils.ResolveDataPath(const SubPath: String): String;
var
  Resolved: String;
begin
  {$IF DEFINED(ANDROID) OR DEFINED(IOS)}
  // On mobile, relative paths don't resolve properly because there is
  // no predictable current directory. We map them under GetDocumentsPath
  // which is writable on both Android and iOS.
  if TPath.IsRelativePath(SubPath) then
    Resolved := TPath.Combine(TPath.GetDocumentsPath, SubPath)
  else
    Resolved := SubPath;
  // Ensure the directory exists (GetDocumentsPath is writable but
  // subdirectories may not exist yet on first run)
  if not TDirectory.Exists(Resolved) then
  begin
    try
      TDirectory.CreateDirectory(Resolved);
    except
      // Silently continue — engine will handle the missing dir gracefully
    end;
  end;
  Result := Resolved;
  {$ELSE}
  // On desktop, paths resolve relative to the executable directory,
  // which is the expected behavior. Return unchanged.
  Result := SubPath;
  {$ENDIF}
end;

end.
