# mfd-combat-simulator

Simulator for large-scale combat in Marked for Death.

## Installing

Check the INSTALL.md file to see what you need in order to run the code.  It's just the Racket programming environment itself plus a handful of modules.

## Running

Once that's installed, you can run from the command line or from DrRacket.

From the command line:

```
    cd <the directory this README.md is in>
    racket Fight.rkt
```

From DrRacket:

```
    File > Open > <browse to Fight.rkt>
    Racket > Run
```

A battle log will be printed to the terminal and saved to BattleLog.txt in the same
directory as this README.md file.

Additionally, the final state of all combatants will be saved to Heroes-final.csv and Villains-final.csv in the same directory as this README.md file.


## Command-line Switches

```
-m, --max-rounds  : Stop after N rounds even if there are still people alive on both sides
--heroes          : A relative path to a combatants CSV file. Default: ./Heroes.csv" 
--villains        : A relative path to a combatants CSV file. Default: ./Villains.csv"
```

You can simulate reinforcements or mid-combat healing by setting it to run for a finite number of rounds, modifying the Heroes-final.csv and Villains-final.csv files, and running it again with the command line arguments:

```
 --heroes Heroes-final.csv --villains Villains-final.csv
```

In the limiting case, run it for 1 round each time and revise the files as needed.

IMPORTANT:  The Heroes-final.csv and Villains-final.csv files get overwritten after each run, so save a copy if you need to.

## Fighters

Fighters are defined in (by default) the "./Heroes.csv" and "./Villains.csv" files. See below for details.

Each fighter has a variety of stats that work together to generate four numbers:

    - OffenseDice : The number of chances to generate a hit
    - DefenseDice : The number of chances to block a hit
    - ToHit       : The % chance of each die succeeding when attacking
    - ToDefend    : The % chance of each die succeeding when blocking

If a fighter has (e.g.) 6 (Offense | Defense)Dice then they generate at most 6 hits and can block at most 6 hits.

The number of dice a fighter has is based on their total XP score, although they will be awarded bonus offense dice if their ToHit is >100% and bonus defense dice if their ToDefend is >100%.  All buffs are applied before the >100% check is performed.

## Combat Explained

Combat works as follows:

* Step 1: Choose matchups.  See the 'Choosing Matchups' section below for details.

* Step 2: For each matchup, the attacker rolls to generate hits and the defender rolls to block hits.  See below for how hits are generated and blocked. Each unblocked hit costs the defender 1 HP.  Fighters die at 0 HP.  By default they start at 2 HP.

See the 'Generating/Blocking Hits' section below for details.
 
NOTE: Fighters are not removed from combat until the end of the round, so even if they are killed they will get one last chance to swing at their foe, although that's probably not the person who killed them.

* Step 3: Display the results of the fight.
 
* Step 4: If the defender has been reduced to 0 or fewer hitpoints, everyone who is linked to them (cf the LinkedTo field) has their hit points set to 0.  (Unless they are already below 0, in which case their HP is not changed.)  If anyone is eliminated this way, display a message to that effect.  This is used for things like 'If Naruto dies, so do Clone1, Clone2, Clone3'.

* Step 5: Remove dead fighters.  If one side has been eliminated, announce that and stop.  If we have reached the maximum allowed number of rounds, announce that and stop.

NOTE: When we stop, either because one side is dead or because we have hit max rounds, the full stats of all combatants will be written to the "./Heroes-final.csv" and "./Villains-final.csv" files.  In order to simulate, e.g., adding combatants or healing people mid-fight, run the combat for N rounds, modify the *-final.csv files, and run it again using those as your inputs.
    
* Step 6: Goto Step 1


## Choosing Matchups 

Each round, heroes and villains are matched up against one another as follows:

```
  for each fighter
    choose N random opponents, where N is the value of the fighter's AOE stat
      if a chosen opponent has one or more bodyguards, choose a random bodyguard instead
      else, add the chosen opponent to the list of people the fighter will attack
```

Bodyguards can block an unlimited number of attacks against their protectee per round.

If Alice has AOE > 1 then she will be assigned multiple defenders.  The system will try to avoid having her attack the same person twice, but this can easily happen if there aren't enough defenders available or if some of the defenders have bodyguards.

Everyone will make at least one attack each round. The matchups are random so it's possible that some people will get attacked multiple times and some people won't be attacked at all.  Also, it's usually not the case that two people will end up choosing to swing at each other, so a defender is generally not going to hit back at their attacker.

## Generating/Blocking Hits

Once matchups are assigned, combat goes:

```
  attacker rolls (OffenseDice) percentile dice. each die that is <= ToHit generates 1 potential hit
  defender rolls (DefenseDice) percentile dice. each die that is <= ToDefend blocks 1 hit
  defender loses (potential hits) - (blocked hits) HP
```

| Statistic          | Determined By|
|--------------------|--------------|
| MIN-TO-HIT         | 0.05|
| MAX-TO-HIT         | 0.99|
| MIN-TO-DEFEND      | 0|
| MAX-TO-DEFEND      | 0.90|
| EXHAUSTION-PENALTY | 0.1|
| raw-ToHit          | (0.3 + BonusToHit    + any bonuses from allies)|
| raw-ToDefend       | (0.3 + BonusToDefend + any bonuses from allies)|
| TotalXP            | (XP + BonusXP)|
| BaseDice           | ceiling(TotalXP / 1000)|
| OffenseDice        | if (raw-ToHit > 1.0) ceiling(BaseDice x ToHit). else BaseDice|
| DefenseDice        | if (raw-ToDefend > 1.0) ceiling(BaseDice x ToDefend). else BaseDice|
| ToHit              | MIN-TO-HIT <= raw-To-Hit <= MAX-TO-HIT|
| ToDefend           | MIN-TO-DEFEND <= raw-To-Defend <= MAX-TO-DEFEND|

ToDefend goes down by EXHAUSTION-PENALTY after every round.  This models people getting tired and lower on chakra.

See 'The Heroes.csv and Villains.csv Spec' section below for details on how bonuses from allies work.

## The Heroes.csv and Villains.csv Spec

To adjust the combatants, simply modify Heroes.csv and/or Villains.csv. A data spec for the CSV files follows:

### All Headers

Name,XP,BonusXP,BonusHP,BonusToHit,BonusToDefend,AOE,BodyguardFor,LinkedTo,BuffName,BuffWho,BuffOffense,BuffDefense

### Headers Explained

Name              -- The name of each combatant. MUST be unique within its file.

XP                -- The combatant's number of XP.  This influences the base number of dice they roll to attack/defend.

BonusXP           -- A number of XP to fudge the ninja's power by.  Can be positive or negative.  This is here so that you can leave the actual XP number undisturbed but experiment with tweaks to represent factors that aren't well handled otherwise.  Examples of when to use it:  A Summoner is a very powerful ninja, but before the battle she burns all her chakra on summoning and therefore is not fighting at full strength

BonusHP           -- Combatants start with HP = 2 + BonusHP.  They lose one when they take a wound in combat. They die when their HP hits 0. BonusHP can be positive or negative; negative BonusHP might be used to simulate summoned creations or Shadow Clones, both of which die on any blow and therefore should start with only 1 HP.

BonusToHit        -- A decimal number.  A value of 0.1 means a +10% bonus to the fighter's chance of causing damage each round.  0.23 means +23%, 0.71 = +71% etc.  The final ToHit value is (DEFAULT-TO-HIT + BonusToHit). No matter what, final ToHit is capped to

BonusToDefend     -- A decimal number.  A value of 0.1 (0.15, etc) means a +10% (+15%, etc) bonus to the fighter's chance of avoiding being hit each round. 

AOE               -- An integer.  This is the number of people that the combatant will attack each round.  Used to simulate AOE attacks or multiple attacks.  If <1 it will be set to 1.

BodyguardFor      -- The name of a person that this combatant will die to defend. Attacks against that person will be diverted to this person instead.

LinkedTo          -- Each combatant can be linked to either 0 or 1 other combatant. A combatant dies if the person they are linked to dies.  This can be used to model Shadow Clones who vanish if their Prime is killed, or summoned creatures who vanish when their summoner is killed.


After this point there can be 0 or more 4-column groups, each of which describes a buff that the fighter provides to themselves and/or their allies.  Each group must have exactly the following columns:

BuffName         -- The name of the buff.  Examples: 'Teamwork' or 'Defend the Log jutsu'

BuffWho          -- One or more names that specify who should get the buff. If there is more than one name then they must be double-quoted and comma-separated.  A buff may apply to the person who supplies the buff.  It may also include names that don't appear in the file; those names will be ignored.  IMPORTANT: Names may include spaces but there should be no spaces between commas and names.

BuffOffense      -- A decimal number that will be added to the person's ToHit.

BuffDefense      -- A decimal number that will be added to the person's ToDefend.

Examples that are VALID (ignoring the elided columns between Name and BuffName):

```
Name...BuffName,BuffWho,BuffOffense,BuffDefense
Alice...GeniusIntellect,"Alice,Bill,Charlie Brown",0.06,0.03
```

The above states that Alice's genius intellect grants a 6% ToHit bonus and a 3% ToDefend bonus to herself, Bill, and CharlieBrown.  For clarity, the columns between Name and BuffName have been elided, but obviously they would need to be there.

Examples that are INVALID!  WILL BLOW UP:

```
Name...BuffName,BuffWho,BuffOffense,BuffDefense
Alice...GeniusIntellect,   "Alice,Bill,Charlie Brown",0.06,0.03
```

```
Name...BuffName,BuffWho,BuffOffense,BuffDefense
Alice...GeniusIntellect,"Alice,Bill,Charlie Brown"   ,0.06,0.03
```

```
Name...BuffName,BuffWho,BuffOffense,BuffDefense
Tom...Jutsu1,Alice,Bill,Charlie Brown,0.06,0.03
```

The first and second have spaces between the double quotes and the adjacent comma.  The third has a list of multiple names that are not double quoted.

A person CAN buff themself. An error will be thrown if there are names in the BuffWhichAllies list that do not refer to a person in the CSV file.

## Example CSV File

This file represents a flying dragon and three ninja mounted on him. IMPORTANT: It's been spaced out to make it easy to read, but in practice you would need to delete all the spaces in order to make it parse correctly.

```
Name          ,XP    ,BonusXP,BonusHP,BonusToHit,BonusToDefend,AOE,BodyguardFor,LinkedTo,BuffName,BuffWho              ,BuffOffense,BuffDefense
Dragon        ,13000 ,1500   ,-1     ,0.9       ,0.1          ,   ,            ,Summoner,Mythic  ,"Dragon,Summoner,Tom",0.06       ,0.02
Summoner      ,5800,-1000    ,1      ,0.15      ,             ,   ,            ,Dragon  ,        ,                     ,           ,
Tom           ,7001,         ,0      ,0.11      ,0.01         ,   ,Summoner    ,Dragon  ,Teamwork,"Tom,Summoner" ,0.1        ,0.12
```

This is what it will result in:

```
Dragon  :	HP(1), ToHit(99%), ToDefend(42%), AOE (1), Total XP (14500), OffenseDice(19), DefenseDice(15), Bodyguarding <no one>, LinkedTo Summoner
Summoner:	HP(3), ToHit(61%), ToDefend(44%), AOE (3), Total XP (4800) , OffenseDice(5) , DefenseDice(5),  Bodyguarding <no one>, LinkedTo Dragon
Tom     :	HP(2), ToHit(57%), ToDefend(54%), AOE (2), Total XP (7001) , OffenseDice(8) , DefenseDice(8),  Bodyguarding Summon  , LinkedTo Dragon
```

Dragon's raw ToHit was higher than 100% so it was given bonus OffenseDice and then its ToHit was capped at 99%.

Dragon will attack 3 enemies each round.

If Dragon dies, so do Summoner and Tom.  (Because if the Dragon dies the others fall to their deaths.)

If Summoner dies, Dragon dies. (Because summoned creatures vanish when their summoner dies.)

Tom will throw himself in front of any attack against Summoner.  Summoner cannot die until Tom dies.



