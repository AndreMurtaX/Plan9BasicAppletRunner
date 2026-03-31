' =============================================
' Plan9Basic - StdLib Test
' Tests: pause, sign, format settings
' =============================================
PRINTLN "=== StdLib Function Tests ==="
PRINTLN ""
' Test pause
PRINTLN "Testing pause(1)... wait 1 second"
pause(1)
PRINTLN "Done!"
PRINTLN ""
' Test sign function
PRINTLN "--- Sign Function ---"
PRINTLN "sign(-100) = "; sign(-100)
PRINTLN "sign(0) = "; sign(0)
PRINTLN "sign(100) = "; sign(100)
PRINTLN ""
' Test format settings
PRINTLN "--- Format Settings ---"
PRINTLN "Decimal separator: "; formatsettings$("decimalseparator")
PRINTLN "Date separator: "; formatsettings$("dateseparator")
PRINTLN "Short date format: "; formatsettings$("shortdateformat")
PRINTLN ""
PRINTLN "=== StdLib Tests Complete ==="
