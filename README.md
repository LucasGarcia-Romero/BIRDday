# README — BirdDeep / AudioMoth Live Node

## Description

This repository contains the scripts and systemd services required to:

- Periodically record audio from a USB sound card (e.g., AudioMoth in USB mode) using **sox**.
- Generate spectrograms and archive recordings locally.
- (Optional) Send recordings to a remote server via **SSH/SCP** and log temperature/humidity telemetry (DHT22).
- Expose a lightweight **HTTP server** that serves the archived recordings.

The configuration is intended to run on **Orange Pi / Armbian** with the `orangepi` user (or similar), but it can be adapted to other SBCs.

---

## Repository Structure

```
.
├─ install.sh                      # Installation and service setup
├─ record.sh                       # Capture loop, spectrogram generation and upload
├─ dht22.c                         # DHT22 sensor reader using WiringPi
├─ audiomooth-live.service.txt     # Service: runs record.sh on boot
├─ simpleHttpServer.service.txt    # Service: FileServer HTTP on boot
├─ BirdDeep-Admin.nmconnection.txt # NetworkManager profile (SSID BirdDeep-admin)
├─ wifi.txt                        # Notes/snippets for Wi-Fi setup
└─ (FileServerBin/, spectrogram/)  # Expected binaries/folders in /home/<user> (see install.sh)
```

- `install.sh`: creates user, directories (`/home/<user>/recordings`, `/home/<user>/sdBackup`), copies services and enables them. Also installs `sox` and sets timezone to **Europe/Madrid**.  
- `record.sh`: handles recording with **sox** (32 kHz, 16-bit, mono, default 10s segments), generates **spectrograms**, archives into `sdBackup/<YYYY-MM-DD>/`, and optionally uploads via `scp`. It also reads CPU and DHT22 telemetry and logs it remotely.  
- `dht22.c`: reads DHT22 sensor via WiringPi, prints `Celsius Humidity` to stdout when checksum is valid.  
- `audiomooth-live.service.txt`: launches `/home/orangepi/record.sh` as a systemd service.  
- `simpleHttpServer.service.txt`: runs an external **FileServer** binary on port 80 serving `/home/orangepi/sdBackup/`.  
- `BirdDeep-Admin.nmconnection.txt`: **NetworkManager** profile for SSID `BirdDeep-admin` on `wlan0`.  
- `wifi.txt`: quick Wi-Fi setup commands (manual and `nmtui`).  

> **Note about service filenames**: `install.sh` expects `audiomoth-live.service` and `simpleHttpServer.service` (no `.txt`). Rename them after cloning or adjust the script.

---

## Requirements

- **Armbian/Debian** on Orange Pi (or other SBC).  
- **sox** (installed via `install.sh`).  
- **NetworkManager** (if using the `.nmconnection` profile).  
- **WiringPi / WiringOP** (to compile and run `dht22.c` if telemetry is required).  
- External binaries expected by the scripts in `$HOME`:
  - `spectrogram/spectrogram` (spectrogram generator).  
  - `FileServerBin/FileServer` (static HTTP server).  

---

## Quick Setup

> Examples assume **user `orangepi`** and **home `/home/orangepi`**. Adjust if using another user.

1. **Clone and prepare filenames**
   ```bash
   git clone <this-repo> birddeep-node
   cd birddeep-node
   mv audiomooth-live.service.txt audiomoth-live.service
   mv simpleHttpServer.service.txt simpleHttpServer.service
   ```

2. **Review `record.sh` variables**
   Edit as needed:
   - Station prefix: `STATION="TECHOUTAD_"`
   - Rates: `SAMPLE_RATE="32000"`, `BITRATE="16"`, `DURATION="10"`, `GAIN="5.0"`
   - Paths and user: `PROGRAMS_DIR=/home/orangepi`, `USER=utad`
   - Remote server: `IPSERVER=10.4.117.10`, target paths (`/datos2/AM$STATION/`)

3. **(Optional) Compile DHT22**
   ```bash
   sudo apt update
   sudo apt install -y build-essential wiringpi
   mkdir -p /home/orangepi/DHT22 && cp dht22.c /home/orangepi/DHT22/
   cd /home/orangepi/DHT22
   gcc dht22.c -lwiringPi -o dht22
   ```

4. **Install expected external binaries**
   - Place spectrogram binary in `/home/orangepi/spectrogram/spectrogram`.  
   - Place FileServer binary in `/home/orangepi/FileServerBin/FileServer`.  

5. **Create directories and set permissions**
   ```bash
   sudo mkdir -p /home/orangepi/recordings /home/orangepi/sdBackup
   sudo chown -R orangepi:orangepi /home/orangepi
   chmod +x record.sh
   ```

6. **Configure Wi-Fi**
   - With NetworkManager (included profile):
     ```bash
     sudo cp BirdDeep-Admin.nmconnection.txt /etc/NetworkManager/system-connections/BirdDeep-Admin.nmconnection
     sudo chmod 600 /etc/NetworkManager/system-connections/BirdDeep-Admin.nmconnection
     sudo nmcli connection reload
     sudo nmcli connection up "BirdDeep-admin"
     ```
   - Manual alternative (`wifi.txt` notes):
     ```bash
     sudo ifconfig wlan0 up
     sudo iwconfig wlan0 essid <SSID> key s:<PASSWORD>
     sudo dhclient wlan0
     # or on Armbian: nmtui-connect <SSID>
     ```

---

## Automatic Startup (systemd)

1. **Copy services**
   ```bash
   sudo cp audiomoth-live.service /etc/systemd/system/
   sudo cp simpleHttpServer.service /etc/systemd/system/
   ```

2. **Review service files**
   - `audiomoth-live.service` should point to your user/path:
     ```
     WorkingDirectory=/home/orangepi
     ExecStart=/home/orangepi/record.sh
     User=root
     ```
   - `simpleHttpServer.service` serves `sdBackup/` on **port 80** and **IP 192.168.2.56** by default. Change `-a` and `-p` if needed:
     ```
     ExecStart=/home/orangepi/FileServerBin/FileServer -p 80 -a 192.168.2.56 -r /home/orangepi/sdBackup/
     ```

3. **Enable and start**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable audiomoth-live.service simpleHttpServer.service
   sudo systemctl start audiomoth-live.service simpleHttpServer.service
   ```

4. **Check status**
   ```bash
   systemctl status audiomoth-live.service
   systemctl status simpleHttpServer.service
   journalctl -u audiomoth-live.service -f
   ```

---

## Recording Workflow

Each loop iteration:

1. Builds filename with timestamp + `STATION` prefix.  
2. Records **DURATION** seconds from `hw:1` (adjust if USB card index differs).  
3. Generates spectrogram with `spectrogram`.  
4. Moves `.wav` and artifacts to `sdBackup/YYYY-MM-DD/`.  
5. (Optional) SSH to server to **log telemetry** and ensure remote folder exists.  
6. Sends `.wav` to remote server with `scp`.  
7. Sleeps and repeats.  

Telemetry collects CPU temp (`/sys/class/thermal/...`) and DHT22 values (`$PROGRAMS_DIR/DHT22/dht22`), building a line like:  
```
YYYY-MM-DD HH:MM:SS BOARD_TEMP <x> ºC BOX_TEMP <y> ºC BOX_HUMIDITY <z> % STATION_filename.wav
```
which is appended remotely via SSH.

---

## Local HTTP Server

With `simpleHttpServer.service` enabled, you get an HTTP server exposing **`/home/<user>/sdBackup/`** at `http://<bind-ip>:<port>/`.  
Defaults: `-p 80`, `-a 192.168.2.56`.

---

## Using `install.sh`

`install.sh` automates:

- `apt update` + installs **sox** and timezone **Europe/Madrid**.  
- Creates user **BirDeep** with home `/home/BirDeep`, prepares `recordings` and `sdBackup`.  
- Copies `FileServerBin` and `spectrogram` into user home, sets `record.sh` executable.  
- Installs/enables systemd services and copies NetworkManager profile.  

