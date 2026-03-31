' =============================================================================
' Plan9Basic Applet Runner - ZipLib Example
' Demonstrates: ZIP archive create, add, list, read, extract
' =============================================================================

PRINTLN "=== ZipLib - ZIP Archive Library ==="
PRINTLN ""

' --- Paths ---
baseDir$   = documentspath()
zipFile$   = baseDir$ + "example_archive.zip"
extractTo$ = baseDir$ + "zip_extracted"

PRINTLN "Archive    : "; zipFile$
PRINTLN "Extract to : "; extractTo$
PRINTLN ""

' --- Create a new ZIP archive ---
PRINTLN "--- Creating Archive ---"
z# = zipcreate#(zipFile$)
IF z# = pointer#(0) THEN
  PRINTLN "ERROR: could not create archive (error "; ziperror(); ")"
  STOP
END IF
PRINTLN "Archive created."
PRINTLN ""

' --- Add string content as virtual files ---
PRINTLN "--- Adding Files ---"
zipaddstr(z#, "readme.txt", "This archive was created by Plan9Basic ZipLib.")
zipaddstr(z#, "data/a.txt", "Contents of file A.")
zipaddstr(z#, "data/b.txt", "Contents of file B.")
zipaddstr(z#, "data/c.txt", "Contents of file C.")
PRINTLN "Added 4 entries."
PRINTLN ""

' --- Close and reopen for reading ---
zipclose(z#)
PRINTLN "Archive closed and saved."
PRINTLN ""

z# = zipopen#(zipFile$)
PRINTLN "Archive re-opened for reading."
PRINTLN ""

' --- List contents using count() / line$() ---
PRINTLN "--- Archive Contents ---"
PRINTLN "Entry count : "; zipcount(z#)
fileList$ = ziplist$(z#)
n = count(fileList$)
PRINTLN "Files listed:"
FOR i = 1 TO n
  entry$ = trim$(line$(fileList$, i))
  IF len(entry$) > 0 THEN
    PRINTLN "  "; entry$
  END IF
NEXT i
PRINTLN ""

' --- Existence checks ---
PRINTLN "--- Existence Checks ---"
PRINTLN "Has readme.txt  : "; zipexists(z#, "readme.txt")
PRINTLN "Has missing.txt : "; zipexists(z#, "missing.txt")
PRINTLN ""

' --- Read file content directly ---
PRINTLN "--- Reading Entries ---"
PRINTLN "readme.txt  : "; zipread$(z#, "readme.txt")
PRINTLN "data/a.txt  : "; zipread$(z#, "data/a.txt")
PRINTLN "data/b.txt size : "; zipfilesize(z#, "data/b.txt"); " bytes"
PRINTLN ""

' --- Extract all files ---
PRINTLN "--- Extracting All Files ---"
ok = zipextractall(z#, extractTo$)
IF ok = 1 THEN
  PRINTLN "Extracted to: "; extractTo$
ELSE
  PRINTLN "Extraction error: "; ziperror()
END IF
PRINTLN ""

zipclose(z#)
PRINTLN "Archive closed."
PRINTLN ""

PRINTLN "=== ZipLib Example Complete ==="
