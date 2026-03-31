unit DateTimeLib;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.DateUtils,
  exec;

procedure RegisterDateTimeFuncs(Lib: TFunctionsDictionary);


implementation

uses
  UnitUtils;

function n_now(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Double(Now());
end;

function n_date(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Double(Date());
end;

function s_date(var Args: array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := DateToStr(Now(), fs);
end;

function n_time(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Double(Time());
end;

function s_time(var Args: array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := TimeToStr(Now(), fs);
end;

function n_gettime(var Args: array of TAsmData): TAsmData;
begin
  Result.n := Double(GetTime());
end;

function s_datetime(var Args: array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := DateTimeToStr(Now(), fs);
end;

function s_timetostr(var Args: array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := TimeToStr(TDateTime(Args[0].n), fs);
end;

function n_strtotime(var Args: array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.n := StrToTime(Args[0].s);
end;

function s_datetimetostr(var Args: Array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := DateTimeToStr(TDateTime(Args[0].n), fs);
end;

function n_strtodatetime(var Args: Array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.n := StrToDateTime(Args[0].s, fs);
end;

function s_datetostr(var Args: Array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := DateToStr(TDateTime(Args[0].n), fs);
end;

function n_strtodate(var Args: Array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.n := StrToDate(Args[0].s, fs);
end;

function n_dayofweek(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DayOfWeek(TDateTime(Args[0].n));
end;

function n_dayoftheweek(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DayOfTheWeek(TDateTime(Args[0].n));
end;

function n_dayof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DayOf(TDateTime(Args[0].n));
end;

function n_dayofthemonth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DayOfTheMonth(TDateTime(Args[0].n));
end;

function n_dayoftheyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DayOfTheYear(TDateTime(Args[0].n));
end;

function n_daysbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DaysBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_daysinamonth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DaysInAMonth(Word(Trunc(Args[0].n)), Word(Trunc(Args[1].n)));
end;

function n_daysinayear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DaysInAYear(Word(Trunc(Args[0].n)));
end;

function n_daysinmonth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DaysInMonth(TDateTime(Args[0].n));
end;

function n_daysinyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DaysInYear(TDateTime(Args[0].n));
end;

function n_hourof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := HourOf(TDateTime(Args[0].n));
end;

function n_dayspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := DaySpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_hoursbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := HoursBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_hourspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := HourSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_millisecondof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MillisecondOf(TDateTime(Args[0].n));
end;

function n_millisecondsbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MillisecondsBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_millisecondspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MillisecondSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_minuteof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MinuteOf(TDateTime(Args[0].n));
end;

function n_minutesbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MinutesBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_minutespan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MinuteSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_secondof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := SecondOf(TDateTime(Args[0].n));
end;

function n_secondsbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := SecondsBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_secondspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := SecondSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_monthof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MonthOf(TDateTime(Args[0].n));
end;

function n_monthoftheyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MonthOfTheYear(TDateTime(Args[0].n));
end;

function n_monthsbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MonthsBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_monthspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := MonthSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_incday(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncDay(TDateTime(Args[0].n), Integer(Trunc(Args[1].n)));
end;

function n_inchour(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncHour(TDateTime(Args[0].n), Int64(Trunc(Args[1].n)));
end;

function n_incmillisecond(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncMillisecond(TDateTime(Args[0].n), Int64(Trunc(Args[1].n)));
end;

function n_incminute(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncMinute(TDateTime(Args[0].n), Int64(Trunc(Args[1].n)));
end;

function n_incsecond(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncSecond(TDateTime(Args[0].n), Int64(Trunc(Args[1].n)));
end;

function n_incweek(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncWeek(TDateTime(Args[0].n), Int64(Trunc(Args[1].n)));
end;

function n_incyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := IncYear(TDateTime(Args[0].n), Int64(Trunc(Args[1].n)));
end;

function n_isam(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(IsAM(TDateTime(Args[0].n)));
end;

function n_isinleapyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(IsInLeapYear(TDateTime(Args[0].n)));
end;

function n_ispm(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(IsPM(TDateTime(Args[0].n)));
end;

function n_issameday(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(IsSameDay(TDateTime(Args[0].n), TDateTime(Args[1].n)));
end;

function n_istoday(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Ord(IsToDay(TDateTime(Args[0].n)));
end;

function n_weekof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeekOf(TDateTime(Args[0].n));
end;

function n_weekofthemonth(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeekOfTheMonth(TDateTime(Args[0].n));
end;

function n_weekoftheyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeekOfTheYear(TDateTime(Args[0].n));
end;

function n_weeksbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeeksBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_weeksinayear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeeksInAYear(Word(Trunc(Args[0].n)));
end;

function n_weeksinyear(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeeksInYear(TDateTime(Args[0].n));
end;

function n_weekspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := WeekSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_yearof(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := YearOf(TDateTime(Args[0].n));
end;

function n_yearsbetween(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := YearsBetween(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_yearspan(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := YearSpan(TDateTime(Args[0].n), TDateTime(Args[1].n));
end;

function n_yesterday(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Yesterday();
end;

function n_today(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Today();
end;

function n_tomorrow(var Args: Array of TAsmData): TAsmData;
begin
  Result.n := Tomorrow();
end;

function s_formatdatetime(var Args: Array of TAsmData): TAsmData;
var
  fs: TFormatSettings;
begin
  fs := TFormatSettings.Create();
  fs.DateSeparator := '-';
  fs.ShortDateFormat := 'yyyy-MM-dd';
  fs.TimeSeparator := ':';
  fs.ShortTimeFormat := 'hh:mm';
  fs.LongTimeFormat := 'hh:mm:ss.zzz';
  Result.s := FormatDateTime(Args[0].s, TDateTime(Args[1].n), fs);
end;

procedure RegisterDateTimeFuncs(Lib: TFunctionsDictionary);
var
  FnData: TLinkFunction;
begin
  FnData.FarCall := True;
  FnData.Entry := n_now; Lib.Add('now@', FnData);
  FnData.Entry := n_date; Lib.Add('date@', FnData);
  FnData.Entry := s_date; Lib.Add('date$@', FnData);
  FnData.Entry := n_time; Lib.Add('time@', FnData);
  FnData.Entry := s_time; Lib.Add('time$@', FnData);
  FnData.Entry := n_gettime; Lib.Add('gettime@', FnData);
  FnData.Entry := s_datetime; Lib.Add('datetime$@', FnData);
  FnData.Entry := s_timetostr; Lib.Add('timetostr$@n', FnData);
  FnData.Entry := n_strtotime; Lib.Add('strtotime@$', FnData);
  FnData.Entry := s_datetimetostr; Lib.Add('datetimetostr$@n', FnData);
  FnData.Entry := n_strtodatetime; Lib.Add('strtodatetime@$',FnData);
  FnData.Entry := s_datetostr; Lib.Add('datetostr$@n', FnData);
  FnData.Entry := n_strtodate; Lib.Add('strtodate@$', FnData);
  FnData.Entry := n_dayofweek; Lib.Add('dayofweek@n', FnData);
  FnData.Entry := n_dayoftheweek; Lib.Add('dayoftheweek@n', FnData);
  FnData.Entry := n_dayof; Lib.Add('dayof@n', FnData);
  FnData.Entry := n_dayofthemonth; Lib.Add('dayofthemonth@n',FnData);
  FnData.Entry := n_dayoftheyear; Lib.Add('dayoftheyear@n', FnData);
  FnData.Entry := n_daysbetween; Lib.Add('daysbetween@nn', FnData);
  FnData.Entry := n_daysinamonth; Lib.Add('daysinamonth@nn', FnData);
  FnData.Entry := n_daysinayear; Lib.Add('daysinayear@n', FnData);
  FnData.Entry := n_daysinmonth; Lib.Add('daysinmonth@n', FnData);
  FnData.Entry := n_daysinyear; Lib.Add('daysinyear@n', FnData);
  FnData.Entry := n_dayspan; Lib.Add('dayspan@nn', FnData);
  FnData.Entry := n_hourof; Lib.Add('hourof@n', FnData);
  FnData.Entry := n_hoursbetween; Lib.Add('hoursbetween@nn', FnData);
  FnData.Entry := n_hourspan; Lib.Add('hourspan@nn', FnData);
  FnData.Entry := n_millisecondof; Lib.Add('millisecondof@n',FnData);
  FnData.Entry := n_millisecondsbetween; Lib.Add('millisecondsbetween@nn', FnData);
  FnData.Entry := n_millisecondspan; Lib.Add('millisecondspan@nn', FnData);
  FnData.Entry := n_minuteof; Lib.Add('minuteof@n', FnData);
  FnData.Entry := n_minutesbetween; Lib.Add('minutesbetween@nn', FnData);
  FnData.Entry := n_minutespan; Lib.Add('minutespan@nn', FnData);
  FnData.Entry := n_secondof; Lib.Add('secondof@n', FnData);
  FnData.Entry := n_secondsbetween; Lib.Add('secondsbetween@nn', FnData);
  FnData.Entry := n_secondspan; Lib.Add('secondspan@nn', FnData);
  FnData.Entry := n_monthof; Lib.Add('monthof@n', FnData);
  FnData.Entry := n_monthoftheyear; Lib.Add('monthoftheyear@n', FnData);
  FnData.Entry := n_monthsbetween; Lib.Add('monthsbetween@nn', FnData);
  FnData.Entry := n_monthspan; Lib.Add('monthspan@nn', FnData);
  FnData.Entry := n_incday; Lib.Add('incday@nn', FnData);
  FnData.Entry := n_inchour; Lib.Add('inchour@nn', FnData);
  FnData.Entry := n_incmillisecond; Lib.Add('incmillisecond@nn', FnData);
  FnData.Entry := n_incminute; Lib.Add('incminute@nn', FnData);
  FnData.Entry := n_incsecond; Lib.Add('incsecond@nn', FnData);
  FnData.Entry := n_incweek; Lib.Add('incweek@nn', Fndata);
  FnData.Entry := n_incyear; Lib.Add('incyear@nn', FnData);
  FnData.Entry := n_isam; Lib.Add('isam@n', FnData);
  FnData.Entry := n_isinleapyear; Lib.Add('isinleapyear@n', FnData);
  FnData.Entry := n_ispm; Lib.Add('ispm@n', FnData);
  FnData.Entry := n_issameday; Lib.Add('issameday@nn', FnData);
  FnData.Entry := n_istoday; Lib.Add('istoday@n', FnData);
  FnData.Entry := n_weekof; Lib.Add('weekof@n', FnData);
  FnData.Entry := n_weekofthemonth; Lib.Add('weekofthemonth@n', FnData);
  FnData.Entry := n_weekoftheyear; Lib.Add('weekoftheyear@n',FnData);
  FnData.Entry := n_weeksbetween; Lib.Add('weeksbetween@nn', FnData);
  FnData.Entry := n_weeksinayear; Lib.Add('weeksinayear@n', FnData);
  FnData.Entry := n_weeksinyear; Lib.Add('weeksinyear@n', FnData);
  FnData.Entry := n_weekspan; Lib.Add('weekspan@nn', FnData);
  FnData.Entry := n_yearof; Lib.Add('yearof@n', FnData);
  FnData.Entry := n_yearsbetween; Lib.Add('yearsbetween@nn', FnData);
  FnData.Entry := n_yearspan; Lib.Add('yearspan@nn', FnData);
  FnData.Entry := n_yesterday; Lib.Add('yesterday@', FnData);
  FnData.Entry := n_today; Lib.Add('today@', FnData);
  FnData.Entry := n_tomorrow; Lib.Add('tomorrow@', FnData);
  FnData.Entry := s_formatdatetime; Lib.Add('formatdatetime$@$n', FnData);
end;

end.
