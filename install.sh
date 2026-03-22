#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║          fastfetch · Yozakura Config Installer               ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colours (tput — degrades gracefully on dumb terminals) ──────
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    RESET="$(tput sgr0)"
    BOLD="$(tput bold)"
    DIM="$(tput dim 2>/dev/null || printf '')"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
    WHITE="$(tput setaf 7)"
else
    RESET="" BOLD="" DIM=""
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
fi

# ── Helpers ─────────────────────────────────────────────────────
info()    { printf "${CYAN}  ${BOLD}::${RESET}${WHITE} %s${RESET}\n"    "$*"; }
success() { printf "${GREEN}  ${BOLD}✓${RESET}${WHITE}  %s${RESET}\n"   "$*"; }
warn()    { printf "${YELLOW}  ${BOLD}⚠${RESET}${YELLOW}  %s${RESET}\n" "$*"; }
error()   { printf "${RED}  ${BOLD}✗${RESET}${RED}  %s${RESET}\n"       "$*" >&2; }
step()    { printf "\n${MAGENTA}${BOLD}▸ %s${RESET}\n"                  "$*"; }
dim()     { printf "${DIM}     %s${RESET}\n"                            "$*"; }

ask() {
    # ask <prompt> → returns 0 (yes) or 1 (no)
    local prompt="$1"
    while true; do
        printf "${BLUE}  ${BOLD}?${RESET}${WHITE}  %s ${DIM}[y/N]${RESET} " "$prompt"
        read -r answer </dev/tty
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no|"") return 1 ;;
            *) warn "Please answer y or n." ;;
        esac
    done
}

banner() {
    printf "\n"
    printf "${MAGENTA}${BOLD}"
    printf "  ╭──────────────────────────────────────────╮\n"
    printf "  │   🌸  fastfetch · Yozakura Installer  🌸 │\n"
    printf "  ╰──────────────────────────────────────────╯\n"
    printf "${RESET}\n"
}

# ── Resolve script location ─────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FASTFETCH_CFG_DIR="${HOME}/.config/fastfetch"
SCRIPTS_SRC="${SCRIPT_DIR}/scripts"
LOGO_SWITCHER_SRC="${SCRIPTS_SRC}/fastfetch-logo-switcher.sh"
LOGO_SWITCHER_DEST="${FASTFETCH_CFG_DIR}/scripts/fastfetch-logo-switcher.sh"

# ═══════════════════════════════════════════════════════════════
banner

# ── Step 1 · Prepare destination directory ──────────────────────
step "Preparing ~/.config/fastfetch"

mkdir -p "${FASTFETCH_CFG_DIR}"
success "Ensured ${FASTFETCH_CFG_DIR} exists"

# Backup existing config.jsonc
if [[ -f "${FASTFETCH_CFG_DIR}/config.jsonc" ]]; then
    cp "${FASTFETCH_CFG_DIR}/config.jsonc" "${FASTFETCH_CFG_DIR}/config.jsonc.bak"
    warn "Existing config.jsonc backed up → config.jsonc.bak"
fi

# ── Step 2 · Copy files (everything except scripts/) ─────────────
step "Installing config files & logos"

# Copy all items from SCRIPT_DIR, skipping the scripts/ subfolder and this installer
THIS_SCRIPT="$(basename "${BASH_SOURCE[0]}")"
for item in "${SCRIPT_DIR}"/*; do
    base="$(basename "$item")"
    [[ "$base" == "scripts" ]]     && continue
    [[ "$base" == "$THIS_SCRIPT" ]] && continue

    if [[ -d "$item" ]]; then
        cp -r "$item" "${FASTFETCH_CFG_DIR}/"
        success "Copied directory: ${base}/"
    elif [[ -f "$item" ]]; then
        cp "$item" "${FASTFETCH_CFG_DIR}/"
        success "Copied file:      ${base}"
    fi
done

# ── Step 3 · Install logo-switcher script ───────────────────────
step "Installing scripts"

mkdir -p "${FASTFETCH_CFG_DIR}/scripts"

if [[ -f "${LOGO_SWITCHER_SRC}" ]]; then
    cp "${LOGO_SWITCHER_SRC}" "${LOGO_SWITCHER_DEST}"
    chmod +x "${LOGO_SWITCHER_DEST}"
    success "Installed & made executable: scripts/fastfetch-logo-switcher.sh"
else
    warn "scripts/fastfetch-logo-switcher.sh not found in source — skipping"
fi

# ── Step 4 · Shell integration ───────────────────────────────────
step "Shell integration"

detect_shell_rc() {
    local shell_name
    shell_name="$(basename "${SHELL:-}")"
    case "$shell_name" in
        bash)  echo "${HOME}/.bashrc" ;;
        zsh)   echo "${HOME}/.zshrc"  ;;
        fish)  echo "${HOME}/.config/fish/config.fish" ;;
        ksh)   echo "${HOME}/.kshrc"  ;;
        *)
            if   [[ -f "${HOME}/.zshrc" ]];   then echo "${HOME}/.zshrc"
            elif [[ -f "${HOME}/.bashrc" ]];   then echo "${HOME}/.bashrc"
            else echo "${HOME}/.profile"
            fi
            ;;
    esac
}

SHELL_RC="$(detect_shell_rc)"
SHELL_NAME="$(basename "${SHELL_RC}")"

info "Detected shell config: ${SHELL_RC}"

FASTFETCH_LINE="fastfetch"
SWITCHER_LINE="${LOGO_SWITCHER_DEST}"

fastfetch_already_present() {
    grep -qxF "${FASTFETCH_LINE}" "${SHELL_RC}" 2>/dev/null
}

if fastfetch_already_present; then
    info "fastfetch is already in ${SHELL_NAME} — skipping shell edit"
else
    if ask "Add fastfetch + logo-switcher to ${SHELL_RC}?"; then
        {
            printf '\n# ── fastfetch (added by Yozakura installer) ──\n'
            printf '%s\n' "${FASTFETCH_LINE}"
            if [[ -f "${LOGO_SWITCHER_DEST}" ]]; then
                printf '%s\n' "${SWITCHER_LINE}"
            fi
        } >> "${SHELL_RC}"
        success "Added fastfetch block to ${SHELL_RC}"
        [[ -f "${LOGO_SWITCHER_DEST}" ]] && \
            dim "fastfetch  →  ${LOGO_SWITCHER_DEST}"
    else
        info "Skipped shell integration"
    fi
fi

# ── Step 5 · Kitty Terminal ──────────────────────────────────────
step "Kitty Terminal (GIF logo support)"

is_installed() { command -v "$1" &>/dev/null; }

kitty_version_tag() {
    # Returns "git", "stable", or "none"
    # Ask the package manager first — version strings don't encode this.

    # pacman-family (covers kitty-git from AUR)
    if command -v pacman &>/dev/null; then
        if pacman -Qi kitty-git &>/dev/null 2>&1; then echo "git"; return; fi
        if pacman -Qi kitty    &>/dev/null 2>&1; then echo "stable"; return; fi
    fi

    # Homebrew HEAD tap
    if command -v brew &>/dev/null; then
        local bv
        bv="$(brew list --versions kitty 2>/dev/null || true)"
        if [[ "$bv" == *HEAD* ]]; then echo "git"; return; fi
        if [[ -n "$bv" ]];        then echo "stable"; return; fi
    fi

    # All other package managers: just check whether the binary exists
    if is_installed kitty; then echo "stable"; return; fi
    echo "none"
}

KITTY_STATUS="$(kitty_version_tag)"

# Handle already-installed cases
if [[ "$KITTY_STATUS" == "git" ]]; then
    success "kitty-git is already installed — GIF support ready"
    printf "\n${MAGENTA}${BOLD}  ╭──────────────────────────────────────────╮${RESET}\n"
    printf "${MAGENTA}${BOLD}  │${RESET}${GREEN}${BOLD}   ✓  Installation complete! 🌸           ${MAGENTA}${BOLD}│${RESET}\n"
    printf "${MAGENTA}${BOLD}  ╰──────────────────────────────────────────╯${RESET}\n\n"
    info "Restart your shell or run:  source ${SHELL_RC}"
    printf "\n"
    exit 0
fi

if [[ "$KITTY_STATUS" == "stable" ]]; then
    warn "kitty (stable) is installed, but kitty-git is preferred for GIF logos"
    if ! ask "Attempt to upgrade to kitty-git?"; then
        info "Keeping stable kitty — GIF logos may not work correctly"
        printf "\n${MAGENTA}${BOLD}  ╭──────────────────────────────────────────╮${RESET}\n"
        printf "${MAGENTA}${BOLD}  │${RESET}${GREEN}${BOLD}   ✓  Installation complete! 🌸           ${MAGENTA}${BOLD}│${RESET}\n"
        printf "${MAGENTA}${BOLD}  ╰──────────────────────────────────────────╯${RESET}\n\n"
        info "Restart your shell or run:  source ${SHELL_RC}"
        printf "\n"
        exit 0
    fi
    # Fall through to install logic
    KITTY_STATUS="none"
fi

# KITTY_STATUS == "none" at this point
if ! ask "Install Kitty Terminal for proper GIF logo support?"; then
    info "Skipped Kitty installation"
    printf "\n${MAGENTA}${BOLD}  ╭──────────────────────────────────────────╮${RESET}\n"
    printf "${MAGENTA}${BOLD}  │${RESET}${GREEN}${BOLD}   ✓  Installation complete! 🌸           ${MAGENTA}${BOLD}│${RESET}\n"
    printf "${MAGENTA}${BOLD}  ╰──────────────────────────────────────────╯${RESET}\n\n"
    info "Restart your shell or run:  source ${SHELL_RC}"
    printf "\n"
    exit 0
fi

# ── OS / package-manager detection ──────────────────────────────
PM="unknown"
PM_INSTALL=""

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
fi

# Order matters: prefer AUR helpers on Arch-family distros
if   command -v paru        &>/dev/null; then PM="paru";    PM_INSTALL="paru -S --needed --noconfirm"
elif command -v yay         &>/dev/null; then PM="yay";     PM_INSTALL="yay -S --needed --noconfirm"
elif command -v pacman      &>/dev/null; then PM="pacman";  PM_INSTALL="sudo pacman -S --needed --noconfirm"
elif command -v apt-get     &>/dev/null; then PM="apt";     PM_INSTALL="sudo apt-get install -y"
elif command -v dnf         &>/dev/null; then PM="dnf";     PM_INSTALL="sudo dnf install -y"
elif command -v zypper      &>/dev/null; then PM="zypper";  PM_INSTALL="sudo zypper install -y"
elif command -v xbps-install &>/dev/null; then PM="xbps";  PM_INSTALL="sudo xbps-install -y"
elif command -v apk         &>/dev/null; then PM="apk";     PM_INSTALL="sudo apk add"
elif command -v emerge      &>/dev/null; then PM="portage"; PM_INSTALL="sudo emerge --ask n"
elif command -v nix-env     &>/dev/null; then PM="nix";     PM_INSTALL="nix-env -iA nixpkgs"
elif command -v brew        &>/dev/null; then PM="brew";    PM_INSTALL="brew install"
fi

info "Package manager detected: ${PM}"

if [[ "$PM" == "unknown" ]]; then
    error "No supported package manager found"
    error "Please install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
else
    case "$PM" in
        paru|yay)
            info "Trying kitty-git from AUR via ${PM}…"
            if ${PM_INSTALL} kitty-git 2>/dev/null; then
                success "kitty-git installed via ${PM}"
            else
                warn "kitty-git failed — falling back to stable kitty"
                if ${PM_INSTALL} kitty 2>/dev/null; then
                    success "kitty (stable) installed"
                    warn "GIF logos may not render correctly on stable kitty"
                else
                    error "kitty installation failed"
                    error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
                fi
            fi
            ;;

        pacman)
            warn "kitty-git requires an AUR helper (yay / paru) — falling back to kitty (stable)"
            if sudo pacman -S --needed --noconfirm kitty 2>/dev/null; then
                success "kitty (stable) installed"
                warn "GIF logos may not render correctly on stable kitty"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        apt)
            info "Installing kitty via apt…"
            if sudo apt-get install -y kitty 2>/dev/null; then
                success "kitty installed"
                warn "kitty-git is unavailable on Debian/Ubuntu; GIF logos may not render correctly"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        dnf)
            info "Installing kitty via dnf…"
            if sudo dnf install -y kitty 2>/dev/null; then
                success "kitty installed"
                warn "kitty-git is unavailable on Fedora; GIF logos may not render correctly"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        zypper)
            info "Installing kitty via zypper…"
            if sudo zypper install -y kitty 2>/dev/null; then
                success "kitty installed"
                warn "kitty-git is unavailable on openSUSE; GIF logos may not render correctly"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        xbps)
            info "Installing kitty via xbps-install (Void Linux)…"
            if sudo xbps-install -y kitty 2>/dev/null; then
                success "kitty installed"
                warn "kitty-git is unavailable on Void Linux; GIF logos may not render correctly"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        apk)
            info "Installing kitty via apk (Alpine)…"
            if sudo apk add kitty 2>/dev/null; then
                success "kitty installed"
                warn "kitty-git is unavailable on Alpine; GIF logos may not render correctly"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        portage)
            info "Installing kitty via emerge (Gentoo)…"
            if sudo emerge --ask n x11-terms/kitty 2>/dev/null; then
                success "kitty installed"
                warn "A live kitty-git ebuild may be available in overlays; GIF logos may not render correctly on stable"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        nix)
            info "Installing kitty via nix-env…"
            if nix-env -iA nixpkgs.kitty 2>/dev/null; then
                success "kitty installed"
                warn "kitty-git is not separately packaged in nixpkgs; GIF logos may not render correctly"
            else
                error "kitty installation failed"
                error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
            fi
            ;;

        brew)
            info "Trying kitty --HEAD (kitty-git equivalent) via Homebrew…"
            if brew install --HEAD kovidgoyal/brew/kitty 2>/dev/null || \
               brew install --HEAD kitty 2>/dev/null; then
                success "kitty (HEAD / git build) installed"
            else
                warn "HEAD build failed — falling back to stable kitty"
                if brew install kitty 2>/dev/null; then
                    success "kitty (stable) installed"
                    warn "GIF logos may not render correctly on stable kitty"
                else
                    error "kitty installation failed"
                    error "GIF logos may not work properly — install Kitty manually: https://sw.kovidgoyal.net/kitty/binary/"
                fi
            fi
            ;;
    esac
fi

# ── Done ─────────────────────────────────────────────────────────
printf "\n${MAGENTA}${BOLD}  ╭──────────────────────────────────────────╮${RESET}\n"
printf "${MAGENTA}${BOLD}  │${RESET}${GREEN}${BOLD}   ✓  Installation complete! 🌸           ${MAGENTA}${BOLD}│${RESET}\n"
printf "${MAGENTA}${BOLD}  ╰──────────────────────────────────────────╯${RESET}\n\n"
info "Restart your shell or run:  source ${SHELL_RC}"
printf "\n"