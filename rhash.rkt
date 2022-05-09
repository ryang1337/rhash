#lang rosette
(provide (except-out (all-defined-out)
    println-and-exit
))
(error-print-width 1000000)

; forewords (some clarifications for reference)
; 1. a term is a symbolic
; 2. an union is a symbolic
; 3. a list of terms is a symbolic (!!), but it's not a term nor a union
; 4. a union of list is a symbolic, a union, but not a term
; 5. a union is NOT a term, vice versa

; for panic use only
(define (println-and-exit msg)
    (printf "~a\n" msg)
    (exit 0)
)

(define zvoid 'zvoid)
(define (zvoid? obj)
    (cond
        [(symbolic? obj) (for/all ([p obj #:exhaustive]) (zvoid? p))]
        [else (equal? zvoid obj)]
    )
)

; cap - capacity, iv - initial value, ev - empty value, k2i - key to index map, vvec - value vector
(struct zhash (cap iv ev k2i vvec symtermvec) #:mutable #:transparent #:reflection-name 'zhash)
; by default, k2i is an empty hash, vvec is a vector of default value ev
(define (make-zhash cap #:iv [iv zvoid] #:ev [ev zvoid]) (zhash cap iv ev (make-hash) (make-vector cap iv) (list)))
(define (zhash-keys arg-zhash) (zhash-k2i arg-zhash))
(define (zhash-vals arg-zhash) (zhash-vvec arg-zhash))

(define (decomposible? v)
    (if (symbolic? v)
        ; symbolic
        (cond 
            ; a union is decomposible
            [(union? v) #t]

            ; symbolic constant is not decomposible
            [(constant? v) #f]

            ; for expression, it could be `ite` or other forms (e.g., +/-)
            ; we use reflecting provided publicly by rosette rather than hacking
            [(expression? v)
                (match v
                    ; (fixme) there are more builtin rosette operators that you need to consider
                    ;         e.g., bitvector->integer
                    [(expression op child ...) (or
                        (equal? 'ite* (object-name op))
                        (equal? 'ite (object-name op))
                    )]
                    [_ (println-and-exit "# [exception] you can't reach here.")] ; for debugging in case anyone overrides `expression`
                )
            ]

            ; (note) (important) this category usually corresponds to a collection that contains symbolic values
            ;                    note that `symbolic?` is contagious, it mark a value as symbolic as long as any
            ;                    of its member is symbolic
            ; e.g., a struct instance with a symbolic member belongs to this category, and regarding decomposibility,
            ; since it's for deciding whether one should use `for/all` (and whether new values will be revealed under `for/all`),
            ; this category does not require decomposing because `for/all` reveals no new values
            [else #f]
        )
        ; not symbolic, so not decomposible
        #f
    )
)

; return a copy of a newly constructed list with element in the designated position replaced by given one
; - arg-ind should be concrete, if not concrete, the caller should wrap a for/all first
; - arg-val can be anything
; - arg-list can be symbolic, but by construction, we don't need for/all here
(define (zhash-val-set! arg-zhash arg-ind arg-val)
    (when (or (not (integer? arg-ind)) (decomposible? arg-ind)) (println-and-exit (format "# [zhash-panic] zhash-val-set: arg-ind should be a concrete integer, got: ~a." arg-ind)))
    (let ([vvec (zhash-vvec arg-zhash)])
        (cond
            ; (note) vvec here in rosette can be
            ; - a concrete vector
            ; - a vector of terms, e.g., (list (ite ...) (ite ...)), whose length is fixed
            ; - (note) by construction, it will NOT be a union
            [(vector? vvec) (vector-set! vvec arg-ind arg-val)]
            [else (println-and-exit (format "# [zhash-panic] zhash-val-set: unsupported vector type, got: ~a." vvec))]
        )
    )
)

; check the key-index-map for existence of a key
; - arg-key should be concrete, if not concrete, the caller should wrap a for/all first
(define (zhash-key-exists? arg-zhash arg-key)
    (when (decomposible? arg-key) (println-and-exit (format "# [zhash-panic] zhash-key-exists?:
                                                                          arg-key should be concrete or symbolic term, got: ~a." arg-key)))
    (let ([k2i (zhash-k2i arg-zhash)])
        (hash-has-key? k2i arg-key)
    )
)

; TODO: change this for symbolic constants
; check the **factual** existence of a key
; if the corresponding value of this key is zvoid, it means the key is **factually** non-existent
(define (zhash-has-key? arg-zhash arg-key)
    (cond
        [(symbolic? arg-key) (for/all ([dkey arg-key #:exhaustive]) (zhash-has-key? arg-zhash dkey))]
        [else
            (if (zhash-key-exists? arg-zhash arg-key)
                ; key exists in the key-index-map, check whether it's zvoid/empty-val
                (let ([vvec (zhash-vvec arg-zhash)]
                      [k2i (zhash-k2i arg-zhash)]
                      [ev (zhash-ev arg-zhash)])
                    (if (equal? ev (vector-ref vvec (hash-ref k2i arg-key)))
                        #f ; zvoid/ev will be treated as key doesn't exist
                        #t ; otherwise the key exists
                    )
                )
                ; key doesn't exist in the key-index-map, directly return #f
                #f
            )
        ]
    )
)

; make sure arg-key exists in key-index-map
; if not, add it
(define (zhash-secure-key! arg-zhash arg-key)
    (printf "# securing key: ~a\n" arg-key)
    (cond
        [(decomposible? arg-key) (for/all ([dkey arg-key #:exhaustive]) (zhash-secure-key! arg-zhash dkey))]
        [else
            (when (not (zhash-key-exists? arg-zhash arg-key))
                (let ([k2i (zhash-k2i arg-zhash)])
                    (when (>= (hash-count k2i) (zhash-cap arg-zhash)) 
                        (println-and-exit (format "# [zhash-panic] zhash-secure-key!: zhash capacity exceeded, max is ~a, now is ~a" (zhash-cap arg-zhash) (hash-count k2i))))
                    ; (fixme) you probably want to temporarily clear the vc here
                    (hash-set! k2i arg-key (hash-count k2i)) ; add the key to the key-index-map
                )
            )
        ]
    )
)

; (note) if the key doesn't exist, the path will authmatically be cut by rosette, which is expected
(define (zhash-ref arg-zhash arg-key)
    (cond
        [(decomposible? arg-key) (for/all ([dkey arg-key #:exhaustive]) (zhash-ref arg-zhash dkey))]
        [else 
            (let ([vvec (zhash-vvec arg-zhash)]
                  [k2i (zhash-k2i arg-zhash)]
                  [stvec (zhash-symtermvec arg-zhash)])
                (cond
                    ; if arg-key is a sym term, check if it exists in the hash
                    ; if it does, then return its mapping
                    ; if it doesn't, return a union where arg-key is set equal to every key in the hash
                    [(term? arg-key)
                        (cond
                            [(hash-has-key? k2i arg-key)
                                (vector-ref vvec (hash-ref k2i arg-key))
                            ]
                            [else
                                (define (compare-keys keys)
                                    (cond
                                        [(not (null? keys))
                                            (define key (car keys))
                                            (if (= key arg-key)
                                                (vector-ref vvec (hash-ref k2i key))
                                                (compare-keys (cdr keys))
                                            )
                                        ]
                                        [else zvoid]
                                    )
                                )
                                (compare-keys (hash-keys k2i))
                            ]
                        )
                    ]
                    ; arg-key in this branch should be a constant
                    ; check if arg-key exists in the hash
                    ; if it does, then return its mapping
                    ; if not, check if there are sym terms in the symtermvec
                        ; if so, return a union where every sym term in the vec is set equal to the arg-key
                        ; if not, then return zvoid, as arg-key can never exist in the hash
                    [else
                        (if (hash-has-key? k2i arg-key)
                            (vector-ref vvec (hash-ref k2i arg-key))
                            (cond
                                [(not (null? stvec))
                                    (define (compare-keys sym-key-vec)
                                        (cond
                                            [(not (null? sym-key-vec))
                                                (define sym-key (car sym-key-vec))
                                                (if (= sym-key arg-key)
                                                    (vector-ref vvec (hash-ref k2i sym-key))
                                                    (compare-keys (cdr sym-key-vec))
                                                )
                                            ]
                                            [else zvoid]
                                        )
                                    )
                                    (compare-keys stvec)
                                ]
                                ; arg-key is a constant, is not in the hash table, and there
                                ; also exist no symbolic constants keys in the hash table
                                [else zvoid]
                            )
                        )
                    ]
                )
            )
        ]
    )
)

; (note) if the key doesn't exist, the path will authmatically be cut by rosette, which is expected
; this returns a copy of a newly set val-list
(define (zhash-set! arg-zhash arg-key arg-val)
    (define prev-hash-keys (hash-keys (zhash-k2i arg-zhash)))

    ; first secure all the keys
    ; this will update val-list to make sure of sufficient slots before actual filling of values
    (zhash-secure-key! arg-zhash arg-key)
    ; then set the value

    (define (exhaustive-set! ex-key)
        (cond
            [(decomposible? arg-key) (for/all ([dkey ex-key #:exhaustive]) (exhaustive-set! dkey))]
            [else
                (let* ([k2i (zhash-k2i arg-zhash)]
                       [ind (hash-ref k2i ex-key)]
                       [stvec (zhash-symtermvec arg-zhash)])
                    (zhash-val-set! arg-zhash ind arg-val)
                    (cond 
                        [(term? ex-key)
                            (set-zhash-symtermvec! arg-zhash (append stvec (list ex-key)))
                            (define (key-update old-key)
                                (when (= ex-key old-key)
                                    (zhash-val-set! arg-zhash (hash-ref k2i old-key) arg-val)
                                )
                            )
                            (for-each key-update prev-hash-keys)
                        ]
                        ; ex-key in this branch should be a constant
                        [else
                            (define (conditional-key-update old-key)
                                (when (&& (term? old-key) (= ex-key old-key))
                                    (zhash-val-set! arg-zhash (hash-ref k2i old-key) arg-val)
                                )
                            )
                            (for-each conditional-key-update prev-hash-keys)
                        ]
                                    
                    )
                )
            ]
        )
    )

    (display "hello")
    (exhaustive-set! arg-key)

)

(define (zhash-clear! arg-zhash)
    (hash-clear! (zhash-k2i arg-zhash))
    (vector-fill! (zhash-vvec arg-zhash) zvoid)
    (set-zhash-symtermvec! arg-zhash (list))
)

(define z (make-zhash 10))
(define l (list "apple" "banana"))
(define-symbolic b c integer?)
(define k (list-ref l b))
