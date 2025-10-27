#!/bin/bash
# Security monitoring script for ProcessMaker
# Place this in /opt/security-monitor.sh
LOG_DIR="/opt/processmaker/shared/sites/workflow/log"
SECURITY_LOG="$LOG_DIR/security.log"
ALERT_LOG="$LOG_DIR/security-alerts.log"
NGINX_LOG="/var/log/nginx/domain.error.log"
APACHE_LOG="/var/log/apache2/domain.error.log"

# Create logs if they don't exist
mkdir -p "$LOG_DIR"
touch "$SECURITY_LOG" "$ALERT_LOG" "$LOG_DIR/debug.log"

# Function to send alert (customize as needed)
send_alert() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SECURITY ALERT: $message" | tee -a "$ALERT_LOG"
    # Add your notification method here (email, Slack, etc.)
}

# Function to check for repeated attacks from same IP
check_ip_attacks() {
    local ip="$1"
    local count=$(grep -c "\"ip\":\"$ip\"" "$SECURITY_LOG" 2>/dev/null | tr -d '\n' || echo 0)
    echo "DEBUG: check_ip_attacks ip='$ip' count='$count'" >> "$LOG_DIR/debug.log"
    if [ "$count" -gt 10 ]; then
        send_alert "IP $ip has attempted $count attacks in the last monitoring period"
    fi
}

# Function to analyze security log
analyze_security_log() {
    if [ ! -f "$SECURITY_LOG" ]; then
        echo "DEBUG: Security log $SECURITY_LOG does not exist" >> "$LOG_DIR/debug.log"
        return
    fi
    if [ ! -r "$SECURITY_LOG" ]; then
        echo "DEBUG: Security log $SECURITY_LOG is not readable" >> "$LOG_DIR/debug.log"
        return
    fi
    
    # Get unique IPs from last hour
    local last_hour=$(date -d '1 hour ago' '+%Y-%m-%d %H')
    local unique_ips=$(grep "$last_hour" "$SECURITY_LOG" 2>/dev/null | grep -o '"ip":"[^"]*' | cut -d'"' -f4 | sort -u)
    
    # Check each IP for repeated attacks
    for ip in $unique_ips; do
        check_ip_attacks "$ip"
    done
    
    # Check for XSS attempts
    local xss_count=$(grep -c "XSS" "$SECURITY_LOG" 2>/dev/null | tr -d '\n' || echo 0)
    echo "DEBUG: xss_count='$xss_count'" >> "$LOG_DIR/debug.log"
    if [ "$xss_count" -gt 5 ]; then
        send_alert "High number of XSS attempts detected: $xss_count"
    fi
    
    # Check for SQL injection attempts
    local sql_count=$(grep -c "SQL_INJECTION" "$SECURITY_LOG" 2>/dev/null | tr -d '\n' || echo 0)
    echo "DEBUG: sql_count='$sql_count'" >> "$LOG_DIR/debug.log"
    if [ "$sql_count" -gt 5 ]; then
        send_alert "High number of SQL injection attempts detected: $sql_count"
    fi
}

# Function to check Nginx 403 errors
check_nginx_blocks() {
    if [ ! -f "$NGINX_LOG" ]; then
        echo "DEBUG: Nginx log $NGINX_LOG does not exist" >> "$LOG_DIR/debug.log"
        return
    fi
    if [ ! -r "$NGINX_LOG" ]; then
        echo "DEBUG: Nginx log $NGINX_LOG is not readable" >> "$LOG_DIR/debug.log"
        return
    fi
    
    local recent_blocks=$(grep "$(date '+%Y/%m/%d %H')" "$NGINX_LOG" 2>/dev/null | grep -c "403" 2>/dev/null | tr -d '\n' || echo 0)
    echo "DEBUG: nginx recent_blocks='$recent_blocks'" >> "$LOG_DIR/debug.log"
    if [ "$recent_blocks" -gt 20 ]; then
        send_alert "High number of Nginx 403 blocks in the last hour: $recent_blocks"
    fi
}

# Function to check Apache security blocks
check_apache_blocks() {
    if [ ! -f "$APACHE_LOG" ]; then
        echo "DEBUG: Apache log $APACHE_LOG does not exist" >> "$LOG_DIR/debug.log"
        return
    fi
    if [ ! -r "$APACHE_LOG" ]; then
        echo "DEBUG: Apache log $APACHE_LOG is not readable" >> "$LOG_DIR/debug.log"
        return
    fi
    
    # Use Apache log date format: [Fri Jul 25 18:28:00 2025]
    local date_pattern=$(date '+%a %b %d %H:[0-5][0-9]:[0-5][0-9] %Y')
    local recent_blocks=$(grep "$date_pattern" "$APACHE_LOG" 2>/dev/null | grep -c "File does not exist" 2>/dev/null | tr -d '\n' || echo 0)
    echo "DEBUG: apache recent_blocks='$recent_blocks'" >> "$LOG_DIR/debug.log"
    if [ "$recent_blocks" -gt 20 ]; then
        send_alert "High number of Apache blocks in the last hour: $recent_blocks"
    fi
}

# Function to generate security report
generate_report() {
    local report_file="$LOG_DIR/security-report-$(date '+%Y%m%d').txt"
    
    cat > "$report_file" << EOF
ProcessMaker Security Report - $(date)
==========================================

Top 10 Attacking IPs:
$(grep -o '"ip":"[^"]*' "$SECURITY_LOG" 2>/dev/null | cut -d'"' -f4 | sort | uniq -c | sort -nr | head -10)

Attack Types Today:
XSS Attempts: $(grep -c "XSS" "$SECURITY_LOG" 2>/dev/null | tr -d '\n' || echo 0)
SQL Injection Attempts: $(grep -c "SQL_INJECTION" "$SECURITY_LOG" 2>/dev/null | tr -d '\n' || echo 0)

Recent Alerts:
$(tail -20 "$ALERT_LOG" 2>/dev/null || echo "No recent alerts")
EOF
    
    echo "Security report generated: $report_file" >> "$LOG_DIR/debug.log"
}

# Main monitoring loop
main() {
    echo "Starting security monitoring at $(date)" >> "$LOG_DIR/debug.log"
    
    while true; do
        analyze_security_log
        check_nginx_blocks
        check_apache_blocks
        
        # Generate daily report at midnight
        if [ "$(date '+%H%M')" = "0000" ]; then
            generate_report
        fi
        
        # Sleep for 10 minutes
        sleep 600
    done
}

# Handle signals
trap 'echo "Security monitoring stopped at $(date)" >> "$LOG_DIR/debug.log"; exit 0' SIGTERM SIGINT

# Run main function
main
