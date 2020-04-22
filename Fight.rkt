#lang racket

;----------------------------------------------------------------------
;  When running in DrRacket, modify the values in this section as
;  desired.  When running on the command line interface (CLI) they can
;  be controlled with arguments.  There's a commented-out copy below
;  so that you can reference the original values.

; How many rounds to fight? +inf.0 means until one side dies.
;   cmdline:   -m or --max-rounds
(define max-rounds        (make-parameter +inf.0))

; Where is the Heroes.csv file?
;   cmdline: --heroes
;   NB:  'same (note the apostrophe) means "the directory this Fight.rkt file is in"
(define heroes-filepath   (make-parameter (build-path 'same "Heroes.csv")))

; Where is the Villains.csv file?
;   cmdline: --villains
(define villains-filepath (make-parameter (build-path 'same "Villains.csv")))

; The following are not available as CLI arguments but can be manually changed
(define DEFAULT-AOE       1)    ; default # of people each combatant hits each turn
(define DEFAULT-HP        2)    ; default points of damage a combatant can take. die at 0
(define DEFAULT-TO-HIT    0.3)  ; 30% chance for each die to cause a point of damage
(define DEFAULT-TO-DEFEND 0.3)  ; 30% chance for each die to deflect a point of damage


;   These are here for reference so you can see what the original
;   values were if you modify this code in DrRacket.
;
;; (define max-rounds        (make-parameter +inf.0))
;; (define heroes-filepath   (make-parameter (build-path 'same "Heroes.csv")))
;; (define villains-filepath (make-parameter (build-path 'same "Villains.csv")))
;; (define csv-column-names  (make-parameter ""))
;; (define DEFAULT-AOE       1)
;; (define DEFAULT-HP        2)
;; (define DEFAULT-TO-HIT    0.3)
;; (define DEFAULT-TO-DEFEND 0.3)

;----------------------------------------------------------------------

;  You should not modify anything below here

(require handy/hash
         handy/utils
         handy/list-utils
         handy/struct
         csv-reading
         struct-plus-plus
         )

(define csv-column-names  (make-parameter '()))
(define-logger fight)

;;----------------------------------------------------------------------

(define (to-num v)
  (match v
    ["" 0]
    [(? string?) (string->number (string-trim v))]
    [_ v]))

(define number-like? (or/c number?
                           ""
                           (and/c non-empty-string?
                                  (λ (v) (regexp-match #px"[0-9]" v)))))

(struct++ combatant
          ([Name              non-empty-string?  string-trim]
           [XP                number-like? to-num]
           [BonusXP           number-like? to-num]
           [Wounds            number-like? to-num]
           [BonusHP           number-like? to-num]
           [BonusToHit        number-like? to-num]
           [BonusToDefend     number-like? to-num]
           [(AOE DEFAULT-AOE) number-like? to-num]
           [BuffNextNumAllies number-like? to-num]
           [BuffAlliesOffense (compose1 (</c 1) to-num) to-num]
           [BuffAlliesDefense (compose1 (</c 1) to-num) to-num]
           [LinkedTo          string? string-trim]
           [BodyguardFor      string? string-trim]
           ;
           ; Private values, should not be in the .csv file
           [(HP                   #f)  integer?]
           [(Dice                 #f)  integer?]
           [(ToHit                #f)  real?   ]
           [(ToDefend             #f)  real?   ]
           [(EffectiveXP          #f)  integer?]
           [(BodyguardingMe       '()) (listof combatant?)]
           [(Linked-to-Me         '()) (listof combatant?)]
           [(CurrentlyBodyguarding #f)  boolean?]
           )
          (#:rule ("calculate HP" #:transform HP (BonusHP Wounds)
                   [(or HP ; only do this if it wasn't set
                        (- (+ DEFAULT-HP (to-num BonusHP)) (to-num Wounds)))])
           #:rule ("calculate EffectiveXP" #:transform EffectiveXP (XP BonusXP)
                   [(or EffectiveXP ; ditto
                        (+ (to-num XP) (to-num BonusXP)))])
           #:rule ("calculate Dice" #:transform Dice (EffectiveXP)
                   [(or Dice ; only do this if it wasn't set
                        (ceiling (/ EffectiveXP 1000)))])
           #:rule ("normalize AOE" #:transform AOE (Name AOE)
                   [(cond
                      [(false?  AOE) DEFAULT-AOE]
                      [((</c 1) AOE) DEFAULT-AOE]
                      [else          AOE])])
           #:rule ("normalize ToHit"    #:transform ToHit    (ToHit BonusToHit)
                   [(define to-hit (match ToHit
                                     [#f  (+ DEFAULT-TO-HIT (to-num BonusToHit))]
                                     [(? number?) ToHit]
                                     [_  (+ (to-num ToHit) (to-num BonusToHit))]))
                    (min 0.99 ; ToHit is always 5% <= x <= 99%
                         (max 0.05 to-hit))])
           #:rule ("normalize ToDefend"    #:transform ToDefend    (ToDefend BonusToDefend)
                   [(define to-defend (match ToDefend
                                        [#f  (+ DEFAULT-TO-DEFEND (to-num BonusToDefend))]
                                        [(? number?) ToDefend]
                                        [_  (+ (to-num ToDefend) (to-num BonusToDefend))]))
                    (min 0.90 ; ToDefend is always 0% <= x <= 90%
                         (max 0 to-defend))])
           #:convert-for (stats-dump
                          (#:post
                           (λ (h)
                             (match-define (hash-table
                                            ('Name              Name )
                                            ('XP                XP )
                                            ('BonusXP           BonusXP )
                                            ('Wounds            Wounds )
                                            ('BonusHP           BonusHP )
                                            ('BonusToHit        BonusToHit )
                                            ('BonusToDefend     BonusToDefend )
                                            ('AOE               AOE )
                                            ('BuffNextNumAllies BuffNextNumAllies )
                                            ('BuffAlliesOffense BuffAlliesOffense )
                                            ('BuffAlliesDefense BuffAlliesDefense )
                                            ('LinkedTo          LinkedTo )
                                            ('BodyguardFor      BodyguardFor ))
                               h)
                             (string-join (map ~a (list Name
                                                        XP
                                                        BonusXP
                                                        Wounds
                                                        BonusHP
                                                        BonusToHit
                                                        BonusToDefend
                                                        AOE
                                                        BuffNextNumAllies
                                                        BuffAlliesOffense
                                                        BuffAlliesDefense
                                                        LinkedTo
                                                        BodyguardFor
                                                        ))
                                          ","))))
           #:convert-for (report-string
                          (#:post (λ (h)
                                    (match-define (hash-table ('Name name)
                                                              ('HP hp)
                                                              ('EffectiveXP total-xp)
                                                              ('ToHit to-hit)
                                                              ('ToDefend to-defend)
                                                              ('AOE aoe)
                                                              ('Dice dice)
                                                              ('BodyguardFor bodyguard-for)
                                                              ('LinkedTo linked-to)
                                                              )
                                      h)
                                    (format "~a:\tHP(~a), ToHit(~a%), ToDefend(~a%), AOE (~a), Total XP (~a), Dice(~a), Bodyguarding: ~a, Linked to: ~a"
                                            name hp
                                            (real->decimal-string (* 100 to-hit)    1)
                                            (real->decimal-string (* 100 to-defend) 1)
                                            aoe total-xp dice
                                            (if (empty-string? bodyguard-for)
                                                "<no one>"
                                                bodyguard-for)
                                            (if (empty-string? linked-to)
                                                "<no one>"
                                                linked-to))))))
          #:transparent
          #:mutable
          )

;;----------------------------------------------------------------------

(define (all-names fighters) (string-join (map combatant-Name fighters) ","))

;;----------------------------------------------------------------------

(define (sort-combatants lst)
  (sort lst (λ (a b)
              (string<? (combatant-Name a)
                        (combatant-Name b)))))

;;----------------------------------------------------------------------

(define (show-sides heroes villains)
  (displayln "Heroes:")
  (if (null? heroes)
      (displayln " <no survivors>")
      (for ([hero heroes])
        (displayln (combatant/convert->report-string hero))))

  (displayln "\n\nVillains:")
  (if (null? villains)
      (displayln " <no survivors>")
      (for ([villain villains])
        (displayln (combatant/convert->report-string villain)))))

;;----------------------------------------------------------------------

(define/contract (is-alive? fighter)
  (-> combatant? (or/c combatant? #f))
  (if (> (combatant-HP fighter) (combatant-Wounds fighter))
      fighter
      #f))

(define living-combatant/c (and/c combatant? is-alive?))

(define/contract (make-more-tired fighter)
  (-> combatant? combatant?)
  fighter #;
  (set-combatant-ToDefend fighter (- (combatant-ToDefend fighter) 0.1)))

;; ;;----------------------------------------------------------------------

(define/contract (make-combatants rows)
  (-> (non-empty-listof (non-empty-listof string?))
      (non-empty-listof combatant?))
  (define headers (csv-column-names))

  ; We get a list of lists where the inner lists are a row from the CSV file.  We turn
  ; that into a hash, then into a combatant? in order to let struct++ run its rules.
  ;
  ; The results of this function will be passed to `initialize`, which will take care of
  ; calculating buffs, tracking linked people and bodyguards, etc.
  ;
  (for/list ([row (cdr rows)])
    (hash->struct/kw combatant++
                     (for/hash ([h headers]
                                [v row])
                       (values (string->symbol h)
                               (string-trim v))))))

;;----------------------------------------------------------------------

(define/contract (initialize combatants)
  (-> (non-empty-listof combatant?)
      (non-empty-listof combatant?))

  ; First, set each combatant to know its bodyguards and linkages
  (for ([fighter combatants])
    (define fighter-name (combatant-Name fighter))

    ;  Have each combatant keep track of their own bodyguards
    (set-combatant-BodyguardingMe!
     fighter
     (filter (λ (f)
               (define protectee-name (combatant-BodyguardFor f))
               (equal? fighter-name protectee-name))
             combatants))

    ;  Have each combatant keep track of who is linked to them
    (set-combatant-Linked-to-Me!
     fighter
     (filter (λ (f)
               (define linked-to-name (combatant-LinkedTo f))
               (equal? fighter-name linked-to-name))
             combatants)))

  ; Modify each combatant's combat stats based on ally buffs
  (define max-allies (sub1 (length combatants))) ; only the first person can have this many
  (let loop ([fighter           (car combatants)]
             [potential-allies  (cdr combatants)])
    (cond [(null? potential-allies) combatants]
          [else
           (match fighter
             [(and (struct* combatant ([BuffNextNumAllies raw-num-allies]
                                       [BuffAlliesOffense attack-boost]
                                       [BuffAlliesDefense defense-boost])))
              (define num-allies  (min raw-num-allies (length potential-allies)))

              ; Allies are the next `num-allies` rows
              (define allies (take potential-allies num-allies))
              (for ([ally allies])
                (match-define (struct* combatant ([ToHit toHit] [ToDefend toDefend])) ally)
                (set-combatant-ToHit!    ally (+ toHit    attack-boost))
                (set-combatant-ToDefend! ally (+ toDefend defense-boost)))
              (loop (car potential-allies)
                    (cdr potential-allies))])])))

;;----------------------------------------------------------------------

; generate-matchups  side1 side2
;
; Takes two lists of combatants, returns a LoL where the inner lists are (attacker
; defender ..+). It's usually only 1 defender, but attackers with AOE attacks might hit
; multiple people.  If a chosen defender has bodyguards then a random pick from the
; bodyguards will be substituted for that defender when the list is assembled.
(define/contract (generate-matchups att all-defenders)
  (-> (listof living-combatant/c) (listof living-combatant/c)
      (non-empty-listof ; list of lists, each sublist has 2+ members  (attacker, 1+ defenders)
       (and/c (listof living-combatant/c)
              (λ (l) (>= (length l) 2)))))

  (define all-attackers (sort-combatants att))

  (log-fight-debug "generating matchups.\n\t all-attackers: ~v\n\t all-defenders: ~v"
                   all-attackers all-defenders)

  (define matchups
    (for/list ([attacker all-attackers])
      (log-fight-debug "attacker ~v has AOE ~a" attacker (combatant-AOE attacker))

      (define attacker-name (combatant-Name attacker))
      (define AOE (combatant-AOE attacker))
      (define defenders
        (sort-combatants
         (cond [(> AOE (length all-defenders))
                (log-fight-debug "AOE was higher than number of defenders. using all defenders")
                all-defenders]
               [else
                (define shuffled-defenders (shuffle all-defenders))
                (log-fight-debug "shuffled defenders: ~a" (map combatant-Name shuffled-defenders))
                (for/list ([candidate shuffled-defenders]
                           [i         AOE]) ; no more than this many
                  (define candidate-name (combatant-Name candidate))
                  (log-fight-debug "~a is trying to attack ~a" attacker-name candidate-name)
                  (define bodyguards (filter (and/c is-alive?
                                                    (negate combatant-CurrentlyBodyguarding))
                                             (combatant-BodyguardingMe candidate)))
                  (log-fight-debug "living, not occupied bodyguards for candiate ~a: ~a"
                                   candidate-name
                                   (if (null? bodyguards)
                                       "<none>"
                                       (all-names bodyguards)))
                  (cond [(null? bodyguards)                   candidate]
                        [else (define choice (pick bodyguards))
                              (displayln (format "\t~a wanted to hit ~a but ~a jumped in the way!"
                                                 attacker-name
                                                 candidate-name
                                                 (combatant-Name choice)))
                              (set-combatant-CurrentlyBodyguarding! choice #t)
                              choice]))])))
      (log-fight-debug "final matchup for attacker ~v: ~v" attacker defenders)
      (cons attacker defenders)))

  (log-fight-debug "all final matchups:\n ~a"
                   (with-output-to-string
                     (thunk (pretty-print matchups))))
  (for ([next (append att all-defenders)])
    (set-combatant-CurrentlyBodyguarding! next #f))

  
  matchups)

;;----------------------------------------------------------------------

(define/contract (generate-hits fighter)
  (-> combatant? natural-number/c)
  (match-define (struct* combatant ([Name name] [Dice dice] [ToHit ToHit])) fighter)
  (define result (for/sum ([n dice]) (if (<= (random) ToHit) 1 0)))
  ;(displayln (format "~a generated ~a raw hits" name result))
  result)

;;----------------------------------------------------------------------

(define/contract (block-hits fighter)
  (-> combatant? natural-number/c)

  (match-define (struct* combatant ([Name name] [Dice dice] [ToDefend ToDefend])) fighter)
  (define result (for/sum ([n dice]) (if (< (random) ToDefend) 1 0)))
  ;(displayln (format "~a blocked ~a raw hits" name result))
  result)


;;----------------------------------------------------------------------

(define/contract (fight-one-round heroes villains)
  (-> (listof combatant?) (listof combatant?) any)

  (log-fight-debug "entering fight-one-round with heroes:\n ~a \n villains: ~a"
                   (all-names heroes)
                   (all-names villains))
  (define h2v (generate-matchups heroes villains))
  (define v2h (generate-matchups villains heroes))

  (log-fight-debug "h2v is: ~v" h2v)
  (log-fight-debug "v2h is: ~v" v2h)

  ; heroes attack villains first, then vice versa.  All attacks are simultaneous, no one
  ; is marked dead until the round is over.
  (for ([lst (list h2v v2h)])
    (define all-attackers       (map car lst))  ; (listof combatant?)
    (define all-defender-groups (map cdr lst))  ; (listof (listof combatant?))

    (log-fight-debug "all-attackers: ~a\n-------------\nall-defender-groups: ~a"
                     (with-output-to-string
                       (thunk (pretty-print all-attackers)))
                     (with-output-to-string
                       (thunk (pretty-print all-defender-groups))))

    (for ([attacker  all-attackers]
          [defenders all-defender-groups])
      (log-fight-debug " attacker ~v\n defenders ~v" attacker defenders)

      (define attacker-name (combatant-Name attacker))
      (when (> (length defenders) 1)
        (displayln (format "\t Note: ~a has AoE attacks and is potentially hitting ~a people!"
                           attacker-name
                           (length defenders))))
      (for ([defender defenders])
        (log-fight-debug "defender: ~a" defender)
        (match-define (struct* combatant ([Name   defender-name]
                                          [Wounds defender-wounds]
                                          [HP     defender-hp]))
          defender)

        (define wounds-inflicted (- (generate-hits attacker) (block-hits defender)))
        (cond [(> wounds-inflicted 0)
               (define total-damage-received  (+ defender-wounds wounds-inflicted))
               (set-combatant-Wounds! defender total-damage-received)
               (displayln (format "~a hit ~a for ~a damage! ~a is at ~a HP~a"
                                  attacker-name
                                  defender-name
                                  wounds-inflicted
                                  defender-name
                                  (- defender-hp total-damage-received)
                                  (if (not (is-alive? defender))
                                      ", and will die at end of round."
                                      ".")))
               (when (not (is-alive? defender))
                 ; kill all living combatants who were linked to the now-deceased defender
                 (define all-linked (filter is-alive? (combatant-Linked-to-Me defender)))
                 (when (not (null? all-linked))
                   (displayln (format "  The following combatants were linked to ~a and will die at end of round: ~a"
                                      defender-name
                                      (all-names all-linked))))
                 (for ([linked all-linked])
                   (set-combatant-Wounds! linked
                                          (max (combatant-Wounds linked)
                                               (combatant-HP     linked)))))]
              [else
               (displayln (format "~a failed to hurt ~a..." attacker-name defender-name))])))
    (displayln "\n"))

  (displayln "\n round ends.  Survivors are:\n\n")
  (show-sides (filter is-alive? heroes) (filter is-alive? villains)))

;;----------------------------------------------------------------------

(define/contract (write-combatant-data heroes villains)
  (-> (listof combatant?) (listof combatant?)
      any)

  (define heroes-final-path (path->string     (build-path 'same "Heroes-final.csv")))
  (define villains-final-path (path->string     (build-path 'same "Villains-final.csv")))
  (displayln (format "\n\nDumping the final state of all combatants to ~a and ~a"
                     heroes-final-path
                     villains-final-path))
  (with-output-to-file
    #:exists 'replace
    heroes-final-path
    (thunk
     (displayln (string-join (csv-column-names) ","))
     (for ([x heroes])
       (displayln (combatant/convert->stats-dump x)))))

  (with-output-to-file
    #:exists 'replace
    villains-final-path
    (thunk
     (displayln (string-join (csv-column-names) ","))
     (for ([x villains]) (displayln (combatant/convert->stats-dump x))))))

;;----------------------------------------------------------------------
;;----------------------------------------------------------------------
;;----------------------------------------------------------------------
; program start

(define (run)
  (define heroes-file   (csv->list  (open-input-file (heroes-filepath))))
  (define villains-file (csv->list  (open-input-file (villains-filepath))))

  (when (< (length heroes-file) 2)
    (error "Heroes.csv must have at least two rows: headers and one combatant"))
  (when (< (length villains-file) 2)
    (error "Villains.csv must have at least two rows: headers and one combatant"))

  (log-fight-debug "Got the files loaded")

  (define headers  (map string-trim (car heroes-file)))
  (when (not (equal? headers (map string-trim (car villains-file))))
    (error "Headers in Heroes.csv and Villains.csv must match"))

  (csv-column-names headers)
  (log-fight-debug "headers matched")

  ; Turn the CSV records into structs and initialize them
  (define heroes   (initialize (make-combatants heroes-file)))
  (define villains (initialize (make-combatants villains-file)))
  (log-fight-debug "initialized heroes and villains")

  (displayln "At start of battle, the sides are:\n")
  (show-sides heroes villains)

  (let loop ([heroes   heroes]
             [villains villains]
             [round#   1]
             )
    (log-fight-debug "loop for round ~a" round#)
    (cond [(> round# (max-rounds))
           (displayln "\n\n Battle ends! Max number of rounds fought.")
           (write-combatant-data heroes villains)
           ]
          [(or (null? heroes)
               (null? villains))
           (displayln "\n\n Battle ends!  One side has been eliminated.")
           (write-combatant-data heroes villains)]
          [else
           (displayln (format "\n\tRound ~a, fight!" round#))

           (fight-one-round (filter is-alive? heroes)
                            (filter is-alive? villains))
           (log-fight-debug "after fight-one-round for round ~a" round#)

           ; After every round, combatants are more tired, lower on chakra, etc, and
           ; simultaneously get more desperate for a win.  To represent that,
           ; make-more-tired will adjust their combat stats downward.  This prevents any
           ; possibility of stalemate due to fighters with ridiculously high defense or
           ; low attack.
           (loop (map make-more-tired (filter is-alive? heroes))
                 (map make-more-tired (filter is-alive? villains))
                 (add1 round#))]))

  )

(define logfilepath   (build-path 'same "BattleLog.txt"))

;  Run the fight and send the output to the log file
(with-output-to-file
  logfilepath
  #:exists 'replace
  #:mode   'text
  (thunk
   (command-line
    #:program "Fight.rkt"
    #:once-each
    [("-m" "--max-rounds") num-rounds "Stop after N rounds even if the fight is not done.  It will output the current state of the combatants to Heroes-final.csv and Villains-final.csv.  You can then modify these files (e.g. add reinforcements) and run it again.  Be sure to use the --heroes and --villains switches if you do"
     (max-rounds (string->number num-rounds))]
    [("--heroes") hf "A relative path to a combatants CSV file. Default: ./Heroes.csv" (heroes-filepath (build-path 'same hf))]
    [("--villains") vf "A relative path to a combatants CSV file. Default: ./Villains.csv" (villains-filepath (build-path 'same vf))]
    )
   (run)
   (displayln (format "\n\n\t NOTE: Output was saved to '~a'" (path->string logfilepath)))
   ))

; display the log file to STDOUT
(displayln (file->string logfilepath))
