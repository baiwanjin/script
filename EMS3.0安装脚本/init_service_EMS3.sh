#!/bin/bash

#ems3地址
EMS3_HOME="/home/data"

#数据文件路径
DATA_PATH="/home/data"
INFLUX2_DATA="$DATA_PATH/.windmanager/influx2"
test -d $INFLUX2_DATA || mkdir -p "$INFLUX2_DATA"
chown influxdb:influxdb $DATA_PATH/.windmanager -R


#node地址
NODEHOME='/usr/local/node'

DATE=`date +"%Y%m%d%H%M%S"`
CrontabList='/etc/crontablist'
#日志文件
LOG_FILE=install-ems3-$DATE.log

#需要开放的TCP端口
TcpPorts=(21 22 8080 8082  8086  9166 5900 5901 5902 5903 5904 9170 9171 9172 9173 9174 9175 9176 9177 9178 9179)
#需要开放的UDP端口
UdpPorts=(123 1434 4747 4848 8086 8182 8184 8185 9166 27017)


#需要禁用的Service列表
maskServiceList=('mongod.service' 'tomcat.service' 'mysqld.service')
###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|tee -a $LOG_FILE
}

systemd_mask_Service(){
    for seviceName in ${maskServiceList[*]}
    do
        if systemctl list-unit-files|grep $seviceName|grep enabled
        then
            log_info "禁用$seviceName服务！"
            systemctl mask $seviceName
        fi
    done
}
###
#文件目录检测
###
check_files(){
    if [ ! -d "$1" ]
    then
        log_error "$1文件不存在，请确认！"      
        exit
    fi
}

###
#添加防火墙策略
###
add_firewall_rules(){
    sudo systemctl enable firewalld
    sudo systemctl restart firewalld
    for TcpPort in ${TcpPorts[*]}
    do
	    port_status=`sudo firewall-cmd --query-port=${TcpPort}/tcp`
		if [ $port_status == 'no' ]
		then
	        log_info "添加TCP端口:${TcpPort}到防火墙"
            sudo firewall-cmd --add-port=${TcpPort}/tcp --permanent
		fi
    done
    for UdpPort in ${UdpPorts[*]}
    do
	    port_status=`sudo firewall-cmd --query-port=${UdpPort}/udp`
	    if [ $port_status == 'no' ]
	    then
	        log_info "添加UDP端口:${UdpPort}到防火墙"
	        sudo firewall-cmd --add-port=${UdpPort}/udp --permanent
        fi
	done
    sudo systemctl restart firewalld
}

###
#安装自动交互工具
###
install_automation(){
    if ls ./automation/*.rpm >/dev/null 2>&1
    then
        log_info "正在安装自动化交互工具"
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
	    log_error "未找到任何安装包，请确认!"
	    exit
    fi
}

###
#systemd模板
###
init_jar(){
    jarName=$1
	workDir=$2
	serverName=$3
	sudo touch /var/log/${serverName}.log
	sudo chown root:windeyapps /var/log/${serverName}.log
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
    sudo \cp $serverName.service /usr/lib/systemd/system/
	sudo systemctl daemon-reload  && systemctl enable $serverName.service && sudo systemctl start $serverName.service
}

init_node_systemd(){
    jarName=$1
	workDir=$2
	serverName=$3
    sudo touch /var/log/${serverName}.log
	sudo chown root:windeyapps /var/log/${serverName}.log
    cat > $workDir/$serverName.sh <<-EOF
#!/bin/bash
NODE_PATH=$NODEHOME/bin/node
workDir="$workDir"
start(){
    cd \$workDir && nohup ./$jarName >> /var/log/${serverName}.log 2>&1 &
}
start
EOF
    chmod +x $workDir/$jarName
    chmod +x $workDir/$serverName.sh 
    cat > $serverName.service <<-EOF
[Unit]
Description=node project

[Service]
Type=forking 
User=root
Group=windeyapps
WorkingDirectory=$workDir
ExecStart=/bin/bash $serverName.sh
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    sudo \cp $serverName.service /usr/lib/systemd/system/
	sudo systemctl daemon-reload  && systemctl enable $serverName.service && sudo systemctl start $serverName.service

}


system_setup(){
   sudo gsettings set org.mate.screensaver idle-activation-enabled false
   sudo gsettings set org.mate.power-manager sleep-display-ac 0
   log_info "屏幕保护和显示器睡眠已关闭"
   sudo systemctl stop rpcbind.socket && sudo systemctl stop rpcbind
   sudo systemctl disable rpcbind.socket && sudo systemctl disable rpcbind
   log_info "rpcbind服务已禁用"
   sudo sed -i '/autologin-user=root/d' /etc/lightdm/lightdm.conf
   sudo sed -i "/greeter-hide-users=true/a autologin-user=root" /etc/lightdm/lightdm.conf
   log_info "已设置root用户自动登录"
}

###
#谷歌浏览器配置
###
init_Chrome(){
    if ! sudo grep -q "Exec=/usr/bin/chromium-browser %U --no-sandbox" /usr/share/applications/chromium-browser.desktop
    then
        sudo sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U --no-sandbox?" /usr/share/applications/chromium-browser.desktop
    fi
        sudo \cp -f -p /usr/share/applications/chromium-browser.desktop /root/windmanager.desktop
        sudo sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U http://127.0.0.1:9170/#/main/config?" /root/windmanager.desktop
        sudo sed -i "s?Name=Chromium Web Browser?Name=windmanager?" /root/windmanager.desktop
        sudo sed -i "s?Name\[zh_CN\]=Chromium 网页浏览器?Name\[zh_CN\]=windmanager?" /root/windmanager.desktop
    if [ -d "/root/桌面" ];then
        sudo \cp -f -p /root/windmanager.desktop /root/桌面
        sudo chmod +x /rppt/桌面/windmanager.desktop
    fi
    if [ -d "/root/Desktop" ];then
        sudo \cp -f -p /root/windmanager.desktop /root/Desktop
        sudo chmod +x /root/Desktop/windmanager.desktop
    fi
    sudo rm -f /root/windmanager.desktop
    log_info "谷歌浏览器配置完成！"
}

###
#配置VNC
###
init_VNC(){

    echo "Windey@2022" | vncpasswd -service 1>/dev/null
    /usr/bin/vnclicense -add VKUPN-MTHHC-UDHGS-UWD76-6N36A 1>/dev/null
    systemctl enable vncserver-x11-serviced.service
    systemctl restart vncserver-x11-serviced.service
    log_info "VNC配置完成！" 
}

###
#redis配置
###
init_redis(){
   
    sudo \cp /etc/redis.conf /etc/redis.conf_`date +"%Y%m%d%H%M%S"`.backup
    sudo sed -i "s#^bind.*#bind 0.0.0.0#g" /etc/redis.conf
    sudo sed -i "s#^daemonize.*#daemonize yes#g" /etc/redis.conf
	sudo sed -i "s#^logfile.*#logfile $DATA_PATH/redis/redis.log#g" /etc/redis.conf
	sudo sed -i "s#^dir.*#dir $DATA_PATH/redis#g" /etc/redis.conf
    sudo sed -i "s?# requirepass foobared?requirepass windey?" /etc/redis.conf
	sudo sed -i "s#^requirepass.*#requirepass windey#g" /etc/redis.conf
   
    sudo mkdir -p $DATA_PATH/redis
	sudo chown redis $DATA_PATH/redis
    chmod 644 /etc/redis.conf
	sudo sed -i "s/Group.*/Group=windeyapps/g" /usr/lib/systemd/system/redis.service 
    sudo systemctl daemon-reload
	sudo systemctl restart redis
    log_info "Redis配置完成！"
}

###
#初始化influxdb
###
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
cat /home/influxdb2/.influxdbv2/configs|grep -v '#'|grep token|awk -F '[""]' '{print $2}' > token.txt
}


###
#influxdb升级
###
install_influxdb(){
     influxdbVersion=`rpm -qa|grep influxdb|awk -F '-' '{print $2}'|awk -F '.' '{print $NR}'`
    if [[ $influxdbVersion -lt 2 ]]
    then
        
        systemctl stop influxdb
        # mkdir -p /home/influxdb2/
        # chown influxdb:influxdb /home/influxdb2/
        # usermod -d /home/influxdb2/ influxdb 
        # systemctl restart influxdb
        # sleep 2
        # systemctl stop influxdb
        # sleep 2
        log_info "influxdb当前版本小于2.0，升级influxdb。"
        test -d $INFLUX2_DATA || mkdir -p "$INFLUX2_DATA"
        chown influxdb:influxdb $INFLUX2_DATA -R
        if ! sudo -u influxdb ls $INFLUX2_DATA >/dev/null 2>&1
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

#nodejs初始化

init_nodejs(){
    if grep "NODE_HOME" /etc/profile
    then
        log_error "检测到存在/etc/profile中存在NODE_HOME，请确认是否安装node环境"
        return
    fi
    tar -xf node-v16.15.0-linux-x64.tar
    mv node-v16.15.0-linux-x64 node
    mv node /usr/local/
    export NODE_HOME=$NODEHOME
    export PATH=$PATH:$NODE_HOME/bin
    export NODE_PATH=$NODE_HOME/lib/node_modules
    echo -e "export NODE_HOME=/usr/local/node\nexport PATH=\$PATH:\$NODE_HOME/bin\nexport NODE_PATH=\$NODE_HOME/lib/node_modules"|tee -a /etc/profile
    source /etc/profile
}


###
#安装前检测
###
check(){
    check_files windconfig
    check_files windstat
    check_files windcore
    check_files winddump
    check_files windmanagerui
    check_files automation
    if ! test -e influxdb-2.*.x86_64.rpm
    then
        log_error "不存在influxdb-2.0的安装包！"
    fi
    if [ ! -f "node-v16.15.0-linux-x64.tar" ];then
        log_error "未在当前目录下找到node-v16.15.0-linux-x64.tar程序文件，脚本运行中断！"
        exit 1
    fi
    log_info "安装环境检测完成"
}

create_group(){
	if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
	then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
	fi
    sudo usermod -G windeyapps root
    sudo usermod -G windeyapps redis
    sudo usermod -G windeyapps influxdb
}

install_windconfig(){
    if test -d $EMS3_HOME/windconfig
    then
        sudo mv $EMS3_HOME/windconfig $EMS3_HOME/windconfig_$DATE.bak
        log_info "存在$EMS3_HOME/windconfig目录，重命名为$EMS3_HOME/windconfig_$DATE.bak"
    fi
    sudo mkdir -p $EMS3_HOME
    \cp -r windconfig $EMS3_HOME
    init_jar 'windconfig.jar' "$EMS3_HOME/windconfig" 'windconfig'
}

install_windcore(){
    if test -d $EMS3_HOME/windcore
    then
        sudo mv $EMS3_HOME/windcore $EMS3_HOME/windcore_$DATE.bak
        log_info "存在$EMS3_HOME/windcore目录，重命名为$EMS3_HOME/windcore_$DATE.bak"
    fi
    sudo mkdir -p $EMS3_HOME
    \cp -r windcore $EMS3_HOME
    init_jar 'windcore.jar' "$EMS3_HOME/windcore" 'windcore'
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
    # sudo systemctl daemon-reload && sudo systemctl enable windcore.service && sudo systemctl start windcore.service
}

install_windstat(){
    if test -d $EMS3_HOME/windstat
    then
        sudo mv $EMS3_HOME/windstat $EMS3_HOME/windstat_$DATE.bak
        log_info "存在$EMS3_HOME/windstat目录，重命名为$EMS3_HOME/windstat_$DATE.bak"
    fi
    sudo mkdir -p $EMS3_HOME
    \cp -r windstat $EMS3_HOME
    init_jar 'windstat.jar' "$EMS3_HOME/windstat" 'windstat'
}

install_winddump(){
    if test -d $EMS3_HOME/winddump
    then
        sudo mv $EMS3_HOME/winddump $EMS3_HOME/winddump_$DATE.bak
        log_info "存在$EMS3_HOME/winddump目录，重命名为$EMS3_HOME/winddump_$DATE.bak"
    fi
    sudo mkdir -p $EMS3_HOME
    \cp -r winddump $EMS3_HOME
    init_jar 'winddump.jar' "$EMS3_HOME/winddump" 'winddump'
    \cp token.txt $EMS3_HOME/winddump/
}

install_windmanagerui(){
    if test -d $EMS3_HOME/windmanagerui
    then
        sudo mv $EMS3_HOME/windmanagerui $EMS3_HOME/windmanagerui_$DATE.bak
        log_info "存在$EMS3_HOME/windmanagerui目录，重命名为$EMS3_HOME/windmanagerui_$DATE.bak"
    fi
    sudo mkdir -p $EMS3_HOME
    \cp -r windmanagerui $EMS3_HOME
    init_node_systemd 'windmanagerui' "$EMS3_HOME/windmanagerui" 'windmanagerui'
}

clean(){
    if ! test -e clean-history-data.sh
    then
        log_error "不存在clean-history-data.sh脚本"
        return
    fi
    mkdir -p $CrontabList
    \cp clean-history-data.sh $CrontabList
    crontab -l  >/dev/null 2>&1 >> crontabfile
    if ! grep 'clean-history-data.sh' crontabfile >/dev/null 2>&1;then echo '10 5 * * *  '$CrontabList'/clean-history-data.sh' >> crontabfile;fi
    crontab crontabfile && rm -f crontabfile

}

main(){
    
    # check
    # install_automation
    # system_setup
    # init_Chrome
    # init_VNC
    # create_group
    # init_redis
    # install_influxdb
    # init_nodejs
    # add_firewall_rules
    install_windconfig
    install_windcore
    install_windstat
    install_winddump
    install_windmanagerui
    # systemd_mask_Service
    # clean
    sudo chown :windeyapps $EMS3_HOME -R
}


main

