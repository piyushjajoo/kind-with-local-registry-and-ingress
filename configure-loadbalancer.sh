#!/bin/sh
set -o errexit

# wait for the ingress pods to be running
echo "waiting for nginx pods to be ready"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# install metallb
echo "install metallb"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# wait until MetalLB pods (controller and speaker) are ready
echo "wait until MetalLB pods (controller and speaker) are ready"
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s

# find the cidr range for kind network
echo "find the cidr range for the kind network"
output=$(docker network inspect -f '{{.IPAM.Config}}' kind)

ipv4_cidr=$(echo "$output" | grep -oE '([0-9]+\.[0-9]+)\.[0-9]+\.[0-9]+/[0-9]+' | head -n 1)
ipv4_parts=$(echo "$ipv4_cidr" | cut -d '.' -f 1,2)

echo "IPv4 CIDR Range (First 2 Parts): $ipv4_parts"

# configure ip address pool
echo "configuring ip address pool"
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - $ipv4_parts.255.200-$ipv4_parts.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF