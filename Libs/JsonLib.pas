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
unit JsonLib;

{******************************************************************************
  JsonLib - JSON Support Library for Plan9Basic

  Provides comprehensive JSON manipulation functions using Delphi's System.JSON.
  All JSON values are tracked by the garbage collector for automatic cleanup.

  Version: 1.0
  Date: 2025

  Function naming convention:
    json_xxx#()   - Returns pointer (JSON value)
    json_xxx$()   - Returns string
    json_xxx()    - Returns number
******************************************************************************}

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections,
  exec, UnitGC;

const
  JSON_GC_TAG = 'BASIC_JSON';

  // JSON type codes (matching System.JSON)
  JSON_TYPE_NULL    = 0;
  JSON_TYPE_OBJECT  = 1;
  JSON_TYPE_ARRAY   = 2;
  JSON_TYPE_STRING  = 3;
  JSON_TYPE_NUMBER  = 4;
  JSON_TYPE_BOOLEAN = 5;

// Register all JSON functions with the function dictionary
procedure RegisterJsonFuncs(Funcs: TFunctionsDictionary);

// Helper function for deep cloning JSON values (used by parser)
function CloneJsonValue(Source: TJSONValue): TJSONValue;

implementation

//------------------------------------------------------------------------------
// Helper Functions
//------------------------------------------------------------------------------

// Deep clone a JSON value
function CloneJsonValue(Source: TJSONValue): TJSONValue;
var
  i: Integer;
  pair: TJSONPair;
  srcObj: TJSONObject;
  srcArr: TJSONArray;
begin
  if Source = nil then
    Exit(TJSONNull.Create);

  if Source is TJSONNull then
    Result := TJSONNull.Create
  else if Source is TJSONTrue then
    Result := TJSONTrue.Create
  else if Source is TJSONFalse then
    Result := TJSONFalse.Create
  else if Source is TJSONNumber then
    Result := TJSONNumber.Create(TJSONNumber(Source).AsDouble)
  else if Source is TJSONString then
    Result := TJSONString.Create(TJSONString(Source).Value)
  else if Source is TJSONObject then
  begin
    srcObj := TJSONObject(Source);
    Result := TJSONObject.Create;
    for i := 0 to srcObj.Count - 1 do
    begin
      pair := srcObj.Pairs[i];
      TJSONObject(Result).AddPair(pair.JsonString.Value, CloneJsonValue(pair.JsonValue));
    end;
  end
  else if Source is TJSONArray then
  begin
    srcArr := TJSONArray(Source);
    Result := TJSONArray.Create;
    for i := 0 to srcArr.Count - 1 do
      TJSONArray(Result).AddElement(CloneJsonValue(srcArr.Items[i]));
  end
  else
    Result := TJSONNull.Create;
end;

// Get JSON type code
function GetJsonTypeCode(Value: TJSONValue): Integer;
begin
  if Value = nil then
    Result := JSON_TYPE_NULL
  else if Value is TJSONNull then
    Result := JSON_TYPE_NULL
  else if Value is TJSONObject then
    Result := JSON_TYPE_OBJECT
  else if Value is TJSONArray then
    Result := JSON_TYPE_ARRAY
  else if Value is TJSONString then
    Result := JSON_TYPE_STRING
  else if Value is TJSONNumber then
    Result := JSON_TYPE_NUMBER
  else if (Value is TJSONTrue) or (Value is TJSONFalse) then
    Result := JSON_TYPE_BOOLEAN
  else
    Result := JSON_TYPE_NULL;
end;

// Navigate JSON by path (e.g., "user.profile.name" or "items[0].value")
function NavigateJsonPath(Root: TJSONValue; const Path: String): TJSONValue;
var
  current: TJSONValue;
  i, startPos, idx: Integer;
  key: String;
  arr: TJSONArray;
begin
  Result := nil;
  if Root = nil then Exit;
  if Path = '' then Exit(Root);

  current := Root;
  i := 1;

  while (i <= Length(Path)) and (current <> nil) do
  begin
    // Skip dots
    if Path[i] = '.' then
    begin
      Inc(i);
      Continue;
    end;

    // Handle array index [n]
    if Path[i] = '[' then
    begin
      Inc(i); // Skip '['
      startPos := i;
      while (i <= Length(Path)) and (Path[i] <> ']') do
        Inc(i);

      if i > Length(Path) then
        Exit(nil); // Malformed path

      key := Copy(Path, startPos, i - startPos);
      Inc(i); // Skip ']'

      if not TryStrToInt(key, idx) then
        Exit(nil); // Invalid index

      if not (current is TJSONArray) then
        Exit(nil);

      arr := TJSONArray(current);
      if (idx < 0) or (idx >= arr.Count) then
        Exit(nil);

      current := arr.Items[idx];
    end
    else
    begin
      // Handle object key
      startPos := i;
      while (i <= Length(Path)) and (Path[i] <> '.') and (Path[i] <> '[') do
        Inc(i);

      key := Copy(Path, startPos, i - startPos);

      if not (current is TJSONObject) then
        Exit(nil);

      current := TJSONObject(current).GetValue(key);
    end;
  end;

  Result := current;
end;

//------------------------------------------------------------------------------
// JSON Creation Functions
//------------------------------------------------------------------------------

// json_object#() - Create empty JSON object
function p_json_object(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  obj := TJSONObject.Create;
  GC.Add<TJSONObject>(obj, JSON_GC_TAG);
  Result.p := obj;
end;

// json_array#() - Create empty JSON array
function p_json_array(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  arr := TJSONArray.Create;
  GC.Add<TJSONArray>(arr, JSON_GC_TAG);
  Result.p := arr;
end;

// json_parse#(str$) - Parse JSON string
function p_json_parse(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  val := TJSONObject.ParseJSONValue(Args[0].s);
  if val <> nil then
  begin
    GC.Add<TJSONValue>(val, JSON_GC_TAG);
    Result.p := val;
  end;
end;

// json_null#() - Create JSON null value
function p_json_null(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONNull;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  val := TJSONNull.Create;
  GC.Add<TJSONNull>(val, JSON_GC_TAG);
  Result.p := val;
end;

// json_bool#(n) - Create JSON boolean (0=false, non-zero=true)
function p_json_bool(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].n <> 0 then
    val := TJSONTrue.Create
  else
    val := TJSONFalse.Create;

  GC.Add<TJSONValue>(val, JSON_GC_TAG);
  Result.p := val;
end;

// json_number#(n) - Create JSON number
function p_json_number(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONNumber;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  val := TJSONNumber.Create(Args[0].n);
  GC.Add<TJSONNumber>(val, JSON_GC_TAG);
  Result.p := val;
end;

// json_string#(str$) - Create JSON string
function p_json_string(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONString;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  val := TJSONString.Create(Args[0].s);
  GC.Add<TJSONString>(val, JSON_GC_TAG);
  Result.p := val;
end;

//------------------------------------------------------------------------------
// JSON Serialization Functions
//------------------------------------------------------------------------------

// json_stringify$(json#) - Convert JSON to string
function p_json_stringify(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);
  Result.s := val.ToString;
end;

// json_pretty$(json#) - Convert JSON to formatted string
function p_json_pretty_1(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);
  Result.s := val.Format(2);  // 2 spaces indent
end;

// json_pretty$(json#, indent) - Convert JSON to formatted string with custom indent
function p_json_pretty_2(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
  indent: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);
  indent := Round(Args[1].n);
  if indent < 0 then indent := 0;
  if indent > 8 then indent := 8;

  Result.s := val.Format(indent);
end;

//------------------------------------------------------------------------------
// JSON Type Functions
//------------------------------------------------------------------------------

// json_type(json#) - Get JSON type code
function p_json_type(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then
    Result.n := JSON_TYPE_NULL
  else
    Result.n := GetJsonTypeCode(TJSONValue(Args[0].p));
end;

// json_typename$(json#) - Get JSON type name
function p_json_typename(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := 'null';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);

  if val is TJSONNull then
    Result.s := 'null'
  else if val is TJSONObject then
    Result.s := 'object'
  else if val is TJSONArray then
    Result.s := 'array'
  else if val is TJSONString then
    Result.s := 'string'
  else if val is TJSONNumber then
    Result.s := 'number'
  else if (val is TJSONTrue) or (val is TJSONFalse) then
    Result.s := 'boolean'
  else
    Result.s := 'unknown';
end;

// json_isobj(json#) - Check if value is object
function p_json_isobj(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if (Args[0].p <> nil) and (TJSONValue(Args[0].p) is TJSONObject) then
    Result.n := 1;
end;

// json_isarr(json#) - Check if value is array
function p_json_isarr(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if (Args[0].p <> nil) and (TJSONValue(Args[0].p) is TJSONArray) then
    Result.n := 1;
end;

// json_isstr(json#) - Check if value is string
function p_json_isstr(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if (Args[0].p <> nil) and (TJSONValue(Args[0].p) is TJSONString) then
    Result.n := 1;
end;

// json_isnum(json#) - Check if value is number
function p_json_isnum(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if (Args[0].p <> nil) and (TJSONValue(Args[0].p) is TJSONNumber) then
    Result.n := 1;
end;

// json_isbool(json#) - Check if value is boolean
function p_json_isbool(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);
  if (val is TJSONTrue) or (val is TJSONFalse) then
    Result.n := 1;
end;

// json_isnull(json#) - Check if value is null
function p_json_isnull(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if (Args[0].p = nil) or (TJSONValue(Args[0].p) is TJSONNull) then
    Result.n := 1;
end;

//------------------------------------------------------------------------------
// JSON Object Access Functions
//------------------------------------------------------------------------------

// json_get#(obj#, key$) - Get value by key
function p_json_get(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  val := obj.GetValue(Args[1].s);

  if val <> nil then
    Result.p := val;
end;

// json_getn(obj#, key$) - Get number value by key
function p_json_getn_2(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  val := obj.GetValue(Args[1].s);

  if val <> nil then
  begin
    if val is TJSONNumber then
      Result.n := TJSONNumber(val).AsDouble
    else if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONFalse then
      Result.n := 0;
  end;
end;

// json_getn(obj#, key$, default) - Get number value by key with default
function p_json_getn_3(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val: TJSONValue;
begin
  Result.n := Args[2].n;  // Default value
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  val := obj.GetValue(Args[1].s);

  if val <> nil then
  begin
    if val is TJSONNumber then
      Result.n := TJSONNumber(val).AsDouble
    else if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONFalse then
      Result.n := 0;
  end;
end;

// json_gets$(obj#, key$) - Get string value by key
function p_json_gets_2(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  val := obj.GetValue(Args[1].s);

  if val <> nil then
  begin
    if val is TJSONString then
      Result.s := TJSONString(val).Value
    else
      Result.s := val.ToString;
  end;
end;

// json_gets$(obj#, key$, default$) - Get string value by key with default
function p_json_gets_3(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := Args[2].s;  // Default value

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  val := obj.GetValue(Args[1].s);

  if val <> nil then
  begin
    if val is TJSONString then
      Result.s := TJSONString(val).Value
    else
      Result.s := val.ToString;
  end;
end;

// json_getb(obj#, key$) - Get boolean value by key (returns 0 or 1)
function p_json_getb(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  val := obj.GetValue(Args[1].s);

  if val <> nil then
  begin
    if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONNumber then
    begin
      if TJSONNumber(val).AsDouble <> 0 then
        Result.n := 1;
    end;
  end;
end;

// json_has(obj#, key$) - Check if key exists
function p_json_has(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  if obj.GetValue(Args[1].s) <> nil then
    Result.n := 1;
end;

//------------------------------------------------------------------------------
// JSON Object Modification Functions
//------------------------------------------------------------------------------

// json_set#(obj#, key$, value#) - Set pointer value
function p_json_set(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  val, cloned: TJSONValue;
  i: Integer;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same object
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);

  // Remove existing key if present
  for i := obj.Count - 1 downto 0 do
  begin
    if obj.Pairs[i].JsonString.Value = Args[1].s then
    begin
      obj.RemovePair(Args[1].s);
      Break;
    end;
  end;

  // Clone the value to avoid ownership issues
  if Args[2].p <> nil then
  begin
    val := TJSONValue(Args[2].p);
    cloned := CloneJsonValue(val);
    // Don't add to GC - parent object takes ownership via AddPair
    obj.AddPair(Args[1].s, cloned);
  end
  else
    obj.AddPair(Args[1].s, TJSONNull.Create);
end;

// json_setn#(obj#, key$, value) - Set number value
function p_json_setn(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  i: Integer;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same object
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);

  // Remove existing key if present
  for i := obj.Count - 1 downto 0 do
  begin
    if obj.Pairs[i].JsonString.Value = Args[1].s then
    begin
      obj.RemovePair(Args[1].s);
      Break;
    end;
  end;

  obj.AddPair(Args[1].s, TJSONNumber.Create(Args[2].n));
end;

// json_sets#(obj#, key$, value$) - Set string value
function p_json_sets(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  i: Integer;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same object
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);

  // Remove existing key if present
  for i := obj.Count - 1 downto 0 do
  begin
    if obj.Pairs[i].JsonString.Value = Args[1].s then
    begin
      obj.RemovePair(Args[1].s);
      Break;
    end;
  end;

  obj.AddPair(Args[1].s, TJSONString.Create(Args[2].s));
end;

// json_setb#(obj#, key$, value) - Set boolean value
function p_json_setb(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  i: Integer;
  boolVal: TJSONValue;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same object
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);

  // Remove existing key if present
  for i := obj.Count - 1 downto 0 do
  begin
    if obj.Pairs[i].JsonString.Value = Args[1].s then
    begin
      obj.RemovePair(Args[1].s);
      Break;
    end;
  end;

  if Args[2].n <> 0 then
    boolVal := TJSONTrue.Create
  else
    boolVal := TJSONFalse.Create;

  obj.AddPair(Args[1].s, boolVal);
end;

// json_setnull#(obj#, key$) - Set null value
function p_json_setnull(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  i: Integer;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same object
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);

  // Remove existing key if present
  for i := obj.Count - 1 downto 0 do
  begin
    if obj.Pairs[i].JsonString.Value = Args[1].s then
    begin
      obj.RemovePair(Args[1].s);
      Break;
    end;
  end;

  obj.AddPair(Args[1].s, TJSONNull.Create);
end;

// json_remove#(obj#, key$) - Remove key from object
function p_json_remove(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same object
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  obj.RemovePair(Args[1].s);
end;

// json_keys#(obj#) - Get array of keys
function p_json_keys(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
  arr: TJSONArray;
  i: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  arr := TJSONArray.Create;
  GC.Add<TJSONArray>(arr, JSON_GC_TAG);

  for i := 0 to obj.Count - 1 do
    arr.AddElement(TJSONString.Create(obj.Pairs[i].JsonString.Value));

  Result.p := arr;
end;

// json_count(obj#) - Get number of keys in object
function p_json_count(var Args: Array of TAsmData): TAsmData;
var
  obj: TJSONObject;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;

  obj := TJSONObject(Args[0].p);
  Result.n := obj.Count;
end;

// json_merge#(target#, source#) - Merge source into target
function p_json_merge(var Args: Array of TAsmData): TAsmData;
var
  target, source: TJSONObject;
  pair: TJSONPair;
  i, j: Integer;
  cloned: TJSONValue;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return target
  Result.s := '';

  if Args[0].p = nil then Exit;
  if Args[1].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONObject) then Exit;
  if not (TJSONValue(Args[1].p) is TJSONObject) then Exit;

  target := TJSONObject(Args[0].p);
  source := TJSONObject(Args[1].p);

  for i := 0 to source.Count - 1 do
  begin
    pair := source.Pairs[i];

    // Remove existing key if present
    for j := target.Count - 1 downto 0 do
    begin
      if target.Pairs[j].JsonString.Value = pair.JsonString.Value then
      begin
        target.RemovePair(pair.JsonString.Value);
        Break;
      end;
    end;

    // Clone and add - don't add to GC, parent takes ownership
    cloned := CloneJsonValue(pair.JsonValue);
    target.AddPair(pair.JsonString.Value, cloned);
  end;
end;

//------------------------------------------------------------------------------
// JSON Array Functions
//------------------------------------------------------------------------------

// json_len(json#) - Get length (array count or object key count)
function p_json_len(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);

  if val is TJSONArray then
    Result.n := TJSONArray(val).Count
  else if val is TJSONObject then
    Result.n := TJSONObject(val).Count
  else if val is TJSONString then
    Result.n := Length(TJSONString(val).Value);
end;

// json_item#(arr#, index) - Get array item as pointer
function p_json_item(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
    Result.p := arr.Items[idx];
end;

// json_itemn(arr#, index) - Get array item as number
function p_json_itemn_2(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
  begin
    val := arr.Items[idx];
    if val is TJSONNumber then
      Result.n := TJSONNumber(val).AsDouble
    else if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONFalse then
      Result.n := 0;
  end;
end;

// json_itemn(arr#, index, default) - Get array item as number with default
function p_json_itemn_3(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
  val: TJSONValue;
begin
  Result.n := Args[2].n;  // Default
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
  begin
    val := arr.Items[idx];
    if val is TJSONNumber then
      Result.n := TJSONNumber(val).AsDouble
    else if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONFalse then
      Result.n := 0;
  end;
end;

// json_items$(arr#, index) - Get array item as string
function p_json_items_2(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
  begin
    val := arr.Items[idx];
    if val is TJSONString then
      Result.s := TJSONString(val).Value
    else
      Result.s := val.ToString;
  end;
end;

// json_items$(arr#, index, default$) - Get array item as string with default
function p_json_items_3(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := Args[2].s;  // Default

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
  begin
    val := arr.Items[idx];
    if val is TJSONString then
      Result.s := TJSONString(val).Value
    else
      Result.s := val.ToString;
  end;
end;

// json_itemb(arr#, index) - Get array item as boolean
function p_json_itemb(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
  begin
    val := arr.Items[idx];
    if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONNumber then
    begin
      if TJSONNumber(val).AsDouble <> 0 then
        Result.n := 1;
    end;
  end;
end;

// json_push#(arr#, value#) - Push pointer value to array
function p_json_push(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  val, cloned: TJSONValue;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same array
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);

  if Args[1].p <> nil then
  begin
    val := TJSONValue(Args[1].p);
    cloned := CloneJsonValue(val);
    // Don't add to GC - parent array takes ownership via AddElement
    arr.AddElement(cloned);
  end
  else
    arr.AddElement(TJSONNull.Create);
end;

// json_pushn#(arr#, value) - Push number to array
function p_json_pushn(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same array
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  arr.AddElement(TJSONNumber.Create(Args[1].n));
end;

// json_pushs#(arr#, value$) - Push string to array
function p_json_pushs(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same array
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  arr.AddElement(TJSONString.Create(Args[1].s));
end;

// json_pushb#(arr#, value) - Push boolean to array
function p_json_pushb(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  boolVal: TJSONValue;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same array
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);

  if Args[1].n <> 0 then
    boolVal := TJSONTrue.Create
  else
    boolVal := TJSONFalse.Create;

  arr.AddElement(boolVal);
end;

// json_pushnull#(arr#) - Push null to array
function p_json_pushnull(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same array
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  arr.AddElement(TJSONNull.Create);
end;

// json_pop#(arr#) - Remove and return last element
function p_json_pop(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  val, cloned: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  if arr.Count = 0 then Exit;

  val := arr.Items[arr.Count - 1];
  cloned := CloneJsonValue(val);
  GC.Add<TJSONValue>(cloned, JSON_GC_TAG);

  arr.Remove(arr.Count - 1);
  Result.p := cloned;
end;

// json_removeat#(arr#, index) - Remove element at index
function p_json_removeat(var Args: Array of TAsmData): TAsmData;
var
  arr: TJSONArray;
  idx: Integer;
begin
  Result.n := 0;
  Result.p := Args[0].p;  // Return same array
  Result.s := '';

  if Args[0].p = nil then Exit;
  if not (TJSONValue(Args[0].p) is TJSONArray) then Exit;

  arr := TJSONArray(Args[0].p);
  idx := Round(Args[1].n);

  if (idx >= 0) and (idx < arr.Count) then
    arr.Remove(idx);
end;

//------------------------------------------------------------------------------
// JSON Path Functions
//------------------------------------------------------------------------------

// json_path#(json#, path$) - Navigate by path
function p_json_path(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := NavigateJsonPath(TJSONValue(Args[0].p), Args[1].s);
  if val <> nil then
    Result.p := val;
end;

// json_pathn(json#, path$) - Get number at path
function p_json_pathn_2(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := NavigateJsonPath(TJSONValue(Args[0].p), Args[1].s);

  if val <> nil then
  begin
    if val is TJSONNumber then
      Result.n := TJSONNumber(val).AsDouble
    else if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONFalse then
      Result.n := 0;
  end;
end;

// json_pathn(json#, path$, default) - Get number at path with default
function p_json_pathn_3(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := Args[2].n;  // Default
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := NavigateJsonPath(TJSONValue(Args[0].p), Args[1].s);

  if val <> nil then
  begin
    if val is TJSONNumber then
      Result.n := TJSONNumber(val).AsDouble
    else if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONFalse then
      Result.n := 0;
  end;
end;

// json_paths$(json#, path$) - Get string at path
function p_json_paths_2(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := NavigateJsonPath(TJSONValue(Args[0].p), Args[1].s);

  if val <> nil then
  begin
    if val is TJSONString then
      Result.s := TJSONString(val).Value
    else
      Result.s := val.ToString;
  end;
end;

// json_paths$(json#, path$, default$) - Get string at path with default
function p_json_paths_3(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := Args[2].s;  // Default

  if Args[0].p = nil then Exit;

  val := NavigateJsonPath(TJSONValue(Args[0].p), Args[1].s);

  if val <> nil then
  begin
    if val is TJSONString then
      Result.s := TJSONString(val).Value
    else
      Result.s := val.ToString;
  end;
end;

// json_pathb(json#, path$) - Get boolean at path
function p_json_pathb(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := NavigateJsonPath(TJSONValue(Args[0].p), Args[1].s);

  if val <> nil then
  begin
    if val is TJSONTrue then
      Result.n := 1
    else if val is TJSONNumber then
    begin
      if TJSONNumber(val).AsDouble <> 0 then
        Result.n := 1;
    end;
  end;
end;

//------------------------------------------------------------------------------
// Utility Functions
//------------------------------------------------------------------------------

// json_clone#(json#) - Deep clone JSON value
function p_json_clone(var Args: Array of TAsmData): TAsmData;
var
  val, cloned: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);
  cloned := CloneJsonValue(val);
  GC.Add<TJSONValue>(cloned, JSON_GC_TAG);

  Result.p := cloned;
end;

// json_value(json#) - Get primitive value as number
function p_json_value(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);

  if val is TJSONNumber then
    Result.n := TJSONNumber(val).AsDouble
  else if val is TJSONTrue then
    Result.n := 1
  else if val is TJSONFalse then
    Result.n := 0;
end;

// json_value$(json#) - Get primitive value as string
function p_json_values(var Args: Array of TAsmData): TAsmData;
var
  val: TJSONValue;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Args[0].p = nil then Exit;

  val := TJSONValue(Args[0].p);

  if val is TJSONString then
    Result.s := TJSONString(val).Value
  else if val is TJSONNull then
    Result.s := ''
  else
    Result.s := val.ToString;
end;

//------------------------------------------------------------------------------
// Registration
//------------------------------------------------------------------------------

procedure RegisterJsonFuncs(Funcs: TFunctionsDictionary);
var
  Fn: TLinkFunction;
begin
  // Creation functions
  Fn.FarCall := True;
  Fn.Entry := @p_json_object; Funcs.Add('json_object#@', Fn);
  Fn.Entry := @p_json_array; Funcs.Add('json_array#@', Fn);
  Fn.Entry := @p_json_parse; Funcs.Add('json_parse#@$', Fn);
  Fn.Entry := @p_json_null; Funcs.Add('json_null#@', Fn);
  Fn.Entry := @p_json_bool; Funcs.Add('json_bool#@n', Fn);
  Fn.Entry := @p_json_number; Funcs.Add('json_number#@n', Fn);
  Fn.Entry := @p_json_string; Funcs.Add('json_string#@$', Fn);

  // Serialization functions
  Fn.Entry := @p_json_stringify; Funcs.Add('json_stringify$@#', Fn);
  Fn.Entry := @p_json_pretty_1; Funcs.Add('json_pretty$@#', Fn);
  Fn.Entry := @p_json_pretty_2; Funcs.Add('json_pretty$@#n', Fn);

  // Type functions
  Fn.Entry := @p_json_type; Funcs.Add('json_type@#', Fn);
  Fn.Entry := @p_json_typename; Funcs.Add('json_typename$@#', Fn);
  Fn.Entry := @p_json_isobj; Funcs.Add('json_isobj@#', Fn);
  Fn.Entry := @p_json_isarr; Funcs.Add('json_isarr@#', Fn);
  Fn.Entry := @p_json_isstr; Funcs.Add('json_isstr@#', Fn);
  Fn.Entry := @p_json_isnum; Funcs.Add('json_isnum@#', Fn);
  Fn.Entry := @p_json_isbool; Funcs.Add('json_isbool@#', Fn);
  Fn.Entry := @p_json_isnull; Funcs.Add('json_isnull@#', Fn);

  // Object access functions
  Fn.Entry := @p_json_get; Funcs.Add('json_get#@#$', Fn);
  Fn.Entry := @p_json_getn_2; Funcs.Add('json_getn@#$', Fn);
  Fn.Entry := @p_json_getn_3; Funcs.Add('json_getn@#$n', Fn);
  Fn.Entry := @p_json_gets_2; Funcs.Add('json_gets$@#$', Fn);
  Fn.Entry := @p_json_gets_3; Funcs.Add('json_gets$@#$$', Fn);
  Fn.Entry := @p_json_getb; Funcs.Add('json_getb@#$', Fn);
  Fn.Entry := @p_json_has; Funcs.Add('json_has@#$', Fn);

  // Object modification functions
  Fn.Entry := @p_json_set; Funcs.Add('json_set#@#$#', Fn);
  Fn.Entry := @p_json_setn; Funcs.Add('json_setn#@#$n', Fn);
  Fn.Entry := @p_json_sets; Funcs.Add('json_sets#@#$$', Fn);
  Fn.Entry := @p_json_setb; Funcs.Add('json_setb#@#$n', Fn);
  Fn.Entry := @p_json_setnull; Funcs.Add('json_setnull#@#$', Fn);
  Fn.Entry := @p_json_remove; Funcs.Add('json_remove#@#$', Fn);
  Fn.Entry := @p_json_keys; Funcs.Add('json_keys#@#', Fn);
  Fn.Entry := @p_json_count; Funcs.Add('json_count@#', Fn);
  Fn.Entry := @p_json_merge; Funcs.Add('json_merge#@##', Fn);

  // Array functions
  Fn.Entry := @p_json_len; Funcs.Add('json_len@#', Fn);
  Fn.Entry := @p_json_item; Funcs.Add('json_item#@#n', Fn);
  Fn.Entry := @p_json_itemn_2; Funcs.Add('json_itemn@#n', Fn);
  Fn.Entry := @p_json_itemn_3;  Funcs.Add('json_itemn@#nn', Fn);
  Fn.Entry := @p_json_items_2;  Funcs.Add('json_items$@#n', Fn);
  Fn.Entry := @p_json_items_3; Funcs.Add('json_items$@#n$', Fn);
  Fn.Entry := @p_json_itemb; Funcs.Add('json_itemb@#n', Fn);
  Fn.Entry := @p_json_push; Funcs.Add('json_push#@##', Fn);
  Fn.Entry := @p_json_pushn; Funcs.Add('json_pushn#@#n', Fn);
  Fn.Entry := @p_json_pushs; Funcs.Add('json_pushs#@#$', Fn);
  Fn.Entry := @p_json_pushb; Funcs.Add('json_pushb#@#n', Fn);
  Fn.Entry := @p_json_pushnull; Funcs.Add('json_pushnull#@#', Fn);
  Fn.Entry := @p_json_pop; Funcs.Add('json_pop#@#', Fn);
  Fn.Entry := @p_json_removeat; Funcs.Add('json_removeat#@#n', Fn);

  // Path functions
  Fn.Entry := @p_json_path; Funcs.Add('json_path#@#$', Fn);
  Fn.Entry := @p_json_pathn_2; Funcs.Add('json_pathn@#$', Fn);
  Fn.Entry := @p_json_pathn_3; Funcs.Add('json_pathn@#$n', Fn);
  Fn.Entry := @p_json_paths_2; Funcs.Add('json_paths$@#$', Fn);
  Fn.Entry := @p_json_paths_3; Funcs.Add('json_paths$@#$$', Fn);
  Fn.Entry := @p_json_pathb; Funcs.Add('json_pathb@#$', Fn);

  // Utility functions
  Fn.Entry := @p_json_clone; Funcs.Add('json_clone#@#', Fn);
  Fn.Entry := @p_json_value; Funcs.Add('json_value@#', Fn);
  Fn.Entry := @p_json_values; Funcs.Add('json_value$@#', Fn);
end;

end.

