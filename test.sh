#!/usr/bin/env bash

PROGRAM="./main.bin"
LOG="log.txt"
HELPER_SOURCE=".test_limits.c"
HELPER=".test_limits.bin"
LIMITS_FILE=".test_limits.txt"

pass=0
fail=0

: >"$LOG"

cleanup() {
        rm -f "$HELPER_SOURCE" "$HELPER" "$LIMITS_FILE" "$LOG.compile"
}
trap cleanup EXIT

#
# Format a string for human-readable test output.
#
format_string() {
        local value="$1"

        value=${value//\\/\\\\}
        value=${value//$'\t'/\\t}
        value=${value//$'\n'/\\n}
        value=${value//$'\r'/\\r}
        value=${value//$'\v'/\\v}
        value=${value//$'\f'/\\f}
        value=${value//\'/\\\'}

        printf "'%s'" "$value"
}

#
# Determine the int limits using standard C rather than assuming
# anything about the machine's int representation.
#
cat >"$HELPER_SOURCE" <<'EOF'
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <inttypes.h>

int main(void)
{
    printf("%" PRIdMAX "\n", (intmax_t)INT_MIN);
    printf("%" PRIdMAX "\n", (intmax_t)INT_MAX);
    printf("%" PRIdMAX "\n", (intmax_t)INT_MAX + 1);
    printf("%" PRIdMAX "\n", (intmax_t)INT_MIN - 1);
    printf("%" PRIdMAX "\n", (intmax_t)INT_MAX - 1);
    printf("%" PRIdMAX "\n", (intmax_t)INT_MIN + 1);

    return 0;
}
EOF

if ! cc -std=c11 -pedantic -Wall -Wextra -Werror \
        "$HELPER_SOURCE" -o "$HELPER" 2>"$LOG.compile"; then
        {
                echo "ERROR: could not compile the standard-C test helper."
                cat "$LOG.compile"
        } >>"$LOG"
        exit 1
fi

rm -f "$LOG.compile"

if ! "./$HELPER" >"$LIMITS_FILE"; then
        echo "ERROR: could not run the test helper." >>"$LOG"
        exit 1
fi

mapfile -t LIMITS <"$LIMITS_FILE"

INT_MIN=${LIMITS[0]}
INT_MAX=${LIMITS[1]}
ABOVE_INT_MAX=${LIMITS[2]}
BELOW_INT_MIN=${LIMITS[3]}
INT_MAX_MINUS_ONE=${LIMITS[4]}
INT_MIN_PLUS_ONE=${LIMITS[5]}

if [[ -z "$INT_MIN" || -z "$INT_MAX" ||
        -z "$ABOVE_INT_MAX" || -z "$BELOW_INT_MIN" ]]; then
        echo "ERROR: could not determine integer limits." >>"$LOG"
        exit 1
fi

#
# run_test TAG NAME INPUT EXPECTED_STATUS EXPECTED_STDOUT
#
run_test() {
        local tag="$1"
        local name="$2"
        local input="$3"
        local expected_status="$4"
        local expected_stdout="$5"

        local stdout_file stderr_file
        stdout_file=$(mktemp)
        stderr_file=$(mktemp)

        "$PROGRAM" "$input" >"$stdout_file" 2>"$stderr_file"
        local actual_status=$?

        local actual_stdout actual_stderr
        actual_stdout=$(cat "$stdout_file")
        actual_stderr=$(cat "$stderr_file")

        local ok=true

        if [[ "$actual_status" -ne "$expected_status" ]]; then
                ok=false
        elif [[ "$actual_stdout" != "$expected_stdout" ]]; then
                ok=false
        fi

        {
                echo "[$tag] $name"
                echo "  input:    $(format_string "$input")"
                echo "  expected: status=$expected_status, stdout=$(format_string "$expected_stdout")"
                echo "  returned: status=$actual_status, stdout=$(format_string "$actual_stdout")"

                if [[ -n "$actual_stderr" ]]; then
                        echo "  stderr:   $(format_string "$actual_stderr")"
                else
                        echo "  stderr:   ''"
                fi

                if $ok; then
                        echo "  result:   PASS"
                        ((pass++))
                else
                        echo "  result:   FAIL"
                        ((fail++))
                fi

                echo
        } >>"$LOG"

        rm -f "$stdout_file" "$stderr_file"
}

#
# Tests for cases where no command-line argument is supplied.
#
run_noarg_test() {
        local tag="$1"
        local name="$2"

        local stderr_file
        stderr_file=$(mktemp)

        "$PROGRAM" >/dev/null 2>"$stderr_file"
        local actual_status=$?
        local actual_stderr
        actual_stderr=$(cat "$stderr_file")

        {
                echo "[$tag] $name"
                echo "  expected: status!=0"
                echo "  returned: status=$actual_status"

                if [[ -n "$actual_stderr" ]]; then
                        echo "  stderr:   $(format_string "$actual_stderr")"
                else
                        echo "  stderr:   ''"
                fi

                if [[ "$actual_status" -ne 0 ]]; then
                        echo "  result:   PASS"
                        ((pass++))
                else
                        echo "  result:   FAIL"
                        ((fail++))
                fi

                echo
        } >>"$LOG"

        rm -f "$stderr_file"
}

#
# Tests for cases where too many command-line arguments are supplied.
#
run_extra_arg_test() {
        local tag="$1"
        local name="$2"

        local stderr_file
        stderr_file=$(mktemp)

        "$PROGRAM" "1" "2" "3" >/dev/null 2>"$stderr_file"
        local actual_status=$?
        local actual_stderr
        actual_stderr=$(cat "$stderr_file")

        {
                echo "[$tag] $name"
                echo "  expected: status!=0"
                echo "  returned: status=$actual_status"

                if [[ -n "$actual_stderr" ]]; then
                        echo "  stderr:   $(format_string "$actual_stderr")"
                else
                        echo "  stderr:   ''"
                fi

                if [[ "$actual_status" -ne 0 ]]; then
                        echo "  result:   PASS"
                        ((pass++))
                else
                        echo "  result:   FAIL"
                        ((fail++))
                fi

                echo
        } >>"$LOG"

        rm -f "$stderr_file"
}

#
# --------------------------------------------------------------------------
# REQ1 / REQ6 — command-line argument count
# --------------------------------------------------------------------------
#

run_noarg_test REQ1/REQ6 "no arguments"
run_extra_arg_test REQ1/REQ6 "too many arguments"

#
# --------------------------------------------------------------------------
# REQ2 — valid lists
# --------------------------------------------------------------------------
#

run_test REQ2 "single zero" \
        "0" 0 "0"

run_test REQ2 "single positive integer" \
        "42" 0 "42"

run_test REQ2 "single negative integer" \
        "-42" 0 "-42"

run_test REQ2 "explicit positive sign" \
        "+42" 0 "42"

run_test REQ2 "negative zero" \
        "-0" 0 "0"

run_test REQ2 "positive zero" \
        "+0" 0 "0"

run_test REQ2 "leading zeroes" \
        "00000042" 0 "42"

run_test REQ2 "multiple integers" \
        "1,2,3" 0 "6"

run_test REQ2 "mixed signs" \
        "-15,+7,100" 0 "92"

run_test REQ2 "leading and trailing whitespace" \
        "  42  " 0 "42"

run_test REQ2 "whitespace around commas" \
        "1  ,  2  ,  3" 0 "6"

run_test REQ2 "whitespace around every integer" \
        "  1  ,  2  ,  3  " 0 "6"

run_test REQ2 "tabs around integers" \
        $'\t1\t,\t2\t' 0 "3"

run_test REQ2 "newlines around integers" \
        $'\n1\n,\n2\n' 0 "3"

run_test REQ2 "mixed C whitespace" \
        $' \t\n1\v\f,\r2 \t\n' 0 "3"

run_test REQ2 "leading zeroes in list" \
        "123,0005,001" 0 "129"

run_test REQ2 "many integers" \
        "1,2,3,4,5,6,7,8,9,10" 0 "55"

run_test REQ2 "all zeroes" \
        "0,0,0,0,0" 0 "0"

run_test REQ2 "negative result" \
        "-10,-20,5" 0 "-25"

#
# --------------------------------------------------------------------------
# REQ2 / REQ3 — missing integer / empty fields
# --------------------------------------------------------------------------
#

run_test REQ2 "empty argument" \
        "" 1 ""

run_test REQ2 "space-only argument" \
        "     " 1 ""

run_test REQ2 "tab-only argument" \
        $'\t\t\t' 1 ""

run_test REQ2 "newline-only argument" \
        $'\n\n' 1 ""

run_test REQ2 "leading comma" \
        ",1" 1 ""

run_test REQ2 "leading comma with whitespace" \
        "  ,1" 1 ""

run_test REQ2 "trailing comma" \
        "1," 1 ""

run_test REQ2 "trailing comma with whitespace" \
        "1,  " 1 ""

run_test REQ2 "consecutive commas" \
        "1,,2" 1 ""

run_test REQ2 "consecutive commas with whitespace" \
        "1,  ,2" 1 ""

run_test REQ2 "three consecutive commas" \
        "1,,,2" 1 ""

run_test REQ2 "comma-only argument" \
        "," 1 ""

run_test REQ2 "multiple comma-only fields" \
        ",,," 1 ""

run_test REQ2 "whitespace-only field" \
        "1,    ,2" 1 ""

run_test REQ2 "whitespace-only field using tabs" \
        $'1,\t\t,2' 1 ""

run_test REQ2 "whitespace-only field using newlines" \
        $'1,\n\n,2' 1 ""

#
# --------------------------------------------------------------------------
# REQ2 / REQ3 — malformed characters before an integer
# --------------------------------------------------------------------------
#

run_test REQ2 "letters before integer" \
        "abc123" 1 ""

run_test REQ2 "single letter before integer" \
        "a1" 1 ""

run_test REQ2 "punctuation before integer" \
        ".1" 1 ""

run_test REQ2 "semicolon before integer" \
        ";1" 1 ""

run_test REQ2 "plus without digits" \
        "+" 1 ""

run_test REQ2 "minus without digits" \
        "-" 1 ""

run_test REQ2 "letters after comma before integer" \
        "1,abc2" 1 ""

run_test REQ2 "punctuation after comma before integer" \
        "1,.2" 1 ""

run_test REQ2 "sign without digits after comma" \
        "1,+" 1 ""

run_test REQ2 "sign followed by whitespace" \
        "+ 1" 1 ""

run_test REQ2 "negative sign followed by whitespace" \
        "- 1" 1 ""

run_test REQ2 "sign followed by whitespace after comma" \
        "1,+ 2" 1 ""

#
# --------------------------------------------------------------------------
# REQ2 / REQ3 — malformed characters after an integer
# --------------------------------------------------------------------------
#

run_test REQ2 "letters after integer" \
        "1abc" 1 ""

run_test REQ2 "single letter after integer" \
        "1a" 1 ""

run_test REQ2 "punctuation after integer" \
        "1." 1 ""

run_test REQ2 "semicolon after integer" \
        "1;2" 1 ""

run_test REQ2 "letters after integer before comma" \
        "1abc,2" 1 ""

run_test REQ2 "punctuation after integer before comma" \
        "1.,2" 1 ""

run_test REQ2 "plus directly after integer" \
        "1+2" 1 ""

run_test REQ2 "minus directly after integer" \
        "1-2" 1 ""

run_test REQ2 "decimal-looking input" \
        "1.2" 1 ""

run_test REQ2 "multiple malformed characters" \
        "1abcXYZ" 1 ""

#
# --------------------------------------------------------------------------
# REQ2 / REQ3 — whitespace inside integers
# --------------------------------------------------------------------------
#

run_test REQ2 "space inside integer" \
        "1 2" 1 ""

run_test REQ2 "tab inside integer" \
        $'1\t2' 1 ""

run_test REQ2 "newline inside integer" \
        $'1\n2' 1 ""

run_test REQ2 "space between digits in list" \
        "12 34,56" 1 ""

run_test REQ2 "space between sign and digits" \
        "+ 1" 1 ""

run_test REQ2 "space between negative sign and digits" \
        "- 1" 1 ""

#
# --------------------------------------------------------------------------
# REQ2 / REQ3 — separator mistakes
# --------------------------------------------------------------------------
#

run_test REQ2 "missing comma" \
        "1 2" 1 ""

run_test REQ2 "missing comma between signed integers" \
        "1 -2" 1 ""

run_test REQ2 "semicolon separator" \
        "1;2" 1 ""

run_test REQ2 "colon separator" \
        "1:2" 1 ""

run_test REQ2 "period separator" \
        "1.2" 1 ""

run_test REQ2 "slash separator" \
        "1/2" 1 ""

run_test REQ2 "extra comma after whitespace" \
        "1 , , 2" 1 ""

run_test REQ2 "multiple trailing commas" \
        "1,2,," 1 ""

#
# --------------------------------------------------------------------------
# REQ4 — individual int boundaries
# --------------------------------------------------------------------------
#

run_test REQ4 "INT_MAX" \
        "$INT_MAX" 0 "$INT_MAX"

run_test REQ4 "INT_MIN" \
        "$INT_MIN" 0 "$INT_MIN"

run_test REQ4 "INT_MAX plus one" \
        "$ABOVE_INT_MAX" 1 ""

run_test REQ4 "INT_MIN minus one" \
        "$BELOW_INT_MIN" 1 ""

run_test REQ4 "INT_MAX plus one with positive sign" \
        "+$ABOVE_INT_MAX" 1 ""

run_test REQ4 "INT_MIN minus one with whitespace" \
        "  $BELOW_INT_MIN  " 1 ""

run_test REQ4 "large positive out-of-range value" \
        "999999999999999999999999999999" 1 ""

run_test REQ4 "large negative out-of-range value" \
        "-999999999999999999999999999999" 1 ""

run_test REQ4 "out-of-range positive number canceled by negative" \
        "$ABOVE_INT_MAX,$BELOW_INT_MIN" 1 ""

run_test REQ4 "out-of-range negative number canceled by positive" \
        "$BELOW_INT_MIN,$ABOVE_INT_MAX" 1 ""

#
# --------------------------------------------------------------------------
# REQ5 — sum overflow / underflow
# --------------------------------------------------------------------------
#

run_test REQ5 "INT_MAX plus one" \
        "$INT_MAX,1" 1 ""

run_test REQ5 "one plus INT_MAX" \
        "1,$INT_MAX" 1 ""

run_test REQ5 "INT_MIN minus one" \
        "$INT_MIN,-1" 1 ""

run_test REQ5 "minus one plus INT_MIN" \
        "-1,$INT_MIN" 1 ""

run_test REQ5 "positive overflow after several values" \
        "1,2,3,$INT_MAX" 1 ""

run_test REQ5 "negative underflow after several values" \
        "-1,-2,-3,$INT_MIN" 1 ""

run_test REQ5 "positive values reaching maximum" \
        "$INT_MAX_MINUS_ONE,1" 0 "$INT_MAX"

run_test REQ5 "negative values reaching minimum" \
        "$INT_MIN_PLUS_ONE,-1" 0 "$INT_MIN"

run_test REQ5 "INT_MAX cancellation" \
        "$INT_MAX,$INT_MIN" 0 "0"

run_test REQ5 "reverse cancellation" \
        "$INT_MIN,$INT_MAX" 0 "0"

run_test REQ5 "positive cancellation" \
        "$INT_MAX,-$INT_MAX" 0 "0"

run_test REQ5 "negative cancellation" \
        "$INT_MIN,-$INT_MIN" 0 "0"

run_test REQ5 "large positive followed by cancellation" \
        "$INT_MAX,-$INT_MAX,1" 0 "1"

run_test REQ5 "large negative followed by cancellation" \
        "$INT_MIN,-$INT_MIN,-1" 0 "-1"

#
# --------------------------------------------------------------------------
# REQ2 / REQ4 / REQ5 — combinations
# --------------------------------------------------------------------------
#

run_test REQ2 "whitespace signs and leading zeroes" \
        $' \t+00042\t,\n-00010 \n' 0 "32"

run_test REQ2 "many signed zeroes" \
        "+0,-0,+000,-000,0" 0 "0"

run_test REQ2 "mixed whitespace and signs" \
        $'\t-10 , +20,\n-30 , +40\t' 0 "20"

#
# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
#

{
        echo "================================"
        echo "Passed: $pass"
        echo "Failed: $fail"
        echo "================================"
} >>"$LOG"

if [[ "$fail" -eq 0 ]]; then
        exit 0
else
        exit 1
fi
