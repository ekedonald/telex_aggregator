#!/bin/bash

USERNAME="telex"
SHELL="/usr/sbin/nologin"
GROUP="sudo"
CONFIG_DIR="/etc/$USERNAME"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
DB_DIR="/var/lib/telex"

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

useradd -r -s "$SHELL" "$USERNAME"
usermod -aG "$GROUP" "$USERNAME"
usermod -aG adm "$USERNAME"
mkdir -p "$CONFIG_DIR"
mkdir -p "$DB_DIR"
touch $CONFIG_FILE
chown -R "$USERNAME:$USERNAME" "$CONFIG_DIR"
chown -R "$USERNAME:$USERNAME" "$DB_DIR"
chmod 777 -R "$CONFIG_DIR"
chmod 644 "$CONFIG_FILE"

# Prompt user for input
read -p "Enter Webhook URLs (separate multiple URLs with space): " webhook_urls
read -p "Enter Application name: " job_name
read -p "Enter Log Directory Paths (separate multiple paths with space): " log_paths

# Create and populate config.yaml file
cat > "$CONFIG_FILE" << EOL
clients:
  - webhook_urls:
EOL

# Add each webhook URL on a new line
for url in $webhook_urls; do
    echo "      - $url" >> "$CONFIG_FILE"
done

cat >> "$CONFIG_FILE" << EOL

targets:
  - application: $job_name
    paths: 
EOL

# Add each log path on a new line with proper indentation
for path in $log_paths; do
    echo "      - $path" >> "$CONFIG_FILE"
done

cat >> "$CONFIG_FILE" << EOL

interval: 30s
EOL

wget -P /usr/local/bin https://github.com/vicradon/telex_aggregator/releases/download/0.0.1/telex_aggregator
chmod +x /usr/local/bin/telex_aggregator
chown -R $USERNAME:$USERNAME /usr/local/bin/telex_aggregator

# Create the systemd service file
cat << EOF | sudo tee /etc/systemd/system/telex.service
[Unit]
Description=Telex Log Aggregator Service
After=network.target

[Service]
ExecStart=/usr/local/bin/telex_aggregator 
WorkingDirectory=/usr/local/bin
User=$USERNAME
Group=$USERNAME
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start telex
sudo systemctl enable telex
sudo systemctl status telex

echo "Telex service has been created and started."