#!/bin/bash
#安装WMMCS服务端
#技术中心

#配置
RedisPasswd='Sa123456%'
current_path=$PWD
SCADA_PATH='/home/data'
NODEHOME='/usr/local/node'
#日志文件
DATE=`date +"%Y%m%d%H%M%S"`
CrontabList='/etc/crontablist'
WindCoreCfg="/home/data/WindCore/cfg"
LOG_FILE=install-wmmcs-server-$DATE.log

INFLUX2_DATA='/home/data/.windmanager/influx2'

#需要禁用的Service列表
maskServiceList=('mongod.service' 'tomcat.service' 'mysqld.service')


###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
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
#创建windeyapps

create_group(){
    if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
    then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
        log_info "创建windeyapps组"
    fi
    sudo usermod -G windeyapps root
    sudo usermod -G windeyapps redis
    sudo usermod -G windeyapps influxdb
    log_info "添加root、redis、influxdb用户到windeyapps组"
}


#初始化redis

init_redis(){
    sudo mkdir -p $SCADA_PATH/redis
    #sudo cp dump.rdb $SCADA_PATH/redis
    sudo chown redis:redis $SCADA_PATH/redis -R
    sudo sed -i "s?^logfile.*?logfile $SCADA_PATH/redis/redis.log?" /etc/redis.conf
    sudo sed -i "s?^dir.*?dir $SCADA_PATH/redis?" /etc/redis.conf
    sudo sed -i "s?bind 127.0.0.1?bind 0.0.0.0?" /etc/redis.conf
    sudo sed -i "s?daemonize no?daemonize yes?" /etc/redis.conf
    if ! sudo grep -q '#save 900 1' /etc/redis.conf
    then
        sudo sed -i "s?save 900 1?#save 900 1?" /etc/redis.conf
    fi

    if ! sudo grep -q '#save 300 10' /etc/redis.conf
    then
        sudo sed -i "s?save 300 10?#save 300 10?" /etc/redis.conf
    fi

    if ! sudo grep -q '#save 60 10000' /etc/redis.conf
    then
        sudo sed -i "s?save 60 10000?#save 60 10000?" /etc/redis.conf
    fi

    if ! sudo grep -q "requirepass ${RedisPasswd}" /etc/redis.conf
    then
        sudo sed -i "s?# requirepass foobared?requirepass ${RedisPasswd}?" /etc/redis.conf
    fi
    sudo sed -i 's/^Group.*/Group=windeyapps/g' /usr/lib/systemd/system/redis.service
    sudo systemctl daemon-reload
    sudo systemctl restart redis && sudo systemctl enable redis
    sudo firewall-cmd --add-port=6379/tcp --permanent
    sudo firewall-cmd --reload
    log_info "Redis配置完成！"
}

#安装redis

install_redis(){

    if systemctl |grep redis  > /dev/null 2>&1
    then

    	init_redis
        return	
    fi

    log_error "未安装redis,请确认！"

}


#初始化influxdb

init_influxdb(){
    cp /etc/influxdb/influxdb.conf /etc/influxdb/influxdb.conf_`date +"%Y%m%d%H%M"`.bak 
    #创建wind_tsdb库
    sudo mkdir -p $SCADA_PATH/windinflux/influxmeta
    sudo mkdir -p $SCADA_PATH/windinflux/influxdata
    sudo mkdir -p $SCADA_PATH/windinflux/influxwal
    sudo chown influxdb: -R $SCADA_PATH/windinflux/
    sudo sed -i -e "s#/var/lib/influxdb/met#$SCADA_PATH/windinflux/influxmeta#g" -e "s#/var/lib/influxdb/data#$SCADA_PATH/windinflux/influxdata#g" -e "s#/var/lib/influxdb/wal#$SCADA_PATH/windinflux/influxwal#g" /etc/influxdb/influxdb.conf
    sudo sed -i 's/^Group.*/Group=windeyapps/g' /usr/lib/systemd/system/influxdb.service
    sudo systemctl daemon-reload
    sudo systemctl restart influxdb
    sudo systemctl enable influxdb
    sleep 5
    #创建管理员用户
    if ! influx -username root -password root -execute "SHOW USERS"|grep root > /dev/null 2>&1
    then
        influx -username root -password root -execute "CREATE USER root WITH PASSWORD 'root' WITH ALL PRIVILEGES"
    fi
    #创建数据库
    if ! influx -username root -password root -execute "SHOW DATABASES"|grep wind_tsdb > /dev/null 2>&1
    then 
        influx -username root -password root -execute "CREATE DATABASE wind_tsdb WITH DURATION 30d"
    fi
    #开启认证

    if grep "^auth-enabled" /etc/influxdb/influxdb.conf >/dev/null 2>&1
    then
        sed -i 's/^auth-enabled.*/auth-enabled=true/g' /etc/influxdb/influxdb.conf
    else
        sed -i '/auth-enabled/a\auth-enabled=true' /etc/influxdb/influxdb.conf
    fi

    sudo systemctl restart influxdb

}

#安装influxdb

install_influxdb(){

    if systemctl |grep influxdb > /dev/null 2>&1
    then
        sudo systemctl restart influxdb
        init_influxdb
	    sudo firewall-cmd --add-port=8086/tcp --permanent
	    sudo firewall-cmd --add-port=8088/tcp --permanent
        sudo firewall-cmd --reload
        return
    fi

    log_error "未安装influxdb，请确认！"

}





#nodejs初始化

init_nodejs(){

    
    if grep "NODE_HOME" /etc/profile
    then
        log_error "检测到nodejs已经安装，请确认！"
        return
    fi
    if [ ! -f "$PWD/node-v16.15.0-linux-x64.tar" ];then
        log_error "未在当前目录下找到node-v16.15.0-linux-x64.tar程序文件，脚本运行中断！"
        return
    fi
    tar -xf node-v16.15.0-linux-x64.tar
    mv node-v16.15.0-linux-x64 node
    \cp -r node /usr/local/
    export NODE_HOME=$NODEHOME
    export PATH=$PATH:$NODE_HOME/bin
    export NODE_PATH=$NODE_HOME/lib/node_modules
    echo -e "export NODE_HOME=/usr/local/node\nexport PATH=\$PATH:\$NODE_HOME/bin\nexport NODE_PATH=\$NODE_HOME/lib/node_modules"|tee -a /etc/profile
    source /etc/profile
}

init_HGDB(){
    chmod +x installDB_expect.sh
    ./installDB_expect.sh $SCADA_PATH
    sudo firewall-cmd --add-port=5866/tcp --permanent
    sudo firewall-cmd --reload
}

init_monitorBackend(){
    if ! test -d monitor-backend
    then 
	log_error "不存在 monitor-backend安装包,请确认！"
	return
    fi
    cat > ./monitor-backend/startup.sh<<-EOF
#!/bin/bash
NODE_PATH=$NODEHOME/bin/node
start(){
    cd $SCADA_PATH/monitor-backend/ && nohup \$NODE_PATH app.js >> /var/log/monitor-backend.log 2>&1 &
}
start
EOF
    sudo \cp -r monitor-backend/ $SCADA_PATH
    #/usr/local/node/bin/npm install log4js/ -g
	#mv log4js $SCADA_PATH/monitor-backend/node_modules/
    cat > monitor-backend.service <<-EOF
[Unit]
Description=node project

[Service]
Type=forking 
User=root
Group=windeyapps
ExecStart=$SCADA_PATH/monitor-backend/startup.sh
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    sudo firewall-cmd --add-port=9161/tcp --permanent
    sudo firewall-cmd --add-port=9162/tcp --permanent
    sudo firewall-cmd --reload
    chmod +x monitor-backend.service
    chmod +x $SCADA_PATH/monitor-backend/startup.sh
    sudo \cp monitor-backend.service /usr/lib/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable monitor-backend.service && sudo systemctl start monitor-backend.service && systemctl status monitor-backend.service
}
init_VNC(){
    echo "Windey@2022" | vncpasswd -service 1>/dev/null
    /usr/bin/vnclicense -add VKUPN-MTHHC-UDHGS-UWD76-6N36A 1>/dev/null
    systemctl enable vncserver-x11-serviced.service
    systemctl restart vncserver-x11-serviced.service
    sudo firewall-cmd --add-port=5900/tcp --permanent
    sudo firewall-cmd --reload
    log_info "已完成VNC的激活"
}

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

install_WindDP(){

    if test -d $SCADA_PATH/WindDP
    then
        sudo mv $SCADA_PATH/WindDP $SCADA_PATH/WindDP_$DATE.bak
        log_info "存在$SCADA_PATH/WindDP目录，重命名为$SCADA_PATH/WindDP_$DATE.bak"
    fi
    sudo mkdir -p $SCADA_PATH
    \cp -r WindDP $SCADA_PATH
    init_jar 'WindDP.jar' "$SCADA_PATH/WindDP" 'winddp'
}

#初始化Windcore

init_WindCore(){
    if test -d $SCADA_PATH/WindCore
    then
        sudo mv $SCADA_PATH/WindCore $SCADA_PATH/WindCore_$DATE.bak
        log_info "存在$SCADA_PATH/WindCore目录，重命名为$SCADA_PATH/WindCore_$DATE.bak"
    fi

    sudo mkdir -p $SCADA_PATH 
    if [ ! -d "$PWD/WindCore" ];then
	log_error "未在当前目录下找到WindCore程序文件，脚本运行中断！"
        return
    fi
    \cp -r $PWD/WindCore $SCADA_PATH
   
    sudo chmod +x $SCADA_PATH/WindCore/startup.sh
    sudo chmod +x $SCADA_PATH/WindCore/WindCore.jar
    if ! sudo grep -q "RedisPassword,${RedisPasswd}" $SCADA_PATH/WindCore/cfg/ConnectValue.csv
    then
        sudo sed -i "/RedisPort,6379/a RedisPassword,${RedisPasswd}" $SCADA_PATH/WindCore/cfg/ConnectValue.csv
    fi
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
    sudo sed -i '/autologin-user=root/d' /etc/lightdm/lightdm.conf
    sudo sed -i "/greeter-hide-users=true/a autologin-user=root" /etc/lightdm/lightdm.conf
    sudo systemctl daemon-reload && sudo systemctl disable windcore.service && sudo systemctl enable windcore.timer && sudo systemctl start windcore.service
    
    WindfarmID=`grep 'WindfarmID,' $WindCoreCfg/Application_HistoryData.csv|awk -F ',' '{print $2}'`
    mkdir -p $SCADA_PATH/$WindfarmID
    log_info "WindCore程序部署完成！"
   
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


scada_daemon(){
    cat > /usr/lib/systemd/system/scada-daemon.service << EOF
[Unit]
Documentation=daemon project

[Service]
Type=simple
ExecStart=$SCADA_PATH/scada-daemon.sh
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.targe
EOF

cat > scada-daemon.sh << EOF
#!/bin/bash
#SCADA守护进程

#相关的服务

SERVICES=(windcore.service winddp.service monitor-backend.service redis.service influxd.service)

DATE=\`date +"%Y%m%d"\`
#日志文件
LOG_FILE=/var/log/scada-\$DATE.log

###
#log
###
log_info(){
    echo "\`date +"%Y-%m-%d %H:%M:%S"\` [INFO]: \$1"|tee -a \$LOG_FILE
}

log_error(){
    echo -e "\033[31m \`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]:  \$1 \033[0m"|tee -a \$LOG_FILE
}

while true
do
    sleep 60
    
    for serviceName in \${SERVICES[*]}
    do
        if ! systemctl status \$serviceName|grep 'Active'|grep 'active'|grep -v 'inactive' >/dev/null 2>&1
        #systemctl status \$serviceName|grep 'Active'|grep 'active'|grep -v 'inactive' #包含stop的服务
        then
            systemctl restart \$serviceName
            log_error "\$serviceName服务状态异常，重启服务，尝试恢复！"
        fi
        log_info "\$serviceName服务检测正常。"
    done

done
EOF

}
#hostnamectl set-hostname wmmcs-server
#if ! grep 'DISPLAY=:0.0' /etc/profile
#then
    #echo 'export DISPLAY=:0.0' >> /etc/profile 
#fi
#export DISPLAY=:0.0
main(){
log_info "创建windeyapps组"
create_group
log_info "正在配置VNC... ..."
init_VNC
log_info "正在配置redis... ..."
install_redis
log_info "正在配置influxdb... ..."
install_influxdb
log_info "正在安装瀚高数据库... ..."
init_HGDB
log_info "正在安装WindCore... ..."
init_WindCore
log_info "正在安装nodejs... ..."
init_nodejs
log_info "正在安装WindDP"
install_WindDP
log_info "正在安装monitor-backend... ..."
init_monitorBackend
log_info "正在添加清理脚本... ..."
clean
systemd_mask_Service
sudo chown :windeyapps -R $SCADA_PATH
log_info "wmmcs环境部署完成"
}
main