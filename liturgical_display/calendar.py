#!/usr/bin/env python3
import yaml
import os
import sys
import subprocess
from .utils import log

def load_config():
    config_path = os.environ.get('LITURGICAL_CONFIG', 'config.yaml')
    with open(config_path) as f:
        return yaml.safe_load(f)

def render_today(output_path, cache_dir):
    try:
        # Call the CLI directly, no custom FONTS_DIR logic
        subprocess.run([
            sys.executable, '-m', 'liturgical_calendar.cli', 'generate', '--output', output_path
        ], check=True)
        log(f"[calendar.py] Rendered image: {output_path}")
    except Exception as e:
        log(f"[calendar.py] ERROR rendering image: {e}")
        raise

if __name__ == "__main__":
    render_today() 