#lang rosette
(require rackunit)
(require/expose rosette/base/core/term (term-val))
(error-print-width 1000000)

(define-symbolic x y integer?)

(define clist (build-list 1000 values))
 
(define key1 (+ (+ 1 y) x))
(define key2 (+ y (+ 1 x)))
(define key3 (+ (+ 2 y) x))
(define complex-key1 (* 2 (+ x y)))
(define complex-key2 (+ (* 2 x) (* 2 y)))


(define (subst symterm substmapping)
    (cond
        [(not (term? symterm)) symterm]
        [else
            (if (constant? symterm)
                (if (hash-has-key? substmapping symterm)
                    (hash-ref substmapping symterm)
                    symterm
                )
                (let* ([symval (term-val symterm)]
                       [op (list-ref symval 0)]
                       [val1 (list-ref symval 1)]
                       [val2 (list-ref symval 2)])
                     (op (subst val1 substmapping) (subst val2 substmapping))
                )
            )
        ]
    )
)

(define (init-sym-hash syms)
    (define (init-helper s h)
        (cond
            [(null? s) h]
            [else
                (hash-set! h (car s) 0)
                (init-helper (cdr s) h)
            ]
        )
    )
    
    (define res-hash (make-hash))
    (init-helper syms res-hash)
)

; returns a list of symbolic unions that contain all values of iters
(define (get-iterators iters num-symbolics)
    (define (get-iterators-helper union-iters num-symbolics)
        (cond
            [(equal? num-symbolics 0) union-iters]
            [else
                (define-symbolic* x integer?)
                (get-iterators-helper 
                    (cons (list-ref iters x) union-iters)
                    (sub1 num-symbolics)
                )
            ]
        )
    )

    (get-iterators-helper (list) num-symbolics)
)

; iters is the list of numbers you want to iterate on
(define (termeq? term1 term2 iters)
    (when (not (equal? (symbolics term1) (symbolics term2))) #f)

    (let* ([symbolics-list (symbolics term1)] ; list of all symbolic constants in term1
           [num-symbolics (length symbolics-list)]
           [iterators (get-iterators iters num-symbolics)] ; list of unions of concrete values for each symconst to iterate over
           [sym-mappings (init-sym-hash symbolics-list)]) ; mappings from symbolic constants to concrete values e.g. ((a->1) (b->2))
        (define (recur-forall count)
            (for*/all ([v (list-ref iterators count) #:exhaustive])
                (hash-set! sym-mappings (list-ref symbolics-list count) v)
                (define res1 (subst term1 sym-mappings))
                (define res2 (subst term2 sym-mappings))
                (if (= count (sub1 (length symbolics-list)))
                    (equal? res1 res2)
                    (and (equal? res1 res2) (recur-forall (add1 count)))
                )
            )
        )
        
        (recur-forall 0)
    )
)

(provide (all-defined-out))
