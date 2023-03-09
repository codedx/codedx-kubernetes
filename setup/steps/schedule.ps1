
'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseNodeSelectors : Step {

	static [string] hidden $description = @'
Specify whether you want to use node selectors to attract Code Dx 
pods to specific nodes in your cluster.

Note: When using node selectors, before installing Code Dx, you must label 
your nodes using the selectors you define. For example, if you specify a 
'node' selector key and a 'webapp' selector value, label your node(s) using 
this command: 

kubectl label nodes your-cluster-node-name node=webapp
'@

	UseNodeSelectors([ConfigInput] $config) : base(
		[UseNodeSelectors].Name, 
		$config,
		'Node Selectors',
		[UseNodeSelectors]::description,
		'Do you want to specify node selectors?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to define node selectors.',
			'No, I do not want to define node selectors', 0)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useNodeSelectors = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[bool]CanRun() {
		# the tool workflows do not currently support node selectors or pod 
		# tolerations (Argo has support in the workflow spec). since most 
		# minikube clusters will be one-node clusters, avoid node selectors
		# and pod tolerations
		return $this.config.k8sProvider -ne [ProviderType]::Minikube
	}

	[void]Reset(){
		$this.config.useNodeSelectors = $false
	}
}

class KeyValueStep : Step {

	[string] $keyPrompt
	[string] $valuePrompt

	KeyValueStep([ConfigInput] $config, 
		[string] $name, [string] $title, 
		[string] $description,
		[string] $keyPrompt,
		[string] $valuePrompt) : base(
		$name, 
		$config,
		$title,
		$description,
		'') {

		$this.keyPrompt = $keyPrompt
		$this.valuePrompt = $valuePrompt
	}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object Question($prompt)
	}

	[bool]Run() {

		Write-HostSection $this.title ($this.GetMessage())

		$keyQuestion = $this.MakeQuestion($this.keyPrompt)
		$keyQuestion.allowEmptyResponse = $true

		$keyQuestion.Prompt()
		if (-not $keyQuestion.hasResponse) {
			return $false
		}
		if ($keyQuestion.isResponseEmpty) {
			return $true
		}

		$valueQuestion = $this.MakeQuestion($this.valuePrompt)
		$valueQuestion.Prompt()
		if (-not $valueQuestion.hasResponse) {
			return $false
		}

		$keyValue = [Tuple`2[string,string]]::new($keyQuestion.response, $valueQuestion.response)
		$this.HandleKeyValueResponse($keyValue)
		$this.HandleKeyValueNote($keyValue)
		return $true
	}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		throw [NotImplementedException]
	}

	[void]HandleKeyValueNote([Tuple`2[string,string]] $keyValue) {
	}

	[bool]HandleResponse([IQuestion] $question) {
		return $true
	}
}

class NodeSelectorStep : KeyValueStep {

	[string] $nodeNameExample

	NodeSelectorStep([ConfigInput] $config, [string] $name, [string] $title, [string] $description, [string] $nodeNameExample) : base(
		$config,
		$name, 
		$title,
		$description,
		'Enter the node selector key name',
		'Enter the node selector value name') {
		$this.nodeNameExample = $nodeNameExample
	}

	[void]HandleKeyValueNote([Tuple`2[string,string]] $keyValue) {
		$this.config.notes[($this.GetType().Name)] = "kubectl label nodes $($this.nodeNameExample) $($keyValue.Item1)=$($keyValue.Item2)"
	}

	[void]Reset() {
		$name = $this.GetType().Name
		if ($this.config.notes.containskey($name)) {
			$this.config.notes.remove($name)
		}
	}

	[bool]CanRun() {
		return $this.config.useNodeSelectors
	}
}

class CodeDxNodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for the Code Dx web application by entering a key and 
a value that you define. You must separately label your cluster node(s).

Note: You can use the same node selector key and value for multiple workloads.
'@

	CodeDxNodeSelector([ConfigInput] $config) : base(
		$config,
		[CodeDxNodeSelector].Name, 
		'Code Dx Node Selector',
		[CodeDxNodeSelector]::description,
		'codedx-web-app-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.codeDxNodeSelector = $keyValue
		return $true
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.codeDxNodeSelector = $null
	}
}

class MasterDatabaseNodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for the master database by entering a key and 
a value that you define. You must separately label your cluster node(s).

Note: You can use the same node selector key and value for multiple workloads.
'@

	MasterDatabaseNodeSelector([ConfigInput] $config) : base(
		$config,
		[MasterDatabaseNodeSelector].Name, 
		'Master Database Node Selector',
		[MasterDatabaseNodeSelector]::description,
		'master-database-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.masterDatabaseNodeSelector = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([NodeSelectorStep]$this).CanRun() -and -not $this.config.skipDatabase
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.masterDatabaseNodeSelector = $null
	}
}

class SubordinateDatabaseNodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for the subordinate database by entering a key and 
a value that you define. You must separately label your cluster node(s).

Note: You can use the same node selector key and value for multiple workloads.
'@

	SubordinateDatabaseNodeSelector([ConfigInput] $config) : base(
		$config,
		[SubordinateDatabaseNodeSelector].Name, 
		'Subordinate Database Node Selector',
		[SubordinateDatabaseNodeSelector]::description,
		'subordinate-database-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.subordinateDatabaseNodeSelector = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([NodeSelectorStep]$this).CanRun() -and $this.config.dbSlaveReplicaCount -gt 0
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.subordinateDatabaseNodeSelector = $null
	}
}

class ToolServiceNodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for the tool service by entering a key and 
a value that you define. You must separately label your cluster node(s).

Note: You can use the same node selector key and value for multiple workloads.
'@

	ToolServiceNodeSelector([ConfigInput] $config) : base(
		$config,
		[ToolServiceNodeSelector].Name, 
		'Tool Service Node Selector',
		[ToolServiceNodeSelector]::description,
		'tool-service-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.toolServiceNodeSelector = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([NodeSelectorStep]$this).CanRun() -and -not $this.config.skipToolOrchestration
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.toolServiceNodeSelector = $null
	}
}

class MinIONodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for MinIO by entering a key and a value that you 
define. You must separately label your cluster node(s).

Note: You can use the same node selector key and value for multiple workloads.
'@

	MinIONodeSelector([ConfigInput] $config) : base(
		$config,
		[MinIONodeSelector].Name, 
		'MinIO Node Selector',
		[MinIONodeSelector]::description,
		'minio-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.minioNodeSelector = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([NodeSelectorStep]$this).CanRun() -and -not $this.config.skipToolOrchestration -and -not $this.config.skipMinIO
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.minioNodeSelector = $null
	}
}

class WorkflowControllerNodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for the workflow controller by entering a key and 
a value that you define. You must separately label your cluster node(s).

Note: You can use the same node selector key and value for multiple workloads.
'@

	WorkflowControllerNodeSelector([ConfigInput] $config) : base(
		$config,
		[WorkflowControllerNodeSelector].Name, 
		'Workflow Controller Node Selector',
		[WorkflowControllerNodeSelector]::description,
		'workflow-controller-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.workflowControllerNodeSelector = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([NodeSelectorStep]$this).CanRun() -and -not $this.config.skipToolOrchestration
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.workflowControllerNodeSelector = $null
	}
}

class ToolNodeSelector : NodeSelectorStep {

	static [string] hidden $description = @'
Specify a node selector for all tools by entering a key and a value that 
you define. You must separately label your cluster node(s). 

You can configure a node selector for specific projects and/or tools by 
adding the nodeSelectorKey and nodeSelectorValue fields to a Code Dx 
Resource Requirement - browse to the following URL for more details:

https://community.synopsys.com/s/document-item?bundleId=codedx&topicId=user_guide%2FAnalysis%2Ftool-orchestration.html&_LANG=enus#resource-requirements

Note: You can use the same node selector key and value for multiple workloads.
'@

	ToolNodeSelector([ConfigInput] $config) : base(
		$config,
		[ToolNodeSelector].Name, 
		'Tool Node Selector',
		[ToolNodeSelector]::description,
		'tool-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.toolNodeSelector = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([NodeSelectorStep]$this).CanRun() -and -not $this.config.skipToolOrchestration
	}

	[void]Reset(){
		([NodeSelectorStep]$this).Reset()
		$this.config.toolNodeSelector = $null
	}
}

class UseTolerations : Step {

	static [string] hidden $description = @'
Specify whether you want to use node taints and tolerations to repel pods from 
specific nodes in your cluster. The tolerations you specify here will apply to 
both the NoSchedule and NoExecute effects.

Note: When using pod tolerations, before installing Code Dx, you must place 
taints on your nodes based on the tolerations you specify. For example, if you 
specify a 'dedicated' toleration key and a 'webapp' toleration value, apply a 
node taint using the following commands:

kubectl taint nodes your-cluster-node-name dedicated=webapp:NoSchedule
kubectl taint nodes your-cluster-node-name dedicated=webapp:NoExecute
'@

	UseTolerations([ConfigInput] $config) : base(
		[UseTolerations].Name, 
		$config,
		'Pod Tolerations',
		[UseTolerations]::description,
		'Do you want to specify pod tolerations?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to define pod tolerations.',
			'No, I do not want to define pod tolerations', 0)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useTolerations = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[bool]CanRun() {
		# the tool workflows do not currently support node selectors or pod 
		# tolerations (Argo has support in the workflow spec). since most 
		# minikube clusters will be one-node clusters, avoid node selectors
		# and pod tolerations
		return $this.config.k8sProvider -ne [ProviderType]::Minikube
	}

	[void]Reset(){
		$this.config.useTolerations = $false
	}
}

class PodTolerationStep : KeyValueStep {

	[string] $nodeNameExample

	PodTolerationStep([ConfigInput] $config, [string] $name, [string] $title, [string] $description, [string] $nodeNameExample) : base(
		$config,
		$name, 
		$title,
		$description,
		'Enter the pod toleration key name',
		'Enter the pod toleration value name') {
		$this.nodeNameExample = $nodeNameExample
	}

	[void]HandleKeyValueNote([Tuple`2[string,string]] $keyValue) {
		$keyValueString = "$($keyValue.Item1)=$($keyValue.Item2)"
		$this.config.notes[($this.GetType().Name)] = "kubectl taint nodes $($this.nodeNameExample) $keyValueString`:NoSchedule`nkubectl taint nodes $($this.nodeNameExample) $keyValueString`:NoExecute"
	}

	[bool]CanRun() {
		return $this.config.useTolerations
	}

	[void]Reset() {
		$name = $this.GetType().Name
		if ($this.config.notes.containskey($name)) {
			$this.config.notes.remove($name)
		}
	}
}

class CodeDxTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for the Code Dx web application by entering a key 
and a value that you define. You must separately apply a taint to your 
cluster node(s). The key and value you define will be associated with the 
NoSchedule and NoExecute effects.

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	CodeDxTolerations([ConfigInput] $config) : base(
		$config,
		[CodeDxTolerations].Name, 
		'Code Dx Pod Toleration',
		[CodeDxTolerations]::description,
		'codedx-web-app-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.codeDxNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.codeDxNoScheduleExecuteToleration = $null
	}
}

class MasterDatabaseTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for the master database by entering a key 
and a value that you define. You must separately apply a taint to your 
cluster node(s). The key and value you define will be associated with the 
NoSchedule and NoExecute effects.

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	MasterDatabaseTolerations([ConfigInput] $config) : base(
		$config,
		[MasterDatabaseTolerations].Name, 
		'Master Database Pod Toleration',
		[MasterDatabaseTolerations]::description,
		'master-database-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.masterDatabaseNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([PodTolerationStep]$this).CanRun() -and -not $this.config.skipDatabase
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.masterDatabaseNoScheduleExecuteToleration = $null
	}
}

class SubordinateDatabaseTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for the subordinate database by entering a key 
and a value that you define. You must separately apply a taint to your 
cluster node(s). The key and value you define will be associated with the 
NoSchedule and NoExecute effects.

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	SubordinateDatabaseTolerations([ConfigInput] $config) : base(
		$config,
		[SubordinateDatabaseTolerations].Name, 
		'Subordinate Database Pod Toleration',
		[SubordinateDatabaseTolerations]::description,
		'subordinate-database-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.subordinateDatabaseNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([PodTolerationStep]$this).CanRun() -and $this.config.dbSlaveReplicaCount -gt 0
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.subordinateDatabaseNoScheduleExecuteToleration = $null
	}
}

class ToolServiceTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for the tool service by entering a key 
and a value that you define. You must separately apply a taint to your 
cluster node(s). The key and value you define will be associated with the 
NoSchedule and NoExecute effects.

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	ToolServiceTolerations([ConfigInput] $config) : base(
		$config,
		[ToolServiceTolerations].Name, 
		'Tool Service Pod Toleration',
		[ToolServiceTolerations]::description,
		'tool-service-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.toolServiceNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([PodTolerationStep]$this).CanRun() -and -not $this.config.skipToolOrchestration
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.toolServiceNoScheduleExecuteToleration = $null
	}
}

class MinIOTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for the MinIO by entering a key and a value that 
you define. You must separately apply a taint to your cluster node(s). 
The key and value you define will be associated with the NoSchedule and 
NoExecute effects.

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	MinIOTolerations([ConfigInput] $config) : base(
		$config,
		[MinIOTolerations].Name, 
		'MinIO Pod Toleration',
		[MinIOTolerations]::description,
		'minio-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.minioNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([PodTolerationStep]$this).CanRun() -and -not $this.config.skipToolOrchestration -and -not $this.config.skipMinIO
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.minioNoScheduleExecuteToleration = $null
	}
}

class WorkflowControllerTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for the workflow controller by entering a key 
and a value that you define. You must separately apply a taint to your 
cluster node(s). The key and value you define will be associated with the 
NoSchedule and NoExecute effects.

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	WorkflowControllerTolerations([ConfigInput] $config) : base(
		$config,
		[WorkflowControllerTolerations].Name, 
		'Workflow Controller Pod Toleration',
		[WorkflowControllerTolerations]::description,
		'workflow-controller-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.workflowControllerNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([PodTolerationStep]$this).CanRun() -and -not $this.config.skipToolOrchestration
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.workflowControllerNoScheduleExecuteToleration = $null
	}
}

class ToolTolerations : PodTolerationStep {

	static [string] hidden $description = @'
Specify a pod toleration for all tools by entering a key and a value that 
you define. You must separately apply a taint to your cluster node(s). 
The key and value you define will be associated with the NoSchedule 
and NoExecute effects.

You can configure a pod toleration for specific projects and/or tools by 
adding the podTolerationKey and podTolerationValue fields to a Code Dx 
Resource Requirement - browse to the following URL for more details:

https://codedx.com/Documentation/UserGuide.html#ResourceRequirements

Note: You can use the same pod toleration key and value for multiple workloads.
'@

	ToolTolerations([ConfigInput] $config) : base(
		$config,
		[ToolTolerations].Name, 
		'Tool Pod Toleration',
		[ToolTolerations]::description,
		'tool-node') {}

	[bool]HandleKeyValueResponse([Tuple`2[string,string]] $keyValue) {
		$this.config.toolNoScheduleExecuteToleration = $keyValue
		return $true
	}

	[bool]CanRun() {
		return ([PodTolerationStep]$this).CanRun() -and -not $this.config.skipToolOrchestration
	}

	[void]Reset(){
		([PodTolerationStep]$this).Reset()
		$this.config.toolNoScheduleExecuteToleration = $null
	}
}
