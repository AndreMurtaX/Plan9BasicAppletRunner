unit Base64Lib;

{******************************************************************************
  Base64Lib - BASE64 Encoding/Decoding Library for Plan9Basic

  Provides functions to encode and decode data using BASE64 encoding,
  commonly used for transmitting binary data in text formats (JSON, XML, 
  email attachments, data URIs, etc.)

  Features:
  - Encode strings to BASE64
  - Decode BASE64 to strings
  - Encode binary files to BASE64 strings
  - Decode BASE64 strings to binary files
  - Validation of BASE64 strings
  - URL-safe BASE64 variant support

  Version: 1.0
  Date: January 2026
  
  Function Count: 8 functions

  Error Codes (via b64error@):
    0 = No error
    1 = Invalid BASE64 string
    2 = Invalid argument (empty input where not allowed)
    3 = File error (read/write failure)

  Copyright (c) 2024-2026 Plan9Basic Project
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.NetEncoding,
  exec;

procedure RegisterBase64Funcs(Lib: TFunctionsDictionary);

implementation

var
  lastError: Integer;  // Error code for last operation (0 = success)

const
  ERR_NONE = 0;
  ERR_INVALID_BASE64 = 1;
  ERR_INVALID_ARGUMENT = 2;
  ERR_FILE_ERROR = 3;

{------------------------------------------------------------------------------
  Error Handling
------------------------------------------------------------------------------}

// b64error@ - Get last error code
function n_b64error(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := lastError;
  Result.s := '';
  Result.p := nil;
end;

{------------------------------------------------------------------------------
  Core Encoding/Decoding Functions
------------------------------------------------------------------------------}

// b64encode$@$ - Encode a string to BASE64
// Input: String to encode (can be empty)
// Output: BASE64 encoded string
function s_b64encode(var Args: Array of TAsmData): TAsmData;
var
  InputBytes: TBytes;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  
  // Empty string encodes to empty string (valid case)
  if Args[0].s = '' then
  begin
    Result.s := '';
    Exit;
  end;
  
  try
    // Convert string to UTF-8 bytes, then encode
    InputBytes := TEncoding.UTF8.GetBytes(Args[0].s);
    Result.s := TNetEncoding.Base64.EncodeBytesToString(InputBytes);
  except
    on E: Exception do
    begin
      lastError := ERR_INVALID_ARGUMENT;
      Result.s := '';
    end;
  end;
end;

// b64decode$@$ - Decode a BASE64 string back to original string
// Input: BASE64 encoded string
// Output: Decoded string (UTF-8)
function s_b64decode(var Args: Array of TAsmData): TAsmData;
var
  DecodedBytes: TBytes;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  
  // Empty string decodes to empty string
  if Args[0].s = '' then
  begin
    Result.s := '';
    Exit;
  end;
  
  try
    DecodedBytes := TNetEncoding.Base64.DecodeStringToBytes(Args[0].s);
    Result.s := TEncoding.UTF8.GetString(DecodedBytes);
  except
    on E: Exception do
    begin
      lastError := ERR_INVALID_BASE64;
      Result.s := '';
    end;
  end;
end;

{------------------------------------------------------------------------------
  URL-Safe BASE64 Variant
  
  Standard BASE64 uses '+' and '/' which are special in URLs.
  URL-safe variant uses '-' and '_' instead.
------------------------------------------------------------------------------}

// b64urlencode$@$ - Encode string to URL-safe BASE64
function s_b64urlencode(var Args: Array of TAsmData): TAsmData;
var
  InputBytes: TBytes;
  Encoded: String;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  
  if Args[0].s = '' then
  begin
    Result.s := '';
    Exit;
  end;
  
  try
    InputBytes := TEncoding.UTF8.GetBytes(Args[0].s);
    Encoded := TNetEncoding.Base64.EncodeBytesToString(InputBytes);
    
    // Convert to URL-safe: + -> -, / -> _, remove padding =
    Encoded := StringReplace(Encoded, '+', '-', [rfReplaceAll]);
    Encoded := StringReplace(Encoded, '/', '_', [rfReplaceAll]);
    Encoded := StringReplace(Encoded, '=', '', [rfReplaceAll]);
    
    Result.s := Encoded;
  except
    on E: Exception do
    begin
      lastError := ERR_INVALID_ARGUMENT;
      Result.s := '';
    end;
  end;
end;

// b64urldecode$@$ - Decode URL-safe BASE64 string
function s_b64urldecode(var Args: Array of TAsmData): TAsmData;
var
  DecodedBytes: TBytes;
  Input: String;
  PadLen: Integer;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  
  if Args[0].s = '' then
  begin
    Result.s := '';
    Exit;
  end;
  
  try
    Input := Args[0].s;
    
    // Convert from URL-safe back to standard BASE64
    Input := StringReplace(Input, '-', '+', [rfReplaceAll]);
    Input := StringReplace(Input, '_', '/', [rfReplaceAll]);
    
    // Restore padding (BASE64 length must be multiple of 4)
    PadLen := (4 - (Length(Input) mod 4)) mod 4;
    Input := Input + StringOfChar('=', PadLen);
    
    DecodedBytes := TNetEncoding.Base64.DecodeStringToBytes(Input);
    Result.s := TEncoding.UTF8.GetString(DecodedBytes);
  except
    on E: Exception do
    begin
      lastError := ERR_INVALID_BASE64;
      Result.s := '';
    end;
  end;
end;

{------------------------------------------------------------------------------
  Validation Function
------------------------------------------------------------------------------}

// b64valid@$ - Check if a string is valid BASE64
// Returns: 1 if valid, 0 if invalid
function n_b64valid(var Args: Array of TAsmData): TAsmData;
var
  Input: String;
  I: Integer;
  C: Char;
  ValidChars: set of AnsiChar;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  
  Input := Args[0].s;
  
  // Empty string is technically valid BASE64 (encodes nothing)
  if Input = '' then
  begin
    Result.n := 1;
    Exit;
  end;
  
  // Valid BASE64 characters: A-Z, a-z, 0-9, +, /, =
  ValidChars := ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '='];
  
  // Check all characters
  for I := 1 to Length(Input) do
  begin
    C := Input[I];
    // Handle Unicode safely - check if in ASCII range first
    if (Ord(C) > 127) or not (AnsiChar(C) in ValidChars) then
    begin
      Result.n := 0;
      Exit;
    end;
  end;
  
  // Check length is multiple of 4 (after removing whitespace)
  Input := StringReplace(Input, ' ', '', [rfReplaceAll]);
  Input := StringReplace(Input, #13, '', [rfReplaceAll]);
  Input := StringReplace(Input, #10, '', [rfReplaceAll]);
  
  if (Length(Input) mod 4) <> 0 then
  begin
    Result.n := 0;
    Exit;
  end;
  
  // Check padding is valid (= only at end, max 2)
  if Pos('=', Input) > 0 then
  begin
    // = can only appear at positions len-1 and len
    for I := 1 to Length(Input) - 2 do
    begin
      if Input[I] = '=' then
      begin
        Result.n := 0;
        Exit;
      end;
    end;
  end;
  
  Result.n := 1;
end;

{------------------------------------------------------------------------------
  File Operations
------------------------------------------------------------------------------}

// b64encodefile$@$ - Encode a binary file to BASE64 string
// Input: File path
// Output: BASE64 encoded contents, or empty string on error
function s_b64encodefile(var Args: Array of TAsmData): TAsmData;
var
  FilePath: String;
  FileStream: TFileStream;
  FileBytes: TBytes;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  
  FilePath := Args[0].s;
  
  if FilePath = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  if not FileExists(FilePath) then
  begin
    lastError := ERR_FILE_ERROR;
    Exit;
  end;
  
  try
    FileStream := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(FileBytes, FileStream.Size);
      if FileStream.Size > 0 then
        FileStream.ReadBuffer(FileBytes[0], FileStream.Size);
      Result.s := TNetEncoding.Base64.EncodeBytesToString(FileBytes);
    finally
      FileStream.Free;
    end;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
      Result.s := '';
    end;
  end;
end;

// b64decodefile@$$ - Decode BASE64 string and save to binary file
// Input: BASE64 string, Output file path
// Output: 1 on success, 0 on failure
function n_b64decodefile(var Args: Array of TAsmData): TAsmData;
var
  Base64Str: String;
  FilePath: String;
  FileStream: TFileStream;
  DecodedBytes: TBytes;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Base64Str := Args[0].s;
  FilePath := Args[1].s;
  
  if FilePath = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  try
    // Decode BASE64 to bytes
    DecodedBytes := TNetEncoding.Base64.DecodeStringToBytes(Base64Str);
    
    // Write to file
    FileStream := TFileStream.Create(FilePath, fmCreate);
    try
      if Length(DecodedBytes) > 0 then
        FileStream.WriteBuffer(DecodedBytes[0], Length(DecodedBytes));
      Result.n := 1;
    finally
      FileStream.Free;
    end;
  except
    on E: EEncodingError do
    begin
      lastError := ERR_INVALID_BASE64;
      Result.n := 0;
    end;
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
      Result.n := 0;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Library Registration
------------------------------------------------------------------------------}

procedure RegisterBase64Funcs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;
  
  // Error handling
  FnData.Entry := @n_b64error; Lib.Add('b64error@', FnData);

  // Core encoding/decoding
  FnData.Entry := @s_b64encode; Lib.Add('b64encode$@$', FnData);
  FnData.Entry := @s_b64decode; Lib.Add('b64decode$@$', FnData);

  // URL-safe variant
  FnData.Entry := @s_b64urlencode; Lib.Add('b64urlencode$@$', FnData);
  FnData.Entry := @s_b64urldecode; Lib.Add('b64urldecode$@$', FnData);

  // Validation
  FnData.Entry := @n_b64valid; Lib.Add('b64valid@$', FnData);

  // File operations
  FnData.Entry := @s_b64encodefile; Lib.Add('b64encodefile$@$', FnData);
  FnData.Entry := @n_b64decodefile; Lib.Add('b64decodefile@$$', FnData);
end;

end.
