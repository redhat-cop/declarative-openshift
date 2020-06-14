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

## Managing Access to Security Context Constraints

OpenShift provides for a secure environment by making use of Security Context Constraints to govern the level of access that is granted to a running container. By default, all containers execute using the `restricted` SCC. There are circumstances where it may be desired or necessary for a container to make use of an alternate SCC. OpenShift contains several SCC's for a variety of use cases including granting access to resources on the Container Host or access to the Container Host Network. 

As a user with elevated access, execute the following commands to view all of the SCC's that are currently defined in the environment:

```
$ oc get scc
NAME               AGE
anyuid             6h45m
hostaccess         6h45m
hostmount-anyuid   6h45m
hostnetwork        6h45m
node-exporter      6h34m
nonroot            6h45m
privileged         6h45m
restricted         6h45m
```

The most common use case for containers running in OpenShift to make use of an alternate SCC is for the container to use the ID of the user specified in the image instead of a randomly generated ID. The `anyuid` SCC provides this functionality and the assets in this exercise will demonstrate how to grant and verify access.

In earlier versions of OpenShift, the preferred method for granting access to an SCC was to make use of a dedicated Service Account to execute the pod and to add the Service Account Directly to the SCC. This caused challenges as the platform evolved over time. The preferred method is to use Role Based Access Controls (RBAC) to declaratively state that grants a Service Account access to a particular SCC.

### SCC Management in Action

By applying the resources in prior sections, the following were applied to the cluster: 

* A _Namespace_ called `manage-scc`
* A _ClusterRole_ the provides access to the _anyuid_ SCC
* A _ServiceAccount_ that can be used by Pods requiring access to the _anyuid_ SCC
* A _ClusterRoleBinding_ that links the _ServiceAccount_ to the _ClusterRole_
* A _Job_ that uses the _ServiceAccount_ to validate it has access to the desired SCC

The key to enabling access to the _anyuid_ SCC is in the `allow-anyuid-scc` _ClusterRole_ by specifying access to `use` through this verb to the resource name called `anyuid` in the `securitycontextconstraints` resource in the `security.openshift.io` as shown below:

```
rules:
  - apiGroups:
      - security.openshift.io
    resources:
      - securitycontextconstraints
    verbs:
      - use
    resourceNames:
      - anyuid
```

The association between the _ClusterRole_ and the ServiceAccount is in the `anyuid-scc` _ClusterRoleBinding_.

A verification job has been launched to confirm that it is running using the `anyuid` SCC. It accomplishes this task by mounting the Pod annotations to a directory using the [Downward API](https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#the-downward-api).

List all pods in the `manage-scc` Namespace:

```
$ oc get pods -n manage-scc

NAME                            READY   STATUS      RESTARTS   AGE
manage-scc-verifier-job-q46rz   0/1     Completed   0          1m
```

A status of _Completed_ indicates that the job was able to successfully verify that the pod is using the `anyuid` SCC. We can confirm this ourself by viewing the `openshift.io/scc` annotation:

```
$ oc get pods -n manage-scc -o jsonpath='{.items[*].metadata.annotations.openshift\.io\/scc}'
```

In addition, logs from the completed pods can be viewed to confirm that it successfully verified the proper annotation.

```
$ oc logs -n manage-scc $(oc get pods -n manage-scc -o jsonpath='{.items[*].metadata.name}')

Desired SCC: anyuid
Actual SCC: anyuid

Result Success!
```