# Zapret Easy Installer

A universal installer script for the [Zapret](https://github.com/bol-van/zapret) tool that works across multiple platforms:

- Linux (various distributions)
- macOS
- OpenWrt
- Windows

## Quick Install

### Unix-based Systems (Linux, macOS, OpenWrt)

Run the following command in your terminal:

```bash
sudo sh -c "$(curl -sSL https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.sh)"
```

### Windows

1. Download the [install_zapret.bat](https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.bat) file
2. Right-click the file and select "Run as administrator"

## Features

- **Cross-platform support**: Works on most major operating systems
- **Automatic curl installation**: Checks if curl is available and installs it if needed
- **Dynamic package selection**: Automatically selects the correct package for your system
- **Integrity verification**: Validates downloaded files using SHA256 checksums
- **Clean installation**: Downloads, extracts, and installs in the appropriate directories
- **Cleanup option**: Optionally remove downloaded files after installation

## How It Works

The installer:

1. Detects your operating system (Linux, macOS, OpenWrt, or Windows)
2. Installs curl if it's not available
3. Downloads the latest version of Zapret from the official GitHub repository
4. Selects the appropriate package for your system:
   - OpenWrt: `zapret-vX.X-openwrt-embedded.tar.gz`
   - Linux/macOS: `zapret-vX.X.tar.gz`
   - Windows: `zapret-vX.X.zip`
5. Verifies the integrity of the downloaded files using SHA256 checksums
6. Extracts the files to the appropriate location:
   - Windows/macOS: `~/Downloads/zapret/`
   - Linux/OpenWrt: `/tmp/zapret/`
7. Runs the installation scripts included in the package
8. Cleans up downloaded files if requested

## System Requirements

- **Linux/OpenWrt**: Root access, sh shell
- **macOS**: Admin privileges, Terminal
- **Windows**: Administrator privileges, PowerShell 5.1+

## Troubleshooting

### Checksum Verification Fails

If you encounter a checksum verification error, it could be due to:

1. Incomplete downloads
2. Network issues
3. Repository changes since the checksum file was created

Try running the installer again. If the problem persists, you can manually download and install the package from the [official Zapret repository](https://github.com/bol-van/zapret/releases).

### Permission Issues

Make sure you're running the installer with administrator privileges:

- Linux/macOS/OpenWrt: Use `sudo` before the command
- Windows: Right-click the BAT file and select "Run as administrator"

### Missing curl

The installer will attempt to install curl if it's not found. If this fails:

1. Install curl manually using your system's package manager
2. Run the installer again

## License

This installer is provided under the MIT License.

## Acknowledgments

- [Zapret](https://github.com/bol-van/zapret) by bol-van

---

*This is an unofficial installer. For issues with Zapret itself, please refer to the [official Zapret repository](https://github.com/bol-van/zapret).* 