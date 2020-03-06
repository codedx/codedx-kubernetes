
$amazonVpcCniCalicoYaml = 'https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/v1.6/calico.yaml'

function Add-AwsCalicoNetworkPolicyProvider([int] $waitTimeSeconds) {

	kubectl apply -f $amazonVpcCniCalicoYaml
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create Calico resources, kubectl exited with code $LASTEXITCODE."
	}

	# Creates these among others:
	#   daemonset.apps/calico-node created
	#   deployment.apps/calico-typha
	#   deployment.apps/calico-typha-horizontal-autoscaler
	Wait-AllRunningPods 'Calico (aws/amazon-vpc-cni-k8s)' $waitTimeSeconds 'kube-system'
}

function Remove-AwsCalicoNetworkPolicyProvider() {

	kubectl delete -f $amazonVpcCniCalicoYaml
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete Calico resources, kubectl exited with code $LASTEXITCODE."
	}
}