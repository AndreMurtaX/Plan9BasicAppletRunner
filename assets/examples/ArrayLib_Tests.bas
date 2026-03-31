' ============================================================================
' ArrayLib Test Suite for Plan9Basic
' ============================================================================
' This test suite validates all ArrayLib functions including:
' - Array creation (dim#, sdim#, pdim#)
' - Array access (narr_get/set, sarr_get/set, parr_get/set)
' - Utility functions (ndims, ubound, lbound, arraysize, arraytype, arraytypename$)
' - 1-based indexing verification
' - Multi-dimensional arrays (1D through 4D)
' ============================================================================
LET passed = 0
LET failed = 0
LET testNum = 0
' ----------------------------------------------------------------------------
' Test helper function
' ----------------------------------------------------------------------------
FUNCTION test(description$, expected, actual) LOCAL dummy
  testNum = testNum + 1
  IF expected = actual THEN
    PRINTLN "[PASS] Test "; testNum; ": "; description$
    passed = passed + 1
  ELSE
    PRINTLN "[FAIL] Test "; testNum; ": "; description$
    PRINTLN "       Expected: "; expected
    PRINTLN "       Actual:   "; actual
    failed = failed + 1
  END IF
  RETURN 0
END FUNCTION
FUNCTION testStr(description$, expected$, actual$) LOCAL dummy
  testNum = testNum + 1
  IF expected$ = actual$ THEN
    PRINTLN "[PASS] Test "; testNum; ": "; description$
    passed = passed + 1
  ELSE
    PRINTLN "[FAIL] Test "; testNum; ": "; description$
    PRINTLN "       Expected: "; expected$
    PRINTLN "       Actual:   "; actual$
    failed = failed + 1
  END IF
  RETURN 0
END FUNCTION
' ----------------------------------------------------------------------------
' SECTION 1: Numeric Array Creation (dim#)
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 1: Numeric Array Creation (dim#)"
PRINTLN "============================================"
PRINTLN
' Test 1D numeric array creation
LET arr1d# = dim#(5)
test("1D numeric array - ndims", 1, ndims(arr1d#))
test("1D numeric array - ubound(1)", 5, ubound(arr1d#, 1))
test("1D numeric array - lbound(1)", 1, lbound(arr1d#, 1))
test("1D numeric array - arraysize", 5, arraysize(arr1d#))
test("1D numeric array - arraytype", 0, arraytype(arr1d#))
testStr("1D numeric array - arraytypename$", "numeric", arraytypename$(arr1d#))
' Test 2D numeric array creation
LET arr2d# = dim#(3, 4)
test("2D numeric array - ndims", 2, ndims(arr2d#))
test("2D numeric array - ubound(1)", 3, ubound(arr2d#, 1))
test("2D numeric array - ubound(2)", 4, ubound(arr2d#, 2))
test("2D numeric array - lbound(1)", 1, lbound(arr2d#, 1))
test("2D numeric array - lbound(2)", 1, lbound(arr2d#, 2))
test("2D numeric array - arraysize", 12, arraysize(arr2d#))
' Test 3D numeric array creation
LET arr3d# = dim#(2, 3, 4)
test("3D numeric array - ndims", 3, ndims(arr3d#))
test("3D numeric array - ubound(1)", 2, ubound(arr3d#, 1))
test("3D numeric array - ubound(2)", 3, ubound(arr3d#, 2))
test("3D numeric array - ubound(3)", 4, ubound(arr3d#, 3))
test("3D numeric array - arraysize", 24, arraysize(arr3d#))
' Test 4D numeric array creation
LET arr4d# = dim#(2, 2, 2, 2)
test("4D numeric array - ndims", 4, ndims(arr4d#))
test("4D numeric array - arraysize", 16, arraysize(arr4d#))
' ----------------------------------------------------------------------------
' SECTION 2: String Array Creation (sdim#)
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 2: String Array Creation (sdim#)"
PRINTLN "============================================"
PRINTLN
' Test 1D string array creation
LET sarr1d# = sdim#(5)
test("1D string array - ndims", 1, ndims(sarr1d#))
test("1D string array - ubound(1)", 5, ubound(sarr1d#, 1))
test("1D string array - lbound(1)", 1, lbound(sarr1d#, 1))
test("1D string array - arraysize", 5, arraysize(sarr1d#))
test("1D string array - arraytype", 1, arraytype(sarr1d#))
testStr("1D string array - arraytypename$", "string", arraytypename$(sarr1d#))
' Test 2D string array creation
LET sarr2d# = sdim#(3, 4)
test("2D string array - ndims", 2, ndims(sarr2d#))
test("2D string array - ubound(1)", 3, ubound(sarr2d#, 1))
test("2D string array - ubound(2)", 4, ubound(sarr2d#, 2))
test("2D string array - arraysize", 12, arraysize(sarr2d#))
' Test 3D string array creation
LET sarr3d# = sdim#(2, 3, 4)
test("3D string array - ndims", 3, ndims(sarr3d#))
test("3D string array - arraysize", 24, arraysize(sarr3d#))
' ----------------------------------------------------------------------------
' SECTION 3: Pointer Array Creation (pdim#)
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 3: Pointer Array Creation (pdim#)"
PRINTLN "============================================"
PRINTLN
' Test 1D pointer array creation
LET parr1d# = pdim#(5)
test("1D pointer array - ndims", 1, ndims(parr1d#))
test("1D pointer array - ubound(1)", 5, ubound(parr1d#, 1))
test("1D pointer array - lbound(1)", 1, lbound(parr1d#, 1))
test("1D pointer array - arraysize", 5, arraysize(parr1d#))
test("1D pointer array - arraytype", 2, arraytype(parr1d#))
testStr("1D pointer array - arraytypename$", "pointer", arraytypename$(parr1d#))
' Test 2D pointer array creation
LET parr2d# = pdim#(3, 4)
test("2D pointer array - ndims", 2, ndims(parr2d#))
test("2D pointer array - arraysize", 12, arraysize(parr2d#))
' ----------------------------------------------------------------------------
' SECTION 4: Numeric Array Get/Set (1-based indexing)
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 4: Numeric Array Get/Set"
PRINTLN "============================================"
PRINTLN
' Test 1D numeric array get/set
LET numArr# = dim#(5)
' Test initial values are zero
test("1D numeric - initial value at index 1", 0, narr_get(numArr#, 1))
test("1D numeric - initial value at index 5", 0, narr_get(numArr#, 5))
' Set and get values (narr_set# returns pointer, must capture)
LET _# = narr_set#(numArr#, 1, 100)
LET _# = narr_set#(numArr#, 3, 300)
LET _# = narr_set#(numArr#, 5, 500)
test("1D numeric - set/get index 1", 100, narr_get(numArr#, 1))
test("1D numeric - set/get index 3", 300, narr_get(numArr#, 3))
test("1D numeric - set/get index 5", 500, narr_get(numArr#, 5))
test("1D numeric - unchanged index 2", 0, narr_get(numArr#, 2))
' Test 2D numeric array get/set
LET num2d# = dim#(3, 4)
' Set corner and middle values
LET _# = narr_set#(num2d#, 1, 1, 11)
LET _# = narr_set#(num2d#, 3, 4, 34)
LET _# = narr_set#(num2d#, 2, 2, 22)
test("2D numeric - set/get (1,1)", 11, narr_get(num2d#, 1, 1))
test("2D numeric - set/get (3,4)", 34, narr_get(num2d#, 3, 4))
test("2D numeric - set/get (2,2)", 22, narr_get(num2d#, 2, 2))
test("2D numeric - unchanged (1,2)", 0, narr_get(num2d#, 1, 2))
' Test 3D numeric array get/set
LET num3d# = dim#(2, 3, 4)
LET _# = narr_set#(num3d#, 1, 1, 1, 111)
LET _# = narr_set#(num3d#, 2, 3, 4, 234)
test("3D numeric - set/get (1,1,1)", 111, narr_get(num3d#, 1, 1, 1))
test("3D numeric - set/get (2,3,4)", 234, narr_get(num3d#, 2, 3, 4))
' Test floating-point values
LET _# = narr_set#(numArr#, 2, 3.14159)
test("1D numeric - floating point value", 3.14159, narr_get(numArr#, 2))
' Test negative values
LET _# = narr_set#(numArr#, 4, -999.5)
test("1D numeric - negative value", -999.5, narr_get(numArr#, 4))
' ----------------------------------------------------------------------------
' SECTION 5: String Array Get/Set (1-based indexing)
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 5: String Array Get/Set"
PRINTLN "============================================"
PRINTLN
' Test 1D string array get/set
LET strArr# = sdim#(5)
' Test initial values are empty strings
testStr("1D string - initial value at index 1", "", sarr_get$(strArr#, 1))
testStr("1D string - initial value at index 5", "", sarr_get$(strArr#, 5))
' Set and get values (sarr_set# returns pointer, must capture)
LET _# = sarr_set#(strArr#, 1, "Hello")
LET _# = sarr_set#(strArr#, 3, "World")
LET _# = sarr_set#(strArr#, 5, "Plan9Basic")
testStr("1D string - set/get index 1", "Hello", sarr_get$(strArr#, 1))
testStr("1D string - set/get index 3", "World", sarr_get$(strArr#, 3))
testStr("1D string - set/get index 5", "Plan9Basic", sarr_get$(strArr#, 5))
testStr("1D string - unchanged index 2", "", sarr_get$(strArr#, 2))
' Test 2D string array get/set
LET str2d# = sdim#(3, 4)
LET _# = sarr_set#(str2d#, 1, 1, "Top-Left")
LET _# = sarr_set#(str2d#, 3, 4, "Bottom-Right")
LET _# = sarr_set#(str2d#, 2, 2, "Center")
testStr("2D string - set/get (1,1)", "Top-Left", sarr_get$(str2d#, 1, 1))
testStr("2D string - set/get (3,4)", "Bottom-Right", sarr_get$(str2d#, 3, 4))
testStr("2D string - set/get (2,2)", "Center", sarr_get$(str2d#, 2, 2))
testStr("2D string - unchanged (1,2)", "", sarr_get$(str2d#, 1, 2))
' Test 3D string array get/set
LET str3d# = sdim#(2, 3, 4)
LET _# = sarr_set#(str3d#, 1, 1, 1, "Origin")
LET _# = sarr_set#(str3d#, 2, 3, 4, "Far Corner")
testStr("3D string - set/get (1,1,1)", "Origin", sarr_get$(str3d#, 1, 1, 1))
testStr("3D string - set/get (2,3,4)", "Far Corner", sarr_get$(str3d#, 2, 3, 4))
' Test special characters in strings
LET _# = sarr_set#(strArr#, 2, "Hello, World! @#$%^&*()")
testStr("1D string - special characters", "Hello, World! @#$%^&*()", sarr_get$(strArr#, 2))
' Test Unicode characters
LET _# = sarr_set#(strArr#, 4, "Olá Mundo! 日本語")
testStr("1D string - Unicode characters", "Olá Mundo! 日本語", sarr_get$(strArr#, 4))
' ----------------------------------------------------------------------------
' SECTION 6: Pointer Array Get/Set
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 6: Pointer Array Get/Set"
PRINTLN "============================================"
PRINTLN
' Create pointer array and test with other arrays as values
LET ptrArr# = pdim#(5)
' Store pointers to other arrays
LET _# = parr_set#(ptrArr#, 1, numArr#)
LET _# = parr_set#(ptrArr#, 2, strArr#)
LET _# = parr_set#(ptrArr#, 3, num2d#)
' Retrieve and verify (using PntToNum for comparison since we can't compare pointers directly)
LET ptr1# = parr_get#(ptrArr#, 1)
LET ptr2# = parr_get#(ptrArr#, 2)
LET ptr3# = parr_get#(ptrArr#, 3)
' Verify the retrieved pointers are valid arrays
test("Pointer array - stored numeric array type", 0, arraytype(ptr1#))
test("Pointer array - stored string array type", 1, arraytype(ptr2#))
test("Pointer array - stored 2D numeric array dims", 2, ndims(ptr3#))
' Verify data through retrieved pointers
test("Pointer array - access through retrieved ptr", 100, narr_get(ptr1#, 1))
testStr("Pointer array - access string through retrieved ptr", "Hello", sarr_get$(ptr2#, 1))
' Test 2D pointer array
LET ptr2d# = pdim#(2, 3)
LET _# = parr_set#(ptr2d#, 1, 1, numArr#)
LET _# = parr_set#(ptr2d#, 2, 3, strArr#)
LET retrieved1# = parr_get#(ptr2d#, 1, 1)
LET retrieved2# = parr_get#(ptr2d#, 2, 3)
test("2D pointer array - stored numeric type", 0, arraytype(retrieved1#))
test("2D pointer array - stored string type", 1, arraytype(retrieved2#))
' ----------------------------------------------------------------------------
' SECTION 7: 1-Based Indexing Verification
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 7: 1-Based Indexing Verification"
PRINTLN "============================================"
PRINTLN
' Create array and fill with index values
LET idxTest# = dim#(10)
FOR i = 1 TO 10
  LET _# = narr_set#(idxTest#, i, i * 10)
NEXT
' Verify 1-based indexing
test("Index 1 has value 10", 10, narr_get(idxTest#, 1))
test("Index 5 has value 50", 50, narr_get(idxTest#, 5))
test("Index 10 has value 100", 100, narr_get(idxTest#, 10))
' Verify lbound is always 1
test("lbound is always 1 for dim 1", 1, lbound(idxTest#, 1))
' 2D indexing test
LET idx2d# = dim#(3, 3)
FOR row = 1 TO 3
  FOR col = 1 TO 3
    LET _# = narr_set#(idx2d#, row, col, row * 10 + col)
  NEXT col
NEXT row
test("2D index (1,1) = 11", 11, narr_get(idx2d#, 1, 1))
test("2D index (1,3) = 13", 13, narr_get(idx2d#, 1, 3))
test("2D index (2,2) = 22", 22, narr_get(idx2d#, 2, 2))
test("2D index (3,1) = 31", 31, narr_get(idx2d#, 3, 1))
test("2D index (3,3) = 33", 33, narr_get(idx2d#, 3, 3))
' ----------------------------------------------------------------------------
' SECTION 8: Overwrite Values
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 8: Overwrite Values"
PRINTLN "============================================"
PRINTLN
' Test overwriting numeric values
LET overArr# = dim#(3)
LET _# = narr_set#(overArr#, 1, 100)
test("Before overwrite", 100, narr_get(overArr#, 1))
LET _# = narr_set#(overArr#, 1, 999)
test("After overwrite", 999, narr_get(overArr#, 1))
' Test overwriting string values
LET overStr# = sdim#(3)
LET _# = sarr_set#(overStr#, 1, "Original")
testStr("Before string overwrite", "Original", sarr_get$(overStr#, 1))
LET _# = sarr_set#(overStr#, 1, "Replaced")
testStr("After string overwrite", "Replaced", sarr_get$(overStr#, 1))
' ----------------------------------------------------------------------------
' SECTION 9: Large Arrays
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 9: Large Arrays"
PRINTLN "============================================"
PRINTLN
' Test larger 1D array
LET large1d# = dim#(1000)
test("Large 1D array - arraysize", 1000, arraysize(large1d#))
LET _# = narr_set#(large1d#, 1, 1)
LET _# = narr_set#(large1d#, 500, 500)
LET _# = narr_set#(large1d#, 1000, 1000)
test("Large 1D - first element", 1, narr_get(large1d#, 1))
test("Large 1D - middle element", 500, narr_get(large1d#, 500))
test("Large 1D - last element", 1000, narr_get(large1d#, 1000))
' Test larger 2D array
LET large2d# = dim#(100, 100)
test("Large 2D array - arraysize", 10000, arraysize(large2d#))
LET _# = narr_set#(large2d#, 1, 1, 11)
LET _# = narr_set#(large2d#, 50, 50, 5050)
LET _# = narr_set#(large2d#, 100, 100, 100100)
test("Large 2D - corner (1,1)", 11, narr_get(large2d#, 1, 1))
test("Large 2D - center (50,50)", 5050, narr_get(large2d#, 50, 50))
test("Large 2D - corner (100,100)", 100100, narr_get(large2d#, 100, 100))
' ----------------------------------------------------------------------------
' SECTION 10: Array Type Safety
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 10: Array Type Safety"
PRINTLN "============================================"
PRINTLN
' Create each array type and verify type codes
LET typeNum# = dim#(3)
LET typeStr# = sdim#(3)
LET typePtr# = pdim#(3)
test("Numeric array type code is 0", 0, arraytype(typeNum#))
test("String array type code is 1", 1, arraytype(typeStr#))
test("Pointer array type code is 2", 2, arraytype(typePtr#))
testStr("Numeric arraytypename$ is 'numeric'", "numeric", arraytypename$(typeNum#))
testStr("String arraytypename$ is 'string'", "string", arraytypename$(typeStr#))
testStr("Pointer arraytypename$ is 'pointer'", "pointer", arraytypename$(typePtr#))
' ----------------------------------------------------------------------------
' SECTION 11: Edge Cases - Single Element Arrays
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 11: Single Element Arrays"
PRINTLN "============================================"
PRINTLN
' Test single-element arrays
LET single1# = dim#(1)
test("Single element numeric - arraysize", 1, arraysize(single1#))
test("Single element numeric - ndims", 1, ndims(single1#))
test("Single element numeric - ubound(1)", 1, ubound(single1#, 1))
LET _# = narr_set#(single1#, 1, 42)
test("Single element numeric - set/get", 42, narr_get(single1#, 1))
LET singleStr# = sdim#(1)
LET _# = sarr_set#(singleStr#, 1, "Only")
testStr("Single element string - set/get", "Only", sarr_get$(singleStr#, 1))
' Single element 2D (1x1)
LET single2d# = dim#(1, 1)
test("1x1 2D array - arraysize", 1, arraysize(single2d#))
LET _# = narr_set#(single2d#, 1, 1, 99)
test("1x1 2D array - set/get", 99, narr_get(single2d#, 1, 1))
' ----------------------------------------------------------------------------
' SECTION 12: Mixed Dimension Sizes
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 12: Mixed Dimension Sizes"
PRINTLN "============================================"
PRINTLN
' Test arrays with very different dimension sizes
LET mixed1# = dim#(1, 100)
test("1x100 array - ndims", 2, ndims(mixed1#))
test("1x100 array - ubound(1)", 1, ubound(mixed1#, 1))
test("1x100 array - ubound(2)", 100, ubound(mixed1#, 2))
test("1x100 array - arraysize", 100, arraysize(mixed1#))
LET mixed2# = dim#(100, 1)
test("100x1 array - ndims", 2, ndims(mixed2#))
test("100x1 array - ubound(1)", 100, ubound(mixed2#, 1))
test("100x1 array - ubound(2)", 1, ubound(mixed2#, 2))
test("100x1 array - arraysize", 100, arraysize(mixed2#))
' Asymmetric 3D array
LET asym3d# = dim#(2, 10, 5)
test("2x10x5 array - ndims", 3, ndims(asym3d#))
test("2x10x5 array - ubound(1)", 2, ubound(asym3d#, 1))
test("2x10x5 array - ubound(2)", 10, ubound(asym3d#, 2))
test("2x10x5 array - ubound(3)", 5, ubound(asym3d#, 3))
test("2x10x5 array - arraysize", 100, arraysize(asym3d#))
' ----------------------------------------------------------------------------
' SECTION 13: Sequential Fill and Verify
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 13: Sequential Fill and Verify"
PRINTLN "============================================"
PRINTLN
' Fill a 2D array sequentially and verify all values
LET seq2d# = dim#(5, 5)
LET counter = 0
FOR r = 1 TO 5
  FOR c = 1 TO 5
    counter = counter + 1
    LET _# = narr_set#(seq2d#, r, c, counter)
  NEXT
NEXT
test("Sequential fill - total elements", 25, arraysize(seq2d#))
test("Sequential fill - (1,1) = 1", 1, narr_get(seq2d#, 1, 1))
test("Sequential fill - (1,5) = 5", 5, narr_get(seq2d#, 1, 5))
test("Sequential fill - (2,1) = 6", 6, narr_get(seq2d#, 2, 1))
test("Sequential fill - (3,3) = 13", 13, narr_get(seq2d#, 3, 3))
test("Sequential fill - (5,5) = 25", 25, narr_get(seq2d#, 5, 5))
' Verify all values are correct
LET allCorrect = 1
counter = 0
FOR r = 1 TO 5
  FOR c = 1 TO 5
    counter = counter + 1
    IF narr_get(seq2d#, r, c) <> counter THEN
      allCorrect = 0
    END IF
  NEXT
NEXT
test("Sequential fill - all 25 values correct", 1, allCorrect)
' ----------------------------------------------------------------------------
' SECTION 14: String Array with Empty and Long Strings
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "SECTION 14: Empty and Long Strings"
PRINTLN "============================================"
PRINTLN
LET strTest# = sdim#(5)
' Empty string
LET _# = sarr_set#(strTest#, 1, "")
testStr("Empty string storage", "", sarr_get$(strTest#, 1))
' Single character
LET _# = sarr_set#(strTest#, 2, "X")
testStr("Single character storage", "X", sarr_get$(strTest#, 2))
' Long string
LET longStr$ = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
longStr$ = longStr$ + longStr$ + longStr$ + longStr$
LET _# = sarr_set#(strTest#, 3, longStr$)
testStr("Long string storage", longStr$, sarr_get$(strTest#, 3))
test("Long string length", len(longStr$), len(sarr_get$(strTest#, 3)))
' ----------------------------------------------------------------------------
' TEST SUMMARY
' ----------------------------------------------------------------------------
PRINTLN
PRINTLN "============================================"
PRINTLN "TEST SUMMARY"
PRINTLN "============================================"
PRINTLN
PRINTLN "Total tests: "; testNum
PRINTLN "Passed: "; passed
PRINTLN "Failed: "; failed
PRINTLN
IF failed = 0 THEN
  PRINTLN "*** ALL TESTS PASSED! ***"
ELSE
  PRINTLN "*** SOME TESTS FAILED - Review output above ***"
END IF
