
## Patching Nodes (UPI)

During a UPI (user provisioned infrastructure) install of OpenShift it could be appropriate to [label](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#step-one-attach-label-to-the-node) or [taint](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) a node according to expected workloads in a declarative manner.  

Since this is not natively supported by OpenShift [yet](https://github.com/openshift/machine-config-operator/pull/845), we'll use the [Resource Locker Operator](https://github.com/redhat-cop/resource-locker-operator#resource-patch-locking) to provide a "declarative patch" that will be kept in place by the operator. 

Example patches are provided below:

Prerequisite:
- A [manifest](rlo-node-rbac.yaml) defining the `ServiceAccount`, `ClusterRole`, and `RoleBinding` (or `ClusterRoleBinding`) with the appropriate permissions that will perform the patch

Patch Manifests:
- A [node label patch](rlo-node-label.yaml) defining the `ResourceLocker` manifest to enforce the label
- A [node label taint](rlo-node-taint.yaml) defining the `ResourceLocker` manifest to enforce the taint

After running this, we can see that our targeted node now has a label and taint on it.
```      
metadata:
  labels:
    workload: production
...
spec:
...
  taints:
    - effect: NoSchedule
      key: redhatcop.redhat.io/productionworkload
...
```