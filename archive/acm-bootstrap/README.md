# ACM Architecture
For more information regarding ACM use and Architecture please refer to [About ACM](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.0/html/about/welcome-to-red-hat-advanced-cluster-management-for-kubernetes#multicluster-architecture)

# Installing the ACM operator with the Operator Lifecycle Manager

This directory contains the manifests required to install the [ACM Operator](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.0/html/install/installing#installing-while-connected-online).


## 1 Bootstrapping the ACM Operator

The ACM bootstrapping example shows how cluster administrators might begin deploying the ACM operator using `oc apply`. Each resource in this example carries a common label (`config.example.com/name: acm-bootstrap`) that associates it with this `project`. In doing this, we can manage the full lifecycle of our resources with a single command.

```
oc apply -Rf ../acm-bootstrap/ --prune -l config.example.com/name=acm-bootstrap
```

The `apply` command idempotently ensures that the live configuration is in sync with our configuration files, while the `--prune` flag allows us to also manage the deletion of live objects by simply deleting the associated file in this repository.


ACM is now deployed by the ACM operator along with the MultiCluster Hub, you can now generate an import command to bring in Clusters for management in ACM.

[Importing Clusters](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.0/html/manage_cluster/importing-a-target-managed-cluster-to-the-hub-cluster#importing-a-cluster)

To begin creating ACM Policies take a look at the follow repo for more examples.
 [ACM-Policies](https://github.com/redhat-cop/acm-policies.git )

## 2 Accessing the ACM Console

To access the ACM Console you must obtain the route created using;
```
oc get route -n open-cluster-management
```

example
```
 oc get route  -o=jsonpath='{.items[*].spec.host }{"\n"}' -n open-cluster-management
 ```



