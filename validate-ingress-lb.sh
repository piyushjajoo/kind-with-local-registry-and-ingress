#!/bin/sh
set -o errexit

# pull docker image
docker pull hashicorp/http-echo:0.2.3

# tag the image for local registry
docker tag hashicorp/http-echo:0.2.3 localhost:5001/http-echo:0.2.3

# push the docker image
docker push localhost:5001/http-echo:0.2.3

# create foo-app, bar-app pods
kubectl apply -f - <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: foo-app
  labels:
    name: foo-app
    app: http-echo
spec:
  containers:
  - name: foo-app
    image: localhost:5001/http-echo:0.2.3
    args:
    - "-text=foo"
---
kind: Pod
apiVersion: v1
metadata:
  name: bar-app
  labels:
    name: bar-app
    app: http-echo
spec:
  containers:
  - name: bar-app
    image: localhost:5001/http-echo:0.2.3
    args:
    - "-text=bar"
---
kind: Service
apiVersion: v1
metadata:
  name: foo-service-lb
spec:
  type: LoadBalancer
  selector:
    name: foo-app
    app: http-echo
  ports:
  # Default port used by the image
  - port: 5678
---
kind: Service
apiVersion: v1
metadata:
  name: foo-service
spec:
  selector:
    name: foo-app
  ports:
  # Default port used by the image
  - port: 5678
---
kind: Service
apiVersion: v1
metadata:
  name: bar-service
spec:
  selector:
    name: bar-app
  ports:
  # Default port used by the image
  - port: 5678
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - http:
      paths:
      - pathType: Prefix
        path: /foo(/|$)(.*)
        backend:
          service:
            name: foo-service
            port:
              number: 5678
      - pathType: Prefix
        path: /bar(/|$)(.*)
        backend:
          service:
            name: bar-service
            port:
              number: 5678
EOF

# wait for the controllers to take effect
sleep 10

# validate the services

# validate cluster ips via Ingress object
# should output "foo-app"
echo "validating foo-app via Ingress object"
curl localhost/foo/hostname
# should output "bar-app"
echo "validating bar-app via Ingress object"
curl localhost/bar/hostname

# validate load balancer service
echo "validating loadbalancer, note on macOS and Windows, docker does not expose the docker network to the host. Because of this limitation, containers (including kind nodes) are only reachable from the host via port-forwards, however other containers/pods can reach other things running in docker including loadbalancers"
LB_IP=$(kubectl get svc/foo-service-lb -n default -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

# should output foo and bar on separate lines 
for _ in {1..10}; do
  curl ${LB_IP}:5678
done