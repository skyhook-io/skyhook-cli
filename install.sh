#!/bin/sh
# Skyhook CLI Installer
# Usage: curl -fsSL https://get.skyhook.io | sh
#
# Environment variables:
#   SKYHOOK_INSTALL_DIR - Override installation directory
#   SKYHOOK_VERSION     - Install specific version (default: latest)

set -e

# Configuration
GITHUB_OWNER="skyhook-io"
GITHUB_REPO="skyhook-cli"
BINARY_NAME="skyhook"

# Installation directories
SYSTEM_BIN="/usr/local/bin"
USER_BIN="$HOME/.local/bin"

# Colors (disabled if not interactive)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

info() {
    printf "${BLUE}==>${NC} ${BOLD}%s${NC}\n" "$1"
}

success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}!${NC} %s\n" "$1"
}

error() {
    printf "${RED}✗${NC} %s\n" "$1" >&2
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "Linux" ;;
        Darwin*) echo "Darwin" ;;
        MINGW*|MSYS*|CYGWIN*) echo "Windows" ;;
        *)       error "Unsupported operating system: $(uname -s)"; exit 1 ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x86_64" ;;
        arm64|aarch64) echo "arm64" ;;
        i386|i686)     echo "i386" ;;
        *)             error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/'
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/'
    else
        error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
}

# Download file
download() {
    url="$1"
    dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    fi
}

# Determine installation directory
get_install_dir() {
    # User override takes precedence
    if [ -n "$SKYHOOK_INSTALL_DIR" ]; then
        echo "$SKYHOOK_INSTALL_DIR"
        return
    fi

    # Running as root → system directory
    if [ "$(id -u)" -eq 0 ]; then
        echo "$SYSTEM_BIN"
        return
    fi

    # Non-root → user directory
    echo "$USER_BIN"
}

# Detect user's shell and its config file
detect_shell_config() {
    # Check what shell is set as default
    user_shell="$(basename "$SHELL")"

    case "$user_shell" in
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                echo "$HOME/.zshrc"
            else
                echo "$HOME/.zprofile"
            fi
            ;;
        bash)
            # macOS uses .bash_profile, Linux typically uses .bashrc
            if [ "$(detect_os)" = "Darwin" ]; then
                if [ -f "$HOME/.bash_profile" ]; then
                    echo "$HOME/.bash_profile"
                else
                    echo "$HOME/.profile"
                fi
            else
                if [ -f "$HOME/.bashrc" ]; then
                    echo "$HOME/.bashrc"
                else
                    echo "$HOME/.profile"
                fi
            fi
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            # Fallback to .profile for POSIX compatibility
            echo "$HOME/.profile"
            ;;
    esac
}

# Add directory to PATH in shell config
add_to_path() {
    dir="$1"
    config_file="$(detect_shell_config)"
    shell_name="$(basename "$SHELL")"

    # Create config file if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"

    # Check if already configured
    if grep -q "$dir" "$config_file" 2>/dev/null; then
        return 0
    fi

    # Add appropriate export line
    case "$shell_name" in
        fish)
            echo "" >> "$config_file"
            echo "# Skyhook CLI" >> "$config_file"
            echo "fish_add_path $dir" >> "$config_file"
            ;;
        *)
            echo "" >> "$config_file"
            echo "# Skyhook CLI" >> "$config_file"
            echo "export PATH=\"\$PATH:$dir\"" >> "$config_file"
            ;;
    esac

    return 1  # Indicates PATH was modified
}

# Check if directory is in PATH
is_in_path() {
    dir="$1"
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
        *) return 1 ;;
    esac
}

main() {
    echo ""
    printf "${BOLD}Skyhook CLI Installer${NC}\n"
    echo ""

    # Detect platform
    OS="$(detect_os)"
    ARCH="$(detect_arch)"
    info "Detected platform: $OS $ARCH"

    # Get version
    if [ -n "$SKYHOOK_VERSION" ]; then
        VERSION="$SKYHOOK_VERSION"
    else
        info "Fetching latest version..."
        VERSION="$(get_latest_version)"
    fi

    if [ -z "$VERSION" ]; then
        error "Failed to determine version to install"
        exit 1
    fi

    info "Installing skyhook v${VERSION}"

    # Determine install location
    INSTALL_DIR="$(get_install_dir)"

    # Build download URL
    # Format: skyhook_darwin_all.tar.gz, skyhook_linux_amd64.tar.gz, skyhook_windows_amd64.zip

    # Map architecture names
    case "$ARCH" in
        x86_64) ARCH_NAME="amd64" ;;
        arm64)  ARCH_NAME="arm64" ;;
        *)      ARCH_NAME="$ARCH" ;;
    esac

    # Map OS names (lowercase for goreleaser)
    case "$OS" in
        Darwin) OS_NAME="darwin"; ARCH_NAME="all" ;;  # Universal binary
        Linux)  OS_NAME="linux" ;;
        Windows) OS_NAME="windows" ;;
        *)      OS_NAME="$(echo "$OS" | tr '[:upper:]' '[:lower:]')" ;;
    esac

    if [ "$OS" = "Windows" ]; then
        ARCHIVE_EXT="zip"
    else
        ARCHIVE_EXT="tar.gz"
    fi
    ARCHIVE_NAME="skyhook_${OS_NAME}_${ARCH_NAME}.${ARCHIVE_EXT}"
    DOWNLOAD_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"

    # Create temp directory
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Download
    info "Downloading from GitHub releases..."
    ARCHIVE_PATH="$TMP_DIR/$ARCHIVE_NAME"
    if ! download "$DOWNLOAD_URL" "$ARCHIVE_PATH"; then
        error "Failed to download $DOWNLOAD_URL"
        error "Please check if the release exists for your platform ($OS $ARCH)"
        exit 1
    fi
    success "Downloaded $ARCHIVE_NAME"

    # Extract
    info "Extracting..."
    cd "$TMP_DIR"
    if [ "$ARCHIVE_EXT" = "zip" ]; then
        unzip -q "$ARCHIVE_NAME"
    else
        tar -xzf "$ARCHIVE_NAME"
    fi

    # Find binary (might be in root or subdirectory)
    BINARY_PATH="$(find "$TMP_DIR" -name "$BINARY_NAME" -type f | head -1)"
    if [ -z "$BINARY_PATH" ]; then
        error "Binary not found in archive"
        exit 1
    fi

    # Create install directory if needed
    mkdir -p "$INSTALL_DIR"

    # Install binary
    info "Installing to $INSTALL_DIR..."
    mv "$BINARY_PATH" "$INSTALL_DIR/$BINARY_NAME"
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    success "Installed $BINARY_NAME to $INSTALL_DIR"

    # Handle PATH for user installs
    NEEDS_SHELL_RESTART=false
    if [ "$INSTALL_DIR" = "$USER_BIN" ]; then
        if is_in_path "$INSTALL_DIR"; then
            success "$INSTALL_DIR is already in your PATH"
        else
            warn "$INSTALL_DIR is not in your PATH"
            info "Adding to shell configuration..."

            if add_to_path "$INSTALL_DIR"; then
                success "PATH already configured in shell config"
            else
                CONFIG_FILE="$(detect_shell_config)"
                success "Added to $CONFIG_FILE"
                NEEDS_SHELL_RESTART=true
            fi
        fi
    fi

    # Done!
    echo ""
    printf "${GREEN}${BOLD}Skyhook CLI installed successfully!${NC}\n"
    echo ""

    if [ "$NEEDS_SHELL_RESTART" = true ]; then
        echo "To start using skyhook, run:"
        echo ""
        printf "    ${BOLD}source %s${NC}\n" "$(detect_shell_config)"
        echo ""
        echo "Or open a new terminal window."
        echo ""
    fi

    echo "Get started:"
    echo ""
    printf "    ${BOLD}skyhook --help${NC}\n"
    echo ""
}

main "$@"
