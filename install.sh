#!/bin/sh
set -eu

PAYLOAD='layouts/phosphor-rain.json layouts/phosphor-rain.svg themes/phosphor-rain.json mods/phosphor-rain mods/phosphor-tabs'
HM_REPO=${HM_REPO:-gara501/herdrmatrix}
HM_REF=${HM_REF:-main}
HERDR_APP_HOME=${HERDR_APP_HOME:-$HOME/.config/herdr-app}
TMP_DIR=

say() {
    printf 'herdrmatrix: %s\n' "$1"
}

die() {
    printf 'herdrmatrix: %s\n' "$1" >&2
    exit 1
}

raw_url() {
    printf 'https://raw.githubusercontent.com/%s/%s/install.sh\n' "$HM_REPO" "$HM_REF"
}

usage() {
    url=$(raw_url)
    cat <<EOF
Usage: install.sh [--force] [--apply] [--uninstall] [--help]

Options:
  --force      Replace existing Phosphor Rain files.
  --apply      Switch to the phosphor-rain layout after installing.
  --uninstall  Remove the Phosphor Rain files.
  --help, -h   Show this help.

Run it piped from curl (flags go after "sh -s --"):
  curl -fsSL $url | sh -s -- --apply
Or from a downloaded copy:
  sh install.sh --apply

--apply installs if needed and switches to the layout; it never needs --force.
--force only replaces files you already have; combine it as --force --apply to update and switch.

Environment: HERDR_APP_HOME, HM_REF, HM_REPO, HM_SRC, HM_TARBALL_URL
EOF
}

run_hint() {
    url=$(raw_url)
    printf '  curl -fsSL %s | sh -s -- %s\n' "$url" "$1"
    printf '  sh install.sh %s\n' "$1"
}

detect_os() {
    case $(uname -s) in
        Linux) printf 'linux\n' ;;
        Darwin) printf 'macos\n' ;;
        *) die "unsupported operating system: $(uname -s)" ;;
    esac
}

cleanup() {
    if [ -n "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

fetch_source() {
    if [ -n "${HM_SRC:-}" ]; then
        FETCHED_SOURCE=$HM_SRC
        printf '%s\n' "$FETCHED_SOURCE"
        return
    fi

    TMP_DIR=$(mktemp -d) || die 'could not create temporary directory'
    trap cleanup EXIT
    url=${HM_TARBALL_URL:-}
    if [ -z "$url" ]; then
        url="https://codeload.github.com/$HM_REPO/tar.gz/$HM_REF"
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$TMP_DIR/src.tgz" </dev/null || die 'could not download source tarball'
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$TMP_DIR/src.tgz" "$url" </dev/null || die 'could not download source tarball'
    else
        die 'curl or wget is required to download the installer source'
    fi
    mkdir "$TMP_DIR/src"
    tar -xzf "$TMP_DIR/src.tgz" -C "$TMP_DIR/src" --strip-components=1 || die 'could not extract source tarball'
    FETCHED_SOURCE=$TMP_DIR/src
    printf '%s\n' "$FETCHED_SOURCE"
}

validate_source() {
    source_dir=$1
    links=$(find "$source_dir/phosphor-rain" -type l)
    if [ -n "$links" ]; then
        die "source contains a symlink: $(printf '%s\n' "$links" | head -n 1)"
    fi
    for path in $PAYLOAD; do
        [ -e "$source_dir/phosphor-rain/$path" ] || die "missing source payload: phosphor-rain/$path"
    done
}

find_conflicts() {
    for path in $PAYLOAD; do
        if [ -e "$HERDR_APP_HOME/$path" ]; then
            printf '%s\n' "$path"
        fi
    done
}

payload_differs() {
    for path in $PAYLOAD; do
        if [ -e "$HERDR_APP_HOME/$path" ] && ! diff -r "$HERDR_APP_HOME/$path" "$source_dir/phosphor-rain/$path" >/dev/null 2>&1; then
            printf '%s\n' "$path"
        fi
    done
}

copy_payload() {
    source_dir=$1
    for path in $PAYLOAD; do
        if [ "${FORCE:-0}" -eq 1 ]; then
            rm -rf "${HERDR_APP_HOME:?}/$path"
        fi
        parent=${path%/*}
        mkdir -p "$HERDR_APP_HOME/$parent"
        cp -R "$source_dir/phosphor-rain/$path" "$HERDR_APP_HOME/$path"
    done
}

run_checks() {
    if ! command -v herdr-app >/dev/null 2>&1; then
        say 'herdr-app not found; checks skipped'
        return
    fi
    for mod in phosphor-rain phosphor-tabs; do
        herdr-app check "$HERDR_APP_HOME/mods/$mod" </dev/null || die "check failed for $mod; files stay installed, run with --uninstall to remove"
    done
}

apply_layout() {
    herdr-app 'do' layout.switch '{"name":"phosphor-rain"}' </dev/null || die 'layout.switch failed; files stay installed, switch manually with ctrl-shift-l'
}

uninstall() {
    for path in $PAYLOAD; do
        rm -rf "${HERDR_APP_HOME:?}/$path"
    done
    say 'uninstalled Phosphor Rain payload'
}

main() {
    FORCE=0
    APPLY=0
    UNINSTALL=0
    while [ "$#" -gt 0 ]; do
        case $1 in
            --force) FORCE=1 ;;
            --apply) APPLY=1 ;;
            --uninstall) UNINSTALL=1 ;;
            --help|-h) usage; exit 0 ;;
            *) die "unknown option: $1 (try --help)" ;;
        esac
        shift
    done

    detect_os >/dev/null
    [ -d "$HERDR_APP_HOME" ] || die "Herdr home not found: $HERDR_APP_HOME. Start Herdr Desktop once, then retry."
    if [ "$UNINSTALL" -eq 1 ]; then
        uninstall
        return
    fi
    if [ "$APPLY" -eq 1 ] && ! command -v herdr-app >/dev/null 2>&1; then
        die 'herdr-app is required for --apply'
    fi
    fetch_source >/dev/null
    source_dir=$FETCHED_SOURCE
    validate_source "$source_dir"
    conflicts=$(find_conflicts)
    if [ -z "$conflicts" ] || [ "$FORCE" -eq 1 ]; then
        copy_payload "$source_dir"
        say 'installed Phosphor Rain payload'
    else
        differing=$(payload_differs)
        if [ -z "$differing" ]; then
            say 'already installed and up to date'
        elif [ "$APPLY" -eq 0 ]; then
            differing_lines=$(printf '%s\n' "$differing" | sed 's/^/  /')
            hints=$(run_hint --force)
            die "installed files differ from this version (nothing changed):
$differing_lines
to replace them, run one of:
$hints"
        else
            say 'installed files differ from this version and were kept; add --force to replace them'
        fi
    fi
    run_checks
    if [ "$APPLY" -eq 1 ]; then
        apply_layout
    else
        say 'Activate: press ctrl-shift-l and choose phosphor-rain, or run again with --apply'
        run_hint --apply
    fi
    say 'Optional: merge phosphor-rain/programs.json into your programs.json for agent icons (not modified).'
}

if [ -z "${HM_SOURCED:-}" ]; then
    main "$@"
fi
