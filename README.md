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

In earlier versions of OpenShift, the preferred method for granting access to an SCC was to make use of a dedicated Service Account to execute the pod and to add the Service Account Directly to the SCC. This caused challenges as the platform evolved over time. The preferred method is to use Role Based Access Controls (RBAC) to declaratively state that a Service Account is able to access to a particular SCC.

### SCC Management in Action

By applying the resources in prior sections, the following were applied to the cluster: 

* A _Namespace_ called `manage-scc`
* A _ClusterRole_ that provides access to the _anyuid_ SCC
* A _ServiceAccount_ that can be used by Pods requiring access to the _anyuid_ SCC
* A _RoleBinding_ in the `manage-scc` namespace that links the _ServiceAccount_ to the _ClusterRole_
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

The association between the _ClusterRole_ and the ServiceAccount is in the `anyuid-scc` _RoleBinding_.

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

## Patching Resources

In some cases, a cluster administrator might have a need to apply a patch to a resource that already exists or is owned by some other process. Some use cases of this are:

- Labelling the `default`, `kube-system`, or other "out of the box" namespaces
- Labelling nodes not managed by an operator

For these cases, we use the [Resource Locker Operator](https://github.com/redhat-cop/resource-locker-operator#resource-patch-locking) to provide a "declarative patch" that will be kept in place by the operator. Building this solution in a declarative way involves creating the following components:

- A [manifest](/simple-bootstrap/0-namespaces/resource-locker-operator.yaml) for managing a `Namespace` for the Resource Locker Operator
- A [manifest](/simple-bootstrap/1-operators/resource-locker-operator.yaml) for installing the Resource Locker Operator

Then, for each patch we want to manage:

- A [manifest](/simple-bootstrap/2-rbac/namespace-labeller.yaml) defining the `ServiceAccount`, `ClusterRole`, and `RoleBinding` (or `ClusterRoleBinding`) that will perform the patch
- A [manifest](/simple-bootstrap/3-operator-configs/patch-default-namespace-labels.yaml) defining the `ResourceLocker` resource that defines the contents of the patch and the target resource to perform the patch on.

After running this, we can see that our `default` namespace now has two labels on it.

```
$ oc get ns/default -o yaml
apiVersion: v1
kind: Namespace
metadata:
...
  labels:
    name: default
    network.openshift.io/policy-group: ingress
  name: default
...
spec:
  finalizers:
  - kubernetes
status:
  phase: Active

```

## Managing Operators

Operators are a foundational component of the architecture of OpenShift, and the lifecycle of operators are managed by the [Operator Lifeycle Manager (OLM)](https://docs.openshift.com/container-platform/latest/operators/understanding_olm/olm-understanding-olm.html). As illustrated in a portion of the prior examples, an operator managed by the OLM is enabled in one or more namespaces by an [OperatorGroup](https://docs.openshift.com/container-platform/latest/operators/understanding_olm/olm-understanding-olm.html#olm-operatorgroups-about_olm-understanding-olm) and the intention to install an operator is enabled using a [Subscription](https://docs.openshift.com/container-platform/latest/operators/understanding_olm/olm-understanding-olm.html#olm-subscription_olm-understanding-olm). A subscription defines the source of the operator including the namespace, catalog and can contain the specific ClusterServiceVersion that is intended to be installed. The OLM will then create an associated [InstallPlan](https://docs.openshift.com/container-platform/4.5/operators/understanding_olm/olm-understanding-olm.html#olm-installplan_olm-understanding-olm) which includes the set of resources that wil be installed in association with the operator.

To manage how upgrades are handled when a new version becomes available, operators use an [approval strategy](https://docs.openshift.com/container-platform/4.5/operators/olm-adding-operators-to-cluster.html) which can either be _Manual_ or _Automatic_ (Specified by the `installPlanApproval` of a _Subscription_). If _Automatic_ is chosen, an operator will automatically be upgraded to the latest version when a new version is available. When using the _Manual_ approval strategy, an  administrator must manually approve the operator before it is installed. 

While the _automatic_ approval strategy offers the simplicity of being able to take advantage of the latest features that an operator can provide, in many cases there is a desire to explicitly specify the version to use without automatically upgrading, thus using the _manual_ approval strategy. Actions that require the intervention of an administrator to approve an operator for it to be deployed contradicts that declarative nature of GitOps. When an operator using the _manual_ approval strategy is approved, the `approved` field on the _InstallPlan_ is set to `true`. 

To replicate the actions that would typically be required by an administrator to approve an operator, a _Job_ can be used. The `resource-locker-operator` deployed previously uses the _manual_ approval strategy and is approved by a _Job_ called [installplan-approver](simple-bootstrap/3-operator-configs/installplan-approver-job.yaml) which will automatically approve an _InstallPlan_ if the CSV matches the desired CSV defined in the _Subscription_.

Managing the _manual_ approval strategy uses the following resources:

* A set of [policies](simple-bootstrap/2-rbac/installplan-approver.yaml) including a _ServiceAccount_ for which the job will run as, a _Role_ that grants access to _InstallPlans_ and _Subscriptions_ along with a _RoleBinding_ which associates the _Role_ to the _ServiceAccount_.
* The [installplan-approver Job](simple-bootstrap/3-operator-configs/installplan-approver-job.yaml) that approves the operator

Verify the job completed successfully by executing the following command:

```
$ oc get pods -n resource-locker-operator -l=job-name=installplan-approver

NAME                         READY   STATUS      RESTARTS   AGE
installplan-approver-vh9dm   0/1     Completed   0          58m
```

When using a GitOps tool, such as ArgoCD, the following annotations can be applied to automatically delete an existing job (if found) to avoid a possible conflict when applying resources.

```
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```