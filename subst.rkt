#lang rosette

(define (subst symterm sublist)
    (define symconstlist (symbolics symterm))
    
    ; go through each of the consts in symconstlist, then evaluate symterm with
    ; the assertion that the first const in symconstlist is equal to
    ; the first value in sublist

    (cond
        [(null? symconstlist) symterm]
        [else
            (let* ([symconst (car symconstlist)]
                   [sub (car sublist)]
                   [symterm-subst (evaluate symterm (solve (assert (= symconst sub))))])
                (subst symterm-subst (cdr sublist))
            )
        ]
    )
)

(provide (all-defined-out))
