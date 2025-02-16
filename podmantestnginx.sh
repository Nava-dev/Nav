#!/bin/bash
set -e

# Function to print section headers
print_section() {
  echo -e "\n\033[1;34m========== $1 ==========\033[0m\n"
}

# Function to print success messages
print_success() {
  echo -e "\n\033[1;32m$1\033[0m\n"
}

# Function to print error messages
print_error() {
  echo -e "\n\033[1;31m$1\033[0m\n"
}

# Function to print info messages
print_info() {
  echo -e "\n\033[1;36m$1\033[0m\n"
}

# Function to remove an existing container if it exists
remove_existing_container() {
  container_name=$1
  if podman ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    print_info "Removing existing container with name ${container_name}"
    podman rm -f "${container_name}"
  fi
}

# Function to find a free host port in the range 49152-65535
get_free_port() {
  while :; do
    port=$(shuf -i 49152-65535 -n 1)
    if ! ss -lntu | grep -q ":${port} "; then
      echo "${port}"
      return
    fi
  done
}

#####
# Step 1: Pull the official nginx image (Alpine variant) using a fully qualified name.
#####
print_section "Pulling the official docker.io/nginx:alpine image"
if podman pull docker.io/nginx:alpine; then
  print_success "Successfully pulled the official docker.io/nginx:alpine image."
else
  print_error "Failed to pull docker.io/nginx:alpine image."
  exit 1
fi

remove_existing_container "test-nginx"

# Select a free host port dynamically
free_port=$(get_free_port)
print_info "Selected free host port: ${free_port}"

#####
# Step 2: Run the nginx container without mounting a volume.
# This preserves the default content located at /usr/share/nginx/html.
#####
print_section "Running a test container using official nginx image on free port ${free_port}"
if podman run -d --name test-nginx -p "${free_port}":80 docker.io/nginx:alpine; then
  print_success "Successfully started the test container with nginx on port ${free_port}."
else
  print_error "Failed to start the test container."
  exit 1
fi

# Allow some time for the container to fully start nginx
sleep 3

#####
# Step 3: Install curl inside container temporarily for internal testing.
# Note: The official nginx container is minimal and may not include curl.
#####
print_section "Installing curl inside container (temporarily)"
if podman exec test-nginx sh -c "apk update && apk add --no-cache curl"; then
  print_success "Curl installed inside container."
else
  print_error "Failed to install curl inside container."
fi

#####
# Step 4: Debug the default nginx page (the image's default index.html).
#####
print_section "Debug: Accessing default nginx page from within container (using curl)"
default_page=$(podman exec test-nginx sh -c "curl -s http://localhost")
if echo "$default_page" | grep -qi "Welcome"; then
  print_success "Inside container: Default nginx page is accessible."
else
  print_error "Inside container: Unable to fetch default nginx page."
fi

#####
# Step 5: Copy a custom file into the container.
# This new file will be created at /usr/share/nginx/html/newfile.html.
#####
print_section "Creating a new custom file in the container"
if podman exec test-nginx sh -c "echo 'Hello, this is the new file!' > /usr/share/nginx/html/newfile.html"; then
  print_success "New file created successfully at /usr/share/nginx/html/newfile.html."
else
  print_error "Failed to create new file in container."
fi

#####
# Step 6: Test with curl inside the container that the new file is accessible.
#####
print_section "Debug: Accessing new file from within container (using curl)"
newfile_page=$(podman exec test-nginx sh -c "curl -s http://localhost/newfile.html")
if echo "$newfile_page" | grep -q "Hello, this is the new file!"; then
  print_success "Inside container: New file is accessible."
else
  print_error "Inside container: Unable to fetch new file."
fi

#####
# Step 7: Output URL for user verification and pause for manual check
#####
print_section "User Verification Required"
default_url="http://localhost:${free_port}"
newfile_url="http://localhost:${free_port}/newfile.html"
echo -e "\033[1;36mPlease open the following URLs in your browser to verify:\033[0m"
echo -e "\033[1;36mDefault nginx page URL: ${default_url}\033[0m"
echo -e "\033[1;36mNew file URL: ${newfile_url}\033[0m"
read -p "After verifying the pages, press Enter to continue with the automated host access tests..."

#####
# Step 8: Test host access for both the default page and the new file.
#####
print_section "Checking host access on port ${free_port} for default page"
sleep 2
host_default=$(curl -s http://localhost:"${free_port}")
if echo "$host_default" | grep -qi "Welcome"; then
  print_success "Host: Default nginx page is accessible on port ${free_port}."
else
  print_error "Host: Failed to access default nginx page on port ${free_port}."
fi

print_section "Checking host access on port ${free_port} for new file"
host_newfile=$(curl -s http://localhost:"${free_port}/newfile.html")
if echo "$host_newfile" | grep -q "Hello, this is the new file!"; then
  print_success "Host: New file is accessible on port ${free_port}."
else
  print_error "Host: Failed to access new file on port ${free_port}."
fi

#####
# Step 9: Cleanup - stop and remove the test container.
#####
print_section "Cleaning up: Removing test container"
if podman stop test-nginx && podman rm test-nginx; then
  print_success "Successfully cleaned up test container."
else
  print_error "Failed to clean up test container."
fi

print_success "Test completed successfully!"
``` ▋
