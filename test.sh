#!/usr/bin/env bash
set -e

DB="test.db"

function do_test() {
    local test_case="$1"
    sqlite3 "${DB}" < "tests/${test_case}.sql"
    sqlite3 "${DB}" < print.sql > "tests/${test_case}.actual"
    if ! cmp -s "tests/${test_case}.expected" "tests/${test_case}.actual"; then
        printf "[\033[31;1m FAIL \033[0m] %s\n" "${test_case}"
    else
        printf "[\033[32;1m  OK  \033[0m] %s\n" "${test_case}"
    fi
}

echo "Creating database..."
rm -f "${DB}"
sqlite3 "${DB}" < ./schema.sql
for testcase in tests/*.sql; do
    do_test "$(basename $testcase .sql)"
done
#do_test single-bomb-in-center-3x3
#do_test empty-field