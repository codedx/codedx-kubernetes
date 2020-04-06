#!/bin/bash

PUBLIC_KEY_PATH=$1
CLUSTER_NAME=$2

LOCATION='us-east-2'

# node pool settings for the Code Dx nodes (db and app)
CODEDX_ZONE='us-east-2a'
CODEDX_NODEGROUPNAME='codedx-nodes'
CODEDX_NODETYPE='t3.2xlarge'
CODEDX_NODECOUNT=1
CODEDX_NODECOUNTMIN=1
CODEDX_NODECOUNTMAX=1
CODEDX_NODEDISKSIZE=20

# node pool settings for the workflow nodes (MinIO and workflows)
WORKFLOW_ZONE='us-east-2b'
WORKFLOW_NODEGROUPNAME='workflow-nodes'
WORKFLOW_NODETYPE='t3.large'
WORKFLOW_NODECOUNT=2
WORKFLOW_NODECOUNTMIN=2
WORKFLOW_NODECOUNTMAX=4
WORKFLOW_NODEDISKSIZE=20

check_exit() {
        local EC=$1
        if [ $EC -ne 0 ]; then
                echo "$2 install failed with exit code $EC!"
                exit $3
        fi
}

check_param() {
	echo $1
	if [ -z $1 ]; then
		echo "Specify a value for $2 and retry." | tee ~/setup.log
		exit 1
	fi
}

check_param "$PUBLIC_KEY_PATH" 'PUBLIC_KEY_PATH'
check_param "$CLUSTER_NAME" 'CLUSTER_NAME'

echo "Time now is $(date)"
eksctl create cluster \
	--name $CLUSTER_NAME \
	--version 1.14 \
	--region $LOCATION \
	--without-nodegroup
check_exit $? 'cluster' 2

echo "Time now is $(date)"
eksctl create nodegroup \
	--region $LOCATION \
	--node-zones $WORKFLOW_ZONE \
	--name $WORKFLOW_NODEGROUPNAME \
	--node-type $WORKFLOW_NODETYPE \
	--nodes $WORKFLOW_NODECOUNT \
	--nodes-min $WORKFLOW_NODECOUNTMIN \
	--nodes-max $WORKFLOW_NODECOUNTMAX \
	--cluster $CLUSTER_NAME \
	--ssh-access \
	--ssh-public-key $PUBLIC_KEY_PATH \
	--node-labels 'codedx=workflow' \
	--node-volume-size $CODEDX_NODEDISKSIZE \
	--asg-access \
	--managed
check_exit $? 'cluster-nodes-workflow' 2

ID=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $WORKFLOW_NODEGROUPNAME | grep nodegroupArn | grep -Po 'arn\:[^"]+')
aws eks tag-resource --resource-arn $ID --tags "k8s.io/cluster-autoscaler/enabled=true,k8s.io/cluster-autoscaler/$CLUSTER_NAME=owned"
check_exit $? 'cluster-nodes-workflow-config' 2

echo "Time now is $(date)"
eksctl create nodegroup \
	--region $LOCATION \
	--node-zones $CODEDX_ZONE \
	--name $CODEDX_NODEGROUPNAME \
	--node-type $CODEDX_NODETYPE \
	--nodes $CODEDX_NODECOUNT \
	--nodes-min $CODEDX_NODECOUNTMIN \
	--nodes-max $CODEDX_NODECOUNTMAX \
	--cluster $CLUSTER_NAME \
	--ssh-access \
	--ssh-public-key $PUBLIC_KEY_PATH \
	--node-labels 'codedx=app-db' \
	--node-volume-size $WORKFLOW_NODEDISKSIZE \
	--asg-access \
	--managed
check_exit $? 'cluster-nodes-codedx' 2

kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
check_exit $? 'autoscaler' 3

kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
check_exit $? 'autoscaler' 4

echo "Time now is $(date)"
echo 'Configure deployment resource based on https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html#ca-ng-considerations'
echo 'See Step 3 of the Deploy the Cluster Autoscaler section'
read -p "Press Enter to continue..."
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
check_exit $? 'autoscaler' 5

kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=k8s.gcr.io/cluster-autoscaler:v1.14.7
check_exit $? 'autoscaler' 6

kubectl -n kube-system patch deployment cluster-autoscaler -p '{"spec":{"template":{"spec":{"priorityClassName":"system-cluster-critical"}}}}'
check_exit $? 'autoscaler priority' 7

printf "\n\nUse the following command to view the cluster autoscaler log:"
echo '  kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler'

echo "Time now is $(date)"

# Uncomment this section to install Prometheus and Grafana after specifying your own adminPassword value. Note that the
# node exporter will tolerate all node taints.
#
# kubectl create namespace prometheus
# helm install prometheus stable/prometheus \
# 	--namespace prometheus \
# 	--set alertmanager.persistentVolume.storageClass="gp2" \
# 	--set server.persistentVolume.storageClass="gp2" \
#   --set nodeExporter.tolerations[0].operator=Exists
# 
# helm install grafana stable/grafana \
#     --namespace cdx-app \
#     --set persistence.storageClassName="gp2" \
#     --set adminPassword='m8F2^eJ*#0c' \
#     --set datasources."datasources\.yaml".apiVersion=1 \
#     --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
#     --set datasources."datasources\.yaml".datasources[0].type=prometheus \
#     --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.prometheus.svc.cluster.local \
#     --set datasources."datasources\.yaml".datasources[0].access=proxy \
#     --set datasources."datasources\.yaml".datasources[0].isDefault=true \
#     --set service.type=LoadBalancer
