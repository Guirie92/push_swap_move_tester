#!/bin/bash

# ------- Config ------- #
EXEC="./push_swap"
TESTER="./checker_linux"
VERBOSE=0
CLR_GRN='\e[32m'
CLR_RED='\e[31m'
CLR_GLN='\e[38;2;255;215;0m'
CLR_RST='\e[0m'

# ------- ARGUMENT HANDLING ------- #
# Get ARRAY_SIZE from $1, fallback to 100
if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
  ARRAY_SIZE=$1
else
  ARRAY_SIZE=100
fi

# Get NUM_TESTS from $2, fallback to 100
if [ -n "$2" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
  NUM_TESTS=$2
else
  NUM_TESTS=100
fi

if [ "$ARRAY_SIZE" -le 100 ]; then
  THRESHOLD=700
else
  THRESHOLD=5500
fi

INT_MIN=-2147483648
INT_MAX=2147483647

# ------- Stats ------- #
MAX_MOVES=0
MIN_MOVES=999999999
TOTAL_MOVES=0
TEST_COUNT=0
THRESHOLD_FAIL_COUNT=0
CHECKER_OK=0
CHECKER_KO=0

# temp files
INPUT_TMP=$(mktemp /tmp/shufnbr.XXXXXX.txt)
MOVES_TMP=$(mktemp /tmp/moves.XXXXXX.txt)

cleanup() {
  echo
  echo "=== Test Summary ==="
  echo "Total Tests Run: $TEST_COUNT"
  if [ "$TEST_COUNT" -gt 0 ]; then
    printf "MIN Moves for %d numbers: %d\n" "$ARRAY_SIZE" "$MIN_MOVES"
    printf "MAX Moves for %d numbers: %d\n" "$ARRAY_SIZE" "$MAX_MOVES"
    AVERAGE=$(echo "scale=2; $TOTAL_MOVES / $TEST_COUNT" | bc 2>/dev/null || echo "0")
    printf "AVERAGE Moves: %s\n" "$AVERAGE"

    echo
	FAILURE_PERCENT=$(echo "scale=2; ($THRESHOLD_FAIL_COUNT * 100) / $TEST_COUNT" | bc 2>/dev/null || echo "0")
	if [ "$FAILURE_PERCENT" = "0" ]; then
		echo -en "$CLR_GRN"
		echo -en "--- Threshold ($THRESHOLD) Analysis ---\n"
		printf "Tests >= Threshold: %d\n" "$THRESHOLD_FAIL_COUNT"
		printf "Failure Percentage: %s%%\n" "$FAILURE_PERCENT"
		echo -en "$CLR_RST"
	else
		echo -en "$CLR_RED"
		echo -en "--- Threshold ($THRESHOLD) Analysis ---\n"
		printf "Tests >= Threshold: %d\n" "$THRESHOLD_FAIL_COUNT"
		printf "Failure Percentage: %s%%\n" "$FAILURE_PERCENT"
		echo -en "$CLR_RST"
	fi
	
    echo
    # Checker analysis: color green if both failure pct are zero
    CHECKER_FAIL_PERCENT=$(echo "scale=2; ($CHECKER_KO * 100) / $TEST_COUNT" | bc 2>/dev/null || echo "0")

    if [ "$CHECKER_FAIL_PERCENT" = "0" ]; then
		echo -en "$CLR_GRN"
		echo -en "--- Checker Analysis ---\n"
		printf "Tests OK: %d\nTests KO: %d\nFailure Percentage: %s%%\n" "$CHECKER_OK" "$CHECKER_KO" "$CHECKER_FAIL_PERCENT"
		echo -en "$CLR_RST"
    else
		echo -en "$CLR_RED"
		echo -en "--- Checker Analysis ---\n"
		printf "Tests OK: %d\nTests KO: %d\nFailure Percentage: %s%%\n" "$CHECKER_OK" "$CHECKER_KO" "$CHECKER_FAIL_PERCENT"
		echo -en "$CLR_RST"
    fi
  fi

  rm -f "$INPUT_TMP" "$MOVES_TMP"
}

trap cleanup EXIT

echo "Starting $NUM_TESTS tests for array size $ARRAY_SIZE..."

while [ "$TEST_COUNT" -lt "$NUM_TESTS" ]; do
  # generate unique random numbers (space-separated) and save to INPUT_TMP
  python3 - <<PY >"$INPUT_TMP"
import random
a=$ARRAY_SIZE
mn=$INT_MIN
mx=$INT_MAX
# random.sample supports range() efficiently
seq = random.sample(range(mn, mx+1), a)
print(' '.join(str(x) for x in seq))
PY

  # Run the executable and save its stdout (the moves) to MOVES_TMP
  # Capture its exit code too
  if ! "$EXEC" $(<"$INPUT_TMP") >"$MOVES_TMP" 2>/dev/null; then
    echo "Warning: $EXEC exited with non-zero status on test $((TEST_COUNT+1)). Moves file may be incomplete."
  fi

  # Count moves: number of lines in MOVES_TMP
  CURRENT_MOVES=$(wc -l < "$MOVES_TMP" | tr -d ' ')
  # if program prints single line like "move number: 113", extract numeric
  if [ "$CURRENT_MOVES" -eq 1 ]; then
    # try to extract number from the line
    LINE_NUM=$(sed -n '1p' "$MOVES_TMP")
    if [[ "$LINE_NUM" =~ ([0-9]+) ]]; then
      CURRENT_MOVES="${BASH_REMATCH[1]}"
    fi
  fi

  # Run checker: give the generated numbers as arguments, and moves file on stdin
  CHECKER_OUT=$("$TESTER" $(<"$INPUT_TMP") < "$MOVES_TMP" 2>/dev/null || echo "KO")
  # Normalize checker output
  CHECKER_OUT=$(echo "$CHECKER_OUT" | tr -d '\r\n' | tr '[:lower:]' '[:upper:]')

  # Update checker counters
  if [ "$CHECKER_OUT" = "OK" ]; then
    CHECKER_OK=$((CHECKER_OK+1))
  else
    CHECKER_KO=$((CHECKER_KO+1))
  fi

  # Ensure CURRENT_MOVES is numeric (if not, set to 0)
  if ! [[ "$CURRENT_MOVES" =~ ^[0-9]+$ ]]; then
    CURRENT_MOVES=0
  fi

  # Update stats
  TOTAL_MOVES=$((TOTAL_MOVES + CURRENT_MOVES))

  if [ "$VERBOSE" -eq 1 ]; then
  	echo -en "$CLR_GLN"
  	echo "Test $((TEST_COUNT+1)):"
	echo -en "$CLR_RST"
  	echo "  Moves: $CURRENT_MOVES"
  	echo "  Checker: $CHECKER_OUT"
  fi

  if [ "$CURRENT_MOVES" -gt "$MAX_MOVES" ]; then
		MAX_MOVES=$CURRENT_MOVES
		[ "$VERBOSE" -eq 1 ] && echo "  NEW MAX: $MAX_MOVES (Test $((TEST_COUNT+1))/$NUM_TESTS)"
  fi
  if [ "$CURRENT_MOVES" -lt "$MIN_MOVES" ]; then
  		MIN_MOVES=$CURRENT_MOVES
		[ "$VERBOSE" -eq 1 ] && echo "  NEW MIN: $MIN_MOVES (Test $((TEST_COUNT+1))/$NUM_TESTS)"
  fi

  if [ "$CURRENT_MOVES" -ge "$THRESHOLD" ]; then
    THRESHOLD_FAIL_COUNT=$((THRESHOLD_FAIL_COUNT + 1))
    echo "  !! THRESHOLD BREACHED: $CURRENT_MOVES moves (Test $((TEST_COUNT + 1))/$NUM_TESTS)"
  fi

  TEST_COUNT=$((TEST_COUNT + 1))
done

# cleanup trap will run automatically
exit 0
