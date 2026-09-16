extends TestSuite
## A suite that never returns and never says anything -- while holding the
## machine down, the way a heavy suite does.
##
## `stalling.gd` next to this one is the cheap version: it spins in an engine
## that holds a quarter of a gibibyte, which is a stalled suite on an idle
## machine. That is not the case the silence budget was got wrong on. The
## certifying run lost test_settlements while its engine held 23.15 GiB and this
## machine's free memory was 0.00 GiB, and a watchdog that counts loop
## iterations rather than seconds loosens exactly there.
##
## The load has to be the engine's own. A python process holding the same
## gibibytes, churning them, or twenty of them at once, was measured on this
## machine and moved the watchdog's loop by half a percent; an engine holding
## them is what the run actually does, and it is what this fixture reproduces.
##
## RUN_TESTS_FIXTURE_GIB says how much to hold -- there is no default worth
## having, because the number that matters is "nearly all of this machine" and
## only the caller knows what this machine is. With it unset the fixture holds
## nothing and behaves like its cheap neighbour.
##
## ./run_runner_guard.sh runs the cheap one. This one is for measuring the
## budget under load; reports/watchdog/ keeps what it measured.
class_name RunnerStallingHeavyFixture

## Long enough that the watchdog is what ends the run, short enough that a
## mistake does not leave an engine holding this machine for the rest of the day.
const GIVE_UP_AFTER_MS := 3_600_000

## One block. Big enough that a hundred of them is not a hundred thousand
## allocations, small enough to step to the requested size without overshooting
## a machine that has nothing left to give.
const BLOCK_BYTES := 256 * 1024 * 1024


func _init() -> void:
	suite_name = "stalling heavy"


func run() -> void:
	var want := OS.get_environment("RUN_TESTS_FIXTURE_GIB").to_float()
	var blocks: Array[PackedByteArray] = []
	var held := 0.0
	while held + 0.25 <= want:
		var block := PackedByteArray()
		block.resize(BLOCK_BYTES)
		# Written, not merely reserved: pages that were never touched are not
		# resident, and a load that is not resident is not a load.
		block.fill(0xa5)
		blocks.append(block)
		held += float(BLOCK_BYTES) / float(1 << 30)

	# Now the silence. The pages are kept warm and one block is replaced each
	# pass, so the kernel goes on reclaiming for as long as this runs -- a full
	# machine standing still is not the same as a full machine working, and it
	# was the working one that stretched the budget.
	var until := Time.get_ticks_msec() + GIVE_UP_AFTER_MS
	var step := 0
	while Time.get_ticks_msec() < until:
		if blocks.is_empty():
			continue
		var block: PackedByteArray = blocks[step % blocks.size()]
		block[0] = block[0] ^ 1
		block[block.size() / 2] = block[block.size() / 2] ^ 1
		block[block.size() - 1] = block[block.size() - 1] ^ 1
		if step % blocks.size() == 0:
			var fresh := PackedByteArray()
			fresh.resize(BLOCK_BYTES)
			fresh.fill(0x5a)
			blocks[0] = fresh
		step += 1
