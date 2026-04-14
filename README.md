# intune-linux

> Microsoft Intune Bootstrap für Ubuntu/Debian — vollautomatisch, mit Logging und Admin-Modi.

[![Version](https://img.shields.io/badge/version-2.0.1-blue)](https://github.com/swayaa/intune-linux/releases)
[![Shell](https://img.shields.io/badge/shell-bash-green)](https://github.com/swayaa/intune-linux)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%2024.04-orange)](https://github.com/swayaa/intune-linux)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

---

## Was macht dieses Skript?

Richtet ein Ubuntu-Gerät vollautomatisch für Microsoft Intune ein:

- Microsoft Paketquelle + GPG-Keyring einrichten
- Microsoft Identity Broker installieren
- Microsoft Edge installieren (lokal oder aus Repo)
- Intune Portal installieren & starten
- Vollständiges Logging jedes Schritts

Nach dem Skript ist nur noch ein manueller Schritt nötig: **Firmenanmeldung im Intune Portal.**

---

## Voraussetzungen

| Anforderung | Details |
|---|---|
| OS | Ubuntu 24.04 LTS (Noble) |
| Architektur | amd64 |
| Rechte | sudo-Berechtigung |
| Abhängigkeiten | `curl`, `gpg`, `lsb_release`, `apt-get`, `systemctl`, `dpkg` |

---

## Schnellstart

```bash
curl -fsSL https://raw.githubusercontent.com/swayaa/intune-linux/main/intune-linux.sh \
  -o ~/Downloads/intune-linux.sh \
  && chmod +x ~/Downloads/intune-linux.sh \
  && ~/Downloads/intune-linux.sh
```

Ohne Argumente startet das **interaktive Menü**.

---

## Verwendung

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
| `--help` | Hilfe anzeigen |

---

## Was wird installiert?

| Paket | Beschreibung |
|---|---|
| `microsoft-identity-broker` | Azure AD / Entra ID Authentifizierung |
| `microsoft-edge-stable` | Microsoft Edge Browser |
| `intune-portal` | Intune Enrollment & Compliance Portal |

---

## Logging

Jeder Lauf erzeugt ein Logfile unter:

```
~/.local/log/intune-bootstrap-YYYYMMDD_HHMMSS.log
```

Mit `--logs` werden alle Logs + Systeminfo als `.tar.gz` gepackt — ideal für den Helpdesk.

---

## Edge — lokal oder Repo

Wenn eine lokale Edge-DEB in `~/Downloads` liegt (`microsoft-edge-stable_*_amd64.deb`), wird diese bevorzugt. Sonst wird Edge direkt aus dem Microsoft-Repo installiert.

---

## Getestet auf

| OS | Version | Status |
|---|---|---|
| Ubuntu | 24.04 LTS (Noble) | ✅ |

---

## Versionen

| Version | Änderungen |
|---|---|
| v2.0.0 | Alle Admin-Modi, interaktives Menü, erweitertes Logging |
| v1.0.0 | Erstveröffentlichung — Grundinstallation mit Logging |

---

## Lizenz

MIT — siehe [LICENSE](LICENSE)
