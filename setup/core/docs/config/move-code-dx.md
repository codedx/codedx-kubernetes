# Move Code Dx

Here are the steps to move your K8s Code Dx deployment:

## Deploy New Code Dx

1) Deploy a brand-new instance of Code Dx, matching version numbers between the source and new destination deployments.

2) Before continuing, make a request to `/codedx/x/system-status` and confirm a ready state:

```
$ curl https://<hostname>/codedx/x/system-status
{"isReady":true,"isAlive":true,"state":"ready"}
```

>Note: Double-check that you have installed the same Code Dx version as your source deployment, and do not use the new Code Dx deployment until you complete the data migration.

## Copy Code Dx Web Files Locally

1) Scale down your source Code Dx instance, replacing the `cdx-src` namespace and `codedx-src-codedx` deployment name as necessary:

```
$ kubectl -n cdx-src scale --replicas=0 deployment/codedx-src-codedx
```

2) Open a terminal and change to a directory where you can store files created during the migration process; let's call this your work directory.

```
$ cd /path/to/work/directory
```

3) Save the following content to a file named host-code-dx-appdata-volume.yaml, replacing the `cdx-src` namespace, `codedx/codedx-tomcat:v2023.4.8` Docker image name, and `codedx-src-appdata` volume name as necessary:

```
apiVersion: v1
kind: Pod
metadata:
  name: host-code-dx-appdata-volume
  namespace: cdx-src
spec:
  containers:
    - image: codedx/codedx-tomcat:v2023.4.8
      name: host-code-dx-appdata-volume
      command: ["sleep", "1d"]
      volumeMounts:
      - mountPath: "/var/cdx"
        name: volume
  securityContext:
    fsGroup: 1000
    runAsGroup: 1000
    runAsUser: 1000
  volumes:
    - name: volume
      persistentVolumeClaim:
        claimName: codedx-src-appdata
```

4) Run the following command to start the host-code-dx-appdata-volume pod, and wait for it to reach a ready state:

```
$ kubectl apply -f /path/to/work/directory/host-code-dx-appdata-volume.yaml
```

5) Run the following commands to copy the analysis-files directory (if it exists), replacing the `cdx-src` namespace as necessary:

```
$ cd /path/to/work/directory
$ kubectl -n cdx-src exec -it host-code-dx-appdata-volume -- bash
$ cd /var/cdx
$ tar -cvzf /var/cdx/appdata.tgz $(ls -d analysis-files notification-templates attachments keystore/master.key keystore/Secret tool-data/addin-tool-files 2> /dev/null)
$ exit
$ kubectl -n cdx-src cp host-code-dx-appdata-volume:/var/cdx/appdata.tgz appdata.tgz
```
6) Run the following command to delete the host-code-dx-appdata-volume pod, replacing the `cdx-src` namespace as necessary:

```
$ kubectl -n cdx-src delete pod host-code-dx-appdata-volume
```

## Copy Code Dx Database Locally

1) Log on to your Code Dx database, either your on-cluster master MariaDB database or your external database instance, and run this command, replacing `codedx` and `root` (e.g., `admin`) as necessary:

```
mysqldump --host=127.0.0.1 --port=3306 --user=root -p codedx > dump-codedx.sql
sed 's/\sDEFINER=`[^`]*`@`[^`]*`//g' -i dump-codedx.sql
```

2) Create /path/to/work/directory/database and copy dump-codedx.sql to the database directory. If you are using an on-cluster database, run this command, replacing the `cdx-src` namespace, `/path/to/dump-codedx.sql` path, and `codedx-src-mariadb-master-0` pod name as necessary:

```
$ cd /path/to/work/directory
$ mkdir database
$ kubectl -n cdx-src cp codedx-src-mariadb-master-0:/path/to/dump-codedx.sql ./database/dump-codedx.sql
```

## Copy Local Data to New Code Dx Instance

If you are using an on-cluster database, run the following command, replacing the `cdx-dest` namespace, `codedx-dest` release name, `/path/to/work/directory` directory, and the passwords for `dest-root-pwd` and `dest-replication-password` as necessary (replace the `cdx-src-svc` namespace or delete the `-namespaceSourceToolOrchestration` parameter if you are not using the Tool Orchestration feature):

```
$ cd /path/to/work/directory
$ pwsh /path/to/git/codedx-kubernetes/admin/migrate-data.ps1 -namespaceCodeDx cdx-dest -releaseNameCodeDx codedx-dest -appDataPath . -dumpFile database/dump-codedx.sql -rootPwd dest-root-pwd -replicationPwd dest-replication-password -namespaceSourceToolOrchestration cdx-src-svc
```

If you are using an external database, run the following command, replacing the `cdx-dest` namespace, `/path/to/work/directory` directory, and `codedx-dest` release name (replace the `cdx-src-svc` namespace or delete the `-namespaceSourceToolOrchestration` parameter if you are not using the Tool Orchestration feature):

```
$ cd /path/to/work/directory
$ pwsh /path/to/git/codedx-kubernetes/admin/migrate-data.ps1 -namespaceCodeDx cdx-dest -releaseNameCodeDx codedx-dest -appDataPath . -externalDatabase  -namespaceSourceToolOrchestration cdx-src-svc
```
