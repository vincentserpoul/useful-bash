#!/usr/bin/env bash

set -euo pipefail

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

#=======================  L o c a l  k 3 s  =======================#

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
    cat "$(k3d get-kubeconfig --name="$CLUSTER_NAME")" > ~/.kube/config-"$CLUSTER_NAME"-"$PROVIDER".yaml;

    # cp  ~/.kube/config_"$CLUSTER_NAME".yaml  ~/.kube/config;
}

#=======================  h e l m  =======================#

helm_init() {
    helm repo add stable https://kubernetes-charts.storage.googleapis.com;
    helm repo update;
}
