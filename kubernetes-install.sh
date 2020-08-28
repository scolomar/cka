#########################################################################
#      Copyright (C) 2020        Sebastian Francisco Colomar Bauza      #
#      SPDX-License-Identifier:  GPL-2.0-only                           #
#########################################################################
export repository_docker_aws=docker-aws                                 ;
export stack=${repository_docker_aws}-$( date +%s )                     ;
export RecordSetNameKube=${stack}-kube-apiserver                        ;
export HostedZoneName=sebastian-colomar.com                             ;
export branch_docker_aws=master                                         ;
export domain=github.com                                                ;
export ip_leader=10.168.1.100                                           ;
export log=/tmp/kubernetes-install.log                                  ;
export kube=$RecordSetNameKube.$HostedZoneName                          ;
export username_docker_aws=secobau                                      ;
export A=$username_docker_aws/$repository_docker_aws                    ;
#########################################################################
#      TO BE RUN ON MASTERS AND WORKERS                                 #
#########################################################################
file=kubernetes.repo                                                    ;
repos=yum.repos.d                                                       ;
uuid=$( uuidgen )                                                       ;
path=$uuid/etc/$repos                                                   ;
git clone                                                               \
  --single-branch --branch $branch_docker_aws                           \
  https://$domain/$A                                                    \
  $uuid                                                                 \
                                                                        ;
mv $path/$file /etc/$repos/$file                                        ;
rm --recursive --force $uuid                                            ;
yum install                                                             \
  --assumeyes                                                           \
  --disableexcludes=kubernetes                                          \
  kubelet-1.18.4-1                                                      \
  kubeadm-1.18.4-1                                                      \
  kubectl-1.18.4-1                                                      \
                                                                        ;
systemctl enable                                                        \
  --now                                                                 \
  kubelet                                                               \
                                                                        ;
#########################################################################
#      TO BE RUN ON LEADER MASTER                                       #
#########################################################################
calico=https://docs.projectcalico.org/v3.14/manifests                   ;
cidr=192.168.0.0/16                                                     ;
kubeconfig=/etc/kubernetes/admin.conf                                   ;
echo $ip_leader $kube | tee --append /etc/hosts                        	;
while true                                                              ;
do                                                                      \
  systemctl                                                             \
    is-enabled                                                          \
      kubelet                                                           \
  |                                                                     \
  grep enabled                                                          \
  && break                                                              \
                                                                        ;
done                                                                    ;
kubeadm init                                                            \
  --upload-certs                                                        \
  --control-plane-endpoint                                              \
    "$kube"                                                             \
  --pod-network-cidr                                                    \
    $cidr                                                               \
  --ignore-preflight-errors                                             \
    all                                                                 \
  2>&1                                                                  \
|                                                                       \
tee --append $log                                                       \
                                                                        ;
kubectl apply                                                           \
  --filename                                                            \
    $calico/calico.yaml                                                 \
  --kubeconfig                                                          \
    $kubeconfig                                                         \
  2>&1                                                                  \
|                                                                       \
tee --append $log                                                       \
                                                                        ;
while true                                                              ;
do                                                                      \
  kubectl get node                                                      \
    --kubeconfig $kubeconfig                                            \
  |                                                                     \
  grep Ready                                                            \
  |                                                                     \
  grep --invert-match NotReady                                          \
  &&                                                                    \
  break                                                                 \
                                                                        ;
  sleep 10                                                              ;
done                                                                    ;
sed --in-place                                                          \
  /$kube/d                                                              \
  /etc/hosts                                                            ;
sed --in-place                                                          \
  /localhost4/s/$/' '$kube/                                             \
  /etc/hosts                                                            ;
token_certificate=$(                                                    \
  grep --max-count 1                                                    \
    certificate-key                                                     \
    $log                                                                \
  |                                                                     \
  sed 's/\\/ /'                                                         \
  |                                                                     \
  base64                                                                \
    --wrap 0                                                            \
)                                                                       ;
token_discovery=$(                                                      \
  grep --max-count 1                                                    \
    discovery-token-ca-cert-hash                                        \
    $log                                                                \
  |                                                                     \
  sed 's/\\/ /'                                                         \
  |                                                                     \
  base64                                                                \
    --wrap 0                                                            \
)                                                                       ;
token_token=$(                                                          \
  grep --max-count 1                                                    \
    kubeadm.*join                                                       \
    $log                                                                \
  |                                                                     \
  sed 's/\\/ /'                                                         \
  |                                                                     \
  base64                                                                \
    --wrap 0                                                            \
)                                                                       ;
export token_certificate=$token_certificate                             \
&&                                                                      \
export token_discovery=$token_discovery                                 \
&&                                                                      \
export token_token=$token_token                                         \
                                                                        ;
#########################################################################
#      TO BE RUN ON NON LEADER MASTERS                                  #
#########################################################################
token_certificate="$(                                                   \
  echo                                                                  \
    $token_certificate                                                  \
  |                                                                     \
  base64                                                                \
    --decode                                                            \
)"                                                                      ;
token_discovery="$(                                                     \
  echo                                                                  \
    $token_discovery                                                    \
  |                                                                     \
  base64                                                                \
    --decode                                                            \
)"                                                                      ;
token_token="$(                                                         \
  echo                                                                  \
    $token_token                                                        \
  |                                                                     \
  base64                                                                \
    --decode                                                            \
)"                                                                      ;
echo $ip_leader $kube | tee --append /etc/hosts                         ;
while true                                                              ;
do                                                                      \
  systemctl                                                             \
    is-enabled                                                          \
      kubelet                                                           \
  |                                                                     \
  grep enabled                                                          \
  && break                                                              \
                                                                        ;
done                                                                    ;
while true                                                              ;
do                                                                      \
  sleep 10                                                              ;
  $token_token                                                          \
    $token_discovery                                                    \
    $token_certificate                                                  \
    --ignore-preflight-errors                                           \
      all                                                               \
    2>&1                                                                \
  |                                                                     \
  tee $log                                                              \
                                                                        ;
  grep 'This node has joined the cluster' $log && break                 ;
done                                                                    ;
sed --in-place                                                          \
  /$kube/d                                                              \
  /etc/hosts                                                            ;
sed --in-place                                                          \
  /localhost4/s/$/' '$kube/                                             \
  /etc/hosts                                                            ;
#########################################################################
#      TO BE RUN ON WORKERS                                             #
#########################################################################
token_discovery="$(                                                     \
  echo                                                                  \
    $token_discovery                                                    \
  |                                                                     \
  base64                                                                \
    --decode                                                            \
)"                                                                      ;
token_token="$(                                                         \
  echo                                                                  \
    $token_token                                                        \
  |                                                                     \
  base64                                                                \
    --decode                                                            \
)"                                                                      ;
compose=etc/docker/swarm/docker-compose.yaml                            ;
uuid=$( uuidgen )                                                       ;
git clone                                                               \
  --single-branch --branch v1.1                                         \
  https://github.com/secobau/nlb                                        \
  $uuid                                                                 ;
sed --in-place s/worker/manager/ $uuid/$compose                         ;
sudo cp --recursive --verbose $uuid/run/* /run                          ;
docker swarm init                                                       ;
docker stack deploy --compose-file $uuid/$compose nlb                   ;
while true                                                              ;
do                                                                      \
  sleep 1                                                               ;
  docker service ls | grep '\([0-9]\)/\1' && break                      ;
done                                                                    ;
sudo rm --recursive --force /run/secrets /run/configs                   ;
sed --in-place                                                          \
  /$kube/d                                                              \
  /etc/hosts                                                            ;
sed --in-place                                                          \
  /localhost4/s/$/' '$kube/                                             \
  /etc/hosts                                                            ;
while true                                                              ;
do                                                                      \
  systemctl                                                             \
    is-enabled                                                          \
      kubelet                                                           \
  |                                                                     \
  grep enabled                                                          \
  && break                                                              \
                                                                        ;
done                                                                    ;
$token_token                                                            \
  $token_discovery                                                      \
  --ignore-preflight-errors                                             \
    all                                                                 \
  2>&1                                                                  \
  |                                                                     \
  tee $log                                                              \
                                                                        ;
#########################################################################
