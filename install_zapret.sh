#!/bin/sh
#
# Zapret Easy Installer for Linux, OpenWrt and macOS
# https://github.com/gorlev/zapret-easy-installer
#
# Downloads the latest official release of zapret or zapret2
# (https://github.com/bol-van), verifies the bundled binaries against the
# release's sha256sum.txt and runs the official interactive installer
# (install_easy.sh).
#
# Usage:
#   U=https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh
#   sh -c "$(curl -fsSL $U 2>/dev/null || wget -qO- $U)"
#   sh install_zapret.sh [--flavor 1|2] [--version TAG] [--blockcheck|--no-blockcheck] [--keep-files]
#
# Environment variables (same meaning as the flags):
#   ZAPRET_FLAVOR=1|2  ZAPRET_VERSION=TAG  ZAPRET_BLOCKCHECK=1|0  ZAPRET_KEEP_FILES=1
#

INSTALLER_URL="https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh"
INSTALLER_NAME="zapret-easy-installer"

FLAVOR="${ZAPRET_FLAVOR:-}"
VERSION="${ZAPRET_VERSION:-}"
BLOCKCHECK="${ZAPRET_BLOCKCHECK:-}"
KEEP_FILES="${ZAPRET_KEEP_FILES:-0}"
WORK_DIR=""

########################################
# Output helpers
########################################
if [ -t 1 ]; then
    C_RED="$(printf '\033[31m')"; C_GRN="$(printf '\033[32m')"
    C_YLW="$(printf '\033[33m')"; C_CYN="$(printf '\033[36m')"
    C_BLD="$(printf '\033[1m')";  C_RST="$(printf '\033[0m')"
else
    C_RED=""; C_GRN=""; C_YLW=""; C_CYN=""; C_BLD=""; C_RST=""
fi

info()  { printf '%s==>%s %s\n' "$C_CYN" "$C_RST" "$*"; }
ok()    { printf '%s[OK]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn()  { printf '%s[WARN]%s %s\n' "$C_YLW" "$C_RST" "$*" >&2; }
die()   { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Zapret Easy Installer

Usage: sh install_zapret.sh [options]

Options:
  --flavor 1|2       1 = zapret (stable, recommended), 2 = zapret2 (Lua based, advanced)
  --version TAG      install a specific release tag (e.g. v72.13) instead of the latest
  --blockcheck       run blockcheck before installing (find a working strategy)
  --no-blockcheck    skip the blockcheck question
  --keep-files       keep the downloaded files in the temporary directory
  -h, --help         show this help

Environment: ZAPRET_FLAVOR, ZAPRET_VERSION, ZAPRET_BLOCKCHECK, ZAPRET_KEEP_FILES
EOF
}

########################################
# Arguments
########################################
while [ $# -gt 0 ]; do
    case "$1" in
        --flavor)        [ $# -ge 2 ] || die "--flavor needs a value (1 or 2)"; FLAVOR="$2"; shift 2 ;;
        --flavor=*)      FLAVOR="${1#*=}"; shift ;;
        --version)       [ $# -ge 2 ] || die "--version needs a value"; VERSION="$2"; shift 2 ;;
        --version=*)     VERSION="${1#*=}"; shift ;;
        --blockcheck)    BLOCKCHECK=1; shift ;;
        --no-blockcheck) BLOCKCHECK=0; shift ;;
        --keep-files)    KEEP_FILES=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        *)               warn "Unknown option: $1"; usage; exit 1 ;;
    esac
done

case "$FLAVOR" in
    ""|1|2) ;;
    zapret)  FLAVOR=1 ;;
    zapret2) FLAVOR=2 ;;
    *) die "Invalid flavor '$FLAVOR'. Use 1 (zapret) or 2 (zapret2)." ;;
esac

########################################
# Interactive input (works even when stdin is a pipe)
########################################
TTY=""
if [ -t 0 ]; then
    TTY="/dev/stdin"
elif (: </dev/tty) 2>/dev/null; then
    TTY="/dev/tty"
fi

# ask "question" default(Y|N) -> returns 0 for yes
ask() {
    _q="$1"; _def="$2"
    if [ -z "$TTY" ]; then
        [ "$_def" = "Y" ]; return
    fi
    if [ "$_def" = "Y" ]; then _hint="[Y/n]"; else _hint="[y/N]"; fi
    printf '%s %s ' "$_q" "$_hint"
    read -r _ans <"$TTY" || _ans=""
    case "$_ans" in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *)     [ "$_def" = "Y" ] ;;
    esac
}

is_openwrt() {
    [ -f /etc/openwrt_release ] || grep -q 'OpenWrt' /etc/os-release 2>/dev/null
}

########################################
# 1) Root privileges
########################################
if [ "$(id -u 2>/dev/null)" != "0" ]; then
    if is_openwrt; then
        die "Please run this script as root on OpenWrt."
    fi
    command -v sudo >/dev/null 2>&1 || die "This script needs root privileges and sudo was not found. Run it as root."

    # Forward the chosen options to the elevated copy.
    set --
    [ -n "$FLAVOR" ]     && set -- "$@" --flavor "$FLAVOR"
    [ -n "$VERSION" ]    && set -- "$@" --version "$VERSION"
    [ "$BLOCKCHECK" = 1 ] && set -- "$@" --blockcheck
    [ "$BLOCKCHECK" = 0 ] && set -- "$@" --no-blockcheck
    [ "$KEEP_FILES" = 1 ] && set -- "$@" --keep-files

    info "Root privileges are required. Re-running with sudo..."
    if [ -f "$0" ] && grep -q "$INSTALLER_NAME" "$0" 2>/dev/null; then
        # Started from a local file: re-run that same file.
        exec sudo sh "$0" "$@"
    fi
    # Started via sh -c "$(curl ...)": fetch the installer again for the root shell.
    if command -v curl >/dev/null 2>&1; then
        _self="$(curl -fsSL "$INSTALLER_URL")" || die "Could not download the installer."
    elif command -v wget >/dev/null 2>&1; then
        _self="$(wget -qO- "$INSTALLER_URL")" || die "Could not download the installer."
    else
        die "Neither curl nor wget is available."
    fi
    exec sudo sh -c "$_self" "$INSTALLER_NAME" "$@"
fi

cat <<'EOF'
 ______                    _     _____
|___  /                   | |   |  ___|
   / / __ _ _ __  _ __ ___| |_  | |__  __ _ ___ _   _
  / / / _` | '_ \| '__/ _ \ __| |  __|/ _` / __| | | |
./ /_| (_| | |_) | | |  __/ |_  | |__| (_| \__ \ |_| |
\_____\__,_| .__/|_|  \___|\__| \____/\__,_|___/\__, |
           | |                                   __/ |
           |_|          Easy Installer          |___/
EOF
echo "https://github.com/gorlev/zapret-easy-installer"
echo

########################################
# 2) Detect the system
########################################
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
PLATFORM=""

if is_openwrt; then
    PLATFORM="openwrt"
elif [ "$OS" = "linux" ]; then
    PLATFORM="linux"
elif [ "$OS" = "darwin" ]; then
    PLATFORM="macos"
else
    case "$OS" in
        mingw*|msys*|cygwin*)
            die "Windows detected. Please use install_zapret.bat or install_zapret.ps1 instead." ;;
        *)
            die "Unsupported system: $OS. zapret's easy installer supports Linux, OpenWrt and macOS." ;;
    esac
fi

info "Detected system: $PLATFORM ($ARCH)"

########################################
# 3) Downloader (curl or wget)
########################################
install_curl() {
    warn "Neither curl nor wget was found. Trying to install curl..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y curl
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm curl
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install curl
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache curl
    elif command -v opkg >/dev/null 2>&1; then
        opkg update && opkg install curl
    fi
    command -v curl >/dev/null 2>&1 || die "Could not install curl. Please install curl (or wget) manually and try again."
    ok "curl installed."
}

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    install_curl
fi

# fetch URL -> stdout
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 "$1"
    else
        wget -qO- "$1"
    fi
}

# download URL FILE
download() {
    if command -v curl >/dev/null 2>&1; then
        if [ -t 2 ]; then
            curl -fSL --retry 3 --progress-bar -o "$2" "$1"
        else
            curl -fsSL --retry 3 -o "$2" "$1"
        fi
    else
        wget -q -O "$2" "$1"
    fi
}

########################################
# 4) Choose zapret or zapret2
########################################
if [ "$PLATFORM" = "macos" ]; then
    if [ "$FLAVOR" = "2" ]; then
        warn "zapret2 does not support macOS. Installing zapret (v1) instead."
    fi
    FLAVOR=1
fi

if [ -z "$FLAVOR" ]; then
    echo
    printf '%sWhich version do you want to install?%s\n' "$C_BLD" "$C_RST"
    echo "  1) zapret   - stable and mature, best choice for most users (recommended)"
    echo "  2) zapret2  - next generation, strategies are Lua scripts; for advanced users"
    echo
    if [ -n "$TTY" ]; then
        printf 'Enter choice [1]: '
        read -r _choice <"$TTY" || _choice=""
    else
        _choice=""
    fi
    case "$_choice" in
        2) FLAVOR=2 ;;
        ""|1) FLAVOR=1 ;;
        *) die "Invalid choice: $_choice" ;;
    esac
fi

if [ "$FLAVOR" = "2" ]; then
    PROJECT="zapret2"
    OTHER_PROJECT="zapret"
    BLOCKCHECK_SCRIPT="blockcheck2.sh"
else
    PROJECT="zapret"
    OTHER_PROJECT="zapret2"
    BLOCKCHECK_SCRIPT="blockcheck.sh"
fi
REPO="bol-van/$PROJECT"
info "Selected: $PROJECT (https://github.com/$REPO)"

if [ -x "/opt/$OTHER_PROJECT/uninstall_easy.sh" ]; then
    echo
    warn "$OTHER_PROJECT is already installed in /opt/$OTHER_PROJECT."
    warn "Running zapret and zapret2 at the same time makes their firewall rules conflict."
    if ask "Uninstall $OTHER_PROJECT first?" N; then
        /opt/"$OTHER_PROJECT"/uninstall_easy.sh <"${TTY:-/dev/null}" || warn "Uninstalling $OTHER_PROJECT failed. Continuing anyway."
    fi
fi

########################################
# 5) Resolve the release tag
########################################
if [ -z "$VERSION" ]; then
    info "Looking up the latest $PROJECT release..."
    _json="$(fetch "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null)"
    VERSION="$(printf '%s\n' "$_json" | grep '"tag_name"' | head -n1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"

    if [ -z "$VERSION" ] && command -v curl >/dev/null 2>&1; then
        # API unavailable or rate limited: follow the /releases/latest redirect instead.
        _url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null)"
        case "$_url" in
            */releases/tag/*) VERSION="${_url##*/}" ;;
        esac
    fi
    [ -n "$VERSION" ] || die "Could not determine the latest release. Check your connection or pass --version TAG."
fi

case "$VERSION" in
    *[!A-Za-z0-9._-]*) die "Invalid version tag: $VERSION" ;;
esac
ok "Release: $PROJECT $VERSION"

if [ "$PLATFORM" = "openwrt" ]; then
    ASSET="$PROJECT-$VERSION-openwrt-embedded.tar.gz"
else
    ASSET="$PROJECT-$VERSION.tar.gz"
fi
BASE_URL="https://github.com/$REPO/releases/download/$VERSION"

########################################
# 6) Download
########################################
cleanup() {
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        if [ "$KEEP_FILES" = "1" ]; then
            info "Downloaded files kept in $WORK_DIR"
        else
            cd / && rm -rf "$WORK_DIR"
        fi
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/zapret-installer.XXXXXX")" || die "Could not create a temporary directory."
cd "$WORK_DIR" || die "Could not enter $WORK_DIR"

info "Downloading $ASSET..."
download "$BASE_URL/$ASSET" "$ASSET" || die "Download failed: $BASE_URL/$ASSET"

HAVE_SUMS=0
if download "$BASE_URL/sha256sum.txt" sha256sum.txt 2>/dev/null; then
    HAVE_SUMS=1
else
    warn "sha256sum.txt is not available for this release. Binaries cannot be verified."
fi

########################################
# 7) Extract
########################################
info "Extracting..."
tar -xzf "$ASSET" || die "Could not extract $ASSET"

SRC_DIR="$WORK_DIR/$PROJECT-$VERSION"
[ -f "$SRC_DIR/install_easy.sh" ] || die "Unexpected archive layout: $SRC_DIR/install_easy.sh not found."

########################################
# 8) Verify binaries
########################################
# sha256sum.txt lists the binaries inside the archive (not the archive itself),
# e.g. "<hash>  zapret-v72.13/binaries/linux-x86_64/nfqws".
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d ' ' -f 1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d ' ' -f 1
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$1" | sed 's/.*= *//'
    fi
}

if [ "$HAVE_SUMS" = "1" ]; then
    if [ -z "$(sha256_of sha256sum.txt)" ]; then
        warn "No SHA-256 tool (sha256sum, shasum or openssl) found. Skipping verification."
    else
        info "Verifying binaries against sha256sum.txt..."
        _checked=0; _failed=0
        while read -r _hash _path; do
            [ -n "$_hash" ] && [ -n "$_path" ] || continue
            _path="${_path#\*}"
            case "$_path" in
                "$PROJECT-$VERSION"/*) ;;
                *) continue ;;
            esac
            [ -f "$_path" ] || continue   # the OpenWrt package ships only a subset
            if [ "$(sha256_of "$_path")" = "$_hash" ]; then
                _checked=$((_checked + 1))
            else
                warn "Checksum mismatch: $_path"
                _failed=$((_failed + 1))
            fi
        done < sha256sum.txt

        if [ "$_failed" -gt 0 ]; then
            die "$_failed binaries failed verification. The download may be corrupted or tampered with. Aborting."
        elif [ "$_checked" -eq 0 ]; then
            warn "No binaries could be matched against sha256sum.txt."
        else
            ok "$_checked binaries verified."
        fi
    fi
fi

########################################
# 9) Prepare binaries and (optionally) run blockcheck
########################################
cd "$SRC_DIR" || die "Could not enter $SRC_DIR"

info "Installing binaries for this architecture (install_bin.sh)..."
sh ./install_bin.sh || die "install_bin.sh failed. Your architecture may not be supported by the prebuilt binaries."

if [ -f "./$BLOCKCHECK_SCRIPT" ]; then
    if [ -z "$BLOCKCHECK" ]; then
        echo
        echo "blockcheck tests your connection and finds DPI bypass strategies that work with your ISP."
        echo "Recommended on first install: you can enter the strategy it finds when the installer asks"
        echo "\"do you want to edit the options\". It can take a while. Stop other DPI bypass tools first."
        if ask "Run blockcheck now?" N; then BLOCKCHECK=1; else BLOCKCHECK=0; fi
    fi
    if [ "$BLOCKCHECK" = "1" ]; then
        info "Running $BLOCKCHECK_SCRIPT..."
        sh "./$BLOCKCHECK_SCRIPT" <"${TTY:-/dev/null}" || warn "blockcheck exited with an error."
        echo
        if [ -n "$TTY" ]; then
            printf 'Note the working strategy above, then press Enter to continue with the installation...'
            read -r _dummy <"$TTY" || true
        fi
    fi
fi

########################################
# 10) Official installer
########################################
echo
info "Starting the official installer (install_easy.sh)."
info "Answer \"Y\" when it offers to copy itself to /opt/$PROJECT."
echo
if [ -n "$TTY" ]; then
    sh ./install_easy.sh <"$TTY"
else
    sh ./install_easy.sh
fi
RC=$?

echo
if [ $RC -ne 0 ] || [ ! -f "/opt/$PROJECT/install_easy.sh" ]; then
    die "The installation was not completed (install_easy.sh exit code $RC). Run the installer again to retry."
fi

ok "$PROJECT $VERSION is installed in /opt/$PROJECT"
cat <<EOF

Next steps:
  Find a working strategy : /opt/$PROJECT/$BLOCKCHECK_SCRIPT
  Edit the configuration  : /opt/$PROJECT/config   (then re-run /opt/$PROJECT/install_easy.sh)
  Uninstall               : /opt/$PROJECT/uninstall_easy.sh

Documentation: https://github.com/$REPO
EOF
