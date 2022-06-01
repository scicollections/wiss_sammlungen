30 04 * * 0 [UNIX_USER] mysql --defaults-file=[PATH_TO_MAYA]/setup/maya-mysql.cnf < [PATH_TO_MAYA]/setup/maya-mysql-optimisation.sql >> [PATH_TO_MAYA]/log/maya-mysql-optimization.log

# [UNIX_USER] = user running the command 
# [PATH_TO_MAYA] = path to maya rails installation
