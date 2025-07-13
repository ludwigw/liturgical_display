# 🛠️ Raspberry Pi Liturgical eInk Display

## Overview
This project displays a daily liturgical calendar image on a Waveshare 10.3" eInk display using a Raspberry Pi Zero W2. It auto-updates, renders, and displays the image each day, with minimal maintenance required.

## Hardware Requirements
- Raspberry Pi Zero W2 (or compatible Pi)
- Waveshare 10.3" eInk display (IT8951 controller)
- SD card, power supply, network access

## Quick Start
1. **Clone this repository:**
   ```sh
   git clone https://github.com/ludwigw/liturgical_display.git
   cd liturgical_display
   ```
2. **Run the setup script:**
   ```sh
   ./setup.sh
   ```
3. **Edit `config.yaml`** to match your environment (paths, VCOM, etc).
4. **Build the epdraw tool:**
   ```sh
   git clone https://github.com/ludwigw/IT8951-ePaper.git
   cd IT8951-ePaper
   git checkout refactir
   make bin/epdraw
   cp bin/epdraw ../liturgical_display/bin/
   cd ../liturgical_display
   ```
5. **Test the workflow:**
   ```sh
   source venv/bin/activate && python3 -m liturgical_display.main
   ```
6. **(Optional) Enable systemd service and timer** for daily runs (see systemd/ directory).

## Configuration: config.yaml

The `config.yaml` file controls all device-specific and operational settings. Edit this file after running setup to match your environment.

| Key                    | What it does                                                      | Example value                                  |
|------------------------|-------------------------------------------------------------------|------------------------------------------------|
| `output_image`         | Where the rendered image for today will be saved                  | `/home/pi/liturgical-display/today.png`        |
| `vcom`                 | VCOM voltage for your eInk display (see sticker on FPC cable)     | `-2.51`                                        |
| `shutdown_after_display` | If true, Pi will shut down after updating the display             | `false`                                        |
| `log_file`             | Path to log file                                                   | `/home/pi/liturgical-display/logs/display.log` |

### Example config.yaml
```yaml
# Where to save the rendered image for today
output_image: /home/pi/liturgical-display/today.png

# VCOM voltage for your eInk display (see sticker on FPC cable, e.g. -2.51)
vcom: -2.51

# If true, Pi will shut down after updating the display (for use with timed power/RTC)
shutdown_after_display: false

# Path to log file
log_file: /home/pi/liturgical-display/logs/display.log
```

## How It Works
- `main.py` orchestrates the daily update, render, and display process.
- All settings are in `config.yaml` (edit this for your device).
- Uses `updater.py` to update the liturgical-calendar package.
- Uses `calendar.py` to render today's image.
- Uses `display.py` to show the image on the eInk display (via `epdraw`).
- The liturgical-calendar package handles its own caching and font management.
- Optionally shuts down the Pi after display (set in config).

## Dependencies
- Python 3.11+
- Install Python dependencies:
  ```sh
  pip install -r requirements.txt
  ```
- IT8951-ePaper (for `epdraw` CLI tool)
- liturgical-calendar (installed via requirements.txt)

## Testing
Run the integration test to verify everything works:
```sh
./tests/test_integration.sh
```

## Troubleshooting
- Ensure SPI is enabled on your Pi (`raspi-config`).
- Check all hardware connections.
- If display does not update, check logs and try running each script manually.
- Make sure `epdraw` is built and in the `bin/` directory or your PATH.
- For more, see PLAN.md and comments in each script.

## License
[TODO: Add license] 