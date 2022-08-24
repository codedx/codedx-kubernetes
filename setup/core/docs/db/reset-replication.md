# Reset MariaDB Replication for your Code Dx database

Here are the steps that use four terminal windows to reset MariaDB database replication (when not using an external database):

>Note: The instructions assume two statefulsets named codedx-mariadb-master and codedx-mariadb-slave in the cdx-app namespace with one subordinate database.

Terminal 1 (Subordinate DB):

1.	kubectl -n cdx-app exec -it codedx-mariadb-slave-0 -- bash
2.	mysql -uroot -p
3.	STOP SLAVE;
4.	exit # mysql

Terminal 2 (Master DB):

5.	kubectl -n cdx-app exec -it codedx-mariadb-master-0 -- bash
6.	mysql -uroot -p
7.	RESET MASTER;
8.	FLUSH TABLES WITH READ LOCK;

Terminal 3 (Master DB):

9.	kubectl -n cdx-app exec -it codedx-mariadb-master-0 -- bash
10.	mysqldump -u root -p codedx > /tmp/codedx-dump.sql

Terminal 2 (Master DB)

11.	UNLOCK TABLES;

Terminal 4:

12.	kubectl -n cdx-app cp codedx-mariadb-master-0:/tmp/codedx-dump.sql ./codedx-dump.sql
13.	kubectl -n cdx-app cp ./codedx-dump.sql codedx-mariadb-slave-0:/bitnami/mariadb/codedx-dump.sql

Terminal 1 (Subordinate DB):

14.	mysql -u root -p codedx < /bitnami/mariadb/codedx-dump.sql
15.	mysql -uroot -p
16.	RESET SLAVE;
17.	CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=1;
18.	START SLAVE;
19.	SHOW SLAVE STATUS \G;
20.	exit # mysql
21.	rm /bitnami/mariadb/codedx-dump.sql
22.	exit # pod
23.	exit # terminal

Terminal 2 (Master DB):

24.	exit # mysql
25.	rm /tmp/codedx-dump.sql
26.	exit # pod
27.	exit # terminal

Terminal 3 (Master DB):

28.	exit # pod
29.	exit # terminal

Terminal 4:

30.	exit # terminal

