#!/bin/sh
set -e

# Set DEBIAN_FRONTEND to noninteractive to prevent prompts
export DEBIAN_FRONTEND=noninteractive

USERNAME=${USERNAME:-"babaji"}
PASSWORD=${PASSWORD:-"babaji"}

echo "Setting up user ${USERNAME}..."

# Only create the user if it doesn't already exist
if id "$USERNAME" >/dev/null 2>&1; then
  echo "User $USERNAME already exists, skipping creation."
else
  # Create the user with home directory and zsh shell
  useradd -m -s /bin/zsh "$USERNAME"

  # Set the password for the new user
  echo "$USERNAME:$PASSWORD" | chpasswd

  echo "User $USERNAME created."
fi

# Ensure user has zsh as default shell (force change even if user already existed)
echo "Setting default shell to zsh for user $USERNAME..."
chsh -s /usr/bin/zsh "$USERNAME" || chsh -s /bin/zsh "$USERNAME"
echo "Default shell set to zsh for user $USERNAME"

# Add user to the sudo group and ensure they can use it without a password
usermod -aG sudo "$USERNAME"
mkdir -p /etc/sudoers.d
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 0440 "/etc/sudoers.d/$USERNAME"

# Set password to match username for easy SSH access
echo "$USERNAME:$USERNAME" | chpasswd
echo "Password set to '$USERNAME' for user $USERNAME"

echo "User $USERNAME setup complete."
