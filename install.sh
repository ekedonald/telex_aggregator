#!/bin/bash

USER_NAME="telex"
SHELL="/usr/sbin/nologin"
GROUP="sudo"
CONFIG_DIR="/etc/$USER_NAME"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
TEMP_CONFIG_FILE="/tmp/config.yaml"
DB_DIR="/var/lib/telex"

# Create user and directories, set permissions
sudo useradd -r -s "$SHELL" "$USER_NAME"
sudo usermod -aG "$GROUP" "$USER_NAME"
sudo usermod -aG adm "$USER_NAME"
sudo usermod -aG $(whoami) "$USER_NAME"
sudo mkdir -p "$CONFIG_DIR"
sudo mkdir -p "$DB_DIR"
touch $TEMP_CONFIG_FILE
sudo chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR"
sudo chown -R "$USER_NAME:$USER_NAME" "$DB_DIR"
sudo chmod 777 -R "$CONFIG_DIR"

# Prompt user for input
read -p "Enter Webhook URLs (separate multiple URLs with space): " webhook_urls
read -p "Enter Application name: " job_name
read -p "Enter Log Directory Paths (separate multiple paths with space): " log_paths

# Create and populate temporary config.yaml file
cat > "$TEMP_CONFIG_FILE" << EOL
clients:
  - webhook_urls:
EOL

# Add each webhook URL on a new line
for url in $webhook_urls; do
    echo "      - $url" >> "$TEMP_CONFIG_FILE"
done

cat >> "$TEMP_CONFIG_FILE" << EOL

targets:
  - application: $job_name
    filter:
    paths: 
EOL

# Add each log path on a new line with proper indentation
for path in $log_paths; do
    echo "      - $path" >> "$TEMP_CONFIG_FILE"
done

cat >> "$TEMP_CONFIG_FILE" << EOL

interval: 30s
EOL

# Move the temporary config file to the final location
sudo mv "$TEMP_CONFIG_FILE" "$CONFIG_DIR"
sudo chmod 644 "$CONFIG_FILE"
sudo chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_FILE"

# Download and set up the telex_aggregator binary
echo "Now downloading the telex_aggregator binary..."
sudo wget -q --show-progress -P /usr/local/bin https://github.com/ekedonald/telex_aggregator/releases/download/v1.0.0/telex_aggregator
sudo chmod +x /usr/local/bin/telex_aggregator
sudo chown -R $USER_NAME:$USER_NAME /usr/local/bin/telex_aggregator

# Create the systemd service file
cat << EOF | sudo tee /etc/systemd/system/telex.service > /dev/null
[Unit]
Description=Telex Log Aggregator Service
After=network.target

[Service]
ExecStart=/usr/local/bin/telex_aggregator 
WorkingDirectory=/usr/local/bin
User=$USER_NAME
Group=$USER_NAME
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start and enable the telex service
sudo systemctl daemon-reload
sudo systemctl start telex
sudo systemctl enable telex
sudo systemctl status telex

echo "Telex service has been created and started."