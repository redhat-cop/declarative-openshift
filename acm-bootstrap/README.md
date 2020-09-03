# Installing the ACM operator with the Operator Lifecycle Manager

This directory contains the manifests required to install the [ACM operaDtor](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.0/html/install/installing#installing-while-connected-online).

You will need to create a base64 encoded pull secret to create the Multi-Cluster Hub.
```
cd  acm-bootstrap/1-operator/
vim *.yaml

apiVersion: v1
kind: Secret
metadata:
  annotations:
    config.example.com/managed-by: gitops
    config.example.com/scm-url: git@github.com:hornjason/declarative-openshift.git
  labels:
    config.example.com/name: acm-bootstrap
    config.example.com/component: operators
  name: pull-secret
  namespace: openshift-image-registry
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: < insert pull secret base64| cat pull_secret.txt|base64 -w0>

# or
oc create secret generic <secret> -n <namespace> --from-file=.dockerconfigjson=<path-to-pull-secret> --type=kubernetes.io/dockerconfigjson

```

## 1 Bootstrapping the ACM Operator

The ACM bootstrapping example shows how cluster administrators might begin deploying the ACM operator `oc apply`. Each resource in this example carries a common label (`config.example.com/name: acm-bootstrap`) that associates it with this `project`. In doing this, we can manage the full lifecycle of our resources with a single command.

```
oc apply -Rf ../acm-bootstrap/ --prune -l config.example.com/name=acm-bootstrap
```

The `apply` command idempotently ensures that the live configuration is in sync with our configuration files, while the `--prune` flag allows us to also manage the deletion of live objects by simply deleting the associated file in this repository.

As an example, let's bootstrap our cluster for the first time:

```
$ oc apply -Rf ../acm-bootstrap/ --prune -l config.example.com/name=acm-bootstrap
namespace/open-cluster-management configured
operatorgroup.operators.coreos.com/acm-operator created
subscription.operators.coreos.com/acm-operator created
```
ACM is now deployed by the ACM operator along with the MultiCluster Hub, you can now generate an import command to bring in Clusters for management in ACM.

To begin creating policies take a look at the follow repo for more examples.
 [ACM-Policiesr](https://github.com/redhat-cop/acm-policies.git )
```
```



