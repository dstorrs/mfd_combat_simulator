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

 (define heroes
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
               17854 0.99 0.9 18 24 40 3)))

 (is (make-combatants heroes-rows)
     (team  heroes
            headers
            #t
            (for/hash ([fighter heroes]) (values (combatant.Name fighter) fighter))
            )
     "make-combatants worked for initial case")

 (is (make-combatants villains-rows)
     '#s(team (#s(combatant "Conjura" 55000 0 -1 0.3 0.3 3 "Summoner" "Summoner"
                       ()
                       () () 55000 0.8999999999999999 0.8 55 55 55 1)
          #s(combatant "Mook A" 14901 0 0 0.1 0 1 "Summoner" ""
                       (#s(buff "Teamwork" ("Mook A" "Mook B" "Summoner") 0.1 0.1)
                        #s(buff "Jutsu 1" ("Conjura" "Mook A" "Mook B" "Summoner") 0.3 0.2))
                       () () 14901 0.8999999999999999 0.7 15 15 15 2)
          #s(combatant "Summoner" 30983 -15000 0 0.1 0 1 "" ""
                       (#s(buff "Teamwork" ("Mook A" "Mook B" "Summoner") 0.1 0.1))
                       ("Mook A" "Conjura") ("Conjura") 15983 0.8999999999999999 0.7 16 16 16 2))
         ("Name" "XP" "BonusXP" "BonusHP" "BonusToHit" "BonusToDefend" "AOE" "BodyguardFor" "LinkedTo" "BuffName" "BuffWho" "BuffOffense" "BuffDefense" "BuffName" "BuffWho" "BuffOffense" "BuffDefense")
         #t
         #hash(("Conjura" . #s(combatant "Conjura" 55000 0 -1 0.3 0.3 3 "Summoner" "Summoner" () () () 55000 0.8999999999999999 0.8 55 55 55 1)) ("Mook A" . #s(combatant "Mook A" 14901 0 0 0.1 0 1 "Summoner" "" (#s(buff "Teamwork" ("Mook A" "Mook B" "Summoner") 0.1 0.1) #s(buff "Jutsu 1" ("Conjura" "Mook A" "Mook B" "Summoner") 0.3 0.2)) () () 14901 0.8999999999999999 0.7 15 15 15 2)) ("Summoner" . #s(combatant "Summoner" 30983 -15000 0 0.1 0 1 "" "" (#s(buff "Teamwork" ("Mook A" "Mook B" "Summoner") 0.1 0.1)) ("Mook A" "Conjura") ("Conjura") 15983 0.8999999999999999 0.7 16 16 16 2))))
     "make-combatants worked for initial villains"))


(test-suite
 "generate-matchups"

 (define heroes   (make-combatants heroes-rows))
 (define villains (make-combatants villains-rows))

 (define h2v-matchups #f)
 (with-output-to-string
   (thunk
    (set! h2v-matchups (generate-matchups heroes villains))))

 (define v2h-matchups #f)
 (with-output-to-string
   (thunk
    (set! v2h-matchups (generate-matchups villains heroes))))

 (ok (thunk (match h2v-matchups
              [(and (list (matchup (? name? attacker-name) (list (? name?))) ...) lst)
               #:when (= 10 (length lst))
               'ok]
              [else #f]))
     "heroes->villains has 10 matchups, each with one defender name"
     )
 )


