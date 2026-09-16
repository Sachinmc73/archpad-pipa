#!/usr/bin/env python3
"""Measure the essential Phase D1 gate around benchmark_e2e."""

import argparse
import json
import os
import resource
import statistics
import subprocess
import sys
import tempfile
import time


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, int((len(ordered) - 1) * fraction + 0.5))
    return ordered[index]


def read_pss_kib(pid: int) -> int:
    with open(f"/proc/{pid}/smaps_rollup", encoding="ascii") as stream:
        for line in stream:
            if line.startswith("Pss:"):
                return int(line.split()[1])
    raise RuntimeError("Pss was absent from smaps_rollup")


def command(args: argparse.Namespace, warmup: int, runs: int,
            output: str) -> list[str]:
    result = [
        args.benchmark,
        "--encoder", os.path.join(args.assets, "honorable_sturgeon/model_fp32.pte"),
        "--decoder", os.path.join(args.assets, "magic_macaw/model_fp32.pte"),
        "--vocab", os.path.join(args.assets, "vocabs/en.combined"),
        "--layout", os.path.join(args.assets, "layouts/en_qwerty.json"),
        "--lm-model", os.path.join(args.assets, "hungry_jellyfish/context_lm.pte"),
        "--lm-vocab", os.path.join(args.assets, "hungry_jellyfish/vocab.txt"),
        "--threads", "1",
        "--beam-width", "300",
        "--top-k", "4",
        "--warmup", str(warmup),
        "--runs", str(runs),
        "--path-points", "80",
    ]
    result.append(output)
    return result


def parse_csv(path: str) -> dict[str, dict[str, float]]:
    with open(path, encoding="utf-8") as stream:
        columns = stream.readline().strip().split(",")
        rows = [[float(value) for value in line.strip().split(",")]
                for line in stream if line.strip()]
    if not rows:
        raise RuntimeError("benchmark produced no timing rows")
    result = {}
    for index, name in enumerate(columns[1:], start=1):
        values = [row[index] for row in rows]
        result[name] = {
            "p50": percentile(values, 0.50),
            "p95": percentile(values, 0.95),
            "p99": percentile(values, 0.99),
            "mean": statistics.fmean(values),
        }
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--benchmark", required=True)
    parser.add_argument("--assets", required=True)
    parser.add_argument("--runs", type=int, default=1000)
    parser.add_argument("--warmup", type=int, default=50)
    parser.add_argument("--init-runs", type=int, default=10)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    init_ms = []
    for _ in range(args.init_runs):
        completed = subprocess.run(
            command(args, 0, 1, "--json"), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        init_ms.append(json.loads(completed.stdout)["init_ms"])

    with tempfile.NamedTemporaryFile(mode="w+", encoding="utf-8") as timing_file:
        start = time.monotonic()
        with open(timing_file.name, "w", encoding="utf-8") as stdout_stream:
            process = subprocess.Popen(
                command(args, args.warmup, args.runs, "--dump-times"),
                text=True, stdout=stdout_stream, stderr=subprocess.PIPE)
            pss_samples = []
            assert process.stderr is not None
            for line in process.stderr:
                if line.startswith("Warming up") or line.startswith("Benchmarking"):
                    pss_samples.append(read_pss_kib(process.pid))
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        wall_seconds = time.monotonic() - start
        if process.returncode != 0:
            raise RuntimeError(f"benchmark exited {process.returncode}")
        timing = parse_csv(timing_file.name)

    sizes = {}
    for relative in (
        "honorable_sturgeon/model_fp32.pte",
        "magic_macaw/model_fp32.pte",
        "hungry_jellyfish/context_lm.pte",
        "hungry_jellyfish/vocab.txt",
        "vocabs/en.combined",
        "layouts/en_qwerty.json",
    ):
        sizes[relative] = os.path.getsize(os.path.join(args.assets, relative))
    sizes["benchmark_e2e"] = os.path.getsize(args.benchmark)

    cpu_seconds = usage.ru_utime + usage.ru_stime
    output = {
        "configuration": {
            "beam_width": 300,
            "top_k": 4,
            "threads": 1,
            "warmup": args.warmup,
            "runs": args.runs,
            "trace": "deterministic synthetic, nominal 80 points",
        },
        "process_init_ms": {
            "runs": args.init_runs,
            "values": init_ms,
            "p50": percentile(init_ms, 0.50),
            "p95": percentile(init_ms, 0.95),
        },
        "timing_us": timing,
        "process": {
            "wall_seconds": wall_seconds,
            "user_cpu_seconds": usage.ru_utime,
            "system_cpu_seconds": usage.ru_stime,
            "cpu_seconds": cpu_seconds,
            "cpu_percent_of_one_core": 100.0 * cpu_seconds / wall_seconds,
            "peak_rss_kib": usage.ru_maxrss,
            "pss_samples_kib": pss_samples,
            "max_observed_pss_kib": max(pss_samples),
            "clean_exit": True,
        },
        "distributable_bytes": {
            "files": sizes,
            "total": sum(sizes.values()),
        },
    }
    with open(args.output, "w", encoding="utf-8") as stream:
        json.dump(output, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"measure-phase-d1: {error}", file=sys.stderr)
        sys.exit(1)
