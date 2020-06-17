# Use Amazon RDS with MariaDB engine for your Code Dx database

Provision a new Amazon RDS database instance using the MariaDB database engine by following the [installation instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_SettingUp.html).

Before using your new database, you must make it compatible with Code Dx by adjusting its configuration. Follow the [Create a DB Parameter Group instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html#USER_WorkingWithParamGroups.Creating) to create a new DB Parameter Group named codedx-recommendations. Then edit the parameters of your new group by using the [Modifying Parameters in a DB Paramete Group instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithParamGroups.html#USER_WorkingWithParamGroups.Modifying) to set the following parameter values:

- optimizer_search_depth=0
- character_set_server=utf8mb4
- collation_server=utf8mb4_general_ci
- double check that the sql_mode parameter includes neither ONLY_FULL_GROUP_BY nor PAD_CHAR_TO_FULL_LENGTH.

>Note: When editing a parameter value, the column to the right of the edit box shows the allowable values (not the current values).

Assign the codedx-recommendations DB Parameter Group to your MariaDB database instance by following the [Modifying an Amazon RDS DB Instance instructions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBInstance.Modifying.html), and then [stop](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StopInstance.html) and [start](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StartInstance.html) your database instance to apply the changes.


