program Plan9BasicApplet;

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

uses
  System.StartUpCopy,
  FMX.Forms,
  AppletRunner in 'AppletRunner.pas' {frmAppletRunner},
  basic in 'basic.pas',
  lexer in 'lexer.pas',
  parser in 'parser.pas',
  exec in 'exec.pas',
  UnitUtils in 'UnitUtils.pas',
  UnitGC in 'utils\UnitGC.pas',
  ArrayLib in 'Libs\ArrayLib.pas',
  StdLib in 'Libs\StdLib.pas',
  StrLib in 'Libs\StrLib.pas',
  SysLib in 'Libs\SysLib.pas',
  TimerLib in 'Libs\TimerLib.pas',
  NumLib in 'Libs\NumLib.pas',
  DateTimeLib in 'Libs\DateTimeLib.pas',
  JsonLib in 'Libs\JsonLib.pas',
  ConfigLib in 'Libs\ConfigLib.pas',
  Base64Lib in 'Libs\Base64Lib.pas',
  ZipLib in 'Libs\ZipLib.pas',
  HttpLib in 'Libs\HttpLib.pas',
  PlatformInfoLib in 'Libs\PlatformInfoLib.pas',
  AILib in 'Libs\AI\AILib.pas',
  RAGEngine in 'Libs\AI\RAGEngine.pas',
  RAGLib in 'Libs\AI\RAGLib.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmAppletRunner, frmAppletRunner);
  Application.Run;
end.
