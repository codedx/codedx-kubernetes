# Obtain Certificate for API certificates.k8s.io

You will need to download the CA certificate associated with the certificates.k8s.io API. Use a terminal window (with support for kubectl run -it) to create and switch to a new directory where you will fetch the CA cert. Run the following commands in order, using a second terminal window for the third step, to access the AKS certificate you need for your deployment.

```
From Terminal 1: kubectl run --rm=true -it busybox --image=busybox --restart=Never
From Terminal 1: / # cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /tmp/azure-aks.pem
From Terminal 2: kubectl cp busybox:/tmp/azure-aks.pem ./azure-aks.pem
From Terminal 1: exit
```

The last command will delete the busybox pod and exit the session you started in the first terminal. You should now have an azure-aks.pem file in the directory where you invoked the second terminal window.

