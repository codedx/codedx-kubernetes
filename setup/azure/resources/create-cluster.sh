#!/bin/bash

# Version: 1.0.0

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
RESOURCE_GROUP_NAME=CodeDx

# Name of the Cluster resource to create
CLUSTER_NAME=codedx

# Physical location of the cluster
# Get the available locations in your subscription with the command:
#    az account list-locations -o table
# (Use 'name', not 'DisplayName')
LOCATION=eastus

# VM size for the cluster nodes
# Get the available sizes for your location with the command:
#    az vm list-sizes -l $LOCATION -o table
#
# (Specify a case-sensitive VM size from the 'Name' column)
#
# Note: The Code Dx web application requires a node with at least 2 vCPUs 
# and 8 GiB of memory.)
NODE_SIZE=Standard_D2s_v3

# Number of nodes to start the cluster with. Nodes can be
# added or removed after cluster creation. The Azure-recommended
# minimum is 3, but only 2 nodes can be used if necessary.
NODE_COUNT=2


# (Resource name options that are unimportant but useful to have)
K8S_VNET_NAME=codedx-vnet
K8S_SUBNET_NAME=codedx-subnet


######
# SCRIPT
#

check_exit() {
        local EC=$1
        if [ $EC -ne 0 ]; then
                echo "$2 failed with exit code $EC!"
                exit $3
        fi
}

# Create a resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
check_exit $? 'resource group' 2

# Create a virtual network and subnet
az network vnet create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $K8S_VNET_NAME \
    --address-prefixes 10.0.0.0/8 \
    --subnet-name $K8S_SUBNET_NAME \
    --subnet-prefix 10.227.0.0/16
check_exit $? 'network create' 3

# Create a service principal and read in the application ID
SP=$(az ad sp create-for-rbac --output json)
check_exit $? 'principal config' 3

SP_ID=$(echo $SP | jq -r .appId)
check_exit $? 'principal config' 3

SP_PASSWORD=$(echo $SP | jq -r .password)
check_exit $? 'principal config' 3

# Wait 15 seconds to make sure that service principal has propagated
echo "Waiting for service principal to propagate..."
sleep 15

# Get the virtual network resource ID
VNET_ID=$(az network vnet show --resource-group $RESOURCE_GROUP_NAME --name $K8S_VNET_NAME --query id -o tsv)
check_exit $? 'network config' 4

# Assign the service principal Contributor permissions to the virtual network resource
az role assignment create --assignee $SP_ID --scope $VNET_ID --role Contributor
check_exit $? 'role create' 5

# Get the virtual network subnet resource ID
SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP_NAME --vnet-name $K8S_VNET_NAME --name $K8S_SUBNET_NAME --query id -o tsv)
check_exit $? 'subnet query' 6

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
    --load-balancer-sku standard \
    --kubernetes-version 1.14.7 \
    --node-vm-size $NODE_SIZE
check_exit $? 'aks create' 7

echo 'Done'
echo "Recommendation: Enable the Pod Security Policy feature preview and enable it on your cluster (see https://docs.microsoft.com/en-us/azure/aks/use-pod-security-policies). Use the -addDefaultPodSecurityPolicyForAuthenticatedUsers setup.ps1 parameter if your cluster's Pod Security Policy configuration will prevent pods without a policy from running."