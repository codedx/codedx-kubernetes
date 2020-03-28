#!/bin/bash

PUBLIC_KEY_PATH=$1
CLUSTER_NAME=$2

LOCATION='us-east-2'
NODETYPE='t3.medium'

NODECOUNT=1
NODECOUNTMIN=1
NODECOUNTMAX=4
NODEGROUPNAME='standard-workers'

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

# creates a cluster with a single managed group that spans availability zones
eksctl create cluster \
	--name $CLUSTER_NAME \
	--version 1.14 \
	--region $LOCATION \
	--nodegroup-name $NODEGROUPNAME \
	--node-type $NODETYPE \
	--nodes $NODECOUNT \
	--nodes-min $NODECOUNTMIN \
	--nodes-max $NODECOUNTMAX \
	--ssh-access \
	--ssh-public-key $PUBLIC_KEY_PATH \
	--managed \
	--asg-access
check_exit $? 'cluster' 2

kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
check_exit $? 'autoscaler' 3

kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
check_exit $? 'autoscaler' 4

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
# kubectl create namespace grafana
# helm install grafana stable/grafana \
#     --namespace grafana \
#     --set persistence.storageClassName="gp2" \
#     --set adminPassword='m8F2^eJ*#0c' \
#     --set datasources."datasources\.yaml".apiVersion=1 \
#     --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
#     --set datasources."datasources\.yaml".datasources[0].type=prometheus \
#     --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.prometheus.svc.cluster.local \
#     --set datasources."datasources\.yaml".datasources[0].access=proxy \
#     --set datasources."datasources\.yaml".datasources[0].isDefault=true \
#     --set service.type=LoadBalancer
