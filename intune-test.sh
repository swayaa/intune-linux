#!/usr/bin/env bash
# =============================================================================
# intune-test.sh — Automatischer Testlauf für intune-linux.sh
# =============================================================================
set -uo pipefail

SCRIPT="${HOME}/Downloads/intune-linux.sh"
TEST_LOG="${HOME}/Downloads/intune-testrun-$(date +%Y%m%d_%H%M%S).log"
PASS=0
FAIL=0
SKIP=0

# -----------------------------------------------------------------------------
# Farben
# -----------------------------------------------------------------------------
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

# -----------------------------------------------------------------------------
# Hilfsfunktionen
# -----------------------------------------------------------------------------
log_raw() { printf "%s\n" "$*" | tee -a "${TEST_LOG}"; }

header() {
  echo "" | tee -a "${TEST_LOG}"
  printf "${C_CYAN}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n" \
    | tee -a "${TEST_LOG}"
  printf "${C_CYAN}${C_BOLD}  %s${C_RESET}\n" "$*" | tee -a "${TEST_LOG}"
  printf "${C_CYAN}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n" \
    | tee -a "${TEST_LOG}"
}

pass() {
  printf "${C_GREEN}  ✓ PASS${C_RESET} — %s\n" "$*" | tee -a "${TEST_LOG}"
  ((PASS++)) || true
}

fail() {
  printf "${C_RED}  ✗ FAIL${C_RESET} — %s\n" "$*" | tee -a "${TEST_LOG}"
  ((FAIL++)) || true
}

skip() {
  printf "${C_YELLOW}  ⊘ SKIP${C_RESET} — %s\n" "$*" | tee -a "${TEST_LOG}"
  ((SKIP++)) || true
}

run_script() {
  # Führt das Skript aus und gibt Output zurück
  # $1 = Flag (z.B. "--repair"), $2 = optionaler stdin Input (z.B. "j\nj")
  local flag="${1:-}"
  local input="${2:-}"
  if [[ -n "${input}" ]]; then
    printf "%s" "${input}" | "${SCRIPT}" ${flag} 2>&1
  else
    "${SCRIPT}" ${flag} 2>&1
  fi
}

assert_contains() {
  local output="$1"
  local needle="$2"
  local label="$3"
  if echo "${output}" | grep -q "${needle}"; then
    pass "${label}"
  else
    fail "${label} (erwartet: '${needle}')"
    echo "--- Output ---" >> "${TEST_LOG}"
    echo "${output}" >> "${TEST_LOG}"
    echo "--- Ende ---" >> "${TEST_LOG}"
  fi
}

assert_not_contains() {
  local output="$1"
  local needle="$2"
  local label="$3"
  if ! echo "${output}" | grep -q "${needle}"; then
    pass "${label}"
  else
    fail "${label} (sollte NICHT enthalten: '${needle}')"
    echo "--- Output ---" >> "${TEST_LOG}"
    echo "${output}" >> "${TEST_LOG}"
    echo "--- Ende ---" >> "${TEST_LOG}"
  fi
}

assert_pkg_installed() {
  local pkg="$1"
  if dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
    pass "${pkg} ist installiert"
  else
    fail "${pkg} ist NICHT installiert"
  fi
}

assert_pkg_missing() {
  local pkg="$1"
  if ! dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
    pass "${pkg} ist korrekt entfernt"
  else
    fail "${pkg} sollte nicht installiert sein"
  fi
}

# -----------------------------------------------------------------------------
# Voraussetzungen
# -----------------------------------------------------------------------------
echo "" | tee "${TEST_LOG}"
printf "${C_BOLD}  intune-linux.sh — Automatischer Testlauf${C_RESET}\n" \
  | tee -a "${TEST_LOG}"
printf "  Logfile: %s\n" "${TEST_LOG}" | tee -a "${TEST_LOG}"
printf "  Datum:   %s\n" "$(date)" | tee -a "${TEST_LOG}"
echo "" | tee -a "${TEST_LOG}"

if [[ ! -f "${SCRIPT}" ]]; then
  printf "${C_RED}FEHLER: %s nicht gefunden!${C_RESET}\n" "${SCRIPT}"
  exit 1
fi

if [[ ! -x "${SCRIPT}" ]]; then
  chmod +x "${SCRIPT}"
fi

# Sudo-Credentials cachen — einmal Passwort, dann läuft alles durch
printf "${C_YELLOW}Sudo-Passwort einmalig eingeben (wird für alle Tests gecacht):${C_RESET}\n"
sudo -v || { printf "${C_RED}sudo fehlgeschlagen — Abbruch.${C_RESET}\n"; exit 1; }

# Sudo-Cache alle 60s auffrischen (läuft im Hintergrund)
( while true; do sudo -v; sleep 50; done ) &
SUDO_REFRESH_PID=$!
trap "kill ${SUDO_REFRESH_PID} 2>/dev/null || true" EXIT

# =============================================================================
# TEST 01 — --version
# =============================================================================
header "TEST 01 — --version"
OUT="$(run_script --version)"
log_raw "${OUT}"
assert_contains "${OUT}" "v2.0.1"   "Skriptversion ist v2.0.1"
assert_contains "${OUT}" "microsoft-identity-broker" "Identity Broker in Ausgabe"
assert_contains "${OUT}" "microsoft-edge-stable"     "Edge in Ausgabe"
assert_contains "${OUT}" "intune-portal"             "Intune Portal in Ausgabe"

# =============================================================================
# TEST 02 — --status (sauberer Zustand)
# =============================================================================
header "TEST 02 — --status (sauberer Zustand)"
OUT="$(run_script --status)"
log_raw "${OUT}"
assert_contains     "${OUT}" "microsoft-identity-broker"  "Broker in Status"
assert_contains     "${OUT}" "microsoft-edge-stable"      "Edge in Status"
assert_contains     "${OUT}" "intune-portal"              "Intune Portal in Status"
assert_not_contains "${OUT}" "\[ERROR\]"                  "Keine ERROR-Zeilen"
assert_contains     "${OUT}" "Registered"                 "Gerät ist registriert"
assert_contains     "${OUT}" "PRT Present"                "PRT vorhanden"
assert_contains     "${OUT}" "intune-agent.timer"         "Timer-Status angezeigt"
assert_not_contains "${OUT}" "✗ intune-agent.timer nicht eingerichtet" \
                             "Timer-WARN nicht fälschlicherweise gesetzt"

# =============================================================================
# TEST 03 — --repair (nichts kaputt)
# =============================================================================
header "TEST 03 — --repair (nichts kaputt)"
OUT="$(run_script --repair)"
log_raw "${OUT}"
assert_contains "${OUT}" "kein Problem gefunden" "Repair meldet kein Problem"
assert_not_contains "${OUT}" "\[ERROR\]"         "Keine ERROR-Zeilen"

# =============================================================================
# TEST 04 — Keyring entfernt → --repair
# =============================================================================
header "TEST 04 — Keyring entfernt → --repair"
sudo rm -f /usr/share/keyrings/microsoft.gpg
OUT="$(run_script --repair)"
log_raw "${OUT}"
assert_contains "${OUT}" "Keyring repariert"           "Keyring wurde repariert"
assert_contains "${OUT}" "Problem(e) behoben"          "Mind. 1 Problem behoben"
[[ -f /usr/share/keyrings/microsoft.gpg ]] \
  && pass "Keyring-Datei existiert wieder" \
  || fail "Keyring-Datei fehlt nach Repair"

# =============================================================================
# TEST 05 — Repo entfernt → --repair
# =============================================================================
header "TEST 05 — Repo entfernt → --repair"
REPO_FILE="/etc/apt/sources.list.d/microsoft-ubuntu-$(lsb_release -cs)-prod.list"
sudo rm -f "${REPO_FILE}"
OUT="$(run_script --repair)"
log_raw "${OUT}"
assert_contains "${OUT}" "Repo repariert"     "Repo wurde repariert"
assert_contains "${OUT}" "Problem(e) behoben" "Mind. 1 Problem behoben"
[[ -f "${REPO_FILE}" ]] \
  && pass "Repo-Datei existiert wieder" \
  || fail "Repo-Datei fehlt nach Repair"

# =============================================================================
# TEST 06 — Broker gestoppt → --repair
# =============================================================================
header "TEST 06 — Broker gestoppt → --repair"
sudo systemctl stop microsoft-identity-device-broker
OUT="$(run_script --repair)"
log_raw "${OUT}"
assert_contains "${OUT}" "Broker erfolgreich neugestartet" "Broker wurde neugestartet"
systemctl is-active --quiet microsoft-identity-device-broker \
  && pass "Broker läuft wieder" \
  || fail "Broker läuft NICHT nach Repair"

# =============================================================================
# TEST 07 — intune-portal entfernt → --repair  [FIX v2.0.1]
# =============================================================================
header "TEST 07 — intune-portal via dpkg -r entfernt → --repair"
sudo dpkg -r intune-portal 2>&1 | tee -a "${TEST_LOG}" || true
assert_pkg_missing "intune-portal"
OUT="$(run_script --repair)"
log_raw "${OUT}"
assert_contains "${OUT}" "intune-portal" "intune-portal in Repair-Output"
assert_pkg_installed "intune-portal"

# =============================================================================
# TEST 08 — Alles auf einmal kaputt → --repair
# =============================================================================
header "TEST 08 — Alles auf einmal kaputt → --repair"
sudo rm -f /usr/share/keyrings/microsoft.gpg
sudo rm -f "${REPO_FILE}"
sudo systemctl stop microsoft-identity-device-broker
sudo dpkg -r intune-portal 2>&1 | tee -a "${TEST_LOG}" || true
OUT="$(run_script --repair)"
log_raw "${OUT}"
assert_contains "${OUT}" "Keyring repariert"              "Keyring repariert"
assert_contains "${OUT}" "Repo repariert"                 "Repo repariert"
assert_contains "${OUT}" "Broker erfolgreich neugestartet" "Broker repariert"
assert_contains "${OUT}" "intune-portal"                  "intune-portal repariert"
assert_pkg_installed "intune-portal"

# =============================================================================
# TEST 09 — --status nach allen Repairs
# =============================================================================
header "TEST 09 — --status nach allen Repairs"
OUT="$(run_script --status)"
log_raw "${OUT}"
assert_contains     "${OUT}" "✓ microsoft-identity-broker" "Broker grün"
assert_contains     "${OUT}" "✓ microsoft-edge-stable"     "Edge grün"
assert_contains     "${OUT}" "✓ intune-portal"             "Intune grün"
assert_contains     "${OUT}" "✓ Keyring vorhanden"         "Keyring grün"
assert_contains     "${OUT}" "✓ Repo vorhanden"            "Repo grün"
assert_not_contains "${OUT}" "\[ERROR\]"                   "Keine ERROR-Zeilen"

# =============================================================================
# TEST 10 — --logs
# =============================================================================
header "TEST 10 — --logs"
OUT="$(run_script --logs)"
log_raw "${OUT}"
DUMP="$(ls "${HOME}/Downloads"/intune-logdump-*.tar.gz 2>/dev/null | tail -n1 || true)"
if [[ -n "${DUMP}" && -f "${DUMP}" ]]; then
  pass "Log-Dump erstellt: $(basename "${DUMP}")"
  SIZE="$(du -h "${DUMP}" | cut -f1)"
  log_raw "    Größe: ${SIZE}"
else
  fail "Log-Dump nicht gefunden"
fi

# =============================================================================
# TEST 11 — --uninstall
# =============================================================================
header "TEST 11 — --uninstall"
OUT="$(printf "j\nj\n" | run_script --uninstall)"
log_raw "${OUT}"
assert_pkg_missing "intune-portal"
assert_pkg_missing "microsoft-edge-stable"
assert_pkg_missing "microsoft-identity-broker"
[[ ! -f /usr/share/keyrings/microsoft.gpg ]] \
  && pass "Keyring entfernt" \
  || fail "Keyring noch vorhanden"
[[ ! -f "${REPO_FILE}" ]] \
  && pass "Repo entfernt" \
  || fail "Repo noch vorhanden"

# =============================================================================
# TEST 12 — --install
# =============================================================================
header "TEST 12 — --install"
OUT="$(run_script --install)"
log_raw "${OUT}"
assert_pkg_installed "microsoft-identity-broker"
assert_pkg_installed "microsoft-edge-stable"
assert_pkg_installed "intune-portal"
assert_contains "${OUT}" "Installation abgeschlossen" "Install-Abschluss-Meldung"
assert_contains "${OUT}" "Intune Portal gestartet"    "Intune Portal gestartet"
[[ -f /usr/share/keyrings/microsoft.gpg ]] \
  && pass "Keyring vorhanden nach Install" \
  || fail "Keyring fehlt nach Install"
[[ -f "${REPO_FILE}" ]] \
  && pass "Repo vorhanden nach Install" \
  || fail "Repo fehlt nach Install"

# =============================================================================
# ZUSAMMENFASSUNG
# =============================================================================
TOTAL=$((PASS + FAIL + SKIP))
echo "" | tee -a "${TEST_LOG}"
printf "${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n" \
  | tee -a "${TEST_LOG}"
printf "${C_BOLD}  ERGEBNIS: %d/%d Tests bestanden${C_RESET}\n" \
  "${PASS}" "${TOTAL}" | tee -a "${TEST_LOG}"
printf "  ${C_GREEN}✓ PASS: %d${C_RESET}   ${C_RED}✗ FAIL: %d${C_RESET}   ${C_YELLOW}⊘ SKIP: %d${C_RESET}\n" \
  "${PASS}" "${FAIL}" "${SKIP}" | tee -a "${TEST_LOG}"
printf "${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n" \
  | tee -a "${TEST_LOG}"
echo "" | tee -a "${TEST_LOG}"
printf "  Vollständiger Log: %s\n\n" "${TEST_LOG}" | tee -a "${TEST_LOG}"

if [[ ${FAIL} -eq 0 ]]; then
  printf "${C_GREEN}${C_BOLD}  Alle Tests bestanden 🚀${C_RESET}\n\n" \
    | tee -a "${TEST_LOG}"
  exit 0
else
  printf "${C_RED}${C_BOLD}  %d Test(s) fehlgeschlagen — bitte Log prüfen.${C_RESET}\n\n" \
    "${FAIL}" | tee -a "${TEST_LOG}"
  exit 1
fi
