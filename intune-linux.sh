#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------
# Logging Setup
# ---------------------------------
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/intune-bootstrap-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${LOG_DIR}"

# Farben (nur im Terminal, nicht in Logfile)
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_GREEN='\033[0;32m'
  C_YELLOW='\033[1;33m'; C_RED='\033[0;31m'
  C_CYAN='\033[0;36m'
else
  C_RESET=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''
fi

log() {
  local level="$1"; shift
  local msg="$*"
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  local color=""
  case "${level}" in
    INFO)  color="${C_GREEN}" ;;
    WARN)  color="${C_YELLOW}" ;;
    ERROR) color="${C_RED}" ;;
    STEP)  color="${C_CYAN}" ;;
  esac
  # Konsole mit Farbe, Logfile plain
  printf "${color}[%s] [%-5s] %s${C_RESET}\n" "${ts}" "${level}" "${msg}"
  printf "[%s] [%-5s] %s\n" "${ts}" "${level}" "${msg}" >> "${LOG_FILE}"
}

log INFO "Logfile: ${LOG_FILE}"

# ---------------------------------
# Variablen (gecacht)
# ---------------------------------
CODENAME="$(lsb_release -cs)"
RELEASE="$(lsb_release -rs)"
KEYRING_PATH="/usr/share/keyrings/microsoft.gpg"
REPO_FILE="/etc/apt/sources.list.d/microsoft-ubuntu-${CODENAME}-prod.list"
DOWNLOAD_DIR="${HOME}/Downloads"
EDGE_DEB="$(find "${DOWNLOAD_DIR}" -maxdepth 1 -type f \
  -name 'microsoft-edge-stable_*_amd64.deb' 2>/dev/null \
  | sort | tail -n 1 || true)"
TMP_EDGE_DEB=""

# ---------------------------------
# Cleanup
# ---------------------------------
cleanup() {
  if [[ -n "${TMP_EDGE_DEB}" && -f "${TMP_EDGE_DEB}" ]]; then
    log WARN "Cleanup: entferne ${TMP_EDGE_DEB}"
    rm -f "${TMP_EDGE_DEB}" || true
  fi
}
trap cleanup EXIT

# ---------------------------------
# Hilfsfunktionen
# ---------------------------------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log ERROR "Pflicht-Kommando fehlt: '$1'"
    exit 1
  }
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

step() {
  echo "" | tee -a "${LOG_FILE}"
  log STEP "==> $1"
}

run_sudo() {
  log INFO "Führe aus: sudo $*"
  sudo "$@" 2>&1 | tee -a "${LOG_FILE}"
}

# ---------------------------------
# Voraussetzungen
# ---------------------------------
step "Prüfe Basis-Kommandos"
for cmd in curl gpg lsb_release apt-get sudo systemctl dpkg; do
  need_cmd "${cmd}"
  log INFO "  OK: ${cmd}"
done

# ---------------------------------
# Microsoft Repo
# ---------------------------------
step "Richte Microsoft Paketquelle ein (${CODENAME} / ${RELEASE})"

if [[ ! -f "${KEYRING_PATH}" ]]; then
  log INFO "Lege Microsoft Keyring an..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee "${KEYRING_PATH}" >/dev/null
  sudo chmod 644 "${KEYRING_PATH}"
  log INFO "Keyring angelegt: ${KEYRING_PATH}"
else
  log INFO "Keyring bereits vorhanden: ${KEYRING_PATH}"
fi

if [[ ! -f "${REPO_FILE}" ]]; then
  log INFO "Lege Repo-Datei an..."
  echo "deb [arch=amd64 signed-by=${KEYRING_PATH}] \
https://packages.microsoft.com/ubuntu/${RELEASE}/prod ${CODENAME} main" \
    | sudo tee "${REPO_FILE}" >/dev/null
  log INFO "Repo angelegt: ${REPO_FILE}"
else
  log INFO "Repo bereits vorhanden: ${REPO_FILE}"
fi

# ---------------------------------
# apt update
# ---------------------------------
step "Aktualisiere Paketlisten"
run_sudo apt-get update -q

# ---------------------------------
# Pakete installieren
# ---------------------------------
install_pkg() {
  local pkg="$1"
  step "Installiere ${pkg}"
  if pkg_installed "${pkg}"; then
    log INFO "${pkg} ist bereits installiert — überspringe"
  else
    run_sudo apt-get install -y "${pkg}"
    log INFO "${pkg} erfolgreich installiert"
  fi
}

install_pkg microsoft-identity-broker

# Edge: lokal bevorzugen, sonst Repo
step "Installiere microsoft-edge-stable"
if pkg_installed microsoft-edge-stable; then
  log INFO "microsoft-edge-stable bereits installiert — überspringe"
elif [[ -n "${EDGE_DEB}" ]]; then
  log INFO "Lokale DEB gefunden: ${EDGE_DEB}"
  TMP_EDGE_DEB="/tmp/$(basename "${EDGE_DEB}")"
  cp -f "${EDGE_DEB}" "${TMP_EDGE_DEB}"
  chmod 644 "${TMP_EDGE_DEB}"
  run_sudo apt-get install -y "${TMP_EDGE_DEB}"
  log INFO "Edge aus lokaler DEB installiert"
else
  log WARN "Keine lokale DEB gefunden — installiere aus Repo"
  run_sudo apt-get install -y microsoft-edge-stable
  log INFO "Edge aus Repo installiert"
fi

install_pkg intune-portal

# ---------------------------------
# systemd user
# ---------------------------------
step "Systemd User Daemon Reload"
if systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}"; then
  log INFO "daemon-reload erfolgreich"
else
  log WARN "daemon-reload fehlgeschlagen — ggf. später manuell: systemctl --user daemon-reload"
fi

# ---------------------------------
# Statusinfos
# ---------------------------------
step "dsreg Status"
if command -v dsreg >/dev/null 2>&1; then
  dsreg --status 2>&1 | tee -a "${LOG_FILE}" || true
else
  log WARN "dsreg nicht gefunden"
fi

step "Microsoft Identity Broker Status"
systemctl status microsoft-identity-device-broker --no-pager 2>&1 \
  | tee -a "${LOG_FILE}" || true

# ---------------------------------
# Intune starten
# ---------------------------------
step "Starte Intune Portal"
if command -v intune-portal >/dev/null 2>&1; then
  nohup intune-portal >/dev/null 2>&1 &
  log INFO "Intune Portal gestartet (PID $!)"
else
  log WARN "intune-portal nicht im PATH — bitte manuell über App-Menü starten"
fi

# ---------------------------------
# Abschluss
# ---------------------------------
echo ""
log INFO "============================================"
log INFO "Fertig. Edge + Intune installiert & geprüft."
log INFO "Logfile: ${LOG_FILE}"
log INFO "============================================"
echo ""
log INFO "Nächster Schritt: Firmenanmeldung im Intune Portal"
echo ""
log INFO "Optionale Prüfung danach:"
log INFO "  dsreg --status"
log INFO "  systemctl --user status intune-agent.timer --no-pager"