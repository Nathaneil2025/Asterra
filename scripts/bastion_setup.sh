#!/bin/bash

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /tmp/bastion_setup.log
}

log "Starting bastion setup..."

# Update system and install PostgreSQL client
log "Installing PostgreSQL client..."
sudo apt update -y
sudo apt install -y postgresql-client dnsutils

# Database connection parameters
DB_HOST="${db_host}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
DB_NAME="${db_name}"

log "Database parameters: Host=$DB_HOST, User=$DB_USER, Database=$DB_NAME"

# Function to test DNS resolution
test_dns_resolution() {
    log "Testing DNS resolution for $DB_HOST..."
    if nslookup "$DB_HOST" > /dev/null 2>&1; then
        log "✅ DNS resolution successful"
        return 0
    else
        log "❌ DNS resolution failed"
        return 1
    fi
}

# Function to test database connectivity
test_db_connection() {
    log "Testing database connection..."
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
        log "✅ Database connection successful"
        return 0
    else
        log "❌ Database connection failed"
        return 1
    fi
}

# Function to check if PostGIS is already enabled
check_postgis_status() {
    log "Checking PostGIS status..."
    local result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT installed_version FROM pg_available_extensions WHERE name = 'postgis';" 2>/dev/null | xargs)
    
    if [ -n "$result" ] && [ "$result" != "" ]; then
        log "✅ PostGIS is already enabled (version: $result)"
        return 0
    else
        log "ℹ️  PostGIS is not enabled yet"
        return 1
    fi
}

# Function to enable PostGIS
enable_postgis() {
    log "Attempting to enable PostGIS extension..."
    local output=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>&1)
    local exit_code=$?
    
    log "PostGIS enable output: $output"
    
    if [ $exit_code -eq 0 ]; then
        log "✅ PostGIS extension enabled successfully"
        
        # Verify by checking version
        local version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT PostGIS_Version();" 2>/dev/null | xargs)
        if [ -n "$version" ]; then
            log "✅ PostGIS verification successful: $version"
            return 0
        else
            log "⚠️  PostGIS enabled but verification failed"
            return 1
        fi
    else
        log "❌ Failed to enable PostGIS: $output"
        return 1
    fi
}

# Main execution logic
log "Starting connectivity and PostGIS setup process..."

# Wait and retry logic
MAX_ATTEMPTS=30
WAIT_INTERVAL=30
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
    log "=== Attempt $attempt of $MAX_ATTEMPTS ==="
    
    # Step 1: Test database connection
    if test_db_connection; then
        
        # Step 2: Test DNS resolution
        if test_dns_resolution; then
            
            # Step 3: Check if PostGIS is already enabled
            if check_postgis_status; then
                log "🎉 PostGIS is already enabled, setup complete!"
                break
            else
                # Step 4: Enable PostGIS
                if enable_postgis; then
                    log "🎉 PostGIS setup completed successfully!"
                    break
                else
                    log "❌ PostGIS enable failed, will retry..."
                fi
            fi
        else
            log "DNS resolution failed, will retry in $WAIT_INTERVAL seconds..."
        fi
    else
        log "Database connection failed, will retry in $WAIT_INTERVAL seconds..."
    fi
    
    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        log "Waiting $WAIT_INTERVAL seconds before next attempt..."
        sleep $WAIT_INTERVAL
    fi
    
    attempt=$((attempt + 1))
done

if [ $attempt -gt $MAX_ATTEMPTS ]; then
    log "❌ Failed to setup PostGIS after $MAX_ATTEMPTS attempts"
    log "Check /tmp/bastion_setup.log for details"
else
    log "✅ Setup completed successfully"
fi

# Create connection script for ubuntu user
log "Creating database connection script..."
cat > /home/ubuntu/connect_to_db.sh << EOF
#!/bin/bash
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME"
EOF

chmod +x /home/ubuntu/connect_to_db.sh
chown ubuntu:ubuntu /home/ubuntu/connect_to_db.sh

# Create environment file
cat > /home/ubuntu/.db_env << EOF
export DB_HOST="$DB_HOST"
export DB_USER="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export DB_NAME="$DB_NAME"
EOF

chown ubuntu:ubuntu /home/ubuntu/.db_env

log "=== Bastion setup completed ==="
log "Check /tmp/bastion_setup.log for full details"
log "Use ./connect_to_db.sh to connect to the database"