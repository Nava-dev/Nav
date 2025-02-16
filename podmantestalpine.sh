#!/bin/bash
set -e

# Version: 2.1.5
# This script tests an Alpine container with integrated network and Nginx tests.
# It uses a Gruvbox-inspired theme with the following customizations:
#   - Headers use a lighter shade of orange.
#   - Success messages use Gruvbox green.
#   - Error messages are in red.
#   - Informational messages are in yellow.
#
# Flags:
#   -h  : Show help.
#   -i  : Enable extended debug output (full config contents & Alpine image inspect output).
#   -p  : Prompt for webpage verification at http://localhost:8080.

# Gruvbox-inspired Color Definitions (Updated)
HEADER_COLOR="\033[38;5;215m"    # Lighter orange for headers
SUCCESS_COLOR="\033[38;5;81m"    # Gruvbox green for success messages
ERROR_COLOR="\033[38;5;124m"     # Red for errors
INFO_COLOR="\033[38;5;223m"      # Yellow for info/messages
RESET_COLOR="\033[0m"

# UI Functions
print_section() {
    echo -e "${HEADER_COLOR}== $1 ==${RESET_COLOR}"
}
print_success() {
    echo -e "${SUCCESS_COLOR}[SUCCESS] $1${RESET_COLOR}"
}
print_error() {
    echo -e "${ERROR_COLOR}[ERROR] $1${RESET_COLOR}"
}
print_info() {
    echo -e "${INFO_COLOR}[INFO] $1${RESET_COLOR}"
}

# Flag Variables
EXT_DEBUG=false
PROMPT_FOR_LINK=false

# Parse flags: -h, -i, -p
while getopts ":hip" opt; do
    case $opt in
        h)
            echo "Usage: $0 [-h] [-i] [-p]"
            echo "  -h  : Show help."
            echo "  -i  : Enable extended debug output (full config contents & Alpine image inspect output)."
            echo "  -p  : Prompt for webpage verification at http://localhost:8080."
            exit 0
            ;;
        i)
            EXT_DEBUG=true
            ;;
        p)
            PROMPT_FOR_LINK=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Utility: Remove an existing container if present.
remove_existing_container() {
    container_name=$1
    if podman ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        print_info "Removing existing container: ${container_name}"
        podman rm -f "${container_name}"
    fi
}

# Main Script Steps

# Step 1: Pull the latest Alpine image.
print_section "Pulling Alpine Image"
if podman pull alpine:latest; then
    print_success "Alpine image pulled."
else
    print_error "Failed to pull Alpine image."
    exit 1
fi

# Step 2: Remove test container (if exists).
remove_existing_container "test-alpine"

# Step 3: Start test container (Mapping host port 8080 to container port 80).
print_section "Starting Test Container"
if podman run -d --name test-alpine -p 8080:80 alpine:latest /bin/sh -c "while true; do sleep 1; done"; then
    print_success "Test container started."
else
    print_error "Container failed to start."
    exit 1
fi

# Step 4: Verify container is running.
print_section "Verifying Container"
if podman ps -a | grep -q "test-alpine"; then
    print_success "Container is running."
else
    print_error "Container is not running."
    podman logs test-alpine
    remove_existing_container "test-alpine"
    exit 1
fi

# Step 5: Test network connectivity inside the container.
print_section "Checking Network Connectivity"
if podman exec test-alpine ping -c 4 google.com; then
    print_success "Network connectivity OK."
else
    print_error "Network test failed. Output of /etc/resolv.conf:"
    podman exec test-alpine cat /etc/resolv.conf
    exit 1
fi

# Step 6: Install Nginx inside the container.
print_section "Installing Nginx"
if podman exec test-alpine sh -c "apk update && apk add --no-cache nginx"; then
    print_success "Nginx installed."
else
    print_error "Failed to install Nginx."
    podman logs test-alpine
    exit 1
fi

# Step 7: Configure Nginx.
print_section "Configuring Nginx"
podman exec test-alpine sh -c "cat > /etc/nginx/nginx.conf <<'EOF'
worker_processes 1;
pid /var/run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/conf.d/*.conf;
}
EOF"
print_success "Created /etc/nginx/nginx.conf"

podman exec test-alpine sh -c "mkdir -p /etc/nginx/conf.d && cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/localhost/htdocs;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF"
print_success "Created /etc/nginx/conf.d/default.conf"

# Step 8: Start Nginx.
print_section "Starting Nginx"
if podman exec test-alpine sh -c "nginx"; then
    print_success "Nginx started."
else
    print_error "Failed to start Nginx."
    podman logs test-alpine
    exit 1
fi
sleep 2

# Step 9: Create a web page with an H1 header.
print_section "Creating Web Page"
if podman exec test-alpine sh -c 'mkdir -p /var/www/localhost/htdocs && echo "<h1>The page confirms the Podman test using alpine image installs nginx and serves web pages accessible on the host machine.</h1>" > /var/www/localhost/htdocs/index.html'; then
    print_success "Web page created."
else
    print_error "Failed to create web page."
    podman logs test-alpine
    exit 1
fi

# Reload Nginx to load the new page.
podman exec test-alpine sh -c "nginx -s reload" || true

# Step 10: Prompt for webpage verification if enabled.
if $PROMPT_FOR_LINK; then
    print_section "Webpage Verification"
    print_info "Please open http://localhost:8080 in your browser to verify the page."
    read -p "Press ENTER to continue..." dummy
fi

# Step 11: Output Minimal Debug Information.
print_section "Debug Info"
print_info "[Note] Run the script with the -i flag for detailed container logs."
if $EXT_DEBUG; then
    print_info "Document root listing:"
    podman exec test-alpine sh -c "ls -l /var/www/localhost/htdocs"
    echo ""
    print_info "Nginx main config (first 10 lines):"
    podman exec test-alpine sh -c "head -n 10 /etc/nginx/nginx.conf"
    echo ""
    print_info "Default server config:"
    podman exec test-alpine sh -c "cat /etc/nginx/conf.d/default.conf" || echo "default.conf not found"
    echo ""
    print_info "Config Explanation:"
    echo "  /etc/nginx/nginx.conf contains the http block that includes conf.d/*.conf."
    echo "  /etc/nginx/conf.d/default.conf defines a server on port 80, with the document root set to /var/www/localhost/htdocs."
    echo ""
fi

# Step 12: Test localhost access using curl.
print_section "Testing Localhost Access"
sleep 5
if curl -s http://localhost:8080 | grep -q "Podman test"; then
    print_success "Web page accessible."
else
    print_error "Web page NOT accessible."
    podman logs test-alpine
    exit 1
fi

# Step 13: Output container logs.
print_section "Container Logs"
print_info "[Note] Run the script with the -i flag for detailed container logs."
logs_output=$(podman logs test-alpine)
# The message below indicates that no log entries were produced by the container during its execution.
if [ -z "$logs_output" ]; then
    print_info "No container logs available."
else
    echo "$logs_output"
fi

# Step 14: Clean up - remove the test container.
print_section "Cleaning Up"
if podman stop test-alpine && podman rm test-alpine; then
    print_success "Container cleaned up."
else
    print_error "Cleanup failed."
    exit 1
fi

print_success "Test completed successfully!"
