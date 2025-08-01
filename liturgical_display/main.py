#!/usr/bin/env python3
import yaml
import os
import sys
import subprocess
import logging
from logging.handlers import RotatingFileHandler

from .updater import update_calendar_package
from .calendar import render_today
from .display import display_image

def load_config():
    config_path = os.environ.get('LITURGICAL_CONFIG', 'config.yaml')
    with open(config_path) as f:
        return yaml.safe_load(f)

def setup_logging(config):
    log_path = config.get('log_file', 'logs/display.log')
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    logger = logging.getLogger("liturgical_display")
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s')
    # File handler
    fh = RotatingFileHandler(log_path, maxBytes=1_000_000, backupCount=3)
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    # Console handler
    ch = logging.StreamHandler()
    ch.setFormatter(formatter)
    logger.addHandler(ch)
    return logger

def main():
    print("[main.py] Entering main() and setting up logger...")
    config = load_config()
    logger = setup_logging(config)
    logger.info("Logger initialized and main() started.")
    logger.info("Loaded config: %s", config)
    logger.info("Step 1: Update liturgical-calendar package and cache artwork...")
    updated = update_calendar_package(config, logger=logger)
    logger.info(f"Updater finished. Package updated: {updated}")

    logger.info("Step 2: Render today's liturgical image...")
    output_path = config.get('output_path', 'today.png')
    render_today(output_path, None)  # Package handles its own caching
    image_path = output_path

    logger.info("Step 3: Display image on eInk display...")
    success = display_image(image_path, config, logger=logger)
    if not success:
        logger.error("Failed to display image. Aborting.")
        return 1

    # Note: Web server is now handled by a separate systemd service
    # (liturgical-web.service) that runs continuously
    logger.info("Display update complete. Web server runs as separate service.")

    if config.get('shutdown_after_display', False):
        logger.info("Shutting down system as requested in config...")
        try:
            subprocess.run(['sudo', 'shutdown', 'now'], check=True)
        except Exception as e:
            logger.error(f"ERROR during shutdown: {e}")
    else:
        logger.info("Done. Not shutting down.")
    return 0

if __name__ == "__main__":
    sys.exit(main()) 