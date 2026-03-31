unit NumLib;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math,
  exec;

procedure RegisterNumFuncs(Lib: TFunctionsDictionary);

implementation

//----------------------------------------------------------
// Math library methods
//----------------------------------------------------------

function n_cint(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Trunc(Args[0].n);
end;

function n_abs(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Abs(Args[0].n);
end;

function n_ln(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Ln(Args[0].n);
end;

function n_tan(var Args: array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Tan(Args[0].n);
end;

function n_randomize(var Args: array of TAsmData): TAsmData;
begin
  Result.n := 1;
  Randomize();
end;

function n_rnd(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Random();
end;

function n_rnd1(var Args: array of TAsmData): TAsmData;
begin
  //Result.n := Random() * Args[0].n;
  Result.n := Random(Trunc(Args[0].n));
end;

function n_cos(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Cos(Args[0].n);
end;

function n_fix(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Int(Args[0].n);
end;

function n_sgn(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := 0;
  if Args[0].n > 0 then Result.n := 1
  else if Args[0].n < 0 then Result.n := -1;
end;

function n_sin(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Sin(Args[0].n);
end;

function n_int(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Int(Args[0].n);
  if Args[0].n < 0 then Result.n := Result.n - 1;
end;

function n_exp(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Exp(Args[0].n);
end;

function n_sqr(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Sqrt(Args[0].n);
end;

function n_log2(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Log2(Args[0].n);
end;

function n_frac(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Frac(Args[0].n);
end;

function n_atan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := ArcTan(Args[0].n);
end;

function n_acos(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.ArcCos(Args[0].n);
end;

function n_asin(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.ArcSin(Args[0].n);
end;

function n_tanh(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Tanh(Args[0].n);
end;

function n_cosh(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Cosh(Args[0].n);
end;

function n_sinh(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Sinh(Args[0].n);
end;

function n_log10(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Log10(Args[0].n);
end;

function n_max(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Max(Args[0].n, Args[1].n);
end;

function n_min(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.Min(Args[0].n, Args[1].n);
end;

function n_atanh(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.ArcTanh(Args[0].n);
end;

function n_acosh(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.ArcCosh(Args[0].n);
end;

function n_asinh(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.ArcSinh(Args[0].n);
end;

function n_round(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Round(Args[0].n);
end;

function n_degtorad(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.DegToRad(Args[0].n);
end;

function n_radtodeg(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.RadToDeg(Args[0].n);
end;

function n_atan2(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.ArcTan2(Args[0].n, Args[1].n);
end;

function n_comparevalue1(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.CompareValue(Args[0].n, Args[1].n);
end;

function n_comparevalue2(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := System.Math.CompareValue(Args[0].n, Args[1].n, Args[2].n);
end;

//------------------------------------------------------------------------------
//The method below register all math related functions to the BASIC engine.
//------------------------------------------------------------------------------
procedure RegisterNumFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;
  FnData.Entry := n_abs; Lib.Add('abs@n', FnData);
  FnData.Entry := n_acos; Lib.Add('acos@n', FnData);
  FnData.Entry := n_acosh; Lib.Add('acosh@n', FnData);
  FnData.Entry := n_asin; Lib.Add('asin@n', FnData);
  FnData.Entry := n_asinh; Lib.Add('asinh@n', FnData);
  FnData.Entry := n_atan; Lib.Add('atan@n', FnData);
  FnData.Entry := n_atan2; Lib.Add('atan2@nn', FnData);
  FnData.Entry := n_atanh; Lib.Add('atanh@n', FnData);
  FnData.Entry := n_cint; Lib.Add('cint@n', FnData);
  FnData.Entry := n_cos; Lib.Add('cos@n', FnData);
  FnData.Entry := n_cosh; Lib.Add('cosh@n', FnData);
  FnData.Entry := n_degtorad; Lib.Add('degtorad@n', FnData);
  FnData.Entry := n_exp; Lib.Add('exp@n', FnData);
  FnData.Entry := n_fix; Lib.Add('fix@n', FnData);
  FnData.Entry := n_frac; Lib.Add('frac@n', FnData);
  FnData.Entry := n_int; Lib.Add('int@n', FnData);
  FnData.Entry := n_ln; Lib.Add('ln@n', FnData);
  FnData.Entry := n_log2; Lib.Add('log2@n', FnData);
  FnData.Entry := n_log10; Lib.Add('log10@n', FnData);
  FnData.Entry := n_max; Lib.Add('max@nn', FnData);
  FnData.Entry := n_min; Lib.Add('min@nn', FnData);
  FnData.Entry := n_radtodeg; Lib.Add('radtodeg@n', FnData);
  FnData.Entry := n_randomize; Lib.Add('randomize@', FnData);
  FnData.Entry := n_rnd; Lib.Add('rnd@', FnData);
  FnData.Entry := n_rnd1; Lib.Add('rnd@n', FnData);
  FnData.Entry := n_round; Lib.Add('round@n', FnData);
  FnData.Entry := n_sin; Lib.Add('sin@n', FnData);
  FnData.Entry := n_sinh; Lib.Add('sinh@n', FnData);
  FnData.Entry := n_sqr; Lib.Add('sqr@n', FnData);
  FnData.Entry := n_sgn; Lib.Add('sgn@n', FnData);
  FnData.Entry := n_tan; Lib.Add('tan@n', FnData);
  FnData.Entry := n_tanh; Lib.Add('tanh@n', FnData);
  FnData.Entry := n_comparevalue1; Lib.Add('cmpval@nn', FnData);
  FnData.Entry := n_comparevalue2; Lib.Add('cmpval@nnn', FnData);
end;

end.
