#!/usr/bin/env bash
set -euo pipefail

cd tex

USER_RUNS=3

CASES=(no_hyphenation default_hyphenation custom_hyphenation)

run() {
    local case="$1"

    local out_dir="../energy-results/${case}"

    mkdir -p "$out_dir/idle" "$out_dir/run"

    energy-bench \
        --warmup-runs 1 \
        --benchmark-runs "$USER_RUNS" \
        --benchmark-name "luatex_${case}" \
        --idle-duration-seconds 30 \
        --idle-path "$out_dir/idle" \
        -- bash -c "
            for i in \$(seq 1 $USER_RUNS); do
                rm -f *.aux *.log *.pdf
                lualatex -interaction=nonstopmode ${case}.tex > /dev/null
            done
        "
}

for case in "${CASES[@]}"; do
    echo "Running $case"
    run "$case"
donebe
