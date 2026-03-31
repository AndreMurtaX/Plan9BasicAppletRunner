' =============================================================================
' Plan9Basic Applet Runner - Base64Lib Example
' Demonstrates: Base64 encoding and decoding
' =============================================================================

PRINTLN "=== Base64Lib - Base64 Encode / Decode ==="
PRINTLN ""

' --- Basic encode / decode ---
PRINTLN "--- Basic Encode & Decode ---"
original$ = "Hello, Plan9Basic!"
encoded$  = b64encode$(original$)
decoded$  = b64decode$(encoded$)
PRINTLN "Original : "; original$
PRINTLN "Encoded  : "; encoded$
PRINTLN "Decoded  : "; decoded$
PRINTLN "Match    : "; (original$ = decoded$)
PRINTLN ""

' --- Encode various strings ---
PRINTLN "--- Encoding Examples ---"
PRINTLN "b64encode$(\"A\")          = "; b64encode$("A")
PRINTLN "b64encode$(\"AB\")         = "; b64encode$("AB")
PRINTLN "b64encode$(\"ABC\")        = "; b64encode$("ABC")
PRINTLN "b64encode$(\"Plan9Basic\") = "; b64encode$("Plan9Basic")
PRINTLN ""

' --- Padding handling ---
PRINTLN "--- Padding Verification ---"
FOR i = 1 TO 6
  s$ = left$("ABCDEF", i)
  PRINTLN "  \""; s$; "\" -> "; b64encode$(s$)
NEXT i
PRINTLN ""

' --- URL-safe variant ---
PRINTLN "--- URL-Safe Base64 ---"
data$ = "Hello+World/Base64=="
enc$  = b64urlencode$(data$)
dec$  = b64urldecode$(enc$)
PRINTLN "Original   : "; data$
PRINTLN "URL-encoded: "; enc$
PRINTLN "Decoded    : "; dec$
PRINTLN "Match      : "; (data$ = dec$)
PRINTLN ""

' --- Validation ---
PRINTLN "--- Validation ---"
PRINTLN "Is valid (\"SGVsbG8=\")   : "; b64isvalid$("SGVsbG8=")
PRINTLN "Is valid (\"not!base64\") : "; b64isvalid$("not!base64")
PRINTLN "Is valid (\"\")           : "; b64isvalid$("")
PRINTLN ""

' --- Round-trip with longer text ---
PRINTLN "--- Round-Trip with Longer Text ---"
longText$ = "Plan9Basic is a cross-platform BASIC interpreter built with Delphi/FMX."
enc$  = b64encode$(longText$)
dec$  = b64decode$(enc$)
PRINTLN "Original  : "; longText$
PRINTLN "Encoded   : "; enc$
PRINTLN "Decoded   : "; dec$
PRINTLN "Match     : "; (longText$ = dec$)
PRINTLN ""

PRINTLN "=== Base64Lib Example Complete ==="
