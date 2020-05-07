#lang racket

(require struct-plus-plus handy/test-more)
(require handy/list-utils handy/hash "Fight.rkt")

(heroes-filepath (build-path 'same "test-heroes.csv"))
(villains-filepath (build-path 'same "test-villains.csv"))
(define-values (heroes-rows villains-rows) (get-csv-data))

(test-suite
 "make-fighter"

 (define-values (headers buff-field-names fields num-fields)
   (parse-csv-data heroes-rows))

 (for ([row (cdr heroes-rows)]
       [expected-name '("Ami" "Kei"  "Prime" "Naruto 01")]
       [correct (list (combatant "Ami" 13993 0 1 0 0 1 "Kei" ""
                                 (list (buff "Mori" '("Ami" "Kei" "Naruto 01" "Prime") 0.06 0.06))
                                 '() '() 13993 0.3 0.3 14 3)
                      (combatant "Kei" 5785 0 1 0 0 1 "" "" '() '() '() 5785 0.3 0.3 6 3)
                      (combatant "Prime" 17854 0 1 0.15 0 1 "" "" (list (buff "Teamwork" '("Naruto 01" "Prime") 0.1 0.1)) '() '() 17854 0.44999999999999996 0.3 18 3)
                      (combatant "Naruto 01" 17854 0 1 0.15 0 1 "Prime" "Prime" (list (buff "Teamwork" '("Naruto 01" "Prime") 0.1 0.1)) '() '() 17854 0.44999999999999996 0.3 18 3)

                      )]
       )
   (is (make-fighter row headers buff-field-names fields num-fields)
       correct
       (format "correctly made fighter ~a" expected-name))))

