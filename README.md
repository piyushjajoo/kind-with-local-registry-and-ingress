# kind-with-local-registry-and-ingress
KIND cluster configuration to setup local k8s environment with local docker registry and nginx deployment to validate Ingress LoadBalancer type k8s service

## Create k8s cluster with multiple nodes and configure cluster with containerd registry config dir

### create the k8s cluster with multiple nodes

This will create k8s cluster with a `control-plane` and 3 `worker` nodes. The `api-server` and other control plane components will be on the node with role `control-plane`. And nodes with `worker` role will have your pods. You will observe the `controller-manager`, `api-server`, `scheduler`, `etcd`, `coredns`, `kindnet`, `kube-proxy` and `local-path-provisioner` pods will be deployed on the control-plane node by default. The worker nodes will have `kindnet` and `kube-proxy` by default. You will also observe that we are configuring the cluster with `containerd` registry config.

```bash
kind create cluster --config cluster-config.yaml
```

You will see something like below on successful creation of kind cluster -

```bash
$ kind create cluster --config cluster-config.yaml
Creating cluster "platformwale" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-platformwale"
You can now use your cluster with:

kubectl cluster-info --context kind-platformwale

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂

$ kubectl cluster-info --context kind-platformwale
Kubernetes control plane is running at https://127.0.0.1:58931
CoreDNS is running at https://127.0.0.1:58931/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Validate that the nodes are created successfully -

```bash
$ kubectl get nodes
NAME                         STATUS   ROLES           AGE     VERSION
platformwale-control-plane   Ready    control-plane   9m20s   v1.27.3
platformwale-worker          Ready    <none>          8m55s   v1.27.3
platformwale-worker2         Ready    <none>          9m1s    v1.27.3
platformwale-worker3         Ready    <none>          8m56s   v1.27.3
```

Please read this [configuration](https://kind.sigs.k8s.io/docs/user/configuration/)documentation to learn more options to configure the KIND cluster.

### create the local registry and configure the cluster with the registry config

This script will accept the name of the kind cluster name as the parameter, in our case it is `platformwale` as specified in [cluster-config.yaml](./cluster-config.yaml). This script will create the local docker registry and configure the cluster to access the local registry.

The local registry is bootstrapped at `localhost:5001`.

```bash
./create-configure-registry.sh "platformwale"
```

This will output something like below -

```
$ ./create-configure-registry.sh "platformwale"
start the registry container on port 5001
4adf6f1485aab44ccfcacc572c382969b2aed675cf376ee6d193ee26ebfe78e2
=============================
add the registry config to the nodes
=============================
Connect the registry to the cluster network if not already connected
=============================
Document the local registry
configmap/local-registry-hosting unchanged
=============================
```

#### validate the registry

This script will pull `hello-server` image from remote public docker registry, tag and push to the local registry we created earlier and start a deployment using the image pulled from the local registry. This will validate that the local registry was setup correctly.

The deployment will start on `platformwale-worker2` node using `nodeSelector: role=app`.

```bash
./validate-registry.sh
```

This will output something like below -

```
$ ./validate-registry.sh
1.0: Pulling from google-samples/hello-app
Digest: sha256:845f77fab71033404f4cfceaa1ddb27b70c3551ceb22a5e7f4498cdda6c9daea
Status: Image is up to date for gcr.io/google-samples/hello-app:1.0
gcr.io/google-samples/hello-app:1.0
The push refers to repository [localhost:5001/hello-app]
d7d0d6206599: Pushed
00c562532b20: Pushed
f3d1c6badec9: Pushed
1.0: digest: sha256:845f77fab71033404f4cfceaa1ddb27b70c3551ceb22a5e7f4498cdda6c9daea size: 949
deployment.apps/hello-server created
2023/08/15 00:55:04 Server listening on port 8080
```

## Deploy nginx Ingress and validate LoadBalancer k8s service

Deploy the modified [nginx.yaml](./nginx.yaml) which will deploy nginx controller on `platformwale-worker3` node which has taint `role=ingress:NoSchedule` as well as nodeSelector `role: ingress`.

```bash
kubectl apply -f ./nginx.yaml
```

This will output something like below -

```
$ kubectl apply -f ./nginx.yaml
namespace/ingress-nginx created
serviceaccount/ingress-nginx created
serviceaccount/ingress-nginx-admission created
role.rbac.authorization.k8s.io/ingress-nginx created
role.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrole.rbac.authorization.k8s.io/ingress-nginx created
clusterrole.rbac.authorization.k8s.io/ingress-nginx-admission created
rolebinding.rbac.authorization.k8s.io/ingress-nginx created
rolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx created
clusterrolebinding.rbac.authorization.k8s.io/ingress-nginx-admission created
configmap/ingress-nginx-controller created
service/ingress-nginx-controller created
service/ingress-nginx-controller-admission created
deployment.apps/ingress-nginx-controller created
job.batch/ingress-nginx-admission-create created
job.batch/ingress-nginx-admission-patch created
ingressclass.networking.k8s.io/nginx created
validatingwebhookconfiguration.admissionregistration.k8s.io/ingress-nginx-admission created
```

Configure loadbalancer by installing `MetalLB` and assign `IPAddressPool`.

```bash
./configure-loadbalancer.sh
```

This will output something like below -

```
$ ./configure-loadbalancer.sh
waiting for nginx pods to be ready
pod/ingress-nginx-controller-57d7c6cb58-klqmj condition met
install metallb
namespace/metallb-system created
customresourcedefinition.apiextensions.k8s.io/addresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bfdprofiles.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgpadvertisements.metallb.io created
customresourcedefinition.apiextensions.k8s.io/bgppeers.metallb.io created
customresourcedefinition.apiextensions.k8s.io/communities.metallb.io created
customresourcedefinition.apiextensions.k8s.io/ipaddresspools.metallb.io created
customresourcedefinition.apiextensions.k8s.io/l2advertisements.metallb.io created
serviceaccount/controller created
serviceaccount/speaker created
role.rbac.authorization.k8s.io/controller created
role.rbac.authorization.k8s.io/pod-lister created
clusterrole.rbac.authorization.k8s.io/metallb-system:controller created
clusterrole.rbac.authorization.k8s.io/metallb-system:speaker created
rolebinding.rbac.authorization.k8s.io/controller created
rolebinding.rbac.authorization.k8s.io/pod-lister created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:controller created
clusterrolebinding.rbac.authorization.k8s.io/metallb-system:speaker created
secret/webhook-server-cert created
service/webhook-service created
deployment.apps/controller created
daemonset.apps/speaker created
validatingwebhookconfiguration.admissionregistration.k8s.io/metallb-webhook-configuration created
wait until MetalLB pods (controller and speaker) are ready
pod/controller-789c75c689-6vjdh condition met
pod/speaker-hxcg5 condition met
pod/speaker-pk9nc condition met
pod/speaker-wl844 condition met
find the cidr range for the kind network
IPv4 CIDR Range (First 2 Parts): 172.18
configuring ip address pool
ipaddresspool.metallb.io/example created
l2advertisement.metallb.io/empty created
```

Validate the `Ingress` object using `ClusterIP` services as well as validate `LoadBalancer` type service using the script below.
The script below will deploy pods and setup `Ingress` object to divert the traffic to the pods based on `path` configured. This will also install `MetalLB` loadbalancer. 

NOTE: on On macOS and Windows, docker does not expose the docker network to the host. Because of this limitation, containers (including kind nodes) are only reachable from the host via port-forwards, however other containers/pods can reach other things running in docker including loadbalancers.

```bash
./validate-ingress-lb.sh
```

This will output something like below -

```
$ ./validate-ingress-lb.sh
0.2.3: Pulling from hashicorp/http-echo
Digest: sha256:ba27d460cd1f22a1a4331bdf74f4fccbc025552357e8a3249c40ae216275de96
Status: Image is up to date for hashicorp/http-echo:0.2.3
docker.io/hashicorp/http-echo:0.2.3
The push refers to repository [localhost:5001/http-echo]
616807f11d1c: Pushed
0.2.3: digest: sha256:61d5cb94d7e546518a7bbd5bee06bfad0ecea8f56a75b084522a43dccbbcd845 size: 528
pod/foo-app created
pod/bar-app created
service/foo-service-lb created
service/foo-service created
service/bar-service created
Warning: path /foo(/|$)(.*) cannot be used with pathType Prefix
Warning: path /bar(/|$)(.*) cannot be used with pathType Prefix
ingress.networking.k8s.io/example-ingress created
validating foo-app via Ingress object
foo
validating bar-app via Ingress object
bar
validating loadbalancer, note on macOS and Windows, docker does not expose the docker network to the host. Because of this limitation, containers (including kind nodes) are only reachable from the host via port-forwards, however other containers/pods can reach other things running in docker including loadbalancers.
```

Please see this [documentation](https://www.thehumblelab.com/kind-and-metallb-on-mac/) on how to make `kind` and `metallb` work on mac.

## Cleanup

You can cleanup the `kind` cluster as well as `registry` using the script below.

```bash
./destroy.sh
```

## Resources

- [kind documentation](https://kind.sigs.k8s.io/)
- [kind resources](https://kind.sigs.k8s.io/docs/user/resources/)
- All the scripts and yamls are uploaded in this [github repository](https://github.com/piyushjajoo/kind-with-local-registry-and-ingress)
- [MetalLB docs](https://metallb.universe.tf/installation/)
