# Expand Code Dx Volume(s)

Here are the steps to expand the volume storage for Code Dx volumes. 

These steps assume that you are using a [storage class configured for volume expansion](https://kubernetes.io/docs/concepts/storage/storage-classes/#allow-volume-expansion).

These steps also assume that you deployed Code Dx using default Kubernetes (K8s) namespaces and Helm release names. 

If you changed the default values, substitute your namespace and resource names as required. If you are using an external database, ignore related commands.

1) Set the Code Dx replica count to 0.

```
kubectl -n cdx-app scale --replicas=0 deployment/codedx
```

2) Delete the MariaDB statefulset resources (do *not* delete the related PVC resources). If you are using an external database, you can ignore this step.

```
kubectl -n cdx-app delete statefulset/codedx-mariadb-master
kubectl -n cdx-app delete statefulset/codedx-mariadb-slave
```

3) Manually edit the MariaDB PVCs by specifying the new storage size for spec.resources.requests.storage. If you are using an external database, you can ignore this step.

```
kubectl -n cdx-app edit pvc data-codedx-mariadb-master-0
kubectl -n cdx-app edit pvc data-codedx-mariadb-slave-0
kubectl -n cdx-app edit pvc backup-codedx-mariadb-slave-0
```

>Note: Afterward, the PVC YAML status field will show a pending resize.

4) Edit your run-setup.ps1 script by updating the volume-related Code Dx deployment script parameters (those with a `VolumeSizeGiB` suffix). The volume size script parameters must match any edits you applied in the previous step.

5) Rerun run-setup.ps1 to expand your expandable volumes.

>Note: If you see an error message, you may not be using [expandable volumes](https://kubernetes.io/docs/concepts/storage/storage-classes/#allow-volume-expansion).
