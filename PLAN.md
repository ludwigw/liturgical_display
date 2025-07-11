# 🛠️ Raspberry Pi Liturgical eInk Display – Technical Brief

## 🌟 Overview

This project uses a **Raspberry Pi Zero W2** and a **Waveshare 10.3” eInk display (IT8951)** to display a liturgical calendar image each day.

### ✅ System Goals

* Wake up daily at **12:01am**
* Generate and display the liturgical image for that date
* Rely on built-in artwork cache from [`liturgical-calendar`](https://github.com/ludwigw/liturgical-calendar)
* Automatically pull updates from the `liturgical-calendar` Git repo
* Redraw the screen only when necessary
* Optionally shut down the device if external timed boot hardware is used

---

## 📦 Libraries Used

### 🔧 Core Libraries

* [`liturgical-calendar`](https://github.com/ludwigw/liturgical-calendar)

  * Provides feast logic, calendar generation, artwork caching, and image rendering
* [`IT8951-ePaper`](https://github.com/ludwigw/IT8951-ePaper)

  * Drives the Waveshare 10.3" eInk display (1872x1404px)
  * Accepts images via Pillow (`PIL.Image`) or raw buffer

### 📆 Python Dependencies

```txt
GitPython
Pillow  # Required by IT8951-ePaper
liturgical-calendar @ git+https://github.com/ludwigw/liturgical-calendar.git
IT8951-ePaper @ git+https://github.com/ludwigw/IT8951-ePaper.git
```

---

## 📁 Project Structure

```
liturgical-display/
├── main.py              # Orchestration entry point
├── display.py           # Sends image to eInk display
├── calendar.py          # Wraps liturgical-calendar logic
├── updater.py           # Git pulls + triggers cache-artwork
├── logs/                # Optional logging
├── systemd/
│   ├── liturgical.service
│   └── liturgical.timer
```

---

## ⚙️ Component Design

### `main.py`

* Entry point for daily execution
* Steps:

  1. Pull latest Git updates (optional)
  2. Cache any missing artwork
  3. Generate today's liturgical image
  4. Send image to eInk display
  5. (Optional) Shutdown Pi

---

### `calendar.py`

* Interfaces with `liturgical-calendar`
* Responsible for:

  * Rendering today’s image
  * Ensuring cache-artwork is run during updates
* Expects PNG output compatible with IT8951 display size (1872x1404)

---

### `updater.py`

* Runs `git pull origin main` in the `liturgical-calendar` repo
* If HEAD has changed, runs `liturgical-calendar cache-artwork`
* Optionally re-renders future dates

---

### `display.py`

* Uses `IT8951-ePaper` to:

  * Load image with Pillow
  * Send to display
  * Trigger full refresh
  * Enter sleep mode after drawing

---

## ⏰ Scheduling: `systemd` Timer

Use `systemd` to run the job every day at **12:01am**.

### `liturgical.timer`

```ini
[Unit]
Description=Daily Liturgical Image Update

[Timer]
OnCalendar=*-*-* 00:01:00
Persistent=true

[Install]
WantedBy=timers.target
```

### `liturgical.service`

```ini
[Unit]
Description=Run Liturgical Calendar Display
After=network.target

[Service]
ExecStart=/usr/bin/python3 /home/pi/liturgical-display/main.py
WorkingDirectory=/home/pi/liturgical-display
StandardOutput=journal
StandardError=journal
```

---

## 🔋 Power Management

* **Pi Zero W2 does NOT support rtcwake or true timed suspend**.
* Options:

| Method          | Hardware Required | Description                                       |
| --------------- | ----------------- | ------------------------------------------------- |
| `systemd.timer` | None              | Runs job daily; Pi stays on                       |
| External RTC    | RTC + FET/relay   | Powers Pi on at 12:00am, shuts off via `shutdown` |
| Always on       | None              | Acceptable for low-power usage                    |

> For full shutdown + restart, you'll need an RTC module (e.g., DS3231) or external timer circuitry.

---

## ✅ Feature Checklist

| Feature            | Status                        |
| ------------------ | ----------------------------- |
| Daily rendering    | ✅                             |
| eInk refresh       | ✅                             |
| Git auto-update    | ✅                             |
| Artwork caching    | ✅ (via `liturgical-calendar`) |
| Display sleep mode | ✅                             |
| Power-saving sleep | ⚠️ Hardware-dependent         |

---

## 🚀 To-Do for AI Engineer

1. Clone and install both libraries
2. Write `main.py` to orchestrate:

   * `updater.py` → `calendar.py` → `display.py`
3. Write `calendar.py` to call `liturgical-calendar` render commands
4. Write `display.py` to draw image using `IT8951-ePaper`
5. Add systemd unit + timer for scheduled runs
6. Optionally log output to `logs/`
