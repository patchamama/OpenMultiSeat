<div align="center">

# OpenMultiSeat

**Universal multi-seat server: one screen + keyboard + mouse per seat, each driving its own VM, container or desktop.**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](LICENSE) ![Status](https://img.shields.io/badge/status-active_development-orange?style=flat-square) ![Node.js 18+](https://img.shields.io/badge/Node.js_18+-339933?style=flat-square&logo=nodedotjs&logoColor=white) ![Express](https://img.shields.io/badge/Express-000000?style=flat-square&logo=express&logoColor=white) ![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white) ![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat-square&logo=powershell&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white) ![WSL2](https://img.shields.io/badge/WSL2-0078D6?style=flat-square&logo=windows&logoColor=white) ![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat-square&logo=linux&logoColor=white)

🇪🇸 [Español](README.es.md) · [Current state](#current-state-windows--wsl) · [Roadmap](#roadmap) · [Tech stack](#tech-stack) · [License](#license)

</div>

Assign a **dedicated keyboard and mouse** to one specific session (a VM, a kiosk browser, a desktop…) so those devices only
control that session while the rest of the computer keeps using its own. The end goal is a **universal, independent project**
(Windows, Linux and macOS) that turns one computer into several workstations: **one screen + one keyboard + one mouse per
seat**, each seat running whatever mode you choose.

This project started inside the Hyper-V Configurator (`/api/seat`) and is now an independent repository. The ELO installer lives
separately in [`elo-stack-installer`](https://github.com/patchamama/elo-stack-installer); here we only keep the idea that a seat
can be "a VM or container running ELO" like any other.

## Current state (Windows + WSL)

Works and is tested with a USB mouse and a USB keyboard:

1. **usbipd-win** detaches the chosen USB devices from Windows and attaches them to the user's WSL distro.
2. Inside WSL, `seat.sh` starts an **Xorg server on a virtual screen** (`dummy`) whose **only input** is those devices
   (`libinput`, `AutoAddDevices off`).
3. Inside it runs an **RDP session** to a VM (`xfreerdp3`), a **kiosk browser** (Firefox; Chrome/Edge optional) or, in Docker mode,
   a **container with a desktop** (Ubuntu + XFCE) that receives only those devices.
4. The image is shown on the Windows desktop with a **view-only VNC viewer** (x11vnc + TigerVNC through WSLg), so the Windows
   keyboard and mouse cannot act on it. The cursor is painted into the image.
5. When the seat stops, the devices go back to Windows.

| File | Purpose |
|---|---|
| `seat.sh` | Seat inside WSL: `start`, `stop`, `status`, `devices`, `check`, `logs`. Installed in WSL as `hvc-seat`. |
| `setup.sh` | Linux packages: Xorg dummy + libinput, x11vnc, TigerVNC, openbox, FreeRDP 3, Firefox (Mozilla `.deb`), optional Chrome/Edge. |
| `seat-lib.js` | Windows side: usbipd (bind/attach/detach), commands in the interactive user's WSL via a scheduled task, prepare/start/stop, Express routes. |
| `app.js`, `start-seat.bat` | Standalone app at `http://localhost:3100` (needs administrator rights). |
| `public/index.html` | UI: requirements, devices, mode (RDP / browser), start/stop. |
| `docker/` | Desktop image `hvc-seat-desktop` (Ubuntu 24.04 + choice of desktops). |

### Usage

```
cd OpenMultiSeat
npm install
start-seat.bat          # asks for elevation and opens http://localhost:3100
```

The page can be opened pre-filled: `/?target=host:13389&user=SRV01%5Cuser&pass=...` (`host` = this Windows as seen from WSL).

### Known limitations

- **USB devices only.** usbipd cannot pass a single Bluetooth device, only the whole adapter, and the WSL kernel lacks the
  MediaTek adapter driver (`BT_HCIBTUSB_MTK`). Built-in laptop keyboards and touchpads cannot be passed either.
- **WSL in `mirrored` mode** cannot reach the host's usbipd service on some networks (VPN); `prepare` switches to `nat`
  (with a `.wslconfig.bak-hvc` copy).
- **Every Windows user has their own WSL VM:** commands run as the signed-in user through a scheduled task, even if the app runs
  elevated under another account. Each operation therefore takes 10-30 s.
- **Performance:** the image goes through local VNC; browser mode with Guacamole means a double remote desktop. For VMs the
  direct RDP mode is better.
- **Transient failures:** at times commands launched as the interactive user returned no output and worked again without
  changes. Retry if it happens.

## Docker seats

A desktop container receives only the devices passed with `--device`, with a view-only VNC on `VNC_PORT`:

```
docker build -t hvc-seat-desktop docker
docker run -d --name hvc-seat-docker --network host --device /dev/input/event0 --device /dev/input/event1 \
  -v /run/udev:/run/udev:ro -e MOUSE=event0 -e KBD=event1 -e DISPLAY_NUM=3 -e VNC_PORT=5903 hvc-seat-desktop
DISPLAY=:0 xtigervncviewer -ViewOnly -PreferredEncoding=Raw -AutoSelect=0 127.0.0.1:5903
```

The UI's "Desktop container (Docker)" mode checks Docker Engine and the image in the distro, installs/builds what is missing,
starts the container `hvc-seat-<display>` and removes it on stop. The desktop is selectable (tag
`hvc-seat-desktop:<desktop>`, built on first use):

| Type | Desktops |
|---|---|
| Full | XFCE, MATE, KDE Plasma, GNOME Flashback (GNOME Shell needs 3D, which the virtual screen lacks) |
| Light | LXQt, LXDE |
| Window managers (very light) | Openbox + tint2, IceWM, Fluxbox, JWM, i3 (tiling, keyboard driven) |

A custom image also works if it follows the same contract: `MOUSE`, `KBD`, `DISPLAY_NUM`, `VNC_PORT`, `SEAT_W`, `SEAT_H`.

## Roadmap

### 1. Windows seats without third-party software

MouseMux V3 was evaluated and **discarded** (commercial, per-window locking is a Pro feature). The
own alternative for Windows, without WSL and with **Bluetooth** support, is an input router built on Raw Input:

- [ ] Read input with Raw Input (`RegisterRawInputDevices` + `WM_INPUT`), which identifies the device behind each event.
- [ ] One fullscreen window per seat that receives only its devices' events (an RDP/VNC client or an embedded browser).
- [ ] Open problem: Windows keeps delivering that input to the system too; it has to be filtered with a low-level hook
      (`WH_KEYBOARD_LL` / `WH_MOUSE_LL`, which do not name the device) or a filter driver.

Free projects to capture and redirect input per device (to evaluate): Interception and AutoHotInterception (Windows; the
Interception driver is non-commercial), LuaMacros, interception-tools / evsieve / keyd (Linux), Karabiner-Elements (macOS),
Kanata, Input Leap (between computers).

### 2. Several seats with several screens

- [x] Detect monitors (`seat.sh monitors`) and choose a **"Screen"** per seat: a 1280×800 window or **fullscreen on one
      monitor**, with the seat's virtual screen at that monitor's resolution.
- [x] **Several seats at once** (Seat 2-5, display `:N`; containers use `:N+20`), each with its own devices; a device belongs to
      one seat only. Stop per seat.
- [ ] Verify with the user which physical monitor each WSLg index is (WSLg numbering differs from Windows) and label them.
- [ ] Guided wizard: **screen → keyboard + mouse → mode**, and saved profiles to start several seats together ("classroom" /
      "office").
- [ ] Per-seat modes: **WSL** (current), **Docker**, **native Windows desktop** (own Raw Input router limited to that monitor),
      **browser kiosk**, **Hyper-V VM** (RDP/VMConnect fullscreen), **VirtualBox VM** (`VBoxManage startvm --type gui` with USB
      filters to pass the devices exclusively, no usbipd).

### 3. Universal: Linux and macOS

- [ ] **Native Linux:** real multi-seat with `systemd-logind` (`loginctl attach seatN <device>`), one compositor per seat (e.g.
      `cage` or Weston in kiosk) with its own video output and libinput-filtered input. With a single GPU and several outputs: one
      compositor per output (or Xorg with a `ServerLayout` per screen).
- [ ] **macOS:** has no multi-seat. Alternative: an app that **exclusively captures** chosen keyboard/mouse with IOKit
      (`IOHIDManager` + `kIOHIDOptionsTypeSeizeDevice`) and forwards them to a session drawn fullscreen on one monitor.
- [ ] **Windows without WSL:** own input router (Raw Input) and a fullscreen window per monitor.
- [ ] Common cross-platform core (Node/Electron or Tauri) with per-OS backends: `wsl`, `docker`, `native`, `browser`, `hyperv`,
      `virtualbox`, `logind`, `iokit`.
- [ ] **Virtual machines of any guest OS** as seat content, not just Windows: Windows (tested with WSL/RDP), **Linux distros**
      (Ubuntu, Debian, Fedora, openSUSE… via RDP/VNC/SPICE or the VM console fullscreen) and **macOS** (only on Apple hardware,
      per Apple's license). Target hypervisors: Hyper-V, VirtualBox, KVM/QEMU (libvirt), VMware, WSL/Docker, behind one backend
      interface: `listVMs`, `start`, `stop`, `attachInput(devices)`, `showFullscreen(monitor)`.
- [ ] **Guest detection:** recognise the VM's OS and offer the right mode (RDP for Windows, SPICE/VNC for Linux, the
      VirtualBox/KVM console otherwise).

### 4. Network multi-seat

A seat does not have to be on the same physical machine as the server. Goal: the server hands out seats to clients on the
network with the same model, "one screen + one keyboard + one mouse = a separate machine".

- [ ] **Remote seat:** a thin client (old PC, Raspberry Pi, laptop) connects to a seat over RDP / VNC / SPICE / Sunshine+Moonlight
      and sends **only its own** keyboard and mouse; the server never mixes it with local seats' input.
- [ ] **USB/IP:** export a client's devices to the server (`usbip` on Linux, `usbipd-win` on Windows) so that remote mouse/keyboard
      behave as local and can be assigned to a seat.
- [ ] **Access model:** per-seat allow-list of devices and clients (by MAC/device ID or key) with an **exclusive** mode (only that
      device drives the seat) and an **inclusive/shared** mode (several devices control the same seat).
- [ ] **Security:** client authentication (key or certificate), encryption (SSH/TLS/WireGuard), nothing exposed by default; the web
      UI only on `localhost` or behind authentication.
- [ ] **Discovery:** announce free seats on the LAN (mDNS) and let clients reserve them.
- [ ] **Several monitors as independent seats** (one monitor + its keyboard/mouse = one machine) combined with remote seats, with
      no seat seeing or controlling another.

### 5. Project housekeeping

- [x] Own repository with its history, own `package.json`, no dependency on the Hyper-V Configurator.
- [x] GPL-3.0-or-later license.
- [ ] Remove the `/api/seat` routes from the original configurator once this repository is used.
- [ ] Rename internal `hvc-*` leftovers (`hvc-seat`, `hvc-seat-desktop`, `C:\ProgramData\hvc-run`) to `openmultiseat`.
- [ ] Elevated start-up per platform and a requirements document; basic CI (lint + `shellcheck` for `seat.sh`/`setup.sh`).

## Tech stack

| Area | Technology |
|---|---|
| App / API | Node.js, Express |
| Input isolation | usbipd-win (USB/IP), Linux `libinput`, Xorg `dummy` driver, `AutoAddDevices off` |
| Seat sessions | FreeRDP 3 (`xfreerdp3`), Firefox / Chrome / Edge in kiosk mode, desktop containers (XFCE, MATE, KDE, LXQt, LXDE, Openbox, IceWM, Fluxbox, JWM, i3) |
| Display | x11vnc + TigerVNC (view-only) through WSLg |
| Runtime | WSL2, Docker Engine, Windows scheduled tasks (run as the interactive user) |
| Scripting | Bash (`seat.sh`, `setup.sh`), PowerShell |
| Planned | Raw Input (Windows), `systemd-logind` seats (Linux), IOKit HID (macOS), Hyper-V / VirtualBox / KVM / VMware backends, USB/IP over the network |

## License

OpenMultiSeat is free software under the **GNU General Public License v3.0 or later** (`GPL-3.0-or-later`, see
[LICENSE](LICENSE)). You can use, study and modify it; if you distribute a modified version you must publish it under the same
license with its source code. The external tools it installs (usbipd-win, FreeRDP, TigerVNC, Xorg…) keep their own licenses.
