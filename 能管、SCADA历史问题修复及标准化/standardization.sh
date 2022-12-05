#!/bin/bash

#技术中心@白万进
#20220919
CrontabList='/etc/crontablist'

DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=standardization-$DATE.log

# services=(redis postgres WindCore postgresql-12 WindManagerBS WindSeer WindSine influxdb mongodb)
###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|tee -a $LOG_FILE
}
#——————————————————————————————————————————服务的优化———————————————————————————————————————————————
#——————————————————————————————————————————  SCADA  ———————————————————————————————————————————————
#服务列表
#1)tomcat
#安装路径
TOMCAT_PATH='/usr/local/tomcat'
#启动脚本
TOMCAT_START='/usr/local/tomcat/bin/startup.sh'
#2)WindCore
#安装路径
WINDCORE_PATH='/home/data/WindCore'
#启动脚本
WINDCORE_START='/home/data/WindCore/startup.sh'
#
#——————————————————————————————————————————   EMS   ———————————————————————————————————————————————
#服务列表
#1)WindManagerBS
#安装路径
WINDMANAGERBS_PATH='/home/data/WindManagerBS'
#启动脚本
WINDMANAGERBS_START='/home/data/WindManagerBS/startup.sh'
#2)WindSeer
#安装路径
WINDSEER_PATH='/home/data/WindSeer'
#启动脚本
WINDSEER_START='/home/data/WindSeer/startup.sh'
#3)WindSine
#安装路径
WINDSINE_PATH='/home/data/WindSine'
#启动脚本
WINDSINE_START='/home/data/WindSine/startup.sh'
#4)WindCore
#安装路径
EWINDCORE_PATH='/home/data/WindCore'
#启动脚本
EWINDCORE_START='/home/data/WindCore/startup.sh'


#————————————————————————————————————————————   函数  —————————————————————————————————————————————————

clean_startup(){
    if test -e $WINDCORE_START
    then
        rm -f $WINDCORE_START
    fi
    if test -e $WINDMANAGERBS_START
    then
        rm -f $WINDMANAGERBS_START
    fi
    if test -e $WINDSEER_START
    then
        rm -f $WINDSEER_START
    fi
    if test -e $WINDSINE_START
    then
        rm -f $WINDSINE_START
    fi
}

create_group(){
	if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
	then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
	fi
    chattr -i /etc/passwd
    chattr -i /etc/shadow
    chattr -i /etc/group
    chattr -i /etc/gshadow
    usermod -G windeyapps root
    usermod -G windeyapps redis
    usermod -G windeyapps influxdb
   
}
set_service_config(){
	for service in ${services[*]}
	do  
	    systemctl daemon-reload
	    if systemctl|grep $service.service >/dev/null 2>&1
		then
		    conf=`systemctl status $service|grep Loaded|awk -F '(' '{print $2}'|awk -F ';' '{print $1}' 2>/dev/null`
		    if grep '^Group' $conf >/dev/null 2>&1
		    then
		        sed -i "s/Group.*/Group=windeyapps/g"  $conf
		    else
		        sed -i '/^\[Service\]/a\Group=windeyapps' $conf
		    fi
			systemctl daemon-reload && systemctl restart $service.service
		    serviceUser=`grep '^User' $conf|awk -F '=' '{print $2}' 2>/dev/null`
		    if [ $serviceUser ]
		    then 
		        usermod -G windeyapps $serviceUser 
		    else
			    usermod -G windeyapps root
			fi
			
		fi
		
	done
	chown :windeyapps /home/data/ -R
}
scada_check(){
    if grep 'CentOS' /etc/redhat-release >/dev/null 2>&1
    then
        if ! test -d $TOMCAT_PATH
        then
            log_error "没有找到$TOMCAT_PATH目录！"
            exit 1
        fi
    fi
    if ! test -d $WINDCORE_PATH
    then
        log_error "没有找到$WINDCORE_PATH目录！"
        exit 1
    fi
    WindCorePID=`ps -ef|grep WindCore|grep -v grep|awk '{print $2}'`
    if [[ -z $WindCorePID ]]
    then 
	    log_error "当前未找到WindCore进程，请确认！"
        exit 1
	fi
    TomcatPID=`ps -ef|grep tomcat|grep -v grep|awk '{print $2}'`
	if [[ -z $TomcatPID ]]
    then 
	    log_error "当前未找到tomcat进程，请确认！"
        exit 1
	fi
}
ems_check(){
    if ! test -d $WINDMANAGERBS_PATH
    then
        log_error "没有找到$WINDMANAGERBS_PATH目录"
        exit 1
    fi
    
    if ! test -d $WINDSEER_PATH
    then
        log_error "没有找到$WINDSEER_PATH目录！"
        exit 1
    fi 
    if ! test -d $EWINDCORE_PATH
    then
        log_error "没有找到$EWINDCORE_PATH目录！"
        exit 1
    fi
    WindCorePID=`ps -ef|grep WindCore|grep -v grep|awk '{print $2}'`
    if [[ -z $WindCorePID ]]
    then 
	    log_error "当前未找到WindCore进程，请确认！"
        exit 1
	fi
    WindManagerBSPID=`ps -ef|grep WindManagerBS|grep -v grep|awk '{print $2}'`
    if [[ -z $WindManagerBSPID ]]
    then 
	    log_error "当前未找到WindManagerBS进程，请确认！"
        exit 1
	fi
    WindSeerPID=`ps -ef|grep wseer|grep -v grep|awk '{print $2}'`
    if [[ -z $WindSeerPID ]]
    then 
	    log_error "当前未找到WindSeer进程，请确认！"
        exit 1
	fi
    
}

kill_chromiumBrowser(){
    test -d $CrontabList || mkdir -p $CrontabList
    cat > $CrontabList/kill_chromiumBrowser.sh <<EOF
#!/bin/bash
ps -ef|grep chromium-browser|grep -v grep|awk '{print \$2}'|xargs kill -9 >/dev/null 2>&1
ps -ef|grep firefox|grep -v grep|awk '{print \$2}'|xargs kill -9 >/dev/null 2>&1
ps -ef|grep chrome|grep -v grep|awk '{print \$2}'|xargs kill -9 >/dev/null 2>&1
EOF
    chmod +x $CrontabList/kill_chromiumBrowser.sh
    if ! grep 'kill_chromiumBrowser.sh'  /var/spool/cron/root >/dev/null 2>&1
    then
        echo '10 1 * * *  '"$CrontabList/kill_chromiumBrowser.sh" >> /var/spool/cron/root
        systemctl restart crond.service 
    fi
    
}

init_jar(){
    jarName=$1
	workDir=$2
	serverName=$3
    WorkingDirectory=/etc/windeyapps/startup
    test -d $WorkingDirectory || mkdir -p $WorkingDirectory
	sudo touch /var/log/${serverName}.log
	sudo chown root:windeyapps /var/log/${serverName}.log
    cat >$WorkingDirectory/$serverName.sh<<-EOF
#!/bin/bash
jarName="$jarName"
workDir="$workDir"
start(){
    cd \${workDir} && java -jar \${jarName} >/dev/null 2>&1 &
}

stop(){
    ps -ef | grep -qP "(?<=-jar)\s+\${jarName}" && kill \$(ps -ef | grep -P "(?<=-jar)\s+\${jarName}" | awk '{print \$2}')
}

case \$1 in
    start)
        stop
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
    chmod +x $WorkingDirectory/$serverName.sh
    cat >$serverName.service<<-EOF
[Unit]
Description=java project

[Service]
Type=forking
User=root
Group=windeyapps
WorkingDirectory=$WorkingDirectory
ExecStart=/bin/bash $serverName.sh start
ExecStop=/bin/bash $serverName.sh stop
ExecReload=/bin/bash $serverName.sh restart
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    sudo \cp $serverName.service /usr/lib/systemd/system/
	sudo systemctl daemon-reload  && systemctl enable $serverName.service && sudo systemctl start $serverName.service
}

set_scada(){
    create_group
    \cp /etc/profile /etc/profile-$DATE.bak
    if grep "$TOMCAT_START" /etc/profile >/dev/null 2>&1
    then
        sed -i  '/\/usr\/local\/tomcat\/bin\/startup.sh/d' /etc/profile
        log_info "注释/etc/profile文件中的$TOMCAT_START"
    fi
    if grep "$WINDCORE_START" /etc/profile >/dev/null 2>&1
    then
        sed -i  '/\/home\/data\/WindCore\/startup.sh/d' /etc/profile
        log_info "注释/etc/profile文件中的$WINDCORE_START"
    fi
    if grep 'CentOS' /etc/redhat-release >/dev/null 2>&1
    then
        ps -ef|grep tomcat|grep -v grep|awk '{print $2}'|xargs kill -9
        log_info "杀死所有的tomcat进程！"
        cat > tomcat.service <<-EOF
[Unit]

Description=tomcat

[Service]
Type=oneshot
User=root
Group=windeyapps
ExecStart=$TOMCAT_START
ExecStop=$TOMCAT_PATH/bin/shutdown.sh
ExecReload=/bin/kill -s HUP \$MAINPID
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        \cp tomcat.service /usr/lib/systemd/system/
        chmod +x $TOMCAT_START && chmod +x $TOMCAT_PATH/bin/shutdown.sh
        systemctl daemon-reload && systemctl enable tomcat.service && systemctl start tomcat.service
    fi
    
    ps -ef|grep WindCore|grep -v grep|awk '{print $2}'|xargs kill -9
    log_info "杀死所有的WindCore进程！"

    init_jar 'WindCore.jar' "$WINDCORE_PATH" 'windcore'
    # set_service_config
    chown :windeyapps /home/data/ -R
}

set_ems(){
    create_group
    \cp /etc/profile /etc/profile-$DATE.bak
    if grep "$WINDMANAGERBS_START" /etc/profile >/dev/null 2>&1
    then
        sed -i  '/\/home\/data\/WindManagerBS\/startup.sh/d' /etc/profile

        log_info "注释/etc/profile文件中的$WINDMANAGERBS_START"
    fi
    if grep "$WINDSEER_START" /etc/profile >/dev/null 2>&1
    then
        sed -i  '/\/home\/data\/WindSeer\/startup.sh/d' /etc/profile
        log_info "注释/etc/profile文件中的$WINDSEER_START"
    fi
    if grep "$WINDSINE_START" /etc/profile >/dev/null 2>&1
    then
        sed -i  '/\/home\/data\/WindSine\/startup.sh/d' /etc/profile
        log_info "注释/etc/profile文件中的$WINDSINE_START"
    fi
    if grep "$EWINDCORE_START" /etc/profile >/dev/null 2>&1
    then
        sed -i  '/\/home\/data\/WindCore\/startup.sh/d' /etc/profile
        log_info "注释/etc/profile文件中的$EWINDCORE_START"
    fi
    ps -ef|grep wseer|grep -v grep|awk '{print $2}'|xargs kill -9 >/dev/null 2>&1
    log_info "杀死所有的WindSeer进程！"
    ps -ef|grep WindCore|grep -v grep|awk '{print $2}'|xargs kill -9 >/dev/null 2>&1
    log_info "杀死所有的WindCore进程！"
    ps -ef|grep WindManagerBS|grep -v grep|awk '{print $2}'|xargs kill -9 >/dev/null 2>&1
    log_info "杀死所有的WindManagerBS进程！"
    init_jar 'WindCore.jar' "$WINDCORE_PATH" 'windcore'
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
    sudo sed -i '/autologin-user=root/d' /etc/lightdm/lightdm.conf
    sudo sed -i "/greeter-hide-users=true/a autologin-user=root" /etc/lightdm/lightdm.conf
    sudo systemctl daemon-reload && sudo systemctl disable windcore.service && sudo systemctl enable windcore.timer && sudo systemctl start windcore.service
    init_jar 'WindManagerBS.jar' "$WINDMANAGERBS_PATH" 'windmanagerbs'
    init_jar 'wseer.jar' "$WINDSEER_PATH" 'windseer'
    if test -d $WINDSINE_PATH
    then
        ps -ef|grep WindSine|grep -v grep|awk '{print $2}'|xargs kill -9 >/dev/null 2>&1
        log_info "杀死所有的WindSine进程！"
        init_jar 'WindSine.jar' "$WINDSINE_PATH" 'windsine'
    fi
    # set_service_config
    chown :windeyapps /home/data/ -R

}

init_scada_daemon(){
    #相关的服务
    cat >scada-daemon<<EOF
#!/bin/bash
SERVICES=(windcore.service tomcat.service redis.service mssql-server.service)

DATE=\`date +"%Y%m%d"\`
#日志文件
LOG_FILE=/var/log/scada-daemon.log

###
#log
###
log_info(){
    echo "\`date +"%Y-%m-%d %H:%M:%S"\` [INFO]: \$1"|tee -a \$LOG_FILE
}

log_error(){
    echo -e "\\033[31m \`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]:  \$1 \\033[0m"|tee -a \$LOG_FILE
}


while true
do
    sleep 10
    
    for serviceName in \${SERVICES[*]}
    do
        if ! systemctl status \$serviceName|grep 'Active'|grep 'active'|grep -v 'inactive' >/dev/null 2>&1
        #systemctl status \$serviceName|grep 'Active'|grep 'active'|grep -v 'inactive' #包含stop的服务
        then
            systemctl restart \$serviceName
            log_error "\$serviceName服务状态异常，重启服务，尝试恢复！"
        fi
        # log_info "\$serviceName服务检测正常。"
    done

done
EOF

\cp scada-daemon /usr/bin/ && chmod +x /usr/bin/scada-daemon

cat > scada-daemon.service <<EOF
[Unit]

Description=scada-daemon service

[Service]
Type=simple
ExecStart=/usr/bin/scada-daemon
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True


[Install]
WantedBy=multi-user.target
EOF

\cp scada-daemon.service /usr/lib/systemd/system/

cat > scada-daemon.timer <<EOF
[Unit]
Description=java project

[Timer]
OnBootSec=1min
Unit=scada-daemon.service
 
[Install]
WantedBy=graphical.target
EOF

\cp scada-daemon.timer /usr/lib/systemd/system/
systemctl daemon-reload && systemctl disable scada-daemon.service && systemctl enable scada-daemon.timer &&  systemctl start scada-daemon.service

}

init_ems_daemon(){
    #相关的服务
cat >ems-daemon<<EOF
#!/bin/bash
SERVICES=(windcore.service redis.service influxd.service windmanagerbs.service windseer.service)

DATE=\`date +"%Y%m%d"\`
#日志文件
LOG_FILE=/var/log/ems-daemon.log

###
#log
###
log_info(){
    echo "\`date +"%Y-%m-%d %H:%M:%S"\` [INFO]: \$1"|tee -a \$LOG_FILE
}

log_error(){
    echo -e "\\033[31m \`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]:  \$1 \\033[0m"|tee -a \$LOG_FILE
}


while true
do
    sleep 10
    
    for serviceName in \${SERVICES[*]}
    do
        if ! systemctl status \$serviceName|grep 'Active'|grep 'active'|grep -v 'inactive' >/dev/null 2>&1
        #systemctl status \$serviceName|grep 'Active'|grep 'active'|grep -v 'inactive' #包含stop的服务
        then
            systemctl restart \$serviceName
            log_error "\$serviceName服务状态异常，重启服务，尝试恢复！"
        fi
        # log_info "\$serviceName服务检测正常。"
    done

done
EOF

\cp ems-daemon /usr/bin/ && chmod +x /usr/bin/ems-daemon

cat > ems-daemon.service <<EOF
[Unit]

Description=ems-daemon service

[Service]
Type=simple
ExecStart=/usr/bin/ems-daemon
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True


[Install]
WantedBy=multi-user.target
EOF

\cp ems-daemon.service /usr/lib/systemd/system/

cat > ems-daemon.timer <<EOF
[Unit]
Description=java project

[Timer]
OnBootSec=1min
Unit=ems-daemon.service

[Install]
WantedBy=graphical.target
EOF

\cp ems-daemon.timer /usr/lib/systemd/system/
systemctl daemon-reload && systemctl disable ems-daemon.service && systemctl enable ems-daemon.timer &&  systemctl start ems-daemon.service

}

main(){

    case $1 in
    scada)
        # if ! cat /etc/.kyinfo | grep SCADA-Server  >/dev/null 2>&1
        # then
        #     echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  这不是一台SCADA-Server类型的服务器，请确认！ \033[0m"
        #     exit 1
        # fi
        scada_check
        set_scada
        init_scada_daemon
        clean_startup
        kill_chromiumBrowser
        ;;
    ems)
        # if ! cat /etc/.kyinfo | grep EMS-Server  >/dev/null 2>&1
        # then
        #     echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  这不是一台EMS-Server类型的服务器，请确认！ \033[0m"
        #     exit 1
        # fi
        if [ ! -d "/home/data/WindManagerBS" ]
        then
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [ERROR]:未找到WindManagerBS，脚本无法运行。请确认是否已在能管服务器上运行脚本。"
            exit 1
        fi
        ems_check
        set_ems
        init_ems_daemon
        clean_startup
        kill_chromiumBrowser
        ;;
    *)
        echo "请选择修复系统类型"
        exit 1
        ;;
    esac
}

main $1