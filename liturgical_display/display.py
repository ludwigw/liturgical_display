#!/usr/bin/env python3
import yaml
import os
import sys
import subprocess
import shutil

def load_config():
    config_path = os.environ.get('LITURGICAL_CONFIG', 'config.yaml')
    with open(config_path) as f:
        return yaml.safe_load(f)

def display_image(image_path=None, config=None, logger=None):
    """Display image on eInk using epdraw. Logs to logger if provided."""
    if config is None:
        config = load_config()
    if image_path is None:
        image_path = config.get('output_image', 'today.png')
    vcom = str(config.get('vcom', '-2.51')).replace('-', '')  # epdraw expects e.g. 251 for -2.51V
    vcom_arg = vcom if vcom else '251'
    log = logger.info if logger else print
    log(f"[display.py] Displaying image {image_path} with VCOM -{vcom_arg}")
    try:
        epdraw_path = 'epdraw'
        if not shutil.which(epdraw_path):
            epdraw_path = os.path.join('bin', 'epdraw')
        # Mode 2 (GC16) is required for the Waveshare 10.3" eInk display (IT8951)
        # Do not change unless you have a different display or special requirements
        subprocess.run([
            'sudo',
            epdraw_path,
            image_path,
            vcom_arg,
            '2'  # GC16 mode (best quality for 10.3" display)
        ], check=True)
        log(f"[display.py] Displayed image: {image_path}")
        return True
    except Exception as e:
        msg = f"[display.py] ERROR displaying image: {e}"
        if logger: logger.error(msg)
        else: print(msg)
        return False

if __name__ == "__main__":
    display_image() 