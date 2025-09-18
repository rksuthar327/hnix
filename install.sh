#!/usr/bin/env bash
#
# RKniX Panel Installer
# Simple installer script that downloads and runs the main setup script
#
# Usage: bash install.sh <LICENSE_KEY>
# Example: bash install.sh RKN-ABC123XYZ456789
#

set -euo pipefail

# Configuration
# TEMPORARY TESTING - REMOVE AFTER TESTING
TESTING_MODE="true"  # Set to "true" to bypass license verification for testing
# END TEMPORARY TESTING

GITHUB_RAW_URL="https://raw.githubusercontent.com/rksuthar327/RKniX/master/setup.sh"
GITHUB_TOKEN="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"  # GitHub token for private repo access
SETUP_SCRIPT_NAME="rknix_setup.sh"
TEMP_DIR="/tmp/rknix_install"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to display banner
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                     RKniX Panel Installer                   ║"
    echo "║                                                              ║"
    echo "║  This script will download and install the RKniX Panel      ║"
    echo "║  with all required components and dependencies.              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        echo "Usage: sudo bash install.sh <LICENSE_KEY>"
        echo "Example: sudo bash install.sh RKN-ABC123XYZ456789"
        exit 1
    fi
}

# Function to check OS compatibility
check_os() {
    log_info "Checking operating system compatibility..."
    
    # Check if it's Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "This installer only supports Linux operating systems"
        exit 1
    fi
    
    # Check for Ubuntu/Debian (look for apt-get)
    if ! command -v apt-get >/dev/null 2>&1; then
        log_error "This installer requires Ubuntu or Debian (apt-get not found)"
        log_info "Supported distributions:"
        log_info "  - Ubuntu 18.04 LTS or later"
        log_info "  - Debian 9 or later"
        exit 1
    fi
    
    # Try to get specific OS info
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            log_success "Detected Ubuntu $VERSION_ID"
            
            # Check Ubuntu version
            version_major=$(echo "$VERSION_ID" | cut -d. -f1)
            if [[ $version_major -lt 18 ]]; then
                log_warning "Ubuntu $VERSION_ID detected. Recommended: Ubuntu 18.04 LTS or later"
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Installation cancelled"
                    exit 0
                fi
            fi
        elif [[ "$ID" == "debian" ]]; then
            log_success "Detected Debian $VERSION_ID"
            
            # Check Debian version
            version_major=$(echo "$VERSION_ID" | cut -d. -f1)
            if [[ $version_major -lt 9 ]]; then
                log_warning "Debian $VERSION_ID detected. Recommended: Debian 9 or later"
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Installation cancelled"
                    exit 0
                fi
            fi
        else
            log_warning "Detected $PRETTY_NAME"
            log_warning "This installer is optimized for Ubuntu/Debian"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
        fi
    else
        log_warning "Could not detect specific OS version"
        log_info "Proceeding with installation..."
    fi
}

# Function to validate license key format
validate_license_key() {
    local license_key="$1"
    
    # TEMPORARY TESTING BYPASS - REMOVE AFTER TESTING
    if [[ "$TESTING_MODE" == "true" ]]; then
        log_info "🧪 TESTING MODE: Bypassing license key validation"
        log_info "License Key: $license_key (not validated)"
        return 0
    fi
    # END TEMPORARY TESTING BYPASS
    
    if [[ -z "$license_key" ]]; then
        log_error "License key is required"
        echo ""
        echo "Usage: sudo bash install.sh <LICENSE_KEY>"
        echo "Example: sudo bash install.sh RKN-ABC123XYZ456789"
        echo ""
        echo "Get your license key from: https://your-license-provider.com"
        exit 1
    fi
    
    # Basic format validation (RKN- followed by 15 alphanumeric characters)
    if [[ ! "$license_key" =~ ^RKN-[A-Z0-9]{15}$ ]]; then
        log_error "Invalid license key format"
        echo ""
        echo "License key must be in format: RKN-XXXXXXXXXXXXXXX"
        echo "Where X is an alphanumeric character (15 characters after RKN-)"
        echo ""
        echo "Example: RKN-ABC123XYZ456789"
        exit 1
    fi
    
    log_success "License key format is valid"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for curl
    if ! command -v curl >/dev/null 2>&1; then
        log_info "Installing curl..."
        apt-get update -qq
        apt-get install -y curl
    fi
    
    # Check internet connectivity
    if ! curl -s --connect-timeout 5 https://google.com >/dev/null; then
        log_error "No internet connection detected"
        log_info "Please check your internet connection and try again"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Function to create temporary directory
create_temp_dir() {
    log_info "Creating temporary directory..."
    
    # Remove existing temp directory if it exists
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    log_success "Temporary directory created: $TEMP_DIR"
}

# Function to download main setup script
download_setup_script() {
    log_info "Downloading main setup script from private GitHub repository..."
    
    local script_path="$TEMP_DIR/$SETUP_SCRIPT_NAME"
    
    # Download the setup script using GitHub token for private repo access
    if [[ -n "$GITHUB_TOKEN" ]]; then
        # Use token for private repository access
        log_info "Using GitHub token for private repository access"
        if curl -fsSL -H "Authorization: token $GITHUB_TOKEN" -o "$script_path" "$GITHUB_RAW_URL"; then
            log_success "Setup script downloaded successfully from private repository"
        else
            log_error "Failed to download setup script from private GitHub repository"
            log_info "Please check:"
            log_info "  - GitHub token validity and permissions"
            log_info "  - Private repository accessibility"
            log_info "  - Internet connection"
            log_info "  - URL: $GITHUB_RAW_URL"
            exit 1
        fi
    else
        # Fallback to public access (will likely fail for private repo)
        log_warning "No GitHub token provided, attempting public access"
        if curl -fsSL -o "$script_path" "$GITHUB_RAW_URL"; then
            log_success "Setup script downloaded successfully"
        else
            log_error "Failed to download setup script from GitHub"
            log_info "For private repositories, please set GITHUB_TOKEN in the install script"
            log_info "Please check:"
            log_info "  - Internet connection"
            log_info "  - GitHub repository accessibility"
            log_info "  - URL: $GITHUB_RAW_URL"
            exit 1
        fi
    fi
    
    # Make the script executable
    chmod +x "$script_path"
    
    # Verify the script was downloaded correctly
    if [[ ! -f "$script_path" ]] || [[ ! -s "$script_path" ]]; then
        log_error "Downloaded script is empty or missing"
        exit 1
    fi
    
    # Basic validation - check if it looks like a bash script
    if ! head -n 1 "$script_path" | grep -q "#!/"; then
        log_error "Downloaded file does not appear to be a valid script"
        exit 1
    fi
    
    log_success "Script validation completed"
}

# Function to run the main setup script
run_setup_script() {
    local license_key="$1"
    local script_path="$TEMP_DIR/$SETUP_SCRIPT_NAME"
    
    log_info "Starting RKniX Panel installation..."
    echo ""
    log_info "Running main setup script with license key: $license_key"
    echo ""
    
    # Run the main setup script with the license key
    if bash "$script_path" "$license_key"; then
        log_success "RKniX Panel installation completed successfully!"
    else
        log_error "Installation failed"
        log_info "Setup script exited with error code: $?"
        exit 1
    fi
}

# Function to cleanup temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    
    # Remove temporary directory
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_success "Temporary files cleaned up"
    fi
}

# Function to cleanup both installer and setup scripts
cleanup_all_scripts() {
    local script_name="$0"
    local setup_script="$TEMP_DIR/$SETUP_SCRIPT_NAME"
    
    log_info "Cleaning up all installation scripts..."
    
    # Remove setup script if it exists
    if [[ -f "$setup_script" ]]; then
        rm -f "$setup_script" 2>/dev/null
        log_success "Setup script cleaned up"
    fi
    
    # Schedule self-deletion of installer script
    if [[ -f "$script_name" ]] && [[ "$script_name" != "/dev/stdin" ]] && [[ "$script_name" != "bash" ]]; then
        # Create a cleanup script that will run in background
        cat > "/tmp/cleanup_installer.sh" <<CLEANUP_SCRIPT
#!/bin/bash
sleep 3
rm -f "$script_name" 2>/dev/null
rm -f "/tmp/cleanup_installer.sh" 2>/dev/null
CLEANUP_SCRIPT
        chmod +x "/tmp/cleanup_installer.sh"
        nohup "/tmp/cleanup_installer.sh" >/dev/null 2>&1 &
        log_success "Installer script scheduled for automatic deletion"
    fi
}

# Function to show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 🎉 Installation Complete! 🎉                ║"
    echo "║                                                              ║"
    echo "║  RKniX Panel has been successfully installed and configured  ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Trap to ensure cleanup on exit (but not cleanup_all_scripts yet)
trap cleanup EXIT

# Main execution
main() {
    # Show banner
    show_banner
    
    # Check if license key is provided (unless in testing mode)
    if [[ $# -lt 1 ]] && [[ "$TESTING_MODE" != "true" ]]; then
        log_error "License key is required"
        echo ""
        echo "Usage: sudo bash install.sh <LICENSE_KEY>"
        echo "Example: sudo bash install.sh RKN-ABC123XYZ456789"
        exit 1
    fi
    
    # Set license key (use TEST key if none provided in testing mode)
    local license_key="${1:-TEST-LICENSE-KEY123}"
    
    # Show testing mode warning
    if [[ "$TESTING_MODE" == "true" ]]; then
        echo ""
        log_warning "🧪 RUNNING IN TESTING MODE 🧪"
        log_warning "License verification is BYPASSED"
        log_warning "Remove TESTING_MODE before production use"
        echo ""
        sleep 2
    fi
    
    # Execute installation steps
    check_root
    check_os
    validate_license_key "$license_key"
    check_prerequisites
    create_temp_dir
    download_setup_script
    run_setup_script "$license_key"
    
    # Show completion message
    show_completion
    
    # Clean up all scripts after successful installation
    cleanup_all_scripts
    
    log_success "Installation process completed!"
}

# Run main function with all arguments
main "$@"
