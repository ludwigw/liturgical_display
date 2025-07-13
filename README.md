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
   > **Note:** The setup script automatically builds the epdraw tool for real hardware deployment and runs validation to ensure everything is working correctly. For testing in Docker, epdraw is automatically mocked.
3. **Edit `config.yaml`** to match your environment (paths, VCOM, etc).
4. **Test the workflow:**
   ```sh
   source venv/bin/activate && python3 -m liturgical_display.main
   ```
5. **(Optional) Enable systemd service and timer** for daily runs (see systemd/ directory).

## Validation

The project includes a comprehensive validation script that checks all components of the installation:

```sh
./validate_install.sh
```

**What it validates:**
- Virtual environment setup and activation
- Python version compatibility (3.11+)
- liturgical-calendar package installation and version
- Font accessibility and loading
- epdraw tool availability and permissions
- Configuration file structure and required keys
- CLI functionality and image generation pipeline
- Main module imports
- Directory structure and permissions
- Systemd service files (optional)

**Validation options:**
```sh
./validate_install.sh --help      # Show help and usage
./validate_install.sh --version   # Show version information
```

The setup script automatically runs validation after installation. If validation fails, the setup script will exit with an error code and provide guidance on fixing issues.

**Sample validation output:**
```
📊 Test Results:
   Total tests: 18
   ✅ Passed: 15
   ❌ Failed: 0
   ⚠️  Warnings: 0

✅ Installation validation PASSED! 🎉
```

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
- IT8951-ePaper (for `epdraw` CLI tool) - automatically built by setup script
- liturgical-calendar (installed via requirements.txt)

## Testing vs Deployment

### Testing (Docker)
For testing the integration without real hardware:
```sh
# Build and run the test container
docker build -t liturgical-test .

# Test the complete setup and validation
docker run --rm liturgical-test:latest bash -c "cd /home/pi/liturgical_display && ./setup.sh"

# Run integration tests
./tests/test_integration.sh
```

This uses a mock epdraw tool and verifies the complete workflow in a containerized environment.

### Deployment (Real Hardware)
For deployment on actual Raspberry Pi hardware:
1. Follow the Quick Start steps above (setup script builds epdraw automatically)
2. Ensure SPI is enabled on your Pi (`raspi-config`)
3. Connect the eInk display hardware
4. Test with: `source venv/bin/activate && python3 -m liturgical_display.main`

## Troubleshooting

### Common Issues

**Setup/Installation Problems:**
- **Validation fails:** Run `./validate_install.sh` to see specific issues
- **Python version too old:** Ensure Python 3.11+ is installed
- **Permission errors:** Check file permissions and ownership
- **Network issues:** Ensure internet access for package downloads

**Hardware Issues:**
- **Display not updating:** Ensure SPI is enabled on your Pi (`raspi-config`)
- **VCOM errors:** Check the VCOM value in config.yaml matches your display
- **Connection problems:** Verify all hardware connections are secure
- **epdraw not found:** The setup script should build this automatically

**Runtime Issues:**
- **Image generation fails:** Check font accessibility and liturgical-calendar package
- **Configuration errors:** Validate your config.yaml structure
- **Log file issues:** Ensure log directory exists and is writable

### Debugging Steps
1. **Run validation:** `./validate_install.sh` to check all components
2. **Check logs:** Look at the log file specified in config.yaml
3. **Test manually:** Run each component separately to isolate issues
4. **Verify config:** Ensure config.yaml has all required keys and valid values

### Getting Help
- Check the validation output for specific error messages
- Review PLAN.md for detailed project information
- Check logs in the specified log file
- Ensure all dependencies are properly installed

## License
[TODO: Add license] 