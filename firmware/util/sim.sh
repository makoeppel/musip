#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 [OPTION]... [TB_ENTITY] [VHD_FILE]..."
    echo
    echo "Options:"
    echo "  --no-gtkwave          Disable gtkwave launch"
    echo "  --wave-format=FORMAT  One of: fst, vcd, ghw, none"
    exit 1
fi

GTKWAVE=1
[ -z "${DISPLAY:-}" ] && GTKWAVE=0

TB=""
SRC=()
WAVE_FORMAT="${WAVE_FORMAT:-fst}"

for arg in "$@"; do
    case "$arg" in
        --no-gtkwave)
            GTKWAVE=0
            ;;
        --wave-format=*)
            WAVE_FORMAT="${arg#--wave-format=}"
            ;;
        *)
            if [[ -z "$TB" ]]; then
                TB=${arg##*/}
                TB=${TB%%.*}
            fi

            [[ "$arg" == *.vhd ]] || continue

            arg=$(python3 -c 'import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[1]), ".cache"))' "$arg")

            if [[ ! " ${SRC[*]-} " =~ [[:space:]]$arg[[:space:]] ]]; then
                SRC+=("$arg")
            fi
            ;;
    esac
done

if [[ -z "$TB" ]]; then
    echo "Error: no testbench entity provided." >&2
    exit 1
fi

DIRS=(
    "/usr/local/lib/ghdl/vendors/altera"
    "/usr/lib/ghdl/vendors/altera"
    "$HOME/.local/share/ghdl/vendors/altera"
)

OPTS=(
    "--std=08"
    "--ieee=standard"
    "-fexplicit"
    "-fsynopsys"
    "--mb-comments"
    "-fpsl"
)

for dir in "${DIRS[@]}"; do
    [ -d "$dir" ] && OPTS+=("-P$dir")
done

SIM_OPTS=(
    "--disp-tree=inst"
    "--ieee-asserts=disable-at-0"
    "--assert-level=failure"
    "--backtrace-severity=warning"
    "--psl-report=$TB.psl-report"
)

case "$WAVE_FORMAT" in
    fst)
        SIM_OPTS+=("--fst=$TB.fst")
        ;;
    vcd)
        SIM_OPTS+=("--vcd=$TB.vcd")
        ;;
    ghw)
        SIM_OPTS+=("--wave=$TB.ghw")
        ;;
    none)
        ;;
    *)
        echo "Error: invalid WAVE_FORMAT '$WAVE_FORMAT'." >&2
        echo "Valid values: fst, vcd, ghw, none" >&2
        exit 1
        ;;
esac

if [ -n "${STOP_TIME_US:+x}" ]; then
    SIM_OPTS+=(
        "--stop-time=${STOP_TIME_US}us"
        "-gg_STOP_TIME_US=$STOP_TIME_US"
        "-gg_SEED=$((0x$(tr -dc '0-9A-F' < /dev/random | head -c 8)-0x80000000))"
    )
else
    SIM_OPTS+=(
        "--stop-time=${STOPTIME:-1us}"
    )
fi

[ -f "../$TB.wave-opt" ] && [ "$WAVE_FORMAT" = "ghw" ] && SIM_OPTS+=("--read-wave-opt=../$TB.wave-opt")

mkdir -p .cache
cd .cache || exit 1

echo "Working directory:"
pwd
echo "Testbench: $TB"
echo "Wave format: $WAVE_FORMAT"
echo "Sources:"
printf '  %s\n' "${SRC[@]}"

ghdl -i "${OPTS[@]}" "${SRC[@]}"
ghdl -m "${OPTS[@]}" "$TB"
ghdl -r "${OPTS[@]}" "$TB" "${SIM_OPTS[@]}"

if [[ $GTKWAVE != 0 ]]; then
    case "$WAVE_FORMAT" in
        ghw)
            touch "../$TB.gtkw"
            gtkwave "$TB.ghw" "../$TB.gtkw"
            ;;
        fst)
            touch "../$TB.gtkw"
            gtkwave "$TB.fst" "../$TB.gtkw"
            ;;
        vcd)
            touch "../$TB.gtkw"
            gtkwave "$TB.vcd" "../$TB.gtkw"
            ;;
    esac
fi