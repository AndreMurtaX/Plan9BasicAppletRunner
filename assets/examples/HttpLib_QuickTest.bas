' ============================================================================
' HttpLib Quick Test - Minimal validation of core functionality
' Uses httpbin.org - Works on all platforms (Desktop sync API)
' ============================================================================
PRINTLN "=== HttpLib Quick Test (v3.0) ==="
PRINTLN ""
IF os_name$() = "Android" OR os_name$() = "iOS" THEN
  PRINTLN "Note: This test uses synchronous HTTP calls."
  PRINTLN "The UI may be unresponsive during requests on mobile."
  PRINTLN ""
END IF
' Test 1: Simple GET
PRINTLN "1. Simple GET..."
LET r$ = http_simpleget$("https://httpbin.org/get")
IF len(r$) > 0 THEN
  PRINTLN "   OK - Got " + str$(len(r$)) + " bytes"
ELSE
  PRINTLN "   FAILED"
END IF
' Test 2: Client-based GET
PRINTLN "2. Client GET..."
LET c# = http_client#("https://httpbin.org")
LET r$ = http_get$(c#, "/get")
IF http_ok(c#) <> 0 THEN
  PRINTLN "   OK - Status " + str$(http_status(c#))
ELSE
  PRINTLN "   FAILED - Status " + str$(http_status(c#))
END IF
' Test 3: POST JSON
PRINTLN "3. POST JSON..."
LET c# = http_contenttype#(c#, "application/json")
LET r$ = http_post$(c#, "/post", "{\"test\":true}")
IF http_ok(c#) <> 0 THEN
  PRINTLN "   OK - Status " + str$(http_status(c#))
ELSE
  PRINTLN "   FAILED"
END IF
' Test 4: Form data
PRINTLN "4. Form POST..."
LET f# = http_form#()
LET f# = http_formfield#(f#, "user", "test")
LET f# = http_formfield#(f#, "pass", "1234")
LET r$ = http_postformurl$(c#, "/post", f#)
IF http_ok(c#) <> 0 THEN
  PRINTLN "   OK - " + str$(http_formfieldcount(f#)) + " fields sent"
ELSE
  PRINTLN "   FAILED"
END IF
LET x = http_formfree(f#)
' Test 5: Query parameters
PRINTLN "5. Query params..."
LET c# = http_param#(c#, "name", "Plan9")
LET c# = http_param#(c#, "ver", "3.0")
LET r$ = http_get$(c#, "/get")
IF instr(r$, "Plan9") > 0 THEN
  PRINTLN "   OK - Params in response"
ELSE
  PRINTLN "   FAILED"
END IF
LET c# = http_paramclear#(c#)
' Test 6: Custom headers
PRINTLN "6. Custom headers..."
LET c# = http_header#(c#, "X-Test", "Plan9Basic")
LET r$ = http_get$(c#, "/headers")
IF instr(r$, "Plan9Basic") > 0 THEN
  PRINTLN "   OK - Header echoed"
ELSE
  PRINTLN "   FAILED"
END IF
' Test 7: PUT
PRINTLN "7. PUT request..."
LET r$ = http_put$(c#, "/put", "{\"update\":1}")
IF http_ok(c#) <> 0 THEN
  PRINTLN "   OK - Status " + str$(http_status(c#))
ELSE
  PRINTLN "   FAILED"
END IF
' Test 8: DELETE
PRINTLN "8. DELETE request..."
LET r$ = http_delete$(c#, "/delete")
IF http_ok(c#) <> 0 THEN
  PRINTLN "   OK - Status " + str$(http_status(c#))
ELSE
  PRINTLN "   FAILED"
END IF
' Test 9: Basic Auth
PRINTLN "9. Basic Auth..."
LET c# = http_basicauth#(c#, "user", "pass")
LET r$ = http_get$(c#, "/basic-auth/user/pass")
IF http_ok(c#) <> 0 THEN
  PRINTLN "   OK - Authenticated"
ELSE
  PRINTLN "   FAILED - Status " + str$(http_status(c#))
END IF
LET c# = http_clearauth#(c#)
' Test 10: URL encoding
PRINTLN "10. URL encoding..."
LET enc$ = http_urlencode$("hello world&test=1")
LET dec$ = http_urldecode$(enc$)
IF dec$ = "hello world&test=1" THEN
  PRINTLN "   OK - Roundtrip successful"
ELSE
  PRINTLN "   FAILED"
END IF
' Cleanup
LET x = http_free(c#)
PRINTLN ""
PRINTLN "=== Quick Test Complete ==="
