#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# intune-linux.sh — v2.1.0
# Microsoft Intune Bootstrap for Ubuntu/Debian
# github.com/swayaa/intune-linux
# =============================================================================

SCRIPT_VERSION="2.1.0"

# -----------------------------------------------------------------------------
# Language Detection — auto via $LANG, override with --lang=en / --lang=de
# -----------------------------------------------------------------------------
LANG_CODE="en"
for _arg in "$@"; do
  case "${_arg}" in
    --lang=de) LANG_CODE="de" ;;
    --lang=en) LANG_CODE="en" ;;
  esac
done
if [[ "${LANG_CODE}" == "en" ]]; then
  case "${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}" in
    de_*) LANG_CODE="de" ;;
  esac
fi

# Translation function: t KEY [arg1 arg2 ...]
t() {
  local key="$1"; shift
  local fmt=""
  case "${LANG_CODE}:${key}" in
    de:logfile_info)           fmt="Logfile: %s" ;;
    en:logfile_info)           fmt="Logfile: %s" ;;
    de:cmd_ok)                 fmt="  OK: %s" ;;
    en:cmd_ok)                 fmt="  OK: %s" ;;
    de:cmd_missing)            fmt="Pflicht-Kommando fehlt: '%s'" ;;
    en:cmd_missing)            fmt="Required command missing: '%s'" ;;
    de:run_sudo)               fmt="Führe aus: sudo %s" ;;
    en:run_sudo)               fmt="Running: sudo %s" ;;
    de:cleanup_remove)         fmt="Cleanup: entferne %s" ;;
    en:cleanup_remove)         fmt="Cleanup: removing %s" ;;
    de:invalid_option)         fmt="Unbekannte Option: %s" ;;
    en:invalid_option)         fmt="Unknown option: %s" ;;
    de:hint_help)              fmt="Hilfe: %s --help" ;;
    en:hint_help)              fmt="Help: %s --help" ;;
    de:invalid_menu)           fmt="Ungültige Auswahl: %s" ;;
    en:invalid_menu)           fmt="Invalid selection: %s" ;;
    de:aborted)                fmt="Abgebrochen." ;;
    en:aborted)                fmt="Aborted." ;;
    de:step_check_cmds)        fmt="Prüfe Basis-Kommandos" ;;
    en:step_check_cmds)        fmt="Checking required commands" ;;
    de:step_setup_repo)        fmt="Richte Microsoft Paketquelle ein (%s / %s)" ;;
    en:step_setup_repo)        fmt="Setting up Microsoft package source (%s / %s)" ;;
    de:step_update_lists)      fmt="Aktualisiere Paketlisten" ;;
    en:step_update_lists)      fmt="Updating package lists" ;;
    de:step_install_pkg)       fmt="Installiere %s" ;;
    en:step_install_pkg)       fmt="Installing %s" ;;
    de:step_install_edge)      fmt="Installiere microsoft-edge-stable" ;;
    en:step_install_edge)      fmt="Installing microsoft-edge-stable" ;;
    de:step_daemon_reload)     fmt="Systemd User Daemon Reload" ;;
    en:step_daemon_reload)     fmt="Systemd user daemon reload" ;;
    de:step_start_intune)      fmt="Starte Intune Portal" ;;
    en:step_start_intune)      fmt="Starting Intune Portal" ;;
    de:step_update_ms)         fmt="Microsoft Paketlisten aktualisieren" ;;
    en:step_update_ms)         fmt="Updating Microsoft package lists" ;;
    de:step_update_pkgs)       fmt="Microsoft Pakete updaten" ;;
    en:step_update_pkgs)       fmt="Upgrading Microsoft packages" ;;
    de:step_versions)          fmt="Versionen nach Update" ;;
    en:step_versions)          fmt="Versions after update" ;;
    de:step_repair_repo)       fmt="Repair: Prüfe Microsoft Repo" ;;
    en:step_repair_repo)       fmt="Repair: Checking Microsoft repository" ;;
    de:step_repair_pkgs)       fmt="Repair: Prüfe fehlende Pakete" ;;
    en:step_repair_pkgs)       fmt="Repair: Checking missing packages" ;;
    de:step_repair_broker)     fmt="Repair: Prüfe Broker Service" ;;
    en:step_repair_broker)     fmt="Repair: Checking broker service" ;;
    de:step_repair_daemon)     fmt="Repair: Systemd User Daemon Reload" ;;
    en:step_repair_daemon)     fmt="Repair: Systemd user daemon reload" ;;
    de:step_repair_apt)        fmt="Repair: Prüfe apt broken packages" ;;
    en:step_repair_apt)        fmt="Repair: Checking broken packages" ;;
    de:step_stop_services)     fmt="Stoppe Dienste" ;;
    en:step_stop_services)     fmt="Stopping services" ;;
    de:step_remove_pkgs)       fmt="Entferne Pakete" ;;
    en:step_remove_pkgs)       fmt="Removing packages" ;;
    de:step_remove_repo)       fmt="Entferne Repo und Keyring" ;;
    en:step_remove_repo)       fmt="Removing repository and keyring" ;;
    de:step_stop_intune)       fmt="Stoppe Intune Agent" ;;
    en:step_stop_intune)       fmt="Stopping Intune Agent" ;;
    de:step_leave_aad)         fmt="Gerät aus Azure AD / Intune austragen" ;;
    en:step_leave_aad)         fmt="Leaving Azure AD / Intune enrollment" ;;
    de:step_collect_logs)      fmt="Sammle Logs für Helpdesk-Dump" ;;
    en:step_collect_logs)      fmt="Collecting logs for helpdesk dump" ;;
    de:step_status_pkgs)       fmt="Paket-Status" ;;
    en:step_status_pkgs)       fmt="Package status" ;;
    de:step_status_repo)       fmt="Microsoft Repo & Keyring" ;;
    en:step_status_repo)       fmt="Microsoft repository & keyring" ;;
    de:step_status_broker)     fmt="Broker Service" ;;
    en:step_status_broker)     fmt="Broker service" ;;
    de:step_status_timer)      fmt="Intune Agent Timer" ;;
    en:step_status_timer)      fmt="Intune Agent timer" ;;
    de:step_status_enroll)     fmt="Enrollment / dsreg" ;;
    en:step_status_enroll)     fmt="Enrollment / dsreg" ;;
    de:keyring_creating)       fmt="Lege Microsoft Keyring an..." ;;
    en:keyring_creating)       fmt="Creating Microsoft keyring..." ;;
    de:keyring_created)        fmt="Keyring angelegt: %s" ;;
    en:keyring_created)        fmt="Keyring created: %s" ;;
    de:keyring_exists)         fmt="Keyring bereits vorhanden" ;;
    en:keyring_exists)         fmt="Keyring already exists" ;;
    de:keyring_missing)        fmt="Keyring fehlt — wird neu angelegt..." ;;
    en:keyring_missing)        fmt="Keyring missing — recreating..." ;;
    de:keyring_fixed)          fmt="Keyring repariert" ;;
    en:keyring_fixed)          fmt="Keyring repaired" ;;
    de:keyring_ok)             fmt="✓ Keyring vorhanden: %s" ;;
    en:keyring_ok)             fmt="✓ Keyring exists: %s" ;;
    de:keyring_warn)           fmt="✗ Keyring fehlt: %s" ;;
    en:keyring_warn)           fmt="✗ Keyring missing: %s" ;;
    de:keyring_removed)        fmt="Keyring entfernt: %s" ;;
    en:keyring_removed)        fmt="Keyring removed: %s" ;;
    de:repo_creating)          fmt="Lege Repo-Datei an..." ;;
    en:repo_creating)          fmt="Creating repository file..." ;;
    de:repo_created)           fmt="Repo angelegt: %s" ;;
    en:repo_created)           fmt="Repository created: %s" ;;
    de:repo_exists)            fmt="Repo bereits vorhanden" ;;
    en:repo_exists)            fmt="Repository already exists" ;;
    de:repo_missing)           fmt="Repo fehlt — wird neu angelegt..." ;;
    en:repo_missing)           fmt="Repository missing — recreating..." ;;
    de:repo_fixed)             fmt="Repo repariert" ;;
    en:repo_fixed)             fmt="Repository repaired" ;;
    de:repo_ok)                fmt="✓ Repo vorhanden: %s" ;;
    en:repo_ok)                fmt="✓ Repository exists: %s" ;;
    de:repo_warn)              fmt="✗ Repo fehlt: %s" ;;
    en:repo_warn)              fmt="✗ Repository missing: %s" ;;
    de:repo_removed)           fmt="Repo entfernt: %s" ;;
    en:repo_removed)           fmt="Repository removed: %s" ;;
    de:pkg_exists)             fmt="%s ist bereits installiert — überspringe" ;;
    en:pkg_exists)             fmt="%s is already installed — skipping" ;;
    de:pkg_installed_ok)       fmt="%s installiert" ;;
    en:pkg_installed_ok)       fmt="%s installed" ;;
    de:pkg_missing_repair)     fmt="%s fehlt — wird installiert..." ;;
    en:pkg_missing_repair)     fmt="%s missing — installing..." ;;
    de:pkgs_installed)         fmt="Fehlende Pakete installiert: %s" ;;
    en:pkgs_installed)         fmt="Missing packages installed: %s" ;;
    de:pkg_status_ok)          fmt="✓ %s %s" ;;
    en:pkg_status_ok)          fmt="✓ %s %s" ;;
    de:pkg_status_fail)        fmt="✗ %s — nicht installiert" ;;
    en:pkg_status_fail)        fmt="✗ %s — not installed" ;;
    de:edge_local_found)       fmt="Lokale DEB gefunden: %s" ;;
    en:edge_local_found)       fmt="Local DEB found: %s" ;;
    de:edge_local_done)        fmt="Edge aus lokaler DEB installiert" ;;
    en:edge_local_done)        fmt="Edge installed from local DEB" ;;
    de:edge_repo_warn)         fmt="Keine lokale DEB — installiere aus Repo" ;;
    en:edge_repo_warn)         fmt="No local DEB found — installing from repository" ;;
    de:edge_repo_done)         fmt="Edge aus Repo installiert" ;;
    en:edge_repo_done)         fmt="Edge installed from repository" ;;
    de:daemon_ok)              fmt="daemon-reload erfolgreich" ;;
    en:daemon_ok)              fmt="daemon-reload successful" ;;
    de:daemon_fail)            fmt="daemon-reload fehlgeschlagen — ggf. manuell: systemctl --user daemon-reload" ;;
    en:daemon_fail)            fmt="daemon-reload failed — run manually if needed: systemctl --user daemon-reload" ;;
    de:broker_running)         fmt="Broker läuft" ;;
    en:broker_running)         fmt="Broker is running" ;;
    de:broker_stopped)         fmt="Broker nicht aktiv — wird neugestartet..." ;;
    en:broker_stopped)         fmt="Broker not active — restarting..." ;;
    de:broker_restarted)       fmt="Broker erfolgreich neugestartet" ;;
    en:broker_restarted)       fmt="Broker restarted successfully" ;;
    de:broker_fail)            fmt="Broker konnte nicht gestartet werden" ;;
    en:broker_fail)            fmt="Broker could not be started" ;;
    de:broker_ok)              fmt="✓ microsoft-identity-device-broker läuft" ;;
    en:broker_ok)              fmt="✓ microsoft-identity-device-broker is running" ;;
    de:broker_warn)            fmt="✗ microsoft-identity-device-broker ist nicht aktiv" ;;
    en:broker_warn)            fmt="✗ microsoft-identity-device-broker is not active" ;;
    de:timer_ok)               fmt="✓ intune-agent.timer läuft" ;;
    en:timer_ok)               fmt="✓ intune-agent.timer is running" ;;
    de:timer_enabled)          fmt="✓ intune-agent.timer eingerichtet (startet beim nächsten Login)" ;;
    en:timer_enabled)          fmt="✓ intune-agent.timer configured (starts at next login)" ;;
    de:timer_warn)             fmt="✗ intune-agent.timer nicht eingerichtet (ggf. noch nicht enrollt)" ;;
    en:timer_warn)             fmt="✗ intune-agent.timer not configured (possibly not yet enrolled)" ;;
    de:dsreg_missing)          fmt="dsreg nicht gefunden" ;;
    en:dsreg_missing)          fmt="dsreg not found" ;;
    de:reg_status)             fmt="Device Registration Status : %s" ;;
    en:reg_status)             fmt="Device Registration Status : %s" ;;
    de:prt_status)             fmt="PRT Present                : %s" ;;
    en:prt_status)             fmt="PRT Present                : %s" ;;
    de:unknown)                fmt="unbekannt" ;;
    en:unknown)                fmt="unknown" ;;
    de:intune_started)         fmt="Intune Portal gestartet (PID %s)" ;;
    en:intune_started)         fmt="Intune Portal started (PID %s)" ;;
    de:intune_not_found)       fmt="intune-portal nicht im PATH — bitte manuell über App-Menü starten" ;;
    en:intune_not_found)       fmt="intune-portal not in PATH — please start manually via app menu" ;;
    de:intune_stopped)         fmt="Intune Agent gestoppt" ;;
    en:intune_stopped)         fmt="Intune Agent stopped" ;;
    de:install_done)           fmt="Installation abgeschlossen." ;;
    en:install_done)           fmt="Installation complete." ;;
    de:install_next)           fmt="Nächster Schritt: Firmenanmeldung im Intune Portal" ;;
    en:install_next)           fmt="Next step: Sign in with your company account in Intune Portal" ;;
    de:install_tip)            fmt="Tipp: %s --status  — zeigt ob alles läuft" ;;
    en:install_tip)            fmt="Tip: %s --status  — shows if everything is running" ;;
    de:repair_apt_run)         fmt="Führe apt-get -f install aus..." ;;
    en:repair_apt_run)         fmt="Running apt-get -f install..." ;;
    de:repair_done_ok)         fmt="Repair abgeschlossen — kein Problem gefunden. System sieht sauber aus." ;;
    en:repair_done_ok)         fmt="Repair complete — no issues found. System looks clean." ;;
    de:repair_done_n)          fmt="Repair abgeschlossen — %s Problem(e) behoben." ;;
    en:repair_done_n)          fmt="Repair complete — %s issue(s) fixed." ;;
    de:repair_tip)             fmt="Tipp: %s --status  — zur Kontrolle" ;;
    en:repair_tip)             fmt="Tip: %s --status  — to verify" ;;
    de:update_done)            fmt="Update abgeschlossen." ;;
    en:update_done)            fmt="Update complete." ;;
    de:reset_warn1)            fmt="ACHTUNG: Das Gerät wird aus Intune ausgetragen." ;;
    en:reset_warn1)            fmt="WARNING: The device will be unenrolled from Intune." ;;
    de:reset_warn2)            fmt="Danach ist eine neue Firmenanmeldung im Intune Portal nötig." ;;
    en:reset_warn2)            fmt="A new company sign-in in the Intune Portal will be required." ;;
    de:reset_confirm)          fmt="Enrollment wirklich zurücksetzen?" ;;
    en:reset_confirm)          fmt="Really reset enrollment?" ;;
    de:reset_no_leave)         fmt="Automatisches Austragen wird auf Linux nicht unterstützt." ;;
    en:reset_no_leave)         fmt="Automatic unenrollment is not supported on Linux." ;;
    de:reset_manual)           fmt="Bitte das Gerät manuell aus dem Intune Admin Center entfernen:" ;;
    en:reset_manual)           fmt="Please remove the device manually from the Intune Admin Center:" ;;
    de:reset_manual_url)       fmt="  https://intune.microsoft.com → Geräte → Gerät suchen → Entfernen" ;;
    en:reset_manual_url)       fmt="  https://intune.microsoft.com → Devices → Find device → Remove" ;;
    de:reset_local_note)       fmt="Enrollment-Daten lokal werden beim neuen Portal-Login überschrieben." ;;
    en:reset_local_note)       fmt="Local enrollment data will be overwritten on next portal login." ;;
    de:reset_done)             fmt="Enrollment zurückgesetzt." ;;
    en:reset_done)             fmt="Enrollment reset." ;;
    de:reset_next)             fmt="Bitte jetzt im Intune Portal neu mit Firmenkonto anmelden." ;;
    en:reset_next)             fmt="Please sign in again with your company account in the Intune Portal." ;;
    de:logs_scripts)           fmt="Skript-Logs kopiert" ;;
    en:logs_scripts)           fmt="Script logs copied" ;;
    de:logs_dsreg)             fmt="dsreg --status gespeichert" ;;
    en:logs_dsreg)             fmt="dsreg --status saved" ;;
    de:logs_broker)            fmt="Broker Journal gespeichert" ;;
    en:logs_broker)            fmt="Broker journal saved" ;;
    de:logs_agent)             fmt="Intune Agent Journal gespeichert" ;;
    en:logs_agent)             fmt="Intune Agent journal saved" ;;
    de:logs_versions)          fmt="Paketversionen gespeichert" ;;
    en:logs_versions)          fmt="Package versions saved" ;;
    de:logs_sysinfo)           fmt="Systeminfo gespeichert" ;;
    en:logs_sysinfo)           fmt="System info saved" ;;
    de:logs_done)              fmt="Log-Dump fertig: %s" ;;
    en:logs_done)              fmt="Log dump ready: %s" ;;
    de:logs_send)              fmt="Diese Datei an den Helpdesk schicken." ;;
    en:logs_send)              fmt="Send this file to your helpdesk." ;;
    de:uninstall_warn)         fmt="ACHTUNG: Folgende Pakete werden entfernt:" ;;
    en:uninstall_warn)         fmt="WARNING: The following packages will be removed:" ;;
    de:uninstall_confirm)      fmt="Wirklich deinstallieren?" ;;
    en:uninstall_confirm)      fmt="Really uninstall?" ;;
    de:uninstall_stopped)      fmt="Dienste gestoppt" ;;
    en:uninstall_stopped)      fmt="Services stopped" ;;
    de:uninstall_done_pkgs)    fmt="Pakete entfernt" ;;
    en:uninstall_done_pkgs)    fmt="Packages removed" ;;
    de:uninstall_repo_confirm) fmt="Auch Microsoft Repo und Keyring entfernen?" ;;
    en:uninstall_repo_confirm) fmt="Also remove Microsoft repository and keyring?" ;;
    de:uninstall_done)         fmt="Deinstallation abgeschlossen." ;;
    en:uninstall_done)         fmt="Uninstallation complete." ;;
    de:summary_sep)            fmt="============================================" ;;
    en:summary_sep)            fmt="============================================" ;;
    de:summary_done)           fmt="Fertig. Edge + Intune installiert & geprüft." ;;
    en:summary_done)           fmt="Done. Edge + Intune installed & verified." ;;
    de:version_pkg_header)     fmt="Paket" ;;
    en:version_pkg_header)     fmt="Package" ;;
    de:version_not_installed)  fmt="nicht installiert" ;;
    en:version_not_installed)  fmt="not installed" ;;
    de:menu_install)           fmt="install          — Erstinstallation" ;;
    en:menu_install)           fmt="install          — First-time installation" ;;
    de:menu_update)            fmt="update           — MS-Pakete updaten" ;;
    en:menu_update)            fmt="update           — Update MS packages" ;;
    de:menu_status)            fmt="status           — Systemübersicht" ;;
    en:menu_status)            fmt="status           — System overview" ;;
    de:menu_repair)            fmt="repair           — Probleme automatisch fixen" ;;
    en:menu_repair)            fmt="repair           — Auto-fix common issues" ;;
    de:menu_reset)             fmt="reset-enrollment — Aus Intune austragen & neu enrollen" ;;
    en:menu_reset)             fmt="reset-enrollment — Unenroll & re-enroll from Intune" ;;
    de:menu_logs)              fmt="logs             — Log-Dump für Helpdesk" ;;
    en:menu_logs)              fmt="logs             — Log dump for helpdesk" ;;
    de:menu_uninstall)         fmt="uninstall        — Alles entfernen" ;;
    en:menu_uninstall)         fmt="uninstall        — Remove everything" ;;
    de:menu_version)           fmt="version          — Skript & Paketversionen" ;;
    en:menu_version)           fmt="version          — Script & package versions" ;;
    de:menu_quit)              fmt="Beenden" ;;
    en:menu_quit)              fmt="Quit" ;;
    de:menu_prompt)            fmt="  Auswahl: " ;;
    en:menu_prompt)            fmt="  Selection: " ;;
    de:help_install)           fmt="  --install          Erstinstallation (Repo, Edge, Intune)\n" ;;
    en:help_install)           fmt="  --install          First-time installation (repo, Edge, Intune)\n" ;;
    de:help_update)            fmt="  --update           Microsoft-Pakete updaten\n" ;;
    en:help_update)            fmt="  --update           Update Microsoft packages\n" ;;
    de:help_status)            fmt="  --status           Systemübersicht\n" ;;
    en:help_status)            fmt="  --status           System overview\n" ;;
    de:help_repair)            fmt="  --repair           Häufige Probleme automatisch beheben\n" ;;
    en:help_repair)            fmt="  --repair           Auto-fix common issues\n" ;;
    de:help_reset)             fmt="  --reset-enrollment Gerät aus Intune austragen & neu enrollen\n" ;;
    en:help_reset)             fmt="  --reset-enrollment Unenroll & re-enroll device from Intune\n" ;;
    de:help_logs)              fmt="  --logs             Log-Dump für Helpdesk (.tar.gz)\n" ;;
    en:help_logs)              fmt="  --logs             Log dump for helpdesk (.tar.gz)\n" ;;
    de:help_uninstall)         fmt="  --uninstall        Alle MS-Pakete entfernen\n" ;;
    en:help_uninstall)         fmt="  --uninstall        Remove all MS packages\n" ;;
    de:help_version)           fmt="  --version          Skript- und Paketversionen\n" ;;
    en:help_version)           fmt="  --version          Script and package versions\n" ;;
    de:help_lang)              fmt="  --lang=de|en       Sprache überschreiben (Standard: auto)\n" ;;
    en:help_lang)              fmt="  --lang=de|en       Override language (default: auto)\n" ;;
    de:help_no_flag)           fmt="\n  Ohne Flag: interaktives Menü\n\n" ;;
    en:help_no_flag)           fmt="\n  No flag: interactive menu\n\n" ;;
    *) fmt="[missing translation: ${key}]" ;;
  esac
  # shellcheck disable=SC2059
  printf "${fmt}" "$@"
}

# confirm with language-aware yes key (j=German, y=English)
confirm_yn() {
  local key="$1"
  local answer
  if [[ "${LANG_CODE}" == "de" ]]; then
    printf "${C_YELLOW}%s [j/N]: ${C_RESET}" "$(t "${key}")"
    read -r answer
    [[ "${answer,,}" == "j" ]]
  else
    printf "${C_YELLOW}%s [y/N]: ${C_RESET}" "$(t "${key}")"
    read -r answer
    [[ "${answer,,}" == "y" ]]
  fi
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/intune-bootstrap-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "${LOG_DIR}"

if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'
  C_RED='\033[0;31m'; C_CYAN='\033[0;36m'; C_BOLD='\033[1m'
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
# Helper functions
# -----------------------------------------------------------------------------
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log ERROR "$(t cmd_missing "$1")"
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
  log INFO "$(t run_sudo "$*")"
  sudo "$@" 2>&1 | tee -a "${LOG_FILE}"
}

# -----------------------------------------------------------------------------
# Variables (cached)
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
    log WARN "$(t cleanup_remove "${TMP_EDGE_DEB}")"
    rm -f "${TMP_EDGE_DEB}" || true
  fi
}
trap cleanup EXIT

# =============================================================================
# MODE: --version
# =============================================================================
cmd_version() {
  printf "\n${C_BOLD}intune-linux.sh${C_RESET} v%s\n\n" "${SCRIPT_VERSION}"
  printf "%-35s %s\n" "$(t version_pkg_header)" "Version"
  printf "%-35s %s\n" "-----------------------------------" "----------"
  for pkg in "${MS_PACKAGES[@]}"; do
    local ver
    if pkg_installed "${pkg}"; then
      ver="$(pkg_version "${pkg}")"
    else
      ver="$(t version_not_installed)"
    fi
    printf "%-35s %s\n" "${pkg}" "${ver}"
  done
  echo ""
}

# =============================================================================
# MODE: --status
# =============================================================================
cmd_status() {
  step "$(t step_status_pkgs)"
  for pkg in "${MS_PACKAGES[@]}"; do
    if pkg_installed "${pkg}"; then
      log INFO "  $(t pkg_status_ok "${pkg}" "$(pkg_version "${pkg}")")"
    else
      log WARN "  $(t pkg_status_fail "${pkg}")"
    fi
  done

  step "$(t step_status_repo)"
  if [[ -f "${KEYRING_PATH}" ]]; then
    log INFO "  $(t keyring_ok "${KEYRING_PATH}")"
  else
    log WARN "  $(t keyring_warn "${KEYRING_PATH}")"
  fi
  if [[ -f "${REPO_FILE}" ]]; then
    log INFO "  $(t repo_ok "${REPO_FILE}")"
  else
    log WARN "  $(t repo_warn "${REPO_FILE}")"
  fi

  step "$(t step_status_broker)"
  if systemctl is-active --quiet microsoft-identity-device-broker; then
    log INFO "  $(t broker_ok)"
  else
    log WARN "  $(t broker_warn)"
  fi

  step "$(t step_status_timer)"
  if systemctl --user is-active --quiet intune-agent.timer 2>/dev/null; then
    log INFO "  $(t timer_ok)"
  elif systemctl --user is-enabled --quiet intune-agent.timer 2>/dev/null; then
    log INFO "  $(t timer_enabled)"
  else
    log WARN "  $(t timer_warn)"
  fi

  step "$(t step_status_enroll)"
  if command -v dsreg >/dev/null 2>&1; then
    local reg_status prt_status
    reg_status="$(dsreg --status 2>/dev/null | awk '/Device Registration Status/ {print $NF}')"
    prt_status="$(dsreg --status 2>/dev/null | awk '/PRT Present/ {print $NF}')"
    log INFO "  $(t reg_status "${reg_status:-$(t unknown)}")"
    log INFO "  $(t prt_status "${prt_status:-$(t unknown)}")"
  else
    log WARN "  $(t dsreg_missing)"
  fi

  echo ""
  log INFO "$(t logfile_info "${LOG_FILE}")"
}

# =============================================================================
# MODE: --install
# =============================================================================
cmd_install() {
  log INFO "$(t logfile_info "${LOG_FILE}")"

  step "$(t step_check_cmds)"
  for cmd in curl gpg lsb_release apt-get sudo systemctl dpkg; do
    need_cmd "${cmd}"
    log INFO "$(t cmd_ok "${cmd}")"
  done

  step "$(t step_setup_repo "${CODENAME}" "${RELEASE}")"

  if [[ ! -f "${KEYRING_PATH}" ]]; then
    log INFO "$(t keyring_creating)"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor \
      | sudo tee "${KEYRING_PATH}" >/dev/null
    sudo chmod 644 "${KEYRING_PATH}"
    log INFO "$(t keyring_created "${KEYRING_PATH}")"
  else
    log INFO "$(t keyring_exists)"
  fi

  if [[ ! -f "${REPO_FILE}" ]]; then
    log INFO "$(t repo_creating)"
    echo "deb [arch=amd64 signed-by=${KEYRING_PATH}] \
https://packages.microsoft.com/ubuntu/${RELEASE}/prod ${CODENAME} main" \
      | sudo tee "${REPO_FILE}" >/dev/null
    log INFO "$(t repo_created "${REPO_FILE}")"
  else
    log INFO "$(t repo_exists)"
  fi

  step "$(t step_update_lists)"
  run_sudo apt-get update -q

  step "$(t step_install_pkg "microsoft-identity-broker")"
  if pkg_installed microsoft-identity-broker; then
    log INFO "$(t pkg_exists "microsoft-identity-broker")"
  else
    run_sudo apt-get install -y microsoft-identity-broker
    log INFO "$(t pkg_installed_ok "microsoft-identity-broker")"
  fi

  step "$(t step_install_edge)"
  if pkg_installed microsoft-edge-stable; then
    log INFO "$(t pkg_exists "microsoft-edge-stable")"
  elif [[ -n "${EDGE_DEB}" ]]; then
    log INFO "$(t edge_local_found "${EDGE_DEB}")"
    TMP_EDGE_DEB="/tmp/$(basename "${EDGE_DEB}")"
    cp -f "${EDGE_DEB}" "${TMP_EDGE_DEB}"
    chmod 644 "${TMP_EDGE_DEB}"
    run_sudo apt-get install -y "${TMP_EDGE_DEB}"
    log INFO "$(t edge_local_done)"
  else
    log WARN "$(t edge_repo_warn)"
    run_sudo apt-get install -y microsoft-edge-stable
    log INFO "$(t edge_repo_done)"
  fi

  step "$(t step_install_pkg "intune-portal")"
  if pkg_installed intune-portal; then
    log INFO "$(t pkg_exists "intune-portal")"
  else
    run_sudo apt-get install -y intune-portal
    log INFO "$(t pkg_installed_ok "intune-portal")"
  fi

  step "$(t step_daemon_reload)"
  if systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}"; then
    log INFO "$(t daemon_ok)"
  else
    log WARN "$(t daemon_fail)"
  fi

  step "$(t step_start_intune)"
  if command -v intune-portal >/dev/null 2>&1; then
    nohup intune-portal >/dev/null 2>&1 &
    log INFO "$(t intune_started "$!")"
  else
    log WARN "$(t intune_not_found)"
  fi

  echo ""
  log INFO "$(t summary_sep)"
  log INFO "$(t install_done)"
  log INFO "$(t logfile_info "${LOG_FILE}")"
  log INFO "$(t summary_sep)"
  echo ""
  log INFO "$(t install_next)"
  log INFO "$(t install_tip "$(basename "$0")")"
}

# =============================================================================
# MODE: --update
# =============================================================================
cmd_update() {
  step "$(t step_update_ms)"
  run_sudo apt-get update -q

  step "$(t step_update_pkgs)"
  run_sudo apt-get install -y --only-upgrade \
    microsoft-identity-broker \
    microsoft-edge-stable \
    intune-portal

  step "$(t step_versions)"
  cmd_version

  step "$(t step_daemon_reload)"
  systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}" || true

  log INFO "$(t update_done)"
  log INFO "$(t logfile_info "${LOG_FILE}")"
}

# =============================================================================
# MODE: --repair
# =============================================================================
cmd_repair() {
  local fixed=0

  step "$(t step_repair_repo)"
  if [[ ! -f "${KEYRING_PATH}" ]]; then
    log WARN "$(t keyring_missing)"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor \
      | sudo tee "${KEYRING_PATH}" >/dev/null
    sudo chmod 644 "${KEYRING_PATH}"
    log INFO "$(t keyring_fixed)"
    ((fixed++)) || true
  fi

  if [[ ! -f "${REPO_FILE}" ]]; then
    log WARN "$(t repo_missing)"
    echo "deb [arch=amd64 signed-by=${KEYRING_PATH}] \
https://packages.microsoft.com/ubuntu/${RELEASE}/prod ${CODENAME} main" \
      | sudo tee "${REPO_FILE}" >/dev/null
    log INFO "$(t repo_fixed)"
    ((fixed++)) || true
  fi

  step "$(t step_repair_pkgs)"
  local missing=()
  for pkg in "${MS_PACKAGES[@]}"; do
    if ! pkg_installed "${pkg}"; then
      log WARN "$(t pkg_missing_repair "${pkg}")"
      missing+=("${pkg}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    run_sudo apt-get update -q
    run_sudo apt-get install -y "${missing[@]}"
    log INFO "$(t pkgs_installed "${missing[*]}")"
    ((fixed++)) || true
  fi

  step "$(t step_repair_broker)"
  if ! systemctl is-active --quiet microsoft-identity-device-broker; then
    log WARN "$(t broker_stopped)"
    run_sudo systemctl restart microsoft-identity-device-broker
    sleep 2
    if systemctl is-active --quiet microsoft-identity-device-broker; then
      log INFO "$(t broker_restarted)"
      ((fixed++)) || true
    else
      log ERROR "$(t broker_fail)"
    fi
  else
    log INFO "$(t broker_running)"
  fi

  step "$(t step_repair_daemon)"
  if systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}"; then
    log INFO "$(t daemon_ok)"
  fi

  step "$(t step_repair_apt)"
  log INFO "$(t repair_apt_run)"
  run_sudo apt-get -f install -y

  echo ""
  if [[ ${fixed} -gt 0 ]]; then
    log INFO "$(t repair_done_n "${fixed}")"
  else
    log INFO "$(t repair_done_ok)"
  fi
  log INFO "$(t repair_tip "$(basename "$0")")"
  log INFO "$(t logfile_info "${LOG_FILE}")"
}

# =============================================================================
# MODE: --reset-enrollment
# =============================================================================
cmd_reset_enrollment() {
  echo ""
  log WARN "$(t reset_warn1)"
  log WARN "$(t reset_warn2)"
  echo ""
  if ! confirm_yn "reset_confirm"; then
    log INFO "$(t aborted)"
    exit 0
  fi

  step "$(t step_stop_intune)"
  systemctl --user stop intune-agent.timer 2>/dev/null | tee -a "${LOG_FILE}" || true
  systemctl --user stop intune-agent.service 2>/dev/null | tee -a "${LOG_FILE}" || true
  log INFO "$(t intune_stopped)"

  step "$(t step_leave_aad)"
  log WARN "$(t reset_no_leave)"
  log WARN "$(t reset_manual)"
  log WARN "$(t reset_manual_url)"
  log INFO "$(t reset_local_note)"

  step "$(t step_daemon_reload)"
  systemctl --user daemon-reload 2>&1 | tee -a "${LOG_FILE}" || true

  step "$(t step_start_intune)"
  if command -v intune-portal >/dev/null 2>&1; then
    nohup intune-portal >/dev/null 2>&1 &
    log INFO "$(t intune_started "$!")"
  else
    log WARN "$(t intune_not_found)"
  fi

  echo ""
  log INFO "$(t reset_done)"
  log INFO "$(t reset_next)"
  log INFO "$(t logfile_info "${LOG_FILE}")"
}

# =============================================================================
# MODE: --logs
# =============================================================================
cmd_logs() {
  local dump_dir; dump_dir="$(mktemp -d)"
  local archive="${HOME}/Downloads/intune-logdump-$(date +%Y%m%d_%H%M%S).tar.gz"

  step "$(t step_collect_logs)"

  if ls "${LOG_DIR}"/intune-bootstrap-*.log >/dev/null 2>&1; then
    cp "${LOG_DIR}"/intune-bootstrap-*.log "${dump_dir}/"
    log INFO "$(t logs_scripts)"
  fi

  if command -v dsreg >/dev/null 2>&1; then
    dsreg --status > "${dump_dir}/dsreg-status.txt" 2>&1 || true
    log INFO "$(t logs_dsreg)"
  fi

  journalctl -u microsoft-identity-device-broker \
    --no-pager -n 200 > "${dump_dir}/broker-journal.txt" 2>&1 || true
  log INFO "$(t logs_broker)"

  journalctl --user -u intune-agent \
    --no-pager -n 200 > "${dump_dir}/intune-agent-journal.txt" 2>&1 || true
  log INFO "$(t logs_agent)"

  cmd_version > "${dump_dir}/package-versions.txt" 2>&1
  log INFO "$(t logs_versions)"

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
  log INFO "$(t logs_sysinfo)"

  tar -czf "${archive}" -C "${dump_dir}" . 2>&1 | tee -a "${LOG_FILE}"
  rm -rf "${dump_dir}"

  echo ""
  log INFO "$(t logs_done "${archive}")"
  log INFO "$(t logs_send)"
}

# =============================================================================
# MODE: --uninstall
# =============================================================================
cmd_uninstall() {
  echo ""
  log WARN "$(t uninstall_warn)"
  for pkg in "${MS_PACKAGES[@]}"; do
    log WARN "  - ${pkg}"
  done
  echo ""
  if ! confirm_yn "uninstall_confirm"; then
    log INFO "$(t aborted)"
    exit 0
  fi

  step "$(t step_stop_services)"
  systemctl --user stop intune-agent.timer 2>/dev/null | tee -a "${LOG_FILE}" || true
  systemctl --user stop intune-agent.service 2>/dev/null | tee -a "${LOG_FILE}" || true
  run_sudo systemctl stop microsoft-identity-device-broker 2>/dev/null || true
  log INFO "$(t uninstall_stopped)"

  step "$(t step_remove_pkgs)"
  run_sudo apt-get remove -y --purge \
    intune-portal \
    microsoft-edge-stable \
    microsoft-identity-broker
  run_sudo apt-get autoremove -y
  log INFO "$(t uninstall_done_pkgs)"

  echo ""
  if confirm_yn "uninstall_repo_confirm"; then
    step "$(t step_remove_repo)"
    sudo rm -f "${REPO_FILE}" && log INFO "$(t repo_removed "${REPO_FILE}")" || true
    sudo rm -f "${KEYRING_PATH}" && log INFO "$(t keyring_removed "${KEYRING_PATH}")" || true
    run_sudo apt-get update -q
  fi

  echo ""
  log INFO "$(t uninstall_done)"
  log INFO "$(t logfile_info "${LOG_FILE}")"
}

# =============================================================================
# Interactive menu (no flag)
# =============================================================================
show_menu() {
  clear
  printf "\n${C_BOLD}  intune-linux.sh v%s${C_RESET}\n" "${SCRIPT_VERSION}"
  printf "  github.com/swayaa/intune-linux\n\n"
  printf "  ${C_CYAN}1)${C_RESET} %s\n" "$(t menu_install)"
  printf "  ${C_CYAN}2)${C_RESET} %s\n" "$(t menu_update)"
  printf "  ${C_CYAN}3)${C_RESET} %s\n" "$(t menu_status)"
  printf "  ${C_CYAN}4)${C_RESET} %s\n" "$(t menu_repair)"
  printf "  ${C_CYAN}5)${C_RESET} %s\n" "$(t menu_reset)"
  printf "  ${C_CYAN}6)${C_RESET} %s\n" "$(t menu_logs)"
  printf "  ${C_CYAN}7)${C_RESET} %s\n" "$(t menu_uninstall)"
  printf "  ${C_CYAN}8)${C_RESET} %s\n" "$(t menu_version)"
  printf "  ${C_CYAN}q)${C_RESET} %s\n\n" "$(t menu_quit)"
  printf "%s" "$(t menu_prompt)"
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
    *) log WARN "$(t invalid_menu "${choice}")" ; sleep 1 ; show_menu ;;
  esac
}

# =============================================================================
# Entry Point
# =============================================================================
_CMD="${1:-}"
case "${_CMD}" in --lang=de|--lang=en) _CMD="${2:-}" ;; esac

case "${_CMD}" in
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
    printf "%s" "$(t help_install)"
    printf "%s" "$(t help_update)"
    printf "%s" "$(t help_status)"
    printf "%s" "$(t help_repair)"
    printf "%s" "$(t help_reset)"
    printf "%s" "$(t help_logs)"
    printf "%s" "$(t help_uninstall)"
    printf "%s" "$(t help_version)"
    printf "%s" "$(t help_lang)"
    printf "%s" "$(t help_no_flag)"
    ;;
  "") show_menu ;;
  *)
    log ERROR "$(t invalid_option "${_CMD}")"
    printf "%s\n" "$(t hint_help "$(basename "$0")")"
    exit 1
    ;;
esac
