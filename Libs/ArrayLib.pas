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
unit ArrayLib;

{******************************************************************************
  ArrayLib - Refactored Array Library for Plan9Basic

  Features:
  - 1-based indexing (traditional BASIC style)
  - Support for 1 to 10 dimensions
  - Type safety with TBasArrayType enum
  - Numeric, String, and Pointer arrays
  - Proper bounds checking with clear error messages
  - 64-bit compatibility (NativeInt for pointers)
  - Reduced code duplication via universal functions

  Version: 2.0 Refactored
  Date: January 2026
******************************************************************************}

interface

uses
  System.SysUtils, System.Math,
  exec, UnitGC;

type
  // Dynamic array type for dimensions (consistent usage)
  TIntegerDynArray = array of Integer;

  // Array type enumeration for runtime type checking
  TBasArrayType = (batNumeric, batString, batPointer);

  // Base class for all array types
  TBasArrayBase = class
  protected
    FArrayType: TBasArrayType;
    FDimensions: TIntegerDynArray;
  public
    property ArrayType: TBasArrayType read FArrayType;
    property Dimensions: TIntegerDynArray read FDimensions;
    function GetDimensionCount: Integer;
    function GetBound(dim: Integer): Integer;
    function GetTotalSize: Integer;
  end;

  // Numeric array class
  TBasNumericArray = class(TBasArrayBase)
  public
    Data: array of Extended;
    constructor Create(const dims: array of Integer);
  end;

  // String array class
  TBasStringArray = class(TBasArrayBase)
  public
    Data: array of String;
    constructor Create(const dims: array of Integer);
  end;

  // Pointer array class
  TBasPointerArray = class(TBasArrayBase)
  public
    Data: array of Pointer;
    constructor Create(const dims: array of Integer);
  end;

// Library registration
procedure RegisterArrayFuncs(Lib: TFunctionsDictionary);

// Utility functions (exposed for testing)
function GetArrayTypeName(at: TBasArrayType): String;
procedure ValidateArrayType(p: Pointer; expected: TBasArrayType; const funcName: String);

implementation

const
  ARRAY_GC_TAG = 'BASIC_ARRAY';

{------------------------------------------------------------------------------
  TBasArrayBase - Base class implementation
------------------------------------------------------------------------------}

function TBasArrayBase.GetDimensionCount: Integer;
begin
  Result := Length(FDimensions);
end;

function TBasArrayBase.GetBound(dim: Integer): Integer;
begin
  // 1-based dimension index for BASIC compatibility
  if (dim < 1) or (dim > Length(FDimensions)) then
    raise Exception.CreateFmt('Invalid dimension: %d (valid: 1..%d)', [dim, Length(FDimensions)]);
  Result := FDimensions[dim - 1];
end;

function TBasArrayBase.GetTotalSize: Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 0 to Length(FDimensions) - 1 do
    Result := Result * FDimensions[i];
end;

{------------------------------------------------------------------------------
  TBasNumericArray
------------------------------------------------------------------------------}

constructor TBasNumericArray.Create(const dims: array of Integer);
var
  i, totalSize: Integer;
begin
  inherited Create;
  FArrayType := batNumeric;

  SetLength(FDimensions, Length(dims));
  totalSize := 1;
  for i := 0 to Length(dims) - 1 do
  begin
    if dims[i] < 1 then
      raise Exception.CreateFmt('Invalid dimension size: %d (must be >= 1)', [dims[i]]);
    FDimensions[i] := dims[i];
    totalSize := totalSize * dims[i];
  end;

  SetLength(Data, totalSize);
  // Initialize to zero
  for i := 0 to totalSize - 1 do
    Data[i] := 0;
end;

{------------------------------------------------------------------------------
  TBasStringArray
------------------------------------------------------------------------------}

constructor TBasStringArray.Create(const dims: array of Integer);
var
  i, totalSize: Integer;
begin
  inherited Create;
  FArrayType := batString;

  SetLength(FDimensions, Length(dims));
  totalSize := 1;
  for i := 0 to Length(dims) - 1 do
  begin
    if dims[i] < 1 then
      raise Exception.CreateFmt('Invalid dimension size: %d (must be >= 1)', [dims[i]]);
    FDimensions[i] := dims[i];
    totalSize := totalSize * dims[i];
  end;

  SetLength(Data, totalSize);
  // Initialize to empty strings
  for i := 0 to totalSize - 1 do
    Data[i] := '';
end;

{------------------------------------------------------------------------------
  TBasPointerArray
------------------------------------------------------------------------------}

constructor TBasPointerArray.Create(const dims: array of Integer);
var
  i, totalSize: Integer;
begin
  inherited Create;
  FArrayType := batPointer;

  SetLength(FDimensions, Length(dims));
  totalSize := 1;
  for i := 0 to Length(dims) - 1 do
  begin
    if dims[i] < 1 then
      raise Exception.CreateFmt('Invalid dimension size: %d (must be >= 1)', [dims[i]]);
    FDimensions[i] := dims[i];
    totalSize := totalSize * dims[i];
  end;

  SetLength(Data, totalSize);
  // Initialize to nil
  for i := 0 to totalSize - 1 do
    Data[i] := nil;
end;

{------------------------------------------------------------------------------
  Helper Functions
------------------------------------------------------------------------------}

function GetArrayTypeName(at: TBasArrayType): String;
begin
  case at of
    batNumeric: Result := 'numeric';
    batString:  Result := 'string';
    batPointer: Result := 'pointer';
  else
    Result := 'unknown';
  end;
end;

procedure ValidateArrayType(p: Pointer; expected: TBasArrayType; const funcName: String);
var
  base: TBasArrayBase;
begin
  if p = nil then
    raise Exception.CreateFmt('%s: Null array pointer', [funcName]);

  if not (TObject(p) is TBasArrayBase) then
    raise Exception.CreateFmt('%s: Invalid array object', [funcName]);

  base := TBasArrayBase(p);
  if base.ArrayType <> expected then
    raise Exception.CreateFmt('%s: Expected %s array, got %s array', [funcName, GetArrayTypeName(expected), GetArrayTypeName(base.ArrayType)]);
end;

// Safely truncate Extended to Integer for indices
function SafeTruncIndex(value: Extended): Integer;
begin
  if IsNaN(value) or IsInfinite(value) then
    raise Exception.Create('Invalid array index (NaN or Infinite)');
  Result := Trunc(value);
end;

// Calculate linear index from 1-based multi-dimensional indices
// Converts 1-based indices to 0-based linear index
function CalculateLinearIndex(const Args: array of TAsmData;
  startIdx, count: Integer; const dims: TIntegerDynArray): Integer;
var
  i, idx, multiplier: Integer;
begin
  Result := 0;
  multiplier := 1;

  for i := 0 to count - 1 do
  begin
    idx := SafeTruncIndex(Args[startIdx + i].n);

    // 1-based bounds check: valid range is 1..dims[i]
    if (idx < 1) or (idx > dims[i]) then
      raise Exception.CreateFmt('Index %d out of bounds: %d (valid: 1..%d)', [i + 1, idx, dims[i]]);

    // Convert 1-based to 0-based for linear calculation
    Result := Result + (idx - 1) * multiplier;
    multiplier := multiplier * dims[i];
  end;
end;

{------------------------------------------------------------------------------
  Array Creation Functions - Universal for 1-10 dimensions
------------------------------------------------------------------------------}

// dim#(d1[, d2, ..., d10]) - Create numeric array
function p_ndim(var Args: array of TAsmData): TAsmData;
var
  arr: TBasNumericArray;
  dims: array of Integer;
  i: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('dim# requires at least one dimension');
  if Length(Args) > 10 then
    raise Exception.Create('dim# supports maximum 10 dimensions');

  SetLength(dims, Length(Args));
  for i := 0 to Length(Args) - 1 do
  begin
    dims[i] := SafeTruncIndex(Args[i].n);
    if dims[i] < 1 then
      raise Exception.CreateFmt('Dimension %d must be >= 1, got %d', [i + 1, dims[i]]);
  end;

  arr := TBasNumericArray.Create(dims);

  if Assigned(UnitGC.GC) then
    UnitGC.GC.Add<TBasNumericArray>(arr, ARRAY_GC_TAG + '_' + IntToStr(NativeInt(arr)));

  Result.p := arr;
end;

// sdim#(d1[, d2, ..., d10]) - Create string array
function p_sdim(var Args: array of TAsmData): TAsmData;
var
  arr: TBasStringArray;
  dims: array of Integer;
  i: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('sdim# requires at least one dimension');
  if Length(Args) > 10 then
    raise Exception.Create('sdim# supports maximum 10 dimensions');

  SetLength(dims, Length(Args));
  for i := 0 to Length(Args) - 1 do
  begin
    dims[i] := SafeTruncIndex(Args[i].n);
    if dims[i] < 1 then
      raise Exception.CreateFmt('Dimension %d must be >= 1, got %d', [i + 1, dims[i]]);
  end;

  arr := TBasStringArray.Create(dims);

  if Assigned(UnitGC.GC) then
    UnitGC.GC.Add<TBasStringArray>(arr, ARRAY_GC_TAG + '_' + IntToStr(NativeInt(arr)));

  Result.p := arr;
end;

// pdim#(d1[, d2, ..., d10]) - Create pointer array
function p_pdim(var Args: array of TAsmData): TAsmData;
var
  arr: TBasPointerArray;
  dims: array of Integer;
  i: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('pdim# requires at least one dimension');
  if Length(Args) > 10 then
    raise Exception.Create('pdim# supports maximum 10 dimensions');

  SetLength(dims, Length(Args));
  for i := 0 to Length(Args) - 1 do
  begin
    dims[i] := SafeTruncIndex(Args[i].n);
    if dims[i] < 1 then
      raise Exception.CreateFmt('Dimension %d must be >= 1, got %d', [i + 1, dims[i]]);
  end;

  arr := TBasPointerArray.Create(dims);

  if Assigned(UnitGC.GC) then
    UnitGC.GC.Add<TBasPointerArray>(arr, ARRAY_GC_TAG + '_' + IntToStr(NativeInt(arr)));

  Result.p := arr;
end;

{------------------------------------------------------------------------------
  Numeric Array Access Functions
------------------------------------------------------------------------------}

// narr_get(arr#, i1[, i2, ..., i10]) - Get value from numeric array
function n_narr_get(var Args: array of TAsmData): TAsmData;
var
  arr: TBasNumericArray;
  dimCount, linearIdx: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('narr_get requires array and at least one index');

  ValidateArrayType(Args[0].p, batNumeric, 'narr_get');
  arr := TBasNumericArray(Args[0].p);

  dimCount := Length(Args) - 1;

  if dimCount <> Length(arr.Dimensions) then
    raise Exception.CreateFmt('Dimension mismatch: array has %d dimensions, got %d indices', [Length(arr.Dimensions), dimCount]);

  linearIdx := CalculateLinearIndex(Args, 1, dimCount, arr.Dimensions);
  Result.n := arr.Data[linearIdx];
end;

// narr_set(arr#, i1[, i2, ..., i10], value) - Set value in numeric array
function n_narr_set(var Args: array of TAsmData): TAsmData;
var
  arr: TBasNumericArray;
  dimCount, linearIdx: Integer;
  value: Extended;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('narr_set requires array, at least one index, and value');

  ValidateArrayType(Args[0].p, batNumeric, 'narr_set');
  arr := TBasNumericArray(Args[0].p);

  dimCount := Length(Args) - 2;  // -1 for array, -1 for value
  value := Args[Length(Args) - 1].n;

  if dimCount <> Length(arr.Dimensions) then
    raise Exception.CreateFmt('Dimension mismatch: array has %d dimensions, got %d indices', [Length(arr.Dimensions), dimCount]);

  linearIdx := CalculateLinearIndex(Args, 1, dimCount, arr.Dimensions);
  arr.Data[linearIdx] := value;
end;

{------------------------------------------------------------------------------
  String Array Access Functions
------------------------------------------------------------------------------}

// sarr_get(arr#, i1[, i2, ..., i10]) - Get value from string array
function s_sarr_get(var Args: array of TAsmData): TAsmData;
var
  arr: TBasStringArray;
  dimCount, linearIdx: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('sarr_get requires array and at least one index');

  ValidateArrayType(Args[0].p, batString, 'sarr_get');
  arr := TBasStringArray(Args[0].p);

  dimCount := Length(Args) - 1;

  if dimCount <> Length(arr.Dimensions) then
    raise Exception.CreateFmt('Dimension mismatch: array has %d dimensions, got %d indices', [Length(arr.Dimensions), dimCount]);

  linearIdx := CalculateLinearIndex(Args, 1, dimCount, arr.Dimensions);
  Result.s := arr.Data[linearIdx];
end;

// sarr_set(arr#, i1[, i2, ..., i10], value$) - Set value in string array
function p_sarr_set(var Args: array of TAsmData): TAsmData;
var
  arr: TBasStringArray;
  dimCount, linearIdx: Integer;
  value: String;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('sarr_set requires array, at least one index, and value');

  ValidateArrayType(Args[0].p, batString, 'sarr_set');
  arr := TBasStringArray(Args[0].p);

  dimCount := Length(Args) - 2;
  value := Args[Length(Args) - 1].s;

  if dimCount <> Length(arr.Dimensions) then
    raise Exception.CreateFmt('Dimension mismatch: array has %d dimensions, got %d indices', [Length(arr.Dimensions), dimCount]);

  linearIdx := CalculateLinearIndex(Args, 1, dimCount, arr.Dimensions);
  arr.Data[linearIdx] := value;
end;

{------------------------------------------------------------------------------
  Pointer Array Access Functions
------------------------------------------------------------------------------}

// parr_get(arr#, i1[, i2, ..., i10]) - Get value from pointer array
function p_parr_get(var Args: array of TAsmData): TAsmData;
var
  arr: TBasPointerArray;
  dimCount, linearIdx: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('parr_get requires array and at least one index');

  ValidateArrayType(Args[0].p, batPointer, 'parr_get');
  arr := TBasPointerArray(Args[0].p);

  dimCount := Length(Args) - 1;

  if dimCount <> Length(arr.Dimensions) then
    raise Exception.CreateFmt('Dimension mismatch: array has %d dimensions, got %d indices', [Length(arr.Dimensions), dimCount]);

  linearIdx := CalculateLinearIndex(Args, 1, dimCount, arr.Dimensions);
  Result.p := arr.Data[linearIdx];
end;

// parr_set(arr#, i1[, i2, ..., i10], value#) - Set value in pointer array
function p_parr_set(var Args: array of TAsmData): TAsmData;
var
  arr: TBasPointerArray;
  dimCount, linearIdx: Integer;
  value: Pointer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('parr_set requires array, at least one index, and value');

  ValidateArrayType(Args[0].p, batPointer, 'parr_set');
  arr := TBasPointerArray(Args[0].p);

  dimCount := Length(Args) - 2;
  value := Args[Length(Args) - 1].p;

  if dimCount <> Length(arr.Dimensions) then
    raise Exception.CreateFmt('Dimension mismatch: array has %d dimensions, got %d indices', [Length(arr.Dimensions), dimCount]);

  linearIdx := CalculateLinearIndex(Args, 1, dimCount, arr.Dimensions);
  arr.Data[linearIdx] := value;
end;

{------------------------------------------------------------------------------
  Array Utility Functions
------------------------------------------------------------------------------}

// ndims(arr#) - Get number of dimensions
function n_ndims(var Args: array of TAsmData): TAsmData;
var
  base: TBasArrayBase;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('ndims requires array argument');

  if Args[0].p = nil then
    raise Exception.Create('ndims: Null array pointer');

  if not (TObject(Args[0].p) is TBasArrayBase) then
    raise Exception.Create('ndims: Invalid array object');

  base := TBasArrayBase(Args[0].p);
  Result.n := base.GetDimensionCount;
end;

// ubound(arr#, dim) - Get upper bound of dimension (1-based dim parameter)
function n_ubound(var Args: array of TAsmData): TAsmData;
var
  base: TBasArrayBase;
  dim: Integer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('ubound requires array and dimension arguments');

  if Args[0].p = nil then
    raise Exception.Create('ubound: Null array pointer');

  if not (TObject(Args[0].p) is TBasArrayBase) then
    raise Exception.Create('ubound: Invalid array object');

  base := TBasArrayBase(Args[0].p);
  dim := SafeTruncIndex(Args[1].n);

  // GetBound already uses 1-based dimension indexing
  Result.n := base.GetBound(dim);
end;

// lbound(arr#, dim) - Get lower bound of dimension (always 1 for BASIC)
function n_lbound(var Args: array of TAsmData): TAsmData;
var
  base: TBasArrayBase;
  dim: Integer;
begin
  Result.n := 1;  // Always 1 for 1-based arrays
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('lbound requires array and dimension arguments');

  if Args[0].p = nil then
    raise Exception.Create('lbound: Null array pointer');

  if not (TObject(Args[0].p) is TBasArrayBase) then
    raise Exception.Create('lbound: Invalid array object');

  base := TBasArrayBase(Args[0].p);
  dim := SafeTruncIndex(Args[1].n);

  // Validate dimension exists
  if (dim < 1) or (dim > base.GetDimensionCount) then
    raise Exception.CreateFmt('Invalid dimension: %d (valid: 1..%d)', [dim, base.GetDimensionCount]);
end;

// arraysize(arr#) - Get total number of elements
function n_arraysize(var Args: array of TAsmData): TAsmData;
var
  base: TBasArrayBase;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('arraysize requires array argument');

  if Args[0].p = nil then
    raise Exception.Create('arraysize: Null array pointer');

  if not (TObject(Args[0].p) is TBasArrayBase) then
    raise Exception.Create('arraysize: Invalid array object');

  base := TBasArrayBase(Args[0].p);
  Result.n := base.GetTotalSize;
end;

// arraytype(arr#) - Get array type (0=numeric, 1=string, 2=pointer)
function n_arraytype(var Args: array of TAsmData): TAsmData;
var
  base: TBasArrayBase;
begin
  Result.n := -1;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('arraytype requires array argument');

  if Args[0].p = nil then
    raise Exception.Create('arraytype: Null array pointer');

  if not (TObject(Args[0].p) is TBasArrayBase) then
    raise Exception.Create('arraytype: Invalid array object');

  base := TBasArrayBase(Args[0].p);
  Result.n := Ord(base.ArrayType);
end;

// arraytypename$(arr#) - Get array type name as string
function s_arraytypename(var Args: array of TAsmData): TAsmData;
var
  base: TBasArrayBase;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('arraytypename$ requires array argument');

  if Args[0].p = nil then
    raise Exception.Create('arraytypename$: Null array pointer');

  if not (TObject(Args[0].p) is TBasArrayBase) then
    raise Exception.Create('arraytypename$: Invalid array object');

  base := TBasArrayBase(Args[0].p);
  Result.s := GetArrayTypeName(base.ArrayType);
end;

// arr_free(arr#) - Free an array and remove from garbage collector
// Returns: 1 on success, 0 if array was nil or invalid
//
// Usage:
//   let myArray# = dim#(100)
//   ' ... use array ...
//   arr_free(myArray#)   ' Free when done
//
function n_arr_free(var Args: array of TAsmData): TAsmData;
var
  obj: TObject;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  // Check for nil pointer
  if Args[0].p = nil then
    Exit;

  // Validate it's an array object
  obj := TObject(Args[0].p);
  if not (obj is TBasArrayBase) then
    raise Exception.Create('arr_free: Invalid array pointer');

  // Remove from garbage collector using pointer address as tag
  // This matches the tag used when the array was created
  if Assigned(UnitGC.GC) then
    UnitGC.GC.Collect(ARRAY_GC_TAG + '_' + IntToStr(NativeInt(Args[0].p)));

  Result.n := 1;
end;

{------------------------------------------------------------------------------
  Library Registration
------------------------------------------------------------------------------}

procedure RegisterArrayFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
  i: Integer;
  nStr: String;
begin
  FnData.FarCall := True;

  //----------------------------------------------------------------------------
  // Array creation - register for 1-10 dimensions
  //----------------------------------------------------------------------------

  // Numeric array creation: dim#(n), dim#(n,n), ... dim#(n,n,n,n,n,n,n,n,n,n)
  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := p_ndim;
    Lib.Add('dim#@' + nStr, FnData);
  end;

  // String array creation: sdim#(n), sdim#(n,n), etc.
  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := p_sdim;
    Lib.Add('sdim#@' + nStr, FnData);
  end;

  // Pointer array creation: pdim#(n), pdim#(n,n), etc.
  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := p_pdim;
    Lib.Add('pdim#@' + nStr, FnData);
  end;

  //----------------------------------------------------------------------------
  // Numeric array access: narr_get@#n, narr_get@#nn, etc.
  //----------------------------------------------------------------------------

  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := n_narr_get;
    Lib.Add('narr_get@#' + nStr, FnData);
  end;

  // narr_set: #n + indices + n (value)
  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := n_narr_set;
    Lib.Add('narr_set#@#' + nStr + 'n', FnData);
  end;

  //----------------------------------------------------------------------------
  // String array access: sarr_get$@#n, sarr_get$@#nn, etc.
  //----------------------------------------------------------------------------

  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := s_sarr_get;
    Lib.Add('sarr_get$@#' + nStr, FnData);
  end;

  // sarr_set: #n + indices + $ (value)
  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := p_sarr_set;
    Lib.Add('sarr_set#@#' + nStr + '$', FnData);
  end;

  //----------------------------------------------------------------------------
  // Pointer array access: parr_get#@#n, parr_get#@#nn, etc.
  //----------------------------------------------------------------------------

  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := p_parr_get;
    Lib.Add('parr_get#@#' + nStr, FnData);
  end;

  // parr_set: #n + indices + # (value)
  for i := 1 to 10 do
  begin
    nStr := StringOfChar('n', i);
    FnData.Entry := p_parr_set;
    Lib.Add('parr_set#@#' + nStr + '#', FnData);
  end;

  //----------------------------------------------------------------------------
  // Utility functions
  //----------------------------------------------------------------------------

  FnData.Entry := n_ndims; Lib.Add('ndims@#', FnData);
  FnData.Entry := n_ubound; Lib.Add('ubound@#n', FnData);
  FnData.Entry := n_lbound; Lib.Add('lbound@#n', FnData);
  FnData.Entry := n_arraysize; Lib.Add('arraysize@#', FnData);
  FnData.Entry := n_arraytype; Lib.Add('arraytype@#', FnData);
  FnData.Entry := s_arraytypename; Lib.Add('arraytypename$@#', FnData);
  FnData.Entry := n_arr_free; Lib.Add('arr_free@#', FnData);
end;

end.

