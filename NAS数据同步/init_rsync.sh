#!/bin/bash

NASNFSDIR='/volume1/Backup'
MOUNTDIR='/data'
CrontabList='/etc/crontablist'
#SCADA目录
scada_dir="('/home/data' '/etc/crontablist' '/etc/influxdb' '/var/spool/cron/root' )"
#能管目录
ems_dir="('/home/data' '/etc/crontablist' '/var/spool/cron/root' '/opt')"
#SCADA同步目录
scada_backup_dir="$MOUNTDIR/scada"
#能管同步目录
ems_backup_dir="$MOUNTDIR/ems"
#规则
eliminate_rule='{}'

#时间戳
DATE=`/usr/bin/date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=rsync-$DATE.log


#需要开放的端口
UdpPorts=(2049)
TcpPorts=(2049)

###
#log
###
log_info(){
    /usr/bin/echo "`/usr/bin/date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|/usr/bin/tee -a $LOG_FILE
}

log_error(){
    /usr/bin/echo -e "`/usr/bin/date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|/usr/bin/tee -a $LOG_FILE
}


#运行前检测
check(){
    if /usr/bin/df -Th |grep $MOUNTDIR >/dev/null 2>&1 
    then
        log_error "$MOUNTDIR目录已存在，请确认！"
        exit 1
    fi

}

#挂载目录
mount_dir(){
    echo  $NFSServerIP
    if ! /usr/sbin/showmount -e $NFSServerIP|grep $NASNFSDIR >/dev/null 2>&1
    then
        log_error "服务器:$NFSServerIP不存在共享目录$NASNFSDIR"
        exit 1
    fi
    /usr/bin/mkdir -p $MOUNTDIR
    /usr/bin/mount -t nfs -o rw,tcp,soft,timeo=5 $NFSServerIP:$NASNFSDIR $MOUNTDIR
    if ! /usr/bin/grep "^$NFSServerIP:$NASNFSDIR" /etc/fstab >/dev/null 2>&1
    then
        /usr/bin/echo "$NFSServerIP:$NASNFSDIR $MOUNTDIR    nfs    defaults,_netdev    0  0"|/usr/bin/tee -a /etc/fstab
    fi
}


add_firewall_rules(){
    for TcpPort in ${TcpPorts[*]}
    do
	    if /usr/bin/firewall-cmd --query-port=${TcpPort}/tcp|/usr/bin/grep "^no"
	    then
	        log_info "添加TCP端口:${TcpPort}到防火墙"
            /usr/bin/firewall-cmd --add-port=${TcpPort}/tcp --permanent
	    fi
    done
    for UdpPort in ${UdpPorts[*]}
    do
	    if /usr/bin/firewall-cmd --query-port=${UdpPort}/udp|/usr/bin/grep "^no"
	    then
	        log_info "添加UDP端口:${TcpPort}到防火墙"
	        /usr/bin/firewall-cmd --add-port=${UdpPort}/udp --permanent
        fi
	done
    /usr/bin/firewall-cmd --reload
}

scada_backup(){
    /usr/bin/test -d $CrontabList || /usr/bin/mkdir -p $CrontabList
    cat > $CrontabList/data_backup.sh << EOF
#!/bin/bash
/usr/bin/test -d $scada_backup_dir || /usr/bin/mkdir -p $scada_backup_dir
scada_dir=$scada_dir
DATE=\`/usr/bin/date +"%Y%m%d%H%M%S"\`
if ! /usr/bin/df -Th | /usr/bin/grep $MOUNTDIR >/dev/null 2>&1 
then
    /usr/bin/echo "$MOUNTDIR目录股挂载异常，请确认！" | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
    exit 1
fi
for dir in \${scada_dir[*]}
do
    data_dir=$scada_backup_dir/\${dir%/*}
    mkdir -p \$data_dir
    /usr/bin/echo "同步\$dir目录" | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
    /usr/bin/rsync -tagopvP --delete --exclude=\$eliminate_rule \$dir \$data_dir/ | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
    /usr/bin/echo "\$dir目录完成" | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
done
EOF
    chmod +x  $CrontabList/data_backup.sh 
    if ! grep 'data_backup.sh'  /var/spool/cron/root >/dev/null 2>&1;then echo '10 3 * * *  '$CrontabList'/data_backup.sh' >>  /var/spool/cron/root;fi
}
ems_backup(){
    /usr/bin/test -d $CrontabList || /usr/bin/mkdir -p $CrontabList
    cat > $CrontabList/data_backup.sh << EOF
#!/bin/bash
/usr/bin/test -d $ems_backup_dir || /usr/bin/mkdir -p $sems_backup_dir
ems_dir=$ems_dir
DATE=\`/usr/bin/date +"%Y%m%d%H%M%S"\`
if ! /usr/bin/df -Th | /usr/bin/grep $MOUNTDIR >/dev/null 2>&1 
then
    /usr/bin/echo "$MOUNTDIR目录股挂载异常，请确认！" | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
    exit 1
fi
for dir in \${ems_dir[*]}
do
    if test -d \$dir 
    then
        data_dir=$scada_backup_dir/\${dir%/*}
        mkdir -p \$data_dir
        /usr/bin/echo "同步\$dir目录" | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
        /usr/bin/rsync  -vurtopg --progress --delete --exclude=\$eliminate_rule \$dir  \$data_dir/ | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
        /usr/bin/echo "\$dir目录完成" | /usr/bin/tee -a /var/log/nasbackup_\$DATE.log
    fi
done
EOF
    chmod +x  $CrontabList/data_backup.sh 
    if ! grep 'data_backup.sh'  /var/spool/cron/root >/dev/null 2>&1;then echo '10 3 * * *  '$CrontabList'/data_backup.sh' >>  /var/spool/cron/root;fi
}
login(){
    while true
    do
        /usr/bin/echo "请您输入NAS备份服务器的地址: "
        read NFSServerIP
        if ! /usr/bin/echo $NFSServerIP | /usr/bin/grep -E "^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$">/dev/null 2>&1
        then
            /usr/bin/echo -e "\033[31m 您输入的IP地址:$NFSServerIP 格式有误！ \033[0m"
            continue
        fi
        break
    done
}

main(){

    case $1 in
    scada)
        check
        login
        add_firewall_rules
        mount_dir
        scada_backup
        ;;
    ems)
        check
        login
        add_firewall_rules
        mount_dir
        ems_backup
        ;;
    cms)
        echo "待维护"
        ;;

    *)
        echo "请选择检测系统类型"
        echo "init_rsync.sh scada 检测SCADA主机部署状态"
        echo "init_rsync.sh ems 检测能管主机部署状态"
        echo "init_rsync.sh cms 检测CMS主机部署状态"
        ;;
    esac

}
main $1