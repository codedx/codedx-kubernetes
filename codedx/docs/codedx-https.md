# Native HTTPS on Code Dx

While an Ingress is generally preferred for exposing HTTPS to a user (see [cert-manager](https://cert-manager.io/docs/tutorials/acme/ingress/#step-7-deploy-a-tls-ingress-resource)), HTTPS can also be enabled directly on Code Dx for enhanced security. Typically a user will make an HTTPS request to your ingress controller, which makes an appropriate HTTP request to Code Dx. With HTTPS enabled on Code Dx, all requests between the user, ingress, and Code Dx will be made using HTTPS.

The cert used by Code Dx can be signed by a well-known CA, your cluster's CA, or it can be self-signed. If there are cert-related problems getting your ingress to accept connections with Code Dx, it may be necessary to configure your ingress controller to trust the CA that is used. Procedure details will vary by ingress controller. 

To configure Code Dx with HTTPS, you will need your certificate and key.

## Generating a Certificate via Cluster CA

A certificate signed with the cluster CA is recommended as it is likely that an ingress controller will have the cluster CA in its set of trusts. 

### Fetching CA Certificate
We will create a temporary pod on the cluster which will be used to extract the CA certificate. Open two terminal windows.

1. In one terminal, run: `kubectl run --rm=true -it busybox --image=busybox --restart=Never` (you should now be connected to a busybox shell)
2. In the same terminal, run: `cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /tmp/k8s-ca.pem`
3. In the other terminal, run: `kubectl -n cdx-svc cp busybox:/tmp/k8s-ca.pem ./k8s-ca.pem` (you should now have a `k8s-ca.pem` file in the working directory of this other terminal)
4. In the terminal running busybox, run: `exit` to cleanly shut down the pod

Once these steps are complete you will have a local copy of `k8s-ca.pem`. We will now use this to create a certificate for Code Dx.

### Making a Certificate Signing Request
Create a new file locally named `codedx-tomcat.conf` and paste the following contents:

```
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
distinguished_name = req_dn
req_extensions = req_ext

[ req_dn ]
CN = {service-name}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = {service-name}
DNS.2 = {service-name}.{namespace}
DNS.3 = {service-name}.{namespace}.svc.cluster.local
```

Before continuing, you must replace the following placeholders as necessary:

- *{service-name}* - Name of the kubernetes service exposing Code Dx; if installed with the release name `codedx`, this is simply `codedx`. For any other name the service will be named `{release}-codedx`, eg a release named `test` will have a service name `test-codedx`
- *{namespace}* - The namespace Code Dx was installed to via `helm install -n/--namespace {name}`. If the namespace was unspecified, this will be `default`.

Be sure to update the placeholders under both the `[req_dn]` and `[alt_names]` sections.

Once the file has been changed, create the CSR with OpenSSL:

```
openssl req -new -config codedx-tomcat.conf -out codedx-tomcat.csr -keyout codedx-tomcat.key
```

### Submit and Accept the CSR

**We strongly suggest using a bash shell to simplify the following steps, which involve base64 encoding and decoding.**

From a bash shell, navigate to the folder containing your new CSR and run:

```
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: codedx-tomcat
spec:
  groups:
  - system:authenticated
  request: $(cat codedx-tomcat.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF
```

Use `kubectl get csr codedx-tomcat` to confirm that the CSR was submitted. Approve the CSR with `kubectl certificate approve codedx-tomcat`.

The Code Dx certificate can then be downloaded with:

```
kubectl get csr codedx-tomcat -o jsonpath='{.status.certificate}' | base64 -d > codedx-tomcat.crt
```

Combine the certificate with the CA certificate to construct the PEM file that will be used by Code Dx:

```
cat codedx-tomcat.crt k8s-ca.pem > codedx-tomcat.pem
```

You will now have the certificate file for Code Dx in `codedx-tomcat.pem`, and the associated key `codedx-tomcat.key` that was created earlier with OpenSSL. These two files can now be used to configure HTTPS natively in Code Dx.

# Configuring Code Dx with Native HTTPS

_Note: The certificate and key files will be referred to as `codedx-tomcat.pem` and `codedx-tomcat.key`, respectively. These names are not required but the commands below should be modified if using different names._

A secret must be created in Code Dx's namespace containing your certificate and key, which will be automatically mounted in Code Dx after configuration. The secret can be created with:

```
kubectl create secret generic codedx-tls --namespace {namespace} --from-file=./codedx-tomcat.pem --from-file=codedx-tomcat.key
```

The above command must be modified with the appropriate namespace (or the `--namespace` argument can be removed if using the default namespace.) The `--from-file` parameters should match the file names of your certificate and key.

Once the secret has been created, update your `values.yaml` to include:

```yaml
codedxTls:
  enabled: true
  secret: 'codedx-tls'
  certFile: 'codedx-tomcat.pem'
  keyFile: 'codedx-tomcat.key'
```

The parameters `secret`, `certFile`, and `keyFile` should be changed if necessary. `certFile` and `keyFile` are the names of the respective files that were used to create the secret.

If using an ingress controller other than NGINX Ingress, it may be necessary to modify annotations on the ingress so that HTTPS is used. Check the documentation for your ingress controller for more details.

Once all changes have been made, use `helm install/upgrade ...` to apply your changes for a new/existing installation. This will lead to a pod restart for existing installations.

Use `kubectl get svc` to inspect the service exposing Code Dx and confirm that it is accepting requests on port 9443. If using an ingress, use `kubectl describe ing` to inspect the ingress resource and confirm that it has the Code Dx backend set to port 9443.