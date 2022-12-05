#!/bin/bash
logs=('cron' ' messages' 'memory.log')
if [ -f "/root/.cache/gdm/session.log" ];then
    cat /dev/null > /root/.cache/gdm/session.log
fi

if [ -f "/root/.cache/gdm/session.log.old" ];then
    cat /dev/null > /root/.cache/gdm/session.log.old
fi

if ls /home/data/wind_2*.bak >/dev/null 2>&1
then
    find /home/data -maxdepth 1 -name "wind_2*.bak" -mtime +31 -exec rm -rf {} \;
fi

if test -d /home/data/WindCore/logs/ 
then
    find /home/data/WindCore/logs -maxdepth 1 -name "log.2*.log" -mtime +31 -exec rm -rf {} \;
fi

rm -rf /root/.Syncovery/Logs/*
rm -rf /etc/.Syncovery/Logs/*

rm -rf /home/.Trash-0/files/*
rm -rf /home/.Trash-0/info/*

rm -f /home/data/WindCore/nohup.out

if [ -d "/usr/local/tomcat" ];then
    find /usr/local/tomcat/temp/* -maxdepth 0 ! -name "safeToDelete.tmp" -exec rm -rf {} \;
    if [ -f "/usr/local/tomcat/logs/catalina.out" ];then
        cat /dev/null > /usr/local/tomcat/logs/catalina.out
    fi
    find /usr/local/tomcat/logs -maxdepth 1 -name "catalina.2*.log" -exec rm -rf {} \;
fi

apachepath=$(find /usr/local -maxdepth 1 -name "apache-tomcat-*" -type d)
if [ "${apachepath}" != "" ];then
    find $apachepath/temp/* -maxdepth 0 ! -name "safeToDelete.tmp" -exec rm -rf {} \;
    if [ -f "$apachepath/logs/catalina.out" ];then
        cat /dev/null > $apachepath/logs/catalina.out
    fi
    find $apachepath/logs -maxdepth 1 -name "catalina.2*.log" -exec rm -rf {} \;
fi

for i in `find / ! -path "/prco/*" -type f  -name ".xsession-errors*"`
do
    chattr -a $i
	echo " " > $i
    chattr +a $i
done	     

if test -d /.Syncovery/Logs/
then
    find /.Syncovery/Logs/ -mtime +31 -name "*.log" -exec rm -rf {} \;
fi

if test -d /home/data/HisDataLog/
then
    find /home/data/HisDataLog/ -mtime +365 -name "*.csv*" -exec rm -rf {} \;
fi

if test -d /home/data/HisDataLog_RT/
then
    find /home/data/HisDataLog_RT/ -mtime +3 -name "*.csv*" -exec rm -rf {} \;
fi

for i in ${logs[*]}
do
    chattr -a /var/log/$i
	zip -v -r /var/log/$i-`date +"%Y%m%d"`.zip /var/log/$i
	echo "" > /var/log/$i
	chattr +a /var/log/$i
done

find /var/log/ -mtime +31 -name "*.zip" -o -name "*.gz" |xargs rm -rf
