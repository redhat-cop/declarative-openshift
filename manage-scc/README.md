# Management of Security Context Constraints

This directory contains manifests required in order to enable an application to make use of a platform provided [Security Context Constraint (SCC)](https://docs.openshift.com/container-platform/4.4/authentication/managing-security-context-constraints.html).

## Overview

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

## Executing the example

The following demonstrates the resources necessary for granting a Pod access to a particular SCC by creating the following resources: 

* A _Namespace_ for the contents of this example
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

### 1. Apply the Resources to the Cluster

With an understanding of the resources associated with this example, use the `oc apply` command to add the resources to the cluster.

```
$ oc apply -Rf . --prune -l config.example.com/name=manage-scc

namespace/manage-scc created
clusterrole.rbac.authorization.k8s.io/allow-anyuid-scc created
clusterrolebinding.rbac.authorization.k8s.io/anyuid-scc created
job.batch/manage-scc-verifier-job created
serviceaccount/scc-accessor created
```

The verification job will be launched to confirm that it is running using the `anyuid` SCC. It accomplishes this task by mounting the Pod annotations to a directory using the [Downward API](https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#the-downward-api).

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

## 2. Cleanup

To remove the resources created during this exercise, execute the following command:

```
$ oc delete -Rf . -l config.example.com/name=manage-scc

namespace "manage-scc" deleted
clusterrole.rbac.authorization.k8s.io "allow-anyuid-scc" deleted
clusterrolebinding.rbac.authorization.k8s.io "anyuid-scc" deleted
job.batch "manage-scc-verifier-job" deleted
serviceaccount "scc-accessor" deleted
```