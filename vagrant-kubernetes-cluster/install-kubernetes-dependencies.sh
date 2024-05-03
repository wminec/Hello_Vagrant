#!/bin/bash -e


install_required_packages ()
{
#curl -s https://api.github.com/repos/kubernetes/kubernetes/releases | grep 'tag_name' | cut -d\" -f4 | grep 1.29
export KUBE_VER="1.29.4"
sudo apt update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBE_VER%.*}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBE_VER%.*}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt -y install vim git curl wget kubelet=${KUBE_VER}* kubeadm=${KUBE_VER}* kubectl=${KUBE_VER}*
sudo apt-mark hold kubelet kubeadm kubectl
}

configure_hosts_file ()
{
sudo tee /etc/hosts<<EOF
172.16.8.10 master
172.16.8.11 node-01
EOF
}

disable_swap () 
{
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
}

configure_sysctl ()
{
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
}

install_crio_runtime ()
{
export OS=xUbuntu_22.04
export CRIO_VERSION=1.28

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list

curl -sL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | sudo apt-key add -
curl -sL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -
sudo apt update
apt install cri-o cri-o-runc cri-tools -y
sudo systemctl daemon-reload 
sudo systemctl restart crio.service
sudo systemctl enable crio.service
}

install_required_packages
configure_hosts_file
disable_swap
configure_sysctl
install_crio_runtime