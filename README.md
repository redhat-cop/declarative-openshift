# Declarative OpenShift

This repository contains sets of example resources to be used with a [declarative management strategy](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/). Please familiarize yourself with the terminology in that document before reading on.

The purpose of these examples is twofold:

1. To act as supporting content for a GitOps series being written for [uncontained.io](http://uncontained.io)
2. To serve as a starting point for establishing a GitOps practice for cluster management

## Quickstart - Simple Bootstrap

The simple cluster bootstrapping example shows how cluster administrators might begin managing OpenShift clusters using just `oc apply`. Each resource in this example carries a common label (`config.example.com/name: simple-bootstrap`) that associates it with this `project`. In doing this, we can manage the full lifecycle of our resources with a single command.

```
until oc apply -Rf simple-bootstrap/ --prune -l config.example.com/name=simple-bootstrap; do sleep 2; done
```

Explanation of the command is below.

### Recursive apply

The `apply` command idempotently ensures that the live configuration is in sync with our configuration files. By adding the `-Rf simple-bootstrap/`, we are able to manage an entire directory structure of manifest files.

```
$ oc apply -Rf simple-bootstrap/
namespace/deleteable created
namespace/namespace-operator created
operatorgroup.operators.coreos.com/namespace-operator created
subscription.operators.coreos.com/namespace-configuration-operator created
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators created
userconfig.redhatcop.redhat.io/sandboxes created
```

If we run this a second time, we'll see that it still completes successfully, but notice that the action taken to each file has been changed from `create` to `unchanged` or in some cases `configured`.

```
$ oc apply -Rf simple-bootstrap/
namespace/deleteable configured
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes created
```

### Pruning resources

The `--prune` flag allows us to also manage the deletion of live objects by simply deleting the associated file in this repository.

Now, let's remove a namespace and re-run the same command:

```
$ rm simple-bootstrap/0-namespaces/deleteable.yaml

$ oc apply -Rf simple-bootstrap/ --prune -l config.example.com/name=simple-bootstrap
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
$ oc apply -Rf simple-bootstrap/ --prune -l config.example.com/name=simple-bootstrap $(cat prune-whitelist.txt)
namespace/deleteable configured
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes created
```

### Handling race conditions

However, there's one likely hiccup that our workflow needs to be able to handle. The management of operators via the [Operator Lifecycel Manager](https://github.com/operator-framework/operator-lifecycle-manager) creates a race condition. When a `Subscription` and `OperatorGroup` resource gets created, it triggers OLM to fetch details about the operator, and install the relevant `CustomResourceDefinitions`(CRDs). Until the CRDs have been put to the cluster, an attempt to create a matching `CustomResource` will fail, as that resource type doesn't yet exist in the API.

In our case, we are deploying the [Namespace Configuration Operator](https://github.com/redhat-cop/namespace-configuration-operator), which provides the `UserConfig` resource type. If we try to create both the `OperatorGroup`/`Subscription` to deploy the operator, and the `UserConfig` to invoke it in the same command, we'll get an error:

```
Error from server (NotFound): error when creating "simple-bootstrap/3-operator-configs/sandbox-userconfig.yaml": the server could not find the requested resource (post userconfigs.redhatcop.redhat.io)
```

The simplest way to handle this is with a simple retry loop.

```
$ until oc apply -Rf simple-bootstrap/ --prune -l config.example.com/name=simple-bootstrap $(cat prune-whitelist.txt); do sleep 2; done
namespace/deleteable configured
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes created
```

This command will re-run (not a problem since `apply` is idempotent) until all resources have been synced to the cluster. Usually this only takes two tries.

## Putting it all together with a GitOps job

Now that we have a repeatable process for managing cluster resources, we can set it up to run automatically as a `CronJob` inside the cluster.

By running the workflow locally, we've already created a `CronJob` in the `cluster-ops` namespace. In order for it to run, it requires a secret be created pointing it to the repository where the cluster configs live.

```
oc create secret generic gitops-repo --from-literal=url=https://github.com/redhat-cop/declarative-openshift.git --from-literal=ref=master --from-literal=contextDir=simple-bootstrap --from-literal=pruneLabel=config.example.com/name=simple-bootstrap -n cluster-ops
```

Now, if you wait a few minutes and check the logs in the job pod...

```
$ oc logs cronjob-gitops-1591666560-4q7f2 -n cluster-ops
Syncing cluster config from https://github.com/redhat-cop/declarative-openshift.git/simple-bootstrap
Cloning into '/tmp/repodir'...
namespace/deleteable configured
namespace/namespace-operator configured
operatorgroup.operators.coreos.com/namespace-operator unchanged
subscription.operators.coreos.com/namespace-configuration-operator unchanged
clusterrolebinding.rbac.authorization.k8s.io/cluster-administrators unchanged
userconfig.redhatcop.redhat.io/sandboxes configured
```

Voila! Enjoy your automatically drift-controlled cluster!

## Additional Examples

The following are additional examples that demonstrate how to declaratively specify common use cases for platform operation:

* [ArgoCD Bootstrap](argocd-bootsrap)
* [Security Context Constraint (SCC) Management](manage-scc)