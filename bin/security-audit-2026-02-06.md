# macOS Security Audit Report

**Machine:** Mac15,6 (Apple M3 Pro)
**macOS:** 26.2 (25C56)
**Serial:** HH67NF24MH
**Date:** 2026-02-06
**Overall Grade:** B (76/100)

---

## PASS — Strong Foundations

| Check | Status |
|---|---|
| FileVault is ON | PASS |
| SIP is enabled | PASS |
| Gatekeeper is enabled | PASS |
| Secure Boot: Full Security | PASS |
| Firewall is enabled | PASS |
| Stealth Mode is ON | PASS |
| Lockdown Mode is enabled | PASS |
| Automatic security updates enabled | PASS |
| macOS is up to date | PASS |
| ICMP broadcast echo disabled | PASS |
| AirDrop is set to 'Contacts Only' | PASS |
| Screen Sharing is disabled | PASS |
| File Sharing (SMB) is disabled | PASS |
| Remote Login (SSH) is disabled | PASS |
| Auto-login is disabled | PASS |
| Admin users: root fexxdev | PASS |
| Screen lock requires password immediately | PASS |
| Login keychain has a lock timeout configured | PASS |
| No authorized_keys file (or empty) | PASS |
| ~/.ssh permissions are 700 | PASS |
| No cron jobs | PASS |
| DNS servers: 1.0.0.1 (known privacy-respecting providers) | PASS |
| No external IPs in /etc/hosts | PASS |
| VPN process detected as running | PASS |
| mkcert CA key permissions are 600 | PASS |
| No Docker system daemons detected | PASS |
| 'Hey Siri' voice trigger is disabled | PASS |
| Bluetooth status: could not determine (likely OFF) | PASS |
| Location Services: could not determine status (check manually) | PASS |
| Analytics & telemetry sharing appears disabled | PASS |
| USB Restricted Mode: accessories require approval or device is unlocked | PASS |
| Wi-Fi auto-join for open networks: not enabled (or set to Ask) | PASS |
| Touch ID: not available on this hardware (skipped) | PASS |

---

## CRITICAL — Fix Immediately

### 1. Remote Management (ARD) is loaded

Apple Remote Desktop agent is running. This allows remote control of your machine if exploited or misconfigured.

```
Fix: System Settings > General > Sharing > Disable 'Remote Management'
     Or via terminal: sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off
```


### 2. TeamViewer LaunchDaemons are installed

TeamViewer has persistent system-level daemons running as root. TeamViewer has been repeatedly compromised (2016, 2019, 2024 breaches) and is a known target for intelligence services.

Third-party LaunchDaemons found:
  - com.apphousekitchen.aldente-pro.helper.plist
  - com.crystalidea.macsfancontrol.smcwrite.plist
  - com.docker.socket.plist
  - com.docker.vmnetd.plist
  - com.microsoft.autoupdate.helper.plist
  - com.privateinternetaccess.vpn.daemon.plist
  - com.sparklabs.ViscosityHelper.plist
  - com.teamviewer.Helper.plist
  - com.teamviewer.UninstallerHelper.plist
  - com.teamviewer.UninstallerWatcher.plist
  - org.wireshark.ChmodBPF.plist

**How to fully uninstall TeamViewer:**

1. Quit TeamViewer if running
2. Open Finder > Applications > right-click TeamViewer > Move to Trash
3. Remove leftover system files:
```
sudo launchctl unload /Library/LaunchDaemons/com.teamviewer.Helper.plist
sudo launchctl unload /Library/LaunchDaemons/com.teamviewer.UninstallerHelper.plist
sudo launchctl unload /Library/LaunchDaemons/com.teamviewer.UninstallerWatcher.plist
sudo rm /Library/LaunchDaemons/com.teamviewer.*
sudo rm /Library/PrivilegedHelperTools/com.teamviewer.Helper
sudo rm -rf /Library/Application\ Support/TeamViewer
rm -rf ~/Library/Application\ Support/TeamViewer
rm -rf ~/Library/Caches/com.teamviewer.*
rm -rf ~/Library/Preferences/com.teamviewer*
rm -rf ~/Library/Logs/TeamViewer
```
4. Verify nothing remains:
```
ls /Library/LaunchDaemons/com.teamviewer* 2>/dev/null && echo 'STILL PRESENT' || echo 'Clean'
```



---

## HIGH — Fix Soon

### 1. Services listening on all network interfaces

The following services are reachable by anyone on your local network:

  - AMPDevice (PID 2914) on *:49408
  - nginx (PID 745) on *:8080
  - nginx (PID 868) on *:8080
  - nginx (PID 872) on *:8080
  - nginx (PID 921) on *:8080
  - nginx (PID 923) on *:8080
  - nginx (PID 924) on *:8080
  - nginx (PID 925) on *:8080
  - nginx (PID 926) on *:8080
  - nginx (PID 927) on *:8080
  - nginx (PID 928) on *:8080
  - nginx (PID 938) on *:8080
  - nginx (PID 942) on *:8080
  - rapportd (PID 619) on *:61587

```
Fix: Bind services to 127.0.0.1 (localhost) or stop them if not needed.
     For nginx: change 'listen 8080' to 'listen 127.0.0.1:8080' in nginx.conf
     To stop nginx: brew services stop nginx
```



---

## MEDIUM — Recommended Hardening

### 1. 10 user LaunchAgents found — review for legitimacy

  - com.github.facebook.watchman.plist
  - com.google.GoogleUpdater.wake.plist
  - com.google.keystone.agent.plist
  - com.google.keystone.xpcservice.plist
  - com.jetbrains.AppCode.BridgeService.plist
  - com.lwouis.alt-tab-macos.plist
  - com.privateinternetaccess.vpn.client.plist
  - com.valvesoftware.steamclean.plist
  - homebrew.mxcl.nginx.plist
  - org.keepassxc.KeePassXC.plist

```
Fix: Review each one. Remove unneeded agents:
     launchctl unload ~/Library/LaunchAgents/<plist>
     rm ~/Library/LaunchAgents/<plist>
```


### 2. Offensive / dual-use security tools installed

While legitimate for security work, these increase attack surface and could be weaponised if your machine is compromised:

  - bettercap
  - mitmproxy
  - nmap
  - sherlock
  - Wireshark (GUI)
```
Fix: Uninstall any you're not actively using. Keep them in a VM if needed for security work.
```



---

## Summary

| Severity | Count |
|---|---|
| PASS | 33 |
| CRITICAL | 2 |
| HIGH | 1 |
| MEDIUM | 2 |
| **Overall Grade** | **B** (76/100) |

---

*Generated by [macos-security-audit](https://github.com/fexxdev/macos-security-audit) v1.0.0 on 2026-02-06*
