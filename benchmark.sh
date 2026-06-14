#!/usr/bin/env bash
set -euo pipefail

USER_RUNS=5

CASES=(0 1)

run() {
    local case="$1"

    local out_dir="../GSLT-tests/energy-results/${case}"

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
                sed -i 's/algorithm = [0-9]\+/algorithm = ${case}/' config.lua
                lualatex -interaction=nonstopmode darwin.tex
            done
        "
}

for case in "${CASES[@]}"; do
    echo "Running $case"
    run "$case"
done
