#!/bin/bash -xe

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cd /root

yum update -y

# install docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker

# install `kubernetes in docker` (kind)
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind

# install git
yum groupinstall 'Development Tools' -y

# install brew, k9s, and kubectl
su - ec2-user <<EOF
git clone https://github.com/Homebrew/brew /home/ec2-user/.linuxbrew/Homebrew
mkdir /home/ec2-user/.linuxbrew/bin
ln -s /home/ec2-user/.linuxbrew/Homebrew/bin/brew /home/ec2-user/.linuxbrew/bin
echo "eval \$(/home/ec2-user/.linuxbrew/Homebrew/bin/brew shellenv)" >> /home/ec2-user/.bash_profile
source /home/ec2-user/.bash_profile
brew install gcc

brew install derailed/k9s/k9s

curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
EOF

# create kubernetes cluster
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
- role: control-plane
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
- role: worker
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
  extraPortMappings:
  - containerPort: 30080
    hostPort: 3080
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
  extraPortMappings:
  - containerPort: 30080
    hostPort: 3081
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
  image: kindest/node:v1.15.7@sha256:e2df133f80ef633c53c0200114fce2ed5e1f6947477dbc83261a6a921169488d
  extraPortMappings:
  - containerPort: 30080
    hostPort: 3082
    listenAddress: "0.0.0.0"
    protocol: tcp
EOF
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-kind

cp -r ./.kube /home/ec2-user/
chown -R ec2-user:ec2-user /home/ec2-user/.kube
