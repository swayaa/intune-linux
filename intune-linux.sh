#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# intune-linux.sh — v2.0.0
# Microsoft Intune Bootstrap für Ubuntu/Debian
# github.com/swayaa/intune-linux
# =============================================================================

SCRIPT_VERSION="2.0.1"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/intune-bootstrap-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${LOG_DIR}"

if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[1;33m'
  C_RED='\033[0;31m'
  C_CYAN='\033[0;36m'
  C_BOLD='\033[1m'
else
  C_RESET=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''; C_BOLD=''
fi

log() {
  local level="$1"; shift
  local msg="$*"
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  local color=""
  case "${level}" in
    INFO)  color="${C_GREEN}"  ;;
    WARN)  color="${C_YELLOW}" ;;
    ERROR) color="${C_RED}"    ;;
    STEP)  color="${C_CYAN}"   ;;
  esac
  printf "${color}[%s] [%-5s] %s${C_RESET}\n" "${ts}" "${level}" "${msg}"
  printf "[%s] [%-5s] %s\n" "${ts}" "${level}" "${msg}" >> "${LOG_FILE}"
}

step() {
  echo "" | tee -a "${LOG_FILE}"
  log STEP "==> $1"
}

# -----------------------------------------------------------------------------
# Hilfsfunktionen
# -----------------------------------------------------------------------------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log ERROR "Pflicht-Kommando fehlt: '$1'"
    exit 1
  }
}

pkg_installed() {
  dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

pkg_version() {
  dpkg -s "$1" 2>/dev/null | awk '/^Version:/ {print $2}'
}

run_sudo() {
  log INFO "Führe aus: sudo $*"
  sudo "$@" 2>&1 | tee -a "${LOG_FILE}"
}

confirm() {
  local prompt="$1"
  local answer
  printf "${C_YELLOW}%s [j/N]: ${C_RESET}" "${prompt}"
  read -r answer
  [[ "${answer,,}" == "j" ]]
}

# -----------------------------------------------------------------------------
# Variablen (gecacht)
# -----------------------------------------------------------------------------
CODENAME="$(lsb_release -cs)"
RELEASE="$(lsb_release -rs)"
KEYRING_PATH="/usr/share/keyrings/microsoft.gpg"
REPO_FILE="/etc/apt/sources.list.d/microsoft-ubuntu-${CODENAME}-prod.list"
DOWNLOAD_DIR="${HOME}/Downloads"
EDGE_DEB="$(find "${DOWNLOAD_DIR}" -maxdepth 1 -type f \
  -name 'microsoft-edge-stable_*_amd64.deb' 2>/dev/null \
  | sort | tail -n 1 || true)"
TMP_EDGE_DEB=""

MS_PACKAGES=(
  microsoft-identity-broker
  microsoft-edge-stable
  intune-portal
)

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
cleanup() {
  if [[ -n "${TMP_EDGE_DEB}" && -f "${TMP_EDGE_DEB}" ]]; then
    log WARN "Cleanup: entferne ${TMP_EDGE_DEB}"
    rm -f "${TMP_EDGE_DEB}" || true
  fi
}
trap cleanup EXIT

# =============================================================================
# MODUS: --version
# =============================================================================
cmd_version() {
  printf "\n${C_BOLD}intune-linux.sh${C_RESET} v%s\n\n" "${SCRIPT_VERSION}"
  printf "%-35s %s\n" "Paket" "Version"
  printf "%-35s %s\n" "-----------------------------------" "----------"
  for pkg in "${MS_PACKAGES[@]}"; do
    local ver
    if pkg_installed "${pkg}"; then
      ver="$(pkg_version "${pkg}")"
    else
      ver="nicht installiert"
    fi
    printf "%-35s %s\n" "${pkg}" "${ver}"
  done
  echo ""
}

# =============================================================================
# MODUS: --status
# =============================================================================
cmd_status() {
  step "Paket-Status"
  for pkg in "${MS_PACKAGES[@]}"; do
    if pkg_installed "${pkg}"; then
      log INFO "  ✓ ${pkg} $(pkg_version "${pkg}")"
    else
      log WARN "  ✗ ${pkg} — nicht installiert"
    fi
  done

  step "Microsoft Repo & Keyring"
  if [[ -f "${KEYRING_PATH}" ]]; then
    log INFO "  ✓ Keyring vorhanden: ${KEYRING_PATH}"
  else
    log WARN "  ✗ Keyring fehlt: ${KEYRING_PATH}"
  fi

  if [[ -f "${REPO_FILE}" ]]; then
    log INFO "  ✓ Repo vorhanden: ${REPO_FILE}"
  else
    log WARN "  ✗ Repo fehlt: ${REPO_FILE}"
  fi

  step "Broker Service"
  if systemctl is-active --quiet microsoft-identity-device-broker; then
    log INFO "  ✓ microsoft-identity-device-broker läuft"
  else
    log WARN "  ✗ microsoft-identity-device-broker ist nicht aktiv"
  fi

  step "Intune Agent Timer"
  if systemctl --user is-active --quiet intune-agent.timer 2>/dev/null; then
    log INFO "  ✓ intune-agent.timer läuft"
  elif systemctl --user is-enabled --quiet intune-agent.timer 2>/dev/null; then
    log INFO "  ✓ intune-agent.timer eingerichtet (startet beim nächsten Login)"
  else
    log WARN "  ✗ intune-agent.timer nicht eingerichtet (ggf. noch nicht enrollt)"
  fi

  step "Enrollment / dsreg"
  if command -v dsreg >/dev/null 2>&1; then
    local reg_status prt_status
    reg_status="$(dsreg --status 2>/dev/null | awk '/Device Registration Status/ {print $NF}')"
    prt_status="$(dsreg --status 2>/dev/null | awk '/PRT Present/ {print $NF}')"
    log INFO "  Device Registration Status : ${reg_status:-unbekannt}"
    log INFO "  PRT Present                : ${prt_status:-unbekannt}"
  else
    log WARN "  dsreg nicht gefunden"
  fi

  echo ""
  log INFO "Logfile: ${LOG_FILE}"
}

# =============================================================================
# MODUS: --install
# =============================================================================
cmd_install() {
  log INFO "Logfile: ${LOG_FILE}"

  step "Prüfe Basis-Kommandos"
  for cmd in curl gpg lsb_release apt-get sudo systemctl dpkg; do
    need_cmd "${cmd}"
    log INFO "  OK: ${cmd}"
  done

  step "Richte Microsoft Paketquelle ein (${CODENAME} / ${RELEASE})"

  if [[ ! -f "${KEYRING_PATH}" ]]; then
    log INFO "Lege Microsoft Keyring an..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor \
      | sudo tee "${KEYRING_PATH}" >/dev/null
    sudo chmod 644 "${KEYRING_PATH}"
    log INFO "Keyring angelegt: ${KEYRING_PATH}"
  else
    log INFO "Keyring bereits vorhanden"
  fi

  if [[ ! -f "${REPO_FILE}" ]]; then
    log INFO "Lege Repo-Datei an..."
    echo "deb [arch=amd64 signed-by=${KEYRING_PATH}] \
https://packages.microsoft.com/ubuntu/${RELEASE}/prod ${CODENAME} main" \
      | sudo tee "${REPO_FILE}" >/dev/null
    log INFO "Repo angelegt: ${REPO_FILE}"
  else
    log INFO "Repo bereits vorhanden"
  fi

  step "Aktualisiere Paketlisten"
  run_sudo apt-get update -q

  # Identity Broker
  step "Installiere microsoft-identity-broker"
  if pkg_installed microsoft-identity-broker; then
    log INFO "bereits installiert — überspringe"
  else
    run_sudo apt-get install -y microsoft-identity-broker
    log INFO "microsoft-identity-broker installiert"
  fi

  # Edge
  step "Installiere microsoft-edge-stable"
  if pkg_installed microsoft-edge-stable; then
    log INFO "bereits installiert — überspringe"
  elif [[ -n "${EDGE_DEB}" ]]; then
    log INFO "Lokale DEB gefunden: ${EDGE_DEB}"
    TMP_EDGE_DEB="/tmp/$(basename "${EDGE_DEB}")"
    cp -f "${EDGE_DEB}" "${TMP_EDGE_DEB}"
    chmod 644 "${TMP_EDGE_DEB}"
    run_sudo apt-get install -y "${TMP_EDGE_DEB}"
    log INFO "Edge aus lokaler DEB installiert"
  else
    log WARN "Keine lokale DEB — installiere aus Repo"
    run_sudo apt-get install -y microsoft-edge-stable
    log INFO "Edge aus Repo installiert"
  fi

  # Intune Portal
  step "Installiere intune-portal"
  if pkg_installed intune-portal; then
    log INFO "bereits installiert — überspringe"
  else
    run_sudo apt-get install -y intune-portal
    log INFO "intune-portal installiert"
  fi

  step "Systemd User Daemon Reload"
  if systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}"; then
    log INFO "daemon-reload erfolgreich"
  else
    log WARN "daemon-reload fehlgeschlagen — ggf. manuell: systemctl --user daemon-reload"
  fi

  step "Starte Intune Portal"
  if command -v intune-portal >/dev/null 2>&1; then
    nohup intune-portal >/dev/null 2>&1 &
    log INFO "Intune Portal gestartet (PID $!)"
  else
    log WARN "intune-portal nicht im PATH — bitte manuell starten"
  fi

  echo ""
  log INFO "============================================"
  log INFO "Installation abgeschlossen."
  log INFO "Logfile: ${LOG_FILE}"
  log INFO "============================================"
  echo ""
  log INFO "Nächster Schritt: Firmenanmeldung im Intune Portal"
  log INFO "Tipp: $(basename "$0") --status  — zeigt ob alles läuft"
}

# =============================================================================
# MODUS: --update
# =============================================================================
cmd_update() {
  step "Microsoft Paketlisten aktualisieren"
  run_sudo apt-get update -q

  step "Microsoft Pakete updaten"
  run_sudo apt-get install -y --only-upgrade \
    microsoft-identity-broker \
    microsoft-edge-stable \
    intune-portal

  step "Versionen nach Update"
  cmd_version

  step "Systemd User Daemon Reload"
  systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}" || true

  log INFO "Update abgeschlossen."
  log INFO "Logfile: ${LOG_FILE}"
}

# =============================================================================
# MODUS: --repair
# =============================================================================
cmd_repair() {
  local fixed=0

  step "Repair: Prüfe Microsoft Repo"
  if [[ ! -f "${KEYRING_PATH}" ]]; then
    log WARN "Keyring fehlt — wird neu angelegt..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor \
      | sudo tee "${KEYRING_PATH}" >/dev/null
    sudo chmod 644 "${KEYRING_PATH}"
    log INFO "Keyring repariert"
    ((fixed++)) || true
  fi

  if [[ ! -f "${REPO_FILE}" ]]; then
    log WARN "Repo fehlt — wird neu angelegt..."
    echo "deb [arch=amd64 signed-by=${KEYRING_PATH}] \
https://packages.microsoft.com/ubuntu/${RELEASE}/prod ${CODENAME} main" \
      | sudo tee "${REPO_FILE}" >/dev/null
    log INFO "Repo repariert"
    ((fixed++)) || true
  fi

  step "Repair: Prüfe fehlende Pakete"
  local missing=()
  for pkg in "${MS_PACKAGES[@]}"; do
    if ! pkg_installed "${pkg}"; then
      log WARN "${pkg} fehlt — wird installiert..."
      missing+=("${pkg}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    run_sudo apt-get update -q
    run_sudo apt-get install -y "${missing[@]}"
    log INFO "Fehlende Pakete installiert: ${missing[*]}"
    ((fixed++)) || true
  fi

  step "Repair: Prüfe Broker Service"
  if ! systemctl is-active --quiet microsoft-identity-device-broker; then
    log WARN "Broker nicht aktiv — wird neugestartet..."
    run_sudo systemctl restart microsoft-identity-device-broker
    sleep 2
    if systemctl is-active --quiet microsoft-identity-device-broker; then
      log INFO "Broker erfolgreich neugestartet"
      ((fixed++)) || true
    else
      log ERROR "Broker konnte nicht gestartet werden"
    fi
  else
    log INFO "Broker läuft"
  fi

  step "Repair: Systemd User Daemon Reload"
  if systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}"; then
    log INFO "daemon-reload erfolgreich"
    ((fixed++)) || true
  fi

  step "Repair: Prüfe apt broken packages"
  log INFO "Führe apt-get -f install aus..."
  run_sudo apt-get -f install -y

  echo ""
  if [[ ${fixed} -gt 0 ]]; then
    log INFO "Repair abgeschlossen — ${fixed} Problem(e) behoben."
  else
    log INFO "Repair abgeschlossen — kein Problem gefunden. System sieht sauber aus."
  fi
  log INFO "Tipp: $(basename "$0") --status  — zur Kontrolle"
  log INFO "Logfile: ${LOG_FILE}"
}

# =============================================================================
# MODUS: --reset-enrollment
# =============================================================================
cmd_reset_enrollment() {
  echo ""
  log WARN "ACHTUNG: Das Gerät wird aus Intune ausgetragen."
  log WARN "Danach ist eine neue Firmenanmeldung im Intune Portal nötig."
  echo ""
  if ! confirm "Enrollment wirklich zurücksetzen?"; then
    log INFO "Abgebrochen."
    exit 0
  fi

  step "Stoppe Intune Agent"
  systemctl --user stop intune-agent.timer 2>/dev/null | tee -a "${LOG_FILE}" || true
  systemctl --user stop intune-agent.service 2>/dev/null | tee -a "${LOG_FILE}" || true
  log INFO "Intune Agent gestoppt"

  step "Gerät aus Azure AD / Intune austragen"
  log WARN "Automatisches Austragen wird auf Linux nicht unterstützt."
  log WARN "Bitte das Gerät manuell aus dem Intune Admin Center entfernen:"
  log WARN "  https://intune.microsoft.com → Geräte → Gerät suchen → Entfernen"
  log INFO "Enrollment-Daten lokal werden beim neuen Portal-Login überschrieben."

  step "Systemd User Daemon Reload"
  systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}" || true

  step "Starte Intune Portal für neue Anmeldung"
  if command -v intune-portal >/dev/null 2>&1; then
    nohup intune-portal >/dev/null 2>&1 &
    log INFO "Intune Portal gestartet (PID $!)"
  else
    log WARN "intune-portal nicht im PATH — bitte manuell starten"
  fi

  echo ""
  log INFO "Enrollment zurückgesetzt."
  log INFO "Bitte jetzt im Intune Portal neu mit Firmenkonto anmelden."
  log INFO "Logfile: ${LOG_FILE}"
}

# =============================================================================
# MODUS: --logs
# =============================================================================
cmd_logs() {
  local dump_dir; dump_dir="$(mktemp -d)"
  local archive="${HOME}/Downloads/intune-logdump-$(date +%Y%m%d_%H%M%S).tar.gz"

  step "Sammle Logs für Helpdesk-Dump"

  # Skript-Logs
  if ls "${LOG_DIR}"/intune-bootstrap-*.log >/dev/null 2>&1; then
    cp "${LOG_DIR}"/intune-bootstrap-*.log "${dump_dir}/"
    log INFO "Skript-Logs kopiert"
  fi

  # dsreg Status
  if command -v dsreg >/dev/null 2>&1; then
    dsreg --status > "${dump_dir}/dsreg-status.txt" 2>&1 || true
    log INFO "dsreg --status gespeichert"
  fi

  # Broker Journal
  journalctl -u microsoft-identity-device-broker \
    --no-pager -n 200 > "${dump_dir}/broker-journal.txt" 2>&1 || true
  log INFO "Broker Journal gespeichert"

  # Intune Agent Journal
  journalctl --user -u intune-agent \
    --no-pager -n 200 > "${dump_dir}/intune-agent-journal.txt" 2>&1 || true
  log INFO "Intune Agent Journal gespeichert"

  # Paketversionen
  cmd_version > "${dump_dir}/package-versions.txt" 2>&1
  log INFO "Paketversionen gespeichert"

  # System Info
  {
    echo "=== uname ==="
    uname -a
    echo ""
    echo "=== lsb_release ==="
    lsb_release -a
    echo ""
    echo "=== hostname ==="
    hostname
  } > "${dump_dir}/sysinfo.txt" 2>&1
  log INFO "Systeminfo gespeichert"

  # Packen
  tar -czf "${archive}" -C "${dump_dir}" . 2>&1 | tee -a "${LOG_FILE}"
  rm -rf "${dump_dir}"

  echo ""
  log INFO "Log-Dump fertig: ${archive}"
  log INFO "Diese Datei an den Helpdesk schicken."
}

# =============================================================================
# MODUS: --uninstall
# =============================================================================
cmd_uninstall() {
  echo ""
  log WARN "ACHTUNG: Folgende Pakete werden entfernt:"
  for pkg in "${MS_PACKAGES[@]}"; do
    log WARN "  - ${pkg}"
  done
  echo ""
  if ! confirm "Wirklich deinstallieren?"; then
    log INFO "Abgebrochen."
    exit 0
  fi

  step "Stoppe Dienste"
  systemctl --user stop intune-agent.timer 2>/dev/null | tee -a "${LOG_FILE}" || true
  systemctl --user stop intune-agent.service 2>/dev/null | tee -a "${LOG_FILE}" || true
  run_sudo systemctl stop microsoft-identity-device-broker 2>/dev/null || true
  log INFO "Dienste gestoppt"

  step "Entferne Pakete"
  run_sudo apt-get remove -y --purge \
    intune-portal \
    microsoft-edge-stable \
    microsoft-identity-broker
  run_sudo apt-get autoremove -y
  log INFO "Pakete entfernt"

  echo ""
  if confirm "Auch Microsoft Repo und Keyring entfernen?"; then
    step "Entferne Repo und Keyring"
    sudo rm -f "${REPO_FILE}" && log INFO "Repo entfernt: ${REPO_FILE}" || true
    sudo rm -f "${KEYRING_PATH}" && log INFO "Keyring entfernt: ${KEYRING_PATH}" || true
    run_sudo apt-get update -q
  fi

  echo ""
  log INFO "Deinstallation abgeschlossen."
  log INFO "Logfile: ${LOG_FILE}"
}

# =============================================================================
# Interaktives Menü (kein Flag)
# =============================================================================
show_menu() {
  clear
  printf "\n${C_BOLD}  intune-linux.sh v%s${C_RESET}\n" "${SCRIPT_VERSION}"
  printf "  github.com/swayaa/intune-linux\n\n"
  printf "  ${C_CYAN}1)${C_RESET} install          — Erstinstallation\n"
  printf "  ${C_CYAN}2)${C_RESET} update           — MS-Pakete updaten\n"
  printf "  ${C_CYAN}3)${C_RESET} status           — Systemübersicht\n"
  printf "  ${C_CYAN}4)${C_RESET} repair           — Probleme automatisch fixen\n"
  printf "  ${C_CYAN}5)${C_RESET} reset-enrollment — Aus Intune austragen & neu enrollen\n"
  printf "  ${C_CYAN}6)${C_RESET} logs             — Log-Dump für Helpdesk\n"
  printf "  ${C_CYAN}7)${C_RESET} uninstall        — Alles entfernen\n"
  printf "  ${C_CYAN}8)${C_RESET} version          — Skript & Paketversionen\n"
  printf "  ${C_CYAN}q)${C_RESET} Beenden\n\n"
  printf "  Auswahl: "
  read -r choice
  echo ""
  case "${choice}" in
    1) cmd_install ;;
    2) cmd_update ;;
    3) cmd_status ;;
    4) cmd_repair ;;
    5) cmd_reset_enrollment ;;
    6) cmd_logs ;;
    7) cmd_uninstall ;;
    8) cmd_version ;;
    q|Q) exit 0 ;;
    *) log WARN "Ungültige Auswahl: ${choice}" ; sleep 1 ; show_menu ;;
  esac
}

# =============================================================================
# Entry Point
# =============================================================================
case "${1:-}" in
  --install)          cmd_install ;;
  --update)           cmd_update ;;
  --status)           cmd_status ;;
  --repair)           cmd_repair ;;
  --reset-enrollment) cmd_reset_enrollment ;;
  --logs)             cmd_logs ;;
  --uninstall)        cmd_uninstall ;;
  --version)          cmd_version ;;
  --help|-h)
    printf "\nUsage: %s [OPTION]\n\n" "$(basename "$0")"
    printf "  --install          Erstinstallation (Repo, Edge, Intune)\n"
    printf "  --update           Microsoft-Pakete updaten\n"
    printf "  --status           Systemübersicht\n"
    printf "  --repair           Häufige Probleme automatisch beheben\n"
    printf "  --reset-enrollment Gerät aus Intune austragen & neu enrollen\n"
    printf "  --logs             Log-Dump für Helpdesk (.tar.gz)\n"
    printf "  --uninstall        Alle MS-Pakete entfernen\n"
    printf "  --version          Skript- und Paketversionen\n"
    printf "\n  Ohne Flag: interaktives Menü\n\n"
    ;;
  "") show_menu ;;
  *)
    log ERROR "Unbekannte Option: ${1}"
    printf "Hilfe: %s --help\n" "$(basename "$0")"
    exit 1
    ;;
esac