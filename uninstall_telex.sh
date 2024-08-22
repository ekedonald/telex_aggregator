#!/bin/bash

USER_NAME="telex"
CONFIG_DIR="/etc/$USER_NAME"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
DB_DIR="/var/lib/telex"
SERVICE_FILE="/etc/systemd/system/telex.service"
BINARY_FILE="/usr/local/bin/telex_aggregator"

# Stop and disable the telex service
echo "Stopping and disabling the telex service..."
sudo systemctl stop telex
sudo systemctl disable telex

# Remove the systemd service file
if [ -f "$SERVICE_FILE" ]; then
    echo "Removing systemd service file..."
    sudo rm -f "$SERVICE_FILE"
else
    echo "Systemd service file not found. Skipping removal."
fi

# Reload systemd daemon to apply changes
sudo systemctl daemon-reload

# Remove the telex_aggregator binary
if [ -f "$BINARY_FILE" ]; then
    echo "Removing telex_aggregator binary..."
    sudo rm -f "$BINARY_FILE"
else
    echo "Telex_aggregator binary not found. Skipping removal."
fi

# Remove the configuration directory and file
if [ -d "$CONFIG_DIR" ]; then
    echo "Removing configuration directory..."
    sudo rm -rf "$CONFIG_DIR"
else
    echo "Configuration directory not found. Skipping removal."
fi

# Remove the database directory
if [ -d "$DB_DIR" ]; then
    echo "Removing database directory..."
    sudo rm -rf "$DB_DIR"
else
    echo "Database directory not found. Skipping removal."
fi

# Remove the user and associated group
echo "Removing user and group..."
sudo userdel -r "$USER_NAME"
sudo groupdel "$USER_NAME" 2>/dev/null

# Verify removal
echo "Verification of removal:"
if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME was not successfully removed."
else
    echo "User $USER_NAME has been successfully removed."
fi

if [ -f "$SERVICE_FILE" ] || [ -f "$BINARY_FILE" ] || [ -d "$CONFIG_DIR" ] || [ -d "$DB_DIR" ]; then
    echo "Some components were not successfully removed."
else
    echo "All components have been successfully removed."
fi

echo "Telex service and all associated components have been uninstalled."
