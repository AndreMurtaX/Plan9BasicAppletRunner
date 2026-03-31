' =============================================
' Plan9Basic - DO...LOOP Test
' Tests all DO...LOOP variants
' =============================================
PRINTLN "=========================================="
PRINTLN "       DO...LOOP STRUCTURE TESTS"
PRINTLN "=========================================="
PRINTLN ""
' ===========================================
' Test 1: DO...LOOP (infinite with EXIT)
' ===========================================
PRINTLN ">>> Test 1: DO...LOOP with BREAK <<<"
PRINTLN ""
count = 0
DO
  count = count + 1
  PRINTLN "Iteration: "; count
  IF count >= 5 THEN BREAK
LOOP
PRINTLN "Exited loop at count = "; count
PRINTLN ""
' ===========================================
' Test 2: DO WHILE...LOOP
' ===========================================
PRINTLN ">>> Test 2: DO WHILE...LOOP <<<"
PRINTLN ""
x = 1
DO WHILE x <= 5
  PRINTLN "x = "; x
  x = x + 1
LOOP
PRINTLN "Final x = "; x
PRINTLN ""
' ===========================================
' Test 3: DO UNTIL...LOOP
' ===========================================
PRINTLN ">>> Test 3: DO UNTIL...LOOP <<<"
PRINTLN ""
y = 10
DO UNTIL y < 5
  PRINTLN "y = "; y
  y = y - 2
LOOP
PRINTLN "Final y = "; y
PRINTLN ""
' ===========================================
' Test 4: DO...LOOP WHILE
' ===========================================
PRINTLN ">>> Test 4: DO...LOOP WHILE <<<"
PRINTLN ""
n = 1
DO
  PRINTLN "n = "; n
  n = n * 2
LOOP WHILE n < 100
PRINTLN "Final n = "; n
PRINTLN ""
' ===========================================
' Test 5: DO...LOOP UNTIL
' ===========================================
PRINTLN ">>> Test 5: DO...LOOP UNTIL <<<"
PRINTLN ""
m = 100
DO
  PRINTLN "m = "; m
  m = m - 15
LOOP UNTIL m <= 0
PRINTLN "Final m = "; m
PRINTLN ""
' ===========================================
' Test 6: Nested DO...LOOP
' ===========================================
PRINTLN ">>> Test 6: Nested DO...LOOP <<<"
PRINTLN ""
i = 1
DO WHILE i <= 3
  j = 1
  DO WHILE j <= 3
    PRINTLN "i="; i; ", j="; j
    j = j + 1
  LOOP
  i = i + 1
LOOP
PRINTLN ""
' ===========================================
' Test 7: CONTINUE in DO...LOOP
' ===========================================
PRINTLN ">>> Test 7: CONTINUE in DO...LOOP <<<"
PRINTLN ""
k = 0
DO WHILE k < 10
  k = k + 1
  IF k = 3 OR k = 7 THEN
    PRINTLN "Skipping "; k
    CONTINUE
  ENDIF
  PRINTLN "Processing "; k
LOOP
PRINTLN ""
' ===========================================
' Test 8: Factorial calculation
' ===========================================
PRINTLN ">>> Test 8: Factorial with DO...LOOP <<<"
PRINTLN ""
num = 5
result = 1
counter = num
DO WHILE counter > 0
  result = result * counter
  counter = counter - 1
LOOP
PRINTLN num; "! = "; result
PRINTLN ""
' ===========================================
' Test 9: Sum of series
' ===========================================
PRINTLN ">>> Test 9: Sum 1+2+...+10 <<<"
PRINTLN ""
sum = 0
i = 1
DO
  sum = sum + i
  i = i + 1
LOOP UNTIL i > 10
PRINTLN "Sum of 1 to 10 = "; sum
PRINTLN ""
PRINTLN "=========================================="
PRINTLN "   ALL DO...LOOP TESTS COMPLETED!"
PRINTLN "=========================================="
