' =============================================
' Plan9Basic - SysLib Test
' Tests: System paths and file operations
' =============================================
PRINTLN "=== SysLib Function Tests ==="
PRINTLN ""
' System paths
PRINTLN "--- System Paths ---"
PRINTLN "Home: "; homepath$()
PRINTLN "Temp: "; temppath$()
PRINTLN "Documents: "; documentspath$()
PRINTLN "Downloads: "; downloadspath$()
PRINTLN "Pictures: "; picturespath$()
PRINTLN "Music: "; musicpath$()
PRINTLN "Movies: "; moviespath$()
PRINTLN "Cache: "; cachepath$()
PRINTLN "Public: "; publicpath$()
PRINTLN "Library: "; librarypath$()
PRINTLN ""
' Path separators
PRINTLN "--- Path Separators ---"
PRINTLN "Directory separator: ["; dirseparator$(); "]"
PRINTLN "Alt separator: ["; altseparator$(); "]"
PRINTLN "Path separator: ["; pathseparator$(); "]"
PRINTLN ""
' File path manipulation
PRINTLN "--- Path Manipulation ---"
filepath$ = homepath$() + "test.bas"
PRINTLN "Full path: "; filepath$
PRINTLN "File name: "; extractfilename$(filepath$)
PRINTLN "File path: "; extractfilepath$(filepath$)
PRINTLN "Extension: "; extractfileext$(filepath$)
PRINTLN "Change to .txt: "; changefileext$(filepath$, ".txt")
PRINTLN ""
' Random file names
PRINTLN "--- Random Filenames ---"
PRINTLN "Random: "; randomfilename$()
PRINTLN "GUID (sep): "; guidfilename$(1)
PRINTLN "GUID (no sep): "; guidfilename$(0)
PRINTLN "Temp file: "; tempfilename$()
PRINTLN ""
' Environment variables
PRINTLN "--- Environment Variables ---"
PRINTLN "PATH (first 60 chars): "; left$(environ$("PATH"), 60); "..."
PRINTLN ""
' Command line
PRINTLN "--- Command Line ---"
PRINTLN "Parameter count: "; paramcount()
PRINTLN "Program (param 0): "; paramstr$(0)
PRINTLN ""
' File operations demo
PRINTLN "--- File Operations ---"
testpath$ = temppath$()
PRINTLN "Temp path exists: "; fileexists(testpath$, 0)
PRINTLN ""
' Color functions
PRINTLN "--- Color Functions ---"
PRINTLN "Note: Color functions work with platform-specific formats"
PRINTLN ""
PRINTLN "=== SysLib Tests Complete ==="
