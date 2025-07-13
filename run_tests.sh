#!/bin/bash
set -e

# Unified test runner for local development
# Runs all relevant tests and prints a summary

PASS=0
FAIL=0
SKIP=0

print_result() {
  if [ $1 -eq 0 ]; then
    echo -e "\033[0;32m✅ $2\033[0m"
    PASS=$((PASS+1))
  elif [ $1 -99 ]; then
    echo -e "\033[1;33m⚠️  Skipped: $2\033[0m"
    SKIP=$((SKIP+1))
  else
    echo -e "\033[0;31m❌ $2\033[0m"
    FAIL=$((FAIL+1))
  fi
}

# 1. Python unit/integration tests (if any)
if [ -d tests ] && ls tests/*.py >/dev/null 2>&1; then
  echo "\nRunning Python tests..."
  if python3 -m unittest discover tests; then
    print_result 0 "Python unit/integration tests"
  else
    print_result 1 "Python unit/integration tests"
  fi
else
  print_result -99 "No Python unit/integration tests found"
fi

# 2. Validation script (Docker only)
echo "\nRunning validate_install.sh in Docker..."
if docker build -t liturgical-test .; then
  if docker run --rm liturgical-test:latest bash -c "cd /home/pi/liturgical_display && ./validate_install.sh"; then
    print_result 0 "validate_install.sh (Docker)"
  else
    print_result 1 "validate_install.sh (Docker)"
  fi
else
  print_result 1 "Docker build for validation failed"
fi

# 3. Systemd static validation
if [ -x tests/test_systemd_static.sh ]; then
  echo "\nRunning systemd static validation..."
  if tests/test_systemd_static.sh; then
    print_result 0 "Systemd static validation"
  else
    print_result 1 "Systemd static validation"
  fi
else
  print_result -99 "Systemd static validation script not found"
fi

# 4. Systemd scheduling test (Docker-based)
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" = "Linux" ]; then
  if [ -x tests/test_systemd_timer_in_docker.sh ]; then
    echo "\nRunning Docker-based systemd scheduling test..."
    if sudo tests/test_systemd_timer_in_docker.sh; then
      print_result 0 "Systemd scheduling test (Docker)"
    else
      print_result 1 "Systemd scheduling test (Docker)"
    fi
  else
    print_result -99 "Systemd scheduling test script not found"
  fi
else
  print_result -99 "Systemd scheduling test (Docker) skipped: not running on Linux"
fi

# 5. Other integration tests
if [ -x tests/test_integration.sh ]; then
  echo "\nRunning integration test script..."
  if tests/test_integration.sh; then
    print_result 0 "Integration test script"
  else
    print_result 1 "Integration test script"
  fi
else
  print_result -99 "Integration test script not found or not executable"
fi

# Summary
echo -e "\n===================="
echo -e "\033[1mTest Summary:\033[0m"
echo -e "  ✅ Passed:   $PASS"
echo -e "  ❌ Failed:   $FAIL"
echo -e "  ⚠️  Skipped:  $SKIP"
echo -e "===================="

if [ $FAIL -eq 0 ]; then
  echo -e "\033[0;32mAll tests passed!\033[0m"
  exit 0
else
  echo -e "\033[0;31mSome tests failed.\033[0m"
  exit 1
fi 