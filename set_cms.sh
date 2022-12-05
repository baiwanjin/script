#!/bin/sh
if ! grep "pid-file=" /etc/my.cnf
then
    echo "pid-file=/var/run/mysql/mysql.pid"|tee -a  /etc/my.cnf
    mkdir -p /var/run/mysql/ && chown mysql:mysql /var/run/mysql/
fi 


sed -i '/setpasswd.sh/d' /var/spool/cron/root 