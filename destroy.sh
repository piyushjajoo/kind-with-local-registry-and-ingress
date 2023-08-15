#!/bin/sh
set -o errexit

# delete kind cluster
echo "deleting kind cluster"
kind delete cluster --name "platformwale"

# delete registry
echo "deleting registry"
docker rm -f $(docker ps -a | grep registry | awk -F ' ' '{print $1}')