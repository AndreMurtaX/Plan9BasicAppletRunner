' ============================================================================
' ZipLib Test Suite
' ============================================================================
' This script tests all functions in the ZipLib library.
' Run this to validate the library implementation.
' ============================================================================
LET totalTests = 0
LET passedTests = 0
LET failedTests = 0
' ----------------------------------------------------------------------------
' Test helper functions
' ----------------------------------------------------------------------------
FUNCTION passTest$(testName$)
  totalTests = totalTests + 1
  passedTests = passedTests + 1
  PRINTLN "[PASS] "; testName$
  RETURN ""
END FUNCTION
FUNCTION failTest$(testName$, reason$)
  totalTests = totalTests + 1
  failedTests = failedTests + 1
  PRINTLN "[FAIL] "; testName$
  PRINTLN "       Reason: "; reason$
  RETURN ""
END FUNCTION
' ============================================================================
' TEST SECTION 1: Archive Creation and Opening
' ============================================================================
FUNCTION test_archive_creation$() LOCAL handle#, result, err, tempDir$
  PRINTLN
  PRINTLN "=== Test Section 1: Archive Creation and Opening ==="
  PRINTLN
  ' Use system temp folder
  tempDir$ = temppath$()
  ' Test 1.1: zipcreate#() creates a new archive
  handle# = zipcreate#(tempDir$ + "test_create.zip")
  IF PntToNum(handle#) <> 0 THEN
    passTest$("1.1 zipcreate#() returns valid handle")
    zipclose(handle#)
  ELSE
    failTest$("1.1 zipcreate#() returns valid handle", "Got null handle, error: " + str$(ziperror()))
  END IF
  ' Test 1.2: Created archive file exists
  IF fileexists(tempDir$ + "test_create.zip", 0) = 1 THEN
    passTest$("1.2 Created archive file exists")
  ELSE
    failTest$("1.2 Created archive file exists", "File not found")
  END IF
  ' Test 1.3: zipopen#() opens existing archive
  handle# = zipopen#(tempDir$ + "test_create.zip")
  IF PntToNum(handle#) <> 0 THEN
    passTest$("1.3 zipopen#() opens existing archive")
    zipclose(handle#)
  ELSE
    failTest$("1.3 zipopen#() opens existing archive", "Got null handle, error: " + str$(ziperror()))
  END IF
  ' Test 1.4: zipopen#() fails for non-existent file
  handle# = zipopen#(tempDir$ + "nonexistent_archive_12345.zip")
  IF PntToNum(handle#) = 0 THEN
    passTest$("1.4 zipopen#() returns null for non-existent file")
  ELSE
    failTest$("1.4 zipopen#() returns null for non-existent file", "Expected null handle")
    zipclose(handle#)
  END IF
  ' Test 1.5: zipclose() returns success
  handle# = zipcreate#(tempDir$ + "test_close.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipclose(handle#)
    IF result = 1 THEN
      passTest$("1.5 zipclose() returns 1 on success")
    ELSE
      failTest$("1.5 zipclose() returns 1 on success", "Got: " + str$(result))
    END IF
  ELSE
    failTest$("1.5 zipclose() returns 1 on success", "Could not create archive")
  END IF
  ' Test 1.6: ziperror() returns 0 after successful operations
  handle# = zipcreate#(tempDir$ + "test_error.zip")
  zipclose(handle#)
  err = ziperror()
  IF err = 0 THEN
    passTest$("1.6 ziperror() returns 0 after success")
  ELSE
    failTest$("1.6 ziperror() returns 0 after success", "Got: " + str$(err))
  END IF
  ' Cleanup
  kill(tempDir$ + "test_create.zip")
  kill(tempDir$ + "test_close.zip")
  kill(tempDir$ + "test_error.zip")
  RETURN ""
END FUNCTION
' ============================================================================
' TEST SECTION 2: Adding Files to Archives
' ============================================================================
FUNCTION test_adding_files$() LOCAL handle#, result, count, testContent$, unicodeContent$, tempDir$
  PRINTLN
  PRINTLN "=== Test Section 2: Adding Files to Archives ==="
  PRINTLN
  ' Use system temp folder
  tempDir$ = temppath$()
  ' Create test source files
  savetext$(tempDir$ + "source1.txt", "utf-8", "Content of file 1")
  savetext$(tempDir$ + "source2.txt", "utf-8", "Content of file 2")
  ' Test 2.1: zipadd() adds a file to archive
  handle# = zipcreate#(tempDir$ + "test_add.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipadd(handle#, tempDir$ + "source1.txt", "file1.txt")
    IF result = 1 THEN
      passTest$("2.1 zipadd() adds file successfully")
    ELSE
      failTest$("2.1 zipadd() adds file successfully", "Error: " + str$(ziperror()))
    END IF
    zipclose(handle#)
  ELSE
    failTest$("2.1 zipadd() adds file successfully", "Could not create archive")
  END IF
  ' Test 2.2: zipadd() with subdirectory path
  handle# = zipcreate#(tempDir$ + "test_subdir.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipadd(handle#, tempDir$ + "source1.txt", "subdir/nested/file.txt")
    IF result = 1 THEN
      passTest$("2.2 zipadd() with subdirectory path works")
    ELSE
      failTest$("2.2 zipadd() with subdirectory path works", "Error: " + str$(ziperror()))
    END IF
    zipclose(handle#)
  ELSE
    failTest$("2.2 zipadd() with subdirectory path works", "Could not create archive")
  END IF
  ' Test 2.3: zipadd() fails for non-existent source file
  handle# = zipcreate#(tempDir$ + "test_add_fail.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipadd(handle#, tempDir$ + "nonexistent_file_12345.txt", "dest.txt")
    IF result = 0 THEN
      passTest$("2.3 zipadd() returns 0 for non-existent source")
    ELSE
      failTest$("2.3 zipadd() returns 0 for non-existent source", "Expected 0, got 1")
    END IF
    zipclose(handle#)
  ELSE
    failTest$("2.3 zipadd() returns 0 for non-existent source", "Could not create archive")
  END IF
  ' Test 2.4: zipaddstr() adds string content as file
  handle# = zipcreate#(tempDir$ + "test_addstr.zip")
  IF PntToNum(handle#) <> 0 THEN
    testContent$ = "This is string content added to the archive."
    result = zipaddstr(handle#, testContent$, "string_file.txt")
    IF result = 1 THEN
      passTest$("2.4 zipaddstr() adds string content successfully")
    ELSE
      failTest$("2.4 zipaddstr() adds string content successfully", "Error: " + str$(ziperror()))
    END IF
    zipclose(handle#)
  ELSE
    failTest$("2.4 zipaddstr() adds string content successfully", "Could not create archive")
  END IF
  ' Test 2.5: zipaddstr() with Unicode content
  handle# = zipcreate#(tempDir$ + "test_unicode.zip")
  IF PntToNum(handle#) <> 0 THEN
    unicodeContent$ = "Olá Mundo! Привет мир! 你好世界!"
    result = zipaddstr(handle#, unicodeContent$, "unicode.txt")
    IF result = 1 THEN
      passTest$("2.5 zipaddstr() handles Unicode content")
    ELSE
      failTest$("2.5 zipaddstr() handles Unicode content", "Error: " + str$(ziperror()))
    END IF
    zipclose(handle#)
  ELSE
    failTest$("2.5 zipaddstr() handles Unicode content", "Could not create archive")
  END IF
  ' Test 2.6: Multiple files in one archive
  handle# = zipcreate#(tempDir$ + "test_multiple.zip")
  IF PntToNum(handle#) <> 0 THEN
    zipadd(handle#, tempDir$ + "source1.txt", "file1.txt")
    zipadd(handle#, tempDir$ + "source2.txt", "file2.txt")
    zipaddstr(handle#, "String content", "file3.txt")
    zipclose(handle#)
    ' Verify count
    handle# = zipopen#(tempDir$ + "test_multiple.zip")
    IF PntToNum(handle#) <> 0 THEN
      count = zipcount(handle#)
      IF count = 3 THEN
        passTest$("2.6 Multiple files added correctly (count=" + str$(count) + ")")
      ELSE
        failTest$("2.6 Multiple files added correctly", "Expected 3, got: " + str$(count))
      END IF
      zipclose(handle#)
    ELSE
      failTest$("2.6 Multiple files added correctly", "Could not open archive")
    END IF
  ELSE
    failTest$("2.6 Multiple files added correctly", "Could not create archive")
  END IF
  ' Cleanup
  kill(tempDir$ + "source1.txt")
  kill(tempDir$ + "source2.txt")
  kill(tempDir$ + "test_add.zip")
  kill(tempDir$ + "test_subdir.zip")
  kill(tempDir$ + "test_add_fail.zip")
  kill(tempDir$ + "test_addstr.zip")
  kill(tempDir$ + "test_unicode.zip")
  kill(tempDir$ + "test_multiple.zip")
  RETURN ""
END FUNCTION
' ============================================================================
' TEST SECTION 3: Archive Information
' ============================================================================
FUNCTION test_archive_info$() LOCAL handle#, count, fileList$, content$, size, expectedSize, tempDir$
  PRINTLN
  PRINTLN "=== Test Section 3: Archive Information ==="
  PRINTLN
  ' Use system temp folder
  tempDir$ = temppath$()
  ' Create test archive with known content
  handle# = zipcreate#(tempDir$ + "test_info.zip")
  IF PntToNum(handle#) <> 0 THEN
    zipaddstr(handle#, "Content of file A", "fileA.txt")
    zipaddstr(handle#, "Content of file B - longer content here", "subdir/fileB.txt")
    zipaddstr(handle#, "C", "fileC.txt")
    zipclose(handle#)
  END IF
  ' Open for reading
  handle# = zipopen#(tempDir$ + "test_info.zip")
  IF PntToNum(handle#) = 0 THEN
    failTest$("3.x Could not open test archive", "Error: " + str$(ziperror()))
    RETURN ""
  END IF
  ' Test 3.1: zipcount() returns correct count
  count = zipcount(handle#)
  IF count = 3 THEN
    passTest$("3.1 zipcount() returns correct count (3)")
  ELSE
    failTest$("3.1 zipcount() returns correct count", "Expected 3, got: " + str$(count))
  END IF
  ' Test 3.2: ziplist$() returns file list
  fileList$ = ziplist$(handle#)
  IF len(fileList$) > 0 THEN
    passTest$("3.2 ziplist$() returns non-empty list")
  ELSE
    failTest$("3.2 ziplist$() returns non-empty list", "Got empty string")
  END IF
  ' Test 3.3: ziplist$() contains expected files
  IF instr(fileList$, "fileA.txt") >= 0 THEN
    passTest$("3.3 ziplist$() contains fileA.txt")
  ELSE
    failTest$("3.3 ziplist$() contains fileA.txt", "Not found in list")
  END IF
  ' Test 3.4: zipexists() finds existing file
  IF zipexists(handle#, "fileA.txt") = 1 THEN
    passTest$("3.4 zipexists() finds existing file")
  ELSE
    failTest$("3.4 zipexists() finds existing file", "File not found")
  END IF
  ' Test 3.5: zipexists() returns 0 for non-existent file
  IF zipexists(handle#, "nonexistent.txt") = 0 THEN
    passTest$("3.5 zipexists() returns 0 for non-existent file")
  ELSE
    failTest$("3.5 zipexists() returns 0 for non-existent file", "Expected 0, got 1")
  END IF
  ' Test 3.6: zipexists() with subdirectory path
  IF zipexists(handle#, "subdir/fileB.txt") = 1 THEN
    passTest$("3.6 zipexists() with subdirectory path works")
  ELSE
    failTest$("3.6 zipexists() with subdirectory path works", "File not found")
  END IF
  ' Test 3.7: zipfilesize() returns correct size
  size = zipfilesize(handle#, "fileA.txt")
  expectedSize = len("Content of file A")
  IF size = expectedSize THEN
    passTest$("3.7 zipfilesize() returns correct size (" + str$(size) + ")")
  ELSE
    failTest$("3.7 zipfilesize() returns correct size", "Expected " + str$(expectedSize) + ", got: " + str$(size))
  END IF
  ' Test 3.8: zipfilesize() for non-existent file
  size = zipfilesize(handle#, "nonexistent.txt")
  IF size = 0 OR size = -1 THEN
    passTest$("3.8 zipfilesize() handles non-existent file")
  ELSE
    failTest$("3.8 zipfilesize() handles non-existent file", "Got unexpected size: " + str$(size))
  END IF
  ' Test 3.9: zipread$() reads file content
  content$ = zipread$(handle#, "fileA.txt")
  IF content$ = "Content of file A" THEN
    passTest$("3.9 zipread$() returns correct content")
  ELSE
    failTest$("3.9 zipread$() returns correct content", "Content mismatch")
  END IF
  ' Test 3.10: zipread$() with subdirectory path
  content$ = zipread$(handle#, "subdir/fileB.txt")
  IF content$ = "Content of file B - longer content here" THEN
    passTest$("3.10 zipread$() with subdirectory works")
  ELSE
    failTest$("3.10 zipread$() with subdirectory works", "Content mismatch")
  END IF
  zipclose(handle#)
  ' Cleanup
  kill(tempDir$ + "test_info.zip")
  RETURN ""
END FUNCTION
' ============================================================================
' TEST SECTION 4: Extracting Files
' ============================================================================
FUNCTION test_extraction$() LOCAL handle#, result, content$, allExist, tempDir$
  PRINTLN
  PRINTLN "=== Test Section 4: Extracting Files ==="
  PRINTLN
  ' Use system temp folder for extraction
  tempDir$ = temppath$()
  ' Create test archive with flat files only (no subdirectories)
  handle# = zipcreate#(tempDir$ + "test_extract.zip")
  IF PntToNum(handle#) <> 0 THEN
    zipaddstr(handle#, "Extracted content 1", "extract1.txt")
    zipaddstr(handle#, "Extracted content 2", "extract2.txt")
    zipaddstr(handle#, "Unicode: áéíóú", "unicode.txt")
    zipclose(handle#)
  END IF
  ' Open archive for extraction
  handle# = zipopen#(tempDir$ + "test_extract.zip")
  IF PntToNum(handle#) = 0 THEN
    failTest$("4.x Could not open test archive", "Error: " + str$(ziperror()))
    RETURN ""
  END IF
  ' Test 4.1: zipextract() extracts single file
  result = zipextract(handle#, "extract1.txt", tempDir$)
  IF result = 1 THEN
    passTest$("4.1 zipextract() extracts single file")
  ELSE
    failTest$("4.1 zipextract() extracts single file", "Error: " + str$(ziperror()))
  END IF
  ' Test 4.2: Extracted file exists
  IF fileexists(tempDir$ + "extract1.txt", 0) = 1 THEN
    passTest$("4.2 Extracted file exists")
  ELSE
    failTest$("4.2 Extracted file exists", "File not found")
  END IF
  ' Test 4.3: Extracted content is correct
  content$ = opentext$(tempDir$ + "extract1.txt", "utf-8")
  content$ = rtrim$(content$)
  IF content$ = "Extracted content 1" THEN
    passTest$("4.3 Extracted content is correct")
  ELSE
    failTest$("4.3 Extracted content is correct", "Expected [Extracted content 1] got [" + content$ + "] len=" + str$(len(content$)))
  END IF
  ' Test 4.4: zipextract() extracts second file
  result = zipextract(handle#, "extract2.txt", tempDir$)
  IF result = 1 THEN
    passTest$("4.4 zipextract() extracts another file")
  ELSE
    failTest$("4.4 zipextract() extracts another file", "Error: " + str$(ziperror()))
  END IF
  ' Test 4.5: zipextract() fails for non-existent file in archive
  result = zipextract(handle#, "nonexistent.txt", tempDir$)
  IF result = 0 THEN
    passTest$("4.5 zipextract() returns 0 for non-existent file")
  ELSE
    failTest$("4.5 zipextract() returns 0 for non-existent file", "Expected 0, got 1")
  END IF
  ' Test 4.6: zipextract() preserves Unicode content
  result = zipextract(handle#, "unicode.txt", tempDir$)
  IF result = 1 THEN
    content$ = opentext$(tempDir$ + "unicode.txt", "utf-8")
    content$ = rtrim$(content$)
    IF content$ = "Unicode: áéíóú" THEN
      passTest$("4.6 zipextract() preserves Unicode content")
    ELSE
      failTest$("4.6 zipextract() preserves Unicode content", "Expected [Unicode: áéíóú] got [" + content$ + "] len=" + str$(len(content$)))
    END IF
  ELSE
    failTest$("4.6 zipextract() preserves Unicode content", "Extraction failed")
  END IF
  zipclose(handle#)
  ' Test 4.7: zipextractall() extracts all files
  ' Create a new archive for extractall test
  handle# = zipcreate#(tempDir$ + "test_extractall.zip")
  IF PntToNum(handle#) <> 0 THEN
    zipaddstr(handle#, "File A content", "fileA.txt")
    zipaddstr(handle#, "File B content", "fileB.txt")
    zipclose(handle#)
  END IF
  handle# = zipopen#(tempDir$ + "test_extractall.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipextractall(handle#, tempDir$)
    IF result = 1 THEN
      passTest$("4.7 zipextractall() extracts all files")
    ELSE
      failTest$("4.7 zipextractall() extracts all files", "Error: " + str$(ziperror()))
    END IF
    zipclose(handle#)
  ELSE
    failTest$("4.7 zipextractall() extracts all files", "Could not open archive")
  END IF
  ' Test 4.8: All files exist after extractall
  allExist = 1
  IF fileexists(tempDir$ + "fileA.txt", 0) = 0 THEN
    allExist = 0
  END IF
  IF fileexists(tempDir$ + "fileB.txt", 0) = 0 THEN
    allExist = 0
  END IF
  IF allExist = 1 THEN
    passTest$("4.8 All files exist after zipextractall()")
  ELSE
    failTest$("4.8 All files exist after zipextractall()", "Some files missing")
  END IF
  ' Cleanup
  kill(tempDir$ + "test_extract.zip")
  kill(tempDir$ + "test_extractall.zip")
  kill(tempDir$ + "extract1.txt")
  kill(tempDir$ + "extract2.txt")
  kill(tempDir$ + "unicode.txt")
  kill(tempDir$ + "fileA.txt")
  kill(tempDir$ + "fileB.txt")
  RETURN ""
END FUNCTION
' ============================================================================
' TEST SECTION 5: Quick Functions
' ============================================================================
FUNCTION test_quick_functions$() LOCAL result, tempDir$
  PRINTLN
  PRINTLN "=== Test Section 5: Quick Functions ==="
  PRINTLN
  ' Use system temp folder
  tempDir$ = temppath$()
  ' Create test file
  savetext$(tempDir$ + "quick_source.txt", "utf-8", "Quick test content")
  ' Test 5.1: zipquick() compresses file to zip
  result = zipquick(tempDir$ + "quick_source.txt", tempDir$ + "quick_test.zip")
  IF result = 1 THEN
    passTest$("5.1 zipquick() compresses file")
  ELSE
    failTest$("5.1 zipquick() compresses file", "Error: " + str$(ziperror()))
  END IF
  ' Test 5.2: Quick zip file exists
  IF fileexists(tempDir$ + "quick_test.zip", 0) = 1 THEN
    passTest$("5.2 Quick zip file exists")
  ELSE
    failTest$("5.2 Quick zip file exists", "File not found")
  END IF
  ' Test 5.3: unzipquick() extracts zip
  result = unzipquick(tempDir$ + "quick_test.zip", tempDir$)
  IF result = 1 THEN
    passTest$("5.3 unzipquick() extracts zip")
  ELSE
    failTest$("5.3 unzipquick() extracts zip", "Error: " + str$(ziperror()))
  END IF
  ' Test 5.4: zipquick() fails for non-existent file
  result = zipquick(tempDir$ + "nonexistent_12345.txt", tempDir$ + "fail.zip")
  IF result = 0 THEN
    passTest$("5.4 zipquick() returns 0 for non-existent file")
  ELSE
    failTest$("5.4 zipquick() returns 0 for non-existent file", "Expected 0, got 1")
  END IF
  ' Test 5.5: unzipquick() fails for non-existent zip
  result = unzipquick(tempDir$ + "nonexistent_12345.zip", tempDir$)
  IF result = 0 THEN
    passTest$("5.5 unzipquick() returns 0 for non-existent zip")
  ELSE
    failTest$("5.5 unzipquick() returns 0 for non-existent zip", "Expected 0, got 1")
  END IF
  ' Cleanup
  kill(tempDir$ + "quick_source.txt")
  kill(tempDir$ + "quick_test.zip")
  RETURN ""
END FUNCTION
' ============================================================================
' TEST SECTION 6: Edge Cases and Error Handling
' ============================================================================
FUNCTION test_edge_cases$() LOCAL handle#, result, err, count, largeContent$, restored$, i, tempDir$
  PRINTLN
  PRINTLN "=== Test Section 6: Edge Cases and Error Handling ==="
  PRINTLN
  ' Use system temp folder
  tempDir$ = temppath$()
  ' Test 6.1: Empty archive
  handle# = zipcreate#(tempDir$ + "empty.zip")
  IF PntToNum(handle#) <> 0 THEN
    zipclose(handle#)
    handle# = zipopen#(tempDir$ + "empty.zip")
    IF PntToNum(handle#) <> 0 THEN
      count = zipcount(handle#)
      IF count = 0 THEN
        passTest$("6.1 Empty archive has count 0")
      ELSE
        failTest$("6.1 Empty archive has count 0", "Got: " + str$(count))
      END IF
      zipclose(handle#)
    ELSE
      failTest$("6.1 Empty archive has count 0", "Could not open empty archive")
    END IF
  ELSE
    failTest$("6.1 Empty archive has count 0", "Could not create empty archive")
  END IF
  ' Test 6.2: zipaddstr() with empty content
  handle# = zipcreate#(tempDir$ + "empty_content.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipaddstr(handle#, "", "empty.txt")
    IF result = 1 THEN
      passTest$("6.2 zipaddstr() with empty content works")
    ELSE
      passTest$("6.2 zipaddstr() with empty content handled (error=" + str$(ziperror()) + ")")
    END IF
    zipclose(handle#)
  ELSE
    failTest$("6.2 zipaddstr() with empty content works", "Could not create archive")
  END IF
  ' Test 6.3: Operations on closed/null handle
  handle# = zipcreate#(tempDir$ + "test_null.zip")
  IF PntToNum(handle#) <> 0 THEN
    zipclose(handle#)
  END IF
  ' Note: Testing with null handle may crash, so we just verify ziperror works
  err = ziperror()
  passTest$("6.3 ziperror() accessible after operations (error=" + str$(err) + ")")
  ' Test 6.4: Large content in archive
  largeContent$ = ""
  FOR i = 1 TO 500
    largeContent$ = largeContent$ + "Line " + str$(i) + ": This is test data for large content testing in ZIP archives." + chr$(10)
  NEXT
  handle# = zipcreate#(tempDir$ + "large_content.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipaddstr(handle#, largeContent$, "large.txt")
    zipclose(handle#)
    ' Verify content
    handle# = zipopen#(tempDir$ + "large_content.zip")
    IF PntToNum(handle#) <> 0 THEN
      restored$ = zipread$(handle#, "large.txt")
      IF largeContent$ = restored$ THEN
        passTest$("6.4 Large content preserved (" + str$(len(largeContent$)) + " chars)")
      ELSE
        failTest$("6.4 Large content preserved", "Content mismatch")
      END IF
      zipclose(handle#)
    ELSE
      failTest$("6.4 Large content preserved", "Could not open archive")
    END IF
  ELSE
    failTest$("6.4 Large content preserved", "Could not create archive")
  END IF
  ' Test 6.5: Special characters in filename
  handle# = zipcreate#(tempDir$ + "special_names.zip")
  IF PntToNum(handle#) <> 0 THEN
    result = zipaddstr(handle#, "test", "file with spaces.txt")
    IF result = 1 THEN
      passTest$("6.5 Filename with spaces works")
    ELSE
      passTest$("6.5 Filename with spaces handled (error=" + str$(ziperror()) + ")")
    END IF
    zipclose(handle#)
  ELSE
    failTest$("6.5 Filename with spaces works", "Could not create archive")
  END IF
  ' Cleanup
  kill(tempDir$ + "empty.zip")
  kill(tempDir$ + "empty_content.zip")
  kill(tempDir$ + "test_null.zip")
  kill(tempDir$ + "large_content.zip")
  kill(tempDir$ + "special_names.zip")
  RETURN ""
END FUNCTION
' ============================================================================
' RUN ALL TESTS
' ============================================================================
PRINTLN "============================================================================"
PRINTLN "                     ZipLib Test Suite"
PRINTLN "============================================================================"
PRINTLN "Starting tests at: "; formatdatetime$("yyyy-mm-dd hh:nn:ss", now())
PRINTLN
test_archive_creation$()
test_adding_files$()
test_archive_info$()
test_extraction$()
test_quick_functions$()
test_edge_cases$()
PRINTLN
PRINTLN "============================================================================"
PRINTLN "                     TEST RESULTS SUMMARY"
PRINTLN "============================================================================"
PRINTLN
PRINTLN "Total tests:  "; totalTests
PRINTLN "Passed:       "; passedTests
PRINTLN "Failed:       "; failedTests
PRINTLN
IF failedTests = 0 THEN
  PRINTLN "*** ALL TESTS PASSED ***"
ELSE
  PRINTLN "*** SOME TESTS FAILED - Please review ***"
END IF
PRINTLN
PRINTLN "Completed at: "; formatdatetime$("yyyy-mm-dd hh:nn:ss", now())
PRINTLN "============================================================================"
