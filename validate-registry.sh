#!/bin/sh
set -o errexit

# pull a sample hello-app from remote registry
docker pull gcr.io/google-samples/hello-app:1.0

# tag the pulled docker image for local registry
docker tag gcr.io/google-samples/hello-app:1.0 localhost:5001/hello-app:1.0

# push the docker image to the local registry
docker push localhost:5001/hello-app:1.0

# deployment hello-server deployment on platformwale-worker2 node
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello-server
  name: hello-server
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-server
  template:
    metadata:
      labels:
        app: hello-server
    spec:
      nodeSelector:
        role: app
      containers:
      - image: localhost:5001/hello-app:1.0
        imagePullPolicy: IfNotPresent
        name: hello-app
EOF

# sleep for the pod to be running
sleep 10

# retrieve the logs
podName=$(kubectl get po -n default --no-headers | grep hello-server | awk -F ' ' '{print $1}')
kubectl logs -n default "${podName}"