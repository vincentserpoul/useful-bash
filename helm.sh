#!/usr/bin/env bash

set -euo pipefail

#==============================================================================#

#============================  i n c l u d e s  ===============================#

DIR_HELM="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR_HELM" ]]; then DIR_HELM="$PWD"; fi

# shellcheck source=/dev/null
. "$DIR_HELM/utils.sh"

#===============================  d e p s  ====================================#

dep_check kubectl

#===============================  h e l m  ====================================#

helm_init() {
    einfo 'initializing helm'

    helm repo add stable https://kubernetes-charts.storage.googleapis.com
    helm repo update
}
