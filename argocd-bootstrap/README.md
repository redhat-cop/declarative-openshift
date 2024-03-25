# Installing the Argo CD operator with the Operator Lifecycle Manager

This directory contains the manifests required to install the [Argo CD operator](https://argocd-operator.readthedocs.io/en/latest/install/olm/).

## 1 Bootstrapping the Argo CD Operator

The argo-cd cluster bootstrapping example shows how cluster administrators might begin deploying the argo-cd operator `oc apply`. Each resource in this example carries a common label (`config.example.com/name: argocd-bootstrap`) that associates it with this `project`. In doing this, we can manage the full lifecycle of our resources with a single command.

```
oc apply -Rf ../argocd-bootstrap/ --prune -l config.example.com/name=argocd-bootstrap
```

The `apply` command idempotently ensures that the live configuration is in sync with our configuration files, while the `--prune` flag allows us to also manage the deletion of live objects by simply deleting the associated file in this repository.

As an example, let's bootstrap our cluster for the first time:

```
$ oc apply -Rf ../argocd-bootstrap/ --prune -l config.example.com/name=argocd-bootstrap
namespace/argocd configured
operatorgroup.operators.coreos.com/argocd-operator created
subscription.operators.coreos.com/argocd-operator created
argocd.argoproj.io/example-argocd created
```
Argo-cd is now deployed by the argo-cd operator. Take a look at all of the components deployed by the operator.
```
$ oc get all -n argocd
NAME                                                         READY   STATUS    RESTARTS   AGE
pod/argocd-operator-786776bfc-84d8z                          1/1     Running   0          31m
pod/example-argocd-application-controller-77c6c4c5b5-vgjp8   1/1     Running   0          31m
pod/example-argocd-dex-server-765597d97-85q62                1/1     Running   0          31m
pod/example-argocd-redis-5b8dcc7f45-992c7                    1/1     Running   0          31m
pod/example-argocd-repo-server-77b8ff4fcb-hnddh              1/1     Running   0          31m
pod/example-argocd-server-6b49b4dfd8-fblp4                   1/1     Running   0          31m

NAME                                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/argocd-operator-metrics         ClusterIP   172.30.207.80    <none>        8383/TCP,8686/TCP   31m
service/example-argocd-dex-server       ClusterIP   172.30.86.202    <none>        5556/TCP,5557/TCP   31m
service/example-argocd-metrics          ClusterIP   172.30.196.132   <none>        8082/TCP            31m
service/example-argocd-redis            ClusterIP   172.30.77.235    <none>        6379/TCP            31m
service/example-argocd-repo-server      ClusterIP   172.30.140.134   <none>        8081/TCP,8084/TCP   31m
service/example-argocd-server           ClusterIP   172.30.131.235   <none>        80/TCP,443/TCP      31m
service/example-argocd-server-metrics   ClusterIP   172.30.45.111    <none>        8083/TCP            31m

NAME                                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/argocd-operator                         1/1     1            1           31m
deployment.apps/example-argocd-application-controller   1/1     1            1           31m
deployment.apps/example-argocd-dex-server               1/1     1            1           31m
deployment.apps/example-argocd-redis                    1/1     1            1           31m
deployment.apps/example-argocd-repo-server              1/1     1            1           31m
deployment.apps/example-argocd-server                   1/1     1            1           31m

NAME                                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/argocd-operator-786776bfc                          1         1         1       31m
replicaset.apps/example-argocd-application-controller-77c6c4c5b5   1         1         1       31m
replicaset.apps/example-argocd-dex-server-765597d97                1         1         1       31m
replicaset.apps/example-argocd-redis-5b8dcc7f45                    1         1         1       31m
replicaset.apps/example-argocd-repo-server-77b8ff4fcb              1         1         1       31m
replicaset.apps/example-argocd-server-6b49b4dfd8                   1         1         1       31m
```

It's great that argo-cd is deploy onto the cluster, but without a route, there is no easy way to use the UI. Let's enable the route in the argo-cd object and reapply our configuration, and rerun the same command.


Update spec section of the argocd-object to set the route under server to true.
```
$ vi 3-argocd/argocd-basic.yaml

apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  annotations:
    config.example.com/managed-by: gitops
    config.example.com/scm-url: git@github.com:redhat-cop/declarative-openshift.git
  labels:
    example: basic
    config.example.com/component: operators
    config.example.com/name: argocd-bootstrap
  name: example-argocd
spec:
  server:
    route: 
      enabled: true


$ oc apply -Rf simple-bootstrap/ --prune -l config.example.com/name=simple-bootstrap
namespace/argocd configured
operatorgroup.operators.coreos.com/argocd-operator unchanged
subscription.operators.coreos.com/argocd-operator unchanged
argocd.argoproj.io/example-argocd configured
```

Now you can see the newly created route for the argo-cd server

```
$ oc get routes -n argocd
NAME                    HOST/PORT                                       PATH   SERVICES                PORT    TERMINATION        WILDCARD
example-argocd-server   example-argocd-server-argocd.apps-crc.testing          example-argocd-server   https   passthrough/None   None
```

You can now access argo-cd through the UI. The password for the admin account is auto-generated and stored in the secret 'example-argocd-cluster'. To extract the admin password with 'jq':

```
$ oc get secret/example-argocd-cluster -o json | jq '.data|to_entries|map({key, value:.value|@base64d})|from_entries'
```
