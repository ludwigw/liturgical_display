#!/bin/bash
set -e

echo "[test_integration.sh] Building Docker image..."
docker build -t liturgical-test .

echo "[test_integration.sh] Running integration test in Docker..."
docker run --rm -v "$PWD":/workspace liturgical-test bash -c '
  set -e
  cd /home/pi/liturgical_display
  # Run setup script to configure environment (now uses venv)
  bash setup.sh
  # Remove cache and fonts to force fresh setup
  rm -rf /home/pi/.liturgical-cache || true
  rm -rf /home/pi/.liturgical-fonts || true
  # Run the workflow using the new package structure with venv
  export LITURGICAL_TEST_MODE=1
  ./venv/bin/python3 -m liturgical_display.main || (cat logs/display.log && false)
  # Search for display.log anywhere in the container
  echo "--- Searching for display.log anywhere in the container ---"
  find / -name display.log 2>/dev/null || true
  # Check logs
  echo "--- display.log ---"
  cat /home/pi/liturgical-display/logs/display.log
  echo "--- epdraw_mock.log ---"
  cat /tmp/epdraw_mock.log
  # Check that mock epdraw was called
  grep "Mock epdraw called" /tmp/epdraw_mock.log
'

echo "[test_integration.sh] Integration test PASSED." 