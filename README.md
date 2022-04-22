# rhash - Prototype Lifted Racket Hash for Rosette

## Expected Behaviors

```lisp
; Key:    Concrete
; Value:  Concrete
(define r0 (make-rhash 10))
(rhash-set! r0 "apple" 1)
(rhash-set! r0 42 1337)
(rhash-ref r0 "apple") ; expected: 1

; Key:    Symbolic Expression
; Value:  Concrete
(clear-vc!)
(define r1 (make-rhash 10))
(define-symbolic b1 integer?)
(if (> b1 0)
    (rhash-set! r1 "apple" 1)
    (rhash-set! r1 "banana" 2))
(rhash-ref r1 "banana") ; expected: (union [(> b 0) zvoid] [(! (> b 0)) 2])

; Key:    Symbolic Expression (union)
; Value:  Concrete
(clear-vc!)
(define r2 (make-rhash 10))
(define-symbolic b2 integer?)
(define l2 (list 1 2))
(define k2 (list-ref l2 b2))
(rhash-set! r2 k2 "apple")
(rhash-ref r2 2) ; expected: (union [(= 0 b) 2] [(= 1 b) zvoid])
(solve (assert (rhash-has-key? z2 2))) ; expected: b2=1

; Key:    Symbolic Expression (union)
; Value:  Symbolic Expression
(clear-vc!)
(define r4 (make-rhash 10))
(define-symbolic b4 integer?)
(define l4 (list "apple" "banana" "cat" "dog"))
(define m4 (list 999 888 777 666))
(define k4 (list-ref l4 b4))
(define v4 (list-ref m4 b4))
(rhash-set! r4 k4 v4)
(printf "4-0: ~v\n" (solve (assert (equal? 777 (rhash-ref r4 "banana"))))) ; expected: unsat
(printf "4-1: ~v\n" (solve (assert (equal? 888 (rhash-ref r4 "banana"))))) ; expected: b4=1

; Symbolic Execution + Update
(clear-vc!)
(define r6 (make-rhash 10))
(define-symbolic b6 integer?)
(if (> b6 29)
	(rhash-set! r6 "uurr" 87)
	(rhash-set! r6 "jjkk" 99)
)
(if (< b6 77)
	(rhash-set! r6 "uurr" 101)
	(rhash-set! r6 "jjkk" 202)
)
(printf "6-0: ~v\n" (solve (assert (equal? 101 (rhash-ref r6 "uurr"))))) ; expected: 29<b6<77
; jjkk --- 29 --- uurr
; uurr --- 77 --- jjkk
(printf "6-1: ~v\n" (solve (assert (not (rhash-has-key? r6 "uurr"))))) ; expected: unsat, because b needs to be: b<=29 and b>=77
(printf "6-2: ~v\n" (solve (assert (rhash-has-key? r6 "uurr")))) ; expected: 29<b<77

; Key:    Symbolic Constant
; Value:  Concrete
(clear-vc!)
(define r7 (make-rhash 10))
(define-symbolic b7 integer?)
(rhash-set! r7 b7 "apple")
(rhash-ref r7 b7) ; expected: "apple"
(solve (assert (equal? "apple" (rhash-ref r7 2)))) ; expected: b7=2

; rhash Size Expansion
(clear-vc!)
(define r8 (make-rhash 4))
(define l8 (list 1 2 3 4 5))
(define-symbolic b8 integer?)
(define k8 (list-ref l8 b8))
(rhash-set r8 k8 "apple") ; expected: no fail

```

## Desired Functionality
```
; make-rhash      - create a new rhash
; rhash-keys      - return all keys (ignoring vc)
; rhash-values    - return all values (ignoring vc)
; rhash-set       - set a key with a value
; rhash-ref       - return the value associated with a given key
; rhash-has-key?  - test whether the value of a given key exists or not
```

## Current Issues and Potential Solutions

1. Issue: Cannot create key to be a symbolic constant  
    Solution: Currently testing solutions, possibly use auxilliary data structure to keep track of only symbolic
    constants
 
2. Issue: No functionality to automatically expand rhash size   
    Solution: When calling rhash-set, check if new key-value pair will expand rhash past its size. If so, copy over all
    key-value pairs into a new larger rhash and add the new key-value pair there and return the new larger rhash.

3. Issue: Updating the same symbolic key multiple times results in long verification conditions   
    Solution: Currently ignoring
