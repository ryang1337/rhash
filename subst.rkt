#lang rosette
(require rackunit)
(require/expose rosette/base/core/term (term-val))

(define (subst symterm substmapping)
    ; go through each of the consts in symconstlist, then evaluate symterm with
    ; the assertion that the first const in symconstlist is equal to
    ; the first value in sublist

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

(provide (all-defined-out))
