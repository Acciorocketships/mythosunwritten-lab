#!/usr/bin/env bash
# Drive the built render shell with synthetic input, one session per component of
# the "a game a person can play" milestone, and photograph each at named ticks.
#
#   ./tools/playtest.sh board     # W-board-overlay
#   ./tools/playtest.sh live      # W-live-world
#   ./tools/playtest.sh input     # W-player-input
#   ./tools/playtest.sh verbs     # W-player-actions
#   ./tools/playtest.sh walk      # W-walk-motion
#   ./tools/playtest.sh pace      # W-walk-pace
#   ./tools/playtest.sh bag       # W-player-inventory
#   ./tools/playtest.sh fit       # W-window-fit
#   ./tools/playtest.sh items     # W-ground-items
#   ./tools/playtest.sh enemy     # W-enemy-spawn, and W-fight-drawn with it
#   ./tools/playtest.sh fight     # W-player-combat
#   ./tools/playtest.sh ended     # W-fight-end: the fight walked into, finished
#   ./tools/playtest.sh beaten    # W-defeat-told: the same fight, lost
#   ./tools/playtest.sh left      # W-fight-end: the same fight, walked out of
#   ./tools/playtest.sh whole     # everything in one seed, one run
#   ./tools/playtest.sh all
#
# Every session is one seed (1234 -- the seed every scenario in the repository is
# written on) and one command, printed before it runs so the log says what made
# each frame. Frames land in reports/assets/, traces in reports/playtest-<name>.log.
#
# This machine has no display, so each session is wrapped in xvfb-run: the shell
# renders into an off-screen buffer and --input presses the keys a person would
# press. On a machine WITH a display, drop the `xvfb-run -a` and the
# --input/--screenshot-ticks flags and play the same session by hand.
#
# The tick schedules below are the second pass's, and they are shorter than the
# first pass's on purpose. A walk now costs the strides it takes rather than a
# flat twenty ticks (commit ac63731), so one press of W is a four-tick action:
# every gap that used to wait out a walk is a quarter of what it was.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

SEED=1234
A=reports/assets

run() {
	local name=$1; shift
	local log="reports/playtest-$name.log"
	{
		echo "=== playtest session: $name"
		echo "=== command: xvfb-run -a ./run_render.sh $*"
		echo "=== on a machine with a display: ./run_render.sh $* (without --input/--screenshot-ticks)"
	} > "$log"
	xvfb-run -a ./run_render.sh "$@" >> "$log" 2>&1
	./tools/playtest_retick.sh "$log" >> "$log" 2>&1
	echo "$name done -> $log"
}

# The same session at a window size other than the shipped one. `--resolution`
# is the engine's own argument, so it goes ahead of the `--` that hands the rest
# to the shell; `run_render.sh` puts everything after that `--`, which is why
# this one calls the binary the way `run_render.sh` calls it rather than calling
# `run_render.sh`.
run_at() {
	local name=$1 size=$2; shift 2
	local log="reports/playtest-$name.log"
	source ./godot_env.sh
	{
		echo "=== playtest session: $name (window $size)"
		echo "=== command: xvfb-run -a \$GODOT --path . --resolution $size -- $*"
		echo "=== on a machine with a display: ./run_render.sh $* at a $size window (without --input/--screenshot-ticks)"
	} > "$log"
	xvfb-run -a "$GODOT" --path . --resolution "$size" -- "$@" >> "$log" 2>&1
	./tools/playtest_retick.sh "$log" >> "$log" 2>&1
	echo "$name done -> $log"
}

session_board() {
	# Squares that follow the terrain and grass that gives way over them.
	#
	# Three runs of the same seed, the same camera and the same asked-for tick.
	# Which tick each frame actually lands on is whatever tick the renderer got to
	# first (see `tools/playtest_retick.sh`), so the three frames are not
	# guaranteed to be the same moment -- and the report does not assume they are.
	# It measures a control box of sky and far hill that no lattice and no
	# character is in, and shows the frames agree there; what is left over is the
	# lattice and the grass over it, which is what the comparison is about.
	run board --seed $SEED --scenario play --play --board \
		--camera 0 16 20 --aim 2 \
		--screenshot-ticks "8:$A/playtest-board-grass-t8.png"
	run board-nograss --seed $SEED --scenario play --play --board --no-grass \
		--camera 0 16 20 --aim 2 \
		--screenshot-ticks "8:$A/playtest-board-bare-t8.png"
	# The pair the claim actually turns on: the same grass, the same seed and the
	# same camera, with the squares on and with them off, so what the grass does
	# over a square is the only difference between them.
	run board-off --seed $SEED --scenario play --play \
		--camera 0 16 20 --aim 2 \
		--screenshot-ticks "8:$A/playtest-board-off-t8.png"
}

session_live() {
	# A world that is running: the cast is asked and answers every tick while
	# the person does nothing at all. No presses on purpose.
	run live --seed $SEED --play --journal \
		--screenshot-ticks "6:$A/playtest-live-t6.png,30:$A/playtest-live-t30.png"
}

session_input() {
	# A person is one of the minds: four steps, and the journal shows them
	# arriving at the same seam the other three characters' choices arrive at.
	# Six ticks apart, which is one four-tick walk plus the tick the choice is
	# picked up on and the tick it is reported on.
	run input --seed $SEED --scenario play --play --journal \
		--input "6:w,12:a,18:s,24:d" \
		--screenshot-ticks "10:$A/playtest-input-t10.png,30:$A/playtest-input-t30.png"
}

session_verbs() {
	# Every row of the action catalogue, reached from a key press, on the stage
	# built to hold one of each. K is pressed on purpose: it is further than an
	# ordinary DEX reaches, so the engine refuses it and says why.
	run verbs --seed $SEED --scenario play --play --journal \
		--input "6:tab,8:e,12:p,20:b,22:t,30:y,38:f,40:l,44:equal,46:o,52:u,56:i,60:h,66:j,72:k,78:g,100:m,104:c,106:q,110:x,114:v,118:n" \
		--screenshot-ticks "16:$A/playtest-verbs-t16.png,34:$A/playtest-verbs-t34.png,64:$A/playtest-verbs-t64.png,124:$A/playtest-verbs-t124.png"
}

session_walk() {
	# One step, photographed as often as this machine can photograph, so the walk
	# can be seen happening rather than inferred -- and after it, to show the
	# person is free again rather than standing out sixteen ticks of an action
	# already finished. The frames are renamed to the ticks they were actually
	# taken on (`tools/playtest_retick.sh`), because a run asked for six
	# consecutive ticks gets six frames on whatever ticks they landed on.
	# Close and low: the four panels cover the bottom of the window and the
	# followed character is drawn near the middle of it, so a camera further back
	# than this puts the walker behind a panel instead of in front of one.
	run walk --seed $SEED --scenario play --play --journal \
		--camera 0 5 10 --aim 1 --input "6:w" \
		--screenshot-ticks "8:$A/playtest-walk-t8.png,10:$A/playtest-walk-t10.png,11:$A/playtest-walk-t11.png,12:$A/playtest-walk-t12.png,13:$A/playtest-walk-t13.png,15:$A/playtest-walk-t15.png"
}

session_pace() {
	# The pace question, asked of one run rather than of two: five presses of W
	# in a row, with the journal on, so the person's walks and the world's own
	# walks are timed against each other in the same trace at the same seed.
	run pace --seed $SEED --scenario play --play --journal \
		--camera 0 5 10 --aim 1 --input "6:w,12:w,18:w,24:w,30:w" \
		--screenshot-ticks "8:$A/playtest-pace-t8.png,36:$A/playtest-pace-t36.png"
	# What the world's own wandering leg costs, for the other side of the
	# comparison: eighteen units, twenty strides, twenty ticks.
	echo "=== the world's own walk, for comparison" > reports/playtest-pace-world.log
	echo "=== command: ./tools/measure_walk.sh --seed $SEED" >> reports/playtest-pace-world.log
	./tools/measure_walk.sh --seed $SEED >> reports/playtest-pace-world.log 2>&1
	echo "pace-world done -> reports/playtest-pace-world.log"
}

session_bag() {
	# The sheet opened and operated: hold, put on, take off, use up, drop, and
	# give away what is held.
	run bag --seed $SEED --scenario play --play --sheet --journal \
		--input "10:f,14:1,20:2,26:f,30:3,36:f,40:x,46:tab,48:f,52:o,60:z" \
		--screenshot-ticks "8:$A/playtest-bag-t8.png,18:$A/playtest-bag-t18.png,34:$A/playtest-bag-t34.png,56:$A/playtest-bag-t56.png"
}

session_fit() {
	# Every panel the shell can draw, open at once, in the window the game ships
	# in and in the two the milestone's fit work also promises. The trace's last
	# lines print each panel's own placement, which is what "inside the window"
	# is judged from; the frames are what a player sees.
	run fit --seed $SEED --scenario play --play --sheet --readout --board \
		--dialogue --trade --journal \
		--input "10:f,20:tab,24:b,28:t" \
		--screenshot-ticks "16:$A/playtest-fit-t16.png,34:$A/playtest-fit-t34.png"
	run_at fit-720 1280x720 --seed $SEED --scenario play --play --sheet --readout \
		--board --dialogue --trade \
		--input "10:f,20:tab,24:b,28:t" \
		--screenshot-ticks "34:$A/playtest-fit-1280x720-t34.png"
	run_at fit-1440 2560x1440 --seed $SEED --scenario play --play --sheet --readout \
		--board --dialogue --trade \
		--input "10:f,20:tab,24:b,28:t" \
		--screenshot-ticks "34:$A/playtest-fit-2560x1440-t34.png"
}

session_items() {
	# Gear lying on the ground as models: aim at the pile, pick the key out of
	# it, take it, hold it, look at it, drop it.
	run items --seed $SEED --scenario play --play --journal \
		--camera 0 6 -11 --aim 1 \
		--input "6:tab,8:tab,10:tab,14:q,20:f,24:l,30:x" \
		--screenshot-ticks "4:$A/playtest-items-t4.png,18:$A/playtest-items-t18.png,28:$A/playtest-items-t28.png,36:$A/playtest-items-t36.png"
	# The same again with the grass switched off, to rule the grass out as the
	# reason nothing is visible on the ground.
	run items-nograss --seed $SEED --scenario play --play --journal --no-grass \
		--camera 0 6 -11 --aim 1 \
		--input "6:tab,8:tab,10:tab,14:q,20:f,24:l,30:x" \
		--screenshot-ticks "18:$A/playtest-items-bare-t18.png,36:$A/playtest-items-bare-t36.png"
	# Walked up to the pile first, so the key is actually taken and dropped
	# rather than refused for reach. Two presses of S now, because one press is
	# a four-tick step of 3.6 units and the pile is 4.0 away.
	run items-pile --seed $SEED --scenario play --play --journal --no-grass \
		--camera 7 5 -7 --aim 1 \
		--input "6:s,14:tab,16:tab,18:tab,22:q,28:f,32:l,38:x" \
		--screenshot-ticks "12:$A/playtest-items-pile-t12.png,26:$A/playtest-items-pile-t26.png,44:$A/playtest-items-pile-t44.png"
	# The fourth camera: high, off to the side, grass off, before anybody moves.
	run items-side --seed $SEED --scenario play --play --no-grass \
		--camera 11 7 5 --aim 0.5 --fov 45 \
		--screenshot-ticks "8:$A/playtest-items-side-t8.png"
}

session_enemy() {
	# The ordinary world, walked through: what the enemy field puts out there
	# decides for itself and starts a fight by coming close. Nothing is asked
	# for on the command line beyond --play, which is the whole point of the
	# re-judgement: a fight that starts by itself has to draw itself.
	run enemy --seed $SEED --play --journal \
		--input "6:w,12:w,18:w,24:w,30:w,36:w" \
		--screenshot-ticks "20:$A/playtest-enemy-t20.png,40:$A/playtest-enemy-t40.png,52:$A/playtest-enemy-t52.png,90:$A/playtest-enemy-t90.png"
	# The same seed and the same world, with the camera pulled in to where a
	# board can be photographed rather than guessed at.
	run enemy-close --seed $SEED --play --journal --camera 0 9 14 --aim 1 \
		--input "6:w,12:w,18:w,24:w,30:w,36:w" \
		--screenshot-ticks "40:$A/playtest-enemy-close-t40.png,60:$A/playtest-enemy-close-t60.png,90:$A/playtest-enemy-close-t90.png"
}

session_fight() {
	# A whole turn on the board and the ones after it: step, strike, send a
	# minion, turn, end the turn, and let the other commanders take theirs.
	run fight --seed $SEED --scenario battle --play --readout --board --journal \
		--input "6:bracketleft,8:bracketright,12:4,16:semicolon,18:apostrophe,20:backslash,24:8,26:0,40:bracketleft,42:bracketright,46:4,50:semicolon,52:apostrophe,54:backslash,58:0,72:bracketleft,74:bracketright,78:4,82:0,96:bracketleft,98:bracketright,102:4,106:0,120:bracketleft,122:bracketright,126:4,130:0" \
		--screenshot-ticks "10:$A/playtest-fight-t10.png,28:$A/playtest-fight-t28.png,80:$A/playtest-fight-t80.png,134:$A/playtest-fight-t134.png"
}

# Walking east until a board turns up. `tests/test_walk_in_fight.gd` drives the
# same walk from inside the simulation -- it presses D on every tick the person
# is not already inside an action -- and this is the keyboard's version of it:
# one press every six ticks, which is a four-tick walk plus the tick the choice
# is picked up on and the tick the answer is reported on.
walk_east() {
	local start=$1 until_tick=$2
	local script="" t=$start
	while [ $t -le "$until_tick" ]; do
		script+="$t:d,"
		t=$((t + 6))
	done
	echo "${script%,}"
}

# The turn a person takes over and over on a board they walked into. A turn buys
# three things -- a move, an action and a minion -- and this spends all three:
# cycle the ring of cells the board is offering and step onto one, turn a quarter
# or two, spend the first weapon action and then the second, pick a minion and a
# cell for it and send it, and end the turn. Written once here and pressed from
# `ended`, `left` and `whole`, so the runs play the same fight the same way.
#
# The second weapon action is pressed on purpose even though a turn buys one:
# `already acted this turn` is the board saying what a turn is worth, and it is
# the only place in this playtest that sentence is shown.
board_turns() {
	local start=$1 turns=$2 every=$3
	local script="" t=$start i=0
	while [ $i -lt "$turns" ]; do
		# Three presses of [ before stepping, because [ cycles the ring of cells
		# on offer rather than choosing the best one: a person reads the board
		# and picks, and this is as much of that as a fixed schedule can do.
		script+="$((t)):bracketleft,$((t + 1)):bracketleft,$((t + 2)):bracketleft,$((t + 3)):bracketright,"
		# Turn a different number of quarters each round, because what a weapon
		# covers is read from where the commander stands as it is facing.
		local q=0
		while [ $q -lt $((i % 4)) ]; do
			script+="$((t + 4 + q)):8,"
			q=$((q + 1))
		done
		script+="$((t + 8)):4,$((t + 9)):5,"
		script+="$((t + 10)):semicolon,$((t + 11)):apostrophe,$((t + 12)):backslash,"
		script+="$((t + 14)):0,"
		t=$((t + every))
		i=$((i + 1))
	done
	echo "${script%,}"
}

session_ended() {
	# A fight nobody asked for, played until it is over. The play stage's own
	# cast walks into one at seed 1234; this presses the same six-key turn
	# twenty times over and photographs the board, a turn on it, and the tick
	# after it is put away.
	run ended --seed $SEED --scenario play --play --journal \
		--camera 0 9 14 --aim 1 \
		--input "$(walk_east 6 108),$(board_turns 120 42 16)" \
		--screenshot-ticks "40:$A/playtest-ended-t40.png,100:$A/playtest-ended-t100.png,150:$A/playtest-ended-t150.png,300:$A/playtest-ended-t300.png,500:$A/playtest-ended-t500.png,700:$A/playtest-ended-t700.png,790:$A/playtest-ended-t790.png"
}

session_beaten() {
	# The same fight as `ended`, at the same seed, with the same presses -- and
	# photographed at the ticks that are about losing it rather than about
	# playing it. At this seed the brawler's three thrusts (t=144, 160, 176) take
	# a person who starts six hearts down out of the fight, and every key pressed
	# from then on used to be answered "it is not your turn on a board" while the
	# panel went on saying it was waiting for them. The frames are the tick after
	# the third thrust, the turn after it, the second board with the person no
	# longer in the world at all, and two later moments of a run that carries on
	# without them.
	#
	# Its own name and its own frames on purpose: `ended` is the session the
	# defect was measured from, and its log and frames are the evidence for that
	# measurement.
	run beaten --seed $SEED --scenario play --play --journal \
		--camera 0 9 14 --aim 1 \
		--input "$(walk_east 6 108),$(board_turns 120 42 16)" \
		--screenshot-ticks "180:$A/playtest-beaten-t180.png,200:$A/playtest-beaten-t200.png,300:$A/playtest-beaten-t300.png,500:$A/playtest-beaten-t500.png,790:$A/playtest-beaten-t790.png"
}

# `.` pressed over and over across a window of ticks. Leaving is a thing a turn
# is spent on, so it is only askable on the person's own turn -- and a fixed
# schedule cannot know which tick that is, because the two other commanders take
# theirs in between and how long they take is their business. Pressing every
# other tick across a window wide enough to hold a whole round means one press
# lands on the person's turn and the rest are refused in the match's own words,
# which is the other half of what this session is for.
leave_window() {
	local start=$1 until_tick=$2
	local script="" t=$start
	while [ $t -le "$until_tick" ]; do
		script+="$t:period,"
		t=$((t + 2))
	done
	echo "${script%,}"
}

session_left() {
	# The same fight, walked out of instead: two turns on the board and then `.`,
	# which spends the turn on leaving and puts the character back in the world
	# where it stood. The frames are the board, a turn on it, the tick after the
	# leave, and real time afterwards.
	run left --seed $SEED --scenario play --play --journal \
		--camera 0 9 14 --aim 1 \
		--input "$(walk_east 6 108),$(board_turns 120 2 16),$(leave_window 150 200),210:d,216:d,222:m,230:e" \
		--screenshot-ticks "100:$A/playtest-left-t100.png,140:$A/playtest-left-t140.png,205:$A/playtest-left-t205.png,220:$A/playtest-left-t220.png,234:$A/playtest-left-t234.png"
}

session_whole() {
	# Everything in one run and one seed: walk, every kind of action, the
	# inventory, a fight the world starts by itself played from the keyboard and
	# then left, and the return to real time after it -- with a walk, a wait and a
	# look on the far side of the fight to show the world took the person back.
	#
	# What this session learned the hard way and now encodes.
	#
	# The wardrobe is worked with the BOOTS, never the sword. Pressing 2 while the
	# sword is the held thing takes it out of the hand (`attacks=0`), and a
	# commander with nothing in the hand slot cannot spend a weapon action.
	#
	# And the fight is left rather than won. Two turns is what a person gets: at
	# this seed Rill lands a thrust every sixteen ticks for eleven to sixteen, Fen
	# starts six down of thirty-two, and a swing aimed by a fixed schedule rather
	# than at the enemy answers `done` without landing. `ended` is the session that
	# fights one to the board being put away; this one takes its two turns and
	# spends the third on `.`, which is the other way the milestone says a fight
	# ends, and the only one that hands the person back to real time alive.
	#
	# Four stretches, in the order a person would meet them: the fifteen rows of
	# the catalogue and the wardrobe on the play stage (t=6 to t=160), the walk
	# east into the fight the world starts by itself (t=166 on), two turns on the
	# board and the leave, and then real time again -- two steps, a wait, a look
	# and the sheet.
	local verbs="6:s,12:s,18:tab,20:tab,22:tab,26:q,32:f,36:l,40:1,46:2,52:x"
	verbs+=",58:f,62:f,66:3,72:tab,74:tab,78:b,80:t,88:y,96:e,100:equal,102:o"
	verbs+=",110:u,116:i,122:h,128:j,134:k,138:m,144:f,148:n,156:z,160:z"
	local after="310:d,316:d,322:m,330:e,336:tab,342:f,348:l,354:z"
	run whole --seed $SEED --scenario play --play --journal --sheet --board --readout \
		--camera 0 9 14 --aim 1 \
		--input "$verbs,$(walk_east 166 214),$(board_turns 224 2 16),$(leave_window 256 304),$after" \
		--screenshot-ticks "30:$A/playtest-whole-t30.png,70:$A/playtest-whole-t70.png,130:$A/playtest-whole-t130.png,158:$A/playtest-whole-t158.png,210:$A/playtest-whole-t210.png,240:$A/playtest-whole-t240.png,262:$A/playtest-whole-t262.png,300:$A/playtest-whole-t300.png,325:$A/playtest-whole-t325.png,350:$A/playtest-whole-t350.png,358:$A/playtest-whole-t358.png"
}

case "${1:-all}" in
	board) session_board ;;
	live) session_live ;;
	input) session_input ;;
	verbs) session_verbs ;;
	walk) session_walk ;;
	pace) session_pace ;;
	bag) session_bag ;;
	fit) session_fit ;;
	items) session_items ;;
	enemy) session_enemy ;;
	fight) session_fight ;;
	ended) session_ended ;;
	beaten) session_beaten ;;
	left) session_left ;;
	whole) session_whole ;;
	all)
		session_board; session_live; session_input; session_verbs; session_walk
		session_pace; session_bag; session_fit; session_items; session_enemy
		session_fight; session_ended; session_beaten; session_left
		session_whole ;;
	*) echo "no such session: $1" >&2; exit 2 ;;
esac
