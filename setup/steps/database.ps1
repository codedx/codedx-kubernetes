'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseExternalDatabase : Step {

	static [string] hidden $description = @'
The Code Dx setup script can deploy a MariaDB database on your cluster, or 
you can choose to use your own database instance to host the Code Dx database. 

When using your own database, you must provide the database server, 
database catalog, and a database username and password. You must also 
provide a certificate for your database CA if you want to use TLS to 
secure the communication between Code Dx and your database (recommended).

To use AWS RDS with MariaDB engine, follow these instructions:
https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/db/use-rds-for-code-dx-database.md

To use Azure Database for MariaDB, follow these instructions:
https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/db/use-azure-db-for-code-dx-database.md

Otherwise, follow these instructions to create your Code Dx database:
https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/db/use-external-database.md
'@

	UseExternalDatabase([ConfigInput] $config) : base(
		[UseExternalDatabase].Name, 
		$config,
		'External Database',
		[UseExternalDatabase]::description,
		'Do you want to host your Code Dx database on an external database server that you provide?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, I want to use a database that I will provide', 
			'No, I want to use the database that Code Dx deploys on Kubernetes', 1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipDatabase = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.skipDatabase = $false
	}
}

class ExternalDatabaseHost : Step {

	static [string] hidden $description = @'
Specify the external database host that you are using to host your Code Dx 
database. If you're using an AWS RDS database, your host will have a name like
server.region.rds.amazonaws.com.
'@

	ExternalDatabaseHost([ConfigInput] $config) : base(
		[ExternalDatabaseHost].Name, 
		$config,
		'External Database Host',
		[ExternalDatabaseHost]::description,
		'Enter the name of your external database host') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalDatabaseHost = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalDatabaseHost = ''
	}

	[bool]CanRun() {
		return $this.config.skipDatabase
	}
}

class ExternalDatabasePort : Step {

	static [string] hidden $description = @'
Specify the port that your external database host is listening to for incoming 
connections. 

Note: The default port for MariaDB is 3306, so enter that value if you haven't 
changed MariaDB's configuration.
'@

	ExternalDatabasePort([ConfigInput] $config) : base(
		[ExternalDatabasePort].Name, 
		$config,
		'External Database Port',
		[ExternalDatabasePort]::description,
		'Enter the port number for your external database host') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object IntegerQuestion($prompt, 0, 65535, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalDatabasePort = ([IntegerQuestion]$question).intResponse
		return $true
	}

	[void]Reset(){
		$this.config.externalDatabasePort = [ConfigInput]::externalDatabasePortDefault
	}

	[bool]CanRun() {
		return $this.config.skipDatabase
	}
}

class ExternalDatabaseName : Step {

	static [string] hidden $description = @'
Specify the name of the Code Dx database you previously created on your 
external database server. For example, enter codedxdb if you previously ran 
a CREATE DATABASE statement with that name during the Code Dx external 
database setup instructions.
'@

	ExternalDatabaseName([ConfigInput] $config) : base(
		[ExternalDatabaseName].Name, 
		$config,
		'External Database Name',
		[ExternalDatabaseName]::description,
		'Enter the name of your Code Dx database or press Enter to accept the default (codedxdb)') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$q = [Question]$question
		$this.config.externalDatabaseName = $q.isResponseEmpty ? 'codedxdb' : $q.response
		return $true
	}

	[void]Reset(){
		$this.config.externalDatabaseName = ''
	}

	[bool]CanRun() {
		return $this.config.skipDatabase
	}
}

class ExternalDatabaseUser : Step {

	static [string] hidden $description = @'
Specify the username for the user with access to your Code Dx database. For 
example, enter codedx if you previously ran a CREATE USER statement with that 
name during the Code Dx external database setup instructions.
'@

	ExternalDatabaseUser([ConfigInput] $config) : base(
		[ExternalDatabaseUser].Name, 
		$config,
		'External Database Username',
		[ExternalDatabaseUser]::description,
		'Enter the Code Dx database username or press Enter to accept the default (codedx)') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$q = [Question]$question
		$this.config.externalDatabaseUser = $q.isResponseEmpty ? 'codedx' : $q.response
		return $true
	}

	[void]Reset(){
		$this.config.externalDatabaseUser = ''
	}

	[bool]CanRun() {
		return $this.config.skipDatabase
	}
}

class ExternalDatabasePwd : Step {

	static [string] hidden $description = @'
Specify the password for the user with access to your Code Dx database. Enter
the password you specified with the IDENTIFIED BY portion of the CREATE USER 
statement you ran during the Code Dx external database setup instructions.
'@

	ExternalDatabasePwd([ConfigInput] $config) : base(
		[ExternalDatabasePwd].Name, 
		$config,
		'External Database Password',
		[ExternalDatabasePwd]::description,
		'Enter the Code Dx database password') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalDatabasePwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalDatabasePwd = ''
	}

	[bool]CanRun() {
		return $this.config.skipDatabase
	}
}

class ExternalDatabaseOneWayAuth : Step {

	static [string] hidden $description = @'
Specify whether you want to enable two-way encryption with server-side 
certificate authentication so that you can protect the communicaitons 
between Code Dx and your database server.

Note: To enable this option, you must have access to the certificate 
associated with your database CA.
'@

	ExternalDatabaseOneWayAuth([ConfigInput] $config) : base(
		[ExternalDatabaseOneWayAuth].Name, 
		$config,
		'External Database Authentication',
		[ExternalDatabaseOneWayAuth]::description,
		'Use one-way server-side authentication to protect your database connection with TLS?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, I have a CA certificate and want to configure TLS for database connections',
			'No, I do not want to configure TLS', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalDatabaseSkipTls = ([YesNoQuestion]$question).choice -eq 1
		return $true
	}	

	[void]Reset(){
		$this.config.externalDatabaseSkipTls = $false
	}

	[bool]CanRun() {
		return $this.config.skipDatabase
	}
}

class ExternalDatabaseCert : Step {

	static [string] hidden $description = @'
Specify a file path to the CA associated with your database host.

If you're using an AWS RDS database, you can download the 
root certificate from the following URL:
https://s3.amazonaws.com/rds-downloads/rds-ca-2019-root.pem. 

If you're using an Azure Database, use the following URL to locate 
the certificate download link:
https://docs.microsoft.com/en-us/azure/mariadb/concepts-ssl-connection-security#default-settings
'@

	ExternalDatabaseCert([ConfigInput] $config) : base(
		[ExternalDatabaseCert].Name, 
		$config,
		'External Database Cert',
		[ExternalDatabaseCert]::description,
		'Enter path to certificate to the certificate of your database CA') {}
	
	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object CertificateFileQuestion($prompt, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalDatabaseServerCert = ([CertificateFileQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalDatabaseServerCert = ''
	}

	[bool]CanRun() {
		return $this.config.skipDatabase -and -not $this.config.externalDatabaseSkipTls
	}
}

class DatabaseRootPwd : Step {

	static [string] hidden $description = @'
Specify the password for the MariaDB root user that the Code Dx setup script 
will create when provisioning the MariaDB database.
'@

	DatabaseRootPwd([ConfigInput] $config) : base(
		[DatabaseRootPwd].Name, 
		$config,
		'Database Root Password',
		[DatabaseRootPwd]::description,
		'Enter a password for the MariaDB root user') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.blacklist = @("'")
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.mariadbRootPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.mariadbRootPwd = ''
	}
}

class DatabaseReplicationPwd : Step {

	static [string] hidden $description = @'
Specify the password for the MariaDB replication user that the Code Dx setup script 
will create when provisioning the MariaDB database.
'@

	DatabaseReplicationPwd([ConfigInput] $config) : base(
		[DatabaseReplicationPwd].Name, 
		$config,
		'Database Replication Password',
		[DatabaseReplicationPwd]::description,
		'Enter a password for the MariaDB replicator user') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.blacklist = @("'")
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.mariadbReplicatorPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.mariadbReplicatorPwd = ''
	}
}

class DatabaseUserPwd : Step {

	static [string] hidden $description = @'
Specify the password for the 'codedx' database user account that the Code Dx 
setup script will create for the Code Dx application to access the 'codedx' 
database.
'@

	DatabaseUserPwd([ConfigInput] $config) : base(
		[DatabaseUserPwd].Name, 
		$config,
		'Code Dx Database User Password',
		[DatabaseUserPwd]::description,
		"Enter a password for the 'codedx' database user account") {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.codedxDatabaseUserPwd = ([ConfirmationQuestion]$question).response
		$this.config.skipUseRootDatabaseUser = $true
		return $true
	}

	[void]Reset(){
		$this.config.codedxDatabaseUserPwd = ''
		$this.config.skipUseRootDatabaseUser = $false
	}
}

class DatabaseReplicaCount : Step {

	static [string] hidden $description = @'
Specify the number of subordinate, read-only databases that will use MariaDB 
data replication to store a copy of the MariaDB master database.

Note: You must specify at least one replica to configure Code Dx backups 
later on. Otherwise, you must back up the Code Dx database on your own at a 
time that's compatible with the Code Dx backup schedule.
'@

	DatabaseReplicaCount([ConfigInput] $config) : base(
		[DatabaseReplicaCount].Name, 
		$config,
		'Database Replicas',
		[DatabaseReplicaCount]::description,
		'Enter the number of database replicas') {}
	
	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object IntegerQuestion($prompt, 0, 5, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.dbSlaveReplicaCount = ([IntegerQuestion]$question).intResponse
		return $true
	}

	[void]Reset(){
		$this.config.dbSlaveReplicaCount = 1
	}
}