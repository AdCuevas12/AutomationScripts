#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
filename=""
username=$(whoami)

# Function to execute commands with sudo and pass the password
run_as_sudo() {
    echo "$user_password" | sudo -S "$@"
}

downloader() {
    # Prompt user for the version
    read -p "Enter the version of Node Exporter you want to download (e.g., 1.3.1): " userinput
    filename="node_exporter-${userinput}"
    rm -rf node_exporter-${userinput}.linux-amd64.tar.gz
    rm -rf ${filename}

    # Construct the URL
    url="https://github.com/prometheus/node_exporter/releases/download/v${userinput}/node_exporter-${userinput}.linux-amd64.tar.gz"
    
    # Download the file
    wget "$url"
    # Check if the download was successful
    if [[ $? -eq 0 ]]; then
        echo -e "${BGreen}Download completed successfully: node_exporter-${userinput}.linux-amd64.tar.gz${NC}"
        # Extract the file
        tar -axf "node_exporter-${userinput}.linux-amd64.tar.gz"
        mv "node_exporter-${userinput}.linux-amd64" "${filename}"
        
        # Check if the extraction was successful
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Extraction completed successfully into directory: ${filename}${NC}"
        else
            echo -e "${BRed}Failed to extract the file. Please check the downloaded file and try again.${NC}"
        fi
    else
        echo -e "${BRed}Failed to download Node Exporter version ${userinput}. Please check the version and try again.${NC}"
    fi
}

regular_user() {
    read -sp "Enter $username password: " user_password
    echo

    # Verify the password
    run_as_sudo -v -k >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        # User provided correct password, proceed with commands
        run_as_sudo useradd --no-create-home --shell /bin/false node_exporter
        echo -e "${GREEN}Node Exporter user created.${NC}"

        # Move files to the appropriate directory
        run_as_sudo cp $filename/node_exporter /usr/local/bin/
        run_as_sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

        # Create systemd service file for Node Exporter
        run_as_sudo bash -c 'cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple

ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'
        echo -e "${GREEN}Node Exporter systemd service file created.${NC}"

        # Reload systemd daemon
        run_as_sudo systemctl daemon-reload
        echo -e "${GREEN}Systemd daemon reloaded.${NC}"

        echo -e "${GREEN}Node Exporter Configured Successfully${NC}"
        echo "=========================="
        echo "What's next?"
        echo -e "Run: ${BYellow}sudo systemctl enable --now node_exporter${NC} to start the service"
        echo -e "Run: ${BYellow}sudo systemctl status node_exporter${NC} to see the current status of the service"
    else
        # Password verification failed
        echo -e "${BRed}Wrong password${NC}"
        exit 1
    fi
}

root_user() {
    echo -e "${BGreen}Already a root user${NC}"
    
    # User provided correct password, proceed with commands
    useradd --no-create-home --shell /bin/false node_exporter
    echo -e "${GREEN}Node Exporter user created.${NC}"

    # Move files to the appropriate directory
    cp ${filename}/node_exporter /usr/local/bin/
    chown node_exporter:node_exporter /usr/local/bin/node_exporter

    # Create systemd service file for Node Exporter
    bash -c 'cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple

ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'
    echo -e "${GREEN}Node Exporter systemd service file created.${NC}"

    # Reload systemd daemon
    systemctl daemon-reload
    echo -e "${GREEN}Systemd daemon reloaded.${NC}"

    echo -e "${GREEN}Node Exporter Configured Successfully${NC}"
    echo "=========================="
    echo "What's next?"
    echo -e "Run: ${BYellow}systemctl enable --now node_exporter${NC} to start the service"
    echo -e "Run: ${BYellow}systemctl status node_exporter${NC} to see the current status of the service"
}

main() {
    clear
    downloader
    if [ $username = "root" ]; then
        root_user
    else
        regular_user
    fi
}

main