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
read -p "Press Enter to continue..."
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
check_exit $? 'autoscaler' 5

kubectl -n kube-system set image deployment.apps/cluster-autoscaler cluster-autoscaler=k8s.gcr.io/cluster-autoscaler:v1.14.7
check_exit $? 'autoscaler' 6

kubectl -n kube-system patch deployment cluster-autoscaler -p '{"spec":{"template":{"spec":{"priorityClassName":"system-cluster-critical"}}}}'
check_exit $? 'autoscaler priority' 7

printf "\n\nUse the following command to view the cluster autoscaler log:"
echo '  kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler'
