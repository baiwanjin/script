#!/bin/bash
#修复麒麟操作系统环境，SCADA系统下WindCore、Tomcat服务权限问题

SCADA_PATH='/home/data'
DATE=`date +"%Y%m%d%H%M%S"`
LOG_FILE=repair-service-$DATE.log
###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
}

#创建windeyapps组
create_group(){
    if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
    then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
        log_info "创建windeyapps组"
    fi
    usermod -G windeyapps root
    usermod -G windeyapps redis
    usermod -G windeyapps influxdb
    log_info "添加root、redis、influxdb用户到windeyapps组"
}

init_jar(){
    jarName=$1
	workDir=$2
	serverName=$3
	touch /var/log/${serverName}.log
	chown root:windeyapps /var/log/${serverName}.log
    cat >$workDir/$serverName.sh<<-EOF
#!/bin/bash
jarName="$jarName"
workDir="$workDir"
start(){
    cd \${workDir} && java -jar \${jarName} >> /var/log/${serverName}.log 2>&1 &
}

stop(){
    ps -ef | grep -qP "(?<=-jar)\s+\${jarName}" && kill \$(ps -ef | grep -P "(?<=-jar)\s+\${jarName}" | awk '{print \$2}')
}

case \$1 in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
esac
EOF
    chmod +x $workDir/$serverName.sh
    cat >$serverName.service<<-EOF
[Unit]
Description=java project
After=$serverName.service

[Service]
Type=forking
User=root
Group=windeyapps
WorkingDirectory=$workDir
ExecStart=/bin/bash $serverName.sh start
ExecStop=/bin/bash $serverName.sh stop
ExecReload=/bin/bash $serverName.sh restart
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    \cp $serverName.service /usr/lib/systemd/system/
	systemctl daemon-reload  && systemctl enable $serverName.service &&  systemctl start $serverName.service
}

reset_WindCore(){
    if test -d $SCADA_PATH/WindCore
    then

        init_jar 'WindCore.jar' "$SCADA_PATH/WindCore" 'windcore'
        sed -i '/\[Service\]/a\Environment="DISPLAY=:0.0"' /usr/lib/systemd/system/windcore.service
        cat > /usr/lib/systemd/system/windcore.timer <<EOF
[Unit]
Description=java project
[Timer]
OnBootSec=1min
Unit=windcore.service
[Install]
WantedBy=graphical.target
EOF
        sed -i '/autologin-user=root/d' /etc/lightdm/lightdm.conf
        sed -i "/greeter-hide-users=true/a autologin-user=root" /etc/lightdm/lightdm.conf
        systemctl daemon-reload &&  systemctl disable windcore.service &&  systemctl enable windcore.timer &&  systemctl start windcore.service
    fi

}

#Tomcat
reset_Tomcat(){
    if systemctl list-unit-files|grep tomcat  >/dev/null 2>&1
    then
        log_info '拷贝文件/usr/lib/systemd/system/tomcat.service为/usr/lib/systemd/system/tomcat.service-`date +"%Y%m%d%H%M%S"`.bak'
        \cp /usr/lib/systemd/system/tomcat.service /usr/lib/systemd/system/tomcat.service-`date +"%Y%m%d%H%M%S"`.bak
        # if ! grep -i '^ExecStartPre=' /usr/lib/systemd/system/tomcat.service  >/dev/null 2>&1
        # then
        #     if test -e '/home/data/windeybs/windeyapp/farmmonitoring.sh'
        #     then
        #         log_info '添加ExecStartPre=/home/data/windeybs/windeyapp/farmmonitoring.sh至文件/usr/lib/systemd/system/tomcat.service'
        #         sed -i '/\[Service\]/a\ExecStartPre=/home/data/windeybs/windeyapp/farmmonitoring.sh' /usr/lib/systemd/system/tomcat.service
        #         log_info '添加文件/usr/lib/systemd/system/tomcat.service的执行权限'
        #         chmod +x /home/data/windeybs/windeyapp/farmmonitoring.sh
        #     else
        #         log_error '/home/data/windeybs/windeyapp/farmmonitoring.sh未找到路径！'
        #     fi
        # fi

        if ! grep -i '^Group=' /usr/lib/systemd/system/tomcat.service  >/dev/null 2>&1
        then
            log_info '添加Group=windeyapps至/usr/lib/systemd/system/tomcat.service'
            sed -i '/\[Service\]/a\Group=windeyapps' /usr/lib/systemd/system/tomcat.service
        else
            log_info '将文件/usr/lib/systemd/system/tomcat.service中Group的值修改为windeyapps'
            sed -i 's/Group=.*/Group=windeyapps/g' /usr/lib/systemd/system/tomcat.service
        fi

        if ! grep -i '^User=' /usr/lib/systemd/system/tomcat.service  >/dev/null 2>&1
        then
            log_info '添加User=root至/usr/lib/systemd/system/tomcat.service'
            sed -i '/\[Service\]/a\User=root' /usr/lib/systemd/system/tomcat.service
        else
            log_info '将文件/usr/lib/systemd/system/tomcat.service中User的值修改为root'
            sed -i 's/User=.*/User=root/g' /usr/lib/systemd/system/tomcat.service
        fi
    fi
    systemctl daemon-reload && systemctl enable tomcat.service

}

