' ============================================================================
' HttpLib Simple Test (v4.0)
' Quick validation of basic HTTP functionality
' ============================================================================
PRINTLN "=== HttpLib Simple Test (v4.0) ==="
PRINTLN ""
IF os_name$() = "Android" OR os_name$() = "iOS" THEN
  PRINTLN "Note: This test uses synchronous HTTP calls."
  PRINTLN "The UI may be unresponsive during requests on mobile."
  PRINTLN ""
END IF
' ----------------------------------------------------------------------------
' Test 1: Create client and make a GET request
' ----------------------------------------------------------------------------
PRINTLN "1. Creating HTTP client..."
LET client# = http_client#("https://httpbin.org")
PRINTLN "   Client created."
PRINTLN ""
PRINTLN "2. Making GET request to /get..."
LET response$ = http_get$(client#, "/get")
PRINTLN "   Status: " + str$(http_status(client#))
PRINTLN "   Response: " + str$(len(response$)) + " bytes"
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 2: Check response details
' ----------------------------------------------------------------------------
PRINTLN "3. Response details:"
PRINTLN "   Status text: " + http_statustext$(client#)
PRINTLN "   Content-Type: " + http_respcontenttype$(client#)
PRINTLN "   Content-Length: " + str$(http_contentlength(client#))
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 3: Verify success
' ----------------------------------------------------------------------------
PRINTLN "4. Status checks:"
IF http_ok(client#) <> 0 THEN
  PRINTLN "   http_ok: YES (2xx response)"
ELSE
  PRINTLN "   http_ok: NO"
END IF
IF http_isclienterror(client#) <> 0 THEN
  PRINTLN "   Client error (4xx): YES"
ELSE
  PRINTLN "   Client error (4xx): NO"
END IF
IF http_isservererror(client#) <> 0 THEN
  PRINTLN "   Server error (5xx): YES"
ELSE
  PRINTLN "   Server error (5xx): NO"
END IF
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 4: Simple POST
' ----------------------------------------------------------------------------
PRINTLN "5. Making POST request..."
LET client# = http_contenttype#(client#, "application/json")
LET response$ = http_post$(client#, "/post", "{\"test\":true}")
PRINTLN "   Status: " + str$(http_status(client#))
IF http_ok(client#) <> 0 THEN
  PRINTLN "   POST successful"
ELSE
  PRINTLN "   POST failed"
END IF
PRINTLN ""
' ----------------------------------------------------------------------------
' Cleanup
' ----------------------------------------------------------------------------
PRINTLN "6. Cleaning up..."
LET x = http_free(client#)
PRINTLN "   Client freed."
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 5: Simple functions (no client needed)
' ----------------------------------------------------------------------------
PRINTLN "7. Testing simple functions..."
LET response$ = http_simpleget$("https://httpbin.org/get")
IF len(response$) > 0 THEN
  PRINTLN "   http_simpleget$: OK (" + str$(len(response$)) + " bytes)"
ELSE
  PRINTLN "   http_simpleget$: FAILED"
END IF
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 6: URL encoding
' ----------------------------------------------------------------------------
PRINTLN "8. URL encoding test..."
LET original$ = "Hello World & Test=123"
LET encoded$ = http_urlencode$(original$)
LET decoded$ = http_urldecode$(encoded$)
PRINTLN "   Original: " + original$
PRINTLN "   Encoded:  " + encoded$
PRINTLN "   Decoded:  " + decoded$
IF original$ = decoded$ THEN
  PRINTLN "   Roundtrip: OK"
ELSE
  PRINTLN "   Roundtrip: FAILED"
END IF
PRINTLN ""
PRINTLN "=== Simple Test Complete ==="
