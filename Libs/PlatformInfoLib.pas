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
unit PlatformInfoLib;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.TypInfo,
  System.UIConsts, System.Classes,
  exec;

procedure RegisterPlatformInfoFuncs(Lib: TFunctionsDictionary);

implementation

//----------------------------------------------------------
// Platform info library methods
//----------------------------------------------------------

function s_platform(var Args: Array of TAsmData): TAsmData;
begin
  Result.s := TOSVersion.ToString();
end;

function s_architecture(var Args: Array of TAsmData): TAsmData;
begin
  Result.s := GetEnumName(TypeInfo(TOSVersion.TArchitecture), Integer(TOSVersion.Architecture)).Substring(2);
end;

function n_build(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := TOSVersion.Build;
end;

function n_major(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := TOSVersion.Major;
end;

function n_minor(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := TOSVersion.Minor;
end;

function n_check1(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(TOSVersion.Check(Trunc(Args[0].n), Trunc(Args[1].n)));
end;

function n_check2(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(TOSVersion.Check(Trunc(Args[0].n), Trunc(Args[1].n), Trunc(Args[2].n)));
end;

function s_name(var Args: Array of TAsmData): TAsmData;
begin
  Result.s := TOSVersion.Name;
end;

function n_spmajor(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := TOSVersion.ServicePackMajor;
end;

function n_spminor(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := TOSVersion.ServicePackMinor;
end;

//-----------------------------------------------------------------------------------
//The method below register all platform info related functions to the BASIC engine.
//-----------------------------------------------------------------------------------
procedure RegisterPlatformInfoFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;
  FnData.Entry := s_platform; Lib.Add('os_platform$@', FnData);
  FnData.Entry := s_architecture; Lib.Add('os_architecture$@', FnData);
  FnData.Entry := n_build; Lib.Add('os_build@', FnData);
  FnData.Entry := n_major; Lib.Add('os_major@', FnData);
  FnData.Entry := n_minor; Lib.Add('os_minor@', FnData);
  FnData.Entry := n_check1; Lib.Add('os_check@nn', FnData);
  FnData.Entry := n_check2; Lib.Add('os_check@nnn', FnData);
  FnData.Entry := s_name; Lib.Add('os_name$@', FnData);
  FnData.Entry := n_spmajor; Lib.Add('os_spmajor@', FnData);
  FnData.Entry := n_spminor; Lib.Add('os_spminor@', FnData);
end;

end.
