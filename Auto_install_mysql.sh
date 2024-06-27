#!/bin/bash
#20210122 by xjp

pro=$(ps aux | grep  mysqld_safe | grep -v grep) 
if [[ -n $pro ]];then
        echo 'MySQL already exists, please check!!!'
        exit
fi

input=""
read -p "Enter the Mysql packet path : " input
cd $input

file=$(find mysql*.tar.gz | sed 's#.*/##')

echo 'Start Install MySQL...'
tar -zvxf $file  -C  /usr/local
cd /usr/local
file1=${file:0:12}
mv $file1*  mysql

groupadd mysql
useradd -r -g mysql mysql
mkdir -p /data/mysqldata
chown -R root.mysql /usr/local/mysql
cp -r /usr/local/mysql/support-files/mysql.server /etc/rc.d/init.d/mysqld

echo 'export PATH=$PATH:/usr/local/mysql/bin'  >> /etc/profile
sleep 2
source /etc/profile
sed -i '/SELINUX/s/enforcing/disabled/'  /etc/selinux/config
echo '* soft nofile 65535'  >> /etc/security/limits.conf
echo '* hard nofile 65535'  >> /etc/security/limits.conf

cat > /etc/my.cnf << EOF
[mysqld]
 server_id=1
 basedir = /usr/local/mysql
 datadir= /data/mysqldata
 socket=/tmp/mysql.sock
 port = 3306
 back_log = 3000
 max_connections = 1000
 max_user_connections = 1000
 character_set_server = utf8
 collation_server=utf8_unicode_ci
 skip_name_resolve
 log_timestamps =system
 skip_ssl
 symbolic-links=0
 lower_case_table_names=1
 max_allowed_packet = 1024M
 query_cache_size = 0
 query_cache_type = 0
 master_info_repository = table
 relay_log_info_repository = table

#innodb
 innodb_file_per_table=1
 innodb_buffer_pool_size = 5G
 innodb_log_file_size = 1024M
 innodb_log_buffer_size = 16M
 innodb_flush_method =O_DIRECT
 innodb_io_capacity =600
 innodb_io_capacity_max =1000
 innodb_flush_log_at_trx_commit =1
 innodb_read_io_threads=4
 innodb_write_io_threads=4
 
 innodb_data_file_path= ibdata1:512M:autoextend
 innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G

 innodb_undo_directory =/data/mysqldata
 innodb_max_undo_log_size = 100M
 innodb_undo_log_truncate = ON
 innodb_undo_logs = 128
 innodb_undo_tablespaces = 3
 innodb_purge_rseg_truncate_frequency = 10

#monitor
 innodb_monitor_enable =log_lsn_checkpoint_age,log_max_modified_age_async

#log
 binlog-format=ROW
 binlog_cache_size=256K
 log-bin=mysql_binlog
 relay_log=mysql-relay-bin
 log-error=mysqld.log
 slow_query_log = on
 long_query_time = 5
 slow_query_log_file =mysql_slow_log
 log_queries_not_using_indexes=1
 binlog_rows_query_log_events=1
 expire_logs_days=30
#global log_bin_trust_function_creators =1

pid-file=/data/mysqldata/mysqld.pid
 
secure_file_priv=

sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'

[mysql]
no_auto_rehash
prompt = [\\u@\\p][\\d]>\\_

[client]
socket=/tmp/mysql.sock

EOF

echo '初始化mysql...'
cd /usr/local/mysql && /usr/local/mysql/bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql/ --datadir=/data/mysqldata/
sleep 10
cat /data/mysqldata/mysqld.log

pass=`grep 'generated'  /data/mysqldata/mysqld.log | awk '{print $NF}'`

service mysqld start

mysql -uroot -p$pass --connect-expired-password 2>/dev/null -e "set password=password('123456');"
if [[ $? -eq 0 ]];then
        echo 'mysql修改密码成功,password=123456'
else
        echo 'mysql修改密码失败...'
fi 

mysql -uroot -p123456  2>/dev/null -e "grant all privileges on *.* to root@'%' identified by '888888';" 
if [[ $? -eq 0 ]];then
        echo '新建远程用户成功,user=root,pwd=888888'
else
        echo '新建远程用户失败...'
fi

mysql -uroot -p123456 2>/dev/null -e 'flush privileges;'
if [[ $? -eq 0 ]];then
        echo $file1 'Install Success!'
else
        echo '刷新权限失败...'
fi