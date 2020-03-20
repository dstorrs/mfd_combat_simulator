# mfd-combat-simulator

Simulator for large-scale combat in Marked for Death.  Currently, this contains Fight.rkt,
Heroes.csv, and Villains.csv.

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

## Fighters

Fighters are defined in the Heroes.csv and Villains.csv files. (See below for details.)

Each fighter has a variety of stats that work together to generate three numbers:

    - Dice      : The number of chances to generate or block a hit
    - ToHit     : The % chance of each die succeeding when attacking
    - ToDefend  : The % chance of each die succeeding when blocking

If a fighters has (e.g.) 6 dice then they generate at most 6 hits and can block at most 6
hits.

## Combat Explained

Combat works as follows:

 Step 1: Choose matchups.  See below for details.

 Step 2: For each matchup, the attacker rolls to generate hits and the defender rolls to
 block hits.  Each unblocked hit costs the defender 1 HP.  Fighters die at 0 HP.  By
 default they start at 2 HP.  (See below.)  NOTE: Fighters are not removed from combat
 until the end of the round, so even if they are killed they will get one last chance to
 swing at their foe, although that's probably not the person who killed them. 

 Step 3: Display the results of the fight.
 
 Step 4: If the defender has been reduced to 0 or fewer hitpoints, everyone who is linked
 to them (cf the LinkedTo field) has their hit points set to 0.  (Unless they are already
 below 0, in which case their HP is not changed.)  If anyone is eliminated this way,
 display a message to that effect.

 Step 5: Remove dead fighters.  If one side has been eliminated, announce that and stop.

 Step 6: Goto Step 1


## Matchups and Generating/Blocking Hits

Each round, heroes and villains are matched up against one another as follows:

  for each fighter
    choose a random opponent
      if the chosen opponent has one or more bodyguards, choose a random bodyguard instead
      else, use the chosen opponent

Everyone will attack each round. The matchups are random so it's possible that some people will get attacked multiple times and some people won't be attacked at all.  Also, it's usually not the case that two people swing at each other, so a defender is generally not going to hit back at their attacker.

Once matchups are assigned, the attacker rolls (Dice) percentile dice; any roll that is
<= ToHit generates a potential hit.  The defender then rolls (Dice) percentile dice; any
roll that is <= ToDefend will block one incoming hit.  As mentioned above, (potential hits) - (blocked hits) is the number of HP inflicted on the defender for that round.

## The Heroes.csv and Villains.csv Spec

To adjust the combatants, simply modify Heroes.csv and/or Villains.csv. A data spec for
the CSV files follows:

### All Headers

Name,XP,BonusXP,Wounds,BonusHP,BonusToHit,BonusToDefend,BuffNextNumAllies,BuffAlliesOffense,BuffAlliesDefense,LinkedTo,BodyguardFor


### Headers Explained

Name              -- The name of each combatant. MUST be unique within its file.

XP                -- The combatant's number of XP.  This determines how many dice they roll to attack/defend.  Dice = ceiling((XP + BonusXP) / 1000)

BonusXP           -- A number of XP to fudge the ninja's power by.  Can be positive or negative.  This is here so that you can leave the actual XP number undisturbed but experiment with tweaks to represent factors that aren't well handled otherwise.

Wounds            -- number of wounds a ninja starts with.  This will normally be 0.  It can be used to simulate ninja who start the battle injured, or to simulate Shadow Clones / Summoned creatures, who pop as soon as they take any damage and should therefore start with only 1 hit point.

BonusHP           -- combatants start with HP = 2 + BonusHP - Wounds.  They lose one when they take a wound in combat. They die when their HP hits 0. 

BonusToHit        -- A decimal number 0 < x < 1.  A value of 0.1 means a +10% bonus to the fighter's chance of causing damage each round.  0.23 means +23%, 0.71 = +71% etc.  No matter what bonus is specified, ToHit is capped to 5% <= x <= 99%

BonusToDefend     -- A decimal number 0 < x < 1.  A value of 0.1 (0.15, etc) means a +10% (+15%, etc) bonus to the fighter's chance of avoiding being hit each round. No matter what bonus is specified, ToDefend is capped to 0% <= x <= 90%

BuffNextNumAllies -- Number of allies below themselves in the list to apply their BuffAlliesOffense and BuffAlliesDefense to.  It's okay if this number is larger than the number of combatants left in the file.

BuffAlliesOffense -- A decimal number 0 <= x < 1, representing the percentage by which to boost allies offensive power.  "BuffAlliesOffense 0.1" means that allies get their ToHit increased by 10%, making them more likely to cause damage.  The boost only applies to the next N combatants below this one, where N is the value of BuffNextNumAllies.

BuffAlliesDefense -- Same as BuffAlliesOffense except it increases their ToDefend instead of their ToHit.

LinkedTo          -- each combatant can be linked to either 0 or 1 other combatant. A combatant dies if the person they are linked to dies.

BodyguardFor      -- the name of a person that this combatant will die to defend. Attacks against that person will be diverted to this person instead.

## Example CSV File

  Given this file:

    Name,     XP,     BonusXP, Wounds, BonusHP, BonusToHit, BonusToDefend, BuffNextNumAllies, BuffAlliesOffense, BuffAlliesDefense, LinkedTo, BodyguardFor
    Alice,    2000,   100,       0,      0,       0.1,        0,             2,                 0.2,               0,                         , 
    Bill,     1000,   10,        0,      1,       0.2,        0,             1,                 0.1,               0.7,               Alice   , Alice
    Charlie,  500,    77,        1,      0,       0,          0,             3,                 0.05,              0,                 Alice   , 
    Denise,   1500,   0,         0,      0,       0,          0.2,           1,                 0.13,              0,                 Alice   , 

  You'll get the following:
  
    Alice:	HP(2), ToHit(40%), ToDefend(30%), Total XP (2100), Dice(3), Bodyguarding <no one>, Linked to <no one>
    Bill:	HP(3), ToHit(70%), ToDefend(30%), Total XP (1010), Dice(2), Bodyguarding Alice,    Linked to Alice
    Charlie:	HP(1), ToHit(60%), ToDefend(90%), Total XP (577),  Dice(1), Bodyguarding <no one>, Linked to Alice
    Denise:	HP(2), ToHit(35%), ToDefend(50%), Total XP (1500), Dice(2), Bodyguarding <no one>, Linked to Alice

  If Alice dies, so do Bill, Charlie, and Denise.
  
  Bill will throw himself in front of any attack against Alice.  Alice cannot die until Bill dies.

  Note that Denise's BuffNextNumAllies is larger than the number of combatants remaining. This is not an issue.
  