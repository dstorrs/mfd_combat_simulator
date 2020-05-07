#lang racket

(require struct-plus-plus handy/test-more)
(require handy/list-utils handy/hash "Fight.rkt")

(heroes-filepath (build-path 'same "test-heroes.csv"))
(villains-filepath (build-path 'same "test-villains.csv"))
(define-values (heroes-rows villains-rows) (get-csv-data))

;; (define-values (headers buff-field-names fields num-fields)
;;   (parse-csv-data heroes-rows))
;; (define kei-row (third heroes-rows))
;; (define kei (make-fighter kei-row headers buff-field-names fields num-fields))
;; kei

#;
(test-suite
 "make-fighter"


 (define-values (headers buff-field-names fields num-fields)
   (parse-csv-data heroes-rows))

 ; NOTE:  We are testing make-fighter, so buffs will not have been applied
 (for ([row (cdr heroes-rows)]
       [correct (list
                 ;          Name,XP,BonusXP,BonusHP,BonusToHit,BonusToDefend,AOE,BodyguardFor,LinkedTo,BuffName,BuffWho,BuffOffense,BuffDefense
                 (combatant "Ami" 13993 0 1 0 0 1 "Kei" ""
                            (list (buff "Mori" '("Ami" "Kei" "Naruto 01" "Prime") 0.06 0.03))
                            '() '() 13993 0.3 0.3 14 3)
                 (combatant "Kei" 5785 0 1 0 0 1 "INVALID-BG" "INVALID-LT" '() '() '() 5785 0.3 0.3 6 3)
                 (combatant "Prime" 17854 0 1 0.15 0 1 "" ""
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 01" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 02" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 03" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 04" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 05" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 06" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3)
                 (combatant "Naruto 07" 17854 0 1 0.15 0 1 "Prime" "Prime"
                            (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
                            '() '() 17854 0.44999999999999996 0.3 18 3))]
       [expected-bgf  (list "Kei" "INVALID-BG" "" "Prime"  "Prime" "Prime" "Prime" "Prime"  "Prime" "Prime")]
       [expected-lt   (list "" "INVALID-LT" "" "Prime"  "Prime" "Prime" "Prime" "Prime"  "Prime" "Prime")]
       )
   (define fighter (make-fighter row headers buff-field-names fields num-fields))
   (is fighter
       correct
       (format "correctly made fighter ~a" (combatant.Name fighter)))
   ; These were already tested implicitly, but put them here for human readability
   (is (combatant.BodyguardFor fighter)
       expected-bgf
       "bodyguard-for correct"
       )
   (is (combatant.LinkedTo fighter)
       expected-lt
       "linked-to correct")
   ))


(test-suite
 "make-combatants"
 (define-values (headers buff-field-names fields num-fields)
   (parse-csv-data heroes-rows))

 (define final-fighters
   (list
    ;          Name,XP,BonusXP,BonusHP,BonusToHit,BonusToDefend,AOE,BodyguardFor,LinkedTo,BuffName,BuffWho,BuffOffense,BuffDefense
    (combatant "Ami" 13993 0 1 0 0 1 "Kei" ""
               (list (buff "Mori" '("Ami" "Kei" "Naruto 01" "Prime") 0.06 0.03))
               '() '() 13993 0.36 0.32999999999999996 14 14 14 3)
    (combatant "Kei" 5785 0 1 0 0 1 "" "" '() '("Ami") '() 5785 0.36 0.32999999999999996 6 6 6 3)
    (combatant "Naruto 01" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 24 40 3)
    (combatant "Naruto 02" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 23 39 3)
    (combatant "Naruto 03" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 23 39 3)
    (combatant "Naruto 04" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 23 39 3)
    (combatant "Naruto 05" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 23 39 3)
    (combatant "Naruto 06" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 23 39 3)
    (combatant "Naruto 07" 17854 0 1 0.15 0 1 "Prime" "Prime"
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '() '() 17854 0.99 0.9 18 23 39 3)
    (combatant "Prime" 17854 0 1 0.15 0 1 "" ""
               (list (buff "Teamwork" '("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.23))
               '("Naruto 07"  "Naruto 06"  "Naruto 05"  "Naruto 04"  "Naruto 03"  "Naruto 02" "Naruto 01")
               '("Naruto 07"  "Naruto 06"  "Naruto 05"  "Naruto 04"  "Naruto 03"  "Naruto 02" "Naruto 01")
               17854 0.99 0.9 18 24 40 3)
    ))

 (is (make-combatants heroes-rows)
     (team  final-fighters
            headers
            #t
            (for/hash ([fighter final-fighters]) (values (combatant.Name fighter) fighter))
            )
     "make-combatants worked for initial case")
 )
