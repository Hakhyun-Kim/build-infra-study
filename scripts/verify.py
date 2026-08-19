#!/usr/bin/env python3
"""Run each experiment's check.sh and record the verdict in docs/results.json.

Console output is ASCII-only on purpose: the development machine's console is
cp949 and non-ASCII output crashes it.
"""

import json
import os
import platform
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPERIMENTS_DIR = ROOT / "experiments"
RESULTS_PATH = ROOT / "docs" / "results.json"

# Tools an experiment needs before it can even be attempted.
REQUIRED_TOOLS = {
    "exp01_bazel_hello": ["bazel"],
    # disk cache 검증만 자동화되어 있어 docker 는 필요 없다 (remote cache 는 수동)
    "exp02_remote_cache": ["bazel", "python3"],
    "exp03_cross_aarch64": ["bazel", "file", "aarch64-linux-gnu-gcc"],
    "exp04_qemu_device": ["bazel", "qemu-aarch64"],
    "exp05_test_impact": ["bazel"],
    "exp06_yocto_qemuarm64": ["bitbake"],
    "exp07_ci_pipeline": ["gitlab-runner"],
}


def find_experiments():
    if not EXPERIMENTS_DIR.is_dir():
        return []
    return sorted(p for p in EXPERIMENTS_DIR.iterdir() if p.is_dir())


def missing_tools(name):
    return [t for t in REQUIRED_TOOLS.get(name, []) if shutil.which(t) is None]


def run_check(exp_dir):
    """Return (status, seconds, detail)."""
    name = exp_dir.name
    check = exp_dir / "check.sh"

    if not check.exists():
        return "NO_CHECK", 0.0, "check.sh not written yet"

    absent = missing_tools(name)
    if absent:
        return "SKIP", 0.0, "missing tools: " + ", ".join(absent)

    if os.name == "nt":
        return "SKIP", 0.0, "checks require a Linux shell (use WSL2 or Ubuntu)"

    start = time.time()
    proc = subprocess.run(
        ["bash", str(check)],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
    )
    elapsed = round(time.time() - start, 1)

    if proc.returncode == 0:
        return "PASS", elapsed, ""
    tail = (proc.stdout + proc.stderr).strip().splitlines()[-5:]
    return "FAIL", elapsed, " | ".join(tail)


def main():
    experiments = find_experiments()
    if not experiments:
        print("No experiments found under " + str(EXPERIMENTS_DIR))
        return 1

    results = []
    print("host: %s %s" % (platform.system(), platform.machine()))
    print("")

    for exp_dir in experiments:
        status, elapsed, detail = run_check(exp_dir)
        results.append(
            {
                "experiment": exp_dir.name,
                "status": status,
                "seconds": elapsed,
                "detail": detail,
            }
        )
        line = "%-26s %-9s %6.1fs" % (exp_dir.name, status, elapsed)
        if detail:
            line += "  (" + detail + ")"
        print(line)

    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "cpu_count": os.cpu_count(),
        },
        "results": results,
    }

    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULTS_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    print("")
    print("pass=%d fail=%d total=%d -> %s" % (passed, failed, len(results), RESULTS_PATH))
    print("Copy these into the README table. Do not edit the table by hand.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
