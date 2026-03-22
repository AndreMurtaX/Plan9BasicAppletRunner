unit TimerLib;

{******************************************************************************
  TimerLib - Timer Control Library for Plan9Basic
  Version: 1.2.0

  Provides timer functionality for creating timed events and periodic callbacks
  in Plan9Basic programs. Timers are non-visual components that fire events
  at specified intervals.

  Function Count: 15 functions

  FEATURES:
  =========
  - Timer creation and lifecycle management
  - Configurable interval (in milliseconds)
  - Enable/disable control
  - OnTimer event callback
  - Tag property for user data

  EVENTS SUPPORT:
  ===============
  - OnTimer: Fires when the timer interval elapses

  USAGE PATTERN:
  ==============
    ' Create a timer that fires every second
    let tmr# = timer#()
    timer_interval#(tmr#, 1000)    ' 1000ms = 1 second
    timer_ontimer#(tmr#, "OnTick")
    timer_enabled#(tmr#, 1)        ' Start the timer

    function OnTick(sender#)
      println "Timer fired!"
    endfunction

  IMPORTANT NOTES:
  ================
  - Interval is specified in MILLISECONDS (1000 = 1 second)
  - Timer starts disabled by default - set enabled to 1 to start
  - Timer continues firing until disabled or freed
  - Minimum practical interval depends on system load (~10-15ms)

  MEMORY MANAGEMENT:
  ==================
  - Timers are managed exclusively by this unit (NOT by the GC)
  - ActiveTimers list owns all timer instances
  - Proper cleanup occurs during unit finalization
  - This ensures timers are disabled before FMX platform services shut down

  MIT License
  Copyright (c) 2024-2026 André Murta

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

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FMX.Types,
  basic, exec, UnitGC;

type
  TBasTimer = class(TTimer)
  private
    FOnTimerFunc: String;
    FBasicEngine: TBasicEngine;
    FConsoleOutput: TStrings;

    procedure InternalOnTimer(Sender: TObject);
    procedure ExecuteCallback(const FuncSignature: String; const Args: array of TAsmData);

    procedure SetOnTimerFunc(const Value: String);

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    property OnTimerFunc: String read FOnTimerFunc write SetOnTimerFunc;
    property BasicEngine: TBasicEngine read FBasicEngine write FBasicEngine;
    property ConsoleOutput: TStrings read FConsoleOutput write FConsoleOutput;
  end;

procedure RegisterTimerFuncs(Lib: TFunctionsDictionary; Eng: TBasicEngine; OutP: TStrings);

// Call this before application shutdown to clean up all timers
// This is called automatically during unit finalization
procedure CleanupAllTimers();

// Debug support: Pause and resume all active timers (for breakpoints)
procedure PauseAllTimers();
procedure ResumeAllTimers();

implementation

const
  ERR_NONE = 0;
  ERR_INVALID_TIMER = 1;
  ERR_INVALID_VALUE = 2;
  ERR_CREATE_FAILED = 3;

var
  lastError: Integer;
  lastErrorMsg: String;
  ModuleEngine: TBasicEngine;
  ModuleOutput: TStrings;

  // ActiveTimers is the SOLE owner of all timer instances
  // No GC involvement - this list manages the complete lifecycle
  ActiveTimers: TList<TBasTimer>;

  // Tracks which timers were enabled before PauseAllTimers was called
  // Used to restore only those timers that were actually running
  PausedTimerStates: TDictionary<TBasTimer, Boolean>;

// -----------------------------------------------------------------------------
// Error Handling
// -----------------------------------------------------------------------------

procedure SetError(Code: Integer; const Msg: String);
begin
  lastError := Code;
  lastErrorMsg := Msg;
end;

procedure ClearError();
begin
  lastError := ERR_NONE;
  lastErrorMsg := '';
end;

function ValidateTimer(P: Pointer; const FuncName: String): Boolean;
begin
  Result := False;
  if P = nil then
  begin
    SetError(ERR_INVALID_TIMER, FuncName + ': Nil pointer');
    Exit();
  end;

  try
    if not (TObject(P) is TBasTimer) then
    begin
      SetError(ERR_INVALID_TIMER, FuncName + ': Invalid object');
      Exit();
    end;

    // Also verify it's in our managed list
    if not ActiveTimers.Contains(TBasTimer(P)) then
    begin
      SetError(ERR_INVALID_TIMER, FuncName + ': Timer not in managed list');
      Exit();
    end;
  except
    SetError(ERR_INVALID_TIMER, FuncName + ': Invalid pointer');
    Exit();
  end;

  Result := True;
end;

// -----------------------------------------------------------------------------
// TBasTimer Implementation
// -----------------------------------------------------------------------------

constructor TBasTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FOnTimerFunc := '';
  FBasicEngine := nil;
  FConsoleOutput := nil;

  // Timer starts disabled by default
  Enabled := False;
  Interval := 1000;  // Default 1 second
end;

destructor TBasTimer.Destroy();
begin
  // Disable timer and clear event handler before destruction
  // This deregisters from the platform timer service
  Enabled := False;
  OnTimer := nil;
  inherited Destroy();
end;

procedure TBasTimer.ExecuteCallback(const FuncSignature: String; const Args: array of TAsmData);
var
  CallArgs: array of TAsmData;
  RetType: TExprKind;
  RetVal: TAsmData;
  i: Integer;
begin
  if UnitGC.GlobalCallbackBusy then
    Exit();
  if not Assigned(FBasicEngine) then
    Exit();
  if not Assigned(FConsoleOutput) then
    Exit();
  if FuncSignature = '' then
    Exit();

  UnitGC.GlobalCallbackBusy := True;
  UnitGC.SkipProcessMessages := True;

  try
    SetLength(CallArgs, Length(Args));
    for i := 0 to High(Args) do
      CallArgs[i] := Args[i];
    try
      FBasicEngine.ExecuteUserFunction(FConsoleOutput, FuncSignature, CallArgs,
        RetType, RetVal);
    except
      on E: Exception do
      begin
        FConsoleOutput.Add('*** Timer Callback Error: ' + E.Message);
      end;
    end;
  finally
    UnitGC.SkipProcessMessages := False;
    UnitGC.GlobalCallbackBusy := False;
  end;
end;

procedure TBasTimer.SetOnTimerFunc(const Value: String);
begin
  FOnTimerFunc := Value;
  if Value <> '' then
    OnTimer := InternalOnTimer
  else
    OnTimer := nil;
end;

procedure TBasTimer.InternalOnTimer(Sender: TObject);
var
  Args: array[0..0] of TAsmData;
begin
  if FOnTimerFunc = '' then Exit();
  Args[0].p := Sender;
  Args[0].n := 0;
  Args[0].s := '';
  ExecuteCallback(LowerCase(FOnTimerFunc) + '@#', Args);
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Creation and Destruction
// -----------------------------------------------------------------------------

// timer#() -> pointer
// Creates a new timer and returns a pointer to it
function p_timer_create(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  ClearError();

  try
    Tmr := TBasTimer.Create(nil);
    Tmr.BasicEngine := ModuleEngine;
    Tmr.ConsoleOutput := ModuleOutput;

    // Add to ActiveTimers - this is the ONLY ownership mechanism
    ActiveTimers.Add(Tmr);

    Result.p := Pointer(Tmr);
  except
    on E: Exception do
    begin
      SetError(ERR_CREATE_FAILED, 'timer#: ' + E.Message);
    end;
  end;
end;

// timer_free#(tmr#) -> pointer (nil)
// Destroys the timer and releases resources
function p_timer_free(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';

  if not ValidateTimer(Args[0].p, 'timer_free#') then
    Exit();

  try
    Tmr := TBasTimer(Args[0].p);

    // Remove from list and free directly
    ActiveTimers.Remove(Tmr);
    Tmr.Free();

    Result.n := 1;
    ClearError();
  except
    on E: Exception do
    begin
      SetError(ERR_INVALID_TIMER, 'timer_free#: ' + E.Message);
    end;
  end;
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Enabled Property
// -----------------------------------------------------------------------------

// timer_enabled(tmr#) -> number (0 or 1)
// Gets whether the timer is currently running
function n_timer_enabled_get(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_enabled') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  if Tmr.Enabled then
    Result.n := 1
  else
    Result.n := 0;
end;

// timer_enabled#(tmr#, enabled) -> pointer
// Sets whether the timer is running (0=stopped, 1=running)
function p_timer_enabled_set(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_enabled#') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Tmr.Enabled := (Args[1].n <> 0);
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Interval Property
// -----------------------------------------------------------------------------

// timer_interval(tmr#) -> number
// Gets the timer interval in milliseconds
function n_timer_interval_get(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_interval') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Result.n := Tmr.Interval;
end;

// timer_interval#(tmr#, milliseconds) -> pointer
// Sets the timer interval in milliseconds
function p_timer_interval_set(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
  Interval: Integer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_interval#') then
    Exit();

  Interval := Trunc(Args[1].n);
  if Interval < 1 then
  begin
    SetError(ERR_INVALID_VALUE, 'timer_interval#: Interval must be >= 1');
    Exit();
  end;

  Tmr := TBasTimer(Args[0].p);
  Tmr.Interval := Interval;
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Tag Property
// -----------------------------------------------------------------------------

// timer_tag(tmr#) -> number
// Gets the numeric tag value
function n_timer_tag_get(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_tag') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Result.n := Tmr.Tag;
end;

// timer_tag#(tmr#, tagValue) -> pointer
// Sets the numeric tag value
function p_timer_tag_set(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_tag#') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Tmr.Tag := Trunc(Args[1].n);
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Event Callback
// -----------------------------------------------------------------------------

// timer_ontimer#(tmr#, funcName$) -> pointer
// Sets the OnTimer callback function name
function p_timer_ontimer_set(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_ontimer#') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Tmr.OnTimerFunc := Args[1].s;
end;

// timer_ontimer$(tmr#) -> string
// Gets the OnTimer callback function name
function s_timer_ontimer_get(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_ontimer$') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Result.s := Tmr.OnTimerFunc;
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Utility
// -----------------------------------------------------------------------------

// timer_start#(tmr#) -> pointer
// Convenience function to start the timer (same as timer_enabled#(tmr#, 1))
function p_timer_start(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_start#') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Tmr.Enabled := True;
end;

// timer_stop#(tmr#) -> pointer
// Convenience function to stop the timer (same as timer_enabled#(tmr#, 0))
function p_timer_stop(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_stop#') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Tmr.Enabled := False;
end;

// timer_restart#(tmr#) -> pointer
// Restarts the timer (stops and starts, resetting the interval countdown)
function p_timer_restart(var Args: array of TAsmData): TAsmData;
var
  Tmr: TBasTimer;
begin
  Result.n := 0;
  Result.p := Args[0].p;
  Result.s := '';
  ClearError();

  if not ValidateTimer(Args[0].p, 'timer_restart#') then
    Exit();

  Tmr := TBasTimer(Args[0].p);
  Tmr.Enabled := False;
  Tmr.Enabled := True;
end;

// -----------------------------------------------------------------------------
// Plan9Basic Functions - Error Handling
// -----------------------------------------------------------------------------

// timer_error() -> number
// Returns the last error code
function n_timer_error(var Args: array of TAsmData): TAsmData;
begin
  Result.n := lastError;
  Result.p := nil;
  Result.s := '';
end;

// timer_error$() -> string
// Returns the last error message
function s_timer_error(var Args: array of TAsmData): TAsmData;
begin
  Result.n := 0;
  Result.p := nil;
  Result.s := lastErrorMsg;
end;

// -----------------------------------------------------------------------------
// Library Registration
// -----------------------------------------------------------------------------

procedure RegisterTimerFuncs(Lib: TFunctionsDictionary; Eng: TBasicEngine; OutP: TStrings);
var
  Fn: TLinkFunction;
begin
  ModuleEngine := Eng;
  ModuleOutput := OutP;
  lastError := ERR_NONE;
  lastErrorMsg := '';

  Fn.FarCall := True;

  // Creation and Destruction
  Fn.Entry := @p_timer_create; Lib.Add('timer#@', Fn);
  Fn.Entry := @p_timer_free; Lib.Add('timer_free#@#', Fn);

  // Enabled property
  Fn.Entry := @n_timer_enabled_get; Lib.Add('timer_enabled@#', Fn);
  Fn.Entry := @p_timer_enabled_set; Lib.Add('timer_enabled#@#n', Fn);

  // Interval property
  Fn.Entry := @n_timer_interval_get; Lib.Add('timer_interval@#', Fn);
  Fn.Entry := @p_timer_interval_set; Lib.Add('timer_interval#@#n', Fn);

  // Tag property
  Fn.Entry := @n_timer_tag_get; Lib.Add('timer_tag@#', Fn);
  Fn.Entry := @p_timer_tag_set; Lib.Add('timer_tag#@#n', Fn);

  // OnTimer event
  Fn.Entry := @p_timer_ontimer_set; Lib.Add('timer_ontimer#@#$', Fn);
  Fn.Entry := @s_timer_ontimer_get; Lib.Add('timer_ontimer$@#', Fn);

  // Utility functions
  Fn.Entry := @p_timer_start; Lib.Add('timer_start#@#', Fn);
  Fn.Entry := @p_timer_stop; Lib.Add('timer_stop#@#', Fn);
  Fn.Entry := @p_timer_restart; Lib.Add('timer_restart#@#', Fn);

  // Error handling
  Fn.Entry := @n_timer_error; Lib.Add('timer_error@', Fn);
  Fn.Entry := @s_timer_error; Lib.Add('timer_error$@', Fn);
end;

// -----------------------------------------------------------------------------
// Timer Cleanup - Disables and frees all managed timers
// -----------------------------------------------------------------------------

procedure CleanupAllTimers();
var
  Tmr: TBasTimer;
begin
  if not Assigned(ActiveTimers) then
    Exit;

  // Free all timers in reverse order (LIFO)
  while ActiveTimers.Count > 0 do
  begin
    Tmr := ActiveTimers[ActiveTimers.Count - 1];
    ActiveTimers.Delete(ActiveTimers.Count - 1);
    try
      Tmr.Free();
    except
      // Ignore errors during cleanup
    end;
  end;
end;

// -----------------------------------------------------------------------------
// Debug Support - Pause/Resume all timers for breakpoints
// -----------------------------------------------------------------------------

procedure PauseAllTimers();
var
  Tmr: TBasTimer;
begin
  if not Assigned(ActiveTimers) then
    Exit;
  if not Assigned(PausedTimerStates) then
    Exit;

  // Clear any previous state
  PausedTimerStates.Clear();

  // Save state and disable all active timers
  for Tmr in ActiveTimers do
  begin
    try
      // Save whether this timer was enabled
      PausedTimerStates.Add(Tmr, Tmr.Enabled);
      // Disable the timer
      if Tmr.Enabled then
        Tmr.Enabled := False;
    except
      // Ignore errors
    end;
  end;
end;

procedure ResumeAllTimers();
var
  Tmr: TBasTimer;
  WasEnabled: Boolean;
begin
  if not Assigned(ActiveTimers) then
    Exit;
  if not Assigned(PausedTimerStates) then
    Exit;

  // Restore state for all timers
  for Tmr in ActiveTimers do
  begin
    try
      // Only re-enable timers that were enabled before pause
      if PausedTimerStates.TryGetValue(Tmr, WasEnabled) then
      begin
        if WasEnabled then
          Tmr.Enabled := True;
      end;
    except
      // Ignore errors
    end;
  end;

  // Clear the saved state
  PausedTimerStates.Clear();
end;

// -----------------------------------------------------------------------------
// Initialization and Finalization
// -----------------------------------------------------------------------------

initialization
  ActiveTimers := TList<TBasTimer>.Create();
  PausedTimerStates := TDictionary<TBasTimer, Boolean>.Create();

finalization
  // Clean up all timers before the platform services shut down
  CleanupAllTimers();
  FreeAndNil(PausedTimerStates);
  FreeAndNil(ActiveTimers);

end.
