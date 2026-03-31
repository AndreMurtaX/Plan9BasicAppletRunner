' =============================================================================
' Plan9Basic Applet Runner - NumLib Example
' Demonstrates: Mathematical functions
' =============================================================================

PRINTLN "=== NumLib - Mathematics Library ==="
PRINTLN ""

' --- Basic math ---
PRINTLN "--- Basic Math ---"
x = -7.85
PRINTLN "x = "; x
PRINTLN "abs(x)   = "; abs(x)
PRINTLN "cint(x)  = "; cint(x)
PRINTLN "fix(x)   = "; fix(x)
PRINTLN "frac(x)  = "; frac(x)
PRINTLN "int(x)   = "; int(x)
PRINTLN "round(x) = "; round(x)
PRINTLN "sgn(x)   = "; sgn(x)
PRINTLN ""

' --- Trigonometry ---
PRINTLN "--- Trigonometry ---"
pi = 3.14159265358979
PRINTLN "pi       = "; pi
PRINTLN "sin(pi/6)  = "; sin(pi / 6)
PRINTLN "cos(pi/3)  = "; cos(pi / 3)
PRINTLN "tan(pi/4)  = "; tan(pi / 4)
PRINTLN "asin(0.5)  = "; asin(0.5)
PRINTLN "acos(0.5)  = "; acos(0.5)
PRINTLN "atan(1)    = "; atan(1)
PRINTLN "atan2(1,1) = "; atan2(1, 1)
PRINTLN ""

' --- Angle conversion ---
PRINTLN "--- Angle Conversion ---"
PRINTLN "degtorad(180) = "; degtorad(180)
PRINTLN "radtodeg(pi)  = "; radtodeg(pi)
PRINTLN ""

' --- Logarithms & exponential ---
PRINTLN "--- Logarithms & Exponential ---"
PRINTLN "exp(1)     = "; exp(1)
PRINTLN "ln(exp(1)) = "; ln(exp(1))
PRINTLN "log2(8)    = "; log2(8)
PRINTLN "log10(100) = "; log10(100)
PRINTLN "sqr(144)   = "; sqr(144)
PRINTLN ""

' --- Min, Max, Power ---
PRINTLN "--- Min / Max / Power ---"
a = 42
b = 17
PRINTLN "a = "; a; ",  b = "; b
PRINTLN "min(a,b) = "; min(a, b)
PRINTLN "max(a,b) = "; max(a, b)
PRINTLN "2 ^ 10   = "; 2 ^ 10
PRINTLN ""

' --- Random numbers ---
PRINTLN "--- Random Numbers ---"
randomize()
PRINTLN "Five random floats (0-1):"
FOR i = 1 TO 5
  PRINTLN "  "; rnd()
NEXT i
PRINTLN "Five random integers (1-100):"
FOR i = 1 TO 5
  PRINTLN "  "; int(rnd() * 100) + 1
NEXT i
PRINTLN ""

PRINTLN "=== NumLib Example Complete ==="
