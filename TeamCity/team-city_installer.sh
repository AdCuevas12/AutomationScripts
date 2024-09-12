#!/bin/bash

# Color definitions for output
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'

# Variables
filename=""
username=$(whoami)
current_option=0
options=("CentOS" "Ubuntu" "Exit")
distro=""

# Function to print the menu
print_menu() {
    clear
    echo -e "${BYellow}Please Select your current Linux Distro:${NC}"
    for i in "${!options[@]}"; do
        if [ $i -eq $current_option ]; then
            echo -e "* \033[1;32m${options[$i]}\033[0m"  # Highlight the selected option
        else
            echo "  ${options[$i]}"
        fi
    done
}

# Function to capture arrow key inputs
navigate_menu() {
    while true; do
        print_menu
        read -rsn1 input
        if [[ $input == $'\x1b' ]]; then
            read -rsn2 input
            case $input in
                '[A')  # Up arrow key
                    ((current_option--))
                    if [ $current_option -lt 0 ]; then
                        current_option=$((${#options[@]} - 1))
                    fi
                    ;;
                '[B')  # Down arrow key
                    ((current_option++))
                    if [ $current_option -ge ${#options[@]} ]; then
                        current_option=0
                    fi
                    ;;
            esac
        elif [[ $input == "" ]]; then
            break
        fi
    done
}

# Install dependencies for CentOS
install_centos_dependencies() {
    echo -e "${BGreen}Installing Java and dependencies on CentOS...${NC}"
    sudo yum install -y java-17-openjdk wget
}

# Install dependencies for Ubuntu
install_ubuntu_dependencies() {
    echo -e "${BGreen}Installing Java and dependencies on Ubuntu...${NC}"
    sudo apt-get update
    sudo apt install -y openjdk-17-jdk wget
}

# Download and install TeamCity
install_teamcity() {
    echo -e "${BGreen}Downloading TeamCity...${NC}"
    wget https://download.jetbrains.com/teamcity/TeamCity-2023.05.1.tar.gz
    echo -e "${BGreen}Extracting TeamCity files...${NC}"
    tar -xzvf TeamCity-2023.05.1.tar.gz -C /opt/
    mv /opt/TeamCity /opt/teamcity

    echo -e "${BGreen}Setting up systemd service...${NC}"
    cat <<EOF | sudo tee /etc/systemd/system/teamcity.service
[Unit]
Description=TeamCity Build Agent
After=network.target

[Service]
Type=simple
ExecStart=/opt/teamcity/bin/runAll.sh start
ExecStop=/opt/teamcity/bin/runAll.sh stop
User=root
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${BGreen}Starting TeamCity...${NC}"
    sudo systemctl daemon-reload
    sudo systemctl start teamcity
    sudo systemctl enable teamcity

    # Check if the service is active
    status=$(sudo systemctl is-active teamcity)
    if [ "$status" == "active" ]; then
        echo -e "${BGreen}[+] SUCCESS: TeamCity service is active.${NC}"
        echo -e "${BYellow}You can access TeamCity at http://localhost:8111${NC}"
    else
        echo -e "${BRed}[!] FAILED: TeamCity service is not running.${NC}"
    fi
}

# Main function
main() {
    current_option=0
    navigate_menu
    selected_option="${options[$current_option]}"

    if [ "$selected_option" == "CentOS" ]; then
        install_centos_dependencies
        install_teamcity
    elif [ "$selected_option" == "Ubuntu" ]; then
        install_ubuntu_dependencies
        install_teamcity
    elif [ "$selected_option" == "Exit" ]; then
        exit 0
    else
        exit 1
    fi
}

main
