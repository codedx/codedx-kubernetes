$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$location = Join-Path $PSScriptRoot '../..'
Push-Location $location

Describe 'Get-ScriptDockerImageTags' {

	It 'gets tags' {

		. $mocks

		$tags = (Get-ScriptDockerImageTags './setup/core/setup.ps1') + (Get-ScriptDockerImageTags './admin/restore-db.ps1')

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$tags['$imageCodeDxTomcat']       | Should -BeExactly 'v1.0.0'
		$tags['$imageCodeDxTools']        | Should -BeExactly 'v1.0.0'
		$tags['$imageCodeDxToolsMono']    | Should -BeExactly 'v1.0.0'

		$tags['$imagePrepare']            | Should -BeExactly 'v1.0.1'
		$tags['$imageNewAnalysis']        | Should -BeExactly 'v1.0.1'
		$tags['$imageSendResults']        | Should -BeExactly 'v1.0.1'
		$tags['$imageSendErrorResults']   | Should -BeExactly 'v1.0.1'
		$tags['$imageToolService']        | Should -BeExactly 'v1.0.1'
		$tags['$imagePreDelete']          | Should -BeExactly 'v1.0.1'

		$tags['$imageCodeDxTomcatInit']   | Should -BeExactly 'v1.0.2'

		$tags['$imageMariaDB']            | Should -BeExactly 'v1.0.3'

		$tags['$imageWorkflowController'] | Should -BeExactly 'v1.0.4'
		$tags['$imageWorkflowExecutor']   | Should -BeExactly 'v1.0.4'

		$tags['$imageMinio']              | Should -BeExactly '2020.3.25-debian-10-r4'

		$tags['$imageDatabaseRestore']    | Should -BeExactly 'v1.0.5'
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

Describe 'Test-ToolOrchestrationChartVersion' {

	It 'should match current version' {

		. $mocks

		$t = Test-ToolOrchestrationChartVersion `
			'./setup/core/setup.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-toolOrchestrationVersion 'v1.0.1'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1

		$t | Should -BeTrue
	}

	It 'should not match current Code Dx version' {

		. $mocks

		$t = Test-CodeDxChartVersion `
			'./setup/core/setup.ps1'           `
			-codeDxVersion            'v2.0.0' `
			-toolOrchestrationVersion 'v1.0.1'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1

		$t | Should -BeFalse
	}

	It 'should not match current Tool Orchestration version' {

		. $mocks

		$t = Test-CodeDxChartVersion `
			'./setup/core/setup.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-toolOrchestrationVersion 'v2.0.1'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1

		$t | Should -BeFalse
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

Describe 'Test-CodeDxChartVersion' {

	It 'should match current version' {

		. $mocks

		$t = Test-CodeDxChartVersion `
			'./setup/core/setup.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1

		$t | Should -BeTrue
	}

	It 'should not match current Code Dx version' {

		. $mocks

		$t = Test-CodeDxChartVersion `
			'./setup/core/setup.ps1'           `
			-codeDxVersion            'v2.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1

		$t | Should -BeFalse
	}

	It 'should not match current Tomcat init version' {

		. $mocks

		$t = Test-CodeDxChartVersion `
			'./setup/core/setup.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v2.0.2'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1

		$t | Should -BeFalse
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

Describe 'Test-CodeDxVersion' {

	It 'should match current version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2' `
			-mariaDBVersion           'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion          'v1.0.4' `
			-restoreDBVersion         'v1.0.5'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeTrue
	}

	It 'should not match current Code Dx version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v2.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2' `
			-mariaDBVersion           'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion          'v1.0.4' `
			-restoreDBVersion         'v1.0.5'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeFalse
	}

	It 'should not match current Tomcat init version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v2.0.2' `
			-mariaDBVersion           'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion          'v1.0.4' `
			-restoreDBVersion         'v1.0.5'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeFalse
	}

	It 'should not match current MariaDB version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2' `
			-mariaDBVersion           'v2.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion          'v1.0.4' `
			-restoreDBVersion         'v1.0.5'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeFalse
	}

	It 'should not match current tool orchestration version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2' `
			-mariaDBVersion           'v1.0.3' `
			-toolOrchestrationVersion 'v2.0.1' `
			-workflowVersion          'v1.0.4' `
			-restoreDBVersion         'v1.0.5'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeFalse
	}

	It 'should not match current workflow version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2' `
			-mariaDBVersion           'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion          'v2.0.4' `
			-restoreDBVersion         'v1.0.5'
		
		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeFalse
	}

	It 'should not match current restore version' {

		. $mocks

		$t = Test-CodeDxVersion `
			'./setup/core/setup.ps1'           `
			'./admin/restore-db.ps1'           `
			-codeDxVersion            'v1.0.0' `
			-codeDxTomcatInitVersion  'v1.0.2' `
			-mariaDBVersion           'v1.0.3' `
			-toolOrchestrationVersion 'v1.0.1' `
			-workflowVersion          'v1.0.4' `
			-restoreDBVersion         'v2.0.5'

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 2

		$t | Should -BeFalse
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

Describe 'Set-HelmChartVersion' {

	It 'should upgrade version and set appVersion (Code Dx)' {

		. $mocks

		$chartFile = './setup/core/charts/codedx/Chart.yaml'
		Set-HelmChartVersion -chartPath $chartFile -appVersion 'v2.0.0'
		
		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 1

		$chartFileData = $fileContent[$chartFile]
		$chartFileData -match 'version:\s1\.1\.0' | Should -BeTrue
		$chartFileData -match 'appVersion:\s"2\.0\.0"' | Should -BeTrue
	}

	It 'should upgrade version and set appVersion (Code Dx Tool Orchestration)' {

		. $mocks

		$chartFile = './setup/core/charts/codedx-tool-orchestration/Chart.yaml'
		Set-HelmChartVersion -chartPath $chartFile -appVersion 'v2.0.0'
		
		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 1

		$chartFileData = $fileContent[$chartFile]
		$chartFileData -match 'version:\s1\.1\.1' | Should -BeTrue
		$chartFileData -match 'appVersion:\s"2\.0\.0"' | Should -BeTrue
	}

	It 'should error on invalid app version' {

		. $mocks

		$chartFile = './setup/core/charts/codedx/Chart.yaml'
		{
			Set-HelmChartVersion -chartPath $chartFile -appVersion '2.0.0'
		} | Should -Throw 'Expected to find an appVersion number matching format v1.2.3 (not 2.0.0)'
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

Describe 'Set-ChartDockerImageValues' {

	It 'should set values (Code Dx)' {

		. $mocks

		$valuesFile = './setup/core/charts/codedx/values.yaml'
		Set-ChartDockerImageValues -valuesPath $valuesFile `
			([Tuple`3[string,string,string]]::new('codedxTomcatImage',     'codedx/codedx-tomcat', '2.0.0'),
			 [Tuple`3[string,string,string]]::new('codedxTomcatInitImage', 'codedx/codedx-bash',   '2.0.2'))
		
		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 1

		$data = $fileContent[$valuesFile]
		$data -match 'codedxTomcatImage:\s''codedx/codedx-tomcat:2\.0\.0''' | Should -BeTrue
		$data -match 'codedxTomcatInitImage:\s''codedx/codedx-bash:2\.0\.2''' | Should -BeTrue
	}

	It 'should set values (Code Dx Tool Orchestration)' {

		. $mocks

		$valuesFile = './setup/core/charts/codedx-tool-orchestration/values.yaml'
		Set-ChartDockerImageValues -valuesPath $valuesFile `
			([Tuple`3[string,string,string]]::new('imageNameCodeDxTools',      'codedx/codedx-tools',         '2.0.0'),
			 [Tuple`3[string,string,string]]::new('imageNameCodeDxToolsMono',  'codedx/codedx-toolsmono',     '2.0.0'),
			 [Tuple`3[string,string,string]]::new('imageNamePrepare',          'codedx/codedx-prepare',       '2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageNameNewAnalysis',      'codedx/codedx-newanalysis',   '2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageNameSendResults',      'codedx/codedx-results',       '2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageNameSendErrorResults', 'codedx/codedx-error-results', '2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageNameHelmPreDelete',    'codedx/codedx-cleanup',       '2.0.1'),
			 [Tuple`3[string,string,string]]::new('toolServiceImageName',      'codedx/codedx-tool-service',  '2.0.1'))
		
		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 1

		$data = $fileContent[$valuesFile]
		$data -match 'imageNameCodeDxTools:\s''codedx/codedx-tools:2\.0\.0''' | Should -BeTrue
		$data -match 'imageNameCodeDxToolsMono:\s''codedx/codedx-toolsmono:2\.0\.0''' | Should -BeTrue
		$data -match 'imageNamePrepare:\s''codedx/codedx-prepare:2\.0\.1''' | Should -BeTrue
		$data -match 'imageNameNewAnalysis:\s''codedx/codedx-newanalysis:2\.0\.1''' | Should -BeTrue
		$data -match 'imageNameSendResults:\s''codedx/codedx-results:2\.0\.1''' | Should -BeTrue
		$data -match 'imageNameSendErrorResults:\s''codedx/codedx-error-results:2\.0\.1''' | Should -BeTrue
		$data -match 'imageNameHelmPreDelete:\s''codedx/codedx-cleanup:2\.0\.1''' | Should -BeTrue
		$data -match 'toolServiceImageName:\s''codedx/codedx-tool-service:2\.0\.1''' | Should -BeTrue
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

Describe 'Set-ScriptDockerImageTags' {


	It 'should set parameters' {

		. $mocks

		$scriptPath = './setup/core/setup.ps1'
		Set-ScriptDockerImageTags -scriptPath $scriptPath `
			([Tuple`3[string,string,string]]::new('imageCodeDxTomcat',       'codedx/codedx-tomcat',              'v2.0.0'),
			 [Tuple`3[string,string,string]]::new('imageCodeDxTools',        'codedx/codedx-tools',               'v2.0.0'),
			 [Tuple`3[string,string,string]]::new('imageCodeDxToolsMono',    'codedx/codedx-toolsmono',           'v2.0.0'),
			 [Tuple`3[string,string,string]]::new('imageCodeDxTomcatInit',   'codedx/codedx-bash',                'v2.0.2'),
			 [Tuple`3[string,string,string]]::new('imageMariaDB',            'codedx/codedx-mariadb',             'v2.0.3'),
			 [Tuple`3[string,string,string]]::new('imagePrepare',            'codedx/codedx-prepare',             'v2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageNewAnalysis',        'codedx/codedx-newanalysis',         'v2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageSendResults',        'codedx/codedx-results',             'v2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageSendErrorResults',   'codedx/codedx-error-results',       'v2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageToolService',        'codedx/codedx-tool-service',        'v2.0.1'),
			 [Tuple`3[string,string,string]]::new('imagePreDelete',          'codedx/codedx-cleanup',             'v2.0.1'),
			 [Tuple`3[string,string,string]]::new('imageWorkflowController', 'codedx/codedx-workflow-controller', 'v2.0.4'),
			 [Tuple`3[string,string,string]]::new('imageWorkflowExecutor',   'codedx/codedx-argoexec',            'v2.0.4'))

		Assert-MockCalled -CommandName 'Get-Content' -Exactly 1
		Assert-MockCalled -CommandName 'Set-Content' -Exactly 1
	 
		$data = $fileContent[$scriptPath]
		$data -match '\$imageCodeDxTomcat\s+=\s+''codedx/codedx-tomcat:v2\.0\.0'',$' | Should -BeTrue
		$data -match '\$imageCodeDxTools\s+=\s+''codedx/codedx-tools:v2\.0\.0'',$' | Should -BeTrue
		$data -match '\$imageCodeDxToolsMono\s+=\s+''codedx/codedx-toolsmono:v2\.0\.0'',$' | Should -BeTrue
		$data -match '\$imageCodeDxTomcatInit\s+=\s+''codedx/codedx-bash:v2\.0\.2'',$' | Should -BeTrue
		$data -match '\$imageMariaDB\s+=\s+''codedx/codedx-mariadb:v2\.0\.3'',$' | Should -BeTrue
		$data -match '\$imagePrepare\s+=\s+''codedx/codedx-prepare:v2\.0\.1'',$' | Should -BeTrue
		$data -match '\$imageNewAnalysis\s+=\s+''codedx/codedx-newanalysis:v2\.0\.1'',$' | Should -BeTrue
		$data -match '\$imageSendResults\s+=\s+''codedx/codedx-results:v2\.0\.1'',$' | Should -BeTrue
		$data -match '\$imageSendErrorResults\s+=\s+''codedx/codedx-error-results:v2\.0\.1'',$' | Should -BeTrue
		$data -match '\$imageToolService\s+=\s+''codedx/codedx-tool-service:v2\.0\.1'',$' | Should -BeTrue
		$data -match '\$imagePreDelete\s+=\s+''codedx/codedx-cleanup:v2\.0\.1'',$' | Should -BeTrue
		$data -match '\$imageWorkflowController\s+=\s+''codedx/codedx-workflow-controller:v2\.0\.4'',$' | Should -BeTrue
		$data -match '\$imageWorkflowExecutor\s+=\s+''codedx/codedx-argoexec:v2\.0\.4'',$' | Should -BeTrue
	}

	BeforeEach {

		. ./.version/common.ps1
		. ./.version/test/mocks.ps1
	}
}

