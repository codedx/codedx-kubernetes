# Code Dx Kubernetes Backup & Restore Procedure

You can configure your Code Dx backup using the Guided Setup. If you already ran the Guided Setup without specifying a backup configuration, you can configure your backup by appending the following [script parameters](https://github.com/codedx/codedx-kubernetes/tree/master/setup/core) to your setup.ps1 command: backupType, namespaceVelero, backupScheduleCronExpression, backupDatabaseTimeoutMinutes, and backupTimeToLiveHours.

Code Dx depends on [Velero](https://velero.io) for cluster state and volume data backups. When not using an external Code Dx database, you must deploy Code Dx with at least one MariaDB subordinate database so that a database backup occurs before Velero runs a backup.

> Note: The Code Dx Kubernetes Backup & Restore Procedure has been tested with Velero versions 1.3, 1.4, and 1.5.

If you are using an external Code Dx database, your database will not be included in the Velero-based backup. You must create a database backup schedule on your own. To minimize data loss, schedule your database backups to coincide with your Code Dx backups to help align your Kubernetes volume and database data after a restore.

> Note: The overall backup process is not an atomic operation, so it's possible to capture inconsistent state in a backup. For example, the Code Dx AppData volume backup could include a file that was unknown at the time the database backup occurred. The likelihood of capturing inconsistent state is a function of multiple factors to include system activity and the duration of backup operations.

## About Velero

Velero can back up both k8s state stored in etcd and k8s volume data. Volume data gets backed up using either [storage provider plugins](https://velero.io/docs/v1.5/supported-providers/) or Velero's integration with [Restic](https://restic.net/). Refer to [How Velero Works](https://velero.io/docs/v1.5/how-velero-works/) and [Restic Integration](https://velero.io/docs/v1.5/restic/) for more details.

> Note: Use Velero's Restic integration when a storage provider plugin is unavailable for your environment.

## Installing Velero

Install the [Velero CLI](https://velero.io/docs/v1.5/basic-install/#install-the-cli) and then follow the Velero installation documentation for your scenario. You can find links to provider-specific documentation in the Setup Instructions column on the [Providers](https://velero.io/docs/v1.5/supported-providers/) page, which includes  links to the [Azure](https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure#setup) and [AWS](https://github.com/vmware-tanzu/velero-plugin-for-aws#setup) instructions. If you're not using a storage provider plugin, [enable Velero's Restic integration](https://velero.io/docs/v1.5/customize-installation/#enable-restic-integration) at install time.

> Note: If your Velero backup unexpectedly fails, you may need to increase the amount of memory available to the Velero pod. Use the --velero-pod-mem-limit parameter with the velero install command as described [here](https://velero.io/docs/v1.5/customize-installation/#customize-resource-requests-and-limits).

## Verify Backup

Once backups start running, use the velero commands that [describe backups and fetch logs](https://velero.io/docs/v1.5/troubleshooting/#general-troubleshooting-information) to confirm that the backups are completing successfully and that they include the following volumes:

- codedx-appdata (Code Dx web application)
- backup (Code Dx MariaDB Slave databases - when not using an external Code Dx database)
- data (MinIO - when using Code Dx Tool Orchestration)

When using Velero with Storage Provider Plugins, the volume snapshots initiated by a plugin may finish after the Backup resource reports a completed status. Wait for the volume snapshot process to finish before starting a restore.

If applicable, you should also confirm that the database backup script runs correctly and produces database backups with each Velero backup in the /bitnami/mariadb/backup/data directory. Use the following command after replacing placeholder parameters to list recent backups for a MariaDB slave database instance:

```
$ kubectl -n code-dx-namespace-placeholder exec codedx-mariadb-slave-pod-placeholder -- ls /bitnami/mariadb/backup/data
```

> Note: Older backup files get removed from the database volume when backups complete.

You can use this command to view the backup log on a MariaDB slave database instance.

```
$ kubectl -n code-dx-namespace-placeholder exec codedx-mariadb-slave-pod-placeholder -- cat /bitnami/mariadb/backup/data/backup.log
```

The backup.log file should have a "completed OK!" message above the log entries indicating that old backups are getting removed.

> Note: To confirm that a backup includes the volume holding your Code Dx database backup, test a backup by running a restore.

## Restoring Code Dx

While the Guided Setup can generate a Velero Schedule resource for use with a GitOps-based deployment, restoring a Code Dx backup currently requires running ad-hoc commands on your cluster.

Velero will skip restoring resources that already exist, so delete those you want to restore from a backup. You can delete the Code Dx namespace(s) to remove all namespaced resources, and you can delete cluster scoped Code Dx resources to remove Code Dx entirely. Since Code Dx depends on multiple PersistentVolume (PV) resources, you will typically want to delete Code Dx PVs when restoring Code Dx to a previous known good state.

There are two steps required to restore Code Dx from a Velero backup. The first step is to use the velero CLI to restore a specific backup. For the second step, you will run the restore-db.ps1 script to restore a local Code Dx database. If you're using an external database, you will skip the second step by restoring your Code Dx database on your own.

>Note: When using Velero with Storage Provider Plugins, wait for the volume snapshot process to finish before restoring a backup.

### Step 1: Restore Cluster State and Volume Data

During Step 1, you will use Velero to restore cluster and volume state from an existing backup. You can see a list of available backups by running the following command:

```
$ velero get backup
```

Assuming you want to restore a backup named 'my-backup', run the following command to install the PriorityClass resources from that backup:

```
$ velero restore create --from-backup my-backup --include-resources=PriorityClass
```

Wait for the restore started by the previous command to finish. You can use the describe command it prints to check progress.

A restore may finish with warnings and errors indicating that one or more resources could not be restored. Velero will not delete resources during a restore, so you may see warnings about Velero failing to create resources that already exist. Review any warnings and errors displayed by Velero's describe and log commands to determine whether they can be ignored.

> Note: You can use Velero's log command to view the details of a restore after it completes.

After waiting for the restore operation to finish, run the following command to restore the remaining resources from your backup:

```
$ velero restore create --from-backup my-backup
```

> Note: Running two velero commands works around an issue discovered in Velero v1.3.2 that blocks the restoration of Code Dx pods. If you run only the second command, Code Dx priority classes get restored, but pods depending on those classes do not.

When using Velero with storage provider plugins, your Code Dx and MariaDB pods may not return to a running state. Step 2 will resolve that issue.

> Note: Code Dx is not ready for use at the end of Step 1.

### Step 2: Restore Code Dx Database

During Step 2, you will run the admin/restore-db.ps1 script to restore the Code Dx database from a backup residing on the volume data you restored. If you are using an external Code Dx database, restore your external database to a time that coincides with your Code Dx backup and skip this section.

At this point, you can find the database backup corresponding to the backup you want to restore. Refer to the Verify Backup section for the command to list backup files on a MariaDB slave database instance. Note the name of the database backup that coincides with the Velero backup you restored (e.g., '20200523-020200-Full'). You will enter this name when prompted by the restore-db.ps1 script.

Start a new PowerShell Core 7 session and change directory to where you downloaded the setup scripts from the [codedx-kubernetes](https://github.com/codedx/codedx-kubernetes).

```
/$ pwsh
PS /> cd ~/git/codedx-kubernetes/admin
```

Start the restore-db.ps1 script by running the following command after replacing parameter placeholders:

```
PS /git/codedx-kubernetes/admin> ./restore-db.ps1 `
        -namespaceCodeDx 'code-dx-namespace-placeholder' `
        -releaseNameCodeDx 'code-dx-helm-release-name-placeholder'
```

> Note: You can pull the Code Dx Restore Database Docker image from an alternate Docker registry using the -imageDatabaseRestore parameter and from a private Docker registry by adding the -dockerImagePullSecretName parameter.

When prompted by the script, enter the name of the database backup you want to restore and the passwords for the MariaDB database root and replicator users. The script will search for the database backup, copy it to a folder in your profile, and use the backup to restore both master and slave database(s). It will then restart database replication, and it will manage the running instances of MariaDB and Code Dx, so when the script is finished, all Code Dx pods will be online. Depending on your ingress type and what was restored, you may need to update your DNS configuration before using the new Code Dx instance.

> Note: The restore-db.ps1 script requires that your work directory (default is your profile directory) not already include a folder named backup-files. The script will stop if it finds that directory, so delete it before starting the script.

## Uninstalling

If you need to uninstall the backup configuration and Velero, do the following:

- Remove the Velero Schedule resource for your Code Dx instance and related Backup and Restore resources (you can remove *all* Velero backup and restore objects by running `velero backup delete --all` and `velero restore delete --all`)
- [Uninstall Velero](https://velero.io/docs/v1.5/uninstalling/)
