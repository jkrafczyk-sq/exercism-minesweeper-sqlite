#!/usr/bin/env bash
set -e

DB="test.db"

function do_test() {
    local test_case="$1"
    local status=0
    echo "INSERT INTO input(line) VALUES ('RESET');" | sqlite3 "${DB}"
    sqlite3 "${DB}" < "tests/${test_case}.sql"  >& /dev/null || true
    sqlite3 "${DB}" < print.sql > "tests/${test_case}.actual"
    if [[ -f "tests/${test_case}.expected_error" ]]; then
        local actual_err="$(echo "SELECT error FROM field_info WHERE error IS NOT NULL;" | sqlite3 "${DB}")"
        local expected_err="$(cat tests/${test_case}.expected_error)"
        if [[ "${expected_err}" = "${actual_err}" ]]; then
            printf "[\033[32;1m  OK  \033[0m] %s\n" "${test_case}"
        else
            printf "[\033[31;1m FAIL \033[0m] %s\n" "${test_case}"
            printf "         Expected error: '%s'\n" "${expected_err}"
            printf "         Actual error:   '%s'\n" "${actual_err}"
            status=1
        fi
    elif ! cmp -s "tests/${test_case}.expected" "tests/${test_case}.actual"; then
        printf "[\033[31;1m FAIL \033[0m] %s: Incorrect field output\n" "${test_case}"
        status=1
    else
        printf "[\033[32;1m  OK  \033[0m] %s\n" "${test_case}"
    fi
    (
        echo "SELECT 'Field size: ' || rows || 'x' || columns FROM field_info;" | sqlite3 "${DB}"
        echo "SELECT 'Returned error message: ' || error FROM field_info WHERE error IS NOT NULL;" | sqlite3 "${DB}"
        cat "tests/${test_case}.actual" | sed 's/^/|/' | sed 's/$/|/'
    ) | sed 's/^/         /' 
}

echo "Creating database..."
rm -f "${DB}"
sqlite3 "${DB}" < ./schema.sql
for testcase in tests/*.sql; do
    do_test "$(basename $testcase .sql)"
done
