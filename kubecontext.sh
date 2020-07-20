#!/usr/bin/env bash

set -euo pipefail

#==============================================================================#

#============================  i n c l u d e s  ===============================#

DIR_KUBECONTEXT="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR_KUBECONTEXT" ]]; then DIR_KUBECONTEXT="$PWD"; fi

# shellcheck source=/dev/null
. "$DIR_KUBECONTEXT/utils.sh"

#===============================  d e p s  ====================================#

dep_check kubectl

#=============  k u b e c t l  c o n t e x t  &  c o n f i g  =================#

kubecontext_save() {
    local -r CONTEXT_NAME=$1
    local -r CONTEXT_FILE_PATH=$2

    einfo "saving kubecontext $CONTEXT_NAME"

    if [[ ! -f ~/.kube/config ]]; then
        touch ~/.kube/config
    fi
    KUBECONFIG="$CONTEXT_FILE_PATH":~/.kube/config \
        kubectl config view --flatten >~/.kube/config.new
    mv ~/.kube/config ~/.kube/config.bak
    mv ~/.kube/config.new ~/.kube/config
    kubectl config set-context "$CONTEXT_NAME"
}

kubecontext_delete() {
    local -r CONTEXT_NAME=$1

    einfo "deleting kubecontext $CONTEXT_NAME"

    kubectl config delete-context "$CONTEXT_NAME"
    kubectl config unset users."$CONTEXT_NAME"
    kubectl config unset contexts."$CONTEXT_NAME"
    kubectl config unset clusters."$CONTEXT_NAME"
}

dep_check kubectl
