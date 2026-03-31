' =============================================
' Plan9Basic - String Formatter Demo
' Demonstrates text formatting capabilities
' =============================================
PRINTLN "=========================================="
PRINTLN "       STRING FORMATTER DEMO"
PRINTLN "=========================================="
PRINTLN ""
PRINTLN "=== Formatted Table ==="
PRINTLN ""
PRINTLN "Name           Age   City"
PRINTLN "-------------- ----- --------------"
' Using rtab$ and ltab$ for alignment
name1$ = "Alice"
name2$ = "Bob"
name3$ = "Charlie"
name4$ = "Diana"
PRINTLN rtab$(name1$, 15); ltab$(str$(25), 6); "New York"
PRINTLN rtab$(name2$, 15); ltab$(str$(30), 6); "London"
PRINTLN rtab$(name3$, 15); ltab$(str$(35), 6); "Tokyo"
PRINTLN rtab$(name4$, 15); ltab$(str$(28), 6); "Paris"
PRINTLN ""
PRINTLN "=== Number Formatting ==="
PRINTLN ""
num = 42
PRINTLN "Number: "; num
PRINTLN "  Decimal: "; str$(num)
PRINTLN "  Hex: "; hex$(num)
PRINTLN "  Octal: "; oct$(num)
PRINTLN "  Binary: "; bin$(num)
PRINTLN ""
num = 255
PRINTLN "Number: "; num
PRINTLN "  Decimal: "; str$(num)
PRINTLN "  Hex: "; hex$(num)
PRINTLN "  Octal: "; oct$(num)
PRINTLN "  Binary: "; bin$(num)
PRINTLN ""
PRINTLN "=== Padding Examples ==="
PRINTLN ""
text$ = "Test"
PRINTLN "Original: ["; text$; "]"
PRINTLN "ltab$(10): ["; ltab$(text$, 10); "]"
PRINTLN "rtab$(10): ["; rtab$(text$, 10); "]"
PRINTLN "lfill$(10,'0'): ["; lfill$(text$, 10, 48); "]"
PRINTLN "rfill$(10,'-'): ["; rfill$(text$, 10, 45); "]"
PRINTLN ""
PRINTLN "=== String Multiplication ==="
PRINTLN ""
PRINTLN "mulstring$('=', 40):"
PRINTLN mulstring$("=", 40)
PRINTLN ""
PRINTLN "mulstring$('-*', 20):"
PRINTLN mulstring$("-*", 20)
PRINTLN ""
PRINTLN "=========================================="
