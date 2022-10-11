# Use an External MariaDB instance for your Code Dx database

Here are the steps required to use Code Dx with an external database:

>Note: Code Dx currently requires [MariaDB version 10.6.x](https://mariadb.com/kb/en/release-notes-mariadb-106-series/).

1) Create a database user for Code Dx. You can customize the following statement to create
   a Code Dx database user named codedx (remove 'REQUIRE SSL' when not using TLS).

   CREATE USER 'codedx'@'%' IDENTIFIED BY 'enter-a-password-here' REQUIRE SSL;

2) Apply any database configuration changes necessary to allow remote database connections. 

3) Create a Code Dx database. The following statement creates a Code Dx database named codedxdb.

   CREATE DATABASE codedxdb;

4) Grant required privileges on the Code Dx database to the database user you created. The
   following statements grant permissions to the codedx database user.

   GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, ALTER, REFERENCES, INDEX, DROP, TRIGGER ON codedxdb.* to 'codedx'@'%';
   FLUSH PRIVILEGES;

5) Set the following MariaDB variables. Failure to complete this step will negatively affect Code Dx performance or functionality.

```
[mysqld]
optimizer_search_depth=0
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
lower_case_table_names=1
log_bin_trust_function_creators=1
```

>Note: The log_bin_trust_function_creators parameter is required when using MariaDB SQL replication.

6) Restart your MariaDB instance.
