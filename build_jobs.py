#!/usr/bin/env python3
"""Choose a safe parallelism for the Godot SCons build.

Godot's build is both CPU bound and memory bound: each translation unit runs
its own clang++ process whose peak RSS is roughly 0.6-1.5 GB. Picking `-j` from
the CPU count alone is what makes builds fall over on 16 GB machines, so this
uses the memory actually available right now.

Environment overrides:
    GODOT_BUILD_JOBS            explicit job count (argv[1] also accepted)
    GODOT_BUILD_MAX_JOBS        upper bound for the computed value (default 8)
    GODOT_BUILD_JOB_MEMORY_MB   assumed peak RSS per compile (default 1200)
    GODOT_BUILD_MEMORY_RESERVE_MB  memory kept free for OS/desktop (default 1500)

Examples on a 20-core / 16 GB machine:
    idle, ~10 GB available        -> 8 jobs (capped)
    desktop busy, ~4 GB available -> 3 jobs
"""

import os
import sys


def memory_mb() -> tuple[int, int]:
    """Return (total, available) memory in MB, or (0, 0) when unavailable."""
    try:
        with open("/proc/meminfo", encoding="utf-8") as handle:
            values = {}
            for line in handle:
                key, _, rest = line.partition(":")
                parts = rest.split()
                if parts:
                    values[key] = int(parts[0]) // 1024
        return values.get("MemTotal", 0), values.get("MemAvailable", 0)
    except (OSError, ValueError):
        return 0, 0


def choose_jobs() -> int:
    cpus = os.cpu_count() or 4
    per_job = max(256, int(os.environ.get("GODOT_BUILD_JOB_MEMORY_MB", "1200")))
    reserve = max(0, int(os.environ.get("GODOT_BUILD_MEMORY_RESERVE_MB", "1500")))
    max_jobs = max(1, int(os.environ.get("GODOT_BUILD_MAX_JOBS", "8")))

    total, available = memory_mb()
    if total <= 0:
        # Unknown memory: stay conservative instead of risking the OOM killer.
        return max(1, min(cpus, 4))

    # Available already excludes what running programs hold; only keep a small
    # reserve on top so the desktop stays responsive.
    budget = max(available - reserve, per_job)
    jobs_by_memory = max(1, budget // per_job)

    return max(1, min(cpus, jobs_by_memory, max_jobs))


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1].strip():
        print(max(1, int(sys.argv[1])))
        return
    if os.environ.get("GODOT_BUILD_JOBS", "").strip():
        print(max(1, int(os.environ["GODOT_BUILD_JOBS"])))
        return
    print(choose_jobs())


if __name__ == "__main__":
    main()
