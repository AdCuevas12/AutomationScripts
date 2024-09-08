#!/bin/bash

# Color definitions for output
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
filename=""
username=$(whoami)
current_option=0
options1=("Centos" "Ubuntu" "Exit")
distro=""


# Function to print the menu
print_menu() {
    local array_name=$1
    local menu_array=("${!array_name}")
    clear
    echo -e "If you're not sure, just exit the choose exit and run: ${BYellow}cat /etc/*release*${NC} and try again."
    echo -e "${BYellow}Please Select your current Linux Distro:${NC}"
    for i in "${!menu_array[@]}"; do
        if [ $i -eq $current_option ]; then
            echo -e "* \033[1;32m${menu_array[$i]}\033[0m"  # Highlight the selected option
        else
            echo "  ${menu_array[$i]}"
        fi
    done
}

# Function to capture arrow key inputs
navigate_menu() {
    local array_name=$1
    local menu_array=("${!array_name}")
    local array_length=${#menu_array[@]}
    while true; do
        # Pass the array reference to print_menu
        print_menu "$array_name[@]"

        # Read one character at a time
        read -rsn1 input
        if [[ $input == $'\x1b' ]]; then
            read -rsn2 input

            case $input in
                '[A')  # Up arrow key
                    ((current_option--))
                    eval "array_length=\${#${array_name}[@]}"
                    if [ $current_option -lt 0 ]; then
                        current_option=$((array_length - 1))
                    fi
                    ;;
                '[B')  # Down arrow key
                    ((current_option++))
                    eval "array_length=\${#${array_name}[@]}"
                    if [ $current_option -ge $array_length ]; then
                        current_option=0
                    fi
                    ;;
            esac
        elif [[ $input == "" ]]; then
            break
        fi
    done
}

# Function to execute commands with sudo and pass the password
run_as_sudo() {
    echo "$user_password" | sudo -S "$@"
}

# Downloader for AlertManager
alertmanager_downloader() {
    # Prompt user for the version of AlertManager
    read -p "Enter the version of AlertManager you want to download (e.g., 0.23.0): " userinput
    filename="alertmanager-${userinput}"
    rm -rf alertmanager-${userinput}.linux-amd64.tar.gz
    rm -rf ${filename}

    # Construct the URL for AlertManager
    url="https://github.com/prometheus/alertmanager/releases/download/v${userinput}/alertmanager-${userinput}.linux-amd64.tar.gz"
    
    # Download the file
    wget "$url"
    if [[ $? -eq 0 ]]; then
        echo -e "${BGreen}Download completed successfully: alertmanager-${userinput}.linux-amd64.tar.gz${NC}"
        # Extract the file
        tar -axf "alertmanager-${userinput}.linux-amd64.tar.gz"
        mv "alertmanager-${userinput}.linux-amd64" "${filename}"
        
        # Check if the extraction was successful
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Extraction completed successfully into directory: ${filename}${NC}"
        else
            echo -e "${BRed}Failed to extract the file. Please check the downloaded file and try again.${NC}"
        fi
    else
        echo -e "${BRed}Failed to download AlertManager version ${userinput}. Please check the version and try again.${NC}"
    fi
}

# Function to handle regular user commands
ubuntu_alertmanager_regular_user() {
    read -sp "Enter $username password: " user_password
    echo

    # Verify the password
    run_as_sudo -v -k >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        # Proceed with setup as a regular user
        run_as_sudo groupadd -f alertmanager
        run_as_sudo useradd -g alertmanager --no-create-home --shell /bin/false alertmanager
        run_as_sudo mkdir -p /etc/alertmanager/templates
        run_as_sudo mkdir -p /var/lib/alertmanager
        run_as_sudo chown alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

        # Move files
        run_as_sudo cp alertmanager-files/alertmanager /usr/bin/
        run_as_sudo cp alertmanager-files/amtool /usr/bin/
        run_as_sudo chown alertmanager:alertmanager /usr/bin/alertmanager
        run_as_sudo chown alertmanager:alertmanager /usr/bin/amtool

        # Copy and set up configuration file
        run_as_sudo cp alertmanager-files/alertmanager.yml /etc/alertmanager/alertmanager.yml
        run_as_sudo chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml
        
        # Create systemd service file
        run_as_sudo bash -c 'cat <<EOF > /usr/lib/systemd/system/alertmanager.service
[Unit]
Description=AlertManager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/bin/alertmanager \\
    --config.file /etc/alertmanager/alertmanager.yml \\
    --storage.path /var/lib/alertmanager/

[Install]
WantedBy=multi-user.target
EOF'
        run_as_sudo chmod 664 /usr/lib/systemd/system/alertmanager.service

        # Reload systemd and start the service
        run_as_sudo systemctl daemon-reload
        run_as_sudo systemctl start alertmanager
        run_as_sudo systemctl enable alertmanager
        
        # Check if the service is running
        status=$(run_as_sudo systemctl is-active alertmanager)
        if [ "$status" == "active" ]; then
            echo -e "${BGreen}[+] SUCCESS: AlertManager service is active.${NC}"
        else
            echo -e "${BRed}[!] FAILED: AlertManager service is not running.${NC}"
        fi
    else
        # Incorrect password handling
        echo -e "${BRed}Incorrect password${NC}"
        exit 1
    fi
}

# Function to handle root user commands
ubuntu_alertmanager_root_user() {
    echo -e "${BGreen}Root user detected. Proceeding with installation...${NC}"
    
    groupadd -f alertmanager
    useradd -g alertmanager --no-create-home --shell /bin/false alertmanager
    mkdir -p /etc/alertmanager/templates
    mkdir -p /var/lib/alertmanager
    chown alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

    # Move binaries
    cp alertmanager-files/alertmanager /usr/bin/
    cp alertmanager-files/amtool /usr/bin/
    chown alertmanager:alertmanager /usr/bin/alertmanager
    chown alertmanager:alertmanager /usr/bin/amtool

    # Set up config file
    cp alertmanager-files/alertmanager.yml /etc/alertmanager/alertmanager.yml
    chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml

    # Create systemd service
    bash -c 'cat <<EOF > /usr/lib/systemd/system/alertmanager.service
[Unit]
Description=AlertManager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/bin/alertmanager \\
    --config.file /etc/alertmanager/alertmanager.yml \\
    --storage.path /var/lib/alertmanager/

[Install]
WantedBy=multi-user.target
EOF'
    chmod 777 /usr/lib/systemd/system/alertmanager.service

    # Reload and start the service
    systemctl daemon-reload
    systemctl start alertmanager
    systemctl enable alertmanager

    # Check service status
    status=$(systemctl is-active alertmanager)
    if [ "$status" == "active" ]; then
        echo -e "${BGreen}[+] SUCCESS: AlertManager service is active.${NC}"
    else
        echo -e "${BRed}[!] FAILED: AlertManager service is not running.${NC}"
    fi
}


# Regular user commands
centos_alertmanager_regular_user() {
    read -sp "Enter $username password: " user_password
    echo

    # Verify the password
    run_as_sudo -v -k >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        # User provided correct password, proceed with commands
        run_as_sudo useradd --no-create-home --shell /bin/false alertmanager
        echo -e "${GREEN}AlertManager user created.${NC}"

        # Move files to the appropriate directory
        run_as_sudo mkdir /etc/alertmanager
        run_as_sudo mv ${filename}/alertmanager.yml /etc/alertmanager/
        run_as_sudo chown -R alertmanager:alertmanager /etc/alertmanager

        # Create directories for AlertManager data
        run_as_sudo mkdir /var/lib/alertmanager
        run_as_sudo chown -R alertmanager:alertmanager /var/lib/alertmanager

        # Move binaries to the appropriate location
        run_as_sudo cp ${filename}/alertmanager /usr/local/bin/
        run_as_sudo cp ${filename}/amtool /usr/local/bin/
        run_as_sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager
        run_as_sudo chown alertmanager:alertmanager /usr/local/bin/amtool

        # Create systemd service file for AlertManager
        run_as_sudo bash -c 'cat <<EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=AlertManager
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \\
    --config.file=/etc/alertmanager/alertmanager.yml \\
    --storage.path=/var/lib/alertmanager
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
        echo -e "${GREEN}AlertManager systemd service file created.${NC}"

        # Reload systemd daemon
        run_as_sudo systemctl daemon-reload
        echo -e "${GREEN}Systemd daemon reloaded.${NC}"

        # Enable and start AlertManager service
        run_as_sudo systemctl enable --now alertmanager

        # Check service status
        status=$(run_as_sudo systemctl is-active alertmanager)
        if [ "$status" == "active" ]; then
            echo -e "${BGreen}[+] SUCCESS: AlertManager service is active.${NC}"
        else
            echo -e "${BRed}[!] FAILED: AlertManager service is not running.${NC}"
        fi
    else
        # Password verification failed
        echo -e "${BRed}Wrong password${NC}"
        exit 1
    fi
}

# Root user commands
centos_alertmanager_root_user() {
    echo -e "${BGreen}Already a root user${NC}"
    
    # User provided correct password, proceed with commands
    useradd --no-create-home --shell /bin/false alertmanager
    echo -e "${GREEN}AlertManager user created.${NC}"

    # Move files to the appropriate directory
    mkdir /etc/alertmanager
    mv ${filename}/alertmanager.yml /etc/alertmanager/
    chown -R alertmanager:alertmanager /etc/alertmanager

    # Create directories for AlertManager data
    mkdir /var/lib/alertmanager
    chown -R alertmanager:alertmanager /var/lib/alertmanager

    # Move binaries to the appropriate location
    cp ${filename}/alertmanager /usr/local/bin/
    cp ${filename}/amtool /usr/local/bin/
    chown alertmanager:alertmanager /usr/local/bin/alertmanager
    chown alertmanager:alertmanager /usr/local/bin/amtool

    # Create systemd service file for AlertManager
    bash -c 'cat <<EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=AlertManager
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml \
    --storage.path=/var/lib/alertmanager
Restart=always

[Install]
WantedBy=multi-user.target
EOF'
    echo -e "${GREEN}AlertManager systemd service file created.${NC}"

    # Reload systemd daemon
    systemctl daemon-reload
    echo -e "${GREEN}Systemd daemon reloaded.${NC}"

    # Enable and start AlertManager service
    systemctl enable --now alertmanager

    # Check service status
    status=$(systemctl is-active alertmanager)
    if [ "$status" == "active" ]; then
        echo -e "${BGreen}[+] SUCCESS: AlertManager service is active.${NC}"
    else
        echo -e "${BRed}[!] FAILED: AlertManager service is not running.${NC}"
    fi
}



main() {
    current_option=0
    navigate_menu 'options1'
    selected_option="${options1[$current_option]}"
    if [ $selected_option = "Centos" ]; then
        alertmanager_downloader
        if [ $username = "root" ]; then
            centos_alertmanager_root_user
        else
            centos_alertmanager_regular_user
        fi
    elif [ $selected_option = "Ubuntu" ]; then
        alertmanager_downloader
        if [ $username = "root" ]; then
            ubuntu_alertmanager_root_user
        else
            ubuntu_alertmanager_regular_user
        fi
    elif [ $selected_option = "Exit" ]; then
        exit 1
    else
        exit 1
    fi
}

main