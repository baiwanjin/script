#!/bin/bash
#校准服务器时间

NTP_SERVER_IP='10.200.195.253'
#日志文件
LOG_FILE=/var/log/set_time.log
CrontabList='/etc/crontablist'

check(){
    ping=`ping -c 3 $NTP_SERVER_IP|grep received |awk '{print $4}'`
    if [ $ping -eq 0 ]
    then
        echo "未连接到NTP服务端地址: $NTP_SERVER_IP !"
        exit 1
    fi
    if ! rpm -qa | grep ntpdate >/dev/null 2>&1
    then
        echo "未安装ntpdate程序，请安装！"
        exit 1
    fi
    if ! systemctl list-unit-files | grep crond.service >/dev/null 2>&1
    then
        echo "未找到crond.service服务，请确认！"
        exit 1
    fi
}

set_cron(){
    if grep '/usr/sbin/ntpdate' /etc/crontab >/dev/null 2>&1
    then
        \cp /etc/crontab /etc/crontab_`date +"%Y%m%d%H%M%S"`.bak
        sed -i '/\/usr\/sbin\/ntpdate/d' /etc/crontab
    fi
    if ! systemctl list-unit-files | grep crond.service | grep enable >/dev/null 2>&1
    then
        systemctl enable crond.service
    fi
    if grep "$CrontabList/set_time.sh" /var/spool/cron/root  >/dev/null 2>&1
    then
        echo "$CrontabList/set_time.sh任务已存在！"
    else
        test -d $CrontabList || mkdir -p $CrontabList
        cat > $CrontabList/set_time.sh <<EOF
#!/bin/bash
#校准服务器时间
log_info(){
    echo "\`date +"%Y-%m-%d %H:%M:%S"\` [INFO]: \$1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m \`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]: \$1 \033[0m"|tee -a $LOG_FILE
}

check(){
    ping=\`ping -c 3 $NTP_SERVER_IP|awk 'NR==7 {print \$4}'\`
    if [ \$ping -eq 0 ]
    then
        log_error "未连接到NTP服务端地址: $NTP_SERVER_IP !"
        exit 1
    fi
    if ! rpm -qa | grep ntpdate >/dev/null 2>&1
    then
        log_error "未安装ntpdate程序，请安装！"
        exit 1
    fi

}

set_timezone(){
    if ! timedatectl | grep "Time zone"|grep 'Asia/Shanghai' >/dev/null 2>&1
    then
        log_error "当前时区为:\`timedatectl | grep "Time zone"\`" 
        log_info '设置时区为: Asia/Shanghai '
        timedatectl set-timezone "Asia/Shanghai"
        log_info "当前时区为: \`timedatectl | grep "Time zone"\`"
    fi
}

set_date(){
    /usr/sbin/ntpdate $NTP_SERVER_IP && /sbin/hwclock -w && log_info "对时任务已执行。"
}

main(){
    check
    set_timezone
    set_date
}

main
EOF
        chmod +x $CrontabList/set_time.sh
        echo "0 1 * * * $CrontabList/set_time.sh"|tee -a /var/spool/cron/root
        echo "对时任务已启动！"
fi
    chmod +x $CrontabList/set_time.sh
    if ! grep "$CrontabList/set_time.sh" /etc/rc.d/rc.local
    then
        echo "$CrontabList/set_time.sh" | tee -a /etc/rc.d/rc.local
    fi
    chmod +x /etc/rc.d/rc.local
    systemctl restart crond.service
    systemctl enable rc-local.service
    systemctl enable crond.service
    $CrontabList/set_time.sh
}

main(){
    check
    set_cron
}
main