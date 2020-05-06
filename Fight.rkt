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
(define DEFAULT-AOE         1)    ; default # of people each combatant hits each turn
(define DEFAULT-HP          2)    ; default points of damage a combatant can take. die at 0
(define DEFAULT-TO-HIT      0.3)  ; 30% chance for each die to cause a point of damage
(define DEFAULT-TO-DEFEND   0.3)  ; 30% chance for each die to deflect a point of damage
(define EXHAUSTION-PENALTY  0.05)  ; after every round, reduce everyone's ToDefend this much

;   These are here for reference so you can see what the original
;   values were if you modify this code in DrRacket.
;
;; (define max-rounds          (make-parameter +inf.0))
;; (define heroes-filepath     (make-parameter (build-path 'same "Heroes.csv")))
;; (define villains-filepath   (make-parameter (build-path 'same "Villains.csv")))
;; (define DEFAULT-AOE         1)
;; (define DEFAULT-HP          2)
;; (define DEFAULT-TO-HIT      0.3)
;; (define DEFAULT-TO-DEFEND   0.3)
;; (define EXHAUSTION-PENALTY  0.1)

;----------------------------------------------------------------------

;  You should not modify anything below here

(require handy/hash
         handy/utils
         handy/list-utils
         handy/struct
         csv-reading
         struct-plus-plus
         )

(provide (all-defined-out))

(define csv-column-names  (make-parameter '()))
(define-logger fight)

(define MIN-TO-HIT 0.5)
(define MAX-TO-HIT 0.99)

(define MIN-TO-DEFEND 0)
(define MAX-TO-DEFEND 0.90)


;;----------------------------------------------------------------------

(define (clip-to-range v min-val max-val)
  (max min-val (min v max-val)))

;;----------------------------------------------------------------------

(define (to-num v [default 0])
  (match v
    ["" default]
    [(? string?) (string->number (string-trim v))]
    [(? number?) v]
    [else (raise-arguments-error 'to-num
                                 "could not convert value to number"
                                 "value" v)]))

(define number-like? (or/c number?
                           ""
                           (and/c non-empty-string?
                                  (λ (v) (regexp-match #px"[0-9]" v)))))

(define name? non-empty-string?)
(struct++ matchup ([attacker name?]
                   [defenders (listof name?)])
          #:transparent)


(struct++ buff
          ([BuffName name?]    ; e.g. "teamwork" or "defend the log jutsu"
           [BuffWho      (or/c string? (listof string?))
                         (λ (v)
                           (sort-str (cond [(list? v) v]
                                           [else (map string-trim (string-split v ","))])))]
           [BuffOffense    number-like? to-num]
           [BuffDefense number-like? to-num])
          (#:convert-from (csv-record (list? (list BuffName BuffWho BuffOffense BuffDefense)
                                             (     BuffName BuffWho BuffOffense BuffDefense)))
           #:convert-for (stats-dump (#:post (λ (h)
                                               (match h
                                                 [(hash-table ('BuffName    name)
                                                              ('BuffWho     who)
                                                              ('BuffOffense off)
                                                              ('BuffDefense def))
                                                  (format "~a,\"~a\",~a,~a" name (string-join who ",") off def)])))))
          #:transparent)

(struct++ combatant
          ([Name                        name?        string-trim]
           [XP                          number-like? to-num]
           [BonusXP                     number-like? to-num]
           [BonusHP                     number-like? to-num]
           [BonusToHit                  number-like? to-num]
           [BonusToDefend               number-like? to-num]
           [AOE                         number-like? (curryr to-num 1)]
           [BodyguardFor                string?]
           [LinkedTo                    string?]
           [(Buffs '())                 (listof buff?)]
           ;
           ; private fields
           [(Bodyguarding-Me '())       (listof name?)]
           [(Linked-to-Me '())          (listof name?)]
           [(TotalXP #f)                exact-positive-integer?]
           [(ToHit   #f)                real?]
           [(ToDefend   #f)             real?]
           [(OffenseDice #f)            exact-positive-integer?]
           [(DefenseDice #f)            exact-positive-integer?]
           [(HP #f)                     integer?])
          (#:rule ("calc TotalXP"
                   #:transform TotalXP  (TotalXP XP BonusXP) [(or TotalXP (+ (to-num XP) (to-num BonusXP)))])
           #:rule ("calc HP"
                   #:transform HP       (HP BonusHP) [(or HP (+ DEFAULT-HP (to-num BonusHP)))])
           #:rule ("calc ToHit"
                   #:transform ToHit    (ToHit BonusToHit)
                   [(clip-to-range
                     (or ToHit
                         (+ (to-num BonusToHit)
                            DEFAULT-TO-HIT))
                     MIN-TO-HIT
                     MAX-TO-HIT)])
           #:rule ("calc ToDefend"
                   #:transform ToDefend (ToDefend BonusToDefend)
                   [(clip-to-range
                     (or ToDefend
                         (+ (to-num BonusToDefend) DEFAULT-TO-DEFEND))
                     MIN-TO-DEFEND
                     MAX-TO-DEFEND)])
           #:rule ("calc OffenseDice"
                   #:transform OffenseDice (OffenseDice TotalXP)
                   [(or OffenseDice (inexact->exact (ceiling (/ TotalXP 1000))))])
           #:rule ("calc DefenseDice"
                   #:transform DefenseDice (DefenseDice TotalXP)
                   [(or DefenseDice (inexact->exact (ceiling (/ TotalXP 1000))))])
           #:convert-from (csv-record
                           (list?
                            (list Name XP BonusXP BonusHP BonusToHit BonusToDefend AOE LinkedTo BodyguardFor _ ...)
                            (Name XP BonusXP BonusHP BonusToHit BonusToDefend AOE LinkedTo BodyguardFor)
                            ))
           #:convert-for (hash (#:post identity))
           #:convert-for (stats-dump
                          (#:post
                           (λ (h)
                             (match-define   (hash-table
                                              ('Name          Name )
                                              ('XP            XP )
                                              ('BonusXP       BonusXP )
                                              ('BonusHP       BonusHP )
                                              ('BonusToHit    BonusToHit )
                                              ('BonusToDefend BonusToDefend )
                                              ('AOE           AOE )
                                              ('LinkedTo      LinkedTo )
                                              ('BodyguardFor  BodyguardFor )
                                              ('Buffs         Buffs))
                               h)

                             (log-fight-debug "in convert for stats-dump, hash: ~v" h)
                             (log-fight-debug "buffs is: ~v" Buffs)
                             (log-fight-debug "dumped buffs is: ~v" (map buff/convert->stats-dump Buffs))

                             (define data
                               (string-join (append (map ~a (list
                                                             Name
                                                             XP
                                                             BonusXP
                                                             BonusHP
                                                             BonusToHit
                                                             BonusToDefend
                                                             AOE
                                                             LinkedTo
                                                             BodyguardFor))
                                                    (map buff/convert->stats-dump Buffs))
                                            ","))
                             (log-fight-debug "in combatant stats dump, data is: ~v" data)
                             data)))
           #:convert-for (report-string
                          (#:post (λ (h)
                                    (log-fight-debug "in convert-for report-string, hash is: ~v" h)
                                    (match-define (hash-table ('Name         name)
                                                              ('HP           hp)
                                                              ('TotalXP      total-xp)
                                                              ('ToHit        to-hit)
                                                              ('ToDefend     to-defend)
                                                              ('OffenseDice  offense-dice)
                                                              ('DefenseDice  defense-dice)
                                                              ('AOE          aoe)
                                                              ('BodyguardFor bodyguard-for)
                                                              ('LinkedTo     linked-to)
                                                              )
                                      h)
                                    (format "~a:\tHP(~a), OffenseDice(~a), DefenseDice(~a), ToHit(~a%), ToDefend(~a%), AOE (~a), Total XP (~a), Bodyguarding: ~a, Linked to: ~a"
                                            name hp
                                            offense-dice defense-dice
                                            (real->decimal-string (* 100 to-hit)    1)
                                            (real->decimal-string (* 100 to-defend) 1)
                                            aoe total-xp
                                            (if (empty-string? bodyguard-for)
                                                "<no one>"
                                                bodyguard-for)
                                            (if (empty-string? linked-to)
                                                "<no one>"
                                                linked-to)))))
           )
          #:transparent)

(define/contract (is-alive? fighter)
  (-> combatant? (or/c combatant? #f))
  #;
  (log-fight-debug "checking is-alive. fighter ~a has HP ~a"
                   (combatant.Name fighter)
                   (combatant.HP fighter))
  (if (> (combatant.HP fighter) 0)
      fighter
      #f))

(define living-combatant/c (and/c combatant? is-alive?))
(struct++ team
          ([fighters              (listof living-combatant/c)]
           [csv-headers           (non-empty-listof string?)]
           [apply-buffs?          boolean?]
           [(fighters-by-name #f) (hash/c name? combatant?)]
           )
          (#:rule ("remove invalid LinkedTo and Bodyguard entries"
                   #:transform fighters (fighters)
                   [(define all-fighters-by-name (hash-aggregate combatant.Name fighters))
                    (for/list ([fighter fighters])
                      (let* ([bodyguard-for (combatant.BodyguardFor fighter)]
                             [linked-to     (combatant.LinkedTo     fighter)]
                             [fighter       (if (hash-has-key? all-fighters-by-name bodyguard-for)
                                                fighter
                                                (set-combatant-BodyguardFor fighter ""))]
                             [fighter       (if (hash-has-key? all-fighters-by-name linked-to)
                                                fighter
                                                (set-combatant-LinkedTo fighter ""))])
                        fighter))])
           #:rule ("apply ally buffs"
                   #:transform fighters (fighters apply-buffs?)
                   [;(log-fight-debug "entering apply-all-buffs, fighters is: ~v" fighters)
                    (cond [(or (not apply-buffs?) (null? fighters))
                           fighters]
                          [else
                           (match (flatten (map combatant.Buffs fighters))
                             ['() fighters]
                             [all-buffs
                              ;; okay, we have some buffs.

                              ;; make a lookup table of name to combatant so it's easy to
                              ;; retrieve them
                              ;(log-fight-debug "about to make fighters-by-name. fighters are: ~v" fighters)
                              (define fighters-by-name (hash-aggregate combatant.Name
                                                                       fighters))
                              ;(log-fight-debug "fighters-by-name: ~v" fighters-by-name)
                              ;; final result is going to be the updated combatants, which
                              ;; are the values of the fighters-by-name hash
                              (hash-values
                               ;; map over all buffs
                               (for/fold ([fighters-by-name fighters-by-name])
                                         ([next-buff all-buffs])
                                 (match-define (struct* buff
                                                        ([BuffWho     recipient-names]
                                                         [BuffOffense offense-buff]
                                                         [BuffDefense defense-buff]))
                                   next-buff)
                                 ;; map over the recipients, giving them the buff
                                 (for/fold ([fighters-by-name fighters-by-name])
                                           ([fighter (filter (negate false?)
                                                             (hash-slice fighters-by-name recipient-names #f))])
                                   (match-define (struct* combatant ([ToHit    ToHit]
                                                                     [ToDefend ToDefend]))
                                     fighter)
                                   ; If a buff refers to someone not in the list of
                                   ; fighters, ignore it.  This could happen when
                                   ; `fight-one-round` updates the team with the living
                                   ; fighters without bothering to update all the buffs
                                   (define name (combatant.Name fighter))
                                   (if (hash-has-key? fighters-by-name name)
                                       (hash-set fighters-by-name
                                                 name
                                                 (let* ([result (set-combatant-ToHit    fighter (+ ToHit    offense-buff))]
                                                        [result (set-combatant-ToDefend fighter (+ ToDefend defense-buff))])
                                                   result))
                                       fighters-by-name))))])])])
           #:rule ("clip ToHit/ToDefend and award bonus dice as appropriate"
                   #:transform fighters (fighters apply-buffs?)
                   [;(log-fight-debug "entering bonus-dice, fighters is: ~v" fighters)
                    (cond [(or (not apply-buffs?) (null? fighters))
                           fighters]
                          [else
                           (for/list ([fighter fighters])
                             (match-define (struct* combatant ([ToHit       ToHit]
                                                               [ToDefend    ToDefend]
                                                               [OffenseDice OffenseDice]
                                                               [DefenseDice DefenseDice]))
                               fighter)
                             (let* ([fighter (if (> ToHit 1)
                                                 (set-combatant-OffenseDice fighter
                                                                            (inexact->exact
                                                                             (ceiling (* OffenseDice ToHit))))
                                                 fighter)]
                                    [fighter (if (> ToDefend 1)
                                                 (set-combatant-DefenseDice fighter
                                                                            (inexact->exact
                                                                             (ceiling (* DefenseDice ToDefend))))
                                                 fighter)]
                                    [fighter (set-combatant-ToHit fighter
                                                                  (max MIN-TO-HIT
                                                                       (min ToHit MAX-TO-HIT)))]
                                    [fighter (set-combatant-ToDefend fighter
                                                                     (max MIN-TO-DEFEND
                                                                          (min ToDefend MAX-TO-DEFEND)))])
                               fighter))])])
           #:rule ("set bodyguarding-me and linked-to-me"
                   #:transform fighters (fighters)
                   [(log-fight-debug "entering set bodyguards, fighters is: ~v" fighters)
                    (cond [(null? fighters) fighters]
                          [else
                           (define bodyguards   (hash-aggregate combatant.BodyguardFor fighters))
                           (define linked-to    (hash-aggregate combatant.LinkedTo     fighters))
                           ;; bodyguards and linked-to are (hash/c name? (listof combatant?))
                           ;; where the combatants are the people bodyguarding/linked-to that name
                           (let* ([result
                                   (begin
                                     (log-fight-debug "in team++, set bodyguards, first 'result' clause, fighters is: ~v"
                                                      fighters)
                                     (for/list ([fighter fighters])
                                       (log-fight-debug "fighter is: ~v" fighter)
                                       (define name (combatant.Name fighter))
                                       (if (hash-has-key? bodyguards name)
                                           (set-combatant-Bodyguarding-Me fighter (map combatant.Name
                                                                                       (autobox (hash-ref bodyguards name))))
                                           fighter)))]
                                  [result
                                   (begin
                                     (log-fight-debug "in team++, set bodyguards, second 'result' clause, result is: ~v"
                                                      result)
                                     (for/list ([fighter result])
                                       (log-fight-debug "fighter is: ~v" fighter)
                                       (define name (combatant.Name fighter))
                                       (if (hash-has-key? linked-to name)
                                           (set-combatant-Linked-to-Me fighter (map combatant.Name
                                                                                    (autobox (hash-ref linked-to name))))
                                           fighter)))])
                             result)])])
           #:rule ("sort fighters by name"
                   #:transform fighters (fighters)
                   [(sort-str #:key combatant.Name fighters)])
           #:rule ("generate fighters-by-name"
                   #:transform fighters-by-name (fighters)
                   [(if (null? fighters)
                        (hash)
                        (hash-aggregate combatant.Name fighters))])
           #:convert-for (stats-dump (#:post
                                      (λ (h)
                                        (cond [(null? (hash-keys h)) "\n"]
                                              [else
                                               (log-fight-debug "fighters are: ~v" (sort-str #:key combatant.Name (hash-ref h 'fighters)))
                                               (string-join
                                                (for/list ([fighter (sort-str #:key combatant.Name (hash-ref h 'fighters))])
                                                  (define dump (combatant/convert->stats-dump fighter))
                                                  (log-fight-debug "dump is: ~v" dump)
                                                  dump)
                                                "\n")]))))
           #:convert-for (report-string
                          (#:post (λ (h)
                                    (if (null? (hash-keys h))
                                        "\n"
                                        (string-join
                                         (for/list ([fighter (sort-str #:key combatant.Name (hash-ref h 'fighters))])
                                           (combatant/convert->report-string fighter))
                                         "\n")))))
           )
          #:transparent)

;;----------------------------------------------------------------------

(define/contract (show-sides heroes villains)
  (-> team? team? (values team? team?))

  (for ([label '("Heroes:\n-------" "\nVillains:\n--------")]
        [the-team (list heroes villains)])
    (displayln label)
    (if (null?  (team.fighters the-team))
        (displayln " <no survivors>")
        (displayln (team/convert->report-string the-team))))
  (values heroes villains))

;;----------------------------------------------------------------------

(define/contract (partition-csv-headers headers)
  (-> (listof string?) (values (listof string?) (listof string?)))
  (partition (λ (v) (regexp-match #px"^Buff" v))  headers))

;;----------------------------------------------------------------------


(define/contract (make-combatants rows)
  (-> (non-empty-listof (non-empty-listof string?))
      team?)

  (log-fight-debug "entering make-combatants")

  ; We get a list of lists where the inner lists are a row from the CSV file.  We turn
  ; that into a hash, then into a combatant? in order to let struct++ run its rules.
  ;
  ; The combatant structs are them placed into a `team` struct which will take care of all
  ; initializations via the struct++ rules for teams.
  (define headers (car rows))
  (define-values (buff-field-names fields) (partition-csv-headers headers))
  (define num-fields (length fields))
  (team++ #:csv-headers headers
          #:apply-buffs? #t
          #:fighters (for/list ([row (cdr rows)])
                       (log-fight-debug "fields are: ~v" fields)
                       (log-fight-debug "row is: ~v" row)
                       (log-fight-debug "take ~a fields are: ~v" num-fields (take row num-fields))

                       (define base (hash->struct/kw combatant++
                                                     (for/hash ([h fields]
                                                                [v (take row num-fields)])
                                                       (values (string->symbol h)
                                                               (string-trim v)))))
                       (define c
                         (cond [(null? buff-field-names) base]
                               [else
                                (define buff-header-lists (step-by-n list buff-field-names 4))
                                ; e.g. '((BuffName BuffWho BuffOffense BuffDefense) (BuffName BuffWho BuffOffense BuffDefense))

                                (define buff-data-lists   (step-by-n list (drop row num-fields) 4))
                                ; e.g. '(("JutsuA" "Alice,Bob" 0.1 0.2) ("JutsuB" "Alice,Tom" 0.3 0.4))

                                (log-fight-debug "buff data lists: ~v "buff-data-lists)

                                ; This ended up very convoluted because I was beating my
                                ; head on a weird problem.  Turns out that csv-reading
                                ; assumes (quite reasonably) that spaces after a comma are
                                ; part of the field.  That means this is a problem:
                                ;
                                ; ...,BuffName,BuffWho,...
                                ; ...,JutsuA,   "Alice,Bob",...           <=== 2 fields, the second is: "Alice,Bob"
                                ;
                                ; The data gets interpreted like this:
                                ;
                                ; '(... "JutsuA" "   \"Alice" "Bob" ...)  <=== 3 fields, the second is "   \"Alice"
                                ;
                                ; After looking at it I've decided that I'm not going to
                                ; deal with it.  Make sure your CSV files are valid.
                                (define buffs
                                  (remove-nulls
                                   (for/list ([header-list buff-header-lists]
                                              [data-list   buff-data-lists])
                                     (define result
                                       (match data-list
                                         [(list "" "" "" "") '()]
                                         [(list name who off def)
                                          (hash 'BuffName    name
                                                'BuffWho     (string-split who ",")
                                                'BuffOffense (to-num off)
                                                'BuffDefense (to-num off))]))
                                     result)))
                                ;(log-fight-debug "buffs: ~v" buffs)
                                (set-combatant-Buffs base
                                                     (map (curry hash->struct/kw buff++)
                                                          buffs))]))
                       (log-fight-debug "combatant is: ~v" c)
                       c)))

;;----------------------------------------------------------------------

; generate-matchups  side1 side2
;
; Takes two teams, returns a LoL where the inner lists are (attacker defender ..+). It's
; usually only 1 defender, but attackers with AOE attacks might hit multiple people.  If a
; chosen defender has bodyguards then a random pick from the bodyguards will be
; substituted for that defender when the list is assembled.  Bodyguards can defend their
; protectee against multiple attacks per round.  The CSV file format forbids a given
; combatant from bodyguarding more than one person.
;
; NOTE: If Alice has multiple attacks then she might end up attacking Bill multiple times,
; either because she randomly chose him multiple times or because she chose him as a
; primary target and then chose someone that he was bodyguarding.
(define/contract (generate-matchups attack-team defend-team)
  (-> team? team? (non-empty-listof matchup?))

  (log-fight-debug "entering generate-matchups. attackers/defenders are:\n\t ~v\n\t ~v"
                   (team.fighters attack-team)
                   (team.fighters defend-team))

  (define defenders  (team.fighters defend-team))
  (for/list ([attacker (team.fighters attack-team)])
    (log-fight-debug "attacker : ~a" (combatant.Name attacker))
    (define num-defenders (combatant.AOE attacker))
    (define defender-names
      (for/list ([i        num-defenders])
                             (define defender (pick defenders))
                             (log-fight-debug "chose defender: ~v" defender)

                             ;; If someone is being bodyguarded then we'll substitute a
                             ;; bodyguard IFF the bodyguard is actually still alive and on
                             ;; the team instead of a leftover artifact who was killed in
                             ;; an earlier round.
                             (match (set-intersect (combatant.Bodyguarding-Me defender)
                                                   (map combatant.Name defenders))
                               ['() (combatant.Name defender)]
                               [bodyguards
                                ; Bodyguards are allowed to block more than one attack per
                                ; turn so it's okay if we end up picking the same one
                                ; multiple times.
                                (define bodyguard (pick bodyguards))
                                ;(log-fight-debug "chose bodyguard: ~a" (combatant.Name bodyguard))
                                (displayln (format "NOTE: ~a tried to attack ~a, but ~a jumped in the way!"
                                                   (combatant.Name attacker)
                                                   (combatant.Name defender)
                                                   bodyguard))
                                bodyguard])))
    (matchup++ #:attacker  (combatant.Name attacker)
               #:defenders defender-names)))

;;----------------------------------------------------------------------

(define (roll dice chance)
  (for/sum ([n dice])
    (if (<= (random) chance)
        1
        0)))

;;----------------------------------------------------------------------

(define/contract (generate-hits fighter)
  (-> combatant? natural-number/c)

  (roll (combatant.OffenseDice fighter)  (combatant.ToHit fighter)))

;;----------------------------------------------------------------------

(define/contract (block-hits fighter)
  (-> combatant? natural-number/c)

  (roll (combatant.DefenseDice fighter) (combatant.ToDefend fighter)))

;;----------------------------------------------------------------------

(define/contract (make-more-tired fighter)
  (-> combatant? combatant?)
  (set-combatant-ToDefend fighter
                          (clip-to-range (- (combatant.ToDefend fighter)
                                            EXHAUSTION-PENALTY)
                                         MIN-TO-DEFEND
                                         MAX-TO-DEFEND)))

;;----------------------------------------------------------------------

(define/contract (handle-one-attack attacker defender)
  (-> combatant? combatant? combatant?)
  (define attacker-name (combatant.Name attacker))
  (define defender-name (combatant.Name defender))

  (define damage-dealt (- (generate-hits attacker)
                          (block-hits    defender)))
  (match damage-dealt
    [(? positive?)
     (displayln (format "~a hit ~a for ~a points of damage!"
                        attacker-name defender-name damage-dealt))
     (set-combatant-HP defender (- (combatant.HP defender)
                                   damage-dealt))
     ]
    [_ (displayln (format "~a swung at ~a and missed!"
                          attacker-name
                          defender-name))
       defender]))

;;----------------------------------------------------------------------

(define/contract (fight-one-round h-team v-team)
  (-> team? team? (values team? team?))

  (log-fight-debug "entering fight-one-round with heroes:\n ~a \n villains: ~a"
                   h-team v-team)

  ; heroes attack villains first, then vice versa.  All attacks are simultaneous, no one
  ; is marked dead until the round is over.  At the end we return new team structs with
  ; the updated combatants
  (define-values (heroes-team villains-team)
    (let loop ([attacking-team         h-team]
               [defending-team         v-team]
               [first-half-results     #f]
               [is-second-half?        #f])

      (define matchups (generate-matchups attacking-team defending-team))
      (displayln "")
      
      ;; Notes:  defender-name-groups is a LoL, usually with only one item in the inner list
      ;;
      ;; Multiple attackers can attack the same target
      ;; Example: assume that Alice gets 3 attacks and everyone else gets 1
      ;; e.g. attacker-names:       '("Alice" "Bill" "Charlie")
      ;; e.g. defender-name-groups: '(("Enemy1" "Enemy2" "Enemy3") ("Enemy2") ("Enemy9"))
      ;;
      (define all-attackers-by-name (team.fighters-by-name attacking-team))
      (define all-defenders-by-name (team.fighters-by-name defending-team))

      (define surviving-defenders-hash
        (for/fold ([survivors        all-defenders-by-name])
                  ([current-matchup  matchups])

          (match-define (struct* matchup ([attacker attacker-name] [defenders defender-names]))
            current-matchup)
          (define attacking-combatant  (hash-ref   all-attackers-by-name attacker-name))
          (define defending-combatants (filter-not false?
                                                   (hash-slice survivors
                                                               defender-names
                                                               #f)))
          (cond [(null? defending-combatants) survivors]
                [else
                 (for/fold ([survivors           survivors])
                           ([defending-combatant defending-combatants])

                   (define updated-defender
                     (handle-one-attack attacking-combatant
                                        defending-combatant))
                   (cond [(is-alive? updated-defender)
                          (hash-set survivors
                                    (combatant.Name updated-defender)
                                    updated-defender)]
                         [else
                          (define def-name  (combatant.Name updated-defender))
                          (define links
                            (set-intersect (combatant.Linked-to-Me updated-defender)
                                           (hash-keys survivors)))
                          (when (not (null? links))
                            (displayln (format "~a was killed and had combatants linked to them.  Killing those combatants and anyone recursively linked to them."
                                               def-name)))
                          (let kill-linked ([survivors    survivors]
                                            [linked-names (cons def-name links)])
                            (define updated-survivors (safe-hash-remove survivors
                                                                        linked-names))
                            (match updated-survivors
                              [(hash-table)
                               updated-survivors]
                              [(? hash?)
                               #:when (equal? (hash-keys updated-survivors)
                                              (hash-keys survivors))
                               updated-survivors]
                              [else
                               (kill-linked updated-survivors
                                            (remove-duplicates
                                             (flatten
                                              (map combatant.Linked-to-Me
                                                   (filter combatant?
                                                           (hash-slice all-defenders-by-name
                                                                       linked-names
                                                                       #f))))))]))]))])))
      (define names-killed (set-subtract (hash-keys all-defenders-by-name)
                                         (hash-keys surviving-defenders-hash)))
      (match names-killed
        ['()
         (displayln (format "\tKilled:  <no one>"))]
        [else
         (displayln (format "\tKilled: ~a"
                            (string-join (sort-str names-killed) ", ")))])

      (define final-defenders-hash
        (for/hash ([(name fighter) (in-hash surviving-defenders-hash)])
         (values name
                 (let* ([fighter
                         (set-combatant-Bodyguarding-Me
                          fighter
                          (set-subtract (combatant.Bodyguarding-Me fighter)
                                        names-killed))]
                        [fighter
                         (set-combatant-Linked-to-Me
                          fighter
                          (set-subtract (combatant.Linked-to-Me fighter)
                                        names-killed))])
                   fighter))))



      ;; The heroes attack first / defend second, so they will be defender-map when the
      ;; round ends.  Therefore, defenders get returned in first position at the end.
      ;;
      ;; After each round we reduce ToDefend by EXHAUSTION-PENALTY.  This ensures that the
      ;; fight will still eventually end even if everyone starts off with super high
      ;; ToDefend scores that render them untouchable.
      (match is-second-half?
        [#f (log-fight-debug "going into second half of fight-one-round")
            (displayln "")
            (loop     defending-team ; villains become attackers
                      attacking-team ; heroes   become defenders
                      (team++ #:csv-headers  (team.csv-headers defending-team)
                              #:apply-buffs? #f
                              #:fighters     (map make-more-tired
                                                  (hash-values surviving-defenders-hash)))
                      #t)]
        [#t (log-fight-debug "leaving let loop in fight-one-round")
            (values (team++ #:csv-headers  (team.csv-headers defending-team)
                            #:apply-buffs? #f
                            #:fighters     (map make-more-tired
                                                (hash-values surviving-defenders-hash)))
                    first-half-results)])))

  (log-fight-debug "leaving fight-one-round")
  (displayln "\n Round ends.  Survivors are:\n\n")
  (show-sides heroes-team villains-team))

;;----------------------------------------------------------------------

(define/contract (write-combatant-data heroes villains)
  (-> team? team? any)

  (define heroes-final-path   (path->string     (build-path 'same "Heroes-final.csv")))
  (define villains-final-path (path->string     (build-path 'same "Villains-final.csv")))
  (displayln (format "\nDumping the final state of all combatants to ~a and ~a"
                     heroes-final-path
                     villains-final-path))
  (with-output-to-file
    #:exists 'replace
    heroes-final-path
    (thunk
     (displayln (string-join (team.csv-headers heroes) ","))
     (for ([x (team.fighters heroes)])
       (displayln (combatant/convert->stats-dump x)))))

  (with-output-to-file
    #:exists 'replace
    villains-final-path
    (thunk
     (displayln (string-join (team.csv-headers villains) ","))
     (for ([x (team.fighters villains)]) (displayln (combatant/convert->stats-dump x))))))

;;----------------------------------------------------------------------

(define (get-csv-data)
  (define heroes-rows   (csv->list (open-input-file (heroes-filepath))))
  (define villains-rows (csv->list (open-input-file (villains-filepath))))

  (when (< (length heroes-rows) 2)
    (error "Heroes.csv must have at least two rows: headers and one combatant"))
  (when (< (length villains-rows) 2)
    (error "Villains.csv must have at least two rows: headers and one combatant"))

  (log-fight-debug "Got the files loaded")

  (define heroes-headers    (map string-trim (car heroes-rows)))
  (define villains-headers  (map string-trim (car villains-rows)))

  (define-values (h-buff-fields h-fields) (partition-csv-headers heroes-headers))
  (define-values (v-buff-fields v-fields) (partition-csv-headers villains-headers))

  (log-fight-debug "h buff fields: ~v" h-buff-fields)
  (log-fight-debug "v buff fields: ~v" v-buff-fields)
  (log-fight-debug "h fields: ~v" h-fields)
  (log-fight-debug "v fields: ~v" h-fields)

  (when (not (equal? h-fields v-fields))
    (error "Headers in Heroes.csv and Villains.csv must match aside from 'Buff*' fields"))

  (for ([h (step-by-n list h-buff-fields 4)])
    (match h
      [(list "BuffName" "BuffWho" "BuffOffense" "BuffDefense") 'ok]
      [_     (error (format "Buff fields in heroes file must be these names in this order: ~a ~a ~a ~a"))]))

  (for ([v (step-by-n list v-buff-fields 4)])
    (match v
      [(list "BuffName" "BuffWho" "BuffOffense" "BuffDefense") 'ok]
      [_     (error (format "Buff fields in villains file must be these names in this order: ~a ~a ~a ~a"
                            "BuffName" "BuffWho" "BuffOffense" "BuffDefense"))]))

  (log-fight-debug "headers matched")
  (values heroes-rows villains-rows))

;;----------------------------------------------------------------------
;;----------------------------------------------------------------------
;;----------------------------------------------------------------------
; program start


(define (run)
  ; Retrieve and validate the CSV files
  (define-values (heroes-rows villains-rows) (get-csv-data))

  ; Turn the CSV records into structs
  (define heroes-team   (make-combatants heroes-rows))
  (define villains-team (make-combatants villains-rows))

  (log-fight-debug "heroes-team: ~v" heroes-team)
  (log-fight-debug "villains-team: ~v" villains-team)

  (displayln "At start of battle, the sides are:\n")
  (show-sides heroes-team villains-team)

  (let loop ([heroes-team   heroes-team]
             [villains-team villains-team]
             [round#   1])
    (define heroes   (team.fighters heroes-team))
    (define villains (team.fighters villains-team))
    (log-fight-debug "loop for round ~a" round#)

    (cond [(> round# (max-rounds))
           (displayln "\n\n Battle ends! Max number of rounds fought.")
           (write-combatant-data heroes-team villains-team)]
          [(or (null? heroes)
               (null? villains))
           (displayln "\n\n Battle ends!  One side has been eliminated.")
           (write-combatant-data heroes-team villains-team)]
          [else
           (displayln (format "\n\tRound ~a, fight!" round#))

           (define-values (ht vt)
             (fight-one-round heroes-team villains-team))

           (log-fight-debug "after fight-one-round for round ~a. number of surviving heroes: ~a. number of surviving villains: ~a "
                            round#
                            (length (team.fighters heroes-team))
                            (length (team.fighters villains-team)))

           (loop ht
                 vt
                 (add1 round#))])))

(define logfilepath   (build-path 'same "BattleLog.txt"))

;  Run the fight and send the output to the log file
(module+ main
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
     (displayln (format "\n\t NOTE: Output was saved to '~a'" (path->string logfilepath)))
     ))

  ; display the log file to STDOUT
  (displayln (file->string logfilepath))
  )
