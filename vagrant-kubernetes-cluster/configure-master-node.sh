#!/bin/bash -e

master_node=172.16.8.10
pod_network_cidr=192.168.0.0/16

initialize_master_node ()
{
sudo systemctl enable kubelet
sudo kubeadm config images pull --cri-socket /run/crio/crio.sock
sudo kubeadm init --cri-socket /run/crio/crio.sock --apiserver-advertise-address=$master_node --pod-network-cidr=$pod_network_cidr --ignore-preflight-errors=NumCPU
}

create_join_command ()
{
kubeadm token create --print-join-command | sed 's/--token/--cri-socket unix:\/\/\/run\/crio\/crio.sock --token/' | tee /vagrant/join_command.sh
chmod +x /vagrant/join_command.sh
}

configure_kubectl () 
{
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown -R $(id -u):$(id -g) $HOME/.kube

##For vagrant user
mkdir -p /home/vagrant/.kube
sudo cp -f /etc/kubernetes/admin.conf /home/vagrant/.kube/config
sudo chown vagrant:vagrant /home/vagrant/.kube/config
}

install_network_cni ()
{
kubectl apply -f /vagrant/kube-flannel.yml
}

install_cilium_cni ()
{
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

cilium --version
cilium install

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

cilium hubble enable
}



initialize_master_node
configure_kubectl
#install_network_cni
install_cilium_cni
create_join_command