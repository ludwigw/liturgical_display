# Web Server Setup Guide

This guide explains how to set up and configure the liturgical display web server, including making it accessible via Tailscale Funnel.

## Overview

The liturgical display includes a Flask web server that provides:
- Web interface for viewing liturgical information
- API endpoints for programmatic access
- "Next feast" UI when no artwork is available for the current date
- Auto-reload capability for development

## Automatic Setup

The web server is automatically configured during the main setup process:

```bash
./setup.sh
```

This will:
1. Install web server dependencies (Flask, Jinja2, requests)
2. Configure web server settings in `config.yaml`
3. Optionally enable the web server as a systemd service

## Manual Configuration

### Web Server Settings

The web server configuration is stored in `config.yaml`:

```yaml
web_server:
  enabled: true
  host: "0.0.0.0"
  port: 8080
  debug: false
```

### Starting the Web Server

#### Option 1: As part of the main application
```bash
source venv/bin/activate
python3 -m liturgical_display.main
```

#### Option 2: Standalone web server
```bash
source venv/bin/activate
python3 -m liturgical_display.web_server
```

#### Option 3: Development mode with auto-reload
```bash
source venv/bin/activate
python3 run_web_debug.py
```

### Systemd Service

To enable the web server to start automatically on boot:

```bash
# Install the web server service
sudo cp systemd/liturgical-web.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable liturgical-web.service
sudo systemctl start liturgical-web.service

# Check status
sudo systemctl status liturgical-web.service
```

## Web Interface

Once running, the web server provides:

- **Home page**: `http://localhost:8080/`
- **Today's information**: `http://localhost:8080/today`
- **Specific date**: `http://localhost:8080/YYYY-MM-DD`

### API Endpoints

- **JSON data**: `/api/today`, `/api/info/YYYY-MM-DD`
- **Original artwork**: `/api/artwork/today`, `/api/artwork/YYYY-MM-DD`
- **Next artwork**: `/api/next-artwork/today`, `/api/next-artwork/YYYY-MM-DD`
- **Generated images**: `/api/image/today/png`, `/api/image/YYYY-MM-DD/bmp`

## Tailscale Funnel Setup

To make your liturgical display accessible from anywhere on the internet through a secure tunnel:

### Prerequisites

1. **Tailscale installed and authenticated**
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

2. **Tailscale Funnel enabled on your account**
   - Go to https://login.tailscale.com/admin/settings/keys
   - Enable "Tailscale Funnel"

3. **Web server running**
   - Ensure the web server is running on port 8080

### Setup Process

Use the provided setup script:

```bash
./setup_tailscale_funnel.sh --hostname liturgical-display
```

Or run interactively:

```bash
./setup_tailscale_funnel.sh
```

### Manual Setup

If you prefer to set up Funnel manually:

```bash
# Start the funnel
tailscale funnel liturgical-display:8080

# Check status
tailscale funnel list

# Stop the funnel
tailscale funnel stop liturgical-display
```

### Accessing Your Display

Once configured, your liturgical display will be accessible at:
```
https://liturgical-display.your-tailnet.ts.net
```

### Security Notes

- The funnel is only accessible to devices on your Tailnet
- You can control access through Tailscale ACLs
- The connection is encrypted end-to-end
- No need to configure firewalls or port forwarding

## Troubleshooting

### Web Server Issues

1. **Port already in use**
   ```bash
   # Check what's using port 8080
   sudo lsof -i :8080
   
   # Kill the process or change the port in config.yaml
   ```

2. **Web server not starting**
   ```bash
   # Check logs
   sudo journalctl -u liturgical-web.service -f
   
   # Test manually
   source venv/bin/activate
   python3 -m liturgical_display.web_server
   ```

3. **Dependencies missing**
   ```bash
   source venv/bin/activate
   pip install -r requirements.txt
   ```

### Tailscale Funnel Issues

1. **Funnel not enabled**
   - Check your Tailscale account settings
   - Ensure you have the appropriate plan

2. **Hostname already in use**
   - Choose a different hostname
   - Check existing funnels: `tailscale funnel list`

3. **Web server not accessible**
   - Ensure the web server is running on the correct port
   - Check firewall settings (usually not needed with Tailscale)

### Validation

Run the validation script to check your setup:

```bash
./validate_install.sh
```

This will test:
- Web server module imports
- Web server dependencies
- Basic web server functionality

## Development

For development with auto-reload:

```bash
# Enable debug mode in config.yaml
web_server:
  debug: true

# Run with auto-reload
python3 run_web_debug.py
```

The web server will automatically restart when you make changes to Python files or templates.

## Next Steps

1. **Customize the design**: Edit templates in `liturgical_display/templates/`
2. **Add new API endpoints**: Modify `liturgical_display/web_server.py`
3. **Configure Tailscale ACLs**: Control access to your funnel
4. **Set up monitoring**: Monitor web server logs and performance

For more information, see the main README.md and the web server implementation files. 