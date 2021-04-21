# Migrate Code Dx Data to Kubernetes

Here are the steps to migrate your Code Dx data from a system created by the Code Dx Installer to a Code Dx deployment running on Kubernetes (without an external database).

>Note: If your Code Dx Kubernetes deployment uses an external database (one that you maintain on your own that is not installed or updated by the Code Dx Kubernetes deployment script), follow the [Migrate Code Dx Data to Kubernetes (External Database)](migrate-data-external-db.md) instructions instead.

If you have not yet installed Code Dx on Kubernetes, run the [Guided Setup](https://github.com/codedx/codedx-kubernetes#deploy-code-dx-on-kubernetes) and the Code Dx deployment script at this time.

The Code Dx version you are running on Kubernetes must be equal to or greater than your non-Kubernetes Code Dx system. If necessary, upgrade your Code Dx version before migrating your Code Dx data.

>Note: You must have adequate disk and memory resources before starting a data migration with a large Code Dx dataset.

The data migration steps below assume that you are migrating data to a new instance of Code Dx running on Kubernetes. If you installed the Tool Orchestration feature and ran an orchestrated analysis, you should re-install Code Dx after manually deleting the Tool Orchestration Helm release and k8s namespace. Doing so will avoid potential conflicts with restored Code Dx data and data in Tool Orchestration storage (i.e., MinIO). If your deployment uses the default release and namespace names, run `helm -n cdx-svc delete codedx-tool-orchestration` and `kubectl delete ns cdx-svc` to uninstall Tool Orchestration components before re-running your saved setup.ps1 command line.

1) Log on to your Code Dx server (non-k8s instance).

2) Run mysqldump to create a backup file. You can run the following command to create a dump-codedx.sql file after specifying the parameters that work for your database.

```
mysqldump --host=127.0.0.1 --port=3306 --user=root -p codedx > dump-codedx.sql
```

>Note: The above command uses a database named codedx. Older versions of Code Dx may use a database named bitnami_codedx.

3) Locate the directory path for your Code Dx AppData directory (e.g., /path/to/codedx_data/codedx_appdata). The AppData directory contains your analysis-files and log-files directories.

4) Clone this repository on your system by running the following command from the directory where you want to store the codedx-kubernetes files:

```
git clone https://github.com/codedx/codedx-kubernetes.git
```

5) Run the migrate-data.ps1 script in the codedx-kubernetes/admin directory. When prompted, enter the path to your dump-codedx.sql file, your Code Dx AppData directory, and specify the passwords for the root and replicator database users (the passwords you specified when running the Guided Setup).

```
cd codedx-kubernetes/admin
pwsh ./migrate-data.ps1
```

Code Dx will be ready with the migrated data once the migrate-data.ps1 script finishes.
