#!/bin/bash
#仅用于将能管2.0升级为能管3.0
#20221014
#ems3地址
EMS3_HOME="/home/data"
#数据文件路径
DATA_PATH="/home/data"
INFLUX2_DATA="$DATA_PATH/.windmanager/influx2"
DATE=`date +"%Y%m%d%H%M%S"`
LOG_FILE=update-ems2toems3-$DATE.log

###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
}

install_automation(){
    if ls ./automation/*.rpm >/dev/null 2>&1
    then
        echo "正在安装自动化交互工具"
        if ! rpm -qa|grep expect 1>/dev/null
        then
	        sudo rpm -ivh ./automation/tcl*.rpm
            sudo rpm -ivh ./automation/expect*.rpm
	    fi
        if ! rpm -qa|grep sshpass 1>/dev/null
	    then
	        sudo rpm -ivh ./automation/sshpass*.rpm
	    fi

    else
	    echo "未找到任何安装包，请确认!"
	    exit 1
    fi
}

check(){
    if ! test -e EMS3-exportConfig.sh
    then
        log_error "当前目录缺少EMS3-exportConfig.sh脚本！"
        exit 1
    fi
    if ! test -e EMS-exportConfig.sh
    then
        log_error "当前目录缺少EMS-exportConfig.sh脚本！"
        exit 1
    fi
    if ! test -e init-ems-daemon.sh
    then
        log_error "当前目录缺少init-ems-daemon.sh脚本！"
        exit 1
    fi
    if ! test -d windmanager
    then
        log_error "当前目录下不存在windmanager程序文件，请确认！"
        exit 1
    fi
    if ! test -d windconfig
    then
        log_error "当前目录下不存在windconfig程序文件，请确认！"
        exit 1
    fi
    if ! test -d windstat
    then
        log_error "当前目录下不存在windstat程序文件，请确认！"
        exit 1
    fi
    if ! test -d windmanagerui
    then
        log_error "当前目录下不存在windmanagerui程序文件，请确认！"
        exit 1
    fi
    if ! test -d winddump
    then
        log_error "当前目录下不存在winddump程序文件，请确认！"
        exit 1
    fi
    if ! test -d python3
    then
        log_error "当前目录缺少python3安装包！"
        exit 1
    fi

    if ! test -e influxdb-2.*.x86_64.rpm
    then
        log_error "当前目录下不存在influxdb-2.*.x86_64.rpm文件"
    fi
    if  java -version 2>&1 | sed '1!d' | sed -e 's/"//g' | awk '{print $3}'|grep '1.8.0'
    then
        log_info "当前Java版本为: `java -version 2>&1 | sed '1!d' | sed -e 's/"//g' | awk '{print $3}'`"
    else
        log_error "当前的Java版本不是1.8.0版本，请确认！"
        log_info "当前Java版本为: `java -version 2>&1 | sed '1!d' | sed -e 's/"//g' | awk '{print $3}'`"
        log_error "升级任务退出！"
        exit 1
    fi
    if rpm -qa|grep 'redis-4.0.2'
    then
        log_info "当前Redis版本为: `rpm -qa|grep 'redis-4.0.2'`"
    else
        log_error "当前Redis版本不是redis-4.0.2，请确认！"
        log_info "当前Redis版本为: `rpm -qa|grep 'redis-4.0.2'`"
        log_error "升级任务退出！"
        exit 1
    fi



}


backup(){
    chmod +x EMS-exportConfig.sh
    ./EMS-exportConfig.sh
    if test -d /home/data
    then
        mv /home/data /home/data_$DATE && log_info "将/home/data目录重命名为/home/data_$DATE"
    fi
    ps -ef|grep WindSine|grep -v grep|awk 'NR>=1 {print $2}'|xargs kill -9
    ps -ef|grep WindCore|grep -v grep|awk 'NR>=1 {print $2}'|xargs kill -9
    ps -ef|grep WindManagerBS|grep -v grep|awk 'NR>=1 {print $2}'|xargs kill -9
    ps -ef|grep wseer|grep -v grep|awk 'NR>=1 {print $2}'|xargs kill -9

}


init_node_systemd(){
    jarName=$1
	workDir=$2
	serverName=$3
     WorkingDirectory=/etc/windeyapps/startup
     test -d $WorkingDirectory || mkdir -p $WorkingDirectory
     touch /var/log/${serverName}.log
	 chown root:windeyapps /var/log/${serverName}.log
    cat > $WorkingDirectory/$serverName.sh <<-EOF
#!/bin/bash
#NODE_PATH=$NODEHOME/bin/node
workDir="$workDir"
start(){
    cd \$workDir && nohup ./$jarName >> /dev/null 2>&1 &
}
start
EOF
    chmod +x $workDir/$jarName
    chmod +x $WorkingDirectory/$serverName.sh
    cat > $serverName.service <<-EOF
[Unit]
Description=node project

[Service]
Type=forking
User=root
Group=windeyapps
WorkingDirectory=$WorkingDirectory
ExecStart=/bin/bash $serverName.sh
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
     \cp $serverName.service /usr/lib/systemd/system/
	 systemctl daemon-reload  && systemctl enable $serverName.service &&  systemctl restart $serverName.service

}


init_jar(){
    jarName=$1
	workDir=$2
	serverName=$3
    WorkingDirectory=/etc/windeyapps/startup
    test -d $WorkingDirectory || mkdir -p $WorkingDirectory
	# sudo touch /var/log/${serverName}.log
	# sudo chown root:windeyapps /var/log/${serverName}.log
    cat >$WorkingDirectory/$serverName.sh<<-EOF
#!/bin/bash
jarName="$jarName"
workDir="$workDir"
start(){
    cd \${workDir} && java -jar \${jarName} >> /dev/null 2>&1 &
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



install_python(){
    if python3 -V >/dev/null 2>&1
    then
        log_info "系统存在python3: `python3 -V`"
    else
        log_info "安装python3！"
        rpm -ivh python3/*.rpm
    fi
}

init_Chrome(){
    if !  grep -q "Exec=/usr/bin/chromium-browser %U --no-sandbox" /usr/share/applications/chromium-browser.desktop
    then
         sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U --no-sandbox?" /usr/share/applications/chromium-browser.desktop
    fi
         \cp -f -p /usr/share/applications/chromium-browser.desktop /root/windmanager.desktop
         sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U http://127.0.0.1:9170/#/main/config?" /root/windmanager.desktop
         sed -i "s?Name=Chromium Web Browser?Name=windmanager?" /root/windmanager.desktop
         sed -i "s?Name\[zh_CN\]=Chromium 网页浏览器?Name\[zh_CN\]=windmanager?" /root/windmanager.desktop
    if [ -d "/root/桌面" ];then
         \cp -f -p /root/windmanager.desktop /root/桌面
         chmod +x /root/桌面/windmanager.desktop
    fi
    if [ -d "/root/Desktop" ];then
         \cp -f -p /root/windmanager.desktop /root/Desktop
         chmod +x /root/Desktop/windmanager.desktop
    fi
     rm -f /root/windmanager.desktop
    log_info "谷歌浏览器配置完成！"
}


init_influxdb(){
    cat > expect.sh <<-EOF
#!/usr/bin/expect
set timeout -1
spawn sudo -u influxdb influx setup
expect "*username"
send "root\r"
expect "*password"
send "WindeyXT@2022\r"
expect "*again"
send "WindeyXT@2022\r"
expect "*name"
send "windey\r"
expect "*name"
send "windmanager\r"
expect "*infinite."
send "720\r" 
expect "*y/n"
send "y\r"
interact
EOF
chmod +x expect.sh && ./expect.sh && rm -f expect.sh
}

install_influxdb(){
    influxdbVersion=`rpm -qa|grep influxdb|awk -F '-' '{print $2}'|awk -F '.' '{print $NR}'`
    if [[ $influxdbVersion -lt 2 ]]
    then
        systemctl stop influxdb
        log_info "influxdb当前版本小于2.0，升级influxdb。"
        test -d $INFLUX2_DATA || mkdir -p "$INFLUX2_DATA"
        chown influxdb:influxdb $INFLUX2_DATA -R
        if !  sudo -u influxdb ls $INFLUX2_DATA >/dev/null 2>&1
        then
            log_error "cannot access $INFLUX2_DATA: Permission denied"
            log_error "请确认$INFLUX2_DATA目录influxdb用户可以访问"
            exit 1
        fi

        if [ "$(ls -A $INFLUX2_DATA)" != "" ]
        then
            log_error "$INFLUX2_DATA不是一个空目录！"
            log_error "$INFLUX2_DATA目录必须是一个空目录，请确认！"
            exit 1
        fi
        rpm -Uvh influxdb-2.*.x86_64.rpm
        sed -i "s#ExecStart=.*#ExecStart=/usr/bin/influxd --engine-path=$INFLUX2_DATA#g" /usr/lib/systemd/system/influxdb.service
        systemctl daemon-reload && systemctl start influxd && systemctl start influxdb
        firewall-cmd --add-port=8086/tcp --permanent
        firewall-cmd --reload
        chmod 777 $PWD
        sleep 5
        for i in {1..10}
        do
            if  netstat -tunlp|grep 8086
            then
			    sleep 5
                init_influxdb
                return
            fi
            log_info "正在等待influxdb启动完成！"
            sleep 3
        done
    fi


}

create_group(){
	if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
	then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
	fi
    chattr -i /etc/group
    chattr -i /etc/gshadow
    usermod -G windeyapps root
    usermod -G windeyapps redis
    usermod -G windeyapps influxdb
}


install_windconfig(){
    init_jar 'windconfig.jar' "$EMS3_HOME/windconfig" 'windconfig'
}

install_windcore(){
    init_jar 'windmanager.jar' "$EMS3_HOME/windmanager" 'windmanager'
}

install_windstat(){
    init_jar 'windstat.jar' "$EMS3_HOME/windstat" 'windstat'
}

install_winddump(){
    init_jar 'winddump.jar' "$EMS3_HOME/winddump" 'winddump'
}

install_windmanagerui(){
    init_node_systemd 'windmanagerui' "$EMS3_HOME/windmanagerui" 'windmanagerui'
}


update(){

    create_group
    test -d /home/data || mkdir -p /home/data
    test -d $INFLUX2_DATA || mkdir -p "$INFLUX2_DATA"
    chown influxdb:influxdb $DATA_PATH/.windmanager -R
    \cp -r wind* /home/data
    chown :windeyapps /home/data -R
    install_automation
    install_influxdb
    install_python
    install_windconfig
    install_windcore
    install_windstat
    install_winddump
    install_windmanagerui
    init_Chrome
    chown :windeyapps /home/data -R
    chmod +x init-ems-daemon.sh
    ./init-ems-daemon.sh
    chmod +x EMS3-exportConfig.sh
    ./EMS3-exportConfig.sh
    echo "***************************"
    echo "******程序升级完成！*******"
    echo "***************************"
}

main(){
    check
    backup
    updates
}

main