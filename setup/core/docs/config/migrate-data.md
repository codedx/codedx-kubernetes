# Migrate Code Dx Data to Kubernetes

Here are the steps to migrate your Code Dx data from a system created by the Code Dx Installer to a Code Dx deployment running on Kubernetes (without an external database).

The Code Dx version you are running on Kubernetes must be equal to or greater than your non-Kubernetes Code Dx system. If necessary, upgrade your Code Dx version before migrating your Code Dx data.

1) Log on to your Code Dx server

2) Run mysqldump to create a backup file. You can run the following command to create a dump-codedx.sql file after specifying the parameters that work for your database.

```
mysqldump --host=127.0.0.1 --port=3306 --user=root -p codedx > dump-codedx.sql
```

>Note: The above command uses a database named codedx. Older versions of Code Dx may use a database named bitnami_codedx.

3) Locate the directory path for your Code Dx AppData directory (e.g., /path/to/codedx_data/codedx_appdata). The AppData directory contains your analysis-files and log-files directories.

4) Clone this repository on your system by running the following command from the directory where you want to store the codedx-kubernetes files:

```
git clone https://github.com/codedx/codedx-kubernetes.git -b feature/guide
```

5) Run the migrate-data.ps1 script in the codedx-kubernetes/admin directory. When prompted, enter the path to your dump-codedx.sql file, your Code Dx AppData directory, and specify the password for the root database user.

```
cd codedx-kubernetes/admin
pwsh ./migrate-data.ps1
```

Code Dx will be ready with the migrated data once the migrate-data.ps1 script finishes.
