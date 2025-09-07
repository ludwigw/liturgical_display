# 🛠️ Setup Guide

This guide covers the modular setup system for the liturgical display project.

## Overview

The project uses a modular setup system that allows you to:
- Run complete setup with one command
- Rebuild individual components
- Debug specific issues
- Skip unnecessary modules

## Quick Start

### Complete Setup
```bash
# Interactive setup (recommended for first time)
./setup.sh

# Non-interactive setup (for automation)
./setup.sh --non-interactive

# Force rebuild everything
./setup.sh --force-rebuild --non-interactive
```

### Individual Components
```bash
# Rebuild just ePdraw
./setup_modules/setup_main.sh --module epdraw --force-rebuild

# Rebuild just Scriptura API
./setup_modules/setup_main.sh --module scriptura --force-rebuild

# Rebuild just systemd services
./setup_modules/setup_main.sh --module services
```

## Setup Modules

### 1. ePdraw Module
Builds the ePdraw tool for e-ink display control.

**Script:** `./setup_modules/setup_epdraw.sh`

**What it does:**
- Clones the IT8951-ePaper repository
- Builds the epdraw binary
- Installs it in the project directory

**Flags:**
- `--force-rebuild`: Force rebuild even if epdraw exists
- `--non-interactive`: Run without user prompts

**Debug:**
```bash
# Diagnose ePdraw issues
./debug_epdraw.sh

# Check ePdraw status
./setup_modules/setup_main.sh --module epdraw --help
```

### 2. Scriptura Module
Sets up the local Scriptura API for Bible text access.

**Script:** `./setup_modules/setup_scriptura.sh`

**What it does:**
- Clones the enhanced Scriptura API repository
- Sets up Python virtual environment
- Installs dependencies
- Configures the API

**Flags:**
- `--force-rebuild`: Force rebuild even if Scriptura exists
- `--non-interactive`: Run without user prompts

**Debug:**
```bash
# Check Scriptura status
./setup_modules/setup_main.sh --module scriptura --help

# Check if Scriptura is running
curl http://localhost:8081/api/versions
```

### 3. Services Module
Installs and configures systemd services.

**Script:** `./setup_modules/setup_services.sh`

**What it does:**
- Installs liturgical-web.service
- Installs scriptura-api.service
- Enables and starts services
- Configures proper permissions

**Flags:**
- `--force-rebuild`: Reinstall services
- `--non-interactive`: Run without user prompts

**Debug:**
```bash
# Check service status
sudo systemctl status liturgical-web.service
sudo systemctl status scriptura-api.service

# View service logs
sudo journalctl -u liturgical-web.service -f
sudo journalctl -u scriptura-api.service -f
```

## Command Line Options

### Main Setup Script (`./setup.sh`)
```bash
./setup.sh [OPTIONS]

Options:
  --force-rebuild          Force rebuild of all components
  --non-interactive        Run without user prompts
  --skip-modules MODULES   Skip specific modules (comma-separated)
  --help                   Show this help message

Examples:
  ./setup.sh                                    # Interactive setup
  ./setup.sh --non-interactive                  # Non-interactive setup
  ./setup.sh --force-rebuild --non-interactive  # Force rebuild everything
  ./setup.sh --skip-modules epdraw,services     # Skip ePdraw and services
```

### Module Runner (`./setup_modules/setup_main.sh`)
```bash
./setup_modules/setup_main.sh --module MODULE [OPTIONS]

Options:
  --module MODULE           Module to run (epdraw, scriptura, services)
  --force-rebuild          Force rebuild of the module
  --non-interactive        Run without user prompts
  --help                   Show this help message

Examples:
  ./setup_modules/setup_main.sh --module epdraw --force-rebuild
  ./setup_modules/setup_main.sh --module scriptura --non-interactive
  ./setup_modules/setup_main.sh --module services
```

### Direct Module Scripts
```bash
# Run modules directly
./setup_modules/setup_epdraw.sh [--force-rebuild] [--non-interactive]
./setup_modules/setup_scriptura.sh [--force-rebuild] [--non-interactive]
./setup_modules/setup_services.sh [--force-rebuild] [--non-interactive]
```

## Common Use Cases

### First-Time Setup
```bash
# Complete setup with prompts
./setup.sh

# Complete setup without prompts
./setup.sh --non-interactive
```

### Fixing Issues
```bash
# ePdraw not working
./debug_epdraw.sh
./setup_modules/setup_main.sh --module epdraw --force-rebuild

# Scriptura API not responding
./setup_modules/setup_main.sh --module scriptura --force-rebuild

# Services not starting
./setup_modules/setup_main.sh --module services
```

### Development/Testing
```bash
# Skip ePdraw for testing
./setup.sh --skip-modules epdraw

# Rebuild just what you need
./setup_modules/setup_main.sh --module scriptura --force-rebuild
```

### Automation/CI
```bash
# Non-interactive setup for automation
./setup.sh --non-interactive

# Force rebuild for clean builds
./setup.sh --force-rebuild --non-interactive
```

## Troubleshooting

### ePdraw Issues
```bash
# Diagnose the problem
./debug_epdraw.sh

# Check what's wrong
./setup_modules/setup_main.sh --module epdraw --help

# Force rebuild
./setup_modules/setup_main.sh --module epdraw --force-rebuild
```

### Scriptura API Issues
```bash
# Check if it's running
curl http://localhost:8081/api/versions

# Check service status
sudo systemctl status scriptura-api.service

# View logs
sudo journalctl -u scriptura-api.service -f

# Rebuild if needed
./setup_modules/setup_main.sh --module scriptura --force-rebuild
```

### Service Issues
```bash
# Check service status
sudo systemctl status liturgical-web.service
sudo systemctl status scriptura-api.service

# Restart services
sudo systemctl restart liturgical-web.service
sudo systemctl restart scriptura-api.service

# Reinstall services
./setup_modules/setup_main.sh --module services
```

## Configuration

After setup, edit `config.yml` to match your environment:

```yaml
# Display settings
output_image: /path/to/today.png
vcom: -2.51  # Check your display's VCOM value

# Web server
web_server:
  enabled: true
  host: "0.0.0.0"
  port: 8080

# Scriptura API
scriptura:
  use_local: true
  local_port: 8081
  version: "asv"

# OpenAI API (for reflections)
openai_api_key: "your-key-here"
```

## Memory Management

The setup script automatically configures memory limits for low-memory Raspberry Pi systems:

### Automatic Memory Limits
- **ImageMagick**: 64MB memory limit (prevents OOM kills)
- **Scriptura API**: 64MB memory limit (lazy loading, only loads ASV version on-demand)
- **Web Server**: 64MB memory limit
- **Additional swap**: 1GB created if high swap usage detected

### Memory Usage Breakdown
- **System**: ~100MB
- **Scriptura API**: ~20-50MB (lazy loading, only loads ASV version on-demand)
- **Web Server**: ~20MB
- **ImageMagick**: ~64MB (limited)
- **Available for conversion**: ~200MB+

### Troubleshooting Memory Issues
```bash
# Check memory usage
free -h

# Check service memory limits
sudo systemctl show scriptura-api.service | grep Memory

# Check for OOM kills
sudo dmesg | grep -i killed

# Monitor memory in real-time
watch -n 1 'free -h'
```

## Validation

After setup, run validation to ensure everything is working:

```bash
# Run full validation
./validate_install.sh

# Run integration tests
./run_tests.sh
```

## Next Steps

1. **Test the display:** `source venv/bin/activate && python3 -m liturgical_display.main`
2. **Check web interface:** Visit `http://localhost:8080`
3. **Enable daily updates:** Services are automatically enabled
4. **Monitor logs:** Check service logs if issues occur

## Getting Help

- Check the main README.md for general information
- Use `--help` flags on any script for usage information
- Check service logs for runtime issues
- Use debug scripts for specific component issues
