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
unit ConfigLib;

{******************************************************************************
  ConfigLib - Cross-Platform Configuration Library for Plan9Basic

  Features:
  - Persistent key/value storage using INI files
  - Works on Windows, Linux, macOS, Android, iOS
  - Support for sections (like INI file sections)
  - Numeric, String, and Boolean value types
  - Auto-save option or manual save control
  - Platform-appropriate storage locations
  - Multiple config file support

  Version: 1.0
  Date: January 2026
******************************************************************************}

interface

uses
  System.SysUtils, System.IniFiles, System.IOUtils, System.Classes,
  exec, UnitGC;

type
  // Configuration file wrapper class
  TBasConfig = class
  private
    FIniFile: TMemIniFile;
    FFilePath: String;
    FAutoSave: Boolean;
    FModified: Boolean;
  public
    constructor Create(const FilePath: String; AutoSave: Boolean = False);
    destructor Destroy(); override;

    // String operations
    procedure SetString(const Section, Key, Value: String);
    function GetString(const Section, Key, Default: String): String;

    // Numeric operations
    procedure SetNumber(const Section, Key: String; Value: Extended);
    function GetNumber(const Section, Key: String; Default: Extended): Extended;

    // Boolean operations (stored as 0/1)
    procedure SetBool(const Section, Key: String; Value: Boolean);
    function GetBool(const Section, Key: String; Default: Boolean): Boolean;

    // Key/Section management
    function KeyExists(const Section, Key: String): Boolean;
    function SectionExists(const Section: String): Boolean;
    procedure DeleteKey(const Section, Key: String);
    procedure DeleteSection(const Section: String);
    procedure Clear();

    // Section/Key enumeration
    function GetSections(): TStringList;
    function GetKeys(const Section: String): TStringList;

    // File operations
    procedure Save();
    procedure Reload();

    property FilePath: String read FFilePath;
    property AutoSave: Boolean read FAutoSave write FAutoSave;
    property Modified: Boolean read FModified;
  end;

// Library registration
procedure RegisterConfigFuncs(Lib: TFunctionsDictionary);

// Utility: Get platform-appropriate config directory
function GetConfigDirectory: String;

implementation

const
  CONFIG_GC_TAG = 'BASIC_CONFIG';
  DEFAULT_SECTION = 'General';

{------------------------------------------------------------------------------
  Utility Functions
------------------------------------------------------------------------------}

function GetConfigDirectory: String;
var
  BaseDir: String;
begin
  {$IFDEF MSWINDOWS}
  // Windows: Documents/Plan9Basic/Config/
  BaseDir := TPath.Combine(TPath.GetDocumentsPath, 'Plan9Basic');
  Result := TPath.Combine(BaseDir, 'Config');
  {$ENDIF}

  {$IFDEF LINUX}
  // Linux: ~/.config/Plan9Basic/
  BaseDir := TPath.GetHomePath;
  Result := TPath.Combine(BaseDir, '.config');
  Result := TPath.Combine(Result, 'Plan9Basic');
  {$ENDIF}

  {$IFDEF MACOS}
  // macOS: ~/Library/Application Support/Plan9Basic/
  BaseDir := TPath.GetHomePath;
  Result := TPath.Combine(BaseDir, 'Library');
  Result := TPath.Combine(Result, 'Application Support');
  Result := TPath.Combine(Result, 'Plan9Basic');
  {$ENDIF}

  {$IFDEF ANDROID}
  // Android: App's documents directory
  Result := TPath.Combine(TPath.GetDocumentsPath, 'Config');
  {$ENDIF}

  {$IFDEF IOS}
  // iOS: App's documents directory
  Result := TPath.Combine(TPath.GetDocumentsPath, 'Config');
  {$ENDIF}

  // Create directory if it doesn't exist
  if not TDirectory.Exists(Result) then
  begin
    try
      TDirectory.CreateDirectory(Result);
    except
      // If creation fails, fall back to documents path
      Result := TPath.GetDocumentsPath;
    end;
  end;
end;

function EnsureConfigPath(const FileName: String): String;
var
  ConfigDir: String;
begin
  // If filename has path separators, use as-is
  if (Pos(TPath.DirectorySeparatorChar, FileName) > 0) or (Pos('/', FileName) > 0) or (Pos('\', FileName) > 0) then
  begin
    Result := FileName;
  end
  else
  begin
    // Otherwise, put in config directory
    ConfigDir := GetConfigDirectory;
    Result := TPath.Combine(ConfigDir, FileName);
  end;

  // Add .ini extension if no extension present
  if TPath.GetExtension(Result) = '' then
    Result := Result + '.ini';
end;

procedure ValidateConfig(p: Pointer; const funcName: String);
begin
  if p = nil then
    raise Exception.CreateFmt('%s: Null config pointer', [funcName]);

  if not (TObject(p) is TBasConfig) then
    raise Exception.CreateFmt('%s: Invalid config object', [funcName]);
end;

{------------------------------------------------------------------------------
  TBasConfig Implementation
------------------------------------------------------------------------------}

constructor TBasConfig.Create(const FilePath: String; AutoSave: Boolean);
begin
  inherited Create();
  FFilePath := EnsureConfigPath(FilePath);
  FAutoSave := AutoSave;
  FModified := False;

  // TMemIniFile works in memory, only writes on UpdateFile
  FIniFile := TMemIniFile.Create(FFilePath, TEncoding.UTF8);
end;

destructor TBasConfig.Destroy();
begin
  // Auto-save on destroy if modified
  if FModified and Assigned(FIniFile) then
  begin
    try
      FIniFile.UpdateFile;
    except
      // Ignore save errors on destroy
    end;
  end;

  if Assigned(FIniFile) then
    FreeAndNil(FIniFile);

  inherited Destroy();
end;

procedure TBasConfig.SetString(const Section, Key, Value: String);
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  FIniFile.WriteString(ActualSection, Key, Value);
  FModified := True;

  if FAutoSave then
    Save();
end;

function TBasConfig.GetString(const Section, Key, Default: String): String;
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  Result := FIniFile.ReadString(ActualSection, Key, Default);
end;

procedure TBasConfig.SetNumber(const Section, Key: String; Value: Extended);
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  FIniFile.WriteFloat(ActualSection, Key, Value);
  FModified := True;

  if FAutoSave then
    Save();
end;

function TBasConfig.GetNumber(const Section, Key: String; Default: Extended): Extended;
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  Result := FIniFile.ReadFloat(ActualSection, Key, Default);
end;

procedure TBasConfig.SetBool(const Section, Key: String; Value: Boolean);
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  FIniFile.WriteBool(ActualSection, Key, Value);
  FModified := True;

  if FAutoSave then
    Save();
end;

function TBasConfig.GetBool(const Section, Key: String; Default: Boolean): Boolean;
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  Result := FIniFile.ReadBool(ActualSection, Key, Default);
end;

function TBasConfig.KeyExists(const Section, Key: String): Boolean;
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  Result := FIniFile.ValueExists(ActualSection, Key);
end;

function TBasConfig.SectionExists(const Section: String): Boolean;
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  Result := FIniFile.SectionExists(ActualSection);
end;

procedure TBasConfig.DeleteKey(const Section, Key: String);
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  FIniFile.DeleteKey(ActualSection, Key);
  FModified := True;

  if FAutoSave then
    Save();
end;

procedure TBasConfig.DeleteSection(const Section: String);
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  FIniFile.EraseSection(ActualSection);
  FModified := True;

  if FAutoSave then
    Save();
end;

procedure TBasConfig.Clear();
begin
  FIniFile.Clear();
  FModified := True;

  if FAutoSave then
    Save();
end;

function TBasConfig.GetSections: TStringList;
begin
  Result := TStringList.Create();
  FIniFile.ReadSections(Result);
end;

function TBasConfig.GetKeys(const Section: String): TStringList;
var
  ActualSection: String;
begin
  if Section = '' then
    ActualSection := DEFAULT_SECTION
  else
    ActualSection := Section;

  Result := TStringList.Create();
  FIniFile.ReadSection(ActualSection, Result);
end;

procedure TBasConfig.Save();
begin
  FIniFile.UpdateFile;
  FModified := False;
end;

procedure TBasConfig.Reload();
begin
  // Re-read from disk
  FIniFile.Rename(FFilePath, True);
  FModified := False;
end;

{------------------------------------------------------------------------------
  Config Creation Functions
------------------------------------------------------------------------------}

// cfg_open#(filename$) - Open or create a config file
function p_cfg_open(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
  filename: String;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_open# requires filename');

  filename := Args[0].s;
  if filename = '' then
    raise Exception.Create('cfg_open#: Filename cannot be empty');

  cfg := TBasConfig.Create(filename, False);

  if Assigned(UnitGC.GC) then
    UnitGC.GC.Add<TBasConfig>(cfg, CONFIG_GC_TAG);

  Result.p := cfg;
end;

// cfg_open_auto#(filename$) - Open with auto-save enabled
function p_cfg_open_auto(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
  filename: String;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_open_auto# requires filename');

  filename := Args[0].s;
  if filename = '' then
    raise Exception.Create('cfg_open_auto#: Filename cannot be empty');

  cfg := TBasConfig.Create(filename, True);  // Auto-save enabled

  if Assigned(UnitGC.GC) then
    UnitGC.GC.Add<TBasConfig>(cfg, CONFIG_GC_TAG);

  Result.p := cfg;
end;

{------------------------------------------------------------------------------
  String Value Functions
------------------------------------------------------------------------------}

// cfg_set#(cfg#, section$, key$, value$) - Set string value
function p_cfg_set(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 4 then
    raise Exception.Create('cfg_set# requires config, section, key, and value');

  ValidateConfig(Args[0].p, 'cfg_set#');
  cfg := TBasConfig(Args[0].p);
  cfg.SetString(Args[1].s, Args[2].s, Args[3].s);

  Result.p := Args[0].p;  // Return config for chaining
end;

// cfg_get$(cfg#, section$, key$, default$) - Get string value
function s_cfg_get(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 4 then
    raise Exception.Create('cfg_get$ requires config, section, key, and default');

  ValidateConfig(Args[0].p, 'cfg_get$');
  cfg := TBasConfig(Args[0].p);
  Result.s := cfg.GetString(Args[1].s, Args[2].s, Args[3].s);
end;

// cfg_sets#(cfg#, key$, value$) - Set string in default section
function p_cfg_sets(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_sets# requires config, key, and value');

  ValidateConfig(Args[0].p, 'cfg_sets#');
  cfg := TBasConfig(Args[0].p);
  cfg.SetString('', Args[1].s, Args[2].s);

  Result.p := Args[0].p;
end;

// cfg_gets$(cfg#, key$, default$) - Get string from default section
function s_cfg_gets(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_gets$ requires config, key, and default');

  ValidateConfig(Args[0].p, 'cfg_gets$');
  cfg := TBasConfig(Args[0].p);
  Result.s := cfg.GetString('', Args[1].s, Args[2].s);
end;

{------------------------------------------------------------------------------
  Numeric Value Functions
------------------------------------------------------------------------------}

// cfg_setn#(cfg#, section$, key$, value) - Set numeric value
function p_cfg_setn(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 4 then
    raise Exception.Create('cfg_setn# requires config, section, key, and value');

  ValidateConfig(Args[0].p, 'cfg_setn#');
  cfg := TBasConfig(Args[0].p);
  cfg.SetNumber(Args[1].s, Args[2].s, Args[3].n);

  Result.p := Args[0].p;
end;

// cfg_getn(cfg#, section$, key$, default) - Get numeric value
function n_cfg_getn(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 4 then
    raise Exception.Create('cfg_getn requires config, section, key, and default');

  ValidateConfig(Args[0].p, 'cfg_getn');
  cfg := TBasConfig(Args[0].p);
  Result.n := cfg.GetNumber(Args[1].s, Args[2].s, Args[3].n);
end;

// cfg_setns#(cfg#, key$, value) - Set numeric in default section
function p_cfg_setns(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_setns# requires config, key, and value');

  ValidateConfig(Args[0].p, 'cfg_setns#');
  cfg := TBasConfig(Args[0].p);
  cfg.SetNumber('', Args[1].s, Args[2].n);

  Result.p := Args[0].p;
end;

// cfg_getns(cfg#, key$, default) - Get numeric from default section
function n_cfg_getns(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_getns requires config, key, and default');

  ValidateConfig(Args[0].p, 'cfg_getns');
  cfg := TBasConfig(Args[0].p);
  Result.n := cfg.GetNumber('', Args[1].s, Args[2].n);
end;

{------------------------------------------------------------------------------
  Boolean Value Functions
------------------------------------------------------------------------------}

// cfg_setb#(cfg#, section$, key$, value) - Set boolean value
function p_cfg_setb(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 4 then
    raise Exception.Create('cfg_setb# requires config, section, key, and value');

  ValidateConfig(Args[0].p, 'cfg_setb#');
  cfg := TBasConfig(Args[0].p);
  cfg.SetBool(Args[1].s, Args[2].s, Args[3].n <> 0);

  Result.p := Args[0].p;
end;

// cfg_getb(cfg#, section$, key$, default) - Get boolean value
function n_cfg_getb(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 4 then
    raise Exception.Create('cfg_getb requires config, section, key, and default');

  ValidateConfig(Args[0].p, 'cfg_getb');
  cfg := TBasConfig(Args[0].p);

  if cfg.GetBool(Args[1].s, Args[2].s, Args[3].n <> 0) then
    Result.n := 1
  else
    Result.n := 0;
end;

// cfg_setbs#(cfg#, key$, value) - Set boolean in default section
function p_cfg_setbs(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_setbs# requires config, key, and value');

  ValidateConfig(Args[0].p, 'cfg_setbs#');
  cfg := TBasConfig(Args[0].p);
  cfg.SetBool('', Args[1].s, Args[2].n <> 0);

  Result.p := Args[0].p;
end;

// cfg_getbs(cfg#, key$, default) - Get boolean from default section
function n_cfg_getbs(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_getbs requires config, key, and default');

  ValidateConfig(Args[0].p, 'cfg_getbs');
  cfg := TBasConfig(Args[0].p);

  if cfg.GetBool('', Args[1].s, Args[2].n <> 0) then
    Result.n := 1
  else
    Result.n := 0;
end;

{------------------------------------------------------------------------------
  Key/Section Query Functions
------------------------------------------------------------------------------}

// cfg_exists(cfg#, section$, key$) - Check if key exists
function n_cfg_exists(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_exists requires config, section, and key');

  ValidateConfig(Args[0].p, 'cfg_exists');
  cfg := TBasConfig(Args[0].p);

  if cfg.KeyExists(Args[1].s, Args[2].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

// cfg_haskey(cfg#, key$) - Check if key exists in default section
function n_cfg_haskey(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_haskey requires config and key');

  ValidateConfig(Args[0].p, 'cfg_haskey');
  cfg := TBasConfig(Args[0].p);

  if cfg.KeyExists('', Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

// cfg_section_exists(cfg#, section$) - Check if section exists
function n_cfg_section_exists(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_section_exists requires config and section');

  ValidateConfig(Args[0].p, 'cfg_section_exists');
  cfg := TBasConfig(Args[0].p);

  if cfg.SectionExists(Args[1].s) then
    Result.n := 1
  else
    Result.n := 0;
end;

{------------------------------------------------------------------------------
  Key/Section Management Functions
------------------------------------------------------------------------------}

// cfg_delete#(cfg#, section$, key$) - Delete a key
function p_cfg_delete(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 3 then
    raise Exception.Create('cfg_delete# requires config, section, and key');

  ValidateConfig(Args[0].p, 'cfg_delete#');
  cfg := TBasConfig(Args[0].p);
  cfg.DeleteKey(Args[1].s, Args[2].s);

  Result.p := Args[0].p;
end;

// cfg_deletekey#(cfg#, key$) - Delete key from default section
function p_cfg_deletekey(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_deletekey# requires config and key');

  ValidateConfig(Args[0].p, 'cfg_deletekey#');
  cfg := TBasConfig(Args[0].p);
  cfg.DeleteKey('', Args[1].s);

  Result.p := Args[0].p;
end;

// cfg_section_delete#(cfg#, section$) - Delete entire section
function p_cfg_section_delete(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_section_delete# requires config and section');

  ValidateConfig(Args[0].p, 'cfg_section_delete#');
  cfg := TBasConfig(Args[0].p);
  cfg.DeleteSection(Args[1].s);

  Result.p := Args[0].p;
end;

// cfg_clear#(cfg#) - Clear all data
function p_cfg_clear(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_clear# requires config');

  ValidateConfig(Args[0].p, 'cfg_clear#');
  cfg := TBasConfig(Args[0].p);
  cfg.Clear();

  Result.p := Args[0].p;
end;

{------------------------------------------------------------------------------
  Enumeration Functions
------------------------------------------------------------------------------}

// cfg_sections$(cfg#) - Get all sections (newline separated)
function s_cfg_sections(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
  sections: TStringList;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_sections$ requires config');

  ValidateConfig(Args[0].p, 'cfg_sections$');
  cfg := TBasConfig(Args[0].p);

  sections := cfg.GetSections();
  try
    Result.s := sections.Text;
    // Remove trailing newline
    Result.s := Result.s.TrimRight;
  finally
    sections.Free;
  end;
end;

// cfg_keys$(cfg#, section$) - Get all keys in section (newline separated)
function s_cfg_keys(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
  keys: TStringList;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_keys$ requires config and section');

  ValidateConfig(Args[0].p, 'cfg_keys$');
  cfg := TBasConfig(Args[0].p);

  keys := cfg.GetKeys(Args[1].s);
  try
    Result.s := keys.Text;
    // Remove trailing newline
    Result.s := Result.s.TrimRight;
  finally
    keys.Free;
  end;
end;

// cfg_keycount(cfg#, section$) - Count keys in section
function n_cfg_keycount(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
  keys: TStringList;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_keycount requires config and section');

  ValidateConfig(Args[0].p, 'cfg_keycount');
  cfg := TBasConfig(Args[0].p);

  keys := cfg.GetKeys(Args[1].s);
  try
    Result.n := keys.Count;
  finally
    keys.Free;
  end;
end;

// cfg_sectioncount(cfg#) - Count sections
function n_cfg_sectioncount(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
  sections: TStringList;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_sectioncount requires config');

  ValidateConfig(Args[0].p, 'cfg_sectioncount');
  cfg := TBasConfig(Args[0].p);

  sections := cfg.GetSections();
  try
    Result.n := sections.Count;
  finally
    sections.Free;
  end;
end;

{------------------------------------------------------------------------------
  File Operation Functions
------------------------------------------------------------------------------}

// cfg_save(cfg#) - Save to disk
function n_cfg_save(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 1;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_save requires config');

  ValidateConfig(Args[0].p, 'cfg_save');
  cfg := TBasConfig(Args[0].p);

  try
    cfg.Save();
    Result.n := 1;  // Success
  except
    Result.n := 0;  // Failure
  end;
end;

// cfg_reload#(cfg#) - Reload from disk
function p_cfg_reload(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_reload# requires config');

  ValidateConfig(Args[0].p, 'cfg_reload#');
  cfg := TBasConfig(Args[0].p);
  cfg.Reload();

  Result.p := Args[0].p;
end;

// cfg_filename$(cfg#) - Get the full file path
function s_cfg_filename(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_filename$ requires config');

  ValidateConfig(Args[0].p, 'cfg_filename$');
  cfg := TBasConfig(Args[0].p);
  Result.s := cfg.FilePath;
end;

// cfg_modified(cfg#) - Check if config has unsaved changes
function n_cfg_modified(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 1 then
    raise Exception.Create('cfg_modified requires config');

  ValidateConfig(Args[0].p, 'cfg_modified');
  cfg := TBasConfig(Args[0].p);

  if cfg.Modified then
    Result.n := 1
  else
    Result.n := 0;
end;

// cfg_autosave#(cfg#, enabled) - Set auto-save mode
function p_cfg_autosave(var Args: array of TAsmData): TAsmData;
var
  cfg: TBasConfig;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if Length(Args) < 2 then
    raise Exception.Create('cfg_autosave# requires config and enabled flag');

  ValidateConfig(Args[0].p, 'cfg_autosave#');
  cfg := TBasConfig(Args[0].p);
  cfg.AutoSave := Args[1].n <> 0;

  Result.p := Args[0].p;
end;

{------------------------------------------------------------------------------
  Utility Functions
------------------------------------------------------------------------------}

// cfg_path$() - Get the config directory path
function s_cfg_path(var Args: array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := GetConfigDirectory;
end;

{------------------------------------------------------------------------------
  Library Registration
------------------------------------------------------------------------------}

procedure RegisterConfigFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;

  //----------------------------------------------------------------------------
  // Config file creation
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_open; Lib.Add('cfg_open#@$', FnData);           // cfg_open#(filename$)
  FnData.Entry := p_cfg_open_auto; Lib.Add('cfg_open_auto#@$', FnData);      // cfg_open_auto#(filename$)

  //----------------------------------------------------------------------------
  // String operations (with section)
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_set; Lib.Add('cfg_set#@#$$$', FnData);         // cfg_set#(cfg#, section$, key$, value$)
  FnData.Entry := s_cfg_get; Lib.Add('cfg_get$@#$$$', FnData);         // cfg_get$(cfg#, section$, key$, default$)

  //----------------------------------------------------------------------------
  // String operations (default section)
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_sets; Lib.Add('cfg_sets#@#$$', FnData);         // cfg_sets#(cfg#, key$, value$)
  FnData.Entry := s_cfg_gets; Lib.Add('cfg_gets$@#$$', FnData);         // cfg_gets$(cfg#, key$, default$)

  //----------------------------------------------------------------------------
  // Numeric operations (with section)
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_setn; Lib.Add('cfg_setn#@#$$n', FnData);        // cfg_setn#(cfg#, section$, key$, value)
  FnData.Entry := n_cfg_getn; Lib.Add('cfg_getn@#$$n', FnData);         // cfg_getn(cfg#, section$, key$, default)

  //----------------------------------------------------------------------------
  // Numeric operations (default section)
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_setns; Lib.Add('cfg_setns#@#$n', FnData);        // cfg_setns#(cfg#, key$, value)
  FnData.Entry := n_cfg_getns; Lib.Add('cfg_getns@#$n', FnData);         // cfg_getns(cfg#, key$, default)

  //----------------------------------------------------------------------------
  // Boolean operations (with section)
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_setb; Lib.Add('cfg_setb#@#$$n', FnData);        // cfg_setb#(cfg#, section$, key$, value)
  FnData.Entry := n_cfg_getb; Lib.Add('cfg_getb@#$$n', FnData);         // cfg_getb(cfg#, section$, key$, default)

  //----------------------------------------------------------------------------
  // Boolean operations (default section)
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_setbs; Lib.Add('cfg_setbs#@#$n', FnData);        // cfg_setbs#(cfg#, key$, value)
  FnData.Entry := n_cfg_getbs; Lib.Add('cfg_getbs@#$n', FnData);         // cfg_getbs(cfg#, key$, default)

  //----------------------------------------------------------------------------
  // Key/Section query
  //----------------------------------------------------------------------------
  FnData.Entry := n_cfg_exists; Lib.Add('cfg_exists@#$$', FnData);        // cfg_exists(cfg#, section$, key$)
  FnData.Entry := n_cfg_haskey; Lib.Add('cfg_haskey@#$', FnData);         // cfg_haskey(cfg#, key$)
  FnData.Entry := n_cfg_section_exists; Lib.Add('cfg_section_exists@#$', FnData); // cfg_section_exists(cfg#, section$)

  //----------------------------------------------------------------------------
  // Key/Section management
  //----------------------------------------------------------------------------
  FnData.Entry := p_cfg_delete; Lib.Add('cfg_delete#@#$$', FnData);       // cfg_delete#(cfg#, section$, key$)
  FnData.Entry := p_cfg_deletekey; Lib.Add('cfg_deletekey#@#$', FnData);     // cfg_deletekey#(cfg#, key$)
  FnData.Entry := p_cfg_section_delete; Lib.Add('cfg_section_delete#@#$', FnData);// cfg_section_delete#(cfg#, section$)
  FnData.Entry := p_cfg_clear; Lib.Add('cfg_clear#@#', FnData);          // cfg_clear#(cfg#)

  //----------------------------------------------------------------------------
  // Enumeration
  //----------------------------------------------------------------------------
  FnData.Entry := s_cfg_sections; Lib.Add('cfg_sections$@#', FnData);       // cfg_sections$(cfg#)
  FnData.Entry := s_cfg_keys; Lib.Add('cfg_keys$@#$', FnData);          // cfg_keys$(cfg#, section$)
  FnData.Entry := n_cfg_keycount; Lib.Add('cfg_keycount@#$', FnData);       // cfg_keycount(cfg#, section$)
  FnData.Entry := n_cfg_sectioncount; Lib.Add('cfg_sectioncount@#', FnData);    // cfg_sectioncount(cfg#)

  //----------------------------------------------------------------------------
  // File operations
  //----------------------------------------------------------------------------
  FnData.Entry := n_cfg_save; Lib.Add('cfg_save@#', FnData);            // cfg_save(cfg#)
  FnData.Entry := p_cfg_reload; Lib.Add('cfg_reload#@#', FnData);         // cfg_reload#(cfg#)
  FnData.Entry := s_cfg_filename; Lib.Add('cfg_filename$@#', FnData);       // cfg_filename$(cfg#)
  FnData.Entry := n_cfg_modified; Lib.Add('cfg_modified@#', FnData);        // cfg_modified(cfg#)
  FnData.Entry := p_cfg_autosave; Lib.Add('cfg_autosave#@#n', FnData);      // cfg_autosave#(cfg#, enabled)

  //----------------------------------------------------------------------------
  // Utility
  //----------------------------------------------------------------------------
  FnData.Entry := s_cfg_path; Lib.Add('cfg_path$@', FnData);            // cfg_path$()
end;

end.

