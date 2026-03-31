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
unit ZipLib;

{******************************************************************************
  ZipLib - ZIP Archive Library for Plan9Basic

  Provides functions to create, read, and manipulate ZIP archives. ZIP format
  supports multiple files in a single archive with individual compression and
  is widely used for file distribution, backup, and data exchange.

  Features:
  - Create new ZIP archives
  - Open and read existing ZIP archives
  - Add files to archives
  - Add strings as files to archives
  - Extract files from archives
  - Extract all files from archives
  - List archive contents
  - Read file contents directly from archives

  Version: 1.0
  Date: January 2026
  
  Function Count: 14 functions

  Error Codes (via ziperror@):
    0 = No error
    1 = Archive not open/invalid handle
    2 = File not found in archive
    3 = File system error (read/write failure)
    4 = Invalid argument
    5 = Compression error
    6 = Archive already exists (when creating)
    7 = Entry already exists in archive

  Copyright (c) 2024-2026 Plan9Basic Project
******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Zip, System.IOUtils,
  System.Generics.Collections,
  exec;

procedure RegisterZipFuncs(Lib: TFunctionsDictionary);

implementation

var
  lastError: Integer;  // Error code for last operation (0 = success)
  
  // Handle management for open ZIP archives
  ZipHandles: TDictionary<NativeInt, TZipFile>;
  NextHandle: NativeInt;

const
  ERR_NONE = 0;
  ERR_INVALID_HANDLE = 1;
  ERR_FILE_NOT_FOUND = 2;
  ERR_FILE_ERROR = 3;
  ERR_INVALID_ARGUMENT = 4;
  ERR_COMPRESSION = 5;
  ERR_ARCHIVE_EXISTS = 6;
  ERR_ENTRY_EXISTS = 7;

{------------------------------------------------------------------------------
  Internal Helper Functions
------------------------------------------------------------------------------}

// Initialize handle management
procedure EnsureHandlesInitialized;
begin
  if ZipHandles = nil then
  begin
    ZipHandles := TDictionary<NativeInt, TZipFile>.Create;
    NextHandle := 1;
  end;
end;

// Get ZIP file from handle
function GetZipFile(Handle: NativeInt): TZipFile;
begin
  Result := nil;
  EnsureHandlesInitialized;
  if ZipHandles.ContainsKey(Handle) then
    Result := ZipHandles[Handle];
end;

// Register a new ZIP handle
function RegisterZipHandle(ZipFile: TZipFile): NativeInt;
begin
  EnsureHandlesInitialized;
  Result := NextHandle;
  ZipHandles.Add(Result, ZipFile);
  Inc(NextHandle);
end;

// Unregister a ZIP handle
procedure UnregisterZipHandle(Handle: NativeInt);
begin
  if ZipHandles <> nil then
  begin
    if ZipHandles.ContainsKey(Handle) then
      ZipHandles.Remove(Handle);
  end;
end;

{------------------------------------------------------------------------------
  Error Handling
------------------------------------------------------------------------------}

// ziperror@ - Get last error code
function n_ziperror(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := lastError;
  Result.s := '';
  Result.p := nil;
end;

{------------------------------------------------------------------------------
  Archive Creation and Opening
------------------------------------------------------------------------------}

// zipcreate#@$ - Create a new ZIP archive
// Input: Archive file path
// Output: Handle (pointer) to the archive, or 0 on failure
function p_zipcreate(var Args: Array of TAsmData): TAsmData;
var
  ArchivePath: String;
  ZipFile: TZipFile;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  
  ArchivePath := Args[0].s;
  
  if ArchivePath = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  try
    ZipFile := TZipFile.Create;
    try
      ZipFile.Open(ArchivePath, zmWrite);
      Result.p := Pointer(RegisterZipHandle(ZipFile));
    except
      ZipFile.Free;
      raise;
    end;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
      Result.p := nil;
    end;
  end;
end;

// zipopen#@$ - Open an existing ZIP archive for reading
// Input: Archive file path
// Output: Handle (pointer) to the archive, or 0 on failure
function p_zipopen(var Args: Array of TAsmData): TAsmData;
var
  ArchivePath: String;
  ZipFile: TZipFile;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.s := '';
  Result.p := nil;
  
  ArchivePath := Args[0].s;
  
  if ArchivePath = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  if not FileExists(ArchivePath) then
  begin
    lastError := ERR_FILE_ERROR;
    Exit;
  end;
  
  try
    ZipFile := TZipFile.Create;
    try
      ZipFile.Open(ArchivePath, zmRead);
      Result.p := Pointer(RegisterZipHandle(ZipFile));
    except
      ZipFile.Free;
      raise;
    end;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
      Result.p := nil;
    end;
  end;
end;

// zipclose@# - Close a ZIP archive
// Input: Archive handle
// Output: 1 on success, 0 on failure
function n_zipclose(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  try
    ZipFile.Close;
    ZipFile.Free;
    UnregisterZipHandle(Handle);
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Adding Files to Archives
------------------------------------------------------------------------------}

// zipadd@#$$ - Add a file to a ZIP archive
// Input: Archive handle, source file path, name in archive
// Output: 1 on success, 0 on failure
function n_zipadd(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  SourcePath, ArchiveName: String;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  SourcePath := Args[1].s;
  ArchiveName := Args[2].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  if (SourcePath = '') or (ArchiveName = '') then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  if not FileExists(SourcePath) then
  begin
    lastError := ERR_FILE_ERROR;
    Exit;
  end;
  
  try
    ZipFile.Add(SourcePath, ArchiveName);
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_COMPRESSION;
    end;
  end;
end;

// zipaddstr@#$$ - Add a string as a file to a ZIP archive
// Input: Archive handle, string content, name in archive
// Output: 1 on success, 0 on failure
function n_zipaddstr(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  Content, ArchiveName: String;
  ContentBytes: TBytes;
  ContentStream: TBytesStream;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  Content := Args[1].s;
  ArchiveName := Args[2].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  if ArchiveName = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  try
    ContentBytes := TEncoding.UTF8.GetBytes(Content);
    ContentStream := TBytesStream.Create(ContentBytes);
    try
      ZipFile.Add(ContentStream, ArchiveName);
    finally
      ContentStream.Free;
    end;
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_COMPRESSION;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Extracting Files from Archives
------------------------------------------------------------------------------}

// zipextract@#$$ - Extract a single file from a ZIP archive
// Input: Archive handle, name in archive, destination path
// Output: 1 on success, 0 on failure
function n_zipextract(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  ArchiveName, DestPath: String;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  ArchiveName := Args[1].s;
  DestPath := Args[2].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  if (ArchiveName = '') or (DestPath = '') then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  try
    // Extract to directory (DestPath should be directory)
    ZipFile.Extract(ArchiveName, DestPath);
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

// zipextractall@#$ - Extract all files from a ZIP archive
// Input: Archive handle, destination directory
// Output: 1 on success, 0 on failure
function n_zipextractall(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  DestPath: String;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  DestPath := Args[1].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  if DestPath = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  try
    ZipFile.ExtractAll(DestPath);
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Archive Information Functions
------------------------------------------------------------------------------}

// ziplist$@# - List all files in a ZIP archive (newline-separated)
// Input: Archive handle
// Output: Newline-separated list of file names
function s_ziplist(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  I: Integer;
  FileList: TStringList;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  
  Handle := NativeInt(Args[0].p);
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  try
    FileList := TStringList.Create;
    try
      for I := 0 to ZipFile.FileCount - 1 do
        FileList.Add(ZipFile.FileNames[I]);
      Result.s := FileList.Text;
      // Remove trailing newline
      if (Length(Result.s) > 0) and (Result.s[Length(Result.s)] = #10) then
        Result.s := Copy(Result.s, 1, Length(Result.s) - 1);
      if (Length(Result.s) > 0) and (Result.s[Length(Result.s)] = #13) then
        Result.s := Copy(Result.s, 1, Length(Result.s) - 1);
    finally
      FileList.Free;
    end;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

// zipcount@# - Get the number of files in a ZIP archive
// Input: Archive handle
// Output: Number of files in the archive
function n_zipcount(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  try
    Result.n := ZipFile.FileCount;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

// zipexists@#$ - Check if a file exists in a ZIP archive
// Input: Archive handle, file name in archive
// Output: 1 if exists, 0 if not
function n_zipexists(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  FileName: String;
  I: Integer;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  Handle := NativeInt(Args[0].p);
  FileName := Args[1].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  try
    for I := 0 to ZipFile.FileCount - 1 do
    begin
      if SameText(ZipFile.FileNames[I], FileName) then
      begin
        Result.n := 1;
        Exit;
      end;
    end;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

// zipread$@#$ - Read a file from ZIP archive as string
// Input: Archive handle, file name in archive
// Output: File contents as string
function s_zipread(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  FileName: String;
  LocalHeader: TZipHeader;
  ContentStream: TStream;
  ContentBytes: TBytes;
begin
  lastError := ERR_NONE;
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  
  Handle := NativeInt(Args[0].p);
  FileName := Args[1].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  if FileName = '' then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  try
    ZipFile.Read(FileName, ContentStream, LocalHeader);
    try
      SetLength(ContentBytes, ContentStream.Size);
      if ContentStream.Size > 0 then
      begin
        ContentStream.Position := 0;
        ContentStream.ReadBuffer(ContentBytes[0], ContentStream.Size);
      end;
      Result.s := TEncoding.UTF8.GetString(ContentBytes);
    finally
      ContentStream.Free;
    end;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_NOT_FOUND;
    end;
  end;
end;

// zipfilesize@#$ - Get the uncompressed size of a file in the archive
// Input: Archive handle, file name in archive
// Output: Uncompressed size in bytes, or -1 on error
function n_zipfilesize(var Args: Array of TAsmData): TAsmData;
var
  Handle: NativeInt;
  ZipFile: TZipFile;
  FileName: String;
  I: Integer;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := -1;
  
  Handle := NativeInt(Args[0].p);
  FileName := Args[1].s;
  
  ZipFile := GetZipFile(Handle);
  
  if ZipFile = nil then
  begin
    lastError := ERR_INVALID_HANDLE;
    Exit;
  end;
  
  try
    for I := 0 to ZipFile.FileCount - 1 do
    begin
      if SameText(ZipFile.FileNames[I], FileName) then
      begin
        Result.n := ZipFile.FileInfo[I].UncompressedSize;
        Exit;
      end;
    end;
    lastError := ERR_FILE_NOT_FOUND;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Convenience Functions (No Handle Required)
------------------------------------------------------------------------------}

// zipquick@$$ - Quick compress: create ZIP with a single file
// Input: Source file path, destination ZIP path
// Output: 1 on success, 0 on failure
function n_zipquick(var Args: Array of TAsmData): TAsmData;
var
  SourcePath, DestPath: String;
  ZipFile: TZipFile;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  SourcePath := Args[0].s;
  DestPath := Args[1].s;
  
  if (SourcePath = '') or (DestPath = '') then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  if not FileExists(SourcePath) then
  begin
    lastError := ERR_FILE_ERROR;
    Exit;
  end;
  
  try
    ZipFile := TZipFile.Create;
    try
      ZipFile.Open(DestPath, zmWrite);
      ZipFile.Add(SourcePath, ExtractFileName(SourcePath));
      ZipFile.Close;
    finally
      ZipFile.Free;
    end;
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

// unzipquick@$$ - Quick extract: extract all files from ZIP
// Input: ZIP file path, destination directory
// Output: 1 on success, 0 on failure
function n_unzipquick(var Args: Array of TAsmData): TAsmData;
var
  ZipPath, DestPath: String;
  ZipFile: TZipFile;
begin
  lastError := ERR_NONE;
  Result.s := '';
  Result.p := nil;
  Result.n := 0;
  
  ZipPath := Args[0].s;
  DestPath := Args[1].s;
  
  if (ZipPath = '') or (DestPath = '') then
  begin
    lastError := ERR_INVALID_ARGUMENT;
    Exit;
  end;
  
  if not FileExists(ZipPath) then
  begin
    lastError := ERR_FILE_ERROR;
    Exit;
  end;
  
  try
    ZipFile := TZipFile.Create;
    try
      ZipFile.Open(ZipPath, zmRead);
      ZipFile.ExtractAll(DestPath);
      ZipFile.Close;
    finally
      ZipFile.Free;
    end;
    Result.n := 1;
  except
    on E: Exception do
    begin
      lastError := ERR_FILE_ERROR;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Library Registration
------------------------------------------------------------------------------}

procedure RegisterZipFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;
  
  // Error handling
  FnData.Entry := @n_ziperror; Lib.Add('ziperror@', FnData);

  // Archive creation and opening
  FnData.Entry := @p_zipcreate; Lib.Add('zipcreate#@$', FnData);
  FnData.Entry := @p_zipopen; Lib.Add('zipopen#@$', FnData);
  FnData.Entry := @n_zipclose; Lib.Add('zipclose@#', FnData);

  // Adding files
  FnData.Entry := @n_zipadd; Lib.Add('zipadd@#$$', FnData);
  FnData.Entry := @n_zipaddstr; Lib.Add('zipaddstr@#$$', FnData);

  // Extracting files
  FnData.Entry := @n_zipextract; Lib.Add('zipextract@#$$', FnData);
  FnData.Entry := @n_zipextractall; Lib.Add('zipextractall@#$', FnData);

  // Archive information
  FnData.Entry := @s_ziplist; Lib.Add('ziplist$@#', FnData);
  FnData.Entry := @n_zipcount; Lib.Add('zipcount@#', FnData);
  FnData.Entry := @n_zipexists; Lib.Add('zipexists@#$', FnData);
  FnData.Entry := @s_zipread; Lib.Add('zipread$@#$', FnData);
  FnData.Entry := @n_zipfilesize; Lib.Add('zipfilesize@#$', FnData);

  // Convenience functions
  FnData.Entry := @n_zipquick; Lib.Add('zipquick@$$', FnData);
  FnData.Entry := @n_unzipquick; Lib.Add('unzipquick@$$', FnData);
end;

initialization
  ZipHandles := nil;
  NextHandle := 1;

finalization
  if ZipHandles <> nil then
  begin
    // Clean up any remaining open handles
    for var ZipFile in ZipHandles.Values do
    begin
      try
        ZipFile.Free;
      except
        // Ignore cleanup errors
      end;
    end;
    ZipHandles.Free;
  end;

end.

