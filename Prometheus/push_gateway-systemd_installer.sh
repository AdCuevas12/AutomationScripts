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

# Downloader for Pushgateway
pushgateway_downloader() {
    # Prompt user for the version of Pushgateway
    read -p "Enter the version of Pushgateway you want to download (e.g., 1.4.0): " userinput
    filename="pushgateway-${userinput}"
    rm -rf pushgateway-${userinput}.linux-amd64.tar.gz
    rm -rf ${filename}

    # Construct the URL for Pushgateway
    url="https://github.com/prometheus/pushgateway/releases/download/v${userinput}/pushgateway-${userinput}.linux-amd64.tar.gz"
    
    # Download the file
    wget "$url"
    if [[ $? -eq 0 ]]; then
        echo -e "${BGreen}Download completed successfully: pushgateway-${userinput}.linux-amd64.tar.gz${NC}"
        # Extract the file
        tar -axf "pushgateway-${userinput}.linux-amd64.tar.gz"
        mv "pushgateway-${userinput}.linux-amd64" "${filename}"
        
        # Check if the extraction was successful
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Extraction completed successfully into directory: ${filename}${NC}"
        else
            echo -e "${BRed}Failed to extract the file. Please check the downloaded file and try again.${NC}"
        fi
    else
        echo -e "${BRed}Failed to download Pushgateway version ${userinput}. Please check the version and try again.${NC}"
    fi
}

# Regular user commands
pushgateway_regular_user() {
    read -sp "Enter $username password: " user_password
    echo

    # Verify the password
    run_as_sudo -v -k >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        # User provided correct password, proceed with commands
        run_as_sudo useradd --no-create-home --shell /bin/false pushgateway
        echo -e "${GREEN}Pushgateway user created.${NC}"

        # Move files to the appropriate directory
        run_as_sudo cp ${filename}/pushgateway /usr/local/bin/
        run_as_sudo chown pushgateway:pushgateway /usr/local/bin/pushgateway

        # Create systemd service file for Pushgateway
        run_as_sudo bash -c 'cat <<EOF > /etc/systemd/system/pushgateway.service
[Unit]
Description=Prometheus Pushgateway
Wants=network-online.target
After=network-online.target

[Service]
User=pushgateway
Group=pushgateway
Type=simple

ExecStart=/usr/local/bin/pushgateway

[Install]
WantedBy=multi-user.target
EOF'
        echo -e "${GREEN}Pushgateway systemd service file created.${NC}"

        # Reload systemd daemon
        run_as_sudo systemctl daemon-reload
        echo -e "${GREEN}Systemd daemon reloaded.${NC}"

        # Enable and start Pushgateway service
        run_as_sudo systemctl enable --now pushgateway

        # Check service status
        status=$(run_as_sudo systemctl is-active pushgateway)
        if [ "$status" == "active" ]; then
            echo -e "${BGreen}[+] SUCCESS: Pushgateway service is active.${NC}"
        else
            echo -e "${BRed}[!] FAILED: Pushgateway service is not running.${NC}"
        fi
    else
        # Password verification failed
        echo -e "${BRed}Wrong password${NC}"
        exit 1
    fi
}

# Root user commands
pushgateway_root_user() {
    echo -e "${BGreen}Already a root user${NC}"
    
    # User provided correct password, proceed with commands
    useradd --no-create-home --shell /bin/false pushgateway
    echo -e "${GREEN}Pushgateway user created.${NC}"

    # Move files to the appropriate directory
    cp ${filename}/pushgateway /usr/local/bin/
    chown pushgateway:pushgateway /usr/local/bin/pushgateway

    # Create systemd service file for Pushgateway
    bash -c 'cat <<EOF > /etc/systemd/system/pushgateway.service
[Unit]
Description=Prometheus Pushgateway
Wants=network-online.target
After=network-online.target

[Service]
User=pushgateway
Group=pushgateway
Type=simple

ExecStart=/usr/local/bin/pushgateway

[Install]
WantedBy=multi-user.target
EOF'
    echo -e "${GREEN}Pushgateway systemd service file created.${NC}"

    # Reload systemd daemon
    systemctl daemon-reload
    echo -e "${GREEN}Systemd daemon reloaded.${NC}"

    # Enable and start Pushgateway service
    systemctl enable --now pushgateway

    # Check service status
    status=$(systemctl is-active pushgateway)
    if [ "$status" == "active" ]; then
        echo -e "${BGreen}[+] SUCCESS: Pushgateway service is active.${NC}"
    else
        echo -e "${BRed}[!] FAILED: Pushgateway service is not running.${NC}"
    fi
}

main() {
    clear
    pushgateway_downloader
    if [ $username = "root" ]; then
        pushgateway_root_user
    else
        pushgateway_regular_user
    fi
}

main