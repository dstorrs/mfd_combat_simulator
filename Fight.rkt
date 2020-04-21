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
           [(HP          #f)]
           [(Dice        #f)]
           [(ToHit       #f)]
           [(ToDefend    #f)]
           [(EffectiveXP #f)]
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
                                    (format "~a:\tHP(~a), ToHit(~a%), ToDefend(~a%), AOE (~a), Total XP (~a), Dice(~a), Bodyguarding ~a, Linked to ~a"
                                            name hp
                                            (real->decimal-string (* 100 to-hit) 0)
                                            (real->decimal-string (* 100 to-defend) 0)
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

(define (make-more-tired fighter)
  fighter #;
  (set-combatant-ToDefend fighter (- (combatant-ToDefend fighter) 0.1)))

;;----------------------------------------------------------------------

; Ensure that no one has a 'LinkedTo' or 'BodyguardFor' that uses a name for a combatant
; not in that file.
(define/contract (validate-names rows)
  (-> (listof combatant?) any)
  (match-define (list (struct* combatant ([Name names] [BodyguardFor def] [LinkedTo links]))
                      ...)
    rows)

  (define all-names (list->set names))
  (define linked    (list->set (filter non-empty-string? links)))
  (define defenders (list->set (filter non-empty-string? def)))

  (unless (subset? linked all-names)
    (error (format "One of the combatants had an unrecognized LinkedTo: ~v" rows)))

  (unless (subset? defenders all-names)
    (error (format "One of the combatants had an unrecognized BodyguardFor: ~v" rows))))

;;----------------------------------------------------------------------

(define (is-alive? fighter)
  (> (combatant-HP fighter) (combatant-Wounds fighter)))

(define (hashify rows headers)
  (for/list ([row (cdr rows)])
    (struct->hash combatant
                  (hash->struct/kw combatant++
                                   (for/hash ([h headers]
                                              [v row])
                                     (values (string->symbol h)
                                             (string-trim v)))))))

(define (initialize rows)
  (define max-allies (sub1 (length rows))) ; only the first person can actually have this many
  (let loop ([result   '()]
             [i        0]
             [rows     rows])
    (cond [(null? rows) (map (curry hash->struct/kw combatant++)
                             (reverse result))]
          [else
           (match (car rows)
             [(and current
                   (hash-table ('BuffNextNumAllies raw-num-allies)
                               ('BuffAlliesOffense attack-boost)
                               ('BuffAlliesDefense defense-boost)))
              (define num-allies  (min raw-num-allies (- max-allies i)))
              (define normalized (hash-set current 'BuffNextNumAllies num-allies))

              ; Allies are the next `num-allies` rows
              (define-values (allies others) (split-at (rest rows) num-allies))

              (loop (cons normalized result)
                    (add1 i)
                    (append (for/list ([ally allies])
                              (match ally
                                [(hash-table ('ToHit attack) ('ToDefend defense))
                                 (safe-hash-set ally
                                                'ToHit    (+ attack  attack-boost)
                                                'ToDefend (+ defense defense-boost))]))
                            others))])])))

(define bodyguard-hash/c (hash/c combatant? (listof combatant?)))
(define/contract (generate-bodyguard-hash fighters)
  (-> (listof combatant?)  bodyguard-hash/c)

  ; Return a hash where the keys are `combatant` structs and the values are a listof
  ; `combatant` structs signifying which combatants will take a bullet for which
  ;
  ;(hash Alice (list Bob Charlie))  ; Bob and Charlie are bodyguarding Alice

  (for/hash ([fighter fighters])
    (define name (combatant-Name fighter))
    (values fighter
            (filter (λ (f) (equal? name (combatant-BodyguardFor f)))
                    fighters))))

;;----------------------------------------------------------------------

; generate-matchups  side1 side2
;
; Takes two lists of combatants, returns a hash where each key/value
; pair is an attacker and the list of people they will attack this
; round.  It's usually only 1 defender, but attackers with AOE attacks
; might hit multiple people.  If any of the chosen defenders have
; bodyguards then a random pick from the bodyguards will be
; substituted for that defender.
(define/contract (generate-matchups  side1 side2)
  (-> (listof combatant?) (listof combatant?)
      (hash/c combatant? (listof combatant?)))

  (define side2-bodyguards (generate-bodyguard-hash side2))
  (for/hash ([attacker side1])
    (log-fight-debug "attacker ~v has AOE ~a" attacker (combatant-AOE attacker))
    (define defenders
      (for/fold ([result '()])
                ([i (combatant-AOE attacker)])
        (define candidate (pick side2))
        (define candidate-bodyguards (filter is-alive? (hash-ref side2-bodyguards candidate '())))
        (cond [(null? candidate-bodyguards)
               (cons  candidate result)]
              [else
               (define chosen-bodyguard (pick candidate-bodyguards))
               (displayln (format "  NOTE: ~a tried to attack ~a but ~a heroically jumped in the way!"
                                  (combatant-Name attacker)
                                  (combatant-Name candidate)
                                  (combatant-Name chosen-bodyguard)))
               (cons chosen-bodyguard result)])))

    (values attacker defenders)))

;;----------------------------------------------------------------------

(define (generate-hits fighter)
  (match-define (struct* combatant ([Name name] [Dice dice] [ToHit ToHit])) fighter)
  (define result (for/sum ([n dice]) (if (<= (random) ToHit) 1 0)))
  ;(displayln (format "~a generated ~a raw hits" name result))
  result)

;;----------------------------------------------------------------------

(define (block-hits fighter)
  (match-define (struct* combatant ([Name name] [Dice dice] [ToDefend ToDefend])) fighter)
  (define result (for/sum ([n dice]) (if (< (random) ToDefend) 1 0)))
  ;(displayln (format "~a blocked ~a raw hits" name result))
  result)


;;----------------------------------------------------------------------

(define/contract (run-combat heroes villains)
  (-> (listof combatant?) (listof combatant?) any)

  (define sides (shuffle (list heroes villains)))
  (log-fight-debug "sides are: ~v" sides)

  (define h2v (apply generate-matchups sides))
  (define v2h (apply generate-matchups (reverse sides)))

  (log-fight-debug "h2v is: ~v" h2v)
  (log-fight-debug "v2h is: ~v" v2h)

  ; heroes attack villains first, then vice versa.  All attacks are simultaneous, no one
  ; is marked dead until the round is over WITH THE EXCEPTION that a bodyguard doesn't get
  ; to keep bodyguarding after taking fatal damage, although they will get their licks in
  ; for that round.
  (for ([hsh (list h2v v2h)])
    (for ([(attacker defenders) (in-hash hsh)])
      (log-fight-debug " attacker ~v\n defenders ~v" attacker defenders)

      (when (> (length defenders) 1)
        (displayln (format "\t Note: ~a has AoE attacks and is potentially hitting ~a people!"
                           (combatant-Name attacker)
                           (length defenders))))
      (for ([defender defenders])
        (log-fight-debug "defender: ~v" defender)
        (match-define (list (struct* combatant ([Name attacker-name]))
                            (struct* combatant ([Name defender-name]
                                                [Wounds defender-wounds]
                                                [HP defender-hp])))
          (list attacker defender))

        (define wounds-inflicted (- (generate-hits attacker) (block-hits defender)))
        (cond [(> wounds-inflicted 0)
               (define total-damage-received  (+ (combatant-Wounds defender) wounds-inflicted))
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
                 (define linked (filter (λ (c)
                                          (equal? (combatant-LinkedTo c) defender-name))
                                        (append heroes villains)))
                 (when (not (null? linked))
                   (displayln (format "  The following combatants were linked to ~a and will die at end of round: ~a"
                                      defender-name
                                      (string-join (map combatant-Name linked) ", ")))
                   (for ([fighter linked])
                     (set-combatant-HP! fighter (min 0 (combatant-HP fighter))))))]
              [else
               (displayln (format "~a failed to hurt ~a..." attacker-name defender-name))])))))

;;----------------------------------------------------------------------

(define/contract (write-combatant-data heroes villains)
  (-> (listof combatant?) (listof combatant?) any)

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

  ; turn the CSV records into hashes and then into structs
  (define heroes   (initialize (hashify heroes-file   headers)))
  (define villains (initialize (hashify villains-file headers)))

  (log-fight-debug "initialized heroes and villains")

  (validate-names heroes)
  (validate-names villains)

  (log-fight-debug "validated heroes and villains")

  (displayln "At start of battle, the sides are:\n")
  (show-sides heroes villains)

  (let loop ([heroes   heroes]
             [villains villains]
             [round#   1]
             )
    (log-fight-debug "loop for round ~a" round#)

    (cond [(or (null? heroes)
               (null? villains)
               (> round# (max-rounds)))
           (displayln "\n\n Battle ends!  Final result:")
           (show-sides heroes villains)
           (write-combatant-data heroes villains)]
          [else
           (displayln (format "\n\tRound ~a, fight!" round#))

           (run-combat heroes villains)

           (log-fight-debug "after run-combat for round ~a" round#)

           ; After every round, combatants are more tired, lower on chakra, etc, and
           ; simultaneously get more desperate for a win.  To represent that, we reduce
           ; their ToDefend by 0.1 (i.e. 10%).  This prevents any possibility of stalemate
           ; due to fighters with ridiculously high defense or low attack.
           (loop (map make-more-tired (filter is-alive? heroes))
                 (map make-more-tired (filter is-alive? villains))
                 (add1 round#))])))

(define logfilepath   (build-path 'same "BattleLog.txt"))
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
   (displayln "\n\n\t NOTE: Output was saved to './BattleLog.txt'")))

(displayln (file->string logfilepath))
