# 🛠️ Raspberry Pi Liturgical eInk Display

## Overview
This project displays a daily liturgical calendar image on a Waveshare 10.3" eInk display using a Raspberry Pi Zero W2. It auto-updates, renders, and displays the image each day, with minimal maintenance required. The system also includes a web server that provides web access to liturgical information and API endpoints.

## Hardware Requirements
- Raspberry Pi Zero W2 (or compatible Pi)
- Waveshare 10.3" eInk display (IT8951 controller)
- SD card, power supply, network access

> **Note:** The epdraw tool requires `sudo` privileges to access GPIO pins via the BCM library. This is automatically handled by the display script.

## Quick Start
**One-line install:**
```sh
git clone https://github.com/ludwigw/liturgical_display.git && cd liturgical_display && ./setup.sh
```

**Or step by step:**
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
5. **Web server is automatically enabled** and runs continuously for web access.
6. **(Optional) Enable systemd service and timer** for daily runs (see systemd/ directory).

## Validation

## Testing & Validation

All validation and integration testing is now performed via the unified test runner:

```sh
./run_tests.sh
```

This script runs:
- Systemd static validation (unit file checks)
- Full integration test (in Docker, with log and workflow validation)
- (Optionally) systemd scheduling test (Linux only)
- (Optionally) Python unit tests (if present)

**How to use:**
- Run `./run_tests.sh` locally to check your setup before deployment or after making changes.
- The integration test covers the entire workflow, including setup, validation, and log file checks.
- In CI, only `run_tests.sh` is used for all validation.

**Sample test runner output:**
```
====================
Test Summary:
  ✅ Passed:   2
  ❌ Failed:   0
  ⚠️  Skipped:  2
====================
All tests passed!
```

> **Note:** The old `validate_install.sh` script is still available for manual troubleshooting, but is no longer run directly in CI or the main test runner. All validation is now covered by the integration test.

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

## Web Server

The liturgical display includes a Flask web server that provides web access to liturgical information and API endpoints. The web server runs as a separate systemd service, ensuring continuous availability.

### Architecture

The system uses a clean separation of concerns:
- **Main service** (`liturgical.service`): Handles daily display updates
- **Web server service** (`liturgical-web.service`): Runs continuously for web access
- **Timer** (`liturgical.timer`): Triggers the main service daily at 12:01 AM

### Web Interface

Once running, the web server provides:

- **Home page**: `http://localhost:8080/`
- **Today's information**: `http://localhost:8080/today`
- **Specific date**: `http://localhost:8080/YYYY-MM-DD`

### API Endpoints

- **JSON data**: `/api/today`, `/api/info/YYYY-MM-DD`
- **Original artwork**: `/api/artwork/today`, `/api/artwork/YYYY-MM-DD`
- **Next artwork**: `/api/next-artwork/today`, `/api/next-artwork/YYYY-MM-DD`
- **Generated images**: `/api/image/today/png`, `/api/image/YYYY-MM-DD/bmp`

### Web Server Configuration

The web server uses a separate configuration file (`web_server_config.yaml`):

```yaml
# Web server configuration
host: "0.0.0.0"
port: 8080
debug: false
log_level: "INFO"
cache_dir: "cache"
wikipedia_cache_dir: "cache/wikipedia"
auto_reload: false
```

### Managing the Web Server

```bash
# Check web server status
sudo systemctl status liturgical-web.service

# View web server logs
sudo journalctl -u liturgical-web.service -f

# Restart web server
sudo systemctl restart liturgical-web.service

# Start web server manually (for development)
source venv/bin/activate
python3 -m liturgical_display.web_server
```

### Remote Access with Tailscale Funnel

To make your liturgical display accessible from anywhere on the internet through a secure tunnel:

1. **Install Tailscale** (if not already installed):
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

2. **Enable Tailscale Funnel** on your account:
   - Go to https://login.tailscale.com/admin/settings/keys
   - Enable "Tailscale Funnel"

3. **Set up the funnel**:
   ```bash
   ./setup_tailscale_funnel.sh --hostname liturgical-display
   ```

Your display will then be accessible at:
```
https://liturgical-display.your-tailnet.ts.net
```

## How It Works

### Display Update Process
- `main.py` orchestrates the daily update, render, and display process.
- All settings are in `config.yaml` (edit this for your device).
- Uses `updater.py` to update the liturgical-calendar package.
- Uses `calendar.py` to render today's image.
- Uses `display.py` to show the image on the eInk display (via `epdraw`).
- The liturgical-calendar package handles its own caching and font management.
- Optionally shuts down the Pi after display (set in config).

### Web Server Process
- `web_server.py` provides the Flask web application.
- Runs as a separate systemd service (`liturgical-web.service`).
- Uses `web_server_config.yaml` for web-specific configuration.
- Provides web interface and API endpoints for liturgical data.
- Runs continuously, independent of display updates.

## Dependencies
- Python 3.11+
- Install Python dependencies:
  ```sh
  pip install -r requirements.txt
  ```
- IT8951-ePaper (for `epdraw` CLI tool) - automatically built by setup script
- liturgical-calendar (installed via requirements.txt)
- Flask, Jinja2, requests (for web server) - automatically installed via requirements.txt

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

**Web Server Issues:**
- **Port already in use:** Check what's using port 8080 with `sudo lsof -i :8080`
- **Web server not starting:** Check logs with `sudo journalctl -u liturgical-web.service -f`
- **Web dependencies missing:** Run `pip install -r requirements.txt` in the virtual environment

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