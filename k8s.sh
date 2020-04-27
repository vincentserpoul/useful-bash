#!/usr/bin/env bash

set -euo pipefail

#==============================================================================#

#============================  i n c l u d e s  ===============================#

DIR_K8S="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR_K8S" ]]; then DIR_K8S="$PWD"; fi

# shellcheck source=/dev/null
. "$DIR_K8S/utils.sh"

#===============================  d e p s  ====================================#

dep_check kubectl
dep_check k3d
dep_check helm

#=============  k u b e c t l  c o n t e x t  &  c o n f i g  =================#

kubecontext_save() {
    local -r PROVIDER=$1
    local -r CLUSTER_NAME=$2

    if [[ ! -f ~/.kube/config ]]; then
        touch ~/.kube/config
    fi
    KUBECONFIG=~/.kube/config-"$CLUSTER_NAME"-"$PROVIDER".yaml:~/.kube/config \
        kubectl config view --flatten >~/.kube/config.new
    mv ~/.kube/config ~/.kube/config.bak
    mv ~/.kube/config.new ~/.kube/config
    kubectl config set-context "$CLUSTER_NAME"
}

kubecontext_destroy() {
    local -r CLUSTER_NAME=$1

    kubectl config delete-context "$CLUSTER_NAME"
    kubectl config unset users."$CLUSTER_NAME"
    kubectl config unset contexts."$CLUSTER_NAME"
    kubectl config unset clusters."$CLUSTER_NAME"
}

#=============================  L o c a l  k 3 s  =============================#

k3s_cluster_create() {
    local -r CLUSTER_NAME=$1
    local -r WORKERS_COUNT=${2:-3}
    local -r PUBLISH_PORT=${3:-8080}
    local -r API_PORT=${4:-6443}

    if [[ -d "$CLUSTER_NAME" ]]; then die "you must define a cluster name"; fi

    einfo "creating k3d cluster ""$CLUSTER_NAME"" with ""$WORKERS_COUNT"" workers, listening on port ""$PUBLISH_PORT"", api on port ""$API_PORT"""
    k3d create --name "$CLUSTER_NAME" \
        --workers "$WORKERS_COUNT" \
        --publish "$PUBLISH_PORT":80 \
        --api-port "$API_PORT"

    sleep 10s
    k3s_cluster_kubeconfig_save "$CLUSTER_NAME"
    kubecontext_save "k3d" "$CLUSTER_NAME"
    k3s_cluster_wait_til_ready "$CLUSTER_NAME"
}

k3s_cluster_wait_til_ready() {
    local -r CLUSTER_NAME=$1

    einfo 'waiting for k3d cluster to be available'
    sleep 5s
    kubectl -n kube-system rollout status deployments/coredns
    sleep 10s
    kubectl -n kube-system rollout status deployments/traefik
}

k3s_cluster_destroy() {
    local -r CLUSTER_NAME=$1

    ewarn 'destroying local k3d cluster'
    k3d delete --name "$CLUSTER_NAME"
    kubecontext_destroy "$CLUSTER_NAME"
}

k3s_cluster_kubeconfig_save() {
    local -r CLUSTER_NAME=$1

    mkdir -p ~/.kube
    cat "$(k3d get-kubeconfig --name="$CLUSTER_NAME")" \
        >~/.kube/config-"$CLUSTER_NAME"-k3d.yaml
}

#===============================  h e l m  ====================================#

helm_init() {
    einfo 'initializing helm'
    helm repo add stable https://kubernetes-charts.storage.googleapis.com
    helm repo update
}
