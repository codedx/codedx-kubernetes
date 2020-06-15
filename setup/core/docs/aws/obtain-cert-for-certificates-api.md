# Obtain Certificate for API certificates.k8s.io

Open the EKS AWS console and download the base64 representation of your cluster's CA certificate. You can generate a aws-eks.pem file by running the following command after specifying the base64-encoded certificate data shown in the console.

```
echo '<base64-encoded-certificate-data>' | base64 -d > aws-eks.pem
```

