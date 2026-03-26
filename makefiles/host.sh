#!/usr/bin/env bash
## ════════════════════════════════════════════════════════════════
##  Managing the hosts file (Linux / macOS / Windows WSL)
## ════════════════════════════════════════════════════════════════
set -euo pipefail

HOSTNAME="${1:-}"
ACTION="${2:--add}"
IP="127.0.0.1"
ENTRY="${IP} ${HOSTNAME}"

RESET='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'

success() { printf "${GREEN}✅ %b${RESET}\n" "$1"; }
warning() { printf "${YELLOW}⚠️ %b${RESET}\n" "$1"; }
info()    { printf "${CYAN}ℹ️ %b${RESET}\n" "$1"; }
error()   { printf "${RED}❌ %b${RESET}\n" "$1"; }

[ -z "$HOSTNAME" ] && info "Usage : $0 <hostname> [--add|--remove]" && exit 0

# ── OS Detection ─────────────────────────────────────────────────
detect_os() {
    case "$(uname -s)" in
        Linux*)
            # WSL detection
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "mac"   ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

OS=$(detect_os)
info "Système détecté : ${BOLD}${OS}${RESET}."

# ── Determine the hosts file path ───────────────────────────────
case "$OS" in
    linux|mac)
        HOSTS_FILE="/etc/hosts"
        ;;
    wsl)
        # On WSL, modify the two hosts files
        HOSTS_FILE="/etc/hosts"
        WIN_HOSTS="/mnt/c/Windows/System32/drivers/etc/hosts"
        ;;
    windows)
        HOSTS_FILE="/c/Windows/System32/drivers/etc/hosts"
        ;;
    *)
        warning "OS non reconnu, tentative avec /etc/hosts."
        HOSTS_FILE="/etc/hosts"
        ;;
esac

# ── Manipulation functions ───────────────────────────────────────
hosts_has_entry() {
    local file="$1"
    grep -qF "$HOSTNAME" "$file" 2>/dev/null
}

hosts_add_entry() {
    local file="$1"
    if hosts_has_entry "$file"; then
        warning "L'entrée ${BOLD}${HOSTNAME}${RESET} existe déjà dans ${file}."
        return 0
    fi

    # Check if we can write directly
    if [ -w "$file" ]; then
        echo "$ENTRY" >> "$file"
        success "Entrée ajoutée dans ${file}."
    else
        # Try with sudo
        if command -v sudo &>/dev/null; then
            echo ""
            warning "Droits administrateur requis pour modifier ${file}."
            echo -e "  Commande : ${BOLD}sudo sh -c 'echo \"${ENTRY}\" >> ${file}'${RESET}"
            echo ""
            if sudo sh -c "echo '${ENTRY}' >> '${file}'"; then
                success "Entrée ajoutée dans ${file} (sudo)."
            else
                warning "Impossible de modifier ${file} automatiquement."
                info "Ajoutez manuellement : ${BOLD}${ENTRY}${RESET} dans ${file}."
            fi
        else
            warning "Impossible de modifier ${file} (pas de sudo)."
            info "Ajoutez manuellement : ${BOLD}${ENTRY}${RESET} dans ${file}."
        fi
    fi
}

hosts_remove_entry() {
    local file="$1"
    if ! hosts_has_entry "$file"; then
        warning "L'entrée ${BOLD}${HOSTNAME}${RESET} n'existe pas dans ${file}."
        return 0
    fi

    local escaped
    escaped=$(echo "$HOSTNAME" | sed 's/[.[\*^$()+?{|]/\\&/g')

    if [ -w "$file" ]; then
        # sed in-place (compatible Linux et macOS)
        if [[ "$OS" == "mac" ]]; then
            sed -i '' "/$escaped/d" "$file"
        else
            sed -i "/$escaped/d" "$file"
        fi
        success "Entrée supprimée de ${file}."
    else
        if command -v sudo &>/dev/null; then
            warning "Droits administrateur requis pour modifier ${file}."
            if [[ "$OS" == "mac" ]]; then
                sudo sed -i '' "/$escaped/d" "$file"
            else
                sudo sed -i "/$escaped/d" "$file"
            fi
            success "Entrée supprimée de ${file} (sudo)."
        else
            warning "Impossible de modifier ${file}. Supprimez manuellement la ligne : ${BOLD}${ENTRY}${RESET}."
        fi
    fi
}

# ── Windows via PowerShell (for WSL or MSYS) ─────────────────────
windows_add_entry() {
    local win_hosts_native
    if [ "$OS" = "wsl" ]; then
        win_hosts_native="C:\\Windows\\System32\\drivers\\etc\\hosts"
        if command -v powershell.exe &>/dev/null; then
            info "Ajout dans le fichier hosts Windows via PowerShell..."
            powershell.exe -Command "
                \$hosts = '${win_hosts_native}'
                \$entry = '${ENTRY}'
                if (-not (Select-String -Path \$hosts -Pattern '${HOSTNAME}' -Quiet)) {
                    Add-Content -Path \$hosts -Value \$entry -Encoding UTF8
                    Write-Host 'OK: Entrée ajoutée dans le fichier hosts Windows'
                } else {
                    Write-Host 'INFO: Entrée déjà présente dans le fichier hosts Windows'
                }
            " 2>/dev/null && success "Entrée ajoutée dans le fichier hosts Windows" || \
                warning "Impossible de modifier le fichier hosts Windows (lancez PowerShell en administrateur)."
        else
            warning "PowerShell non disponible. Ajoutez manuellement dans : ${win_hosts_native}."
            info "Ligne à ajouter : ${BOLD}${ENTRY}${RESET}."
        fi
    fi
}

windows_remove_entry() {
    local win_hosts_native
    if [ "$OS" = "wsl" ]; then
        win_hosts_native="C:\\Windows\\System32\\drivers\\etc\\hosts"
        if command -v powershell.exe &>/dev/null; then
            info "Suppression dans le fichier hosts Windows via PowerShell..."
            powershell.exe -Command "
                \$hosts = '${win_hosts_native}'
                \$content = Get-Content \$hosts | Where-Object { \$_ -notmatch '${HOSTNAME}' }
                Set-Content -Path \$hosts -Value \$content -Encoding UTF8
                Write-Host 'OK: Entrée supprimée du fichier hosts Windows'
            " 2>/dev/null && success "Entrée supprimée du fichier hosts Windows" || \
                warning "Impossible de modifier le fichier hosts Windows."
        fi
    fi
}

# ── Execution ─────────────────────────────────────────────────────
echo ""
if [ "$ACTION" = "--remove" ]; then
    info "Suppression de l'entrée hosts pour : ${BOLD}${HOSTNAME}${RESET}."
    hosts_remove_entry "$HOSTS_FILE"
    [ "$OS" = "wsl" ] && windows_remove_entry
else
    info "Ajout de l'entrée hosts pour : ${BOLD}${HOSTNAME}${RESET}."
    hosts_add_entry "$HOSTS_FILE"

    # On WSL, also modify the Windows hosts file
    if [ "$OS" = "wsl" ]; then
        windows_add_entry
        # And also the Linux WSL hosts, which are so different
        if [ "$WIN_HOSTS" != "$HOSTS_FILE" ] && [ -f "$WIN_HOSTS" ]; then
            hosts_add_entry "$WIN_HOSTS" 2>/dev/null || true
        fi
    fi
fi

echo ""
info "Fichier hosts actuel (entrées ${HOSTNAME}) :"
grep -F "$HOSTNAME" "$HOSTS_FILE" 2>/dev/null | sed 's/^/    /' || echo "    (aucune entrée)"
echo ""

# ── DNS Verification ──────────────────────────────────────────────
if command -v ping &>/dev/null; then
    if ping -c1 -W1 "$HOSTNAME" &>/dev/null 2>&1; then
        success "DNS résolu : ${BOLD}${HOSTNAME}${RESET} → ${IP}."
    else
        warning "Le hostname n'est pas encore résolu (normal si c'est un nouvel ajout).\nAttendez quelques secondes et réessayez : ${BOLD}ping ${HOSTNAME}${RESET}."
    fi
fi
