#!/bin/sh
set -e

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
#!/bin/bash
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
# Final test of complete automated versioning system
