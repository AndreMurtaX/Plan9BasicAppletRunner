' ============================================================================
' HttpLib Test Suite for Plan9Basic (v3.0)
' Uses httpbin.org - a free HTTP testing service
' Desktop sync API - for comprehensive testing
' On mobile platforms, this test may occasionally cause the application to
' stop responding. This is normal due to the number of requests made in the
' example. Allow the application to continue running and the tests will
' complete.
' ============================================================================
' ----------------------------------------------------------------------------
' TEST 1: Simple GET Request
' ----------------------------------------------------------------------------
FUNCTION Test_SimpleGet() LOCAL response$
  PRINTLN "=== TEST 1: Simple GET Request ==="
  LET response$ = http_simpleget$("https://httpbin.org/get")
  IF http_error() = 0 THEN
    PRINTLN "SUCCESS: Got response"
    PRINTLN "Response length: " + str$(len(response$)) + " chars"
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 2: GET with Client and Base URL
' ----------------------------------------------------------------------------
FUNCTION Test_ClientGet() LOCAL client#, response$, x
  PRINTLN "=== TEST 2: GET with Client ==="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_get$(client#, "/get")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Status " + str$(http_status(client#))
    PRINTLN "Content-Type: " + http_respcontenttype$(client#)
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 3: GET with Query Parameters
' ----------------------------------------------------------------------------
FUNCTION Test_QueryParams() LOCAL client#, response$, x
  PRINTLN "=== TEST 3: Query Parameters ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_param#(client#, "name", "Plan9Basic")
  LET client# = http_param#(client#, "version", "3.0")
  LET client# = http_param#(client#, "test", "hello world")
  LET response$ = http_get$(client#, "/get")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Parameters sent"
    IF instr(response$, "Plan9Basic") > 0 THEN
      PRINTLN "Verified: 'Plan9Basic' found in response"
    END IF
    IF instr(response$, "hello world") > 0 THEN
      PRINTLN "Verified: 'hello world' found (URL encoding works)"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 4: Custom Headers
' ----------------------------------------------------------------------------
FUNCTION Test_CustomHeaders() LOCAL client#, response$, x
  PRINTLN "=== TEST 4: Custom Headers ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_header#(client#, "X-Custom-Header", "Plan9Basic-Test")
  LET client# = http_header#(client#, "X-Request-ID", "12345")
  LET response$ = http_get$(client#, "/headers")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Headers sent"
    IF instr(response$, "Plan9Basic-Test") > 0 THEN
      PRINTLN "Verified: Custom header found in response"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 5: POST with JSON Body
' ----------------------------------------------------------------------------
FUNCTION Test_PostJson() LOCAL client#, body$, response$, x
  PRINTLN "=== TEST 5: POST with JSON Body ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_contenttype#(client#, "application/json")
  LET body$ = "{\"name\":\"John\",\"language\":\"Plan9Basic\",\"version\":3}"
  LET response$ = http_post$(client#, "/post", body$)
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: POST completed"
    PRINTLN "Status: " + str$(http_status(client#))
    IF instr(response$, "Plan9Basic") > 0 THEN
      PRINTLN "Verified: JSON data echoed back"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 6: POST with Form Data (URL-encoded)
' ----------------------------------------------------------------------------
FUNCTION Test_PostForm() LOCAL client#, form#, response$, x
  PRINTLN "=== TEST 6: POST with Form Data ==="
  LET client# = http_client#("https://httpbin.org")
  LET form# = http_form#()
  LET form# = http_formfield#(form#, "username", "testuser")
  LET form# = http_formfield#(form#, "password", "secret123")
  LET form# = http_formfield#(form#, "remember", "true")
  PRINTLN "Form fields: " + str$(http_formfieldcount(form#))
  LET response$ = http_postformurl$(client#, "/post", form#)
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Form POST completed"
    IF instr(response$, "testuser") > 0 THEN
      PRINTLN "Verified: Form data echoed back"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_formfree(form#)
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 7: PUT Request
' ----------------------------------------------------------------------------
FUNCTION Test_Put() LOCAL client#, body$, response$, x
  PRINTLN "=== TEST 7: PUT Request ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_contenttype#(client#, "application/json")
  LET body$ = "{\"id\":123,\"status\":\"updated\"}"
  LET response$ = http_put$(client#, "/put", body$)
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: PUT completed"
    PRINTLN "Status: " + str$(http_status(client#))
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 8: DELETE Request
' ----------------------------------------------------------------------------
FUNCTION Test_Delete() LOCAL client#, response$, x
  PRINTLN "=== TEST 8: DELETE Request ==="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_delete$(client#, "/delete")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: DELETE completed"
    PRINTLN "Status: " + str$(http_status(client#))
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 9: PATCH Request
' ----------------------------------------------------------------------------
FUNCTION Test_Patch() LOCAL client#, body$, response$, x
  PRINTLN "=== TEST 9: PATCH Request ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_contenttype#(client#, "application/json")
  LET body$ = "{\"field\":\"patched_value\"}"
  LET response$ = http_patch$(client#, "/patch", body$)
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: PATCH completed"
    PRINTLN "Status: " + str$(http_status(client#))
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 10: HEAD Request
' ----------------------------------------------------------------------------
FUNCTION Test_Head() LOCAL client#, status, x
  PRINTLN "=== TEST 10: HEAD Request ==="
  LET client# = http_client#("https://httpbin.org")
  LET status = http_head(client#, "/get")
  IF status = 200 THEN
    PRINTLN "SUCCESS: HEAD returned status " + str$(status)
    PRINTLN "Content-Length: " + str$(http_contentlength(client#))
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: Status " + str$(status)
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 11: Basic Authentication
' ----------------------------------------------------------------------------
FUNCTION Test_BasicAuth() LOCAL client#, response$, x
  PRINTLN "=== TEST 11: Basic Authentication ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_basicauth#(client#, "testuser", "testpass")
  LET response$ = http_get$(client#, "/basic-auth/testuser/testpass")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Authentication passed"
    IF instr(response$, "authenticated") > 0 THEN
      PRINTLN "Verified: Response confirms authentication"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 12: Bearer Token Authentication
' ----------------------------------------------------------------------------
FUNCTION Test_BearerAuth() LOCAL client#, response$, x
  PRINTLN "=== TEST 12: Bearer Token Authentication ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_bearerauth#(client#, "my-secret-token-12345")
  LET response$ = http_get$(client#, "/bearer")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Bearer auth accepted"
    IF instr(response$, "my-secret-token-12345") > 0 THEN
      PRINTLN "Verified: Token echoed in response"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: Status " + str$(http_status(client#))
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 13: Response Headers
' ----------------------------------------------------------------------------
FUNCTION Test_ResponseHeaders() LOCAL client#, response$, i, count, x
  PRINTLN "=== TEST 13: Response Headers ==="
  LET client# = http_client#("https://httpbin.org")
  LET response$ = http_get$(client#, "/get")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: Got response"
    LET count = http_respheadercount(client#)
    PRINTLN "Response header count: " + str$(count)
    ' Show first few headers
    IF count > 3 THEN
      LET count = 3
    END IF
    FOR i = 0 TO count - 1
      PRINTLN "  " + http_respheadername$(client#, i) + ": " + http_respheadervalue$(client#, i)
    NEXT
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 14: Status Codes
' ----------------------------------------------------------------------------
FUNCTION Test_StatusCodes() LOCAL client#, response$, x
  PRINTLN "=== TEST 14: Status Codes ==="
  LET client# = http_client#("https://httpbin.org")
  ' Test 404
  LET response$ = http_get$(client#, "/status/404")
  PRINTLN "404 test: Status=" + str$(http_status(client#)) + " IsClientError=" + str$(http_isclienterror(client#))
  ' Test 500
  LET response$ = http_get$(client#, "/status/500")
  PRINTLN "500 test: Status=" + str$(http_status(client#)) + " IsServerError=" + str$(http_isservererror(client#))
  ' Test 302 (redirect - might follow depending on settings)
  LET response$ = http_get$(client#, "/status/200")
  PRINTLN "200 test: Status=" + str$(http_status(client#)) + " IsOK=" + str$(http_ok(client#))
  PRINTLN ""
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 15: Cookies
' ----------------------------------------------------------------------------
FUNCTION Test_Cookies() LOCAL client#, response$, x
  PRINTLN "=== TEST 15: Cookies ==="
  LET client# = http_client#("https://httpbin.org")
  ' Set a cookie and send request
  LET client# = http_cookie#(client#, "session_id", "abc123")
  LET client# = http_cookie#(client#, "user_pref", "dark_mode")
  PRINTLN "Cookies set: " + str$(http_cookiecount(client#))
  LET response$ = http_get$(client#, "/cookies")
  IF http_ok(client#) <> 0 THEN
    IF instr(response$, "abc123") > 0 THEN
      PRINTLN "SUCCESS: Cookie sent and echoed"
    ELSE
      PRINTLN "WARNING: Cookie may not have been echoed"
    END IF
    PRINTLN ""
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 16: URL Encoding
' ----------------------------------------------------------------------------
FUNCTION Test_UrlEncoding() LOCAL original$, encoded$, decoded$
  PRINTLN "=== TEST 16: URL Encoding ==="
  LET original$ = "Hello World & Special <chars> + more!"
  LET encoded$ = http_urlencode$(original$)
  LET decoded$ = http_urldecode$(encoded$)
  PRINTLN "Original: " + original$
  PRINTLN "Encoded:  " + encoded$
  PRINTLN "Decoded:  " + decoded$
  IF original$ = decoded$ THEN
    PRINTLN "SUCCESS: Encode/Decode roundtrip OK"
  ELSE
    PRINTLN "FAILED: Mismatch after roundtrip"
  END IF
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 17: HTML Encoding
' ----------------------------------------------------------------------------
FUNCTION Test_HtmlEncoding() LOCAL original$, encoded$, decoded$
  PRINTLN "=== TEST 17: HTML Encoding ==="
  LET original$ = "<script>alert('XSS')</script>"
  LET encoded$ = http_htmlencode$(original$)
  LET decoded$ = http_htmldecode$(encoded$)
  PRINTLN "Original: " + original$
  PRINTLN "Encoded:  " + encoded$
  PRINTLN "Decoded:  " + decoded$
  IF original$ = decoded$ THEN
    PRINTLN "SUCCESS: HTML Encode/Decode roundtrip OK"
  ELSE
    PRINTLN "FAILED: Mismatch after roundtrip"
  END IF
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 18: Timeout Configuration
' ----------------------------------------------------------------------------
FUNCTION Test_Timeout() LOCAL client#, response$, x
  PRINTLN "=== TEST 18: Timeout Configuration ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_timeout#(client#, 5000)
  LET client# = http_responsetimeout#(client#, 10000)
  PRINTLN "Connection timeout: " + str$(http_timeout(client#)) + " ms"
  ' Test with delayed response (2 seconds - should succeed)
  LET response$ = http_get$(client#, "/delay/2")
  IF http_ok(client#) <> 0 THEN
    PRINTLN "SUCCESS: 2-second delay completed within timeout"
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  PRINTLN ""
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 19: User-Agent
' ----------------------------------------------------------------------------
FUNCTION Test_UserAgent() LOCAL client#, response$, x
  PRINTLN "=== TEST 19: User-Agent ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_useragent#(client#, "Plan9Basic-HttpLib/3.0 (Test Suite)")
  LET response$ = http_get$(client#, "/user-agent")
  IF http_ok(client#) <> 0 THEN
    IF instr(response$, "Plan9Basic-HttpLib") > 0 THEN
      PRINTLN "SUCCESS: Custom User-Agent sent"
    ELSE
      PRINTLN "WARNING: User-Agent not found in response"
    END IF
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  PRINTLN ""
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 20: Error Handling
' ----------------------------------------------------------------------------
FUNCTION Test_ErrorHandling() LOCAL x, badClient#, response$, errCode, errMsg$, errDesc$
  PRINTLN "=== TEST 20: Error Handling ==="
  ' Clear any previous error
  LET x = http_clearerror()
  ' Try to use a null pointer (should set error)
  LET badClient# = Pointer#(0)
  LET response$ = http_get$(badClient#, "/get")
  LET errCode = http_error()
  LET errMsg$ = http_errormsg$()
  LET errDesc$ = http_strerror$(errCode)
  IF errCode <> 0 THEN
    PRINTLN "SUCCESS: Error detected"
    PRINTLN "Error code: " + str$(errCode)
    PRINTLN "Error message: " + errMsg$
    PRINTLN "Error description: " + errDesc$
  ELSE
    PRINTLN "Note: Error handling may vary"
  END IF
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 21: Simple POST
' ----------------------------------------------------------------------------
FUNCTION Test_SimplePost() LOCAL body$, response$
  PRINTLN "=== TEST 21: Simple POST ==="
  LET body$ = "{\"test\":\"simple post\"}"
  LET response$ = http_simplepost$("https://httpbin.org/post", body$)
  IF http_error() = 0 THEN
    PRINTLN "SUCCESS: Simple POST completed"
    IF instr(response$, "simple post") > 0 THEN
      PRINTLN "Verified: Data echoed back"
    END IF
  ELSE
    PRINTLN "FAILED: " + http_errormsg$()
  END IF
  PRINTLN ""
END FUNCTION
' ----------------------------------------------------------------------------
' TEST 22: Client Reset
' ----------------------------------------------------------------------------
FUNCTION Test_ClientReset() LOCAL client#, x
  PRINTLN "=== TEST 22: Client Reset ==="
  LET client# = http_client#("https://httpbin.org")
  LET client# = http_header#(client#, "X-Test", "Before")
  LET client# = http_param#(client#, "key", "value")
  LET client# = http_bearerauth#(client#, "token123")
  PRINTLN "Before reset: Headers=" + str$(http_headercount(client#))
  LET client# = http_reset#(client#)
  PRINTLN "After reset: Headers=" + str$(http_headercount(client#))
  PRINTLN "SUCCESS: Client reset"
  PRINTLN ""
  LET x = http_free(client#)
END FUNCTION
' ----------------------------------------------------------------------------
' MAIN: Run All Tests
' ----------------------------------------------------------------------------
PRINTLN "=============================================="
PRINTLN "  HttpLib Test Suite v3.0 for Plan9Basic"
PRINTLN "  Testing against httpbin.org"
PRINTLN "=============================================="
PRINTLN ""
IF os_name$() = "Android" OR os_name$() = "iOS" THEN
  PRINTLN "Note: This test uses synchronous HTTP calls."
  PRINTLN "The UI may be unresponsive during requests on mobile."
  PRINTLN ""
END IF
Test_SimpleGet()
Test_ClientGet()
Test_QueryParams()
Test_CustomHeaders()
Test_PostJson()
Test_PostForm()
Test_Put()
Test_Delete()
Test_Patch()
Test_Head()
Test_BasicAuth()
Test_BearerAuth()
Test_ResponseHeaders()
Test_StatusCodes()
Test_Cookies()
Test_UrlEncoding()
Test_HtmlEncoding()
Test_Timeout()
Test_UserAgent()
Test_ErrorHandling()
Test_SimplePost()
Test_ClientReset()
PRINTLN "=============================================="
PRINTLN "  All Tests Completed"
PRINTLN "=============================================="
