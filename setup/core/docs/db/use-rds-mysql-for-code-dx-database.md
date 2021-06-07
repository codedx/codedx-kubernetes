# Use Amazon RDS with MySQL engine for your Code Dx database

Code Dx recommends using an RDS database instance with the [MariaDB database engine](use-rds-for-code-dx-database.md), but these instructions are here to support those who are unable to use MariaDB.

1) Your new MySQL RDS database instance must use a configuration that's compatible with Code Dx. Follow the [Create a DB Parameter Group instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html#USER_WorkingWithParamGroups.Creating) to create a new DB Parameter Group named codedx-mysql-recommendation. Then edit the parameters of your new group by using the [Modifying Parameters in a DB Parameter Group instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html#USER_WorkingWithParamGroups.Modifying) to set the following parameter values:

- optimizer_search_depth=0
- character_set_server=utf8mb4
- collation_server=utf8mb4_general_ci
- lower_case_table_names=1
- log_bin_trust_function_creators=1

>Note: When editing a parameter value, the column to the right of the edit box shows the allowable values (not the current values).

The log_bin_trust_function_creators parameter is required when using MariaDB SQL replication, which is enabled by default with the AWS MariaDB Production template.

2) Provision a new Amazon RDS MySQL database instance with the codedx-mysql-recommendation DB Parameter Group by following the [installation instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html).
