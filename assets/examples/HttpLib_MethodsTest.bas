' ============================================================================
' HttpLib Methods Test (v4.0)
' Tests all HTTP methods and response handling
' ============================================================================
' ----------------------------------------------------------------------------
' Test 1: GET Request
' ----------------------------------------------------------------------------
FUNCTION TestGet() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 1: GET Request"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_get$(client#, "/get")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
    PRINTLN "Response: " + str$(len(response$)) + " bytes"
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 2: POST Request
' ----------------------------------------------------------------------------
FUNCTION TestPost() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 2: POST Request"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_contenttype#(client#, "application/json")
  LET response$ = http_post$(client#, "/post", "{\"name\":\"Plan9Basic\",\"version\":4}")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
    IF instr(response$, "Plan9Basic") >= 0 THEN
      PRINTLN "Verified: JSON data echoed back"
    END IF
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 3: PUT Request
' ----------------------------------------------------------------------------
FUNCTION TestPut() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 3: PUT Request"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_contenttype#(client#, "application/json")
  LET response$ = http_put$(client#, "/put", "{\"id\":123,\"status\":\"updated\"}")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 4: DELETE Request
' ----------------------------------------------------------------------------
FUNCTION TestDelete() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 4: DELETE Request"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_delete$(client#, "/delete")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 5: PATCH Request
' ----------------------------------------------------------------------------
FUNCTION TestPatch() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 5: PATCH Request"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_contenttype#(client#, "application/json")
  LET response$ = http_patch$(client#, "/patch", "{\"field\":\"patched\"}")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 6: HEAD Request
' ----------------------------------------------------------------------------
FUNCTION TestHead() LOCAL client#, status, x
  PRINTLN "=============================================="
  PRINTLN "Test 6: HEAD Request"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET status = http_head(client#, "/get")
  IF status = 200 THEN
    PRINTLN "SUCCESS: Status " + str$(status)
    PRINTLN "Content-Length: " + str$(http_contentlength(client#))
  ELSE
    PRINTLN "FAILED: Status " + str$(status)
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 7: Multiple Sequential Requests
' ----------------------------------------------------------------------------
FUNCTION TestMultipleRequests() LOCAL client#, response$, i, x
  PRINTLN "=============================================="
  PRINTLN "Test 7: Multiple Sequential Requests"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  FOR i = 1 TO 3
    PRINTLN "Request " + str$(i) + "..."
    LET response$ = http_get$(client#, "/get")
    IF http_ok(client#) <> 0 THEN
      PRINTLN "  OK - " + str$(len(response$)) + " bytes"
    ELSE
      PRINTLN "  FAILED"
    END IF
  NEXT
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 8: Response Headers
' ----------------------------------------------------------------------------
FUNCTION TestResponseHeaders() LOCAL client#, response$, i, count, x
  PRINTLN "=============================================="
  PRINTLN "Test 8: Response Headers"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_get$(client#, "/get")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
    PRINTLN "Content-Type: " + http_respcontenttype$(client#)
    LET count = http_respheadercount(client#)
    PRINTLN "Total headers: " + str$(count)
    ' Show first 5 headers
    FOR i = 0 TO 4
      IF i < count THEN
        PRINTLN "  " + http_respheadername$(client#, i) + ": " + http_respheadervalue$(client#, i)
      END IF
    NEXT
  ELSE
    PRINTLN "FAILED"
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 9: Delayed Request (tests timeout handling)
' ----------------------------------------------------------------------------
FUNCTION TestDelayedRequest() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 9: Delayed Request (2 seconds)"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_timeout#(client#, 10000)
  LET client# = http_responsetimeout#(client#, 10000)
  PRINTLN "Starting 2-second delayed request..."
  LET response$ = http_get$(client#, "/delay/2")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Response received after delay"
    PRINTLN "Response: " + str$(len(response$)) + " bytes"
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' Test 10: Error Handling (404)
' ----------------------------------------------------------------------------
FUNCTION TestErrorHandling() LOCAL client#, response$, x
  PRINTLN "=============================================="
  PRINTLN "Test 10: Error Handling (404)"
  PRINTLN "=============================================="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_get$(client#, "/status/404")
  PRINTLN "Status: " + str$(http_status(client#))
  IF http_isclienterror(client#) <> 0 THEN
    PRINTLN "SUCCESS: Client error detected (4xx)"
  ELSE
    PRINTLN "Note: Status was not 4xx"
  END IF
  LET x = http_free(client#)
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' MAIN
' ----------------------------------------------------------------------------
PRINTLN "=============================================="
PRINTLN "  HttpLib Methods Test Suite (v4.0)"
PRINTLN "  Pure Synchronous API"
PRINTLN "=============================================="
PRINTLN ""
IF os_name$() = "Android" OR os_name$() = "iOS" THEN
  PRINTLN "Note: This test uses synchronous HTTP calls."
  PRINTLN "The UI may be unresponsive during requests on mobile."
  PRINTLN ""
END IF
TestGet()
TestPost()
TestPut()
TestDelete()
TestPatch()
TestHead()
TestMultipleRequests()
TestResponseHeaders()
TestDelayedRequest()
TestErrorHandling()
PRINTLN "=============================================="
PRINTLN "  All Method Tests Completed"
PRINTLN "=============================================="
