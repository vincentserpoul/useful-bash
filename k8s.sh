#!/usr/bin/env bash

set -euo pipefail

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi

. "$DIR/utils.sh"

#=============  k u b e c t l  c o n t e x t  a n d  c o n f i g  =============#

save_kubecontext() {
    KUBE_NAME=$1;
    KUBE_PROVIDER=$2;
    touch ~/.kube/config;
    KUBECONFIG=~/.kube/config-"$KUBE_NAME"-"$KUBE_PROVIDER".yaml:~/.kube/config \
      kubectl config view --flatten > ~/.kube/config;
    kubectl config set-context "$KUBE_NAME";
}

destroy_kubecontext() {
    KUBE_NAME=$1;
    kubectl config delete-context "$KUBE_NAME";
    kubectl config unset users."$KUBE_NAME";
    kubectl config unset contexts."$KUBE_NAME";
    kubectl config unset clusters."$KUBE_NAME";
}

#=============================  L o c a l  k 3 s  =============================#

create_k3s_cluster() {
    einfo 'creating k3d cluster';
    k3d create --api-port 6443 --name "$CLUSTER_NAME" --publish 8080:80 \
        --workers 3;
    sleep 10s;
    save_kubeconfig_k3s_cluster;
    save_kubecontext "$CLUSTER_NAME" "$PROVIDER";
    wait_til_k3d_cluster_ready;
}

wait_til_k3d_cluster_ready() {
    einfo 'waiting for k3d cluster to be available';
    sleep 5s;
    kubectl -n kube-system rollout status deployments/coredns;
    sleep 10s;
    kubectl -n kube-system rollout status deployments/traefik;
}

destroy_k3s_cluster() {
    ewarn 'destroying local k3d cluster';
    k3d delete --name "$CLUSTER_NAME";
    destroy_kubecontext "$CLUSTER_NAME";
}

save_kubeconfig_k3s_cluster() {
    mkdir -p ~/.kube;
    cat "$(k3d get-kubeconfig --name="$CLUSTER_NAME")" \
        > ~/.kube/config-"$CLUSTER_NAME"-"$PROVIDER".yaml;
}

#===============================  h e l m  ====================================#

helm_init() {
    einfo 'initializing helm';
    helm repo add stable https://kubernetes-charts.storage.googleapis.com;
    helm repo update;
}


#==========================  D i g i t a l  O c e a n =========================#

create_do_cluster() {
    doctl kubernetes cluster create "$CLUSTER_NAME" --region sgp1 --size s-4vcpu-8gb --count 4;
    save_kubeconfig_do_cluster;
    save_kubecontext "$CLUSTER_NAME" "$PROVIDER";
    kubectl create clusterrolebinding --user system:serviceaccount:kube-system:default \
        kube-system-cluster-admin \
        --clusterrole cluster-admin;
    deploy_metrics_server;
}

destroy_do_cluster() {
    doctl kubernetes cluster delete "$CLUSTER_NAME";
    destroy_kubecontext "$CLUSTER_NAME";
}

save_kubeconfig_do_cluster() {
    mkdir -p ~/.kube;
    doctl kubernetes clusters kubeconfig show "$CLUSTER_NAME" > \
        ~/.kube/config-"$CLUSTER_NAME"-do.yaml;
}

deploy_metrics_server() {
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/;
    helm install metrics-server stable/metrics-server \
        --namespace kube-system \
        --set args="{--metric-resolution=15s,--kubelet-preferred-address-types=InternalIP}";
    # https://www.digitalocean.com/community/tutorials/how-to-autoscale-your-workloads-on-digitalocean-kubernetes
}
