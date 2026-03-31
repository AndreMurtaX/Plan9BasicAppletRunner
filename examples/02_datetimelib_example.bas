' =============================================================================
' Plan9Basic Applet Runner - DateTimeLib Example
' Demonstrates: Date and time operations
' =============================================================================

PRINTLN "=== DateTimeLib - Date & Time Library ==="
PRINTLN ""

' --- Current date and time ---
PRINTLN "--- Current Date & Time ---"
PRINTLN "date$()     = "; date$()
PRINTLN "time$()     = "; time$()
PRINTLN "datetime$() = "; datetime$()
PRINTLN ""

' --- Date components ---
PRINTLN "--- Date Components ---"
dt = now()
PRINTLN "Year    : "; yearof(dt)
PRINTLN "Month   : "; monthof(dt)
PRINTLN "Day     : "; dayof(dt)
PRINTLN "Hour    : "; hourof(dt)
PRINTLN "Minute  : "; minuteof(dt)
PRINTLN ""

' --- Day information ---
PRINTLN "--- Day Information ---"
PRINTLN "Day of week (1=Sun) : "; dayofweek(dt)
PRINTLN "Day of year         : "; dayoftheyear(dt)
PRINTLN "Week of year        : "; weekoftheyear(dt)
PRINTLN ""

' --- Yesterday / Today / Tomorrow ---
PRINTLN "--- Relative Days ---"
PRINTLN "Yesterday : "; datetostr$(yesterday())
PRINTLN "Today     : "; datetostr$(today())
PRINTLN "Tomorrow  : "; datetostr$(tomorrow())
PRINTLN ""

' --- Date arithmetic ---
PRINTLN "--- Date Arithmetic ---"
d = today()
PRINTLN "Today          : "; datetostr$(d)
PRINTLN "In 10 days     : "; datetostr$(incday(d, 10))
PRINTLN "In 3 months    : "; datetostr$(incday(d, 90))
PRINTLN "10 days ago    : "; datetostr$(incday(d, -10))
PRINTLN "In 1 year      : "; datetostr$(incyear(d, 1))
PRINTLN ""

' --- Time arithmetic ---
PRINTLN "--- Time Arithmetic ---"
t = now()
PRINTLN "Now           : "; datetimetostr$(t)
PRINTLN "In 2 hours    : "; datetimetostr$(inchour(t, 2))
PRINTLN "In 45 minutes : "; datetimetostr$(incminute(t, 45))
PRINTLN ""

' --- Date differences ---
PRINTLN "--- Date Differences ---"
d1 = strtodate("2025-01-01")
d2 = strtodate("2025-12-31")
PRINTLN "From : "; datetostr$(d1)
PRINTLN "To   : "; datetostr$(d2)
PRINTLN "Days between   : "; daysbetween(d1, d2)
PRINTLN "Weeks between  : "; weeksbetween(d1, d2)
PRINTLN "Months between : "; monthsbetween(d1, d2)
PRINTLN ""

' --- Formatting ---
PRINTLN "--- Custom Formatting ---"
dt = now()
PRINTLN "yyyy-mm-dd    : "; formatdatetime$("yyyy-mm-dd", dt)
PRINTLN "dd/mm/yyyy    : "; formatdatetime$("dd/mm/yyyy", dt)
PRINTLN "hh:nn:ss      : "; formatdatetime$("hh:nn:ss", dt)
PRINTLN ""

' --- Checks ---
PRINTLN "--- Date Checks ---"
PRINTLN "Is leap year 2024 : "; isinleapyear(strtodate("2024-06-15"))
PRINTLN "Is leap year 2025 : "; isinleapyear(strtodate("2025-06-15"))
PRINTLN "Days in Feb 2024  : "; daysinamonth(2024, 2)
PRINTLN "Days in Feb 2025  : "; daysinamonth(2025, 2)
PRINTLN ""

PRINTLN "=== DateTimeLib Example Complete ==="
