' ============================================================================
' Host callbacks — verification script
' ============================================================================
' The engine no longer talks to FireMonkey. It asks the host application for
' the three things that need a person, through InputProc, ConfirmProc and
' YieldProc. This script exercises all three, plus the handle validation that
' replaced dereferencing whatever pointer a program hands back.
'
' Run it on every platform you ship. On Android in particular: the dialogs
' must be the asynchronous kind, and a stale handle must be refused rather
' than followed, because there a bad dereference kills the process instead of
' raising a catchable error.
' ============================================================================

PRINTLN "=== 1. YieldProc ==="
' Every PRINT goes through the yield path. If the window stays responsive
' while this loop runs, the host is pumping its message loop correctly.
FOR i = 1 TO 20
  PRINTLN "  line " + STR$(i)
NEXT i
PRINTLN "ok - if the UI never froze, YieldProc is wired"
PRINTLN ""

PRINTLN "=== 2. InputProc ==="
PRINTLN "A prompt should appear. Type a number, or cancel."

FUNCTION gotValue(v) LOCAL dummy
  PRINTLN "  the host returned: " + STR$(v)
  PRINTLN "  ok - InputProc is wired"
  PRINTLN "  (if no prompt appeared and this never printed, the host left it nil"
  PRINTLN "   and INPUT kept the default, which is also valid)"
  RETURN 0
END FUNCTION

INPUT "Plan9Basic", "Type a number:", 42, gotValue
PRINTLN ""

PRINTLN "=== 3. ConfirmProc (BREAKPOINT) ==="
PRINTLN "A yes/no dialog should appear. Answer YES to continue."
counter = 7
TRACE 1
BREAKPOINT "checking the host dialog", counter
TRACE 0
PRINTLN "if a dialog appeared and YES resumed, ConfirmProc is wired."
PRINTLN "if nothing appeared, the host left it nil and BREAKPOINT just continued."
PRINTLN ""

PRINTLN "=== 4. Handle validation ==="
' A real handle works.
a# = dim#(3)
a#[1] = 11
PRINTLN "  a real array handle reads back: " + STR$(narr_get(a#, 1))

' A fabricated pointer must be refused. This aborts the program with the
' library's own message — which is the point. Before HandleRegistry it
' dereferenced the address: recoverable on Windows, fatal on Android.
PRINTLN "  now passing an invented pointer; the program must stop with a"
PRINTLN "  message from ArrayLib, NOT crash the app:"
junk# = pointer#(305419896)
n = ndims(junk#)
PRINTLN "  FAILURE - this line should never be reached"
