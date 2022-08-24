# Reset MariaDB Replication for your Code Dx database

Here are the steps that use four terminal windows to reset MariaDB database replication (when not using an external database):

>Note: The instructions assume two statefulsets named codedx-mariadb-master and codedx-mariadb-slave and a deployment named codedx in the cdx-app namespace with one subordinate database. 

Terminal 1 (Subordinate DB):

1.	kubectl -n cdx-app scale --replicas=0 deployment/codedx
2.	kubectl -n cdx-app exec -it codedx-mariadb-slave-0 -- bash
3.	mysql -uroot -p
4.	STOP SLAVE;
5.	exit # mysql

Terminal 2 (Master DB):

6.	kubectl -n cdx-app exec -it codedx-mariadb-master-0 -- bash
7.	mysql -uroot -p
8.	RESET MASTER;
9.	FLUSH TABLES WITH READ LOCK;

Terminal 3 (Master DB):

10.	kubectl -n cdx-app exec -it codedx-mariadb-master-0 -- bash
11.	mysqldump -u root -p codedx > /bitnami/mariadb/codedx-dump.sql

>Note: The above command assumes you have adequate space at /bitnami/mariadb to store your database backup. Use an alternate path as necessary, and adjust paths in subsequent steps accordingly.

Terminal 2 (Master DB)

12.	UNLOCK TABLES;

Terminal 4:

13.	kubectl -n cdx-app cp codedx-mariadb-master-0:/bitnami/mariadb/codedx-dump.sql ./codedx-dump.sql
14.	kubectl -n cdx-app cp ./codedx-dump.sql codedx-mariadb-slave-0:/bitnami/mariadb/codedx-dump.sql

Terminal 1 (Subordinate DB):

15.	mysql -u root -p codedx < /bitnami/mariadb/codedx-dump.sql
16.	mysql -uroot -p
17.	RESET SLAVE;
18.	CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=1;
19.	START SLAVE;
20.	SHOW SLAVE STATUS \G;
21.	exit # mysql
22.	rm /bitnami/mariadb/codedx-dump.sql
23.	exit # pod
24.	exit # terminal

Terminal 2 (Master DB):

25.	exit # mysql
26.	rm /bitnami/mariadb/codedx-dump.sql
27.	exit # pod
28.	exit # terminal

Terminal 3 (Master DB):

29.	exit # pod
30.	exit # terminal

Terminal 4:

31.	exit # terminal

