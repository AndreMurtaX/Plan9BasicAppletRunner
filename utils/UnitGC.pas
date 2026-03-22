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
unit UnitGC;

{******************************************************************************
  UnitGC - Garbage Collector for Plan9Basic
  Version: 2.0.0

  Manages lifecycle of NON-VISUAL objects only:
  - Arrays (TBasNumericArray, TBasStringArray, TBasPointerArray)
  - Dictionaries (TBasNumericDict, TBasStringDict, TBasPointerDict)
  - JSON objects (TJSONObject, TJSONArray, TJSONValue, etc.)
  - String lists (TBasStringList)
  - Config files (TBasConfig)
  - SQLite connections (TBasSqliteConn)
  - HTTP clients (TBasHttpClient)
  - Regex results (TStringList)

  IMPORTANT: Visual FMX objects (Forms, Timers, Controls) must NOT be
  registered in this GC. They have their own lifecycle managers:
  - Forms -> FormLib.ActiveForms + CleanupAllForms()
  - Timers -> TimerLib.ActiveTimers + CleanupAllTimers()
  - Controls -> FMX parent-child ownership (auto-freed when parent dies)

  CHANGE LOG v2.0.0:
  - Changed from TComponent to TObject (no more ownership chain conflicts)
  - Plain TDictionary (no doOwnsKeys) with explicit freeing
  - Objects freed outside the lock to prevent deadlocks
  - Simplified Release() method
******************************************************************************}

interface

uses
  System.Generics.Collections, System.Rtti, System.SyncObjs;

type
  TGarbageCollector = class(TObject)
  public
    const DEFAULT_TAG = 'DEFAULT_GC_TAG';
  private
    FItems: TDictionary<TObject, String>;
    FLock: TCriticalSection;
    FEnabled: Boolean;
  public
    constructor Create();
    destructor Destroy(); override;

    // Add an object to the GC with optional tag
    function Add<T>(item: T): T; overload;
    function Add<T>(item: T; const tag: String): T; overload;

    procedure Collect(const tag: String); // Collect (free) objects by tag
    procedure CollectAll(); // Collect ALL objects

    // Check if an object exists in the GC
    function Contains(obj: TObject): Boolean; overload;
    function ContainsTag(const tag: String): Boolean; overload;

    function GetTag(obj: TObject): String; // Get tag for an object
    function Release(obj: TObject): Boolean; // Remove object from GC WITHOUT freeing it
    function Count(): Integer; // Get count of managed objects
    function CountByTag(const tag: String): Integer; // Get count of objects with specific tag

    property Enabled: Boolean read FEnabled write FEnabled;
  end;

var
  GC: TGarbageCollector;
  GlobalCallbackBusy: Boolean = False;
  SkipProcessMessages: Boolean = False;

implementation

uses
  System.SysUtils;

constructor TGarbageCollector.Create();
begin
  inherited Create();
  // Plain TDictionary — we free objects explicitly in Collect/CollectAll.
  // NOT TObjectDictionary with doOwnsKeys, which caused double-free crashes
  // when FMX components were involved.
  FItems := TDictionary<TObject, String>.Create();
  FLock := TCriticalSection.Create();
  FEnabled := True;
end;

destructor TGarbageCollector.Destroy();
begin
  try
    CollectAll();
  except
    // Ignore exceptions during shutdown
  end;

  FreeAndNil(FLock);
  FreeAndNil(FItems);

  inherited Destroy();
end;

function TGarbageCollector.Add<T>(item: T): T;
begin
  Result := Add<T>(item, DEFAULT_TAG);
end;

function TGarbageCollector.Add<T>(item: T; const tag: String): T;
var
  v: TValue;
begin
  Result := item;

  if not FEnabled then
    Exit;

  v := TValue.From<T>(item);
  if not v.IsObject then
    raise Exception.Create('TGarbageCollector.Add: not an Object');

  if v.AsObject = nil then
    raise Exception.Create('TGarbageCollector.Add: cannot add nil object');

  FLock.Enter();
  try
    if not FItems.ContainsKey(v.AsObject) then
      FItems.Add(v.AsObject, tag);
  finally
    FLock.Leave();
  end;
end;

procedure TGarbageCollector.Collect(const tag: String);
var
  item: TPair<TObject, String>;
  gcList: TList<TObject>;
  key: TObject;
begin
  gcList := TList<TObject>.Create();
  try
    // Under lock: identify and remove from dictionary
    FLock.Enter();
    try
      for item in FItems do
      begin
        if item.Value = tag then
          gcList.Add(item.Key);
      end;
      for key in gcList do
        FItems.Remove(key);
    finally
      FLock.Leave();
    end;

    // Outside lock: free the objects explicitly.
    // Done outside the lock to prevent deadlocks if a destructor
    // triggers code that re-enters the GC.
    for key in gcList do
    begin
      try
        key.Free();
      except
        // Ignore errors (object may already be freed)
      end;
    end;
  finally
    gcList.Free();
  end;
end;

procedure TGarbageCollector.CollectAll();
var
  objs: TList<TObject>;
  item: TPair<TObject, String>;
  obj: TObject;
begin
  objs := TList<TObject>.Create();
  try
    // Under lock: snapshot all objects and clear dictionary
    FLock.Enter();
    try
      for item in FItems do
        objs.Add(item.Key);
      FItems.Clear();
    finally
      FLock.Leave();
    end;

    // Outside lock: free all objects
    for obj in objs do
    begin
      try
        obj.Free();
      except
        // Ignore errors during cleanup
      end;
    end;
  finally
    objs.Free();
  end;
end;

function TGarbageCollector.Contains(obj: TObject): Boolean;
begin
  if obj = nil then
    Exit(False);

  FLock.Enter();
  try
    Result := FItems.ContainsKey(obj);
  finally
    FLock.Leave();
  end;
end;

function TGarbageCollector.ContainsTag(const tag: String): Boolean;
var
  item: TPair<TObject, String>;
begin
  Result := False;

  FLock.Enter();
  try
    for item in FItems do
    begin
      if item.Value = tag then
      begin
        Result := True;
        Break;
      end;
    end;
  finally
    FLock.Leave();
  end;
end;

function TGarbageCollector.GetTag(obj: TObject): String;
begin
  Result := '';

  if obj = nil then
    Exit;

  FLock.Enter();
  try
    if FItems.ContainsKey(obj) then
      Result := FItems[obj];
  finally
    FLock.Leave();
  end;
end;

function TGarbageCollector.Release(obj: TObject): Boolean;
begin
  Result := False;

  if obj = nil then
    Exit;

  FLock.Enter();
  try
    Result := FItems.ContainsKey(obj);
    if Result then
      FItems.Remove(obj);
  finally
    FLock.Leave();
  end;
end;

function TGarbageCollector.Count(): Integer;
begin
  FLock.Enter();
  try
    Result := FItems.Count;
  finally
    FLock.Leave();
  end;
end;

function TGarbageCollector.CountByTag(const tag: String): Integer;
var
  item: TPair<TObject, String>;
begin
  Result := 0;

  FLock.Enter();
  try
    for item in FItems do
    begin
      if item.Value = tag then
        Inc(Result);
    end;
  finally
    FLock.Leave();
  end;
end;

end.

