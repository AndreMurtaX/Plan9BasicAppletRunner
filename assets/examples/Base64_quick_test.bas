' ============================================================================
' Base64 Quick Sanity Test
' ============================================================================
' A fast test to verify basic functionality works.
' Run this first before the comprehensive test suite.
' ============================================================================
PRINTLN "=== Base64 Quick Sanity Test ==="
PRINTLN ""
' Test 1: Basic encode/decode round-trip
PRINTLN "Test 1: Basic round-trip"
original$ = "Hello, Plan9Basic!"
encoded$ = b64encode$(original$)
decoded$ = b64decode$(encoded$)
PRINTLN "  Original: "; original$
PRINTLN "  Encoded:  "; encoded$
PRINTLN "  Decoded:  "; decoded$
IF decoded$ = original$ THEN
  PRINTLN "  Result:   PASS"
ELSE
  PRINTLN "  Result:   FAIL"
END IF
PRINTLN ""
' Test 2: Known value test (RFC 4648)
PRINTLN "Test 2: Known value (RFC 4648)"
testVal$ = b64encode$("foobar")
expected$ = "Zm9vYmFy"
PRINTLN "  Input:    'foobar'"
PRINTLN "  Expected: "; expected$
PRINTLN "  Got:      "; testVal$
IF testVal$ = expected$ THEN
  PRINTLN "  Result:   PASS"
ELSE
  PRINTLN "  Result:   FAIL"
END IF
PRINTLN ""
' Test 3: Validation
PRINTLN "Test 3: Validation function"
validTest$ = "SGVsbG8="
invalidTest$ = "Invalid!!!"
v1 = b64valid(validTest$)
v2 = b64valid(invalidTest$)
PRINTLN "  Valid string test:   "; v1; " (expected 1)"
PRINTLN "  Invalid string test: "; v2; " (expected 0)"
IF v1 = 1 THEN
  IF v2 = 0 THEN
    PRINTLN "  Result:   PASS"
  ELSE
    PRINTLN "  Result:   FAIL (invalid not detected)"
  END IF
ELSE
  PRINTLN "  Result:   FAIL (valid not recognized)"
END IF
PRINTLN ""
' Test 4: URL-safe encoding
PRINTLN "Test 4: URL-safe encoding"
urlOrig$ = "test@example.com"
urlEnc$ = b64urlencode$(urlOrig$)
urlDec$ = b64urldecode$(urlEnc$)
PRINTLN "  Original: "; urlOrig$
PRINTLN "  Encoded:  "; urlEnc$
PRINTLN "  Decoded:  "; urlDec$
IF urlDec$ = urlOrig$ THEN
  PRINTLN "  Result:   PASS"
ELSE
  PRINTLN "  Result:   FAIL"
END IF
PRINTLN ""
' Test 5: Error handling
PRINTLN "Test 5: Error handling"
dummy$ = b64decode$("!!NotValid!!")
errCode = b64error()
PRINTLN "  Decoded invalid BASE64"
PRINTLN "  Error code: "; errCode; " (expected non-zero)"
IF errCode <> 0 THEN
  PRINTLN "  Result:   PASS"
ELSE
  PRINTLN "  Result:   FAIL"
END IF
PRINTLN ""
' Test 6: Empty string handling
PRINTLN "Test 6: Empty string handling"
emptyEnc$ = b64encode$("")
emptyDec$ = b64decode$("")
PRINTLN "  Encode '': '"; emptyEnc$; "'"
PRINTLN "  Decode '': '"; emptyDec$; "'"
IF emptyEnc$ = "" THEN
  IF emptyDec$ = "" THEN
    PRINTLN "  Result:   PASS"
  ELSE
    PRINTLN "  Result:   FAIL (decode)"
  END IF
ELSE
  PRINTLN "  Result:   FAIL (encode)"
END IF
PRINTLN ""
PRINTLN "=== Quick Sanity Test Complete ==="
