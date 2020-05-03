#!/usr/bin/env bash

set -euo pipefail

#==============================================================================#

#============================  i n c l u d e s  ===============================#

DIR_DO="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR_DO" ]]; then DIR_DO="$PWD"; fi

# shellcheck source=/dev/null
. "$DIR_DO/utils.sh"
# shellcheck source=/dev/null
. "$DIR_DO/kubecontext.sh"
# shellcheck source=/dev/null
. "$DIR_DO/helm.sh"

#===============================  d e p s  ====================================#

dep_check kubectl
dep_check doctl
dep_check helm

#==========================  D i g i t a l  O c e a n =========================#

do_cluster_create() {
    local -r CLUSTER_NAME=$1
    local -r NODE_COUNT=${2:-3}
    local -r REGION=${3:-sgp1}
    local -r MACHINE_SIZE=${4:-s-4vcpu-8gb}

    if [[ -d "$CLUSTER_NAME" ]]; then die "you must define a cluster name"; fi

    einfo "creating do cluster ""$CLUSTER_NAME"" with ""$NODE_COUNT"" nodes"

    doctl kubernetes cluster create "$CLUSTER_NAME" \
        --region "$REGION" \
        --size "$MACHINE_SIZE" \
        --count "$NODE_COUNT"

    sleep 10s

    do_cluster_kubeconfig_save "$CLUSTER_NAME"

    kubectl create clusterrolebinding \
        --user system:serviceaccount:kube-system:default kube-system-cluster-admin \
        --clusterrole cluster-admin

    metrics_server_deploy
}

do_cluster_wait_til_ready() {
    local -r CLUSTER_NAME=$1

    einfo 'waiting for k3d cluster to be available'
    sleep 5s
    kubectl -n kube-system rollout status deployments/coredns
    sleep 10s
    kubectl -n kube-system rollout status deployments/traefik
}

do_cluster_context_file_path() {
    local -r CLUSTER_NAME=$1
    echo "$HOME/.kube/config-""$CLUSTER_NAME"".yaml"
}

do_cluster_delete() {
    local -r CLUSTER_NAME=$1

    local -r CONTEXT_FILE_PATH=$(do_cluster_context_file_path "$CLUSTER_NAME")

    ewarn 'deleting do cluster'

    doctl kubernetes cluster delete "$CLUSTER_NAME"
    kubecontext_delete "$CLUSTER_NAME"
    rm "$CONTEXT_FILE_PATH"
}

do_cluster_kubeconfig_save() {
    local -r CLUSTER_NAME=$1

    local -r CONTEXT_FILE_PATH=$(do_cluster_context_file_path "$CLUSTER_NAME")

    mkdir -p "$HOME"/.kube
    doctl kubernetes clusters kubeconfig show "$CLUSTER_NAME" \
        >"$CONTEXT_FILE_PATH"

    kubecontext_save "$CLUSTER_NAME" "$CONTEXT_FILE_PATH"
}

metrics_server_deploy() {
    helm_init

    helm install metrics-server stable/metrics-server \
        --namespace kube-system \
        --set args="{--metric-resolution=10s,--kubelet-preferred-address-types=InternalIP}"
    # https://www.digitalocean.com/community/tutorials/how-to-autoscale-your-workloads-on-digitalocean-kubernetes
}
