# Use an EFS volume for Code Dx AppData storage

Here are the steps to configure Code Dx to use AWS EFS for the Code Dx AppData volume.

>Note: These steps assume that you are using Code Dx with an external database and not using the Tool Orchestration capability.

1) Create and configure EFS file system using the [AWS instructions](https://aws.amazon.com/premiumsupport/knowledge-center/eks-persistent-storage/)

>Note: Before continuing, make sure that the EFS file system exists with network mounts in the required Availability Zones having a mount target state of Available.

2) Save this StorageClass content to a file named efs-storageclass.yaml:

```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
```

3) Create the StorageClass resource with the following command:

```
kubectl apply -f ./efs-storageclass.yaml
```

4) Save this PersistentVolume content to a file named codedx-appdata-pv.yaml **after** editing the storage capacity and volumeHandle fields:

```
apiVersion: v1 
kind: PersistentVolume 
metadata: 
  name: codedx-appdata
spec: 
  capacity: 
    storage: 64Gi 
  volumeMode: Filesystem 
  accessModes: 
    - ReadWriteMany 
  persistentVolumeReclaimPolicy: Retain 
  storageClassName: efs-sc 
  csi: 
    driver: efs.csi.aws.com 
    volumeHandle: fs-0a9f9d72
```

5) Create the PersistentVolume resource with the following command:

```
kubectl apply -f ./codedx-appdata-pv.yaml
```

6) If the cdx-app namespace does not yet exist, create it now with the following command:

```
kubectl create ns cdx-app
```

7) Save this PersistentVolumeClaim content to a file named codedx-appdata-pvc.yaml **after** editing the storage capacity field to match your PersistentVolume edit:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: codedx-appdata
  namespace: cdx-app
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 64Gi
```

8) Create the PersistentVolumeClaim resource in the cdx-app namespace with the following command:

```
kubectl apply -f ./codedx-appdata-pvc.yaml
```

9) Wait for the PersistentVolumeClaim to reach a bound status, check by periodically running the following command:

```
kubectl -n cdx-app get pvc codedx-appdata
```

10) Save this Job content to a file named codedx-appdata-job.yaml:

```
apiVersion: batch/v1
kind: Job 
metadata:
  name: codedx-appdata
  namespace: cdx-app
spec:
  template:
    spec:
      containers:
      - name: codedx-appdata
        image: busybox
        command: ["/bin/sh"]
        args: ["-c", "cd /data && chmod 2775 . && chown root:1000 ."]
        volumeMounts:
        - name: codedx-appdata-storage
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: codedx-appdata-storage
        persistentVolumeClaim:
          claimName: codedx-appdata
```

11) Create the Job resource in the cdx-app namespace with the following command:

```
kubectl apply -f ./codedx-appdata-job.yaml
```

12) Wait for the Job in the cdx-app namespace to complete, check by periodically running the following command:

```
kubectl -n cdx-app get job codedx-appdata
```

13) Save this Code Dx configuration to a file named codedx-custom-props.yaml:

```
persistence:
  existingClaim: codedx-appdata
```

>Note: If you already use a codedx-custom-props.yaml file for your Code Dx deployment, merge the above content with your file.

14) Append the following parameter to the setup.ps1 command line in the run-setup.ps1 file you generated with the Code Dx Guided Setup:

```
-extraCodeDxValuesPaths @('/path/to/codedx-custom-props.yaml')
```

15) Invoke run-setup.ps1 with the following command:

```
pwsh /path/to/run-setup.ps1
```
