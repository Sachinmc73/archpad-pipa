#!/usr/bin/env python3
"""Phase C boundary and process-lifecycle validation for the isolated CLI."""

import argparse
import json
import subprocess
import sys


def run(cli: str, assets: str, payload: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [cli, "--assets", assets, "--trace", "-"],
        input=payload,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True)
    parser.add_argument("--assets", required=True)
    parser.add_argument("--lifecycle-runs", type=int, default=5)
    args = parser.parse_args()
    require(args.lifecycle_runs > 1, "lifecycle-runs must be greater than one")

    invalid_cases = {
        "malformed_json": "{",
        "missing_points": json.dumps({}),
        "empty_trace": json.dumps({"points": []}),
        "one_point": json.dumps({"points": [{"x": 0.5, "y": 0.5, "t": 0.0}]}),
        "missing_coordinate": json.dumps({
            "points": [{"x": 0.1, "y": 0.2, "t": 0.0}, {"x": 0.2, "t": 1.0}]
        }),
        "out_of_range": json.dumps({
            "points": [{"x": 0.1, "y": 0.2, "t": 0.0}, {"x": 1.01, "y": 0.2, "t": 1.0}]
        }),
        "non_finite": '{"points":[{"x":0.1,"y":0.2,"t":0},{"x":1e400,"y":0.2,"t":1}]}',
        "decreasing_time": json.dumps({
            "points": [{"x": 0.1, "y": 0.2, "t": 2.0}, {"x": 0.2, "y": 0.2, "t": 1.0}]
        }),
    }

    results: dict[str, object] = {"invalid": {}, "valid": {}, "lifecycle": {}}
    for name, payload in invalid_cases.items():
        completed = run(args.cli, args.assets, payload)
        require(completed.returncode != 0, f"{name}: invalid trace was accepted")
        results["invalid"][name] = "rejected"

    short_trace = {
        "points": [
            {"x": 0.10, "y": 0.25, "t": 0.0},
            {"x": 0.20, "y": 0.25, "t": 1.0},
        ]
    }
    completed = run(args.cli, args.assets, json.dumps(short_trace))
    require(completed.returncode == 0, f"short trace failed: {completed.stderr}")
    short_output = json.loads(completed.stdout)
    require(short_output["models"] == {"context_lm": True, "decoder": True},
            "short trace did not load the complete model pipeline")
    results["valid"]["two_point_trace"] = "accepted"

    long_trace = {
        "points": [
            {
                "x": 0.10 + 0.80 * (i / 9999.0),
                "y": 0.25 + 0.10 * ((i % 101) / 100.0),
                "t": float(i),
            }
            for i in range(10000)
        ]
    }
    completed = run(args.cli, args.assets, json.dumps(long_trace))
    require(completed.returncode == 0, f"long trace failed: {completed.stderr}")
    json.loads(completed.stdout)
    results["valid"]["ten_thousand_point_trace"] = "accepted"

    reference_words = None
    smoke_payload = json.dumps({
        "points": [
            {"x": 0.39, "y": 0.50, "t": 0.0},
            {"x": 0.27, "y": 0.50, "t": 40.0},
            {"x": 0.86, "y": 0.50, "t": 80.0},
            {"x": 0.86, "y": 0.50, "t": 120.0},
            {"x": 0.91, "y": 0.50, "t": 160.0},
        ],
        "context": ["say"],
    })
    for iteration in range(args.lifecycle_runs):
        completed = run(args.cli, args.assets, smoke_payload)
        require(completed.returncode == 0,
                f"lifecycle run {iteration + 1} failed: {completed.stderr}")
        output = json.loads(completed.stdout)
        words = [candidate["word"] for candidate in output["candidates"]]
        require(words, f"lifecycle run {iteration + 1} returned no candidates")
        require(output["models"] == {"context_lm": True, "decoder": True},
                f"lifecycle run {iteration + 1} omitted a model")
        if reference_words is None:
            reference_words = words
        require(words == reference_words,
                f"lifecycle run {iteration + 1} changed ranked candidates")

    results["lifecycle"] = {
        "clean_process_runs": args.lifecycle_runs,
        "stable_candidates": reference_words,
    }
    print(json.dumps(results, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"validate-phase-c: {error}", file=sys.stderr)
        sys.exit(1)
