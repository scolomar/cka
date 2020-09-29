################################################################################
#         Copyright (C) 2020         Sebastian Francisco Colomar Bauza         #
#         SPDX-License-Identifier:   GPL-2.0-only                              #
################################################################################
sudo apt-get update && sudo apt-get install -y apt-transport-https curl        ;
echo deb http://apt.kubernetes.io/ kubernetes-xenial main                      \
| sudo tee -a /etc/apt/sources.list.d/kubernetes.list                          ;
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg                  \
| sudo apt-key add -                                                           ;
sudo apt-get update && sudo apt-get install -y docker-ce                       ;
sudo apt-get install -y kubelet kubeadm kubectl                                ;
sudo apt-mark hold kubelet kubeadm kubectl                                     ;
ip=< PRIVATE IP OF THE KUBERNETES MASTER >                                     ;
echo $ip k8smaster | sudo tee -a /etc/hosts                                    ;
#sudo sed -i /127.0.0.1/s/$/' 'k8smaster/ /etc/hosts                           #
sudo kubeadm init                                                              \
  --control-plane-endpoint=k8smaster                                           \
  --pod-network-cidr=192.168.0.0/16                                            \
  --ignore-preflight-errors=all                                                ;
mkdir -p $HOME/.kube                                                           ;
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config                          ;
sudo chown $(id -u):$(id -g) $HOME/.kube/config                                ;
kubectl apply -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml    ;
echo "source <(kubectl completion bash)" >> ~/.bashrc                          ;
kubectl taint node ideapad node-role.kubernetes.io/master:NoSchedule-          ;
kubectl apply  --filename . --recursive                                        ;
kubectl delete --filename . --recursive                                        ;
################################################################################
