#!/usr/bin/env python3
"""
Simple script to run the liturgical display web server with debug mode enabled.
This ensures auto-reload works properly for development.
"""

import os
import sys

# Add the project root to the Python path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

from liturgical_display.web_server import run_web_server

if __name__ == "__main__":
    print("Starting liturgical display web server with debug mode...")
    print("Auto-reload enabled - changes to templates will automatically refresh the browser")
    print("Press Ctrl+C to stop the server")
    run_web_server() 