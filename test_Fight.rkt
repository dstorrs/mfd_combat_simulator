#lang racket

(require struct-plus-plus handy/test-more)
(require handy/list-utils handy/hash "Fight.rkt")

(heroes-filepath (build-path 'same "test-heroes.csv"))
(villains-filepath (build-path 'same "test-villains.csv"))
(define-values (heroes-rows villains-rows) (get-csv-data))

(test-suite
 "make-combatant"

 (define-values (headers buff-field-names fields num-fields)
  (parse-csv-data heroes-rows))

 (define data (cdr heroes-rows))
 (define fighter (make-fighter (car data) headers buff-field-names fields num-fields))
 (is fighter
     (combatant "Ami" 13993 0 1 0 0 1 "Kei" ""
                (list (buff "Mori" '("Ami" "Kei" "Naruto 01" "Prime") 0.06 0.06))
                '() '() 13993 0.3 0.3 14 3))
 )
