<div align="center">

# Zapret Easy Installer

**One-command installer for [zapret](https://github.com/bol-van/zapret) and [zapret2](https://github.com/bol-van/zapret2): the open-source DPI bypass tools by bol-van.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20OpenWrt%20%7C%20macOS%20%7C%20Windows-informational)
![Shell](https://img.shields.io/badge/shell-POSIX%20sh-green)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)

</div>

---

zapret helps you get around ISP-level blocking and throttling based on Deep Packet Inspection (DPI). It changes how your own traffic looks on the wire, without a VPN or proxy server. This project does **not** change zapret in any way. It downloads the official release, verifies it, and walks you through the official setup so you don't have to do it by hand.

## Table of contents

- [Quick start](#quick-start)
- [zapret or zapret2?](#zapret-or-zapret2)
- [Supported platforms](#supported-platforms)
- [What the installer does](#what-the-installer-does)
- [After installation](#after-installation)
- [Options](#options)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [FAQ](#faq)
- [Disclaimer](#disclaimer)
- [Credits](#credits)

## Quick start

### Linux, macOS and OpenWrt

One command for all three. It uses `curl` if available and falls back to `wget`, which OpenWrt ships by default:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh 2>/dev/null || wget -qO- https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh)"
```

- **Linux / macOS:** the script asks for your password through `sudo` when it needs root privileges.
- **OpenWrt:** log in as `root` over SSH first. On older images you may need `opkg update && opkg install ca-bundle libustream-mbedtls` so that `wget` can use HTTPS.

The script detects the platform itself and downloads the right package (the `openwrt-embedded` build on OpenWrt).

### Windows

**Option A, PowerShell (recommended):** open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.ps1 | iex
```

**Option B, double-click:** download [`install_zapret.bat`](https://github.com/gorlev/zapret-easy-installer/raw/main/install_zapret.bat) and double-click it.

Either way, the installer opens an elevated window (accept the UAC prompt) and shows an interactive menu.

## zapret or zapret2?

The installer asks which one you want. Both are developed by the same author and are maintained in parallel.

| | **zapret** (v1) | **zapret2** |
|---|---|---|
| Status | Mature and stable | Next generation, under active development |
| Engine | `nfqws` / `tpws`, strategies built into C code | `nfqws2`, strategies are **Lua scripts** |
| Flexibility | Large but fixed set of options | Write or modify your own desync strategies |
| Transparent proxy mode (`tpws`) | Yes | No |
| Linux / OpenWrt | Yes | Yes |
| Windows | `winws.exe` | `winws2.exe` |
| macOS | Partial (`tpws` only) | **Not supported** |
| Install location (Unix) | `/opt/zapret` | `/opt/zapret2` |
| Best for | Most users | Enthusiasts who want full control |

**Not sure? Choose zapret (1).** It is the default. On macOS, zapret is always used because zapret2 does not support it.

> [!NOTE]
> Don't run zapret and zapret2 at the same time: their firewall rules conflict. If the other one is already installed, the installer warns you and offers to uninstall it.

## Supported platforms

| Platform | Package used | Notes |
|---|---|---|
| Linux (systemd, OpenRC, SysV) | `zapret-<ver>.tar.gz` / `zapret2-<ver>.tar.gz` | x86, x86_64, ARM, ARM64, MIPS, PPC, RISC-V (zapret2) |
| OpenWrt | `*-openwrt-embedded.tar.gz` | Run as root. Uses the built-in firewall (fw3/fw4). |
| macOS | `zapret-<ver>.tar.gz` | zapret v1 only (`tpws` + `pf`), universal binary for Intel and Apple Silicon |
| Windows 8, 10, 11 (x64) | [zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) | Has both `winws` and `winws2`, plus blockcheck |
| Windows 11 ARM64 | zapret-win-bundle | Needs test-signing mode (`arm64\install_arm64.cmd`) |
| Windows 7 x64 | zapret-win-bundle | May need ESU updates or `win7\install_win7.cmd` |

## What the installer does

### Linux, OpenWrt and macOS (`install_zapret.sh`)

1. Gets root privileges through `sudo` (on OpenWrt you are already root).
2. Detects the platform and asks for **zapret** or **zapret2**.
3. Finds the latest release on GitHub. If the API is rate-limited, it falls back to the release redirect.
4. Downloads the right package into a fresh temporary directory using `curl` or `wget`.
5. **Verifies every bundled binary** against the release's official `sha256sum.txt` and stops on any mismatch.
6. Runs `install_bin.sh` to select the binaries for your CPU architecture.
7. Optionally runs **blockcheck** to find a strategy that works with your ISP.
8. Starts the official interactive **`install_easy.sh`**, which copies zapret to `/opt/zapret` (or `/opt/zapret2`), sets up the firewall and the autostart service.
9. Removes the temporary files.

### Windows (`install_zapret.ps1`)

1. Restarts itself with administrator rights.
2. Asks for **zapret** (`winws.exe`) or **zapret2** (`winws2.exe`).
3. Downloads the latest official [zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) into `C:\zapret`. It is pinned to the current commit, and the exe is cross-checked against the official release checksum.
4. Creates an editable **strategy file** (`C:\zapret\strategy-zapret.txt` or `strategy-zapret2.txt`) from the bundle's example preset.
5. Opens a menu:

```
  1) Run blockcheck (find a strategy that works with your ISP)
  2) Test the strategy now (runs in a window until you close it)
  3) Install as a Windows service (start automatically with Windows)
  4) Edit the strategy file
  5) Show status
  6) Stop and remove the service
  7) Uninstall everything
```

Run the installer again at any time to update the bundle or get back to this menu. Your strategy files are kept.

## After installation

zapret has **no universal "works everywhere" setting**. Every ISP blocks differently, so you need a strategy that matches yours. The usual workflow:

1. **Run blockcheck.** It tries many techniques against a blocked site and reports which ones work.
   - Linux / OpenWrt / macOS: `/opt/zapret/blockcheck.sh` (zapret2: `/opt/zapret2/blockcheck2.sh`)
   - Windows: menu option **1**
2. **Apply the strategy.**
   - Linux / OpenWrt / macOS: edit `/opt/zapret/config` (`NFQWS_OPT` / `TPWS_OPT`; zapret2: `/opt/zapret2/config`, `NFQWS2_OPT`), then run `install_easy.sh` again.
   - Windows: paste the arguments into the strategy file (menu option **4**).
3. **Test it.**
   - Windows: menu option **2**.
   - Unix: restart the service, e.g. `systemctl restart zapret` or `/etc/init.d/zapret restart`.
4. **Make it permanent.**
   - Unix: `install_easy.sh` already set up autostart.
   - Windows: menu option **3** installs a service that starts with Windows.

For details on strategies, see the official documentation: [zapret](https://github.com/bol-van/zapret/blob/master/docs/readme.en.md) · [zapret2](https://github.com/bol-van/zapret2/blob/master/docs/manual.en.md).

## Options

### `install_zapret.sh`

| Flag | Environment variable | Description |
|---|---|---|
| `--flavor 1\|2` | `ZAPRET_FLAVOR` | `1` = zapret, `2` = zapret2. Skips the question. |
| `--version TAG` | `ZAPRET_VERSION` | Install a specific release (e.g. `v72.13`) instead of the latest. |
| `--blockcheck` / `--no-blockcheck` | `ZAPRET_BLOCKCHECK=1\|0` | Run or skip blockcheck before installing. |
| `--keep-files` | `ZAPRET_KEEP_FILES=1` | Keep the downloaded files in the temp directory. |
| `-h`, `--help` | | Show help. |

Example: install zapret2 and skip this installer's own questions:

```bash
ZAPRET_FLAVOR=2 ZAPRET_BLOCKCHECK=0 sh -c "$(curl -fsSL https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh)"
```

> `install_easy.sh` itself is interactive, so you still answer zapret's own setup questions.

### `install_zapret.ps1`

| Parameter | Environment variable | Description |
|---|---|---|
| `-Flavor 1\|2` | `ZAPRET_FLAVOR` | `1` = zapret (`winws`), `2` = zapret2 (`winws2`) |
| `-InstallDir <path>` | `ZAPRET_DIR` | Install folder, default `C:\zapret`. Avoid paths with spaces. |
| `-SkipDownload` | | Use the existing installation and go straight to the menu. |

## Uninstalling

| Platform | Command |
|---|---|
| Linux / OpenWrt / macOS | `/opt/zapret/uninstall_easy.sh` (or `/opt/zapret2/uninstall_easy.sh`), then `rm -rf /opt/zapret` |
| Windows | Run the installer and choose **7) Uninstall everything**. It removes the services, the WinDivert driver and `C:\zapret`. |

## Troubleshooting

<details>
<summary><b>Sites still don't open after installation</b></summary>

The default or example strategy most likely doesn't match your ISP. Run blockcheck (see [After installation](#after-installation)) and use the strategy it finds. Also make sure no other DPI bypass tool, VPN or proxy is running at the same time. Encrypted DNS (DoH/DoT) in your browser or OS often helps too, because many ISPs also block at the DNS level.
</details>

<details>
<summary><b>Windows: antivirus deletes or blocks <code>WinDivert64.sys</code> / <code>winws.exe</code></b></summary>

WinDivert is a signed, legitimate packet-capture driver, but some antivirus products flag it as a "hacking tool". Add `C:\zapret` to your antivirus exclusions, or compare the files with the [official WinDivert release](https://reqrypt.org/windivert.html).
</details>

<details>
<summary><b>Windows: WinDivert fails to load</b></summary>

- **Windows 11 ARM64:** run `C:\zapret\arm64\install_arm64.cmd` and reboot (enables test-signing mode).
- **Windows 7:** install the ESU updates or run `C:\zapret\win7\install_win7.cmd`.
- **Windows 8+:** on some systems Secure Boot prevents the driver from loading.
</details>

<details>
<summary><b>Windows: the service is installed but not running</b></summary>

Usually the strategy file has an error. Use menu option **2** to start winws in a visible window and read its error message, fix the strategy file, then install the service again.
</details>

<details>
<summary><b>"Checksum mismatch" error</b></summary>

One or more binaries in the downloaded package don't match the official `sha256sum.txt`. This means the download is corrupted or has been tampered with, so the installer stops. Try again later or from another network. Don't bypass this check.
</details>

<details>
<summary><b>"Could not determine the latest release"</b></summary>

GitHub couldn't be reached, or you hit the anonymous API rate limit (60 requests per hour). Wait a few minutes, or pass a tag directly: `--version v72.13`.
</details>

<details>
<summary><b>OpenWrt: <code>wget</code> fails with an SSL error</b></summary>

Install HTTPS support: `opkg update && opkg install ca-bundle libustream-mbedtls`, or install curl: `opkg install curl`.
</details>

<details>
<summary><b>"system is not either systemd, openrc or openwrt based"</b></summary>

zapret's installer can't configure autostart on your init system. You can still continue, then set up autostart manually as described in the zapret documentation.
</details>

## Security

Piping a script from the internet into a shell means trusting its author. If you prefer to check it first, download it, read it, then run it:

```bash
curl -fsSLO https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh
less install_zapret.sh
sh install_zapret.sh
```

- Everything is downloaded only from official GitHub sources: `github.com/bol-van/zapret`, `bol-van/zapret2` and `bol-van/zapret-win-bundle`.
- On Linux, OpenWrt and macOS, every binary is checked against the release's `sha256sum.txt` before anything runs.
- On Windows, the bundle has no release checksums. The installer pins the download to a specific commit (saved in `C:\zapret\BUNDLE_COMMIT.txt`) and cross-checks `winws.exe` / `winws2.exe` against the official release checksum when the versions match.

## FAQ

**Is this an official zapret project?**
No. It is an unofficial helper. All credit for zapret goes to [bol-van](https://github.com/bol-van). Report zapret bugs in the official repositories, and installer bugs [here](https://github.com/gorlev/zapret-easy-installer/issues).

**Does zapret work like a VPN?**
No. Your traffic still goes directly to the destination from your own IP address. zapret only changes packets so that the ISP's DPI can't classify them. It doesn't hide your identity or encrypt anything.

**Can I switch between zapret and zapret2 later?**
Yes. Uninstall one, then run the installer again and pick the other. They install to different folders, but you shouldn't run them at the same time.

**How do I update?**
Run the installer again. On Unix, `install_easy.sh` offers to keep your existing config. On Windows, your strategy files are kept.

## Disclaimer

This software is provided for educational purposes and to protect access to information. You are responsible for complying with the laws of your country and the terms of your internet service provider. The authors accept no liability for any misuse or damage.

## Credits

- [bol-van](https://github.com/bol-van): author of [zapret](https://github.com/bol-van/zapret), [zapret2](https://github.com/bol-van/zapret2) and [zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle)
- [WinDivert](https://reqrypt.org/windivert.html) by basil00

## License

The installer scripts are released under the [MIT License](LICENSE). zapret, zapret2 and their components keep their own licenses.
