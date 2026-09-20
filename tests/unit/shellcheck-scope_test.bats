#!/usr/bin/env bats
# ShellCheck scope contract for this repository.
#
# The scope is currently stated by two consumers:
#   - .github/workflows/validate-shellcheck.yml lints build/**/*.sh in CI
#   - Justfile:lint lints every *.sh under the repository root locally
#
# Ownership (Task 2 vs. the follow-up lint task): this file is the conditional
# coverage introduced by Task 2. The `.shellcheck-scope` tests below skip until
# the manifest exists and then gate its shape, so a stale or malformed pattern
# cannot silently drop a script from the scope. The follow-up lint task MUST
# reuse these tests when it creates .shellcheck-scope and MUST NOT add a second,
# duplicate manifest-contract test.
#
# Run with: bats tests/unit/shellcheck-scope_test.bats

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/validate-shellcheck.yml"
JUSTFILE="${REPO_ROOT}/Justfile"
SCOPE="${REPO_ROOT}/.shellcheck-scope"

# Declared glob patterns, comments and blank lines stripped.
scope_patterns() {
    sed 's/#.*//' "${SCOPE}" | tr -d '[:blank:]' | grep -v '^$'
}

# Files matched by the declared patterns, expanded from the repository root.
scope_matches() {
    (
        cd "${REPO_ROOT}" || exit 1
        shopt -s globstar nullglob
        while IFS= read -r pattern; do
            for f in ${pattern}; do
                [ -f "${f}" ] && printf '%s\n' "${f}"
            done
        done < <(scope_patterns)
    ) | sort -u
}

# Print the body of a recipe whose header ends in `:` (arguments allowed).
# Reading a specific recipe matters: a bare `grep -F 'find .'` over the whole
# Justfile would match the `check` recipe's `find . -type f -name "*.just"`
# first and prove nothing about `lint`.
recipe_body() {
    local recipe="$1"
    awk -v recipe="${recipe}" '
        $0 ~ ("^" recipe "([ ][^:]*)?:$") { in_recipe = 1; next }
        in_recipe && /^[^[:space:]]/ { exit }
        in_recipe { print }
    ' "${JUSTFILE}"
}

# Extract "<root>|<pattern>" from the first `find <root> -iname <pattern>`
# declaration in a recipe body or workflow snippet.
find_scope() {
    local line="$1" root pattern
    line="${line#*find }"
    root="${line%% *}"
    root="${root//\"/}"
    root="${root//\'/}"
    line="${line#* -iname }"
    pattern="${line%% *}"
    pattern="${pattern//\"/}"
    pattern="${pattern//\'/}"
    [ -n "${root}" ] && [ -n "${pattern}" ] || return 1
    printf '%s|%s\n' "${root}" "${pattern}"
}

@test "CI shellcheck workflow lints build shell scripts" {
    [ -f "${WORKFLOW}" ]

    run grep -F 'build/**/*.sh' "${WORKFLOW}"
    [ "${status}" -eq 0 ]

    run grep -F 'find "build" -iname' "${WORKFLOW}"
    [ "${status}" -eq 0 ]

    run grep -F 'shellcheck -x' "${WORKFLOW}"
    [ "${status}" -eq 0 ]
}

@test "Justfile lint lints every *.sh from the repository root" {
    [ -f "${JUSTFILE}" ]

    run grep -F 'find . -iname' "${JUSTFILE}"
    [ "${status}" -eq 0 ]

    run grep -F 'shellcheck "{}"' "${JUSTFILE}"
    [ "${status}" -eq 0 ]
}

@test "just lint's declared scope covers every script the CI workflow lints" {
    # Expand both consumers from their actual declarations instead of trusting
    # a self-matching `find build ... | [[ $f == build/*.sh ]]` loop. If the
    # workflow stops matching real files, or `just lint` stops walking the tree
    # from the repository root, the expanded scopes no longer line up.
    local lint_body lint_scope
    lint_body="$(recipe_body lint)"
    [ -n "${lint_body}" ]
    [[ "${lint_body}" == *'/usr/bin/find . -iname "*.sh"'* ]]

    lint_scope="$(find_scope "${lint_body}")"
    [ -n "${lint_scope}" ]
    [ "${lint_scope%%|*}" = "." ]
    [ "${lint_scope##*|}" = "*.sh" ]

    local ci_line ci_scope
    ci_line="$(grep -F 'find "build" -iname' "${WORKFLOW}")"
    [ -n "${ci_line}" ]
    ci_scope="$(find_scope "${ci_line}")"
    [ -n "${ci_scope}" ]

    local local_files ci_files uncovered
    # Normalize the `find .` prefix so both scopes are compared as repo-relative
    # paths (`./build/x.sh` and `build/x.sh` are the same file).
    local_files="$(cd "${REPO_ROOT}" && find "${lint_scope%%|*}" -iname "${lint_scope##*|}" -type f | sed 's|^\./||' | sort)"
    [ -n "${local_files}" ]

    ci_files="$(cd "${REPO_ROOT}" && find "${ci_scope%%|*}" -iname "${ci_scope##*|}" -type f | sed 's|^\./||' | sort)"
    [ -n "${ci_files}" ]

    uncovered="$(comm -23 <(printf '%s\n' "${ci_files}") <(printf '%s\n' "${local_files}"))"
    if [ -n "${uncovered}" ]; then
        echo "scripts linted by CI but outside the 'just lint' scope:"
        echo "${uncovered}"
        false
    fi
}

@test ".shellcheck-scope (when present) is a well-formed manifest" {
    [ -f "${SCOPE}" ] || skip "no .shellcheck-scope yet (added by the lint follow-up)"

    run scope_patterns
    [ "${status}" -eq 0 ]
    [ -n "${output}" ]

    # Consumers join patterns with spaces, so an embedded space would silently
    # split one pattern into two.
    run bash -c "sed 's/#.*//' '${SCOPE}' | grep -v '^[[:space:]]*$' | grep -n '[[:space:]]'"
    [ "${status}" -ne 0 ]
}

@test ".shellcheck-scope (when present) matches files and covers build/*.sh" {
    [ -f "${SCOPE}" ] || skip "no .shellcheck-scope yet (added by the lint follow-up)"

    local pattern
    while IFS= read -r pattern; do
        run bash -c "cd '${REPO_ROOT}' && shopt -s globstar nullglob && files=(${pattern}) && printf '%s\n' \${#files[@]}"
        [ "${status}" -eq 0 ]
        [ "${output}" -gt 0 ] || {
            echo "stale pattern (matches nothing): ${pattern}"
            false
        }
    done < <(scope_patterns)

    local matches build_scripts uncovered
    matches="$(scope_matches)"
    build_scripts="$(cd "${REPO_ROOT}" && find build -iname '*.sh' -type f | sort)"
    [ -n "${build_scripts}" ]

    uncovered="$(comm -23 <(printf '%s\n' "${build_scripts}") <(printf '%s\n' "${matches}"))"
    if [ -n "${uncovered}" ]; then
        echo "build scripts not matched by .shellcheck-scope:"
        echo "${uncovered}"
        false
    fi
}
