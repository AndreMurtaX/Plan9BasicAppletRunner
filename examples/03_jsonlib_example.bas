' =============================================================================
' Plan9Basic Applet Runner - JsonLib Example
' Demonstrates: JSON create, build, parse, navigate
' =============================================================================

PRINTLN "=== JsonLib - JSON Library ==="
PRINTLN ""

' --- Build a JSON object from scratch ---
PRINTLN "--- Building a JSON Object ---"
person# = json_object#()
person# = json_sets#(person#, "name", "Alice")
person# = json_setn#(person#, "age", 30)
person# = json_sets#(person#, "city", "Lisbon")
person# = json_setb#(person#, "active", 1)
PRINTLN "Person object  : "; json_stringify$(person#)
PRINTLN "Pretty printed :"
PRINTLN json_pretty$(person#)
PRINTLN ""

' --- Read values from an object ---
PRINTLN "--- Reading Object Values ---"
PRINTLN "name   = "; json_gets$(person#, "name")
PRINTLN "age    = "; json_getn(person#, "age")
PRINTLN "city   = "; json_gets$(person#, "city")
PRINTLN "active = "; json_getb(person#, "active")
PRINTLN "has email? "; json_has(person#, "email")
PRINTLN ""

' --- Build a JSON array ---
PRINTLN "--- Building a JSON Array ---"
colors# = json_array#()
colors# = json_pushs#(colors#, "red")
colors# = json_pushs#(colors#, "green")
colors# = json_pushs#(colors#, "blue")
PRINTLN "Colors array : "; json_stringify$(colors#)
PRINTLN "Count        : "; json_len(colors#)
PRINTLN "Item 0       : "; json_items$(colors#, 0)
PRINTLN "Item 1       : "; json_items$(colors#, 1)
PRINTLN "Item 2       : "; json_items$(colors#, 2)
PRINTLN ""

' --- Nested JSON ---
PRINTLN "--- Nested JSON ---"
address# = json_object#()
address# = json_sets#(address#, "street", "Main Street")
address# = json_setn#(address#, "number", 42)
address# = json_sets#(address#, "country", "Portugal")

profile# = json_object#()
profile# = json_sets#(profile#, "username", "alice99")
profile# = json_set#(profile#, "address", address#)
profile# = json_set#(profile#, "favouriteColors", colors#)

PRINTLN json_pretty$(profile#)
PRINTLN ""

' --- Parse JSON from a string ---
PRINTLN "--- Parsing JSON from a String ---"
raw$ = "{\"product\":\"Plan9Basic\",\"version\":1.8,\"open\":true}"
parsed# = json_parse#(raw$)
PRINTLN "Parsed OK"
PRINTLN "product = "; json_gets$(parsed#, "product")
PRINTLN "version = "; json_getn(parsed#, "version")
PRINTLN "open    = "; json_getb(parsed#, "open")
PRINTLN ""

' --- Type inspection ---
PRINTLN "--- Type Inspection ---"
PRINTLN "Type of parsed# : "; json_typename$(parsed#)
PRINTLN "Is object?      : "; json_isobj(parsed#)
PRINTLN "Is array?       : "; json_isarr(parsed#)
PRINTLN ""

PRINTLN "=== JsonLib Example Complete ==="
