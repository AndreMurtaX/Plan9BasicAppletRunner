' ============================================================================
' Base64 Test Suite for Plan9Basic
' ============================================================================
' This file contains comprehensive tests for all Base64 functions.
' Run each test section and verify the expected output matches.
' ============================================================================
PRINTLN "========================================"
PRINTLN "  Base64 Test Suite"
PRINTLN "========================================"
PRINTLN
' Track test results
LET totalTests = 0
LET passedTests = 0
LET dummy = 0
' ----------------------------------------------------------------------------
' Helper function to report test results
' ----------------------------------------------------------------------------
FUNCTION reportTest(testName$, passed)
  totalTests = totalTests + 1
  IF passed = 1 THEN
    passedTests = passedTests + 1
    PRINTLN "[PASS] "; testName$
  ELSE
    PRINTLN "[FAIL] "; testName$
  END IF
END FUNCTION
' ============================================================================
' TEST SECTION 1: b64encode$() - Basic Encoding
' ============================================================================
PRINTLN ""
PRINTLN "--- TEST SECTION 1: b64encode$() ---"
PRINTLN
' Test 1.1: Simple ASCII string
test1$ = "Hello"
result1$ = b64encode$(test1$)
expected1$ = "SGVsbG8="
passed = 0
IF result1$ = expected1$ THEN
  passed = 1
END IF
dummy = reportTest("1.1 Encode 'Hello'", passed)
' Test 1.2: String with spaces
test2$ = "Hello, World!"
result2$ = b64encode$(test2$)
expected2$ = "SGVsbG8sIFdvcmxkIQ=="
passed = 0
IF result2$ = expected2$ THEN
  passed = 1
END IF
dummy = reportTest("1.2 Encode 'Hello, World!'", passed)
' Test 1.3: Empty string
test3$ = ""
result3$ = b64encode$(test3$)
expected3$ = ""
passed = 0
IF result3$ = expected3$ THEN
  passed = 1
END IF
dummy = reportTest("1.3 Encode empty string", passed)
' Test 1.4: Single character
test4$ = "A"
result4$ = b64encode$(test4$)
expected4$ = "QQ=="
passed = 0
IF result4$ = expected4$ THEN
  passed = 1
END IF
dummy = reportTest("1.4 Encode single char 'A'", passed)
' Test 1.5: Two characters (different padding)
test5$ = "AB"
result5$ = b64encode$(test5$)
expected5$ = "QUI="
passed = 0
IF result5$ = expected5$ THEN
  passed = 1
END IF
dummy = reportTest("1.5 Encode 'AB' (1 padding)", passed)
' Test 1.6: Three characters (no padding)
test6$ = "ABC"
result6$ = b64encode$(test6$)
expected6$ = "QUJD"
passed = 0
IF result6$ = expected6$ THEN
  passed = 1
END IF
dummy = reportTest("1.6 Encode 'ABC' (no padding)", passed)
' Test 1.7: Numbers as string
test7$ = "12345"
result7$ = b64encode$(test7$)
expected7$ = "MTIzNDU="
passed = 0
IF result7$ = expected7$ THEN
  passed = 1
END IF
dummy = reportTest("1.7 Encode '12345'", passed)
' Test 1.8: Special characters
test8$ = "!@#$%"
result8$ = b64encode$(test8$)
expected8$ = "IUAjJCU="
passed = 0
IF result8$ = expected8$ THEN
  passed = 1
END IF
dummy = reportTest("1.8 Encode special chars '!@#$%'", passed)
' ============================================================================
' TEST SECTION 2: b64decode$() - Basic Decoding
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 2: b64decode$() ---"
PRINTLN
' Test 2.1: Simple decode
enc1$ = "SGVsbG8="
dec1$ = b64decode$(enc1$)
passed = 0
IF dec1$ = "Hello" THEN
  passed = 1
END IF
dummy = reportTest("2.1 Decode to 'Hello'", passed)
' Test 2.2: Decode with spaces in result
enc2$ = "SGVsbG8sIFdvcmxkIQ=="
dec2$ = b64decode$(enc2$)
passed = 0
IF dec2$ = "Hello, World!" THEN
  passed = 1
END IF
dummy = reportTest("2.2 Decode to 'Hello, World!'", passed)
' Test 2.3: Empty string decode
enc3$ = ""
dec3$ = b64decode$(enc3$)
passed = 0
IF dec3$ = "" THEN
  passed = 1
END IF
dummy = reportTest("2.3 Decode empty string", passed)
' Test 2.4: Single padded char
enc4$ = "QQ=="
dec4$ = b64decode$(enc4$)
passed = 0
IF dec4$ = "A" THEN
  passed = 1
END IF
dummy = reportTest("2.4 Decode 'QQ==' to 'A'", passed)
' Test 2.5: No padding decode
enc5$ = "QUJD"
dec5$ = b64decode$(enc5$)
passed = 0
IF dec5$ = "ABC" THEN
  passed = 1
END IF
dummy = reportTest("2.5 Decode 'QUJD' to 'ABC'", passed)
' ============================================================================
' TEST SECTION 3: Round-Trip Tests (encode then decode)
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 3: Round-Trip Tests ---"
PRINTLN
' Test 3.1: Simple round-trip
orig1$ = "Plan9Basic"
rt1$ = b64decode$(b64encode$(orig1$))
passed = 0
IF rt1$ = orig1$ THEN
  passed = 1
END IF
dummy = reportTest("3.1 Round-trip 'Plan9Basic'", passed)
' Test 3.2: Long string round-trip
orig2$ = "The quick brown fox jumps over the lazy dog"
rt2$ = b64decode$(b64encode$(orig2$))
passed = 0
IF rt2$ = orig2$ THEN
  passed = 1
END IF
dummy = reportTest("3.2 Round-trip long string", passed)
' Test 3.3: String with newlines
orig3$ = "Line1" + chr$(10) + "Line2" + chr$(10) + "Line3"
rt3$ = b64decode$(b64encode$(orig3$))
passed = 0
IF rt3$ = orig3$ THEN
  passed = 1
END IF
dummy = reportTest("3.3 Round-trip with newlines", passed)
' Test 3.4: String with tabs
orig4$ = "Col1" + chr$(9) + "Col2" + chr$(9) + "Col3"
rt4$ = b64decode$(b64encode$(orig4$))
passed = 0
IF rt4$ = orig4$ THEN
  passed = 1
END IF
dummy = reportTest("3.4 Round-trip with tabs", passed)
' Test 3.5: Mixed content
orig5$ = "Name: Test" + chr$(13) + chr$(10) + "Value: 123!@#"
rt5$ = b64decode$(b64encode$(orig5$))
passed = 0
IF rt5$ = orig5$ THEN
  passed = 1
END IF
dummy = reportTest("3.5 Round-trip mixed content", passed)
' ============================================================================
' TEST SECTION 4: b64valid() - Validation
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 4: b64valid() ---"
PRINTLN
' Test 4.1: Valid BASE64 (no padding)
passed = 0
IF b64valid("QUJD") = 1 THEN
  passed = 1
END IF
dummy = reportTest("4.1 Valid 'QUJD' (no padding)", passed)
' Test 4.2: Valid BASE64 (with padding)
passed = 0
IF b64valid("QQ==") = 1 THEN
  passed = 1
END IF
dummy = reportTest("4.2 Valid 'QQ==' (2 padding)", passed)
' Test 4.3: Valid BASE64 (1 padding)
passed = 0
IF b64valid("QUI=") = 1 THEN
  passed = 1
END IF
dummy = reportTest("4.3 Valid 'QUI=' (1 padding)", passed)
' Test 4.4: Empty string is valid
passed = 0
IF b64valid("") = 1 THEN
  passed = 1
END IF
dummy = reportTest("4.4 Empty string is valid", passed)
' Test 4.5: Invalid - wrong characters
passed = 0
IF b64valid("ABC!") = 0 THEN
  passed = 1
END IF
dummy = reportTest("4.5 Invalid 'ABC!' (bad char)", passed)
' Test 4.6: Invalid - wrong length
passed = 0
IF b64valid("ABC") = 0 THEN
  passed = 1
END IF
dummy = reportTest("4.6 Invalid 'ABC' (wrong length)", passed)
' Test 4.7: Invalid - padding in wrong place
passed = 0
IF b64valid("A=BC") = 0 THEN
  passed = 1
END IF
dummy = reportTest("4.7 Invalid 'A=BC' (bad padding)", passed)
' Test 4.8: Valid long string
passed = 0
IF b64valid("SGVsbG8sIFdvcmxkIQ==") = 1 THEN
  passed = 1
END IF
dummy = reportTest("4.8 Valid long BASE64", passed)
' Test 4.9: Invalid - spaces not allowed
passed = 0
IF b64valid("QUI =") = 0 THEN
  passed = 1
END IF
dummy = reportTest("4.9 Invalid with space", passed)
' ============================================================================
' TEST SECTION 5: b64urlencode$() - URL-Safe Encoding
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 5: b64urlencode$() ---"
PRINTLN
' Test 5.1: Simple URL encode
urlTest1$ = "Hello"
urlEnc1$ = b64urlencode$(urlTest1$)
' Should not contain +, /, or =
passed = 1
IF instr(urlEnc1$, "+") > 0 THEN
  passed = 0
END IF
IF instr(urlEnc1$, "/") > 0 THEN
  passed = 0
END IF
IF instr(urlEnc1$, "=") > 0 THEN
  passed = 0
END IF
dummy = reportTest("5.1 URL encode has no +/=/", passed)
' Test 5.2: String that would produce + in standard BASE64
' Character sequence that produces + : ">?"
urlTest2$ = ">?"
urlEnc2$ = b64urlencode$(urlTest2$)
passed = 1
IF instr(urlEnc2$, "+") > 0 THEN
  passed = 0
END IF
dummy = reportTest("5.2 URL encode converts + to -", passed)
' Test 5.3: Empty string
urlEnc3$ = b64urlencode$("")
passed = 0
IF urlEnc3$ = "" THEN
  passed = 1
END IF
dummy = reportTest("5.3 URL encode empty string", passed)
' Test 5.4: Verify different from standard
stdEnc$ = b64encode$("Hello")
urlEnc$ = b64urlencode$("Hello")
' URL version should have no padding
passed = 0
IF instr(stdEnc$, "=") > 0 THEN
  IF instr(urlEnc$, "=") = 0 THEN
    passed = 1
  END IF
ELSE
  passed = 1
END IF
dummy = reportTest("5.4 URL encode removes padding", passed)
' ============================================================================
' TEST SECTION 6: b64urldecode$() - URL-Safe Decoding
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 6: b64urldecode$() ---"
PRINTLN
' Test 6.1: Decode URL-safe string
urlDec1$ = b64urldecode$("SGVsbG8")
passed = 0
IF urlDec1$ = "Hello" THEN
  passed = 1
END IF
dummy = reportTest("6.1 URL decode 'SGVsbG8'", passed)
' Test 6.2: Round-trip URL encode/decode
urlOrig$ = "user:password@host"
urlRt$ = b64urldecode$(b64urlencode$(urlOrig$))
passed = 0
IF urlRt$ = urlOrig$ THEN
  passed = 1
END IF
dummy = reportTest("6.2 URL round-trip", passed)
' Test 6.3: Decode empty string
urlDec3$ = b64urldecode$("")
passed = 0
IF urlDec3$ = "" THEN
  passed = 1
END IF
dummy = reportTest("6.3 URL decode empty string", passed)
' Test 6.4: URL decode can also decode standard BASE64
urlDec4$ = b64urldecode$("SGVsbG8=")
passed = 0
IF urlDec4$ = "Hello" THEN
  passed = 1
END IF
dummy = reportTest("6.4 URL decode handles standard BASE64", passed)
' ============================================================================
' TEST SECTION 7: b64error() - Error Handling
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 7: b64error() ---"
PRINTLN
' Test 7.1: No error after successful encode
dummy$ = b64encode$("Test")
passed = 0
IF b64error() = 0 THEN
  passed = 1
END IF
dummy = reportTest("7.1 No error after encode", passed)
' Test 7.2: No error after successful decode
dummy$ = b64decode$("VGVzdA==")
passed = 0
IF b64error() = 0 THEN
  passed = 1
END IF
dummy = reportTest("7.2 No error after decode", passed)
' Test 7.3: Error after invalid decode
dummy$ = b64decode$("!!invalid!!")
passed = 0
IF b64error() <> 0 THEN
  passed = 1
END IF
dummy = reportTest("7.3 Error after invalid decode", passed)
' Test 7.4: Error code 1 for invalid BASE64
dummy$ = b64decode$("NotValid!!!")
errCode = b64error()
passed = 0
IF errCode = 1 THEN
  passed = 1
END IF
dummy = reportTest("7.4 Error code 1 (invalid BASE64)", passed)
' ============================================================================
' TEST SECTION 8: File Operations (if files exist)
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 8: File Operations ---"
PRINTLN
' Test 8.1: Create a test file, encode it, decode it back
' First, create test content and save to file
testContent$ = "This is test file content for BASE64 encoding."
testFilePath$ = "b64_test_input.txt"
outputFilePath$ = "b64_test_output.txt"
' Save test content to file using savetext$
saveResult$ = savetext$(testContent$, testFilePath$, "utf-8")
' Test encoding file
encodedFile$ = b64encodefile$(testFilePath$)
passed = 0
IF b64error() = 0 THEN
  IF len(encodedFile$) > 0 THEN
    passed = 1
  END IF
END IF
dummy = reportTest("8.1 Encode file to BASE64", passed)
' Test 8.2: Decode and save to new file
decodeResult = b64decodefile(encodedFile$, outputFilePath$)
passed = 0
IF decodeResult = 1 THEN
  passed = 1
END IF
dummy = reportTest("8.2 Decode BASE64 to file", passed)
' Test 8.3: Verify file content matches
recoveredContent$ = opentext$(outputFilePath$, "utf-8")
passed = 0
IF recoveredContent$ = testContent$ THEN
  passed = 1
END IF
dummy = reportTest("8.3 File round-trip content match", passed)
' Test 8.4: Error on non-existent file
dummy$ = b64encodefile$("nonexistent_file_xyz.txt")
passed = 0
IF b64error() = 3 THEN
  passed = 1
END IF
dummy = reportTest("8.4 Error on missing file (code 3)", passed)
' Test 8.5: Error on empty file path
dummy$ = b64encodefile$("")
passed = 0
IF b64error() = 2 THEN
  passed = 1
END IF
dummy = reportTest("8.5 Error on empty path (code 2)", passed)
' ============================================================================
' TEST SECTION 9: Edge Cases and Special Strings
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 9: Edge Cases ---"
PRINTLN
' Test 9.1: String with null character
nullStr$ = "Before" + chr$(0) + "After"
nullEnc$ = b64encode$(nullStr$)
nullDec$ = b64decode$(nullEnc$)
passed = 0
IF len(nullDec$) = len(nullStr$) THEN
  passed = 1
END IF
dummy = reportTest("9.1 Handle null character", passed)
' Test 9.2: Very long string (1000 chars)
longStr$ = ""
FOR i = 1 TO 100
  longStr$ = longStr$ + "0123456789"
NEXT
longEnc$ = b64encode$(longStr$)
longDec$ = b64decode$(longEnc$)
passed = 0
IF longDec$ = longStr$ THEN
  passed = 1
END IF
dummy = reportTest("9.2 Long string (1000 chars)", passed)
' Test 9.3: Binary-like data (all byte values representable)
binStr$ = ""
FOR i = 1 TO 255
  binStr$ = binStr$ + chr$(i)
NEXT
binEnc$ = b64encode$(binStr$)
binDec$ = b64decode$(binEnc$)
passed = 0
IF len(binDec$) = 255 THEN
  passed = 1
END IF
dummy = reportTest("9.3 All byte values (1-255)", passed)
' Test 9.4: Unicode string (Portuguese)
uniStr$ = "Programacao em BASIC"
uniEnc$ = b64encode$(uniStr$)
uniDec$ = b64decode$(uniEnc$)
passed = 0
IF uniDec$ = uniStr$ THEN
  passed = 1
END IF
dummy = reportTest("9.4 Portuguese text", passed)
' Test 9.5: Only whitespace
wsStr$ = "   " + chr$(9) + chr$(10) + chr$(13) + "   "
wsEnc$ = b64encode$(wsStr$)
wsDec$ = b64decode$(wsEnc$)
passed = 0
IF wsDec$ = wsStr$ THEN
  passed = 1
END IF
dummy = reportTest("9.5 Whitespace-only string", passed)
' ============================================================================
' TEST SECTION 10: Known BASE64 Test Vectors (RFC 4648)
' ============================================================================
PRINTLN
PRINTLN "--- TEST SECTION 10: RFC 4648 Test Vectors ---"
PRINTLN
' Standard test vectors from RFC 4648
' Test 10.1: "" encodes to ""
passed = 0
IF b64encode$("") = "" THEN
  passed = 1
END IF
dummy = reportTest("10.1 RFC: '' -> ''", passed)
' Test 10.2: "f" encodes to "Zg=="
passed = 0
IF b64encode$("f") = "Zg==" THEN
  passed = 1
END IF
dummy = reportTest("10.2 RFC: 'f' -> 'Zg=='", passed)
' Test 10.3: "fo" encodes to "Zm8="
passed = 0
IF b64encode$("fo") = "Zm8=" THEN
  passed = 1
END IF
dummy = reportTest("10.3 RFC: 'fo' -> 'Zm8='", passed)
' Test 10.4: "foo" encodes to "Zm9v"
passed = 0
IF b64encode$("foo") = "Zm9v" THEN
  passed = 1
END IF
dummy = reportTest("10.4 RFC: 'foo' -> 'Zm9v'", passed)
' Test 10.5: "foob" encodes to "Zm9vYg=="
passed = 0
IF b64encode$("foob") = "Zm9vYg==" THEN
  passed = 1
END IF
dummy = reportTest("10.5 RFC: 'foob' -> 'Zm9vYg=='", passed)
' Test 10.6: "fooba" encodes to "Zm9vYmE="
passed = 0
IF b64encode$("fooba") = "Zm9vYmE=" THEN
  passed = 1
END IF
dummy = reportTest("10.6 RFC: 'fooba' -> 'Zm9vYmE='", passed)
' Test 10.7: "foobar" encodes to "Zm9vYmFy"
passed = 0
IF b64encode$("foobar") = "Zm9vYmFy" THEN
  passed = 1
END IF
dummy = reportTest("10.7 RFC: 'foobar' -> 'Zm9vYmFy'", passed)
' ============================================================================
' FINAL RESULTS
' ============================================================================
PRINTLN
PRINTLN "========================================"
PRINTLN "  TEST RESULTS SUMMARY"
PRINTLN "========================================"
PRINTLN ""
PRINTLN "Total Tests:  "; totalTests
PRINTLN "Passed:       "; passedTests
PRINTLN "Failed:       "; totalTests - passedTests
PRINTLN
IF passedTests = totalTests THEN
  PRINTLN "*** ALL TESTS PASSED! ***"
ELSE
  PRINTLN "*** SOME TESTS FAILED ***"
  PRINTLN "Review the [FAIL] entries above."
END IF
PRINTLN
PRINTLN "========================================"
PRINTLN "  End of Test Suite"
PRINTLN "========================================"
