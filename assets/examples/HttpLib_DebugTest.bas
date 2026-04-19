' Simple debug test for HTTP events
PRINTLN "=== HTTP Event Debug Test ==="
PRINTLN ""
IF os_name$() = "Android" OR os_name$() = "iOS" THEN
  PRINTLN "Note: This test uses synchronous HTTP calls."
  PRINTLN "The UI may be unresponsive during requests on mobile."
  PRINTLN ""
END IF
' Create client - should show [DEBUG] http_client#(url): Engine OK
PRINTLN "Creating client..."
LET client# = http_client#("https://httpbin.org")
PRINTLN "Client created."
PRINTLN ""
' Make a simple request
PRINTLN "Making request to /get..."
LET response$ = http_get$(client#, "/get")
PRINTLN "Request complete."
PRINTLN "Response length: " + str$(len(response$))
PRINTLN ""
LET x = http_free(client#)
PRINTLN "=== Test Complete ==="
