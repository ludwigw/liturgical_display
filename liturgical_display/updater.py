#!/usr/bin/env python3
import yaml
import os
import sys
import subprocess
from git import Repo, InvalidGitRepositoryError
from .utils import log

def load_config():
    config_path = os.environ.get('LITURGICAL_CONFIG', 'config.yaml')
    with open(config_path) as f:
        return yaml.safe_load(f)

def update_calendar_package(config=None, logger=None):
    """Update the liturgical-calendar package and run cache-artwork if needed."""
    if config is None:
        config = load_config()
    
    # Let the package handle its own caching - no custom cache directory needed
    log("[updater.py] Using package default caching behavior")

    # TEST MODE: Skip cache-artwork if LITURGICAL_TEST_MODE is set
    if os.environ.get("LITURGICAL_TEST_MODE") == "1":
        log("[updater.py] TEST MODE: Skipping package update and cache-artwork.")
        return False

    # Check for package updates (simplified - just reinstall to latest)
    log("[updater.py] Checking for liturgical-calendar package updates...")
    try:
        # Get current version
        result = subprocess.run([
            sys.executable, '-m', 'pip', 'show', 'liturgical-calendar'
        ], capture_output=True, text=True, check=True)
        current_version = result.stdout
        
        # Install/upgrade to latest
        subprocess.run([
            sys.executable, '-m', 'pip', 'install', '--upgrade',
            'git+https://github.com/ludwigw/liturgical-calendar.git'
        ], check=True)
        
        # Check if version changed
        result = subprocess.run([
            sys.executable, '-m', 'pip', 'show', 'liturgical-calendar'
        ], capture_output=True, text=True, check=True)
        new_version = result.stdout
        
        updated = (current_version != new_version)
        if updated:
            log("[updater.py] Package updated successfully.")
        else:
            log("[updater.py] Package already up to date.")
            
    except Exception as e:
        msg = f"[updater.py] ERROR updating package: {e}"
        if logger: logger.error(msg)
        else: print(msg)
        return False
    
    # Package handles its own artwork caching automatically
    log("[updater.py] Package handles artwork caching automatically.")
    return updated

if __name__ == "__main__":
    update_calendar_package() 