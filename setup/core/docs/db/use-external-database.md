# Use an External MariaDB instance for your Code Dx database

Here are the steps required to use Code Dx with an external database:

1) Create a database user for Code Dx. You can customize the following statement to create
   a Code Dx database user named codedx (remove 'REQUIRE SSL' when not using TLS).

   CREATE USER 'codedx'@'%' IDENTIFIED BY 'enter-a-password-here' REQUIRE SSL;

2) Apply any database configuration changes necessary to allow remote database connections. 

3) Create a Code Dx database. The following statement creates a Code Dx database named codedxdb.

   CREATE DATABASE codedxdb;

4) Grant required privileges on the Code Dx database to the database user you created. The
   following statements grant permissions to the codedx database user.

   GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, REFERENCES, INDEX, DROP, TRIGGER ON codedxdb.* to 'codedx'@'%';
   FLUSH PRIVILEGES;

5) Set the optimizer_search_depth database variable to 0, the character set to utf8mb4, and the collation to
   utf8mb4_general_ci with the below configuration. Failure to complete this step will negatively affect Code Dx
   performance or functionality.

```
[mysqld]
optimizer_search_depth=0
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
lower_case_table_names=1
```
