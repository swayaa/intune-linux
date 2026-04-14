# intune-linux

[![Version](https://img.shields.io/badge/version-2.1.0-blue)](https://github.com/swayaa/intune-linux/releases)
[![Shell](https://img.shields.io/badge/shell-bash-green)](https://github.com/swayaa/intune-linux)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2024.04-orange)](https://github.com/swayaa/intune-linux)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

---

## 🇩🇪 Deutsch

> Microsoft Intune Bootstrap für Ubuntu/Debian — vollautomatisch, mit Logging, Admin-Modi und DE/EN Lokalisierung.

### Was macht dieses Skript?

Richtet ein Ubuntu-Gerät vollautomatisch für Microsoft Intune ein:

- Microsoft Paketquelle + GPG-Keyring einrichten
- Microsoft Identity Broker installieren
- Microsoft Edge installieren (lokal oder aus Repo)
- Intune Portal installieren & starten
- Vollständiges Logging jedes Schritts

Nach dem Skript ist nur noch ein manueller Schritt nötig: **Firmenanmeldung im Intune Portal.**

### Voraussetzungen

| Anforderung | Details |
|---|---|
| OS | Ubuntu 24.04 LTS (Noble) |
| Architektur | amd64 |
| Rechte | sudo-Berechtigung |
| Abhängigkeiten | `curl`, `gpg`, `lsb_release`, `apt-get`, `systemctl`, `dpkg` |

### Schnellstart

```bash
curl -fsSL https://raw.githubusercontent.com/swayaa/intune-linux/main/intune-linux.sh \
  -o ~/Downloads/intune-linux.sh \
  && chmod +x ~/Downloads/intune-linux.sh \
  && ~/Downloads/intune-linux.sh
```

Ohne Argumente startet das **interaktive Menü**.

### Verwendung

```bash
./intune-linux.sh [OPTION]
```

| Option | Beschreibung |
|---|---|
| *(kein Flag)* | Interaktives Menü |
| `--install` | Erstinstallation (Repo, Broker, Edge, Intune) |
| `--update` | Alle Microsoft-Pakete updaten |
| `--status` | Systemübersicht: Pakete, Broker, Enrollment |
| `--repair` | Häufige Probleme automatisch beheben |
| `--reset-enrollment` | Gerät aus Intune austragen & neu enrollen |
| `--logs` | Log-Dump als `.tar.gz` für den Helpdesk |
| `--uninstall` | Alle Microsoft-Pakete & Repo entfernen |
| `--version` | Skript- und Paketversionen anzeigen |
| `--lang=de\|en` | Sprache überschreiben (Standard: auto via `$LANG`) |
| `--help` | Hilfe anzeigen |

### Sprache

Das Skript erkennt die Systemsprache automatisch über `$LANG`. Deutsch wird verwendet wenn `$LANG` mit `de_` beginnt, sonst Englisch.

```bash
./intune-linux.sh --lang=de --status
./intune-linux.sh --lang=en --install
```

### Was wird installiert?

| Paket | Beschreibung |
|---|---|
| `microsoft-identity-broker` | Azure AD / Entra ID Authentifizierung |
| `microsoft-edge-stable` | Microsoft Edge Browser |
| `intune-portal` | Intune Enrollment & Compliance Portal |

### Logging

Jeder Lauf erzeugt ein Logfile unter:

```
~/.local/log/intune-bootstrap-YYYYMMDD_HHMMSS.log
```

Mit `--logs` werden alle Logs + Systeminfo als `.tar.gz` gepackt — ideal für den Helpdesk.

### Edge — lokal oder Repo

Wenn eine lokale Edge-DEB in `~/Downloads` liegt (`microsoft-edge-stable_*_amd64.deb`), wird diese bevorzugt. Sonst wird Edge direkt aus dem Microsoft-Repo installiert.

### Getestet auf

| Gerät | CPU | OS | Status |
|---|---|---|---|
| Dell Latitude 7420 | Intel Core i5-1145G7 (11th Gen) | Ubuntu 24.04 LTS | ✅ |
| MSI MS-7C91 | AMD Ryzen 5 5600X | Ubuntu 24.04 LTS | ✅ |

### Versionen

| Version | Änderungen |
|---|---|
| v2.1.0 | DE/EN Lokalisierung, Auto-Detection via `$LANG`, `--lang=` Flag |
| v2.0.1 | fix: `pkg_installed`, Timer `is-enabled`, daemon-reload, Testsuite (49 Tests) |
| v2.0.0 | Alle Admin-Modi, interaktives Menü, erweitertes Logging |
| v1.0.0 | Erstveröffentlichung |

---

## 🇬🇧 English

> Microsoft Intune Bootstrap for Ubuntu/Debian — fully automated, with logging, admin modes and DE/EN localization.

### What does this script do?

Sets up an Ubuntu device for Microsoft Intune automatically:

- Set up Microsoft package source + GPG keyring
- Install Microsoft Identity Broker
- Install Microsoft Edge (local DEB or from repository)
- Install & launch Intune Portal
- Full logging of every step

After the script, only one manual step remains: **signing in with your company account in the Intune Portal.**

### Requirements

| Requirement | Details |
|---|---|
| OS | Ubuntu 24.04 LTS (Noble) |
| Architecture | amd64 |
| Permissions | sudo access |
| Dependencies | `curl`, `gpg`, `lsb_release`, `apt-get`, `systemctl`, `dpkg` |

### Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/swayaa/intune-linux/main/intune-linux.sh \
  -o ~/Downloads/intune-linux.sh \
  && chmod +x ~/Downloads/intune-linux.sh \
  && ~/Downloads/intune-linux.sh
```

Without arguments, the **interactive menu** starts.

### Usage

```bash
./intune-linux.sh [OPTION]
```

| Option | Description |
|---|---|
| *(no flag)* | Interactive menu |
| `--install` | First-time installation (repo, broker, Edge, Intune) |
| `--update` | Update all Microsoft packages |
| `--status` | System overview: packages, broker, enrollment |
| `--repair` | Auto-fix common issues |
| `--reset-enrollment` | Unenroll device & re-enroll from Intune |
| `--logs` | Log dump as `.tar.gz` for helpdesk |
| `--uninstall` | Remove all Microsoft packages & repository |
| `--version` | Show script and package versions |
| `--lang=de\|en` | Override language (default: auto via `$LANG`) |
| `--help` | Show help |

### Language

The script automatically detects the system language via `$LANG`. German is used when `$LANG` starts with `de_`, otherwise English.

```bash
./intune-linux.sh --lang=de --status
./intune-linux.sh --lang=en --install
```

### What gets installed?

| Package | Description |
|---|---|
| `microsoft-identity-broker` | Azure AD / Entra ID authentication |
| `microsoft-edge-stable` | Microsoft Edge browser |
| `intune-portal` | Intune enrollment & compliance portal |

### Logging

Each run creates a logfile at:

```
~/.local/log/intune-bootstrap-YYYYMMDD_HHMMSS.log
```

Use `--logs` to pack all logs + system info into a `.tar.gz` — ideal for helpdesk support.

### Edge — local or repository

If a local Edge DEB is found in `~/Downloads` (`microsoft-edge-stable_*_amd64.deb`), it will be used. Otherwise Edge is installed directly from the Microsoft repository.

### Tested on

| Device | CPU | OS | Status |
|---|---|---|---|
| Dell Latitude 7420 | Intel Core i5-1145G7 (11th Gen) | Ubuntu 24.04 LTS | ✅ |
| MSI MS-7C91 | AMD Ryzen 5 5600X | Ubuntu 24.04 LTS | ✅ |

### Changelog

| Version | Changes |
|---|---|
| v2.1.0 | DE/EN localization, auto-detection via `$LANG`, `--lang=` flag |
| v2.0.1 | fix: `pkg_installed`, timer `is-enabled`, daemon-reload, test suite (49 tests) |
| v2.0.0 | All admin modes, interactive menu, extended logging |
| v1.0.0 | Initial release |

---

## License

MIT — see [LICENSE](LICENSE)
