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

 ; NOTE:  We are testing make-fighter, so buffs will not have been applied
 (for ([row (cdr heroes-rows)]
       [expected-name '("Ami" "Kei"  "Prime" "Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04")]
       [correct (list
                 ;          Name,XP,BonusXP,BonusHP,BonusToHit,BonusToDefend,AOE,BodyguardFor,LinkedTo,BuffName,BuffWho,BuffOffense,BuffDefense
                 (combatant "Ami" 13993 0 1 0 0 1 "Kei" ""
                            (list (buff "Mori" '("Ami" "Kei" "Naruto 01" "Prime") 0.06 0.03))
                            '() '() 13993 0.3 0.3 14 3)
                 (combatant "Kei" 5785 0 1 0 0 1 "" "" '() '() '() 5785 0.3 0.3 6 3)
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
                            '() '() 17854 0.44999999999999996 0.3 18 3)
)]
       [expected-bgf  (list "Kei" "" "" "Prime"  "Prime" "Prime" "Prime")]
       [expected-lt   (list "" "" "" "Prime" "Prime" "Prime" "Prime")]
       )
   (define fighter (make-fighter row headers buff-field-names fields num-fields))
   (is fighter
       correct
       (format "correctly made fighter ~a" expected-name))
   ;; ; Verify that these came out in the right order and my test data wasn't backwards 
   ;; (is (combatant.BodyguardFor fighter)
   ;;     expected-bgf
   ;;     "bodyguard-for correct"
   ;;     )
   ;; (is (combatant.LinkedTo fighter)
   ;;     expected-lt
   ;;     "linked-to correct")
   ))

#;
(test-suite
 "make-combatants - heroes"

 (define-values (headers buff-field-names fields num-fields)
   (parse-csv-data heroes-rows))


 (is (make-combatants heroes-rows)
     '#s(team
                                        ;Name,XP,BonusXP,BonusHP,BonusToHit,BonusToDefend,AOE,BodyguardFor,LinkedTo,BuffName,BuffWho,BuffOffense,BuffDefense
         (#s(combatant "Ami" 13993 0 1 0 0 1 "Kei" "" (#s(buff "Mori" ("Ami" "Kei" "Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.06 0.06)) () () 13993 0.5 0.36 14 3)
          #s(combatant "Kei" 5785 0 1 0 0 1 "" "" () ("Ami") () 5785 0.5 0.36 6 3)
          #s(combatant "Naruto 01" 17854 0 1 0.15 0 1 "Prime" "Prime" (#s(buff "Teamwork" ("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.1)) () () 17854 0.71 0.56 18 3)
          #s(combatant "Prime" 17854 0 1 0.15 0 1 "" "" (#s(buff "Teamwork" ("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.1)) ("Naruto 01") ("Naruto 01") 17854 0.71 0.56 18 3))
         ("Name" "XP" "BonusXP" "BonusHP" "BonusToHit" "BonusToDefend" "AOE" "LinkedTo" "BodyguardFor" "BuffName" "BuffWho" "BuffOffense" "BuffDefense")
         #t
         #hash(("Ami"
                .
                #s(combatant "Ami" 13993 0 1 0 0 1 "Kei" "" (#s(buff "Mori" ("Ami" "Kei" "Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.06 0.06)) () () 13993 0.5 0.36 14 3))
               ("Kei"
                .
                #s(combatant "Kei" 5785 0 1 0 0 1 "" "" () ("Ami") () 5785 0.5 0.36 6 3))
               ("Naruto 01"
                .
                #s(combatant "Naruto 01" 17854 0 1 0.15 0 1 "Prime" "Prime" (#s(buff "Teamwork" ("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.1)) () () 17854 0.71 0.56 18 3))
               ("Prime"
                .
                #s(combatant "Prime" 17854 0 1 0.15 0 1 "" "" (#s(buff "Teamwork" ("Naruto 01" "Naruto 02" "Naruto 03" "Naruto 04" "Naruto 05" "Naruto 06" "Naruto 07" "Prime") 0.1 0.1)) ("Naruto 01") ("Naruto 01") 17854 0.71 0.56 18 3))))
     "make-combatants worked for initial case")
 )




