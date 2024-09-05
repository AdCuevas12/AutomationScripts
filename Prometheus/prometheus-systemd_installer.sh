#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
UGreen='\033[4;32m'
BYellow='\033[1;33m'
BGreen='\033[1;32m'
filename=""
username=$(whoami)

# Function to execute commands with sudo and pass the password
run_as_sudo() {
    echo "$user_password" | sudo -S "$@"
}

regular_user() {
    read -sp "Enter $username password: " user_password
    # Verify the password
    run_as_sudo -v -k >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        # User provided correct password, proceed with commands
        run_as_sudo useradd --no-create-home --shell /bin/false prometheus
        echo " "
        echo -e "${GREEN}Prometheus user created.${NC}"

        # Create Initial Directories
        run_as_sudo mkdir -p /etc/prometheus
        run_as_sudo mkdir -p /var/lib/prometheus
        echo -e "${GREEN}Directories /etc/prometheus and /var/lib/prometheus created.${NC}"

        run_as_sudo chown prometheus:prometheus /etc/prometheus
        run_as_sudo chown prometheus:prometheus /var/lib/prometheus
        echo -e "${GREEN}Ownership set for /etc/prometheus and /var/lib/prometheus.${NC}"

        # Move files to specific Directory
        run_as_sudo cp $filename/prometheus /usr/local/bin/
        run_as_sudo cp $filename/promtool /usr/local/bin/
        echo -e "${GREEN}Prometheus and promtool copied to /usr/local/bin/.${NC}"

        run_as_sudo chown prometheus:prometheus /usr/local/bin/prometheus
        run_as_sudo chown prometheus:prometheus /usr/local/bin/promtool
        echo -e "${GREEN}Ownership set for /usr/local/bin/prometheus and promtool.${NC}"

        # Move some files in /etc
        run_as_sudo cp -r $filename/consoles /etc/prometheus/
        run_as_sudo cp -r $filename/console_libraries /etc/prometheus/
        run_as_sudo cp $filename/prometheus.yml /etc/prometheus/
        echo -e "${GREEN}Consoles, console_libraries, and prometheus.yml copied to /etc/prometheus/.${NC}"

        run_as_sudo chown -R prometheus:prometheus /etc/prometheus/consoles
        run_as_sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
        run_as_sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml
        echo -e "${GREEN}Ownership set for /etc/prometheus files.${NC}"

        # Create systemd service file for Prometheus
        run_as_sudo bash -c 'cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple

ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF'
        echo -e "${GREEN}Prometheus systemd service file created.${NC}"

        # Reload systemd daemon
        run_as_sudo systemctl daemon-reload
        echo -e "${GREEN}Systemd daemon reloaded.${NC}"

        echo -e "${GREEN}Prometheus Configured Successfully${NC}"
        echo "=========================="
        echo "What's next?"
        echo -e "Run: ${BYellow}sudo systemctl enable --now prometheus${NC} to start the service"
        echo -e "Run: ${BYellow}sudo systemctl status prometheus${NC} to see the current status of the service"
    else
        # Password verification failed
        echo -e "${BRed}Wrong password${NC}"
        exit 1
    fi
}

root_user(){
    echo -e "${BGreen}Already a root user${NC}"
    # User provided correct password, proceed with commands
    useradd --no-create-home --shell /bin/false prometheus
    echo -e "${GREEN}Prometheus user created.${NC}"

    # Create Initial Directories
    mkdir -p /etc/prometheus
    mkdir -p /var/lib/prometheus
    echo -e "${GREEN}Directories /etc/prometheus and /var/lib/prometheus created.${NC}"

    chown prometheus:prometheus /etc/prometheus
    chown prometheus:prometheus /var/lib/prometheus
    echo -e "${GREEN}Ownership set for /etc/prometheus and /var/lib/prometheus.${NC}"

    # Move files to specific Directory
    cp $filename/prometheus /usr/local/bin/
    cp $filename/promtool /usr/local/bin/
    echo -e "${GREEN}Prometheus and promtool copied to /usr/local/bin/.${NC}"

    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool
    echo -e "${GREEN}Ownership set for /usr/local/bin/prometheus and promtool.${NC}"

    # Move some files in /etc
    cp -r $filename/consoles /etc/prometheus/
    cp -r $filename/console_libraries /etc/prometheus/
    cp $filename/prometheus.yml /etc/prometheus/
    echo -e "${GREEN}Consoles, console_libraries, and prometheus.yml copied to /etc/prometheus/.${NC}"

    chown -R prometheus:prometheus /etc/prometheus/consoles
    chown -R prometheus:prometheus /etc/prometheus/console_libraries
    chown -R prometheus:prometheus /etc/prometheus/prometheus.yml
    echo -e "${GREEN}Ownership set for /etc/prometheus files.${NC}"

    # Create systemd service file for Prometheus
    bash -c 'cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple

ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF'
    echo -e "${GREEN}Prometheus systemd service file created.${NC}"

    # Reload systemd daemon
    systemctl daemon-reload
    echo -e "${GREEN}Systemd daemon reloaded.${NC}"

    echo -e "${GREEN}Prometheus Configured Successfully${NC}"
    echo "=========================="
    echo "What's next?"
    echo -e "Run: ${BYellow}systemctl enable --now prometheus${NC} to start the service"
    echo -e "Run: ${BYellow}systemctl status prometheus${NC} to see the current status of the service"
}

downloader() {
    # Prompt user for the version
    read -p "Enter the version of Prometheus you want to download (e.g., 2.4.0): " userinput
    filename="prometheus-${userinput}"
    rm -rf prometheus-${userinput}.linux-amd64.tar.gz
    rm -rf prometheus-${userinput}
    # Construct the URL
    url="https://github.com/prometheus/prometheus/releases/download/v${userinput}/prometheus-${userinput}.linux-amd64.tar.gz"
    
    # Download the file
    wget "$url"    
    # Check if the download was successful
    if [[ $? -eq 0 ]]; then
        echo -e "${BGreen}Download completed successfully: prometheus-${userinput}.linux-amd64.tar.gz${NC}"
        # Extract the file
        tar -axf "prometheus-${userinput}.linux-amd64.tar.gz"
        mv "prometheus-${userinput}.linux-amd64" "prometheus-${userinput}"
        
        # Check if the extraction was successful
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Extraction completed successfully into directory: prometheus-${userinput}${NC}"
        else
            echo -e "${BRed}Failed to extract the file. Please check the downloaded file and try again.${NC}"
        fi
    else
        echo -e "${BRed}Failed to download prometheus version ${userinput}. Please check the version and try again.${NC}"
    fi
}

main () {
    clear
    downloader
    if [ $username = "root" ]; then
        root_user
    else
        regular_user
    fi
}

main