#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
UGreen='\033[4;32m'
BYellow='\033[1;33m'
BGreen='\033[1;32m'

username=$(whoami)

# Function to execute commands with sudo and pass the password
run_as_sudo() {
    echo "$user_password" | sudo -S "$@"
}

# Check if the necessary files exist

if [ $username = "root" ]; then
    echo -e "${BGreen}Already a root user${NC}"

    #Run TLS Authentication
    openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout node_exporter.key -out node_exporter.crt -subj "/C=PH/ST=Manila/L=Mandaluyong/O=MyOrg/CN=localhost" -addext "subjectAltName = DNS:localhost"
    bash -c 'cat <<EOF > config.yaml
tls_server_config:
  cert_file: node_exporter.crt
  key_file: node_exporter.key
EOF'
    mkdir /etc/node_exporter
    mv node_exporter.* /etc/node_exporter
    cp config.yaml /etc/node_exporter
    chown -R node_exporter:node_exporter /etc/node_exporter
    sed -i 's|ExecStart=/usr/local/bin/node_exporter|ExecStart=/usr/local/bin/node_exporter --web.config=/etc/node_exporter/config.yml|g' /etc/systemd/system/node_exporter.service
    # Reload systemd daemon
    systemctl daemon-reload
    systemctl restart node_exporter
    echo -e "${GREEN}TLS Configured Successfully${NC}"
    echo "=========================="
    echo "What's next?"
    echo -e "Run: ${BYellow}systemctl enable --now node_exporter${NC} to start the service"
    echo -e "Run: ${BYellow}systemctl status node_exporter${NC} to see the current status of the service"

else
    read -sp "Enter $username password: " user_password
    echo

    # Verify the password by running a simple sudo command
    if echo "$user_password" | sudo -S true >/dev/null 2>&1; then
        #Run TLS Authentication
        run_as_sudo openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout node_exporter.key -out node_exporter.crt -subj "/C=PH/ST=Manila/L=Mandaluyong/O=MyOrg/CN=localhost" -addext "subjectAltName = DNS:localhost"
        bash -c 'cat <<EOF > config.yaml
tls_server_config:
  cert_file: node_exporter.crt
  key_file: node_exporter.key
EOF'
        run_as_sudo mkdir /etc/node_exporter
        run_as_sudo mv node_exporter.* /etc/node_exporter
        run_as_sudo cp config.yaml /etc/node_exporter
        run_as_sudo chown -R node_exporter:node_exporter /etc/node_exporter
        run_as_sudo sed -i 's|ExecStart=/usr/local/bin/node_exporter|ExecStart=/usr/local/bin/node_exporter --web.config=/etc/node_exporter/config.yml|g' /etc/systemd/system/node_exporter.service
        # Reload systemd daemon
        run_as_sudo systemctl daemon-reload
        run_as_sudo systemctl restart node_exporter
        echo -e "${GREEN}TLS Configured Successfully${NC}"
        echo "=========================="
        echo "What's next?"
        echo -e "Run: ${BYellow}systemctl enable --now node_exporter${NC} to start the service"
        echo -e "Run: ${BYellow}systemctl status node_exporter${NC} to see the current status of the service"
        else
            # Password verification failed
            echo -e "${BRed}Wrong password${NC}"
            exit 1
        fi
fi