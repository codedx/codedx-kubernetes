# This script is based on the guide provided by Microsoft at:
#    https://docs.microsoft.com/en-us/azure/aks/use-network-policies
#
# This script will create a resource group with the specified name,
# create the appropriate networking resources, and deploy a Kubernetes
# cluster using the configuration parameters below.


######
# CONFIG
#

# Resource group to store the cluster resource in. Note that
# VMs, disks, networks, and other resources for the cluster
# will be created in a *new* resource group - not the one
# specified here.
#
# The Cluster resource will be deployed to the
# given resource group, while it will manage the sub-resources
# of the cluster in a new resource group.
RESOURCE_GROUP_NAME=myResourceGroup-NP

# Name of the Cluster resource to create
CLUSTER_NAME=myAKSCluster

# Physical location of the cluster
# Get the available locations in your subscription with the command:
#    az account list-locations -o table
# (Use 'name', not 'DisplayName')
LOCATION=eastus

# VM size for the cluster nodes
# Get the available sizes for your location with the command:
#    az vm list-sizes -l $LOCATION -o table
# (Use 'name', case-sensitive. Nodes must have at least 2 cores
#  and 8GB of memory.)
NODE_SIZE=Standard_B2ms

# Number of nodes to start the cluster with. Nodes can be
# added or removed after cluster creation. The Azure-recommended
# minimum is 3, but only 2 nodes can be used if necessary.
NODE_COUNT=2


# (Resource name options that are unimportant but useful to have)
K8S_VNET_NAME=k8s-vnet
K8S_SUBNET_NAME=k8s-subnet


######
# SCRIPT
#

# Create a resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create a virtual network and subnet
az network vnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $K8S_VNET_NAME \
    --address-prefixes 10.0.0.0/8 \
    --subnet-name $K8S_SUBNET_NAME \
    --subnet-prefix 10.240.0.0/16

# Create a service principal and read in the application ID
SP=$(az ad sp create-for-rbac --output json)
SP_ID=$(echo $SP | jq -r .appId)
SP_PASSWORD=$(echo $SP | jq -r .password)

# Wait 15 seconds to make sure that service principal has propagated
echo "Waiting for service principal to propagate..."
sleep 15

# Get the virtual network resource ID
VNET_ID=$(az network vnet show --resource-group $RESOURCE_GROUP_NAME --name $K8S_VNET_NAME --query id -o tsv)

# Assign the service principal Contributor permissions to the virtual network resource
az role assignment create --assignee $SP_ID --scope $VNET_ID --role Contributor

# Get the virtual network subnet resource ID
SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $K8S_VNET_NAME --name $K8S_SUBNET_NAME --query id -o tsv)

# Create the AKS cluster and specify the virtual network and service principal information
# Enable network policy by using the `--network-policy` parameter
az aks create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --node-count $NODE_COUNT \
    --generate-ssh-keys \
    --network-plugin azure \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $SUBNET_ID \
    --service-principal $SP_ID \
    --client-secret $SP_PASSWORD \
    --network-policy azure \
    --kubernetes-version 1.14.6 \
    --node-vm-size $NODE_SIZE