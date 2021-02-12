$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$location = Join-Path $PSScriptRoot '../..'
Push-Location $location

Describe 'version' {

	It 'should not run with current versions' {

		. $mocks

		{. ./.version/version.ps1 `
			-codeDxVersion 'v1.0.0' `
			-codeDxTomcatInitVersion 'v1.0.2' `
			-mariaDBVersion 'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion 'v1.0.4' `
			-restoreDBVersion 'v1.0.5' `
		} | Should -Throw "Neither the Code Dx nor Tool Orchestration charts require an update"
	}

	It 'should not edit charts when updating MariaDB' {

		. $mocks

		. ./.version/version.ps1 `
			-codeDxVersion 'v1.0.0' `
			-codeDxTomcatInitVersion 'v1.0.2' `
			-mariaDBVersion 'v2.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion 'v1.0.4' `
			-restoreDBVersion 'v1.0.5' `

		$fileContent.Keys.Count | Should -Be 2
		$fileContent.Keys | Should -Contain './admin/restore-db.ps1'
		$fileContent.Keys | Should -Contain './setup/core/setup.ps1'

		$fileContent['./setup/core/setup.ps1'] | Select-String -Pattern 'imageMariaDB\s+=\s''codedx/codedx-mariadb:v2.0.3''' | Should -Not -BeNullOrEmpty
	}

	It 'should not edit charts when updating workflow' {

		. $mocks

		. ./.version/version.ps1 `
			-codeDxVersion 'v1.0.0' `
			-codeDxTomcatInitVersion 'v1.0.2' `
			-mariaDBVersion 'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion 'v2.0.4' `
			-restoreDBVersion 'v1.0.5' `

		$fileContent.Keys.Count | Should -Be 2
		$fileContent.Keys | Should -Contain './admin/restore-db.ps1'
		$fileContent.Keys | Should -Contain './setup/core/setup.ps1'

		$fileContent['./setup/core/setup.ps1'] | Select-String -Pattern 'imageWorkflowController\s+=\s''codedx/codedx-workflow-controller:v2.0.4''' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/setup.ps1'] | Select-String -Pattern 'imageWorkflowExecutor\s+=\s''codedx/codedx-argoexec:v2.0.4''' | Should -Not -BeNullOrEmpty
	}

	It 'should not edit charts when updating restore DB' {

		. $mocks

		. ./.version/version.ps1 `
			-codeDxVersion 'v1.0.0' `
			-codeDxTomcatInitVersion 'v1.0.2' `
			-mariaDBVersion 'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion 'v1.0.4' `
			-restoreDBVersion 'v2.0.5' `

		$fileContent.Keys.Count | Should -Be 2
		$fileContent.Keys | Should -Contain './admin/restore-db.ps1'
		$fileContent.Keys | Should -Contain './setup/core/setup.ps1'

		$fileContent['./admin/restore-db.ps1'] | Select-String -Pattern 'imageDatabaseRestore\s+=\s''codedx/codedx-dbrestore:v2.0.5''' | Should -Not -BeNullOrEmpty
	}

	It 'should edit Code Dx chart when updating tomcat init' {

		. $mocks

		. ./.version/version.ps1 `
			-codeDxVersion 'v1.0.0' `
			-codeDxTomcatInitVersion 'v2.0.2' `
			-mariaDBVersion 'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion 'v1.0.4' `
			-restoreDBVersion 'v1.0.5' `

		$fileContent.Keys.Count | Should -Be 4
		$fileContent.Keys | Should -Contain './admin/restore-db.ps1'
		$fileContent.Keys | Should -Contain './setup/core/setup.ps1'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx/Chart.yaml'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx/values.yaml'

		$fileContent['./setup/core/setup.ps1'] | Select-String -Pattern 'imageCodeDxTomcatInit\s+=\s''codedx/codedx-bash:v2.0.2''' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx/Chart.yaml'] | Select-String -Pattern 'version:\s1.1.0' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx/Chart.yaml'] | Select-String -Pattern 'appVersion:\s"1.0.0"' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx/values.yaml'] | Select-String -Pattern 'codedxTomcatInitImage:\s''codedx/codedx-bash:v2.0.2''' | Should -Not -BeNullOrEmpty
	}

	It 'should edit Code Dx Tool Orchestration chart when updating tool orchestration' {

		. $mocks

		. ./.version/version.ps1 `
			-codeDxVersion 'v1.0.0' `
			-codeDxTomcatInitVersion 'v1.0.2' `
			-mariaDBVersion 'v1.0.3' `
			-toolOrchestrationVersion 'v2.0.1' `
			-workflowVersion 'v1.0.4' `
			-restoreDBVersion 'v1.0.5' `

		$fileContent.Keys.Count | Should -Be 4
		$fileContent.Keys | Should -Contain './admin/restore-db.ps1'
		$fileContent.Keys | Should -Contain './setup/core/setup.ps1'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx-tool-orchestration/Chart.yaml'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx-tool-orchestration/values.yaml'

		$fileContent['./setup/core/setup.ps1'] | Select-String -Pattern 'imagePrepare\s+=\s''codedx/codedx-prepare:v2.0.1''' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx-tool-orchestration/Chart.yaml'] | Select-String -Pattern 'version:\s1.1.1' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx-tool-orchestration/Chart.yaml'] | Select-String -Pattern 'appVersion:\s"2.0.1"' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx-tool-orchestration/values.yaml'] | Select-String -Pattern 'imageNamePrepare:\s''codedx/codedx-prepare:v2.0.1''' | Should -Not -BeNullOrEmpty
	}

	It 'should edit charts when updating Code Dx' {

		. $mocks

		. ./.version/version.ps1 `
			-codeDxVersion 'v2.0.0' `
			-codeDxTomcatInitVersion 'v1.0.2' `
			-mariaDBVersion 'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion 'v1.0.4' `
			-restoreDBVersion 'v1.0.5' `

		$fileContent.Keys.Count | Should -Be 6
		$fileContent.Keys | Should -Contain './admin/restore-db.ps1'
		$fileContent.Keys | Should -Contain './setup/core/setup.ps1'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx/Chart.yaml'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx/values.yaml'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx-tool-orchestration/Chart.yaml'
		$fileContent.Keys | Should -Contain './setup/core/charts/codedx-tool-orchestration/values.yaml'

		$fileContent['./setup/core/setup.ps1'] | Select-String -Pattern 'imageCodeDxTools\s+=\s''codedx/codedx-tools:v2.0.0''' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx/Chart.yaml'] | Select-String -Pattern 'version:\s1.1.0' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx/Chart.yaml'] | Select-String -Pattern 'appVersion:\s"2.0.0"' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx/values.yaml'] | Select-String -Pattern 'codedxTomcatImage:\s''codedx/codedx-tomcat:v2.0.0''' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx-tool-orchestration/Chart.yaml'] | Select-String -Pattern 'version:\s1.1.1' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx-tool-orchestration/Chart.yaml'] | Select-String -Pattern 'appVersion:\s"1.0.1"' | Should -Not -BeNullOrEmpty
		$fileContent['./setup/core/charts/codedx-tool-orchestration/values.yaml'] | Select-String -Pattern 'imageNamePrepare:\s''codedx/codedx-prepare:v1.0.1''' | Should -Not -BeNullOrEmpty
	}

	BeforeEach {

		. ./.version/test/mocks.ps1
	}
}