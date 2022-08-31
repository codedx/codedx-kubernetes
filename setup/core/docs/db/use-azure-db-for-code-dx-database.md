# Use Azure Database for MariaDB for your Code Dx database

Here are the steps required to use Code Dx with an external database hosted with Azure Database:

>Note: Code Dx currently requires [MariaDB version 10.3.x](https://mariadb.com/kb/en/release-notes-mariadb-103-series/).

1) Your new MariaDB database instance must use a configuration that's compatible with Code Dx. After provisioning a new database instance, open `Server parameters` (under Settings), specify the following parameter values, and click Save:

    - optimizer_search_depth=0
    - character_set_server=UTF8MB4
    - collation_server=UTF8MB4_GENERAL_CI
    - lower_case_table_names=1
    - log_bin_trust_function_creators=ON

        The log_bin_trust_function_creators parameter is required when using MariaDB SQL replication (`Replication` under Settings).

2) Open `Connection security` (under Settings) and configure the firewall to permit remote database connections from your cluster and any other hosts from which you'll access your Code Dx database.

3) Connect to your database instance. When using SSL, download the [required certificate](https://docs.microsoft.com/en-us/azure/mariadb/concepts-ssl-connection-security#default-settings).

   mysql -h database-hostname --ssl-ca=/path/to/cert -u admin-username -p

4) Create a database user for Code Dx. You can customize the following statement to create
   a Code Dx database user named codedx (remove 'REQUIRE SSL' when not using TLS, which is enabled by default).

   CREATE USER 'codedx'@'%' IDENTIFIED BY 'enter-a-password-here' REQUIRE SSL;

5) Create a Code Dx database. The following statement creates a Code Dx database named codedxdb.

   CREATE DATABASE codedxdb;

6) Grant required privileges on the Code Dx database to the database user you created. The
   following statements grant permissions to the codedx database user.

   GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, ALTER, REFERENCES, INDEX, DROP, TRIGGER ON codedxdb.* to 'codedx'@'%';
   FLUSH PRIVILEGES;
