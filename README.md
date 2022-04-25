# rhash - Prototype Lifted Racket Hash for Rosette

## Expected Behaviors

**Note:** The `union` notation is abused in the following examples. According to the Rosette Guide, "the guards in a
symbolic union are disjoint: only one of them can ever be true." However, I choose to use it as an "if-else if-else"
operator with short circuiting (i.e. if the first guard is true, then ignore the rest of the guards, however they might
        also be true). This just makes notation more concise and readable

### Concrete Key

```lisp
; Scenario 1: Querying a Conrete Value with Concrete Key
r -> #rhash(("apple" . 1) ("banana" . 2))
(rhash-ref r "apple") -> 1
```

### Symbolic Union Keys / Values

```lisp
; Scenario 2: Inserting a Symbolic Union Key
r -> #rhash()
k -> (union [(< 0 b) "apple"] [(! (< 0 b)) "banana"])
v -> 2
(rhash-set! r k v) -> #rhash( ((union [(< 0 b) "apple"] [(! (< 0 b)) "banana"]) . 3) )

; Scenario 3: Querying a Concrete Value With Concrete Key
;             Where rhash has Symbolic Union Key
r -> #rhash( ((union [(< 0 b) "apple"] [(! (< 0 b)) "banana"]) . 3) )
k -> "apple"
(rhash-ref r k) -> (union [(< 0 b) 3] [else rvoid])

; Scenario 4: Querying a Concrete Value with Symbolic Union Key
;             Where rhash Has Concrete Key
r -> #rhash(("apple" . 1) ("banana" . 2))
k -> (union [(> c 10) "apple"] [else "banana"])
(rhash-ref r k) -> (union [(> c 10) 1] [else 2])

; Scenario 5: Querying a Concrete Value With Symbolic Union Key
;             Where rhash Has Symbolic Union Key
r -> #rhash( ((union [(< 0 b) "apple"] [(! (< 0 b)) "banana"]) . 3) )
k -> (union [(> c 10) "apple"] [else "banana"])
(rhash-ref r k) -> (union [(|| (&& (> c 10) (< 0 b))
                               (&& (! (> c 10)) (! (< 0 b)))) 3]
                          [else rvoid])

; Scenario 6: Querying a Symbolic Union Value With Symbolic Union Key
;             Where rhash Has Symbolic Union Key
r -> #rhash( ((union [(< 0 b) "apple"] [(! (< 0 b)) "banana"]) . 
               (union [(> c 10) "cat"] [else "dog"])) )
k -> (union [(< c 15) "apple"] [else "banana"])
(rhash-ref r k) -> (union [(|| (&& (> c 10) (< 0 b) (< c 15))  
                               (&& (! (< c 15)) (! (< 0 b)))) "cat"]
                          [(|| (&& (! (> c 10)) (< 0 b))
                               (&& (! (< c 15)) (! (> c 10)) (! (> c 10)))) "dog"]
                          [else rvoid])

; Scenario 7: Updating rhash With Symbolic Union Key-Symbolic Union Value Pair
;             When rhash Has Symbolic Union Key
r -> #rhash( ((union [(< 0 b) "apple"] [else "banana"]) . 3) )
k -> (union [(> c 0) "apple"] [else "cat"])
v -> (ite (> d 0) 4 5)
(rhash-set! r k v) -> #rhash( ("apple" . (union [(&& (> b 0) (> c 0) (> d 0)) 4]
                                                [(&& (> b 0) (> c 0) (! (> d 0))) 5]
                                                [(> b 0) 3]
                                                [else rvoid]))
                              ("banana" . (union [(! (> b 0)) 3]
                                                 [else rvoid]))
                              ("cat" . (union [(&& (! (> c 0)) (> d 0)) 4]
                                              [(&& (! (> c 0)) (! (> d 0))) 5]
                                              [else rvoid])) )
```

### Symbolic Constants

```lisp
; Scenario 8: Inserting a Symbolic Constant Key and Concrete Value
r -> #rhash()
k -> (define-symbolic b integer?)
v -> 2
(rhash-set! r k v) -> #rhash( (b . 2) )

; Scenario 9: Querying a Symbolic Constant Key and Concrete Value
r -> #rhash( (b . 2) )
k -> b
(rhash-ref r k) -> 2

; Scenario 9.5: Querying a Concrete Key
r -> #rhash ( (b . 2) )
k -> 4
(rhash-ref r k) -> (ite (= b 4) 2 rvoid)

; Scenario 10: Querying a Symbolic Constant Key and Concrete Value
;             When rhash Has Symbolic Union Key
r -> #rhash( ((ite (> b 0) 2 3) . "apple") )
k -> c
(rhash-ref r k) -> (union [(|| (&& (= c 2) (> b 0)) (&& (= c 3) (! (> b 0)))) "apple"] [else rvoid])

; Scenario 11: Querying a Symbolic Union Key and Concrete Value
;              When rhash Has Symbolic Constant
r -> #rhash( (b . 5) )
k -> (ite (> b 0) 2 3)
(rhash-ref r k) -> (ite* (⊢ (= b 2) 5) (⊢ (! (= b 2)) rvoid))

r -> #rhash( (b . 5) )
k -> (ite (> b 0) -1 3)
(rhash-ref r k) -> rvoid

; Scenario 12: Querying a Symbolic Union Key with Symbolic Constant Evaluation and Concrete Value
;              When rhash Has Symbolic Constant Key
r -> #rhash( (b . 5) )
k -> (union [(> b 0) c] [else d])
(rhash-ref r k) -> (union [(|| (&& (> b 0) (= c b))
                               (&& (! (> b 0)) (= d b))) 5]
                          [else rvoid])

; Scenario 13: Updating rhash With Concrete Key-Value Pair
;              When rhash Has Symbolic Constant Key
r -> #rhash( (b . 5) )
k -> 2
v -> 3
(rhash-set! r k v) -> #rhash( (b . (ite (= b 2) 3 5)) 
                              (2 . 3) )

; Scenario 14: Updating rhash With Concrete Key-Symbolic Union Value Pair
;              When rhash Has Symbolic Constant Key
r -> #rhash( (b . "apple") )
k -> 2
v -> (union [(> c 0) "banana"] [else "cat"])
(rhash-set! r k v) -> #rhash( (b . (union [(&& (= b 2) (> c 0)) "banana"]
                                          [(&& (= b 2) (! (> c 0))) "cat"]
                                          [else "apple"]))
                              (2 . (union [(> c 0) "banana"] [else "cat"])) )

; Scenario 15: Updating rhash With Symbolic Union Key-Concrete Value Pair
;              When rhash Has Symbolic Constant Key
r -> #rhash( (b . "apple") )
k -> (ite (> c 0) 2 3)
v -> "banana"
(rhash-set! r k v) -> #rhash( (b . (union [(|| (&& (= b 2) (> c 0))
                                               (&& (= b 3) (! (> c 0)))) "banana"]
                                          [else "apple"]))
                              (2 . (union [(> c 0) "banana"] [else rvoid]))
                              (3 . (union [(! (> c 0)) "banana"] [else rvoid])) )

; Scenario 16: Updating rhash With Symbolic Union Key-Symbolic Union Value Pair
;              When rhash Has Symbolic Constant Key
r -> #rhash( (b . "apple") )
k -> (ite (> c 0) 2 3)
v -> (union [(> d 0) "banana"] [else "cat"])
(rhash-set! r k v) -> #rhash( (b . (union [(|| (&& (= b 2) (> c 0) (> d 0)) 
                                               (&& (= b 3) (! (> c 0)) (> d 0))) "banana"]
                                          [(|| (&& (= b 2) (> c 0) (! (> d 0)))
                                               (&& (= b 3) (! (> c 0)) (! (> d 0)))) "cat"]
                                          [else "apple"]))
                              (2 . (union [(&& (> c 0) (> d 0)) "banana"]
                                          [(&& (> c 0) (! (> d 0))) "cat"]
                                          [else rvoid]))
                              (3 . (union [(&& (! (> c 0)) (> d 0)) "banana"]
                                          [(&& (! (> c 0)) (! (> d 0))) "cat"]
                                          [else rvoid])) )
```

### Symbolic Structs

```lisp
; Scenario 17: Inserting a Symbolic Struct with Symbolic Constant Field as a Key
r -> #rhash()
k -> struct s(b "apple") ; b is symbolic integer
v -> 1
(rhash-set! r k v) -> #rhash( ((s b "apple") . 1) )

; Scenario 18: Inserting a Symbolic Struct with Symbolic Union Field as a Key
r -> #rhash()
k -> struct s((union [(> b 0) 2] [else 3]) "apple")
v -> 1
; (rhash-set! r k v) -> #rhash( (union [(> b 0) (s 2 "apple")] [else (s 3 "apple")] . 1) )
(rhash-set! r k v) -> #rhash( ((s 2 "apple") . (ite (> b 0) 1 rvoid))
                              ((s 3 "apple") . (ite (! (> b 0)) 1 rvoid)) )

; Scenario 19: Querying a Symbolic Struct with Symbolic Union Field as a Key
r -> #rhash( (union [(> b 0) (s 2 "apple")] [else (s 3 "apple")] . 1) )
k -> (union [(> c 0) (s 2 "apple")] [else (s 3 "apple)])
(rhash-ref r k) -> (union [(|| (&& (> b 0) (> c 0))
                               (&& (! (> b 0)) (! (> c 0)))) 1]
                          [else rvoid])
```

### Other 'Trivial' Scenarios

Having `ite` keys is similar to symbolic `union`s and I believe they behave the same way, so I will not repeat both cases.  

Having symbolic constants as the value is similar to concrete constants as values. If they are referenced using
`rhash-ref`, then the symbolic constant will just be returned.  

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

2. Issue: Cannot create key to be struct containing symbolic fields   
    Solution: Leverage the `decomposible?` function to check if key is struct containing symbolic field, then go from
    there. Not yet solved.
 
3. Issue: No functionality to automatically expand rhash size   
    Solution: When calling rhash-set, check if new key-value pair will expand rhash past its size. If so, copy over all
    key-value pairs into a new larger rhash and add the new key-value pair there and return the new larger rhash.

4. Issue: Updating the same symbolic key multiple times results in long verification conditions   
    Solution: Currently ignoring
