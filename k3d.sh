#!/usr/bin/env bash

set -euo pipefail

#==============================================================================#

#============================  i n c l u d e s  ===============================#

DIR_K3S="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR_K3S" ]]; then DIR_K3S="$PWD"; fi

# shellcheck source=/dev/null
. "$DIR_K3S/utils.sh"
# shellcheck source=/dev/null
. "$DIR_K3S/kubecontext.sh"

#===============================  d e p s  ====================================#

dep_check kubectl
dep_check k3d

#=============================  L o c a l  k 3 s  =============================#

k3s_cluster_create() {
    local -r CLUSTER_NAME=$1
    local -r WORKERS_COUNT=${2:-3}
    local -r PUBLISH_PORT=${3:-8080}
    local -r API_PORT=${4:-6443}
    local -r SERVER_ARG=${5:-""}
    local -r AGENT_ARG=${6:-""}

    if [[ -d "$CLUSTER_NAME" ]]; then die "you must define a cluster name"; fi

    einfo "creating k3d cluster ""$CLUSTER_NAME"" with ""$WORKERS_COUNT"" workers, listening on port ""$PUBLISH_PORT"", api on port ""$API_PORT"""
    k3d create --name "$CLUSTER_NAME" \
        --workers "$WORKERS_COUNT" \
        --publish "$PUBLISH_PORT":80 \
        --api-port "$API_PORT" \
        --server-arg "$SERVER_ARG" \
        --agent-arg "$AGENT_ARG"

    sleep 10s

    k3s_cluster_kubeconfig_save "$CLUSTER_NAME"

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

k3s_cluster_context_file_path() {
    local -r CLUSTER_NAME=$1
    echo "$HOME/.kube/config-""$CLUSTER_NAME"".yaml"
}

k3s_cluster_delete() {
    local -r CLUSTER_NAME=$1

    local -r CONTEXT_FILE_PATH=$(k3s_cluster_context_file_path "$CLUSTER_NAME")

    ewarn 'deleting local k3d cluster'
    k3d delete --name "$CLUSTER_NAME"
    kubecontext_delete "$CLUSTER_NAME"
    rm "$CONTEXT_FILE_PATH"
}

k3s_cluster_kubeconfig_save() {
    local -r CLUSTER_NAME=$1

    local -r CONTEXT_FILE_PATH=$(k3s_cluster_context_file_path "$CLUSTER_NAME")

    mkdir -p "$HOME"/.kube
    cat "$(k3d get-kubeconfig --name="$CLUSTER_NAME")" \
        >"$CONTEXT_FILE_PATH"

    kubecontext_save "$CLUSTER_NAME" "$CONTEXT_FILE_PATH"
}
