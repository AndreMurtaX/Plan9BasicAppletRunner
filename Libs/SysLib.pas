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
unit SysLib;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.UIConsts, System.Classes, System.IOUtils,
  {$IFDEF ANDROID}
  Posix.Unistd,
  {$ENDIF}
  {$IFDEF LINUX64}
  Posix.Unistd,
  {$ENDIF}
  FMX.Forms,
  exec;

procedure RegisterSysFuncs(Lib: TFunctionsDictionary);

implementation

function n_paramcount(var Args: array of TAsmData): TAsmData;
begin
  Result.n := ParamCount();
end;

function s_paramstr(var Args: array of TAsmData): TAsmData;
begin
  Result.s := ParamStr(Trunc(Int(Args[0].n)));
end;

function n_chdir(var Args: array of TAsmData): TAsmData;
begin
  Result.n := 1;
  ChDir(Args[0].s);
end;

function n_kill(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Ord(DeleteFile(Args[0].s));
end;

function n_fileexists(var Args: array of TAsmData): TAsmData;
var
  FollowLink: Boolean;
begin
  FollowLink := False;
  if Args[1].n <> 0 then
    FollowLink := True;
  Result.n := 0;
  if FileExists(Args[0].s, FollowLink) then Result.n := 1;
end;

function n_mkdir(var Args: array of TAsmData): TAsmData;
begin
  Result.n := 1;
  MkDir(Args[0].s);
end;

function n_forcedirectories(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Ord(ForceDirectories(Args[0].s));
end;

function n_rmdir(var Args: array of TAsmData): TAsmData;
begin
  Result.n := 1;
  RmDir(Args[0].s);
end;

function s_environ(var Args: array of TAsmData): TAsmData;
begin
  Result.s := GetEnvironmentVariable(Args[0].s);
end;

function s_getrandomfilename(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetRandomFileName;
end;

function s_getguidfilename(var Args: array of TAsmData): TAsmData;
var
  UseSep: Boolean;
begin
  UseSep := True;
  if Args[0].n = 0 then
    UseSep := False;
  Result.s := System.IOUtils.TPath.GetGUIDFileName(UseSep);
end;

function s_gettempfilename(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetTempFileName();
end;

function s_gettemppath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetTempPath();
end;

function s_gethomepath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetHomePath();
end;

function s_getdocumentspath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetDocumentsPath();
end;

function s_getshareddocumentspath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedDocumentsPath();
end;

function s_getlibrarypath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetLibraryPath();
end;

function s_getcachepath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetCachePath();
end;

function s_getpublicpath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetPublicPath();
end;

function s_getpicturespath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetPicturesPath();
end;

function s_getsharedpicturespath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedPicturesPath();
end;

function s_getcamerapath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetCameraPath();
end;

function s_getsharedcamerapath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedCameraPath();
end;

function s_getmusicpath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetMusicPath();
end;

function s_getsharedmusicpath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedMusicPath();
end;

function s_getmoviespath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetMoviesPath();
end;

function s_getsharedmoviespath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedMoviesPath();
end;

function s_getalarmspath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetAlarmsPath();
end;

function s_getsharedalarmspath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedAlarmsPath();
end;

function s_getdownloadspath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetDownloadsPath();
end;

function s_getshareddownloadspath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedDownloadsPath();
end;

function s_getringtonespath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetRingtonesPath();
end;

function s_getsharedringtonespath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.GetSharedRingtonesPath();
end;

function s_dirseparator(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.DirectorySeparatorChar;
end;

function s_altseparator(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.AltDirectorySeparatorChar;
end;

function s_pathseparator(var Args: array of TAsmData): TAsmData;
begin
  Result.s := System.IOUtils.TPath.PathSeparator;
end;

function s_changefileext(var Args: array of TAsmData): TAsmData;
begin
  Result.s := ChangeFileExt(Args[0].s, Args[1].s);
end;

function s_extractfileext(var Args: array of TAsmData): TAsmData;
begin
  Result.s := ExtractFileExt(Args[0].s);
end;

function s_extractfilename(var Args: array of TAsmData): TAsmData;
begin
  Result.s := ExtractFileName(Args[0].s);
end;

function s_extractfilepath(var Args: array of TAsmData): TAsmData;
begin
  Result.s := ExtractFilePath(Args[0].s);
end;

function n_alphacolor(var Args: array of TAsmData): TAsmData;
begin
  Result.n := StringToAlphaColor(args[0].s);
end;

function n_color(var Args: array of TAsmData): TAsmData;
begin
  Result.n := StringToColor(args[0].s);
end;

function s_colortostring(var Args: array of TAsmData): TAsmData;
begin
  Result.s := ColorToString(TColor(Trunc((Args[0].n))));
end;

procedure RegisterSysFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;
  FnData.Entry := n_paramcount;  Lib.Add('paramcount@', FnData);
  FnData.Entry := s_paramstr;  Lib.Add('paramstr$@n', FnData);
  FnData.Entry := n_chdir; Lib.Add('chdir@$', FnData);
  FnData.Entry := n_kill; Lib.Add('kill@$', FnData);
  FnData.Entry := n_fileexists; Lib.Add('fileexists@$n', FnData);
  FnData.Entry := s_changefileext; Lib.Add('changefileext$@$$', FnData);
  FnData.Entry := s_extractfileext; Lib.Add('extractfileext$@$', FnData);
  FnData.Entry := s_extractfilename; Lib.Add('extractfilename$@$', FnData);
  FnData.Entry := s_extractfilepath; Lib.Add('extractfilepath$@$', FnData);
  FnData.Entry := n_mkdir; Lib.Add('mkdir@$', FnData);
  FnData.Entry := n_forcedirectories; Lib.Add('forcedirectories@$', FnData);
  FnData.Entry := n_rmdir; Lib.Add('rmdir@$', FnData);
  FnData.Entry := s_environ; Lib.Add('environ$@$', FnData);
  FnData.Entry := s_getrandomfilename; Lib.Add('randomfilename$@', FnData);
  FnData.Entry := s_getguidfilename; Lib.Add('guidfilename$@n', FnData);
  FnData.Entry := s_gettempfilename; Lib.Add('tempfilename$@', FnData);
  FnData.Entry := s_gettemppath; Lib.Add('temppath$@', FnData);
  FnData.Entry := s_gethomepath; Lib.Add('homepath$@', FnData);
  FnData.Entry := s_getdocumentspath; Lib.Add('documentspath$@', FnData);
  FnData.Entry := s_getshareddocumentspath; Lib.Add('shareddocumentspath$@', FnData);
  FnData.Entry := s_getlibrarypath; Lib.Add('librarypath$@', FnData);
  FnData.Entry := s_getcachepath; Lib.Add('cachepath$@', FnData);
  FnData.Entry := s_getpublicpath; Lib.Add('publicpath$@', FnData);
  FnData.Entry := s_getpicturespath; Lib.Add('picturespath$@', FnData);
  FnData.Entry := s_getsharedpicturespath; Lib.Add('sharedpicturespath$@', FnData);
  FnData.Entry := s_getcamerapath; Lib.Add('camerapath$@', FnData);
  FnData.Entry := s_getsharedcamerapath; Lib.Add('sharedcamerapath$@', FnData);
  FnData.Entry := s_getmusicpath; Lib.Add('musicpath$@', FnData);
  FnData.Entry := s_getsharedmusicpath; Lib.Add('sharedmusicpath$@', FnData);
  FnData.Entry := s_getmoviespath; Lib.Add('moviespath$@', FnData);
  FnData.Entry := s_getsharedmoviespath; Lib.Add('sharedmoviespath$@', FnData);
  FnData.Entry := s_getalarmspath; Lib.Add('alarmspath$@', FnData);
  FnData.Entry := s_getsharedalarmspath; Lib.Add('sharedalarmspath$@', FnData);
  FnData.Entry := s_getdownloadspath; Lib.Add('downloadspath$@', FnData);
  FnData.Entry := s_getshareddownloadspath; Lib.Add('shareddownloadspath$@', FnData);
  FnData.Entry := s_getringtonespath; Lib.Add('ringtonespath$@', FnData);
  FnData.Entry := s_getsharedringtonespath; Lib.Add('sharedringtonespath$@', FnData);
  FnData.Entry := s_dirseparator; Lib.Add('dirseparator$@', FnData);
  FnData.Entry := s_altseparator; Lib.Add('altseparator$@', FnData);
  FnData.Entry := s_pathseparator; Lib.Add('pathseparator$@',FnData);
  FnData.Entry := n_alphacolor; Lib.Add('alphacolor@$',FnData);
  FnData.Entry := n_color; Lib.Add('color@$',FnData);
  FnData.Entry := s_colortostring; Lib.Add('colortostr$@n',FnData);
end;

end.
