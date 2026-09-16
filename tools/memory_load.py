#!/usr/bin/env python3
"""Put this machine under a named, held memory load, and keep it there.

The runner's silence watchdog used to count loop iterations rather than
seconds, so its budget stretched exactly when the machine was busy. Proving
that -- and proving that a wall-time watchdog does not stretch -- needs the
machine put under a load that is chosen and written down, rather than borrowed
from whichever suite happens to be heavy that day.

Two ways to say how much:

    python3 tools/memory_load.py --gib 18            # hold 18 GiB resident
    python3 tools/memory_load.py --leave 1.0         # hold free memory at 1 GiB

The second is the one that reproduces a heavy suite. The certifying run's
recording shows test_settlements driving this machine's available memory to
0.00 GiB while its engine held 23.15 GiB, so the load that matters is not a
number of gibibytes -- that depends on what else is up -- but how little the
machine has left. --leave holds the machine at that edge and keeps it there,
giving a block back if it goes further and taking another if it recovers, so
the kernel reclaims continuously for as long as the load runs.

Pages are written, not merely reserved, so they are really resident, and a
walker keeps rewriting them so none of the set goes cold and is quietly
reclaimed. The held size and the machine's remaining memory are printed every
few seconds, so the load a measurement was taken under can be quoted.
"""
import argparse, os, sys, time

CHUNK = 1 << 26  # 64 MiB per block: big enough to be cheap, small enough to step
GIB = float(1 << 30)


def available_gib() -> float:
	for line in open("/proc/meminfo"):
		if line.startswith("MemAvailable:"):
			return int(line.split()[1]) * 1024 / GIB
	raise RuntimeError("this kernel's /proc/meminfo has no MemAvailable")


def rss_gib() -> float:
	return int(open("/proc/self/statm").read().split()[1]) * os.sysconf("SC_PAGE_SIZE") / GIB


def main() -> int:
	ap = argparse.ArgumentParser()
	size = ap.add_mutually_exclusive_group(required=True)
	size.add_argument("--gib", type=float, help="gibibytes to hold resident")
	size.add_argument("--leave", type=float,
	                  help="hold the machine's available memory down to this many GiB")
	ap.add_argument("--for", dest="seconds", type=float, default=0.0,
	                help="give the memory back after this long (0 = until killed)")
	ap.add_argument("--churn", action="store_true",
	                help="keep asking for fresh pages instead of rewriting held ones, "
	                     "so the kernel must reclaim continuously")
	args = ap.parse_args()

	blocks, filler = [], b"\xa5" * CHUNK
	def take() -> None:
		blocks.append(bytearray(filler))
	def give() -> None:
		if blocks:
			blocks.pop()

	if args.gib is not None:
		while len(blocks) * CHUNK < args.gib * GIB:
			take()
	else:
		# Walk down to the edge rather than jumping at it: the last gibibyte
		# before MemAvailable reaches zero is where the kernel starts killing,
		# and the point of this fixture is to sit next to that, not past it.
		while available_gib() > args.leave:
			take()
	print("memory_load: holding %.2f GiB resident, machine has %.2f GiB left, pid %d"
	      % (rss_gib(), available_gib(), os.getpid()), flush=True)

	until = time.time() + args.seconds if args.seconds else None
	step, said = 0, time.time()
	while until is None or time.time() < until:
		if args.churn and blocks:
			# A full machine is not a thrashing machine. Holding pages still
			# leaves the kernel nothing to do; asking for fresh ones while
			# there are none left is what makes it reclaim on every request,
			# which is the state a heavy suite puts this machine in.
			blocks.append(bytearray(filler))
			blocks.pop(0)
		elif blocks:
			block = blocks[step % len(blocks)]
			block[0] ^= 1
			block[len(block) // 2] ^= 1
			block[-1] ^= 1
		step += 1
		if step % max(1, len(blocks)) == 0:
			time.sleep(0.01)
			if args.leave is not None:
				free = available_gib()
				if free < args.leave * 0.4:
					give()
				elif free > args.leave * 2.0:
					take()
			if time.time() - said >= 5.0:
				said = time.time()
				print("memory_load: %.2f GiB held, %.2f GiB left"
				      % (rss_gib(), available_gib()), flush=True)
	return 0


if __name__ == "__main__":
	sys.exit(main())
