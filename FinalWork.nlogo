;--------------------------------------------------
; Random Money Laundering Dataset Generation
; Developed by: Ítalo Della Garza Silva
; 2021-22-11
; Course: Agent-Based Modeling
; Federal University of Lavras - UFLA
;--------------------------------------------------

extensions [rnd]

breed [people person]
breed [accounts account]

globals [
  n-transactions ; number of transactions until that timestamp
  n-ilegal ; number of ilegal transactions until that timestamp
  n-passage-tr ; number of transactions performed by passage
               ;accounts until that timestamp
]

people-own [
  predisposition ; Predisposition to do ML
  n-connections ; Number of connections in financial network
]

accounts-own [
  financial-inst ; Financial institution where the account is registered.
  main ; If this account is the main account of its proprietary or not.
  remaining-transactions;
  most-recent? ; If this account is the most recently created to that user
              ; (used to control).
]

;--------------------------------------------------
; MAIN CONTROL PROCEDURES
;--------------------------------------------------
to setup
  clear-all
  reset-ticks
  set-default-shape people "person"
  ask patches [ set pcolor blue ]
  make-people
  make-network
  ask links [ set color black ]
  if file-exists? "output.csv" [file-delete "output.csv"]
  file-open "output.csv"
  file-type "TIMESTAMP;ID_ORIGIN;ID_DESTINATION;ACC_ORIGIN;"
  file-type "ACC_DESTINATION;FI_ORIGIN;FI_DESTINATION;VALUE;IS_ML\n"
  file-flush
  file-close
  initialize-globals
end


to initialize-globals
  set n-transactions 0
  set n-ilegal 0
  set n-passage-tr 0
end


to go
  let n-emissors em-per-timestamp * n-people
  ask n-of n-emissors people [ schedule-transactions ]
  ; delete passage accounts with no more remaining transactions to perform
  ask accounts with [ main = false and empty? remaining-transactions ] [ die ]
  ask links [set color black]
  ask accounts [ perform-sched-transactions ]
  tick
end

;--------------------------------------------------
; IMPLEMENTATION PROCEDURES
;--------------------------------------------------

to make-people
  create-people n-people [
    set size 3
    set color yellow
    set predisposition random-float 1
    ; Create main accounts.
    let main-acc register-bank-account (random n-financial-inst) true
  ]
  layout-circle sort people max-pxcor - 1
end

to make-network
   ask people [
    set n-connections ((random ( max-connections - 1 )) + 1)
  ]
  ;creates one initial connection to each agent
  ask people [
    set n-connections ((random ( max-connections - 1 )) + 1)
    if (count other people with [(count people-on link-neighbors) < n-connections] > 0) [
      create-link-with rnd:weighted-one-of

      other people with [ (count people-on link-neighbors) < n-connections ]
      [
        ; As the difference between the predispositions increases,
        ; the chance to be a connection decreases.
        1.0f - ( predisposition - ( [ predisposition ] of myself) )
      ]
    ]
  ]
  ; Perform the restant links
  ask people [
    let remaining-con n-connections - ( count people-on link-neighbors)
    while [remaining-con > 0 and (count other people with [(count people-on link-neighbors) < n-connections]) > 0] [

      create-link-with rnd:weighted-one-of
      other people with [ (count people-on link-neighbors) < n-connections ]
      [
        ; As the difference between the predispositions increases,
        ; the chance to be a connection decreases.
        1.0f - ( predisposition - ([predisposition] of myself))
      ]
      set remaining-con remaining-con - 1
    ]
    set n-connections count people-on link-neighbors
  ]
end

to schedule-transactions
  ; account choice
  let orig-acc one-of accounts-on (accounts-on link-neighbors) with [ main = true ]
  let orig-bank [ financial-inst ] of orig-acc

  ; deciding the transactions to be performed
  let is-ml? random-bernoulli (predisposition * criminal-inf)
  ifelse is-ml? [
    ; total value generation
    let total-value 2 * (beta 5 1) * max-perm-value
    ; transaction amounts generation
    let next-to-max-perm? random-bernoulli 0.5
    let values []
    ifelse next-to-max-perm? [
      while [ total-value > 0 ] [
        let sd random-float (max-perm-value * 0.05) + 0.01
        let value max-perm-value - sd
        set values lput value values
        set total-value total-value - value
      ]
    ]
    [
      let central random (max-perm-value / 1000) - 1
      while [ total-value > 0 ] [
        let sd random-float (central * 0.05) - (central * 0.025)
        let value max-perm-value - sd
        set values lput value values
        set total-value total-value - value
      ]
    ]
    ; destination choice
    let dest rnd:weighted-one-of people-on link-neighbors [ predisposition ]
    let dest-acc [ one-of accounts-on ( accounts-on link-neighbors ) with [ main = true ]] of dest
    let dest-bank [ financial-inst ] of dest-acc



    ; separates the origin and the destination financial instituitions (to create
    ; the passage accounts above).
    let financial-insts-orig-dest []
    let other-financial-insts []

    let remaining-insts n-financial-inst - 1
    while [ remaining-insts >= 0 ] [
      ifelse remaining-insts = orig-bank or remaining-insts = dest-bank [
        set financial-insts-orig-dest lput remaining-insts financial-insts-orig-dest
      ]
      [
        set other-financial-insts lput remaining-insts financial-insts-orig-dest
      ]
      set remaining-insts remaining-insts - 1
    ]

    ; passage accounts generation (all transactions will be in the same day)
    let n-passage-acc random 3
    let passage-accs []
    while [ n-passage-acc > 0 ] [
      ; Choice randomly the accont owner
      let destiny-owner? random-bernoulli 0.5
      ; Choice randomly (with weights) the financial institute of account
      let same-fi? random-bernoulli (1 / n-financial-inst)
      let f-inst ifelse-value same-fi? [ one-of financial-insts-orig-dest ] [ one-of other-financial-insts ]
      ifelse destiny-owner? [
        let new-p-account [register-bank-account f-inst false] of dest
      ]
      [
        let new-p-account register-bank-account f-inst false
      ]

      set passage-accs lput (register-bank-account f-inst false) passage-accs
      set n-passage-acc n-passage-acc - 1
    ]

    let pass-acc? not (empty? passage-accs)

    ; ask the accounts to schedule transactions
    let n-timestamps 0
    foreach values [ value ->
      ; 1 - send from the origin main account to the first passage account.
      ask orig-acc[
        ; get temporary destination account
        ; (if there's no passage accounts, it will be the destination, directly).
        let tmp-dest-acc ifelse-value pass-acc? [ first passage-accs ][ dest-acc ]
        ;get temporary destination account owner
        let tmp-dest one-of people-on [ link-neighbors ] of tmp-dest-acc
        ;schedule transaction
        account-sched-transaction (ticks + n-timestamps) tmp-dest myself tmp-dest-acc 1 value
      ]

      if pass-acc? [

        ; 2 - send from one passage account to the other, following the list.
        (foreach (but-last passage-accs) (but-first passage-accs) [ [ passage-acc-1 passage-acc-2 ] ->
          ; get account 1 owner
          let acc-1-owner one-of people-on [ link-neighbors ] of passage-acc-1

          ; get account 2 owner
          let acc-2-owner one-of people-on [ link-neighbors ] of passage-acc-2

          ;schedule transaction
          ask passage-acc-1 [
            account-sched-transaction (ticks + n-timestamps) acc-2-owner acc-1-owner passage-acc-2  1 value
          ]

        ])
        ; 3 - send from the last passage account in the list to the destination account.

        ask last passage-accs [
          let tmp-orig one-of people-on [ link-neighbors ] of self
          account-sched-transaction (ticks + n-timestamps) dest tmp-orig dest-acc 1 value
        ]
      ]
      set n-timestamps n-timestamps + 1
    ]

  ]
  [
    ; defining a value lesser than the max permitted one
    let value random ( max-perm-value - 0.02) + 0.01
    let dest one-of people-on link-neighbors
    let dest-acc [ one-of accounts-on ( accounts-on link-neighbors ) with [ main = true ]] of dest
    ; ask the main account to schedule transaction
    ask orig-acc [
      account-sched-transaction ticks dest myself dest-acc 0 value
    ]
  ]
end


to account-sched-transaction [#timestamp #dest #orig #dest-acc #illegal #value]
  let orig-acc-id [ who ] of self
  let orig-fi [ financial-inst ] of self
  let orig-id [ who ] of #orig
  let dest-fi [ financial-inst ] of #dest-acc
  let dest-id [ who ] of #dest
  let dest-acc-id [ who ] of #dest-acc
  let transaction (list #timestamp orig-id dest-id orig-acc-id dest-acc-id orig-fi dest-fi (precision #value 2) #illegal)
  set remaining-transactions lput transaction remaining-transactions
end

to-report register-bank-account [ #f-inst #is-main? ]
  let return 0
  ask accounts-on link-neighbors [
    set most-recent? false
  ]

  hatch-accounts 1 [
    set financial-inst #f-inst
    create-link-with myself [ hide-link ]
    set remaining-transactions []
    set main #is-main?
    hide-turtle
    set most-recent? true
  ]
  report one-of (accounts-on link-neighbors) with [ most-recent? = true ]
end


to perform-sched-transactions
  file-open "output.csv"
  foreach remaining-transactions [ elem ->
    let timestamp first elem
    if timestamp = ticks [
      let con-lnk link (item 1 elem) (item 2 elem)
      if con-lnk != nobody [ ; check if the link exists in sotial network
                             ; (if this is not a link from the person to itself).
        ask con-lnk [ set color ifelse-value (last elem = 1) [ red ] [ green ] ]
      ]
      file-type timestamp
      foreach but-first elem [ col ->
        file-type ";"
        file-type col
      ]
      file-type "\n"

      if last elem = 1 [ set n-ilegal n-ilegal + 1 ]
      if  member? (item 3 elem) ([ who ] of accounts with [ main = false ]) [
        set n-passage-tr n-passage-tr + 1
      ]
      set n-transactions n-transactions + 1
    ]

  ]
  file-flush
  file-close
  set remaining-transactions filter [ elem -> item 0 elem > ticks ] remaining-transactions
end

;--------------------------------------------------
; UTILITY PROCEDURES
;--------------------------------------------------


to-report random-bernoulli [ #p ]
  report random-float 1 < #p
end

to-report beta [ #alpha #beta ]
  let XX random-gamma #alpha 1
  let YY random-gamma #beta 1
  report XX / (XX + YY)
end
@#$#@#$#@
GRAPHICS-WINDOW
166
10
629
474
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-45
45
-45
45
0
0
1
ticks
30.0

BUTTON
22
71
95
105
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
801
65
1014
98
n-people
n-people
0
200
50.0
1
1
NIL
HORIZONTAL

SLIDER
802
132
1012
165
criminal-inf
criminal-inf
0
1
0.76
0.01
1
NIL
HORIZONTAL

SLIDER
801
203
1017
236
n-financial-inst
n-financial-inst
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
803
269
1017
302
max-connections
max-connections
0
10
5.0
1
1
NIL
HORIZONTAL

BUTTON
23
119
92
152
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
804
335
1017
368
em-per-timestamp
em-per-timestamp
0
1
0.6
0.01
1
NIL
HORIZONTAL

SLIDER
804
406
1022
439
max-perm-value
max-perm-value
1.0
10000
10000.0
0.01
1
NIL
HORIZONTAL

PLOT
1049
14
1532
340
% of Money Laundering and Passage Accounts Transactions
Timestamp
%
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Money Laundering (%)" 1.0 0 -16777216 true "" "plot ifelse-value (n-transactions = 0) [ 0 ][ n-ilegal / n-transactions * 100 ]"
"Passage account transactions" 1.0 0 -2674135 true "" "plot ifelse-value n-transactions = 0 [ 0 ] [ n-passage-tr * 100 / n-transactions ]"

MONITOR
1061
362
1233
407
# of Transactions
n-transactions
0
1
11

MONITOR
1252
363
1403
408
# of Money Laundering
n-ilegal
17
1
11

TEXTBOX
656
71
806
89
# of people:
13
0.0
1

TEXTBOX
655
126
805
160
Criminal influence factor:
13
0.0
1

TEXTBOX
656
207
806
241
# of financial institutions:
13
0.0
1

TEXTBOX
658
252
808
303
Maximum # of connections to each person:
13
0.0
1

TEXTBOX
656
317
806
368
Proportion of emissions at each timestamp:
13
0.0
1

TEXTBOX
654
386
804
437
Maximum permitted value in one transaction:
13
0.0
1

TEXTBOX
762
17
912
36
Control Variables
16
0.0
1

TEXTBOX
17
27
167
46
Main Controls
16
0.0
1

@#$#@#$#@
# Money Laundering Dataset Generator
## WHAT IS IT?

This model attempts to simulate a financial transactions dataset generation, with the presence of money laundering operations. In this model, the agents are people who have a bank account and eventually performs money laundering transactions. The model generates a file with the transactions (with and without ml) at the end of this execution. Concerning the Money Laundering transactions, this model tries to cover the following techniques generally performed by criminals:

- __Smurfing__: The repeated transaction sets have a standard deviation attached, which covers it's identification.

- __Passage Accounts__: Accounts used only to transfer the amount to another one, to prevent the finding of money source at the investigation.

- __Transaction Values Rounding__: The repeated transactions generally are rounded to a value divisible by 1,000.

## HOW IT WORKS

The model has two types of agents:

- __Person__: The agent who will open the accounts and take the decisions. It owns a predisposition value to realize money laundering (between 0 and 1) and the number of connections in the social network, used during its initialization.

- __Account__: The account used by a person to perform the financial transactions. The accounts are associated to a financial institute identifier. They have a variable to list the remaining scheduled transactions to perform and two boolean variables to indicate if it was the last opened by the owner and if it is the main owner's account or just a passage account.

People are arranged in a communication network, structured as an undirected graph. They select the destination of their transaction considering only their links in the network.


### SETUP

In the setup, a number of people (setable trough the variable `n-people`) is created in the environment, with a random predisposition value. Then, the social network is constructed, according to the following constraints:

- Each person will have a number of connections smaller than a global maximum number value (and this value is setable through the variable `max-connections`). 
- Each person will have at least one connection. To attend this constraint, a unique connection is created initially to each person before the creation of the other links to attenf the person's number of connections.
- People with similar predisposition are more likely connected. To attend this constraint, each other person will have a weight associated at the moment of the choice to be the one person connection, which is obtained from the difference between two person's predisposition minus 1, that is, smaller differences generates a bigger weight.

### EXECUTION

At each step of the execution, a proportion of people will schedule a transaction. To each person, it is asked to perform a transaction, which will be a money laundering operation or not according to a Bernoulli Distribution with the probability determined by the product of the person's predisposition and a criminal influence factor. Each of these situations have their own particularities:
- If the transaction is Money Laundering: 
	- The most likely destination are the ones with biggest predisposition (also chosen trough weights).
	- The amount has a biggest probability to be higher than the maximum permitted value. Various successive transactions are scheduled to cover the total.
	- A layer scheme with passage accounts can be constructed or not (with 50% probability) and they are randomly owned by the destination person or the sender.
	- The financial institution of the passage accounts is most likely different of the origin account's one.
	- Each scheduled transaction's amount value has it's average next to a value divisible by 1,000 with a small random deviation (positive or negative), or a little smaller than the maximum permitted with a small negative deviation.
- If the transaction is not a Money Laundering:
	- The amount will be lesser than the maximum permitted value.
	- The transaction will be done within a single timestep.

After scheduling, at the same timestep, each account is verified in order to perform their scheduled transactions to that timestep. The transactions are recorded in an output file (`output.csv`) which has the register of each transaction described by the following variables:

- __`TIMESTAMP`__: The transaction timestamp.
- __`ID_ORIGIN`__: The `who` variable of the origin.
- __`ID_DESTINATION`__: The `who` variable of the destination. 
- __`ACC_ORIGIN`__: The `who` variable of the origin's account.
- __`ACC_DESTINATION`__: The `who` variable of the destination's account.
- __`FI_ORIGIN`__: The financial institution number of the origin.
- __`FI_DESTINATION`__: The financial institution number of the destination.
- __`VALUE`__: The transaction value.
- __`IS_ML`__: If is a money laundering (1) or not (0).



## HOW TO USE IT

You can initialize the model by "setup" button and execute it by the "go" button. There are many sliders to control other variables in the model:

- `n-people`: Determines the number of people created in the setup.
- `criminal-inf`: Determines the factor of criminal influence in the model. Higher values will result in most Money Laundering transactions.
- `n-financial-inst`: The number of financial institutions in the model.
- `max-connections`: The maximum number of connections to each person in the social network.
- `em-per-timestamp`: The proportion of the people who will perform emissions at each timestamp.
- `max-perm-value`: The maximum permitted transaction value.

It is possible to see the proportion of Money Launderig and passage accounts transactions at each timestamp through a line graph, as the numeric number of total transactions and money laundering transactions. In the environment world window, it is possible to see the people's social network, and the transactions being performed between them at each timestep. When the link becomes green, there is a normal transaction between the two persons linked. When the link becomes red, it's a Money Laundering transaction.

At each time when the model setups, a new "output.csv" file is created containing only the reader with the column names. During the execution, the transactions performed are registered in the last line of this file, building the dataset. 


## NETLOGO FEATURES

This model makes use of the `rnd` extention to generate some random variables.


## CREDITS AND REFERENCES

This model was inspired by the following works:

- https://ccl.northwestern.edu/2005/Generating_Fraud_Agent_Based_Financial_N.pdf
- https://github.com/EdgarLopezPhD/PaySim
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>ifelse-value (n-transactions = 0) [ 0 ][ n-ilegal / n-transactions * 100 ]</metric>
    <metric>ifelse-value n-transactions = 0 [ 0 ] [ n-passage-tr * 100 / n-transactions ]</metric>
    <metric>n-transactions</metric>
    <enumeratedValueSet variable="n-people">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="criminal-inf">
      <value value="0.1"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="n-financial-inst">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-connections">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="em-per-timestamp">
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-perm-value">
      <value value="2000"/>
      <value value="5000"/>
      <value value="10000"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
