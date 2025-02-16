# UI Concept Theme Specification (Embedded Gruvbox-Inspired)

This document outlines the UI theme to be implemented directly within scripts. The theme is designed to be minimalist and condensed, using a Gruvbox-inspired color scheme with the following customizations:

- **Headers:**  
  - Use a lighter shade of orange for section headers.
  - Format: `== Section Name ==`
  - ANSI Code: `\033[38;5;215m`  
    *Example:*  
    `== Starting Up ==`

- **Success Messages:**  
  - Use Gruvbox green for messages confirming test success (e.g., "Nginx started", "Network connectivity OK").
  - Format: `[SUCCESS] message`
  - ANSI Code: `\033[38;5;81m`  
    *Example:*  
    `[SUCCESS] Nginx started.`

- **Error Messages:**  
  - Use red for failure messages.
  - Format: `[ERROR] message`
  - ANSI Code: `\033[38;5;124m`  
    *Example:*  
    `[ERROR] Failed to start container.`

- **Info Messages:**  
  - Use yellow for additional informational output.
  - Format: `[INFO] message`
  - ANSI Code: `\033[38;5;223m`  
    *Example:*  
    `[INFO] Please open http://localhost:8080 in your browser.`

- **Reset:**  
  - ANSI Code: `\033[0m`  
    Used to revert the terminal color back to the default styling.

## Embedded UI Functions

As the theme must be implemented within each script, the UI functions and color definitions should be embedded directly. Below is an example of the UI block:

```bash
# Gruvbox-Inspired Color Definitions
HEADER_COLOR="\033[38;5;215m"    # Lighter orange for headers
SUCCESS_COLOR="\033[38;5;81m"    # Gruvbox green for success messages
ERROR_COLOR="\033[38;5;124m"     # Red for errors
INFO_COLOR="\033[38;5;223m"      # Yellow for informational messages
RESET_COLOR="\033[0m"

# UI Functions (Embedded)
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
```

## Output Layout (Condensed, Minimal)

Scripts should follow this structure for output:

1. **Section Headers:**  
   - Displayed as:  
     `== Section Name ==`  
     (In lighter orange.)

2. **Success Messages:**  
   - Displayed as:  
     `[SUCCESS] message`  
     (In Gruvbox green.)

3. **Error Messages:**  
   - Displayed as:  
     `[ERROR] message`  
     (In red.)

4. **Info Messages:**  
   - Displayed as:  
     `[INFO] message`  
     (In yellow.)

## Extended Debug Information

Some sections of the output display minimal details by default. For additional details, use the `-i` flag when running the script:

- **Debug Info:**  
  The "Debug Info" block displays a brief summary
