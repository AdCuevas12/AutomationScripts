#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
current_option=0
options1=("Universal (Recommended)" "Centos" "Ubuntu" "Exit")
distro=""

# Function to print the menu
print_menu() {
    local array_name=$1
    local menu_array=("${!array_name}")
    clear
    echo -e "If you're not sure, just exit and run: ${BYellow}cat /etc/*release*${NC} and try again."
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

script_installer() {
		export PATH=$PATH:/usr/local/bin
    sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
		chmod 777 get_helm.sh
		./get_helm.sh
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Helm successfully installed your machine.${NC}"
    else
        echo -e "${BRed}Failed to install Helm on your machine.${NC}"
        exit 1
    fi
}

centos_installer() {
    sudo dnf install helm -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Helm successfully installed on CentOS.${NC}"
    else
        echo -e "${BRed}Failed to install Helm on CentOS.${NC}"
        exit 1
    fi
}

ubuntu_installer() {
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Helm GPG key added successfully.${NC}"
    else
        echo -e "${BRed}Failed to add Helm GPG key.${NC}"
        exit 1
    fi

    sudo apt-get install apt-transport-https --yes
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}apt-transport-https installed successfully.${NC}"
    else
        echo -e "${BRed}Failed to install apt-transport-https.${NC}"
        exit 1
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Helm repository added successfully.${NC}"
    else
        echo -e "${BRed}Failed to add Helm repository.${NC}"
        exit 1
    fi

    sudo apt-get update
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}System updated successfully.${NC}"
    else
        echo -e "${BRed}Failed to update the system.${NC}"
        exit 1
    fi

    sudo apt-get install helm -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Helm successfully installed on Ubuntu.${NC}"
    else
        echo -e "${BRed}Failed to install Helm on Ubuntu.${NC}"
        exit 1
    fi
}

kube-p8s-stack_installer() {
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Prometheus Helm repository added successfully.${NC}"
    else
        echo -e "${BRed}Failed to add Prometheus Helm repository.${NC}"
        exit 1
    fi

    helm repo update
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Helm repository updated successfully.${NC}"
    else
        echo -e "${BRed}Failed to update Helm repository.${NC}"
        exit 1
    fi

    helm install prometheus prometheus-community/kube-prometheus-stack --set prometheus-node-exporter.hostRootFsMount.enabled=false
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}kube-prometheus-stack successfully installed.${NC}"
    else
        echo -e "${BRed}Failed to install kube-prometheus-stack.${NC}"
        exit 1
    fi
}

current_option=0
navigate_menu 'options1'
selected_option="${options1[$current_option]}"
if [ "$selected_option" = "Universal (Recommended)" ]; then
    script_installer
elif [ "$selected_option" = "Centos" ]; then
    centos_installer
elif [ "$selected_option" = "Ubuntu" ]; then
    ubuntu_installer
else
    exit 1
fi
