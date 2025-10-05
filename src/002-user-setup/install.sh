#!/usr/bin/env zsh
set -e

# Logging mechanism for debugging
LOG_FILE="/tmp/002-user-setup-install.log"
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >> "$LOG_FILE"
}

# Initialize logging
log_debug "=== 002-USER-SETUP INSTALL STARTED ==="
log_debug "Script path: $0"
log_debug "PWD: $(pwd)"
log_debug "Environment: USER=$USER HOME=$HOME"

# Set DEBIAN_FRONTEND to noninteractive to prevent prompts
export DEBIAN_FRONTEND=noninteractive

USERNAME=${USERNAME:-"babaji"}
PASSWORD=${PASSWORD:-"babaji"}
USER_UID=${USER_UID:-"1000"}
USER_GID=${USER_GID:-"1000"}

echo "Setting up user ${USERNAME}..."

# Only create the user if it doesn't already exist
if id "$USERNAME" >/dev/null 2>&1; then
  echo "User $USERNAME already exists, skipping creation."
else
  # Create the user with home directory, zsh shell, and specific UID/GID
  useradd -m -s /bin/zsh -u "$USER_UID" -g "$USER_GID" "$USERNAME" || {
    # If group doesn't exist, create it first
    groupadd -g "$USER_GID" "$USERNAME" 2>/dev/null || true
    useradd -m -s /bin/zsh -u "$USER_UID" -g "$USER_GID" "$USERNAME"
  }

  # Set the password for the new user
  echo "$USERNAME:$PASSWORD" | chpasswd

  echo "User $USERNAME created."
fi

# Ensure user has zsh as default shell (force change even if user already existed)
echo "Setting default shell to zsh for user $USERNAME..."
# First make sure zsh is installed
if ! command -v zsh >/dev/null 2>&1; then
    echo "Zsh not found, installing..."
    apt-get update && apt-get install -y zsh
fi

# Try multiple zsh paths and force change
echo "Current shell for $USERNAME: $(getent passwd $USERNAME | cut -d: -f7)"
if chsh -s /usr/bin/zsh "$USERNAME" 2>/dev/null; then
    echo "Set shell to /usr/bin/zsh"
elif chsh -s /bin/zsh "$USERNAME" 2>/dev/null; then
    echo "Set shell to /bin/zsh"
else
    # Force change by editing /etc/passwd directly
    echo "chsh failed, editing /etc/passwd directly..."
    sed -i "s|^$USERNAME:\([^:]*:\)\{5\}[^:]*:|$USERNAME:\1/usr/bin/zsh:|" /etc/passwd
    echo "Forced shell change in /etc/passwd"
fi
echo "Final shell for $USERNAME: $(getent passwd $USERNAME | cut -d: -f7)"

# Create a post-install hook to ensure shell stays zsh even if other features try to change it
mkdir -p /etc/profile.d
cat > /etc/profile.d/force-zsh-shell.sh << 'EOF'
#!/usr/bin/env zsh
# Force zsh shell for babaji user - runs after all features
if [ "$USER" = "babaji" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
    export SHELL="/usr/bin/zsh"
fi
EOF
chmod +x /etc/profile.d/force-zsh-shell.sh

# Add user to the sudo group and ensure they can use it without a password
usermod -aG sudo "$USERNAME"
mkdir -p /etc/sudoers.d
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 0440 "/etc/sudoers.d/$USERNAME"

# Set password to match username for easy SSH access
echo "$USERNAME:$USERNAME" | chpasswd
echo "Password set to '$USERNAME' for user $USERNAME"

echo "User $USERNAME setup complete."

# Create workspace symlink setup script
echo "Creating workspace symlink setup script..."
cat << 'EOF' > /usr/local/bin/setup-workspace-link
#!/usr/bin/env zsh
# Setup workspace symlink for consistent paths

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Standard path we expect
STANDARD_PATH="/workspaces/shellinator"

# If standard path already exists, we're done
if [[ -d "$STANDARD_PATH" ]]; then
    echo -e "${GREEN}✅ Standard workspace path exists: $STANDARD_PATH${NC}"
    exit 0
fi

# Find any shellinator-* directories
workspace_dir=$(find /workspaces -maxdepth 1 -mindepth 1 -type d -name "shellinator-*" 2>/dev/null | head -1)

if [[ -n "$workspace_dir" ]]; then
    # Create symlink from found directory to standard path
    ln -sf "$workspace_dir" "$STANDARD_PATH"
    echo -e "${GREEN}✅ Workspace linked: $workspace_dir → $STANDARD_PATH${NC}"
else
    # No shellinator directory found - show error
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}                    ⚠️  WORKSPACE SETUP ERROR ⚠️${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Unable to find a shellinator workspace directory!${NC}"
    echo ""
    echo -e "Expected to find one of:"
    echo -e "  • ${BLUE}/workspaces/shellinator${NC}"
    echo -e "  • ${BLUE}/workspaces/shellinator-*${NC}"
    echo ""
    echo -e "Current directories in /workspaces:"
    if [[ -d "/workspaces" ]]; then
        ls -la /workspaces/ 2>/dev/null | grep "^d" | awk '{print "  • "$9}' | tail -n +3
    else
        echo -e "  ${RED}/workspaces directory doesn't exist!${NC}"
    fi
    echo ""
    echo -e "${YELLOW}This will cause issues with:${NC}"
    echo -e "  ❌ Git branch detection (prompt will show 'local')"
    echo -e "  ❌ Feature update checking"
    echo -e "  ❌ Babaji-config tools"
    echo ""
    echo -e "${GREEN}━━━ How to Fix This ━━━${NC}"
    echo ""
    echo -e "${BLUE}Option 1: Restart with correct naming${NC}"
    echo -e "  Exit and run:"
    echo -e "  ${GREEN}devpod up https://github.com/nikunh/shellinator.git@branch --id shellinator${NC}"
    echo ""
    echo -e "${BLUE}Option 2: Create a manual symlink${NC}"
    echo -e "  Run: ${GREEN}sudo ln -sf /workspaces/YOUR_DIR /workspaces/shellinator${NC}"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Continuing without proper workspace setup - features may not work!${NC}"
fi
EOF

chmod +x /usr/local/bin/setup-workspace-link
echo "✅ Workspace symlink script created"

log_debug "=== 002-USER-SETUP INSTALL COMPLETED ==="

# Complete end-to-end automation test with all fixes
