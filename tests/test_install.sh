#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT HUP INT TERM
PASSED=0
FAILED=0
OUT=$T/out
RC=0
BASE_PATH=$PATH

new_env() {
    if [ -n "${T:-}" ]; then
        rm -rf "$T"
    fi
    T=$(mktemp -d)
    mkdir -p "$T/home" "$T/bin"
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'if [ "$1" = do ]; then exit "${HM_TEST_SWITCH_RC:-0}"; fi' 'exit 0' > "$T/bin/herdr-app"
    chmod +x "$T/bin/herdr-app"
    export T
    unset HM_TEST_CHECK_RC HM_TEST_SWITCH_RC
    export HERDR_APP_HOME="$T/home"
    export HM_SRC="$ROOT"
    export PATH="$T/bin:$BASE_PATH"
    OUT=$T/out
    RC=0
}

run_install() {
    set +e
    (cd "$ROOT" && sh install.sh "$@") >"$OUT" 2>&1
    RC=$?
    set -e
}

ok() {
    name=$1
    shift
    if "$@"; then
        PASSED=$((PASSED + 1))
        printf 'ok - %s\n' "$name"
    else
        FAILED=$((FAILED + 1))
        printf 'not ok - %s\n' "$name"
    fi
}

payload_exists() {
    for path in layouts/phosphor-rain.json layouts/phosphor-rain.svg themes/phosphor-rain.json mods/phosphor-rain mods/phosphor-tabs; do
        [ -e "$HERDR_APP_HOME/$path" ] || return 1
    done
}

payload_absent() {
    for path in layouts/phosphor-rain.json layouts/phosphor-rain.svg themes/phosphor-rain.json mods/phosphor-rain mods/phosphor-tabs; do
        [ -e "$HERDR_APP_HOME/$path" ] && return 1
    done
    return 0
}

case_clean_install() {
    new_env
    run_install
    [ "$RC" -eq 0 ] && payload_exists
}
ok 'clean install copies payload' case_clean_install

case_second_run_refuses() {
    new_env
    run_install || :
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    run_install || :
    [ "$RC" -ne 0 ] && grep -q 'themes/phosphor-rain.json' "$OUT" && grep -q '# mine' "$HERDR_APP_HOME/themes/phosphor-rain.json"
}
ok 'second run refuses and changes nothing' case_second_run_refuses

case_conflicts_are_lines() {
    new_env
    mkdir -p "$HERDR_APP_HOME/layouts" "$HERDR_APP_HOME/themes"
    : > "$HERDR_APP_HOME/layouts/phosphor-rain.json"
    : > "$HERDR_APP_HOME/themes/phosphor-rain.json"
    run_install || :
    [ "$RC" -ne 0 ] && grep -Fxq '  layouts/phosphor-rain.json' "$OUT" && grep -Fxq '  themes/phosphor-rain.json' "$OUT"
}
ok 'conflicts print one path per line' case_conflicts_are_lines

case_force_replaces() {
    new_env
    run_install || :
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    run_install --force
    [ "$RC" -eq 0 ] && ! grep -q '# mine' "$HERDR_APP_HOME/themes/phosphor-rain.json"
}
ok '--force replaces' case_force_replaces

case_missing_home() {
    new_env
    HERDR_APP_HOME=$T/nope
    export HERDR_APP_HOME
    run_install || :
    [ "$RC" -ne 0 ] && [ ! -e "$HERDR_APP_HOME" ]
}
ok 'missing herdr home fails' case_missing_home

case_incomplete_source() {
    new_env
    mkdir -p "$T/src"
    cp -R "$ROOT/phosphor-rain" "$T/src/phosphor-rain"
    rm "$T/src/phosphor-rain/themes/phosphor-rain.json"
    HM_SRC=$T/src
    export HM_SRC
    run_install || :
    [ "$RC" -ne 0 ] && [ ! -e "$HERDR_APP_HOME/layouts/phosphor-rain.json" ]
}
ok 'incomplete source fails before copying' case_incomplete_source

case_home_space() {
    new_env
    HERDR_APP_HOME="$T/my home"
    mkdir -p "$HERDR_APP_HOME"
    export HERDR_APP_HOME
    run_install
    [ "$RC" -eq 0 ] && payload_exists
}
ok 'home with a space works' case_home_space

case_programs_untouched() {
    new_env
    printf '{"x":1}' > "$HERDR_APP_HOME/programs.json"
    run_install
    [ "$RC" -eq 0 ] && printf '{"x":1}' > "$T/expected" && cmp "$T/expected" "$HERDR_APP_HOME/programs.json"
}
ok 'programs.json untouched' case_programs_untouched

case_tarball_download() {
    new_env
    unset HM_SRC
    mkdir -p "$T/herdrmatrix-main"
    cp -R "$ROOT/phosphor-rain" "$T/herdrmatrix-main/phosphor-rain"
    tar -czf "$T/r.tgz" -C "$T" herdrmatrix-main
    HM_TEST_TARBALL=$T/r.tgz
    export HM_TEST_TARBALL
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'while [ "$#" -gt 0 ]; do' '    if [ "$1" = -o ]; then shift; cat "$HM_TEST_TARBALL" > "$1"; exit 0; fi' '    shift' 'done' 'exit 1' > "$T/bin/curl"
    chmod +x "$T/bin/curl"
    run_install
    [ "$RC" -eq 0 ] && payload_exists
}
ok 'tarball download path works' case_tarball_download

case_curl_failure_does_not_copy() {
    new_env
    unset HM_SRC
    mkdir -p "$T/herdrmatrix-main"
    cp -R "$ROOT/phosphor-rain" "$T/herdrmatrix-main/phosphor-rain"
    tar -czf "$T/r.tgz" -C "$T" herdrmatrix-main
    HM_TEST_TARBALL=$T/r.tgz
    export HM_TEST_TARBALL
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'while [ "$#" -gt 0 ]; do' '    if [ "$1" = -o ]; then shift; cat "$HM_TEST_TARBALL" > "$1"; exit 22; fi' '    shift' 'done' 'cat "$HM_TEST_TARBALL"' 'exit 22' > "$T/bin/curl"
    chmod +x "$T/bin/curl"
    run_install || :
    [ "$RC" -ne 0 ] && [ ! -e "$HERDR_APP_HOME/layouts/phosphor-rain.json" ]
}
ok 'curl failure does not copy payload' case_curl_failure_does_not_copy

case_unsupported_os() {
    new_env
    printf '#!/bin/sh\nprintf "Plan9\\n"\n' > "$T/bin/uname"
    chmod +x "$T/bin/uname"
    run_install || :
    [ "$RC" -ne 0 ] && grep -qi unsupported "$OUT"
}
ok 'unsupported OS fails' case_unsupported_os

case_check_runs_for_both_mods() {
    new_env
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "$T/calls"' 'if [ "$1" = check ]; then exit "${HM_TEST_CHECK_RC:-0}"; fi' > "$T/bin/herdr-app"
    chmod +x "$T/bin/herdr-app"
    export T
    run_install
    [ "$RC" -eq 0 ] && grep -Fxq "check $HERDR_APP_HOME/mods/phosphor-rain" "$T/calls" && grep -Fxq "check $HERDR_APP_HOME/mods/phosphor-tabs" "$T/calls"
}
ok 'check runs for both mods' case_check_runs_for_both_mods

case_check_failure_is_named() {
    new_env
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "$T/calls"' 'if [ "$1" = check ]; then exit "${HM_TEST_CHECK_RC:-0}"; fi' > "$T/bin/herdr-app"
    chmod +x "$T/bin/herdr-app"
    export T HM_TEST_CHECK_RC=1
    run_install || :
    [ "$RC" -ne 0 ] && grep -q phosphor-rain "$OUT" && grep -q -- --uninstall "$OUT"
}
ok 'check failure is non-zero and named' case_check_failure_is_named

case_no_apply_suggests_activation() {
    new_env
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "$T/calls"' 'if [ "$1" = check ]; then exit "${HM_TEST_CHECK_RC:-0}"; fi' > "$T/bin/herdr-app"
    chmod +x "$T/bin/herdr-app"
    export T
    run_install
    [ "$RC" -eq 0 ] && ! grep -q layout.switch "$T/calls" && grep -q ctrl-shift-l "$OUT"
}
ok 'no --apply means no layout.switch' case_no_apply_suggests_activation

case_apply_switches_layout() {
    new_env
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "$T/calls"' 'if [ "$1" = check ]; then exit "${HM_TEST_CHECK_RC:-0}"; fi' > "$T/bin/herdr-app"
    chmod +x "$T/bin/herdr-app"
    export T
    run_install --apply
    [ "$RC" -eq 0 ] && grep -Fxq 'do layout.switch {"name":"phosphor-rain"}' "$T/calls"
}
ok '--apply switches layout' case_apply_switches_layout

case_switch_failure_is_friendly() {
    new_env
    HM_TEST_SWITCH_RC=1
    export HM_TEST_SWITCH_RC
    run_install --apply || :
    [ "$RC" -ne 0 ] && grep -q ctrl-shift-l "$OUT"
}
ok 'layout.switch failure suggests manual switch' case_switch_failure_is_friendly

case_apply_without_app_fails_early() {
    new_env
    mkdir "$T/limited-bin"
    for tool in sh tar cp rm mkdir mktemp uname cat printf grep cmp; do
        ln -s "$(command -v "$tool")" "$T/limited-bin/$tool"
    done
    set +e
    (cd "$ROOT" && env PATH="$T/limited-bin" /bin/sh install.sh --apply) >"$OUT" 2>&1
    RC=$?
    set -e
    [ "$RC" -ne 0 ] && grep -q 'herdr-app' "$OUT" && [ ! -e "$HERDR_APP_HOME/layouts/phosphor-rain.json" ]
}
ok '--apply without herdr-app fails early' case_apply_without_app_fails_early

case_uninstall_removes_only_payload() {
    new_env
    run_install || :
    mkdir -p "$HERDR_APP_HOME/mods/other"
    : > "$HERDR_APP_HOME/mods/other/x"
    : > "$HERDR_APP_HOME/programs.json"
    run_install --uninstall
    [ "$RC" -eq 0 ] && payload_absent && [ -e "$HERDR_APP_HOME/mods/other/x" ] && [ -e "$HERDR_APP_HOME/programs.json" ]
}
ok '--uninstall removes payload only' case_uninstall_removes_only_payload

case_unknown_option_fails() {
    new_env
    run_install --bogus || :
    [ "$RC" -ne 0 ] && grep -q 'unknown option' "$OUT"
}
ok 'unknown option fails' case_unknown_option_fails

case_programs_hint() {
    new_env
    run_install
    [ "$RC" -eq 0 ] && grep -q 'not modified' "$OUT"
}
ok 'output mentions programs.json hint' case_programs_hint

case_symlink_source_rejected() {
    new_env
    mkdir -p "$T/src" "$T/outside"
    : > "$T/outside/secret"
    cp -R "$ROOT/phosphor-rain" "$T/src/phosphor-rain"
    rm -rf "$T/src/phosphor-rain/mods/phosphor-tabs"
    ln -s "$T/outside" "$T/src/phosphor-rain/mods/phosphor-tabs"
    HM_SRC=$T/src
    export HM_SRC
    run_install || :
    [ "$RC" -ne 0 ] && grep -q symlink "$OUT" && payload_absent
}
ok 'symlink in source is rejected before copying' case_symlink_source_rejected

case_help_long() {
    new_env
    HERDR_APP_HOME=$T/nope
    export HERDR_APP_HOME
    run_install --help
    [ "$RC" -eq 0 ] && grep -q 'Usage:' "$OUT" && grep -Fq 'sh -s -- --apply' "$OUT" && [ ! -e "$HERDR_APP_HOME" ]
}
ok '--help exits 0 with usage, without a Herdr home' case_help_long

case_help_short() {
    new_env
    HERDR_APP_HOME=$T/nope
    export HERDR_APP_HOME
    run_install -h
    [ "$RC" -eq 0 ] && grep -q 'Usage:' "$OUT" && grep -Fq 'sh -s -- --apply' "$OUT" && [ ! -e "$HERDR_APP_HOME" ]
}
ok '-h exits 0 with usage, without a Herdr home' case_help_short

case_conflict_shows_hints() {
    new_env
    run_install
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    run_install || :
    [ "$RC" -ne 0 ] && grep -Fq 'sh -s -- --force' "$OUT" && grep -Fq 'sh install.sh --force' "$OUT"
}
ok 'conflict message shows copy-paste force commands' case_conflict_shows_hints

case_activate_hint_shows_apply() {
    new_env
    run_install
    [ "$RC" -eq 0 ] && grep -Fq 'sh -s -- --apply' "$OUT"
}
ok 'activate hint shows copy-paste apply command' case_activate_hint_shows_apply

case_unknown_option_suggests_help() {
    new_env
    run_install --bogus || :
    [ "$RC" -ne 0 ] && grep -Fq -- '--help' "$OUT"
}
ok 'unknown option suggests --help' case_unknown_option_suggests_help

case_conflict_no_apply_hint() {
    new_env
    run_install
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    run_install || :
    [ "$RC" -ne 0 ] && grep -Fq 'sh -s -- --force' "$OUT" && ! grep -Fq -- '--force --apply' "$OUT"
}
ok 'conflict without --apply does not suggest --apply' case_conflict_no_apply_hint

case_help_apply_examples() {
    new_env
    run_install --help
    [ "$RC" -eq 0 ] && grep -Fq 'sh -s -- --apply' "$OUT" && grep -Fq -- '--apply installs if needed' "$OUT"
}
ok '--help shows --force --apply examples' case_help_apply_examples

logging_stub() {
    # shellcheck disable=SC2016
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "$T/calls"' 'if [ "$1" = check ]; then exit "${HM_TEST_CHECK_RC:-0}"; fi' 'if [ "$1" = do ]; then exit "${HM_TEST_SWITCH_RC:-0}"; fi' 'exit 0' > "$T/bin/herdr-app"
    chmod +x "$T/bin/herdr-app"
}

case_apply_rerun_identical() {
    new_env
    run_install
    cp "$HERDR_APP_HOME/themes/phosphor-rain.json" "$T/before"
    logging_stub
    run_install --apply
    [ "$RC" -eq 0 ] && grep -Fq 'do layout.switch' "$T/calls" && grep -Fq 'up to date' "$OUT" && cmp -s "$T/before" "$HERDR_APP_HOME/themes/phosphor-rain.json"
}
ok '--apply on identical files switches without copying' case_apply_rerun_identical

case_apply_keeps_modified() {
    new_env
    run_install
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    logging_stub
    run_install --apply
    [ "$RC" -eq 0 ] && grep -Fq 'do layout.switch' "$T/calls" && grep -q '# mine' "$HERDR_APP_HOME/themes/phosphor-rain.json" && grep -Fq 'were kept' "$OUT"
}
ok '--apply keeps modified files and switches' case_apply_keeps_modified

case_noflag_lists_only_modified() {
    new_env
    run_install
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    run_install || :
    [ "$RC" -ne 0 ] && grep -Fxq '  themes/phosphor-rain.json' "$OUT" && ! grep -q 'layouts/phosphor-rain.json' "$OUT" && grep -Fq 'sh -s -- --force' "$OUT" && grep -q '# mine' "$HERDR_APP_HOME/themes/phosphor-rain.json"
}
ok 'no flags lists only the modified path' case_noflag_lists_only_modified

case_noflag_identical_up_to_date() {
    new_env
    run_install
    logging_stub
    run_install
    [ "$RC" -eq 0 ] && grep -Fq 'up to date' "$OUT" && grep -Fq 'sh -s -- --apply' "$OUT" && ! grep -Fq 'layout.switch' "$T/calls"
}
ok 'no flags on identical files reports up to date' case_noflag_identical_up_to_date

case_force_apply_replaces() {
    new_env
    run_install
    printf '# mine\n' >> "$HERDR_APP_HOME/themes/phosphor-rain.json"
    logging_stub
    run_install --force --apply
    [ "$RC" -eq 0 ] && ! grep -q '# mine' "$HERDR_APP_HOME/themes/phosphor-rain.json" && grep -Fq 'do layout.switch' "$T/calls"
}
ok '--force --apply replaces and switches' case_force_apply_replaces

printf '%s passed, %s failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
