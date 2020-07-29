# Code Dx Kubernetes Backup & Restore Procedure

This document describes how to configure backups so that you can return Code Dx to a previous state when necessary.

## Approach

Code Dx depends on [Velero](https://velero.io) for cluster state and volume data backups. When not using an external Code Dx database, you must deploy Code Dx with at least one MariaDB subordinate database that will get backed up when Velero creates a backup.

> Note: The Code Dx Kubernetes Backup & Restore Procedure has been tested with Velero versions 1.3 and 1.4.

If you are using an external Code Dx database, your database will not be included in the Velero-based backup. You must create a database backup schedule on your own. To minimize data loss, schedule your database backups for a time that matches your Code Dx backup to help align your Kubernetes volume and external database data after a restore.

Code Dx gets restored with either a two-step or a three-step process depending on whether you're using Velero's Restic integration. You first use Velero to restore cluster state and volume data for the Code Dx AppData directory, MariaDB database backups (when not using an external database), and MinIO (when using Code Dx Tool Orchestration). When not using Velero's Restic integration, you restart the MariaDB master and slave database instances to provision new MariaDB PVC and PV resources. Finally, you run the Code Dx admin/restore-db.ps1 script to restore the MariaDB master and slave databases (when not using an external database).

> Note: The overall backup process is not an atomic operation, so it's possible to capture inconsistent state in a backup. For example, the Code Dx AppData volume backup could include a file that was unknown at the time the database backup occurred. The likelihood of capturing inconsistent state is a function of multiple factors to include system activity and the duration of backup operations.

## About Velero

Velero can back up both k8s state stored in etcd and k8s volume data. Volume data gets backed up using either [storage provider plugins](https://velero.io/docs/v1.4/supported-providers/) or Velero's integration with [Restic](https://restic.net/). Refer to [How Velero Works](https://velero.io/docs/v1.4/how-velero-works/) and [Restic Integration](https://velero.io/docs/v1.4/restic/) for more details.

> Note: Use Velero's Restic integration when a storage provider plugin is unavailable for your environment.

## Installing Velero

Install the [Velero CLI](https://velero.io/docs/v1.4/basic-install/#install-the-cli) and then follow the Velero installation documentation for your scenario. You can find links to provider-specific documentation in the Setup Instructions column on the [Providers](https://velero.io/docs/v1.4/supported-providers/) page, which includes  links to the [Azure](https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure#setup) and [AWS](https://github.com/vmware-tanzu/velero-plugin-for-aws#setup) instructions. If you're not using a storage provider plugin, [enable Velero's Restic integration](https://velero.io/docs/v1.4/customize-installation/#enable-restic-integration) at install time.

> Note: If your Velero backup unexpectedly fails, you may need to increase the amount of memory available to the Velero pod. Use the --velero-pod-mem-limit parameter with the velero install command as described [here](https://velero.io/docs/v1.4/customize-installation/#customize-resource-requests-and-limits).

## Applying Backup Configuration

This section explains how to add Velero-specific configuration to previously installed Code Dx software running on k8s. Since Code Dx can run with or without the Code Dx Tool Orchestration feature, and Velero can run with or without Restic, this section covers all of those cases.

While the Code Dx deployment includes a database backup script, it does not apply Velero-specific configuration, nor does it set up a backup schedule. You will accomplish both tasks by running the admin/set-backup.ps1 script.

Start a new PowerShell Core 7 session and change directory to where you downloaded the setup scripts from the [codedx-kubernetes](https://github.com/codedx/codedx-kubernetes).

```
/$ pwsh
PS /> cd ~/git/codedx-kubernetes/admin
```

The set-backup.ps1 admin script applies the required Velero backup configuration. There are four supported scenarios described in the next four sections, so follow the one that matches your deployment.

IMPORTANT NOTE: If you are using an external Code Dx database, append the `-skipDatabaseBackup` parameter to each usage of set-backup.ps1.

> Note: Running set-backup.ps1 will start a scheduled backup if the schedule has not previously run.

### Code Dx with Tool Orchestration (Velero Storage Provider Plugins)

If you're using storage provider plugins with Velero and using Code Dx Tool Orchestration, run the following command after replacing parameter placeholders:

```
PS /git/codedx-kubernetes/admin> ./set-backup.ps1 `
        -namespaceCodeDx 'code-dx-namespace-placeholder' `
        -releaseNameCodeDx 'code-dx-helm-release-name-placeholder' `
        -namespaceCodeDxToolOrchestration 'code-dx-orchestration-namespace-placeholder' `
        -releaseNameCodeDxToolOrchestration 'code-dx-orchestration-helm-release-name-placeholder'
```

> Note: By default, the backup will occur daily at 3 AM (UTC). To change the schedule, use the -scheduleCronExpression parameter to specify your own cron expression. If you need to change the backup schedule, rerun set-backup.ps1 and specify a different value for -scheduleCronExpression.

### Code Dx without Tool Orchestration (Velero Storage Provider Plugins)

If you're using storage provider plugins with Velero and are not using Code Dx Tool Orchestration, run the following command after replacing parameter placeholders:

```
PS >/ ./set-backup.ps1 `
        -namespaceCodeDx 'code-dx-namespace-placeholder' `
        -releaseNameCodeDx 'code-dx-helm-release-name-placeholder' `
        -skipToolOrchestration
```

> Note: By default, the backup will occur daily at 3 AM (UTC). To change the schedule, use the -scheduleCronExpression parameter to specify your own cron expression. If you need to change the backup schedule, rerun set-backup.ps1 and specify a different value for -scheduleCronExpression.

### Code Dx with Tool Orchestration (Velero Restic Integration)

If you're using Velero's Restic integration and you are using Code Dx Tool Orchestration, run the following command after replacing parameter placeholders:

```
PS >/ ./set-backup.ps1 `
        -namespaceCodeDx 'code-dx-namespace-placeholder' `
        -releaseNameCodeDx 'code-dx-helm-release-name-placeholder' `
        -namespaceCodeDxToolOrchestration 'code-dx-orchestration-namespace-placeholder' `
        -releaseNameCodeDxToolOrchestration 'code-dx-orchestration-helm-release-name-placeholder' `
        -useVeleroResticIntegration
```

> Note: By default, the backup will occur daily at 3 AM (UTC). To change the schedule, use the -scheduleCronExpression parameter to specify your own cron expression. If you need to change the backup schedule, rerun set-backup.ps1 and specify a different value for -scheduleCronExpression.

### Code Dx without Tool Orchestration (Velero Restic Integration)

If you're using Velero's Restic integration and you are not using Code Dx Tool Orchestration, run the following command after replacing parameter placeholders:

```
PS >/ ./set-backup.ps1 `
        -namespaceCodeDx 'code-dx-namespace-placeholder' `
        -releaseNameCodeDx 'code-dx-helm-release-name-placeholder' `
        -skipToolOrchestration `
        -useVeleroResticIntegration
```

> Note: By default, the backup will occur daily at 3 AM (UTC). To change the schedule, use the -scheduleCronExpression parameter to specify your own cron expression. If you need to change the backup schedule, rerun set-backup.ps1 and specify a different value for -scheduleCronExpression.

### Set-Backup.ps1 Parameters

Refer to the following table for a description of the set-backup.ps1 script parameters.

| Parameter                          | Description                                    | Default                   |
|------------------------------------|------------------------------------------------|---------------------------|
| namespaceCodeDx                    | Code Dx namespace                              | cdx-app                   |
| releaseNameCodeDx                  | Code Dx Helm release name                      | codedx                    |
|                                    |                                                |                           |
| namespaceCodeDxToolOrchestration   | Tool Orchestration namespace                   | cdx-svc                   |
| releaseNameCodeDxToolOrchestration | Tool Orchestration Helm release name           | codedx-tool-orchestration |
|                                    |                                                |                           |
| scheduleCronExpression             | Backup schedule expression                     | 0 3 * * *                 |
| databaseBackupTimeout              | Allowable database backup time                 | 30m                       |
| databaseBackupTimeToLive           | Duration of Velero backups                     | 720h0m0s                  |
|                                    |                                                |                           |
| useVeleroResticIntegration         | Whether using Velero Restic integration        | $false                    |
|                                    |                                                |                           |
| skipDatabaseBackup                 | Whether to skip a database backup              | $false                    |
| skipToolOrchestration              | Whether to skip a Tool Orchestration backup    | $false                    |
|                                    |                                                |                           |
| workDirectory                      | Directory for creating working files           | ~                         |
| namespaceVelero                    | Velero namespace                               | velero                    |
|                                    |                                                |                           |
| delete                             | Whether to delete backup config                | $false                    |

## Verify Backup

Once backups start running, use the velero commands that [describe backups and fetch logs](https://velero.io/docs/v1.4/troubleshooting/#general-troubleshooting-information) to confirm that the backups are completing successfully and that they include the following volumes:

- codedx-appdata (Code Dx web application)
- backup (Code Dx MariaDB Slave databases - when not using an external Code Dx database)
- data (MinIO - when using Code Dx Tool Orchestration)

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

The steps for restoring a Code Dx instance from a backup appear below. Depending on how you have Velero configured, you will need to accomplish 2-3 steps.

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

IMPORTANT NOTE: When using Velero with storage provider plugins, when the restore is complete, you should reapply the backup configuration (see the Applying Backup Configuration section) to avoid storing unnecessary volume snapshots for the data volumes of the MariaDB master and slave databases.

### Step 2: Restart MariaDB

Step 2 is required when using Velero with storage provider plugins. Skip this section if you are using Velero's Restic integration or if you are using an external Code Dx database.

During Step 2, you will start the process of bringing Code Dx and the MariaDB databases online. Initially, volume data excluded from the backup will cause MariaDB database pods to get stuck in the Pending state. This step will result in new PVCs and PVs for the data volumes.

Start a new PowerShell Core 7 session and change directory to where you downloaded the setup scripts from the [codedx-kubernetes](https://github.com/codedx/codedx-kubernetes).

```
/$ pwsh
PS /> cd ~/git/codedx-kubernetes/admin
```

Restart the MariaDB databases by running the restart-db.ps1 script:

```
PS /git/codedx-kubernetes/admin> ./restart-db.ps1
```

> Note: At the conclusion of Step 2, Code Dx and the MariaDB databases will be in a running state, but you must finish Step 3 before using the Code Dx application.

### Step 3: Restore Code Dx Database

During Step 3, you will run the admin/restore-db.ps1 script to restore the Code Dx database from a backup residing on the volume data you restored. If you are using an external Code Dx database, restore your external database at this time and skip this section.

Before continuing, make sure that all Velero restore operations have finished and that the Code Dx pods are in a ready state.

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

When prompted by the script, enter the name of the database backup you want to restore and the password for the MariaDB database root user. The script will search for the database backup, copy it to a folder in your profile, and use the backup to restore both master and slave database(s). It will then restart database replication, and it will manage the running instances of MariaDB and Code Dx, so when the script is finished, you can start using the restored Code Dx instance.

> Note: The restore-db.ps1 script requires that your work directory (default is your profile directory) not already include a folder named backup-files. The script will stop if it finds that directory, so delete it before starting the script.

## Removing Backup Configuration

You can remove the backup configuration you applied to Code Dx k8s resources by rerunning the command you ran in the Apply Backup Configuration section with the additional -delete parameter. For example, if you applied a backup configuration suitable for Code Dx running with Tool Orchestration and are using Velero's Restic integration, run the following command to undo that configuration (replacing parameter placeholders):

```
PS >/ ./set-backup.ps1 `
        -namespaceCodeDx 'code-dx-namespace-placeholder' `
        -releaseNameCodeDx 'code-dx-helm-release-name-placeholder' `
        -namespaceCodeDxToolOrchestration 'code-dx-orchestration-namespace-placeholder' `
        -releaseNameCodeDxToolOrchestration 'code-dx-orchestration-helm-release-name-placeholder' `
        -useVeleroResticIntegration `
        -delete
```

>Note: Remember to append `-skipDatabaseBackup` to your set-backup.ps1 usage when using an external Code Dx database.

## Uninstalling

If you need to uninstall the backup capability, do the following:

- Remove the backup configuration you applied to Code Dx k8s resources (see the Removing Backup Configuration section)
- Remove Velero backup and restore objects with `velero backup delete --all` and `velero restore delete --all`
- [Uninstall Velero](https://velero.io/docs/v1.4/uninstalling/)
