# Declarative OpenShift

This repository contains sets of example resources to be used with a [declarative management strategy](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/). Please familiarize yourself with the terminology in that document before reading on.

The purpose of these examples is twofold:

1. To act as supporting content for a GitOps series being written for [uncontained.io](http://uncontained.io)
2. To serve as a starting point for establishing a GitOps practice for cluster management

## 1 Simple Cluster Bootstrapping

The simple cluster bootstrapping example shows how cluster administrators might begin managing OpenShift clusters using just `oc apply`. Each resource in this example carries a common label (`example.com/project: simple-bootstrap`) that associates it with this `project`. In doing this, we can manage the full lifecycle of our resources with a single command.

```
oc apply -Rf simple-bootstrap/ --prune -l example.com/project=simple-bootstrap
```

The `apply` command idempotently ensures that the live configuration is in sync with our configuration files, while the `--prune` flag allows us to also manage the deletion of live objects by simply deleting the associated file in this repository.

As an example, let's bootstrap our cluster for the first time:

> :exclamation: The first time you run this command, you will get an error applying the `userconfig`. This is because there is a [race condition created when deploying operators through OLM](https://github.com/redhat-cop/declarative-openshift/issues/14). As a workaround, just run the command again until it succeeds.

```
$ oc apply -Rf simple-bootstrap/ --prune -l example.com/project=simple-bootstrap
namespace/deleteable configured
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes created
```

Now, let's remove a namespace and re-run the same command:

```
$ rm simple-bootstrap/0-namespaces/deleteable.yaml

$ oc apply -Rf simple-bootstrap/ --prune -l example.com/project=simple-bootstrap
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes unchanged
namespace/deleteable pruned
```

We can see that by deleting the file, the resource gets deleted.

In order to be able to handle pruning of custom resources, we have to customize the set of resource types that we are searching for with our label. To do this, we pass the `--prune-whitelist` flag. In order to simplify this, we've written the set of flags that we're handling to a file that we add to the command.

```
$ oc apply -Rf simple-bootstrap/ --prune -l example.com/project=simple-bootstrap $(cat prune-whitelist.txt)
namespace/deleteable configured
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes created
```
