# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

zapret-newtochno is a DPI (Deep Packet Inspection) bypass tool for Windows that circumvents internet censorship and throttling. This is a custom build of the zapret project, focused on bypassing restrictions on services like YouTube, Discord, and other platforms primarily in Russia.

The project works by manipulating TCP/UDP packets using WinDivert to evade DPI systems deployed by ISPs. It runs as a Windows service using `winws.exe` as the core engine.

## Common Commands

### Service Management
Run `service.bat` (requires admin privileges) for interactive service management:
```cmd
service.bat
```

The script provides a menu for:
- Installing the service (converts .bat presets to Windows services)
- Removing services
- Checking service status
- Running diagnostics

### Testing Presets
Test configurations before installing as services:

```cmd
general.cmd
```

```cmd
mypreset.cmd
```

```cmd
preset_russia_autohostlist.cmd
```

### Cleaning Up WinDivert
If you need to manually remove the WinDivert driver:
```cmd
windivert_delete.cmd
```

## Architecture

### Core Components

**winws.exe** - The main DPI bypass engine
- Intercepts network packets using WinDivert
- Applies various DPI evasion techniques (packet fragmentation, fake packets, desynchronization)
- Configured via command-line arguments

**WinDivert** (WinDivert64.sys, WinDivert.dll)
- Kernel-mode driver for packet interception
- Allows userspace programs to capture/modify network packets
- Must be properly signed for Windows

**elevator.exe** - Privilege escalation helper
- Used to request admin rights when needed

### Configuration Files

**.cmd preset files** - DPI bypass configurations
- `general.cmd` - General-purpose configuration for HTTP/HTTPS/QUIC
- `mypreset.cmd` - Custom preset with host/IP filtering
- `preset_russia_autohostlist.cmd` - Russia-specific with auto hostlist learning
- Each file contains `winws.exe` invocation with specific DPI evasion parameters

**service.bat** - Service management script
- Version: 1.8.1 (see LOCAL_VERSION variable)
- Parses .bat/.cmd preset files and converts them to Windows services
- Provides diagnostics for common conflicts (Adguard, Killer services, CheckPoint, SmartByte, VPNs)
- Can update from GitHub releases

### Directory Structure

```
/
├── winws.exe                    # Main DPI bypass executable
├── WinDivert.dll/.sys           # Packet capture driver
├── elevator.exe                 # Privilege escalation helper
├── service.bat                  # Service installer/manager
├── general.cmd                  # General preset
├── mypreset.cmd                 # Custom preset
├── preset_russia_autohostlist.cmd  # Russia-specific preset
├── list-youtube.txt             # YouTube/Apple/Chess/Cloudflare/Discord/etc. domains
├── /files/                      # Binary payloads for DPI evasion
│   ├── list-youtube.txt         # Domain hostlist
│   └── quic_initial_www_google_com.bin  # QUIC fake packet
├── /lists/                      # IP and domain lists
│   └── ipset-all.txt            # IP address whitelist
└── /pre-configs/                # Additional preset configurations
    ├── preset_russia.cmd
    └── preset_russia_autohostlist.cmd
```

### DPI Evasion Techniques

The tool uses multiple strategies defined in preset files:

1. **TCP/HTTP (port 80)**
   - `--dpi-desync=fake,fakedsplit` - Send fake packets and split
   - `--dpi-desync-autottl=2` - Auto TTL adjustment
   - `--dpi-desync-fooling=md5sig` - TCP MD5 signature option manipulation

2. **TCP/HTTPS (port 443)**
   - `--dpi-desync=fake,multidisorder` - Multiple out-of-order packets
   - `--dpi-desync-split-pos=midsld` - Split at middle of second-level domain
   - `--dpi-desync-repeats=6-11` - Repeat desync techniques
   - `--dpi-desync-fake-tls` - Use fake TLS ClientHello packets

3. **UDP/QUIC (port 443)**
   - `--dpi-desync=fake` - Fake packet injection
   - `--dpi-desync-fake-quic` - Use fake QUIC Initial packets
   - `--dpi-desync-repeats=11` - Multiple repetitions

4. **Discord Voice (UDP 50000-50099)**
   - `--ipset` filtering for Discord IPs
   - `--dpi-desync-any-protocol` - Protocol-agnostic desync
   - `--dpi-desync-cutoff=n4` - Cutoff strategy

### Hostlist and IP Filtering

**list-youtube.txt** - Contains domains for popular services:
- YouTube and Google video domains
- Apple ecosystem domains
- Chess.com
- Cloudflare infrastructure
- Discord
- Instagram/Facebook/Meta
- Nvidia
- Various Russian streaming sites

**lists/ipset-all.txt** - IP address whitelist
- Can be enabled/disabled via service.bat menu
- Used for IP-based rather than domain-based filtering

### Service Management Logic

`service.bat` performs complex parsing:
1. Reads .bat/.cmd files to extract `winws.exe` command lines
2. Handles variable substitution (`%~dp0`, `%BIN%`, `%LISTS%`)
3. Converts relative paths to absolute paths
4. Merges multi-line commands (handles `^` continuation)
5. Creates Windows service with parsed arguments

### Diagnostic Checks

The diagnostics function checks for known conflicts:
- **Adguard** - May interfere with Discord
- **Killer Network Services** - Known conflicts
- **Check Point** security software
- **SmartByte** network optimizer
- **VPN services** - Some VPNs conflict
- **DNS settings** - Warns if using ISP DNS
- **Discord cache** - Offers to clear

## Development Notes

### When modifying presets:
- Test with `.cmd` files directly before installing as service
- Use `service.bat` → "Check Status" to verify service is running
- Check `tasklist | findstr winws.exe` to see if bypass is active
- Multiple `--new` flags separate independent filter chains

### Parameter Syntax:
- `--wf-tcp` / `--wf-udp` - Define which ports to intercept (WinDivert filter)
- `--filter-tcp` / `--filter-udp` - Apply specific DPI techniques to these ports
- `--hostlist` - Apply only to domains in specified file
- `--ipset` - Apply only to IPs in specified file
- `--dpi-desync-*` - Various desync/evasion strategies
- `--new` - Starts a new independent filter chain

### Adding new blocked services:
1. Add domains to `list-youtube.txt` or create new list file
2. Add IP ranges to `lists/ipset-all.txt` if using IP filtering
3. Update preset files with appropriate `--hostlist` or `--ipset` flags
4. Consider which desync strategies work best (test iteratively)

## Update Mechanism

The tool checks for updates from:
- Repository: `https://github.com/Flowseal/zapret-discord-youtube`
- Version file: `/main/.service/version.txt`
- Current version tracked in `service.bat` as `LOCAL_VERSION=1.8.1`

## Windows Compatibility

- Requires Windows with WinDivert driver support (Windows 7+)
- Needs Administrator privileges for service installation
- WinDivert must be properly signed (may require test signing mode on older Windows)
- PowerShell used for colored output and HTTP requests
