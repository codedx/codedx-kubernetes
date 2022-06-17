# Expand Code Dx Volume(s)

Here are the steps to expand the volume storage for Code Dx volumes. 

These steps assume that you are using a [storage class configured for volume expansion](https://kubernetes.io/docs/concepts/storage/storage-classes/#allow-volume-expansion).

These steps also assume that you deployed Code Dx using default Kubernetes (K8s) namespaces and Helm release names. 

If you changed the default values, substitute your namespace and resource names as required. If you are using an external database or you did not install Tool Orchestration, ignore related commands. 

1) Run the Code Dx database backup script. If you are using an external database, you can ignore this step. 

>Note: If you are using the internal Code Dx database, but you do not deploy a database replica, rerun your deployment script with this command parameter: `-dbSlaveReplicaCount 1`

```
kubectl -n cdx-app exec -it codedx-mariadb-slave-0 -- sh /bitnami/mariadb/scripts/backup.sh
```

Before continuing, verify that you see "completed OK message" in the backup output. Note the backup name (e.g., 20220616-162928-Full), which you will reference in subsequent steps.

2) Create a new local directory to store the database backup you created, replace backup-name with the name of your backup (e.g., 20220616-162928-Full). If you are using an external database, you can ignore this step.

```
cd /path/to/my/working/directory
mkdir db-backup
cd db-backup
kubectl -n cdx-app cp codedx-mariadb-slave-0:/bitnami/mariadb/backup/data/backup-name .
```

Verify that you see output similar to what's below in your db-backup directory:

```
Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----           6/17/2022    10:56                codedx
d----           6/17/2022    10:56                mysql
d----           6/17/2022    10:56                performance_schema
d----           6/17/2022    10:56                test
-a---           6/17/2022    10:56             52 aria_log_control
-a---           6/17/2022    10:56          16384 aria_log.00000001
-a---           6/17/2022    10:56            324 backup-my.cnf
-a---           6/17/2022    10:56              0 done
-a---           6/17/2022    10:56            976 ib_buffer_pool
-a---           6/17/2022    10:56           2560 ib_logfile0
-a---           6/17/2022    10:56       79691776 ibdata1
-a---           6/17/2022    10:56           1311 mysql-bin.000001
-a---           6/17/2022    10:56       63044202 mysql-bin.000002
-a---           6/17/2022    10:56            417 mysql-bin.000003
-a---           6/17/2022    10:56             85 xtrabackup_binlog_info
-a---           6/17/2022    10:56             79 xtrabackup_checkpoints
-a---           6/17/2022    10:56            681 xtrabackup_info
```

3) Set the Code Dx replica count to 0.

```
kubectl -n cdx-app scale --replicas=0 deployment/codedx
```

4) With the database backup copied to your local system, manually delete the MariaDB K8s resources. If you are using an external database, you can ignore this step.

```
kubectl -n cdx-app delete statefulset/codedx-mariadb-master
kubectl -n cdx-app delete statefulset/codedx-mariadb-slave
kubectl -n cdx-app delete pvc/data-codedx-mariadb-master-0
kubectl -n cdx-app delete pvc/data-codedx-mariadb-slave-0
kubectl -n cdx-app delete pvc/backup-codedx-mariadb-slave-0
```

5) Confirm the removal of all three MariaDB K8s Persistent Volumes (PV) by reviewing the output of the existing PVs. If you are using an external database, you can ignore this step.

```
kubectl get pv
```

>Note: It may take some time for the MariaDB volumes to disappear. Do not proceed if they still show in the above command's output.

6) Edit your run-setup.ps1 script by updating the volume-related Code Dx deployment script parameters (those with a `VolumeSizeGiB` suffix).

7) Rerun run-setup.ps1 to expand your expandable volumes.

>Note: If you see an error message, you may not be using [expandable volumes](https://kubernetes.io/docs/concepts/storage/storage-classes/#allow-volume-expansion).

8) If you are using an external database, Code Dx will work at this point. Otherwise, run the Code Dx Database Restore script specifying the path to your db-backup folder from Step 2 for the `-backupToRestore` parameter. The script will ask for the MariaDB root and replication database passwords.

```
cd /path/to/codedx-kubernetes/admin
pwsh ./restore-db.ps1 -backupToRestore /path/to/my/working/directory/db-backup
```

>Note: If you changed the default K8s namespaces and Helm release names, append values for the `-namespaceCodeDx` and `-releaseNameCodeDx` script parameters.

9) If you added a replica database by rerunning your run-setup.ps1 script with `-dbSlaveReplicaCount 1`, you can now rerun your run-setup.ps1 script after removing `-dbSlaveReplicaCount 1`.
