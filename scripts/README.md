# Scripts Directory

This directory contains utility scripts for the liturgical display project, organized by category.

## Directory Structure

### `debug/`
Debug and troubleshooting scripts for specific components.

- **`debug_epdraw.sh`** - Debug ePdraw compilation and display issues
  - Usage: `./scripts/debug/debug_epdraw.sh`
  - Checks BCM library, compilation, and display functionality

- **`run_web_debug.py`** - Run web server in debug mode with auto-reload
  - Usage: `./scripts/debug/run_web_debug.py`
  - Enables auto-reload for development
  - Automatically refreshes browser on template changes

### `monitoring/`
Memory and system monitoring scripts.

- **`monitor_memory.sh`** - Comprehensive memory monitoring for project services
  - Usage: `./scripts/monitoring/monitor_memory.sh`
  - Monitors Scriptura API, web server, and system memory usage
  - Continuous monitoring: `watch -n 5 ./scripts/monitoring/monitor_memory.sh`

### `setup/`
Setup and installation scripts (modular setup system).

- **`setup_modules/`** - Individual component setup scripts
  - `setup_epdraw.sh` - ePdraw compilation and installation
  - `setup_scriptura.sh` - Scriptura API setup
  - `setup_services.sh` - Systemd services installation
  - `setup_main.sh` - Main orchestrator script

### Root Level Scripts
- **`run_tests.sh`** - Run integration and system tests
  - Usage: `./scripts/run_tests.sh`
  - Tests all components and services

## Usage Examples

### Memory Monitoring
```bash
# Check current memory usage
./scripts/monitoring/monitor_memory.sh

# Continuous monitoring
watch -n 5 ./scripts/monitoring/monitor_memory.sh
```

### Debugging
```bash
# Debug ePdraw issues
./scripts/debug/debug_epdraw.sh

# Run web server in debug mode
./scripts/debug/run_web_debug.py

# Run system tests
./scripts/run_tests.sh
```

### Setup
```bash
# Setup specific component
./setup_modules/setup_main.sh --module epdraw --force-rebuild

# Full setup
./setup.sh
```

## Script Categories

| Category | Purpose | Scripts |
|----------|---------|---------|
| **Debug** | Troubleshooting | `debug_epdraw.sh`, `run_web_debug.py` |
| **Monitoring** | System monitoring | `monitor_memory.sh` |
| **Setup** | Installation | `setup_modules/*.sh` |
| **Testing** | Validation | `run_tests.sh` |

## Adding New Scripts

When adding new scripts:

1. **Choose appropriate directory** based on script purpose
2. **Make executable**: `chmod +x script_name.sh`
3. **Update this README** with script description and usage
4. **Follow naming convention**: `action_component.sh` (e.g., `debug_scriptura.sh`)

## Script Requirements

All scripts should:
- Include usage information (`--help` flag)
- Be executable (`chmod +x`)
- Handle errors gracefully
- Follow project coding standards
- Include comments for complex logic
