breed [agents an-agent]
breed [cops cop]

globals [
  legitimacy       ; The perceived legitimacy of the authority
  shock_rate       ; Rate at which unexpected events may influence agent behavior
  ;noise
  shock?
  cops_ratio       ; The percentage of patches to be occupied by cops
  protestors_ratio ; The ratio of active and jailed agents to population
  world_status     ; The status of the revolution
  agent_vision     ; How many layers an agent can see
  base_legitimacy  ; The legitimacy of the government at time 0
  ;threshold
  revolution_threshold  ; The minimum protestors ratio needed for an revolution

]

agents-own [
  risk_aversion ; The level of risk aversion each agent has, from 0 to 1
  rage          ; The level of discontent or rage each agent has, from 0 to 1
  status        ; The current status of the agent: "active", "quiet", "jailed", "killed", "migrated"
  vision        ; How far the agent can see (number of layers)
  jailed_time     ; The amount of time the agent has been jailed
  neighbor_killed ; The number of killed agents in the vision
  neighbor_active
  neighbor_migrated
  neighbor_jailed
  neighbor_ready
  ;neighbor_killed2
  ;neighbor_active2
  ;neighbor_migrated2
  ;neighbor_jailed2
  ;neighbor_ready2
]

cops-own [
  cop_vision   ; How far a cop can see
  ; cop_status
  violence_level  ; The determinant of likelihood of killing an active agent
]

to setup
  clear-all

  set base_legitimacy (Quality-of-life-index / 79 * 100 + Corruption-perceptions-index / 90 * 100) / 200     ; The base legitimacy of a government is a function of (relative) quality of life index and (relative) corruption index
  set legitimacy base_legitimacy ; The legitimacy of a government can decrease by the number if "killed" agents.
  ;set threshold 0
  set shock_rate Shock-Rate       ; The average number of unreasonable acts of government in one year
  set cops_ratio cops-density     ; The ratio of cops to the total patches

  set agent_vision initial-agents-vision ; How far an agent can get information. Min is 2 and max (in case of internet connection) is the lattice size /2 . If internet is disconnected the agent-vision decreases to 2.
  set revolution_threshold 0.5


  ; Create the world of size 30*30
  resize-world 0 19 0 19
  set-patch-size 20         ; Adjust the patch size for better visibility
  ask patches [ set pcolor white ]  ; Set the background color to white

  ; Create agents
  let total_patches count patches
  let agent_patches 80 / 100 * total_patches
  let cop_patches cops_ratio / 100 * total_patches

  ; Ensure there's no overlap by using sprout
  ; Create agents first
; Create agents
ask n-of agent_patches patches [
  sprout-agents 1 [
    set risk_aversion random-float 1.0
    set rage random-float 1.0 / 3
    let condition rage - risk_aversion - legitimacy

    ; Initialize vision and jailed_time for each agent
    ;set vision agent_vision  ; This variable can be changed due to limitations on media and internet.
    set jailed_time 0        ; Initially, no agent is jailed.


    set neighbor_killed count agents in-radius agent_vision with [status = "killed"]
    set neighbor_active count agents in-radius agent_vision with [status = "active"]
    set neighbor_migrated count agents in-radius agent_vision with [status = "migrated"]
    set neighbor_jailed count agents in-radius agent_vision with [status = "jailed"]
    set neighbor_ready count agents in-radius agent_vision with [status = "ready"]

    ;let b round (agent_vision / 2)
    ;set neighbor_killed2 count agents in-radius b with [status = "killed"]
    ;set neighbor_active2 count agents in-radius b with [status = "active"]
    ;set neighbor_migrated2 count agents in-radius b with [status = "migrated"]
    ;set neighbor_jailed2 count agents in-radius b with [status = "jailed"]
    ;set neighbor_ready2 count agents in-radius b with [status = "ready"]


      ; determining the initial status of the agents
    ifelse condition > 0 [
      set status "active"
      set color red
    ]
    [ ifelse condition > -0.2 and condition < 0 and risk_aversion < 0.4 [
      set color grey
      set status "ready"
    ] [
      set color yellow  ; Default color for other cases
      set status "quiet"  ; Default status
      ]]

    set heading 0
    set shape "person"
  ]
]



  ; Then create cops on remaining patches
ask n-of cop_patches patches with [not any? turtles-here] [
    sprout-cops 1 [
      set cop_vision round (agent_vision * 1.5)
      set color black
      set heading 0
      set shape "person police"
      set size 0.7
      set violence_level random-float (((1 - legitimacy) / 50 + (protestors_ratio + 0.03)) * 100)  ; Initialize violence_level
    ]
  ]

  reset-ticks
end

to go
  if world_status > 0 [
    user-message (word
      "You just witnessed a revolution!")
    stop
  ]
  update_globals       ; Update global variables like legitimacy and protestors_ratio
  cops_act            ; Cops take actions based on their vision and violence_level
  update_agents_status  ; Update the status of agents
  agents_act            ; Agents take actions based on their status

  tick
end

to cops_act
  ask cops [
    ; Update to violence_level
    set violence_level random-float (((1 - legitimacy) / 50 + (protestors_ratio + 0.03)) * 100)

    let nearby_active_agents agents in-radius cop_vision with [status = "active"]

    if any? nearby_active_agents [
      let target one-of nearby_active_agents

      ifelse violence_level > ( 40 + agent_vision) [
        ; The condiotion for killing the agent
        ask target [
          set status "killed"
          set shape "star"  ; Change shape to indicate killed status
          set color Black     ; Change color to indicate killed status
        ]
      ] [
        ; The condition for arresting status
        ask target [
          set status "jailed"
          set shape "flag"  ; Change shape to indicate jailed status
          set color red     ; change color to indicate jailed status
          set jailed_time random ((protestors_ratio + 0.05) * 100 )
        ]
      ]
    ]
  ]
end

to update_globals
  ; Update legitimacy based on the number of killed agents
  let killed_agents count agents with [status = "killed"]
  set legitimacy base_legitimacy / (exp(0.01 * (killed_agents)))

  ; Calculate protestors_ratio based on the number of active, jailed, and quiet agents
  let total_agents count agents
  let active_and_jailed count agents with [status = "active" or status = "jailed"]
  let quiet_agents count agents with [status = "quiet"]
  set protestors_ratio active_and_jailed / (total_agents)

  if internet-disconnection [
    if revolution_threshold - protestors_ratio <= 0.1 [
      set agent_vision 2 ]
  ]

  ; Determine world_status based on protestors_ratio
  ifelse protestors_ratio > revolution_threshold [
    set world_status 1
    ] [
    set world_status 0
  ]
end

to update_agents_status
  ask agents [
    ; Skip agents with status "killed" or "migrated"
    if not (status = "killed" or status = "migrated") [

      ; Update rage and risk_aversion based on surrounding agents
      let killed_vision count agents in-radius agent_vision with [status = "killed"]
      let jailed_vision count agents in-radius agent_vision with [status = "jailed"]
      let ready_vision count agents in-radius agent_vision with [status = "ready"]
      let active_vision count agents in-radius agent_vision with [status = "active"]
      let migrated_vision count agents in-radius agent_vision with [status = "migrated"]
      let cops_vision count cops in-radius agent_vision
      ifelse (random-float 100 < 2 * shock_rate) [
        set shock? 1] [
        set shock? 0]

      ; Update rage based on the surrounding environment and its previous value
      let stimuli ((killed_vision - neighbor_killed) * 0.8 + (jailed_vision - neighbor_jailed) * 0.6 + (active_vision - neighbor_active) * 0.6 + (ready_vision - neighbor_ready) * 0.2)
      let rage_growth_rate (0.02 + agent_vision / 100)  ; This controls how quickly rage responds to stimuli
      set rage rage + rage_growth_rate * stimuli + shock? * shock_rate * agent_vision

      ; Ensure rage remains within bounds [0, 1]
      if rage > 1 [set rage 1]

      ;let c round (agent_vision / 2)
      ;let killed_vision2 count agents in-radius c with [status = "killed"]
      ;let jailed_vision2 count agents in-radius c with [status = "jailed"]
      ;let ready_vision2 count agents in-radius c with [status = "ready"]
      ;let active_vision2 count agents in-radius c with [status = "active"]
      ;let migrated_vision2 count agents in-radius c with [status = "migrated"]


      ; Update risk_aversion based on the surrounding environment and its previous value
      ;let risk_stimuli ((killed_vision2 - neighbor_killed2) * 1 + (jailed_vision2 - neighbor_jailed2) * 0.4 + (migrated_vision2 - neighbor_migrated2) * 0.2 + cops_vision * 0.002)
      ;let risk_growth_rate (0.08 + c / 300) ; Adjust the growth rate for risk_aversion
      ;set risk_aversion risk_aversion + risk_growth_rate * risk_stimuli

      ; Ensure risk_aversion remains within bounds [0, 1]
      if risk_aversion > 1 [set risk_aversion 1]

      set neighbor_killed killed_vision
      set neighbor_jailed jailed_vision
      set neighbor_migrated migrated_vision
      set neighbor_active active_vision
      set neighbor_ready ready_vision

      ; Compute the condition
      let condition rage - risk_aversion - legitimacy

      ; Check if the agent is "jailed"
      if status = "jailed" [
        set jailed_time jailed_time - 1
        if jailed_time <= 0 [
          if condition > 0 [
            set status "active"
            set shape "person"
            set color red  ; Change color to indicate active status
          ]
          if condition <= 0 [
            set status "quiet"
            set shape "person"
            set color yellow  ; Change color to indicate quiet status
          ]
        ]
      ]
    ]
  ]
end


to agents_act
  ask agents [
    ; Compute the condition for each agent
    let condition rage - risk_aversion - legitimacy

    ; Update status, shape, and color based on the condition and current status
    if (status = "quiet" or status = "ready" or status = "active") [
      if condition > 0.0 [
        set status "active"
        set shape "person"
        set color red
      ]

      if (condition > -0.1 and condition < 0) [
        set status "ready"
        set shape "person"
        set color grey
      ]
      if condition < -0.1 [
        set status "quiet"
        set shape "person"
        set color yellow
      ]
    ]


    ; Additional rule for "quiet" or "ready" agents considering migration
    let a random-float 1.0
    if ((status = "ready" ) or (status = "active") and risk_aversion > 0.5 and (a > 0.7 )) [
      set status "migrated"
      set shape "airplane"
      set color green
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
462
17
870
426
-1
-1
20.0
1
10
1
1
1
0
1
1
1
0
19
0
19
0
0
1
ticks
30.0

BUTTON
1016
39
1079
72
setup
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

BUTTON
1088
38
1161
74
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
1054
81
1129
114
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
0
152
302
337
Agents Status
time
agents
0.0
20.0
0.0
150.0
true
true
"" ""
PENS
"quiet" 1.0 0 -1184463 true "" "plot count agents with [status = \"quiet\"]"
"active" 1.0 0 -2674135 true "" "plot count agents with [status = \"active\"]"
"migrated" 1.0 0 -13210332 true "" "plot count agents with [status = \"migrated\"]"
"killed" 1.0 0 -16777216 true "" "plot count agents with [status = \"killed\"]"
"jailed" 1.0 0 -14730904 true "" "plot count agents with [status = \"jailed\"]"

MONITOR
3
90
74
135
Legitimacy
legitimacy
2
1
11

SLIDER
1011
322
1191
355
Corruption-perceptions-index
Corruption-perceptions-index
0
90
44.0
1
1
NIL
HORIZONTAL

SLIDER
1010
167
1182
200
initial-agents-vision
initial-agents-vision
2
15
15.0
1
1
NIL
HORIZONTAL

SWITCH
1012
209
1191
242
internet-disconnection
internet-disconnection
1
1
-1000

SLIDER
1013
247
1185
280
cops-density
cops-density
0
20
20.0
1
1
NIL
HORIZONTAL

SLIDER
1011
285
1191
318
Quality-of-life-index
Quality-of-life-index
0
79
22.0
1
1
NIL
HORIZONTAL

SLIDER
1010
128
1182
161
Shock-Rate
Shock-Rate
0
5
2.0
0.1
1
NIL
HORIZONTAL

MONITOR
85
91
188
136
NIL
protestors_ratio
2
1
11

PLOT
6
350
206
500
shock?
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot shock?"

PLOT
216
352
416
502
agent_vision
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot agent_vision"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

person construction
false
0
Rectangle -7500403 true true 123 76 176 95
Polygon -1 true false 105 90 60 195 90 210 115 162 184 163 210 210 240 195 195 90
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Circle -7500403 true true 110 5 80
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -955883 true false 180 90 195 90 195 165 195 195 150 195 150 120 180 90
Polygon -955883 true false 120 90 105 90 105 165 105 195 150 195 150 120 120 90
Rectangle -16777216 true false 135 114 150 120
Rectangle -16777216 true false 135 144 150 150
Rectangle -16777216 true false 135 174 150 180
Polygon -955883 true false 105 42 111 16 128 2 149 0 178 6 190 18 192 28 220 29 216 34 201 39 167 35
Polygon -6459832 true false 54 253 54 238 219 73 227 78
Polygon -16777216 true false 15 285 15 255 30 225 45 225 75 255 75 270 45 285

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

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
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
