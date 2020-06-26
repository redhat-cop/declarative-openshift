# Declarative OpenShift

## 1 Bootstrapping logging onto a cluster 

The logging bootstrapping example shows how cluster administrators might begin deploying an EFK stack onto an OpenShift cluster using just `oc apply`. Each resource in this example carries a common label (`example.com/project: logging-bootstrap`) that associates it with this `project`. In doing this, we can manage the full lifecycle of our resources with a single command.

```
oc apply -Rf ../logging-bootstrap/ --prune -l example.com/project=logging-bootstrap
```

The `apply` command idempotently ensures that the live configuration is in sync with our configuration files, while the `--prune` flag allows us to also manage the deletion of live objects by simply deleting the associated file in this repository.

As an example, let's bootstrap logging onto our cluster for the first time:

```
$ oc apply -Rf ../logging-bootstrap/ --prune -l example.com/project=logging-bootstrap
##TODO add output
Note that the creation of the clusterlogging object may fail. This is because its CRD did not exist quite yet. If you rerun the command, then it should succeed
```

##Phase one stops here (note this was a 4.2 install)

##TODO Try deploying 4.4 operator with base install with new tech-preview CR's
