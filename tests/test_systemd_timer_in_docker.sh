#!/bin/bash
set -e

# This script tests systemd timer scheduling in a Docker container using your real liturgical.service/timer.
# It uses a systemd drop-in override to safely test scheduling without running the real service logic.
# Requires Docker and a systemd-enabled image (jrei/systemd-ubuntu:22.04 is recommended).

IMAGE="jrei/systemd-ubuntu:22.04"
CONTAINER_NAME="systemd-timer-test-$$"

# Build context: project root
PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)

SERVICE_FILE="$PROJECT_DIR/systemd/liturgical.service"
TIMER_FILE="$PROJECT_DIR/systemd/liturgical.timer"

for f in "$SERVICE_FILE" "$TIMER_FILE"; do
  if [ ! -f "$f" ]; then
    echo "❌ Missing $f"
    exit 1
  fi
done

# Pull image if needed
docker pull $IMAGE

# Start container with systemd, mounting the real unit files
CID=$(docker run -d --privileged --name $CONTAINER_NAME \
  -v "$SERVICE_FILE:/etc/systemd/system/liturgical.service:ro" \
  -v "$TIMER_FILE:/etc/systemd/system/liturgical.timer:ro" \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -e container=docker \
  --entrypoint /lib/systemd/systemd \
  $IMAGE)
trap "docker rm -f $CID >/dev/null 2>&1 || true" EXIT

# Wait for systemd to be ready
sleep 5

echo "Creating systemd drop-in override for liturgical.service..."
docker exec $CID mkdir -p /etc/systemd/system/liturgical.service.d
# Write override.conf to replace ExecStart
cat <<EOF | docker exec -i $CID tee /etc/systemd/system/liturgical.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=/bin/bash -c 'echo "Timer fired at \\$(date)" >> /tmp/liturgical_test.log'
EOF

echo "Enabling and starting liturgical.timer..."
docker exec $CID systemctl daemon-reload
if ! docker exec $CID systemctl enable --now liturgical.timer; then
  echo "❌ Failed to enable/start liturgical.timer"
  exit 1
fi

# Show timer list
sleep 2
docker exec $CID systemctl list-timers --all

# Fast-forward the clock by 2 minutes to trigger the timer at least once
echo "Fast-forwarding clock by 2 minutes..."
docker exec $CID date -s "+2 minutes"

# Wait for the timer to fire
sleep 5

echo "Checking for log output..."
if docker exec $CID test -f /tmp/liturgical_test.log && docker exec $CID grep -q 'Timer fired' /tmp/liturgical_test.log; then
  echo "\n✅ Systemd timer successfully triggered the service!"
  docker exec $CID cat /tmp/liturgical_test.log
  exit 0
else
  echo "\n❌ Systemd timer did not trigger the service as expected."
  docker exec $CID cat /tmp/liturgical_test.log || true
  exit 1
fi 