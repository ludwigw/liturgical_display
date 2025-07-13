#!/bin/bash
set -e

# Static validation for systemd unit files

SERVICE_FILE="systemd/liturgical.service"
TIMER_FILE="systemd/liturgical.timer"

fail=0

check_file() {
    if [ ! -f "$1" ]; then
        echo "❌ Missing: $1"
        fail=1
    else
        echo "✅ Found: $1"
    fi
}

echo "Checking for systemd unit files..."
check_file "$SERVICE_FILE"
check_file "$TIMER_FILE"

echo "\nValidating systemd unit file syntax..."
if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze verify "$SERVICE_FILE" || fail=1
    systemd-analyze verify "$TIMER_FILE" || fail=1
else
    echo "⚠️  systemd-analyze not available, skipping syntax check."
fi

# Lint for [Install] section
for file in "$SERVICE_FILE" "$TIMER_FILE"; do
    if ! grep -q "^\[Install\]" "$file"; then
        echo "⚠️  $file is missing [Install] section (may not be enable-able)"
    fi

done

if [ $fail -eq 0 ]; then
    echo "\n✅ Static systemd validation PASSED"
    exit 0
else
    echo "\n❌ Static systemd validation FAILED"
    exit 1
fi 