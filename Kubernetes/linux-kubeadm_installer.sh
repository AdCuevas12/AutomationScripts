#!/bin/bash

# Color definitions
GREEN='\033[0;32m'
NC='\033[0m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
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

centos_installer() {
    # Update the system
    echo -e "${BYellow}Updating the system...${NC}"
    sudo yum update -y
    echo -e "${BGreen}System updated.${NC}"

    # Disable SELinux
    echo -e "${BYellow}Disabling SELinux...${NC}"
    sudo setenforce 0
    sudo sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/sysconfig/selinux
    echo -e "${BGreen}SELinux disabled.${NC}"

    # Disable Swap
    echo -e "${BYellow}Disabling Swap...${NC}"
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab
    echo -e "${BGreen}Swap disabled.${NC}"

    # Enable the br_netfilter module
    echo -e "${BYellow}Enabling br_netfilter module...${NC}"
    sudo modprobe br_netfilter
    echo '1' | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables
    echo -e "${BGreen}br_netfilter module enabled.${NC}"

    # Create Kubernetes repo file
    echo -e "${BYellow}Creating Kubernetes repository file...${NC}"
    cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$K8sVersion/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$K8sVersion/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
    echo -e "${BGreen}Kubernetes repository file created.${NC}"

    # Install kubeadm, kubelet, kubectl
    echo -e "${BYellow}Installing kubeadm, kubelet, and kubectl...${NC}"
    sudo yum install -y kubeadm-$KubeAdmVersion kubelet-$KubeAdmVersion kubectl-$KubeAdmVersion --disableexcludes=kubernetes
    echo -e "${BGreen}kubeadm, kubelet, and kubectl installed.${NC}"

    # Enable and start kubelet service
    echo -e "${BYellow}Enabling and starting kubelet service...${NC}"
    sudo systemctl enable --now kubelet
    echo -e "${BGreen}kubelet service started.${NC}"

    # Configure sysctl for Kubernetes
    echo -e "${BYellow}Configuring sysctl for Kubernetes...${NC}"
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sudo sysctl --system
    echo -e "${BGreen}Sysctl configuration applied.${NC}"

    # Disable firewall
    echo -e "${BYellow}Disabling firewall...${NC}"
    sudo systemctl disable --now firewalld
    echo -e "${BGreen}Firewall disabled.${NC}"

    # Load necessary kernel modules
    echo -e "${BYellow}Loading necessary kernel modules...${NC}"
    sudo modprobe overlay
    sudo modprobe br_netfilter
    echo -e "${BGreen}Kernel modules loaded.${NC}"

    # Install and configure containerd
    echo -e "${BYellow}Installing and configuring containerd...${NC}"
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y containerd.io
    sudo rm -f /etc/containerd/config.toml
    sudo mkdir -p /etc/containerd
    cat <<EOF | sudo tee /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF
    sudo systemctl restart containerd
    sudo systemctl enable containerd
    sudo systemctl enable --now kubelet
    echo -e "${BGreen}Containerd installed and configured.${NC}"

    # Set kubelet to use containerd as the CRI
    echo -e "${BYellow}Configuring kubelet to use containerd...${NC}"
    sudo tee /etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
    echo -e "${BGreen}kubelet configured to use containerd.${NC}"

    # Conditional logic based on the argument provided
    if [[ "$MW" == "master" ]]; then
        # Initialize Kubernetes cluster (for master node)
        echo -e "${BYellow}Initializing Kubernetes cluster (master node)...${NC}"
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16

        # Configure kubectl for the regular user
        echo -e "${BYellow}Configuring kubectl for the regular user...${NC}"
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        # Install Flannel CNI plugin
        echo -e "${BYellow}Installing Flannel CNI plugin...${NC}"
        kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
        echo -e "${BGreen}Flannel CNI plugin installed.${NC}"
    else
        echo -e "${BYellow}This node is configured as a worker node. Skipping master node setup.${NC}"
    fi
    echo -e "${BGreen}Kubernetes installation completed successfully!${NC}"
}


ubuntu_installer() {
    # Disable swap & add kernel settings
    echo -e "${BYellow}Disabling swap and removing swap entries from /etc/fstab...${NC}"
    sudo swapoff -a
    sudo sed -i '/swap/d' /etc/fstab
    echo -e "${BGreen}Swap disabled and entries removed.${NC}"

    # Add kernel settings & Enable IP tables (CNI Prerequisites)
    echo -e "${BYellow}Adding kernel settings and enabling IP tables...${NC}"
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

    # Configure sysctl for Kubernetes
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sudo sysctl --system
    echo -e "${BGreen}Kernel settings added and sysctl configured.${NC}"

    # Install containerd runtime
    echo -e "${BYellow}Installing containerd runtime...${NC}"

    # To install containerd, first install its dependencies.
    apt-get update -y
    apt-get install ca-certificates curl gnupg lsb-release -y

    # Add Docker’s official GPG key:
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the repository:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install containerd
    apt-get update -y
    apt-get install containerd.io -y

    # Generate default configuration file for containerd
    echo -e "${BYellow}Generating default configuration file for containerd...${NC}"
    sudo rm -f /etc/containerd/config.toml
    sudo mkdir -p /etc/containerd
    cat <<EOF | sudo tee /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF

    # Restart and enable containerd service
    echo -e "${BYellow}Restarting and enabling containerd service...${NC}"
    systemctl restart containerd
    systemctl enable containerd
    echo -e "${BGreen}Containerd service restarted and enabled.${NC}"

    # Installing kubeadm, kubelet, and kubectl
    echo -e "${BYellow}Installing kubeadm, kubelet, and kubectl...${NC}"
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl

    # Download the Google Cloud public signing key:
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8sVersion/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    # Add the Kubernetes apt repository:
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8sVersion/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

    # Update apt package index, install kubelet, kubeadm, and kubectl, and pin their version:
    apt-get update
    apt-get install -y kubelet=$KubeAdmVersion-1.1 kubeadm=$KubeAdmVersion-1.1 kubectl=$KubeAdmVersion-1.1

    # apt-mark hold will prevent the package from being automatically upgraded or removed.
    apt-mark hold kubelet kubeadm kubectl
    echo -e "${BGreen}kubeadm, kubelet, and kubectl installed and pinned.${NC}"

# Enable and start kubelet service
    echo -e "${BYellow}Enabling and starting kubelet service...${NC}"
    systemctl daemon-reload
    systemctl start kubelet
    systemctl enable kubelet.service
    echo -e "${BGreen}kubelet service started and enabled.${NC}"

    # Conditional logic based on the argument provided
    if [[ "$MW" == "master" ]]; then
        # Initialize Kubernetes cluster (for master node)
        echo -e "${BYellow}Initializing Kubernetes cluster (master node)...${NC}"
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16

        # Configure kubectl for the regular user
        echo -e "${BYellow}Configuring kubectl for the regular user...${NC}"
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        # Install Flannel CNI plugin
        echo -e "${BYellow}Installing Flannel CNI plugin...${NC}"
        kubectl create -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel-rbac.yml
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
        echo -e "${BGreen}Flannel CNI plugin installed.${NC}"
    else
        echo -e "${BYellow}This node is configured as a worker node. Skipping master node setup.${NC}"
    fi

    echo -e "${BGreen}Kubernetes installation completed successfully!${NC}"

}

current_option=0
navigate_menu 'options1'
selected_option="${options1[$current_option]}"
if [ $selected_option = "Centos" ]; then
    read -p "Enter Kubernetes version (e.g., 1.31): " K8sVersion
    read -p "Enter the kubeadm, kubectl, kubecli version (e.g., 1.30.1): " KubeAdmVersion
    read -p "Enter (master/worker): " MW
    centos_installer
elif [ $selected_option = "Ubuntu" ]; then
    read -p "Enter Kubernetes version (e.g., 1.31): " K8sVersion
    read -p "Enter the kubeadm, kubectl, kubecli version (e.g., 1.30.1): " KubeAdmVersion
    read -p "Enter (master/worker): " MW
    ubuntu_installer
else
    exit 1
fi
