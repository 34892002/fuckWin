<div align="center">

# 🖕 fuckWin

**Take back control of your Windows PC.**  
A lightweight, transparent PowerShell tool to kill forced updates, strip out Copilot & AI bloat, and destroy telemetry in Windows 10 & 11.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue.svg)](https://microsoft.com)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-brightgreen.svg)](https://github.com/PowerShell/PowerShell)

[Quick Start](#-quick-start) • [Features](#-features) • [Security & Transparency](#-security--transparency) • [FAQ](#-faq) • [License](#-license)

</div>

---

## ⚡ Quick Start

Run PowerShell **as Administrator** and execute:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/34892002/fuckWin/main/fuckwin.ps1 | iex
```

> **Note**: Fully open-source and transparent. You can inspect the code anytime before running. No background services left behind.

---

## 🔥 Features

* **🛑 Freeze Windows Updates Permanently**
  * Fully disable Windows Update service (`wuauserv`), scheduled wake tasks, and `UsoClient.exe` to stop stealth background reactivations and forced reboots.
* **🧠 Complete De-AI Stripping**
  * Completely remove Windows Copilot, Recall surveillance, and unwanted AI sidebars embedded in Edge, Paint, and Notepad.
* **🕵️ Obliterate Telemetry & Adware**
  * Kill diagnostic tracking, CEIP logging, location tracking, and annoying lock screen / Start Menu promos.
* **🛠️ Restore Classic UX**
  * Restore the Windows 11 full-context right-click menu natively (say goodbye to "Show more options").
  * Disable Bing web search in the Start Menu to keep file search purely local.
* **🧹 UWP Bloatware Purge**
  * Batch-uninstall pre-installed system bloat like Xbox GameBar, Cortana, Phone Link, and extra consumer apps.

---

## 🛡️ Security & Transparency

`fuckWin` follows strict open-source security principles:

1. **Pure Plain-Text Script**: No pre-compiled `.exe` or obfuscated `.dll` files. Audit every registry change and command yourself.
2. **Zero Background Footprint**: Runs once, cleans your system, and exits. Leaves no background tracking daemons.
3. **100% Clean & Legal**: Contains no KMS activators, cracks, or license bypass code. Pure system optimization.

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
Yes! Re-run the script anytime and choose the <b>Restore</b> module to undo specific tweaks.
</details>

---

## ☕ Support & Sponsorship

If `fuckWin` saved you from annoying updates and unwanted AI features, consider supporting the project:

* * [Support on Ko-fi](https://ko-fi.com/ggyy2008)

---

## 📄 License

Distributed under the [MIT License](LICENSE). Feel free to modify, distribute, and build upon this project.
