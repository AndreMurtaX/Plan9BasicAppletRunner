' =============================================
' Plan9Basic - DateTimeLib Test
' Tests: Date and time functions
' =============================================
PRINTLN "=== DateTimeLib Function Tests ==="
PRINTLN ""
' Current date/time
PRINTLN "--- Current Date/Time ---"
PRINTLN "now() = "; now()
PRINTLN "date() = "; date()
PRINTLN "time() = "; time()
PRINTLN "date$() = "; date$()
PRINTLN "time$() = "; time$()
PRINTLN "datetime$() = "; datetime$()
PRINTLN ""
' Date components
PRINTLN "--- Date Components ---"
dt = now()
PRINTLN "Current: "; datetimetostr$(dt)
PRINTLN "Year: "; yearof(dt)
PRINTLN "Month: "; monthof(dt)
PRINTLN "Day: "; dayof(dt)
PRINTLN "Hour: "; hourof(dt)
PRINTLN "Minute: "; minuteof(dt)
PRINTLN "Millisecond: "; millisecondof(dt)
PRINTLN ""
' Day of week
PRINTLN "--- Day of Week ---"
PRINTLN "dayofweek() (1=Sun): "; dayofweek(dt)
PRINTLN "dayoftheweek() (1=Mon, ISO): "; dayoftheweek(dt)
PRINTLN "dayoftheyear(): "; dayoftheyear(dt)
PRINTLN ""
' Week info
PRINTLN "--- Week Information ---"
PRINTLN "weekof(): "; weekof(dt)
PRINTLN "weekofthemonth(): "; weekofthemonth(dt)
PRINTLN "weekoftheyear(): "; weekoftheyear(dt)
PRINTLN ""
' Special days
PRINTLN "--- Special Days ---"
PRINTLN "Yesterday: "; datetostr$(yesterday())
PRINTLN "Today: "; datetostr$(today())
PRINTLN "Tomorrow: "; datetostr$(tomorrow())
PRINTLN ""
' Date arithmetic
PRINTLN "--- Date Arithmetic ---"
dt = today()
PRINTLN "Today: "; datetostr$(dt)
PRINTLN "In 7 days: "; datetostr$(incday(dt, 7))
PRINTLN "In 1 month: "; datetostr$(incday(dt, 30))
PRINTLN "In 1 year: "; datetostr$(incyear(dt, 1))
PRINTLN "5 days ago: "; datetostr$(incday(dt, -5))
PRINTLN ""
' Time arithmetic
PRINTLN "--- Time Arithmetic ---"
dt = now()
PRINTLN "Now: "; datetimetostr$(dt)
PRINTLN "In 2 hours: "; datetimetostr$(inchour(dt, 2))
PRINTLN "In 30 minutes: "; datetimetostr$(incminute(dt, 30))
PRINTLN ""
' Date differences
PRINTLN "--- Date Differences ---"
dt1 = strtodate("2024-01-01")
dt2 = strtodate("2024-12-31")
PRINTLN "Date 1: "; datetostr$(dt1)
PRINTLN "Date 2: "; datetostr$(dt2)
PRINTLN "Days between: "; daysbetween(dt1, dt2)
PRINTLN "Weeks between: "; weeksbetween(dt1, dt2)
PRINTLN "Months between: "; monthsbetween(dt1, dt2)
PRINTLN ""
' Time checks
PRINTLN "--- Time Checks ---"
dt = now()
PRINTLN "Is AM: "; isam(dt)
PRINTLN "Is PM: "; ispm(dt)
PRINTLN "Is Today: "; istoday(dt)
PRINTLN "Is Leap Year: "; isinleapyear(dt)
PRINTLN ""
' Days in month/year
PRINTLN "--- Days Count ---"
PRINTLN "Days in Feb 2024 (leap): "; daysinamonth(2024, 2)
PRINTLN "Days in Feb 2025: "; daysinamonth(2025, 2)
PRINTLN "Days in 2024: "; daysinayear(2024)
PRINTLN "Days in 2025: "; daysinayear(2025)
PRINTLN ""
' Format datetime
PRINTLN "--- Format DateTime ---"
dt = now()
PRINTLN "yyyy-mm-dd: "; formatdatetime$("yyyy-mm-dd", dt)
PRINTLN "dd/mm/yyyy: "; formatdatetime$("dd/mm/yyyy", dt)
PRINTLN "hh:nn:ss: "; formatdatetime$("hh:nn:ss", dt)
PRINTLN ""
PRINTLN "=== DateTimeLib Tests Complete ==="
