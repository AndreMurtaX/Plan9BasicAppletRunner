' =============================================
' Plan9Basic - NumLib Test
' Tests: Mathematical functions
' =============================================
PRINTLN "=== NumLib Function Tests ==="
PRINTLN ""
' Basic math functions
PRINTLN "--- Basic Math ---"
x = -3.7
PRINTLN "x = "; x
PRINTLN "abs(x) = "; abs(x)
PRINTLN "cint(x) = "; cint(x)
PRINTLN "fix(x) = "; fix(x)
PRINTLN "frac(x) = "; frac(x)
PRINTLN "int(x) = "; int(x)
PRINTLN "round(x) = "; round(x)
PRINTLN ""
' Sign function
PRINTLN "--- Sign Function ---"
PRINTLN "sgn(-50) = "; sgn(-50)
PRINTLN "sgn(0) = "; sgn(0)
PRINTLN "sgn(50) = "; sgn(50)
PRINTLN ""
' Trigonometry
PRINTLN "--- Trigonometry ---"
pi = 3.14159265358979
angle = pi / 4
PRINTLN "angle = pi/4 = "; angle
PRINTLN "sin(angle) = "; sin(angle)
PRINTLN "cos(angle) = "; cos(angle)
PRINTLN "tan(angle) = "; tan(angle)
PRINTLN ""
' Inverse trigonometry
PRINTLN "--- Inverse Trigonometry ---"
PRINTLN "asin(0.5) = "; asin(0.5)
PRINTLN "acos(0.5) = "; acos(0.5)
PRINTLN "atan(1) = "; atan(1)
PRINTLN "atan2(1, 1) = "; atan2(1, 1)
PRINTLN ""
' Hyperbolic functions
PRINTLN "--- Hyperbolic Functions ---"
PRINTLN "sinh(1) = "; sinh(1)
PRINTLN "cosh(1) = "; cosh(1)
PRINTLN "tanh(1) = "; tanh(1)
PRINTLN ""
' Logarithms and exponential
PRINTLN "--- Logarithms & Exponential ---"
PRINTLN "exp(1) = e = "; exp(1)
PRINTLN "ln(2.71828) = "; ln(2.71828)
PRINTLN "log2(8) = "; log2(8)
PRINTLN "log10(100) = "; log10(100)
PRINTLN "sqr(16) = "; sqr(16)
PRINTLN ""
' Min/Max
PRINTLN "--- Min/Max ---"
a = 25
b = 17
PRINTLN "a = "; a; ", b = "; b
PRINTLN "min(a, b) = "; min(a, b)
PRINTLN "max(a, b) = "; max(a, b)
PRINTLN ""
' Random numbers
PRINTLN "--- Random Numbers ---"
randomize()
PRINTLN "5 random numbers (0-1):"
FOR i = 1 TO 5
  PRINTLN "  "; rnd()
NEXT
PRINTLN ""
PRINTLN "5 random integers (0-99):"
FOR i = 1 TO 5
  PRINTLN "  "; rnd(100)
NEXT
PRINTLN ""
' Degree/Radian conversion
PRINTLN "--- Angle Conversion ---"
PRINTLN "degtorad(180) = "; degtorad(180)
PRINTLN "radtodeg(3.14159) = "; radtodeg(3.14159)
PRINTLN ""
' Compare values
PRINTLN "--- Compare Values ---"
PRINTLN "cmpval(5, 5) = "; cmpval(5, 5)
PRINTLN "cmpval(3, 7) = "; cmpval(3, 7)
PRINTLN "cmpval(9, 2) = "; cmpval(9, 2)
PRINTLN ""
PRINTLN "=== NumLib Tests Complete ==="
