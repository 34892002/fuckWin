<div align="center">

# 🖕 fuckWin

**Take back control of your Windows PC.**  
A lightweight, transparent PowerShell tool for managing automatic updates, Windows AI features, telemetry settings, classic UX tweaks, and bundled apps on Windows 10 and 11.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue.svg)](https://microsoft.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-brightgreen.svg)](https://github.com/PowerShell/PowerShell)

[Quick Start](#-quick-start) • [Features](#-features) • [Security & Transparency](#-security--transparency) • [FAQ](#-faq) • [License](#-license)

</div>

---

## ⚡ Quick Start

Open **Windows PowerShell as Administrator** and launch the interactive menu:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://fuckwin.lol/fuckwin.ps1 | iex
```

This command follows the `fuckwin.lol` redirect and executes the current `main` branch in memory. To inspect the script first or use parameters such as `-Action`, `-UpdateMode`, and `-WhatIf`, download it locally:

```powershell
irm https://fuckwin.lol/fuckwin.ps1 -OutFile fuckwin.ps1
Set-ExecutionPolicy Bypass -Scope Process -Force
.\fuckwin.ps1 -Action Updates -UpdateMode Lockdown -WhatIf
```

The default update mode is `Notify`, which keeps manual updates available. The `Disable` and `Lockdown` modes block Windows security updates too. Review the script and create a restore point before using either mode.

---

## 🔥 Features

* **🛑 Control Windows Updates**
  * Choose `Notify`, `Disable`, or `Lockdown` profiles with policy, service, and scheduled-task verification.
* **🧠 Disable Windows AI Features**
  * Apply policies that disable Windows Copilot and Recall where those policies are supported.
* **🕵️ Reduce Telemetry & Promotions**
  * Set telemetry policy to the lowest supported level and disable advertising ID, tailored experiences, and consumer suggestions.
* **🛠️ Restore Classic UX**
  * Restore the Windows 11 full-context right-click menu natively (say goodbye to "Show more options").
  * Disable Bing web search in the Start Menu to keep file search purely local.
* **🧹 UWP Bloatware Purge**
  * Uninstall a conservative list of consumer Appx packages for the current user while leaving system-critical packages alone.

---

## 🧰 Usage

```powershell
# Interactive menu
.\fuckwin.ps1

# Keep updates manual: notify before download and installation (default)
.\fuckwin.ps1 -Action Updates -UpdateMode Notify

# Block automatic updates using policy, core services, and selected tasks
.\fuckwin.ps1 -Action Updates -UpdateMode Disable

# Also target Windows Update Medic and the full known task set
.\fuckwin.ps1 -Action Updates -UpdateMode Lockdown

# Run another module
.\fuckwin.ps1 -Action Privacy
.\fuckwin.ps1 -Action AI
.\fuckwin.ps1 -Action UX
.\fuckwin.ps1 -Action Bloatware

# Run every module after a confirmation prompt
.\fuckwin.ps1 -Action All

# Show OS and update-service state; administrator rights are not required
.\fuckwin.ps1 -Action Audit

# Restore registry, service, and scheduled-task state saved before changes
.\fuckwin.ps1 -Action Restore
```

Use `-Force` for unattended execution and `-WhatIf` to preview supported changes. `Lockdown` requires typing `LOCKDOWN` unless `-Force` is supplied. Backups are stored in `%ProgramData%\fuckWin\backup.json`. Appx package removal is not automatically reversed by `Restore`; reinstall removed apps from Microsoft Store if needed.

### Update modes

| Mode | Behavior | Impact |
| --- | --- | --- |
| `Notify` | Uses documented Windows Update policies to notify before download/install and avoid automatic restarts while signed in | Recommended default; manual updates remain available |
| `Disable` | Sets `NoAutoUpdate`, disables `wuauserv`, `UsoSvc`, and selected scan/start tasks | Store, drivers, optional features, and manual update checks can be affected |
| `Lockdown` | Adds `WaaSMedicSvc` and the full known Orchestrator/Medic task set, then verifies accessible items | Strongest mode; Windows may refuse protected changes or restore them later |

Switching to `Notify` restores update services and tasks previously changed by this tool before applying notification policy. `Lockdown` deliberately does **not** disable `BITS` or `TrustedInstaller`, change system-file permissions, rename DLL/EXE files, or block Microsoft domains.

No mode can guarantee permanent behavior across every Windows build or feature upgrade. Run `Audit` after major Windows updates to check whether services or tasks were recreated or re-enabled.

### Modules

| Action | Changes |
| --- | --- |
| `Updates` | Applies the selected `Notify`, `Disable`, or `Lockdown` update profile |
| `Privacy` | Reduces telemetry and disables advertising and consumer-content settings |
| `AI` | Disables Copilot and Recall through Windows policies |
| `UX` | Enables the classic Windows 11 context menu and disables Bing Start search |
| `Bloatware` | Removes selected consumer Appx packages for the current user |
| `Restore` | Restores backed-up registry, service, and task state |
| `Audit` | Reports update policies, services, known tasks, and backup availability |

---

## 🛡️ Security & Transparency

`fuckWin` follows strict open-source security principles:

1. **Pure Plain-Text Script**: No pre-compiled `.exe` or obfuscated `.dll` files. Audit every registry change and command yourself.
2. **Zero Background Footprint**: Runs once, cleans your system, and exits. Leaves no background tracking daemons.
3. **No Activation Bypasses**: Contains no KMS activators, cracks, or license-bypass code.
4. **Preview and Restore**: Supports PowerShell `-WhatIf`, records original settings before applying changes, and verifies accessible services and tasks.
5. **No System-File Tampering**: Does not rename Windows binaries, take ownership of system files, disable `BITS`/`TrustedInstaller`, or edit the hosts file.

---

## ❓ FAQ

<details>
<summary><b>"Access Denied" or Permission Errors?</b></summary>
<br>
Make sure you launch PowerShell as <b>Administrator</b>: Search "PowerShell" in the Start Menu, right-click, and select <i>"Run as Administrator"</i>.
</details>

<details>
<summary><b>Can I revert the changes?</b></summary>
<br>
Registry, service, and scheduled-task changes made by the script can be restored from its backup. Removed Appx packages must be reinstalled separately from Microsoft Store.
</details>

---

## ☕ Support & Sponsorship

If `fuckWin` saved you from annoying updates and unwanted AI features, consider supporting the project:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R5C425QUEU)

[Support on Ko-fi](https://ko-fi.com/ggyy2008)

---

## 📄 License

Distributed under the [MIT License](LICENSE). Feel free to modify, distribute, and build upon this project.
