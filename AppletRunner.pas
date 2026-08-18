unit AppletRunner;

{******************************************************************************
  Plan9Basic Interpreter Engine
  AppletRunner — Minimal FMX host application form

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

  ---------------------------------------------------------------------------
  Overview
  ---------------------------------------------------------------------------
  TfrmAppletRunner is a self-contained FMX form built entirely in code
  (no .fmx file required).  It provides:

    * A script editor pane where you can type or paste Plan9Basic source.
    * Load / Save buttons to read and write .bas files.
    * Run / Stop buttons to compile and execute the current script.
    * An output pane that displays every PRINT result from the script.
    * A status label showing compile / runtime feedback.

  The form initialises TBasicEngine and registers the four standard
  libraries included with this project:
    - ArrayLib (dynamic arrays)
    - StdLib (general utilities)
    - StrLib (string functions)
    - SysLib (file system / environment)

  ---------------------------------------------------------------------------
  Cross-platform compatibility
  ---------------------------------------------------------------------------
  This unit compiles and runs on every platform supported by FireMonkey:
  Windows, macOS, Linux, iOS, and Android.

  On desktop platforms (Windows, macOS, Linux), Load and Save use the
  native TOpenDialog / TSaveDialog file pickers.

  On mobile platforms (iOS and Android), TOpenDialog / TSaveDialog are not
  available.  Instead, Load and Save use TDialogService.InputQuery to ask
  for a filename, and files are read from / written to the application's
  Documents folder (TPath.GetDocumentsPath).  On Android, deploy your .bas
  scripts to the device's Documents folder via the IDE or adb before loading.

  The P9B_DESKTOP conditional is set automatically based on the target
  platform — no manual configuration is needed.

  ---------------------------------------------------------------------------
  Embedding guide
  ---------------------------------------------------------------------------
  To host the Plan9Basic engine in your own FMX application:

    GC := TGarbageCollector.Create();       // must come first

    FEngine := TBasicEngine.Create();
    RegisterArrayFuncs(FEngine.Functions);
    RegisterStdFuncs(FEngine.Functions);
    RegisterStrFuncs(FEngine.Functions);
    RegisterSysFuncs(FEngine.Functions);
    RegisterTimerFuncs(FEngine.Functions, FEngine, OutputLines);  // required — pass your output TStrings
    FEngine.ScriptTimeOut := 30;            // seconds

    if FEngine.Compile(ScriptLines) = 0 then
      FEngine.ExecuteProgram(OutputLines)
    else
      ShowError(FEngine.ErrorLine, FEngine.ErrorMessage);

    FreeAndNil(FEngine);
    FreeAndNil(GC);                         // must come last
******************************************************************************}

// ---------------------------------------------------------------------------
//  Platform detection
//  P9B_DESKTOP is defined for Windows, macOS, and Linux.
//  When NOT defined (iOS, Android), the mobile file-access path is compiled.
// ---------------------------------------------------------------------------
{$IF DEFINED(MSWINDOWS) OR DEFINED(MACOS) OR DEFINED(LINUX)}
  {$DEFINE P9B_DESKTOP}
{$ENDIF}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.DialogService,
  FMX.DialogService.Async,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Memo, FMX.Layouts,
  FMX.ScrollBox, FMX.Memo.Types, FMX.Edit,
  basic, exec, UnitGC,
  ArrayLib, StdLib, StrLib, SysLib, TimerLib,
  NumLib, DateTimeLib, JsonLib, ConfigLib, Base64Lib, ZipLib,
  PlatformInfoLib, HttpLib, AILib, RAGLib;

type
  TfrmAppletRunner = class(TForm)
  private
    FEngine: TBasicEngine;

    // Layout containers
    FLayoutToolbar : TLayout;

    // Toolbar controls
    FBtnLoad: TButton;
    FBtnSave: TButton;
    FBtnRun: TButton;
    FBtnStop: TButton;
    FBtnClear: TButton;
    FStatusLbl: TLabel;

    // Editor / output panes
    FScriptMemo: TMemo;
    FSplitter: TSplitter;
    FOutputMemo: TMemo;

    // File dialogs — desktop platforms only
    {$IFDEF P9B_DESKTOP}
    FOpenDlg: TOpenDialog;
    FSaveDlg: TSaveDialog;
    {$ENDIF}

    // Internals
    FCurrentFile : String;

    procedure BtnLoadClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnRunClick(Sender: TObject);
    procedure BtnStopClick(Sender: TObject);
    procedure BtnClearClick(Sender: TObject);

    // Called by the engine for each PRINT statement
    procedure OnPrintOutput(Sender: TObject; const Text: String; IsClear: Boolean);

    procedure BuildUI();
    //Host side of the engine's interactions with a person. The engine itself
    //no longer knows FireMonkey; the dialogs live here.
    procedure HostInput(const ACaption: String; const ALabels: array of String;
                        const ADefaults: array of String; const ADone: TInputDoneProc);
    procedure HostConfirm(const AMessage: String; const ADone: TConfirmDoneProc);
    procedure HostYield();
    procedure InitEngine();
    procedure SetStatus(const Msg: String);
    procedure SetTitle();

    // Helper: create a toolbar button
    function MakeButton(const Caption: String; W: Single; Handler: TNotifyEvent): TButton;

    // Mobile helpers
    {$IFNDEF P9B_DESKTOP}
    function MobileDocsPath: String;
    {$ENDIF}
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
  end;

var
  frmAppletRunner: TfrmAppletRunner;

implementation

{ TfrmAppletRunner }

constructor TfrmAppletRunner.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);  // CreateNew skips .fmx resource loading (form is built entirely in code)
  BuildUI();
  // Engine and GC are NOT created here — they are built fresh on each Run
  // click inside BtnRunClick, mirroring the original Plan9Basic CmdRun pattern.
end;

destructor TfrmAppletRunner.Destroy();
begin
  // Cleanup order mirrors InitBASICEngine in the original project:
  // 1. Timers first (they hold callbacks into the engine)
  TimerLib.CleanupAllTimers();
  // 2. Engine
  FreeAndNil(FEngine);
  // 3. GC last — non-visual heap objects may still reference engine data
  if Assigned(GC) then
    FreeAndNil(GC);

  inherited Destroy();
end;

// ---------------------------------------------------------------------------
//  Engine initialisation  (called at the start of every Run)
// ---------------------------------------------------------------------------
//
//  This mirrors the InitBASICEngine + CmdRun pattern from the original
//  Plan9Basic project (UnitMain.pas, lines 2006-2157 / 2447-2514):
//
//    Cleanup order:  Timers → Engine → GC
//    Rebuild order:  GC → Engine → Libraries → OnPrintOutput
//
//  The engine is NEVER reused between runs; a fresh pair (GC + Engine)
//  is created each time so that no stale heap objects or registered
//  callbacks can interfere with the next execution.
// ---------------------------------------------------------------------------

procedure TfrmAppletRunner.HostInput(const ACaption: String;
  const ALabels: array of String; const ADefaults: array of String;
  const ADone: TInputDoneProc);
var
  Values: array of String;
  I: Integer;
begin
  SetLength(Values, Length(ADefaults));
  for I := 0 to High(ADefaults) do
    Values[I] := ADefaults[I];

  TDialogServiceAsync.InputQuery(ACaption, ALabels, Values,
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      ADone(AResult = mrOk, AValues);
    end);
end;

procedure TfrmAppletRunner.HostConfirm(const AMessage: String;
  const ADone: TConfirmDoneProc);
begin
  //Timers belong to the host, so pausing them around a breakpoint is the
  //host's job. The engine only asks the question.
  TimerLib.PauseAllTimers();

  TDialogServiceAsync.MessageDialog(AMessage, TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes, 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrNo then
        TimerLib.ResumeAllTimers();
      ADone(AResult <> mrNo);
    end);
end;

procedure TfrmAppletRunner.HostYield();
begin
  Application.ProcessMessages();
end;

procedure TfrmAppletRunner.InitEngine();
begin
  // --- Tear down previous run (safe to call even on the very first run) ---
  TimerLib.CleanupAllTimers();        // stop async timer callbacks first
  FreeAndNil(FEngine);
  if Assigned(GC) then FreeAndNil(GC);

  // --- Rebuild ---
  GC      := TGarbageCollector.Create();  // must come before engine
  FEngine := TBasicEngine.Create();

  // Register the standard libraries supplied with this project.
  RegisterArrayFuncs(FEngine.Functions);                             // arrays
  RegisterStdFuncs(FEngine.Functions);                               // type conversion, formatting
  RegisterStrFuncs(FEngine.Functions);                               // string manipulation (47+ funcs)
  RegisterSysFuncs(FEngine.Functions);                               // file system, environment vars
  RegisterTimerFuncs(FEngine.Functions, FEngine, FOutputMemo.Lines); // timer callbacks (required)
  RegisterNumFuncs(FEngine.Functions);                               // math: trig, log, random...
  RegisterDateTimeFuncs(FEngine.Functions);                          // date/time operations
  RegisterJsonFuncs(FEngine.Functions);                              // JSON parse & build
  RegisterConfigFuncs(FEngine.Functions);                            // INI-style config files
  RegisterBase64Funcs(FEngine.Functions);                            // Base64 encode/decode
  RegisterZipFuncs(FEngine.Functions);                               // ZIP archive operations
  RegisterHttpFuncs(FEngine.Functions, FEngine, FOutputMemo.Lines);  // HTTP client protocol
  RegisterPlatformInfoFuncs(FEngine.Functions);                      // Runtime platform info
  RegisterAIFuncs(FEngine.Functions, FEngine, FOutputMemo.Lines);    // AI Transport Layer
  RegisterRAGFuncs(FEngine.Functions);                               // RAG Engine

  FEngine.ScriptTimeOut := 30; // seconds; 0 = unlimited
  FEngine.OnPrintOutput := OnPrintOutput;
  FEngine.InputProc := HostInput;
  //BREAKPOINT parks the VM until this answers, so it is only safe where the
  //platform can deliver a modal answer with the calling thread blocked. Left
  //unset, the engine reports the breakpoint frame to the trace and carries on,
  //instead of waiting for a reply that can never arrive.
  if CanPauseForHostDialog then
    FEngine.ConfirmProc := HostConfirm;
  FEngine.YieldProc := HostYield;
end;

// ---------------------------------------------------------------------------
//  UI construction (no .fmx file — everything is built in code)
// ---------------------------------------------------------------------------

function TfrmAppletRunner.MakeButton(const Caption: String; W: Single; Handler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FLayoutToolbar;
  Result.Text := Caption;
  Result.Align := TAlignLayout.Left;
  Result.Width := W;
  Result.Margins.Right := 4;
  Result.OnClick := Handler;
end;

procedure TfrmAppletRunner.BuildUI();
const
  TOOLBAR_H = 48;
  {$IFDEF P9B_DESKTOP}
  BTN_W = 90;
  {$ELSE}
  BTN_W = 64;  // narrow buttons so all 5 fit on a phone in portrait
  {$ENDIF}
begin
  Caption := 'Plan9Basic Applet Runner';
  Width   := 960;
  Height  := 700;

  // ---- Toolbar (button row) ----
  FLayoutToolbar := TLayout.Create(Self);
  FLayoutToolbar.Parent := Self;
  FLayoutToolbar.Align  := TAlignLayout.Top;
  FLayoutToolbar.Height := TOOLBAR_H;
  FLayoutToolbar.Padding.Rect := TRectF.Create(4, 4, 4, 4);

  // NOTE: FMX TAlignLayout.Left stacks controls in REVERSE creation order
  // (last created = leftmost).  Create buttons right-to-left so they display
  // Load | Save | Run | Stop | Clear from left to right on screen.
  {$IFDEF P9B_DESKTOP}
  FBtnClear := MakeButton('Clear Output',  110,   BtnClearClick);
  FBtnStop  := MakeButton('Stop  '#$25A0, BTN_W, BtnStopClick);
  FBtnRun   := MakeButton('Run  '#$25B6,  BTN_W, BtnRunClick);
  FBtnSave  := MakeButton('Save',          BTN_W, BtnSaveClick);
  FBtnLoad  := MakeButton('Load',          BTN_W, BtnLoadClick);

  // Status label fills remaining toolbar width on the right (desktop only)
  FStatusLbl := TLabel.Create(Self);
  FStatusLbl.Parent := FLayoutToolbar;
  FStatusLbl.Align  := TAlignLayout.Client;
  FStatusLbl.Text   := 'Ready';
  FStatusLbl.TextSettings.HorzAlign := TTextAlign.Trailing;
  FStatusLbl.TextSettings.VertAlign := TTextAlign.Center;
  FStatusLbl.Margins.Right := 6;
  {$ELSE}
  // Mobile: icon-only Run/Stop buttons to stay narrow; all 5 × 64 = 320 px
  FBtnClear := MakeButton('Clear',  BTN_W, BtnClearClick);
  FBtnStop  := MakeButton(#$25A0,  BTN_W, BtnStopClick);   // ■
  FBtnRun   := MakeButton(#$25B6,  BTN_W, BtnRunClick);    // ▶
  FBtnSave  := MakeButton('Save',   BTN_W, BtnSaveClick);
  FBtnLoad  := MakeButton('Load',   BTN_W, BtnLoadClick);
  {$ENDIF}

  // ---- Mobile status bar (thin row below toolbar, above editor) ----
  {$IFNDEF P9B_DESKTOP}
  FStatusLbl := TLabel.Create(Self);
  FStatusLbl.Parent  := Self;
  FStatusLbl.Align   := TAlignLayout.Top;
  FStatusLbl.Height  := 22;
  FStatusLbl.Text    := 'Ready';
  FStatusLbl.Font.Size := 11;
  FStatusLbl.TextSettings.HorzAlign := TTextAlign.Center;
  FStatusLbl.TextSettings.VertAlign := TTextAlign.Center;
  {$ENDIF}

  // ---- Script editor (top half) ----
  FScriptMemo := TMemo.Create(Self);
  FScriptMemo.Parent := Self;
  FScriptMemo.Align := TAlignLayout.Top;
  {$IFDEF P9B_DESKTOP}
  FScriptMemo.Height := 300;
  {$ELSE}
  FScriptMemo.Height := 220;  // shorter on mobile to leave room for output
  {$ENDIF}
  FScriptMemo.Font.Family := 'Courier New';
  FScriptMemo.Font.Size := 13;
  FScriptMemo.Lines.Add('REM  Plan9Basic - host validation applet');
  FScriptMemo.Lines.Add('REM');
  FScriptMemo.Lines.Add('REM  Press Run. Five checks, each printing PASS or');
  FScriptMemo.Lines.Add('REM  FAIL. Read check 5 before running: INPUT is');
  FScriptMemo.Lines.Add('REM  asynchronous, so the script finishes BEFORE you');
  FScriptMemo.Lines.Add('REM  answer it, and its PASS line arrives later. That');
  FScriptMemo.Lines.Add('REM  is the design, not a fault.');
  FScriptMemo.Lines.Add('');
  FScriptMemo.Lines.Add('FUNCTION gotIt(v) LOCAL d');
  FScriptMemo.Lines.Add('  PRINTLN "  PASS - the host returned " + STR$(v)');
  FScriptMemo.Lines.Add('  PRINTLN "  (arriving after Done. is correct: INPUT is async)"');
  FScriptMemo.Lines.Add('  RETURN 0');
  FScriptMemo.Lines.Add('END FUNCTION');
  FScriptMemo.Lines.Add('');
  FScriptMemo.Lines.Add('PRINTLN "=== 1/5  UI stays alive (YieldProc) ==="');
  FScriptMemo.Lines.Add('PRINTLN "  scrolling 30 lines; the screen must not freeze"');
  FScriptMemo.Lines.Add('FOR i = 1 TO 30');
  FScriptMemo.Lines.Add('  PRINTLN "  working " + STR$(i)');
  FScriptMemo.Lines.Add('NEXT i');
  FScriptMemo.Lines.Add('PRINTLN "  PASS if the app stayed responsive"');
  FScriptMemo.Lines.Add('PRINTLN ""');
  FScriptMemo.Lines.Add('');
  FScriptMemo.Lines.Add('PRINTLN "=== 2/5  Library errors are reported ==="');
  FScriptMemo.Lines.Add('d$ = b64decode$("NotValid!!!")');
  FScriptMemo.Lines.Add('IF b64error() <> 0 THEN');
  FScriptMemo.Lines.Add('  PRINTLN "  PASS - bad input reported code " + STR$(b64error())');
  FScriptMemo.Lines.Add('ELSE');
  FScriptMemo.Lines.Add('  PRINTLN "  FAIL - bad input reported no error"');
  FScriptMemo.Lines.Add('END IF');
  FScriptMemo.Lines.Add('PRINTLN ""');
  FScriptMemo.Lines.Add('');
  FScriptMemo.Lines.Add('PRINTLN "=== 3/5  Invented pointer is refused ==="');
  FScriptMemo.Lines.Add('t# = timer#()');
  FScriptMemo.Lines.Add('timer_interval#(t#, 500)');
  FScriptMemo.Lines.Add('PRINTLN "  a real handle reads " + STR$(timer_interval(t#))');
  FScriptMemo.Lines.Add('junk# = pointer#(305419896)');
  FScriptMemo.Lines.Add('n = timer_interval(junk#)');
  FScriptMemo.Lines.Add('IF timer_error() <> 0 THEN');
  FScriptMemo.Lines.Add('  PRINTLN "  PASS - refused: " + timer_error$()');
  FScriptMemo.Lines.Add('ELSE');
  FScriptMemo.Lines.Add('  PRINTLN "  FAIL - an invented address was accepted"');
  FScriptMemo.Lines.Add('END IF');
  FScriptMemo.Lines.Add('timer_free#(t#)');
  FScriptMemo.Lines.Add('PRINTLN ""');
  FScriptMemo.Lines.Add('');
  FScriptMemo.Lines.Add('PRINTLN "=== 4/5  BREAKPOINT degrades where it cannot pause ==="');
  FScriptMemo.Lines.Add('PRINTLN "  desktop: a dialog appears - answer YES to go on"');
  FScriptMemo.Lines.Add('PRINTLN "  mobile:  no dialog; the frame is printed below"');
  FScriptMemo.Lines.Add('bpcount = 3');
  FScriptMemo.Lines.Add('bpname$ = "frame dump"');
  FScriptMemo.Lines.Add('TRACE 1');
  FScriptMemo.Lines.Add('BREAKPOINT "checkpoint reached", bpcount, bpname$');
  FScriptMemo.Lines.Add('TRACE 0');
  FScriptMemo.Lines.Add('PRINTLN "  PASS - execution continued past the breakpoint"');
  FScriptMemo.Lines.Add('PRINTLN ""');
  FScriptMemo.Lines.Add('');
  FScriptMemo.Lines.Add('PRINTLN "=== 5/5  INPUT asks the host (async) ==="');
  FScriptMemo.Lines.Add('PRINTLN "  a prompt appears; the script ENDS without waiting"');
  FScriptMemo.Lines.Add('PRINTLN "  type a number - the PASS line arrives when you do"');
  FScriptMemo.Lines.Add('INPUT "Plan9Basic", "Type any number:", 42, gotIt');
  FScriptMemo.Lines.Add('PRINTLN ""');
  FScriptMemo.Lines.Add('PRINTLN "script finished - now answer the prompt above"');

  // ---- Splitter between editor and output ----
  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := Self;
  FSplitter.Align := TAlignLayout.Top;
  FSplitter.Height := 8;
  FSplitter.MinSize := 80;

  // ---- Output console (bottom half) ----
  FOutputMemo := TMemo.Create(Self);
  FOutputMemo.Parent := Self;
  FOutputMemo.Align := TAlignLayout.Client;
  FOutputMemo.ReadOnly := True;
  FOutputMemo.Font.Family := 'Courier New';
  FOutputMemo.Font.Size := 13;

  // ---- File dialogs (desktop only) ----
  {$IFDEF P9B_DESKTOP}
  FOpenDlg := TOpenDialog.Create(Self);
  FOpenDlg.Filter := 'Plan9Basic Scripts (*.bas)|*.bas|All Files (*.*)|*.*';

  FSaveDlg := TSaveDialog.Create(Self);
  FSaveDlg.Filter := 'Plan9Basic Scripts (*.bas)|*.bas';
  FSaveDlg.DefaultExt := 'bas';
  {$ENDIF}
end;

// ---------------------------------------------------------------------------
//  Toolbar handlers
// ---------------------------------------------------------------------------

procedure TfrmAppletRunner.BtnLoadClick(Sender: TObject);
{$IFDEF P9B_DESKTOP}
begin
  if FOpenDlg.Execute() then
  begin
    FScriptMemo.Lines.LoadFromFile(FOpenDlg.FileName);
    FCurrentFile := FOpenDlg.FileName;
    SetTitle();
    SetStatus('Loaded: ' + ExtractFileName(FOpenDlg.FileName));
  end;
end;
{$ELSE}
// Mobile: ask for a filename and load from the app's Documents folder.
var
  DefaultName: String;
begin
  DefaultName := ExtractFileName(FCurrentFile);
  TDialogService.InputQuery('Load Script', ['Filename in Documents folder:'], [DefaultName],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      FullPath: String;
    begin
      if (AResult = mrOk) and (Trim(AValues[0]) <> '') then
      begin
        FullPath := TPath.Combine(MobileDocsPath, Trim(AValues[0]));
        if TFile.Exists(FullPath) then
        begin
          FScriptMemo.Lines.LoadFromFile(FullPath);
          FCurrentFile := FullPath;
          SetTitle();
          SetStatus('Loaded: ' + ExtractFileName(FullPath));
        end
        else
          SetStatus('File not found: ' + Trim(AValues[0]));
      end;
    end);
end;
{$ENDIF}

procedure TfrmAppletRunner.BtnSaveClick(Sender: TObject);
{$IFDEF P9B_DESKTOP}
begin
  if FCurrentFile <> '' then
    FSaveDlg.FileName := FCurrentFile;
  if FSaveDlg.Execute() then
  begin
    FScriptMemo.Lines.SaveToFile(FSaveDlg.FileName);
    FCurrentFile := FSaveDlg.FileName;
    SetTitle();
    SetStatus('Saved: ' + ExtractFileName(FSaveDlg.FileName));
  end;
end;
{$ELSE}
// Mobile: ask for a filename and save to the app's Documents folder.
var
  DefaultName: String;
begin
  DefaultName := ExtractFileName(FCurrentFile);
  if DefaultName = '' then DefaultName := 'script.bas';
  TDialogService.InputQuery('Save Script', ['Filename in Documents folder:'], [DefaultName],
    procedure(const AResult: TModalResult; const AValues: array of string)
    var
      FullPath: String;
    begin
      if (AResult = mrOk) and (Trim(AValues[0]) <> '') then
      begin
        FullPath := TPath.Combine(MobileDocsPath, Trim(AValues[0]));
        FScriptMemo.Lines.SaveToFile(FullPath);
        FCurrentFile := FullPath;
        SetTitle();
        SetStatus('Saved: ' + ExtractFileName(FullPath));
      end;
    end);
end;
{$ENDIF}

procedure TfrmAppletRunner.BtnRunClick(Sender: TObject);
var
  ErrCount: Integer;
begin
  SetStatus('Initialising engine...');
  Application.ProcessMessages();

  // Tear down the previous run and build a fresh engine — same pattern as
  // the original Plan9Basic project's CmdRun → InitBASICEngine sequence.
  InitEngine();

  SetStatus('Compiling...');
  Application.ProcessMessages();

  ErrCount := FEngine.Compile(FScriptMemo.Lines);

  if ErrCount <> 0 then
  begin
    FOutputMemo.Lines.Add(Format('Compile error (line %d): %s', [FEngine.ErrorLine, FEngine.ErrorMessage]));
    SetStatus('Compile error — see output pane.');
    Exit();
  end;

  SetStatus('Running...');
  Application.ProcessMessages();

  try
    // Pass the output memo lines directly: every PRINT appends a line there.
    FEngine.ExecuteProgram(FOutputMemo.Lines);
    SetStatus('Done.');
  except
    on E: Exception do
    begin
      FOutputMemo.Lines.Add('Runtime error: ' + E.Message);
      SetStatus('Runtime error — see output pane.');
    end;
  end;
end;

procedure TfrmAppletRunner.BtnStopClick(Sender: TObject);
begin
  if Assigned(FEngine) then
    FEngine.Stop();
  SetStatus('Stopped by user.');
end;

procedure TfrmAppletRunner.BtnClearClick(Sender: TObject);
begin
  FOutputMemo.Lines.Clear();
end;

// ---------------------------------------------------------------------------
//  Engine callback
// ---------------------------------------------------------------------------

procedure TfrmAppletRunner.OnPrintOutput(Sender: TObject; const Text: String; IsClear: Boolean);
begin
  // IsClear = True means the BASIC script issued a CLS command.
  if IsClear then
    FOutputMemo.Lines.Clear();
  // Text output is already appended by ExecuteProgram via the stdout TStrings
  // reference, so we only need to handle the clear-screen case here.
end;

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

procedure TfrmAppletRunner.SetStatus(const Msg: String);
begin
  FStatusLbl.Text := Msg;
end;

procedure TfrmAppletRunner.SetTitle();
begin
  if FCurrentFile <> '' then
    Caption := 'Plan9Basic Applet Runner — ' + ExtractFileName(FCurrentFile)
  else
    Caption := 'Plan9Basic Applet Runner';
end;

{$IFNDEF P9B_DESKTOP}
function TfrmAppletRunner.MobileDocsPath: String;
begin
  // Returns the app's writable Documents folder on iOS and Android.
  // On Android this maps to the internal app storage Documents directory.
  // On iOS this is the app's sandboxed Documents directory, which is also
  // accessible via iTunes File Sharing when enabled in Info.plist.
  Result := TPath.GetDocumentsPath;
end;
{$ENDIF}

end.
