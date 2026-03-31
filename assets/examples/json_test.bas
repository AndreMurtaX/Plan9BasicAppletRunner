' ============================================================================
' JSON Library Test Suite for Plan9Basic
' ============================================================================
PRINTLN "=== JSON LIBRARY TESTS ==="
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 1: Empty structures
' ----------------------------------------------------------------------------
PRINTLN "Test 1: Empty structures"
LET emptyObj# = json_object#()
LET emptyArr# = json_array#()
PRINTLN "Empty object: " + json_stringify$(emptyObj#)
PRINTLN "Empty array: " + json_stringify$(emptyArr#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 2: Simple array literal
' ----------------------------------------------------------------------------
PRINTLN "Test 2: Simple array literal"
LET arr# = [1, 2, 3]
PRINTLN "Array [1, 2, 3]: " + json_stringify$(arr#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 3: String array literal
' ----------------------------------------------------------------------------
PRINTLN "Test 3: String array literal"
LET names# = ["Alice", "Bob", "Carol"]
PRINTLN "Names array: " + json_stringify$(names#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 4: Mixed types array
' ----------------------------------------------------------------------------
PRINTLN "Test 4: Mixed types array"
LET mixed# = [10, "text", 3.14]
PRINTLN "Mixed array: " + json_stringify$(mixed#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 5: Simple object literal
' ----------------------------------------------------------------------------
PRINTLN "Test 5: Simple object literal"
LET person# = {"name": "John", "age": 30}
PRINTLN "Person object: " + json_stringify$(person#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 6: Variables in JSON
' ----------------------------------------------------------------------------
PRINTLN "Test 6: Variables in JSON"
LET userName$ = "Alice"
LET userAge = 25
LET user# = {"name": userName$, "age": userAge}
PRINTLN "User with variables: " + json_stringify$(user#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 7: Nested objects
' ----------------------------------------------------------------------------
PRINTLN "Test 7: Nested objects"
LET nested# = {"user": {"name": "John", "email": "john@example.com"}}
PRINTLN "Nested object: " + json_stringify$(nested#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 8: Object with array property
' ----------------------------------------------------------------------------
PRINTLN "Test 8: Object with array property"
LET record# = {"name": "John", "scores": [95, 87, 92]}
PRINTLN "Object with array: " + json_stringify$(record#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 9: Array of objects
' ----------------------------------------------------------------------------
PRINTLN "Test 9: Array of objects"
LET users# = [{"name": "Alice"}, {"name": "Bob"}]
PRINTLN "Array of objects: " + json_stringify$(users#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 10: Boolean and null values
' ----------------------------------------------------------------------------
PRINTLN "Test 10: Boolean and null values"
LET flags# = [TRUE, FALSE, NULL]
PRINTLN "Flags array: " + json_stringify$(flags#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 11: Nested arrays
' ----------------------------------------------------------------------------
PRINTLN "Test 11: Nested arrays"
LET matrix# = [[1, 2], [3, 4]]
PRINTLN "Nested arrays: " + json_stringify$(matrix#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 12: Negative numbers
' ----------------------------------------------------------------------------
PRINTLN "Test 12: Negative numbers"
LET nums# = [-10, 20, -30.5]
PRINTLN "Negative numbers: " + json_stringify$(nums#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 13: Object access functions
' ----------------------------------------------------------------------------
PRINTLN "Test 13: Object access functions"
LET obj# = {"name": "John", "age": 30, "active": TRUE}
PRINTLN "Name: " + json_gets$(obj#, "name")
PRINTLN "Age: " + stri$(json_getn(obj#, "age"))
PRINTLN "Active: " + stri$(json_getb(obj#, "active"))
PRINTLN "Has email: " + stri$(json_has(obj#, "email"))
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 14: Array access functions
' ----------------------------------------------------------------------------
PRINTLN "Test 14: Array access functions"
LET arr# = [10, 20, 30, 40, 50]
PRINTLN "Length: " + stri$(json_len(arr#))
PRINTLN "Item 0: " + stri$(json_itemn(arr#, 0))
PRINTLN "Item 2: " + stri$(json_itemn(arr#, 2))
PRINTLN "Item 99 (default -1): " + stri$(json_itemn(arr#, 99, -1))
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 15: Path navigation
' ----------------------------------------------------------------------------
PRINTLN "Test 15: Path navigation"
LET DATA# = {"user": {"profile": {"name": "John", "scores": [95, 87, 92]}}}
PRINTLN "user.profile.name: " + json_paths$(DATA#, "user.profile.name")
PRINTLN "user.profile.scores[0]: " + stri$(json_pathn(DATA#, "user.profile.scores[0]"))
PRINTLN "user.profile.scores[2]: " + stri$(json_pathn(DATA#, "user.profile.scores[2]"))
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 16: Type checking
' ----------------------------------------------------------------------------
PRINTLN "Test 16: Type checking"
LET testObj# = {"test": 1}
LET testArr# = [1, 2, 3]
LET testNum# = json_number#(42)
LET testStr# = json_string#("hello")
LET testBool# = json_bool#(1)
LET testNull# = json_null#()
PRINTLN "Object type: " + json_typename$(testObj#)
PRINTLN "Array type: " + json_typename$(testArr#)
PRINTLN "Number type: " + json_typename$(testNum#)
PRINTLN "String type: " + json_typename$(testStr#)
PRINTLN "Boolean type: " + json_typename$(testBool#)
PRINTLN "Null type: " + json_typename$(testNull#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 17: Object modification
' ----------------------------------------------------------------------------
PRINTLN "Test 17: Object modification"
LET MOD# = json_object#()
LET MOD# = json_sets#(MOD#, "name", "Alice")
LET MOD# = json_setn#(MOD#, "age", 28)
LET MOD# = json_setb#(MOD#, "active", 1)
PRINTLN "After modifications: " + json_stringify$(MOD#)
LET MOD# = json_remove#(MOD#, "age")
PRINTLN "After removing age: " + json_stringify$(MOD#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 18: Array modification
' ----------------------------------------------------------------------------
PRINTLN "Test 18: Array modification"
LET arrMod# = json_array#()
LET arrMod# = json_pushn#(arrMod#, 10)
LET arrMod# = json_pushs#(arrMod#, "hello")
LET arrMod# = json_pushb#(arrMod#, 1)
LET arrMod# = json_pushnull#(arrMod#)
PRINTLN "After pushes: " + json_stringify$(arrMod#)
LET popped# = json_pop#(arrMod#)
PRINTLN "Popped: " + json_typename$(popped#)
PRINTLN "After pop: " + json_stringify$(arrMod#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 19: Clone
' ----------------------------------------------------------------------------
PRINTLN "Test 19: Clone"
LET original# = {"name": "John", "data": [1, 2, 3]}
LET copy# = json_clone#(original#)
LET copy# = json_sets#(copy#, "name", "Jane")
PRINTLN "Original name: " + json_gets$(original#, "name")
PRINTLN "Copy name: " + json_gets$(copy#, "name")
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 20: Pretty print
' ----------------------------------------------------------------------------
PRINTLN "Test 20: Pretty print"
LET prettyObj# = {"name": "John", "address": {"city": "NYC"}}
PRINTLN "Pretty output:"
PRINTLN json_pretty$(prettyObj#)
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 21: Parse JSON string
' ----------------------------------------------------------------------------
PRINTLN "Test 21: Parse JSON string"
LET jsonStr$ = "{\"product\": \"Widget\", \"price\": 29.99, \"inStock\": true}"
LET parsed# = json_parse#(jsonStr$)
PRINTLN "Parsed product: " + json_gets$(parsed#, "product")
PRINTLN "Parsed price: " + stri$(json_getn(parsed#, "price"))
PRINTLN "Parsed inStock: " + stri$(json_getb(parsed#, "inStock"))
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 22: Object keys
' ----------------------------------------------------------------------------
PRINTLN "Test 22: Object keys"
LET keysObj# = {"a": 1, "b": 2, "c": 3}
LET keys# = json_keys#(keysObj#)
PRINTLN "Keys: " + json_stringify$(keys#)
PRINTLN "Key count: " + stri$(json_count(keysObj#))
PRINTLN ""
' ----------------------------------------------------------------------------
' Test 23: Merge objects
' ----------------------------------------------------------------------------
PRINTLN "Test 23: Merge objects"
LET base# = {"name": "John", "age": 30}
LET extra# = {"city": "NYC", "age": 31}
LET base# = json_merge#(base#, extra#)
PRINTLN "After merge: " + json_stringify$(base#)
PRINTLN ""
PRINTLN "=== ALL TESTS COMPLETED ==="
