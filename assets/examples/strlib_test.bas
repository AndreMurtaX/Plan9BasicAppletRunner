' =============================================
' Plan9Basic - StrLib Test
' Tests: String manipulation functions
' =============================================
PRINTLN "=== StrLib Function Tests ==="
PRINTLN ""
' Test case conversion
PRINTLN "--- Case Conversion ---"
text$ = "Hello World"
PRINTLN "Original: "; text$
PRINTLN "lcase$(): "; lcase$(text$)
PRINTLN "ucase$(): "; ucase$(text$)
PRINTLN ""
' Test trim
PRINTLN "--- Trim Functions ---"
padded$ = "   Trimmed   "
PRINTLN "Original: ["; padded$; "]"
PRINTLN "ltrim$(): ["; ltrim$(padded$); "]"
PRINTLN "rtrim$(): ["; rtrim$(padded$); "]"
PRINTLN ""
' Test substring
PRINTLN "--- Substring Functions ---"
text$ = "Plan9Basic"
PRINTLN "Original: "; text$
PRINTLN "left$(5): "; left$(text$, 5)
PRINTLN "right$(5): "; right$(text$, 5)
PRINTLN "mid$(5): "; mid$(text$, 5)
PRINTLN "mid$(5,4): "; mid$(text$, 5, 4)
PRINTLN ""
' Test character functions
PRINTLN "--- Character Functions ---"
PRINTLN "chr$(65) = "; chr$(65)
PRINTLN "chr$(66) = "; chr$(66)
PRINTLN "asc('A') = "; asc("A")
PRINTLN "len('Plan9Basic') = "; len("Plan9Basic")
PRINTLN ""
' Test number conversion
PRINTLN "--- Number Conversion ---"
num = 255
PRINTLN "Number: "; num
PRINTLN "hex$(): "; hex$(num)
PRINTLN "oct$(): "; oct$(num)
PRINTLN "bin$(): "; bin$(num)
PRINTLN "str$(): "; str$(num)
PRINTLN ""
' Test string to number
PRINTLN "val('3.14159') = "; val("3.14159")
PRINTLN ""
' Test search functions
PRINTLN "--- Search Functions ---"
text$ = "Plan9Basic Programming"
PRINTLN "Text: "; text$
PRINTLN "containsstr('Basic'): "; containsstr(text$, "Basic")
PRINTLN "containstext('basic'): "; containstext(text$, "basic")
PRINTLN "startsstr('Plan', text$): "; startsstr("Plan", text$)
PRINTLN "endsstr('ming', text$): "; endsstr("ming", text$)
PRINTLN ""
' Test manipulation
PRINTLN "--- String Manipulation ---"
text$ = "Hello World"
PRINTLN "reverse$(): "; reverse$(text$)
PRINTLN "replacestr$('World','Plan9'): "; replacestr$(text$, "World", "Plan9")
PRINTLN "mulstring$('Ha',3): "; mulstring$("Ha", 3)
PRINTLN ""
PRINTLN "=== StrLib Tests Complete ==="
