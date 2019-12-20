Follow these instructions to use your Kubernetes CA to issue certificates for your Tool Orchestration service and MinIO server. The steps assume that you will use toolsvc for your Helm release name and cdx-svc for the Kubernetes namespace where you will install Tool Orchestration components.

## Prerequisites

Some of the commands in this section require use of a bash shell with openssl installed. If you're using Windows, you can install Git Bash to perform steps requiring a bash shell.

## 1) Obtain Kubernetes CA Certificate

Use a terminal window (with support for `kubectl run -it`) to create and switch to a new directory where you will gather your certificate files. Run the following commands in order using a second terminal window, running from your new directory, to complete the steps.

```
From Terminal 1: kubectl -n cdx-svc run --rm=true -it busybox --image=busybox --restart=Never
From Terminal 1: / # cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /tmp/k8s-ca.pem
From Terminal 2: kubectl -n cdx-svc cp busybox:/tmp/k8s-ca.pem ./k8s-ca.pem
From Terminal 1: exit
```

The last command will delete the busybox pod and exit the session you started in the first terminal. You should now have a k8s-ca.pem file in the directory where you invoked the second terminal window.

## 2) Create Tool Orchestration Service Certificate

Create a file named toolsvc-tool-orchestration.conf with the following contents.

```
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
distinguished_name = req_dn
req_extensions = req_ext

[ req_dn ]
CN = toolsvc-codedx-tool-orchestration

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = toolsvc-codedx-tool-orchestration
DNS.2 = toolsvc-codedx-tool-orchestration.cdx-svc
DNS.3 = toolsvc-codedx-tool-orchestration.cdx-svc.svc.cluster.local
```

From a bash shell, create a CSR with the following command.

```
openssl req -new -config toolsvc-tool-orchestration.conf -out toolsvc-tool-orchestration.csr -keyout toolsvc-tool-orchestration.key
```

From a bash shell, run the following command.

```
cat <<EOF | kubectl -n cdx-svc create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: toolsvc-tool-orchestration
spec:
  groups:
  - system:authenticated
  request: $(cat toolsvc-tool-orchestration.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
```

Verify that you have a Pending CSR with the following command:

```
kubectl get csr toolsvc-tool-orchestration
```

Approve the CSR with the following command.

```
kubectl certificate approve toolsvc-tool-orchestration
```

From a bash shell, download the server tool-orchestration certificate with the following command.

```
kubectl get csr toolsvc-tool-orchestration -o jsonpath='{.status.certificate}' | base64 -d > toolsvc-tool-orchestration.crt
```

From a bash shell, add the certificate chain to toolsvc-tool-orchestration.pem

```
cat toolsvc-tool-orchestration.crt k8s-ca.pem > toolsvc-tool-orchestration.pem
```

## 3) Create MinIO Server Certificate

Create a file named toolsvc-minio.conf with the following contents.

```
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
distinguished_name = req_dn
req_extensions = req_ext

[ req_dn ]
CN = toolsvc-minio

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = toolsvc-minio
DNS.2 = toolsvc-minio.cdx-svc
DNS.3 = toolsvc-minio.cdx-svc.svc.cluster.local
```

From a bash shell, create a CSR with the following command.

```
openssl req -new -config toolsvc-minio.conf -out toolsvc-minio.csr -keyout toolsvc-minio.key
```

From a bash shell, run the following command.

```
cat <<EOF | kubectl -n cdx-svc create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: toolsvc-minio
spec:
  groups:
  - system:authenticated
  request: $(cat toolsvc-minio.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
```

Verify that you have a Pending CSR with the following command:

```
kubectl get csr toolsvc-minio
```

Approve the CSR with the following command.

```
kubectl certificate approve toolsvc-minio
```

From a bash shell, download the server certificate for toolsvc-minio with the following command.

```
kubectl get csr toolsvc-minio -o jsonpath='{.status.certificate}' | base64 -d > toolsvc-minio.crt
```

From a bash shell, add the certificate chain to toolsvc-minio.pem

```
cat toolsvc-minio.crt k8s-ca.pem > toolsvc-minio.pem
```

## 4) Results

You should have the following files after completing the above steps.

```
$ ls
k8s-ca.pem          toolsvc-minio.csr  toolsvc-tool-orchestration.conf  toolsvc-tool-orchestration.key
toolsvc-minio.conf  toolsvc-minio.key  toolsvc-tool-orchestration.crt   toolsvc-tool-orchestration.pem
toolsvc-minio.crt   toolsvc-minio.pem  toolsvc-tool-orchestration.csr
```

The key files must be kept private.
