#!/bin/bash

# Memory monitoring script for liturgical display project
# Shows overall system memory and project-specific service memory usage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project services to monitor
SERVICES=(
    "scriptura-api.service"
    "liturgical-web.service"
    "liturgical.service"
    "liturgical.timer"
)

echo -e "${BLUE}🔍 Liturgical Display Memory Monitor${NC}"
echo "=================================================="
echo "Timestamp: $(date)"
echo ""

# Overall system memory
echo -e "${GREEN}📊 Overall System Memory:${NC}"
free -h
echo ""

# Memory usage by project services
echo -e "${GREEN}🔧 Project Services Memory Usage:${NC}"
echo "----------------------------------------"

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}✅ $service (ACTIVE)${NC}"
        
        # Get memory information
        MEMORY_CURRENT=$(systemctl show "$service" --property=MemoryCurrent --value 2>/dev/null || echo "N/A")
        MEMORY_PEAK=$(systemctl show "$service" --property=MemoryPeak --value 2>/dev/null || echo "N/A")
        MEMORY_HIGH=$(systemctl show "$service" --property=MemoryHigh --value 2>/dev/null || echo "N/A")
        MEMORY_MAX=$(systemctl show "$service" --property=MemoryMax --value 2>/dev/null || echo "N/A")
        MEMORY_ACCOUNTING=$(systemctl show "$service" --property=MemoryAccounting --value 2>/dev/null || echo "N/A")
        
        # Convert bytes to human readable if possible
        if [[ "$MEMORY_CURRENT" != "N/A" && "$MEMORY_CURRENT" != "0" && "$MEMORY_CURRENT" != "[not set]" ]]; then
            MEMORY_CURRENT_HR=$(numfmt --to=iec --suffix=B "$MEMORY_CURRENT" 2>/dev/null || echo "$MEMORY_CURRENT")
        else
            MEMORY_CURRENT_HR="N/A"
        fi
        
        if [[ "$MEMORY_PEAK" != "N/A" && "$MEMORY_PEAK" != "0" && "$MEMORY_PEAK" != "[not set]" ]]; then
            MEMORY_PEAK_HR=$(numfmt --to=iec --suffix=B "$MEMORY_PEAK" 2>/dev/null || echo "$MEMORY_PEAK")
        else
            MEMORY_PEAK_HR="N/A"
        fi
        
        echo "  Current Memory: $MEMORY_CURRENT_HR"
        echo "  Peak Memory:    $MEMORY_PEAK_HR"
        echo "  Memory High:    $MEMORY_HIGH"
        echo "  Memory Max:     $MEMORY_MAX"
        echo "  Accounting:     $MEMORY_ACCOUNTING"
        
        # Check if approaching limits
        if [[ "$MEMORY_CURRENT" != "N/A" && "$MEMORY_CURRENT" != "0" && "$MEMORY_CURRENT" != "[not set]" && "$MEMORY_MAX" != "N/A" && "$MEMORY_MAX" != "infinity" && "$MEMORY_MAX" != "[not set]" ]]; then
            CURRENT_MB=$((MEMORY_CURRENT / 1024 / 1024))
            MAX_MB=$((MEMORY_MAX / 1024 / 1024))
            USAGE_PERCENT=$((CURRENT_MB * 100 / MAX_MB))
            
            if [[ $USAGE_PERCENT -gt 90 ]]; then
                echo -e "  ${RED}⚠️  WARNING: High memory usage ($USAGE_PERCENT%)${NC}"
            elif [[ $USAGE_PERCENT -gt 75 ]]; then
                echo -e "  ${YELLOW}⚠️  CAUTION: Moderate memory usage ($USAGE_PERCENT%)${NC}"
            else
                echo -e "  ${GREEN}✅ Memory usage OK ($USAGE_PERCENT%)${NC}"
            fi
        fi
        
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo -e "${YELLOW}⏸️  $service (ENABLED but not active)${NC}"
    else
        echo -e "${RED}❌ $service (NOT FOUND)${NC}"
    fi
    echo ""
done

# Top memory consuming processes
echo -e "${GREEN}🔝 Top Memory Consuming Processes:${NC}"
echo "----------------------------------------"
ps aux --sort=-%mem | head -10 | awk 'NR==1{printf "%-8s %-8s %-8s %-8s %-8s %s\n", $1, $2, $3, $4, $5, $11} NR>1{printf "%-8s %-8s %-8s %-8s %-8s %s\n", $1, $2, $3, $4, $5, $11}'
echo ""

# Check for recent OOM kills
echo -e "${GREEN}💀 Recent OOM Kills:${NC}"
echo "----------------------------------------"
if sudo dmesg | grep -i "killed process" | tail -5; then
    echo ""
else
    echo "No recent OOM kills found"
fi
echo ""

# Swap usage
echo -e "${GREEN}💾 Swap Usage:${NC}"
echo "----------------------------------------"
swapon --show 2>/dev/null || echo "No swap configured"
echo ""

# Memory pressure
echo -e "${GREEN}📈 Memory Pressure:${NC}"
echo "----------------------------------------"
if command -v vmstat >/dev/null 2>&1; then
    vmstat 1 1 | tail -1 | awk '{printf "Free: %d MB, Available: %d MB, Used: %d MB\n", $4/1024, $7/1024, ($3+$4)/1024}'
else
    echo "vmstat not available"
fi
echo ""

# Service status summary
echo -e "${GREEN}📋 Service Status Summary:${NC}"
echo "----------------------------------------"
for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "✅ $service: ${GREEN}RUNNING${NC}"
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo -e "⏸️  $service: ${YELLOW}ENABLED${NC}"
    else
        echo -e "❌ $service: ${RED}NOT FOUND${NC}"
    fi
done

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "- Run 'watch -n 5 ./scripts/monitoring/monitor_memory.sh' for continuous monitoring"
echo "- Check logs with 'sudo journalctl -u SERVICE_NAME -f'"
echo "- Restart services with 'sudo systemctl restart SERVICE_NAME'"
echo ""
