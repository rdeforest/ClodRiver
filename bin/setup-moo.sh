#!/bin/bash
# ClodRiver MOO Setup Script
# Sets up LambdaMOO server with Waterpoint core for development

set -e  # Exit on any error

# Configuration
MOO_DIR="./moo"
LAMBDAMOO_DIR="$MOO_DIR/lambdamoo"
MOO_PORT="7777"
MOO_DB="waterpoint.db"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[MOO Setup]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[MOO Setup]${NC} $1"
}

error() {
    echo -e "${RED}[MOO Setup]${NC} $1"
    exit 1
}

check_dependencies() {
    log "Checking dependencies..."
    
    command -v gcc >/dev/null 2>&1 || command -v clang >/dev/null 2>&1 || error "gcc or clang is required but not installed"
    command -v make >/dev/null 2>&1 || error "make is required but not installed"
    command -v git >/dev/null 2>&1 || error "git is required for submodules"
    
    log "Dependencies check passed"
}

setup_lambdamoo_submodule() {
    log "Setting up LambdaMOO submodule..."
    
    # Check if we're in a git repository
    if [ ! -d ".git" ]; then
        error "Not in a git repository. Please run from project root."
    fi
    
    # Initialize submodule if it doesn't exist
    if [ ! -d "moo/lambdamoo/.git" ]; then
        log "Adding LambdaMOO submodule..."
        git submodule add https://github.com/wrog/lambdamoo.git moo/lambdamoo
    else
        log "LambdaMOO submodule already exists"
    fi
    
    # Ensure submodule is up to date
    log "Updating submodule..."
    git submodule update --init --recursive
    
    mkdir -p "$MOO_DIR"
}

compile_lambdamoo() {
    log "Compiling LambdaMOO..."
    cd "$LAMBDAMOO_DIR"
    
    # Configure and compile
    ./configure
    make
    
    log "LambdaMOO compiled successfully"
    cd ../../
}

setup_waterpoint() {
    log "Setting up Waterpoint core..."
    
    if [ ! -f "waterpoint.db" ]; then
        warn "Please place waterpoint.db in the project root directory"
        warn "You can download it from the Waterpoint MOO site"
        warn "The script will continue, but you'll need the database file to run the MOO"
    fi
    
    # Create MOO configuration
    cat > "$MOO_DIR/moo.conf" << EOF
# ClodRiver MOO Configuration
port = $MOO_PORT
database = ../$MOO_DB
log_file = moo.log
checkpoint_interval = 3600
dump_interval = 3600
max_connections = 10
EOF
    
    log "MOO configuration created"
}

create_startup_script() {
    log "Creating startup script..."
    
    cat > "$MOO_DIR/start-moo.sh" << 'EOF'
#!/bin/bash
# Start the MOO server for ClodRiver development

MOO_DIR="$(dirname "$0")"
cd "$MOO_DIR"

if [ ! -f "../waterpoint.db" ]; then
    echo "Error: waterpoint.db not found in project root"
    echo "Please download the Waterpoint core database"
    exit 1
fi

echo "Starting LambdaMOO server..."
echo "Connect to: telnet localhost 7777"
echo "Press Ctrl+C to stop"

./lambdamoo/moo -f moo.conf ../waterpoint.db
EOF
    
    chmod +x "$MOO_DIR/start-moo.sh"
    
    log "Startup script created at $MOO_DIR/start-moo.sh"
}

create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Stop script
    cat > "$MOO_DIR/stop-moo.sh" << 'EOF'
#!/bin/bash
# Stop the MOO server

echo "Stopping MOO server..."
pkill -f "moo.*waterpoint.db" || echo "No MOO process found"
EOF
    chmod +x "$MOO_DIR/stop-moo.sh"
    
    # Status script
    cat > "$MOO_DIR/status-moo.sh" << 'EOF'
#!/bin/bash
# Check MOO server status

if pgrep -f "moo.*waterpoint.db" > /dev/null; then
    echo "MOO server is running"
    echo "Connections:"
    netstat -an 2>/dev/null | grep :7777 || ss -an 2>/dev/null | grep :7777 || echo "Could not check connections"
else
    echo "MOO server is not running"
fi
EOF
    chmod +x "$MOO_DIR/status-moo.sh"
    
    log "Helper scripts created"
}

main() {
    log "Starting LambdaMOO setup for ClodRiver..."
    
    check_dependencies
    setup_lambdamoo_submodule
    compile_lambdamoo
    setup_waterpoint
    create_startup_script
    create_helper_scripts
    
    log "MOO setup complete!"
    echo
    echo "Next steps:"
    echo "1. Place waterpoint.db in the project root directory"
    echo "2. Run: ./moo/start-moo.sh"
    echo "3. Connect with: telnet localhost 7777"
    echo
    echo "Helper commands:"
    echo "  ./moo/start-moo.sh  - Start the MOO server"
    echo "  ./moo/stop-moo.sh   - Stop the MOO server"  
    echo "  ./moo/status-moo.sh - Check server status"
}

main "$@"