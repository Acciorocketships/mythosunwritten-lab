#!/usr/bin/env bash
# Drive the built render shell with synthetic input, one session per component of
# the "a game a person can play" milestone, and photograph each at named ticks.
#
#   ./tools/playtest.sh board     # W-board-overlay
#   ./tools/playtest.sh live      # W-live-world
#   ./tools/playtest.sh input     # W-player-input
#   ./tools/playtest.sh verbs     # W-player-actions
#   ./tools/playtest.sh walk      # W-walk-motion
#   ./tools/playtest.sh bag       # W-player-inventory
#   ./tools/playtest.sh items     # W-ground-items
#   ./tools/playtest.sh enemy     # W-enemy-spawn
#   ./tools/playtest.sh fight     # W-player-combat
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
	echo "$name done -> $log"
}

session_board() {
	# Squares that follow the terrain and grass that gives way over them. The
	# same seed, camera and ticks twice: once with the grass, once without.
	run board --seed $SEED --scenario play --play --board \
		--camera 0 16 20 --aim 2 \
		--screenshot-ticks "8:$A/playtest-board-grass-t8.png"
	run board-nograss --seed $SEED --scenario play --play --board --no-grass \
		--camera 0 16 20 --aim 2 \
		--screenshot-ticks "8:$A/playtest-board-bare-t8.png"
	# The pair the claim actually turns on: the same grass, the same seed, the
	# same camera and the same tick, with the squares on and with them off, so
	# what the grass does over a square is the only difference between them.
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
	run input --seed $SEED --scenario play --play --journal \
		--input "6:w,28:a,50:s,72:d" \
		--screenshot-ticks "10:$A/playtest-input-t10.png,80:$A/playtest-input-t80.png"
}

session_verbs() {
	# Every row of the action catalogue, reached from a key press, on the stage
	# built to hold one of each. K is pressed on purpose: it is further than an
	# ordinary DEX reaches, so the engine refuses it and says why.
	run verbs --seed $SEED --scenario play --play --journal \
		--input "6:tab,8:e,14:p,36:b,38:t,46:y,54:f,56:l,62:equal,64:o,72:u,78:i,84:h,92:j,98:k,104:g,126:m,130:c,132:q,138:x,144:v,150:n" \
		--screenshot-ticks "20:$A/playtest-verbs-t20.png,60:$A/playtest-verbs-t60.png,100:$A/playtest-verbs-t100.png,156:$A/playtest-verbs-t156.png"
}

session_walk() {
	# One step, photographed on five consecutive ticks of the twenty it spans,
	# so the walk can be seen happening rather than inferred.
	# Close and low: the four panels cover the bottom third of the window and the
	# followed character is drawn near the middle of it, so a camera further back
	# than this puts the walker behind a panel instead of in front of one.
	run walk --seed $SEED --scenario play --play --journal \
		--camera 0 5 10 --aim 1 --input "6:w" \
		--screenshot-ticks "8:$A/playtest-walk-t8.png,12:$A/playtest-walk-t12.png,16:$A/playtest-walk-t16.png,20:$A/playtest-walk-t20.png,28:$A/playtest-walk-t28.png"
}

session_bag() {
	# The sheet opened and operated: hold, put on, take off, use up, drop, and
	# give away what is held.
	run bag --seed $SEED --scenario play --play --sheet --journal \
		--input "10:f,14:1,22:2,28:f,32:3,40:f,44:x,52:tab,54:f,58:o,66:z" \
		--screenshot-ticks "8:$A/playtest-bag-t8.png,18:$A/playtest-bag-t18.png,36:$A/playtest-bag-t36.png,62:$A/playtest-bag-t62.png"
}

session_items() {
	# Gear lying on the ground as models: aim at the pile, pick the key out of
	# it, take it, hold it, look at it, drop it.
	run items --seed $SEED --scenario play --play --journal \
		--camera 0 6 -11 --aim 1 \
		--input "6:tab,8:tab,10:tab,16:q,24:f,28:l,36:x" \
		--screenshot-ticks "4:$A/playtest-items-t4.png,20:$A/playtest-items-t20.png,32:$A/playtest-items-t32.png,42:$A/playtest-items-t42.png"
	# The same again with the grass switched off, to rule the grass out as the
	# reason nothing is visible on the ground.
	run items-nograss --seed $SEED --scenario play --play --journal --no-grass \
		--camera 0 6 -11 --aim 1 \
		--input "6:tab,8:tab,10:tab,16:q,24:f,28:l,36:x" \
		--screenshot-ticks "20:$A/playtest-items-bare-t20.png,42:$A/playtest-items-bare-t42.png"
	# Walked up to the pile first, so the key is actually taken and dropped
	# rather than refused for reach.
	run items-pile --seed $SEED --scenario play --play --journal --no-grass \
		--camera 7 5 -7 --aim 1 \
		--input "6:s,32:tab,34:tab,36:tab,42:q,54:f,58:l,66:x" \
		--screenshot-ticks "30:$A/playtest-items-pile-t30.png,50:$A/playtest-items-pile-t50.png,72:$A/playtest-items-pile-t72.png"
	# The fourth camera: high, off to the side, grass off, before anybody moves.
	run items-side --seed $SEED --scenario play --play --no-grass \
		--camera 11 7 5 --aim 0.5 --fov 45 \
		--screenshot-ticks "8:$A/playtest-items-side-t8.png"
}

session_enemy() {
	# The ordinary world, walked through: what the enemy field puts out there
	# decides for itself and starts a fight by coming close.
	run enemy --seed $SEED --play --journal \
		--input "6:w,28:w,50:w,72:w" \
		--screenshot-ticks "24:$A/playtest-enemy-t24.png,40:$A/playtest-enemy-t40.png,90:$A/playtest-enemy-t90.png"
}

session_fight() {
	# A whole turn on the board and the ones after it: step, strike, send a
	# minion, turn, end the turn, and let the other commanders take theirs.
	run fight --seed $SEED --scenario battle --play --readout --board --journal \
		--input "6:bracketleft,8:bracketright,12:4,16:semicolon,18:apostrophe,20:backslash,24:8,26:0,40:bracketleft,42:bracketright,46:4,50:semicolon,52:apostrophe,54:backslash,58:0,72:bracketleft,74:bracketright,78:4,82:0,96:bracketleft,98:bracketright,102:4,106:0,120:bracketleft,122:bracketright,126:4,130:0" \
		--screenshot-ticks "10:$A/playtest-fight-t10.png,28:$A/playtest-fight-t28.png,80:$A/playtest-fight-t80.png,134:$A/playtest-fight-t134.png"
}

session_whole() {
	# Everything in one run and one seed: walk, every kind of action, the
	# inventory, the walk east that Rill notices, the whole fight on the board,
	# and the return to real time after it.
	#
	# Two things this session learned the hard way and now encodes.
	# First: the wardrobe is worked with the BOOTS, never the sword. Pressing 2
	# while the sword is the held thing takes it out of the hand (`attacks=0`),
	# and a commander with nothing in the hand slot cannot spend a weapon action,
	# so a run that disarms itself can never bring its own fight to an end.
	# Second: what an attack covers is read from where the commander stands *as
	# it is facing*, so each round turns a different number of quarters before it
	# swings -- 0, 1, 2, 3 and round again -- and every facing gets tried.
	run whole --seed $SEED --scenario play --play --journal --sheet --board --readout \
		--input "6:s,30:tab,32:tab,34:tab,40:q,48:f,52:l,56:1,64:2,72:x,80:f,84:f,88:3,96:tab,98:tab,102:b,104:t,112:y,120:e,128:equal,130:o,138:u,144:i,150:h,158:j,164:k,170:m,176:f,180:n,188:f,192:n,200:f,204:n,212:f,216:n,224:z,230:z,236:d,258:d,280:d,302:d,324:d,350:bracketleft,352:bracketright,356:4,360:5,364:0,376:bracketleft,378:bracketright,380:8,384:4,388:5,392:0,404:bracketleft,406:bracketright,408:8,410:8,414:4,418:5,422:0,434:bracketleft,436:bracketright,438:8,440:8,442:8,446:4,450:5,454:0,466:bracketleft,468:bracketright,472:4,476:5,480:0,492:bracketleft,494:bracketright,496:8,500:4,504:5,508:0,520:bracketleft,522:bracketright,524:8,526:8,530:4,534:5,538:0,550:bracketleft,552:bracketright,554:8,556:8,558:8,562:4,566:5,570:0,582:bracketleft,584:bracketright,588:4,592:5,596:0,608:bracketleft,610:bracketright,612:8,616:4,620:5,624:0,636:bracketleft,638:bracketright,640:8,642:8,646:4,650:5,654:0,666:bracketleft,668:bracketright,670:8,672:8,674:8,678:4,682:5,686:0,698:bracketleft,700:bracketright,704:4,708:5,712:0,724:bracketleft,726:bracketright,728:8,732:4,736:5,740:0,752:bracketleft,754:bracketright,756:8,758:8,762:4,766:5,770:0,782:bracketleft,784:bracketright,786:8,788:8,790:8,794:4,798:5,802:0,814:bracketleft,816:bracketright,820:4,824:5,828:0,840:bracketleft,842:bracketright,844:8,848:4,852:5,856:0,868:bracketleft,870:bracketright,872:8,874:8,878:4,882:5,886:0,898:bracketleft,900:bracketright,902:8,904:8,906:8,910:4,914:5,918:0,930:w,952:m,958:tab,960:e" \
		--screenshot-ticks "34:$A/playtest-whole-t34.png,90:$A/playtest-whole-t90.png,230:$A/playtest-whole-t230.png,345:$A/playtest-whole-t345.png,500:$A/playtest-whole-t500.png,700:$A/playtest-whole-t700.png,920:$A/playtest-whole-t920.png,966:$A/playtest-whole-t966.png"
}

case "${1:-all}" in
	board) session_board ;;
	live) session_live ;;
	input) session_input ;;
	verbs) session_verbs ;;
	walk) session_walk ;;
	bag) session_bag ;;
	items) session_items ;;
	enemy) session_enemy ;;
	fight) session_fight ;;
	whole) session_whole ;;
	all)
		session_board; session_live; session_input; session_verbs; session_walk
		session_bag; session_items; session_enemy; session_fight; session_whole ;;
	*) echo "no such session: $1" >&2; exit 2 ;;
esac
