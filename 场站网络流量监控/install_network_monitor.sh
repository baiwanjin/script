#!/bin/bash
#技术中心@白万进
#20220809
#日志文件
LOG_FILE=install-network_monitor-$DATE.log
DATA_PATH='/home/data'
WORKSPACE=$DATA_PATH/'networkmonitor'

###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  $1 \033[0m"|tee -a $LOG_FILE
}


check(){
    if ! test -e fping-3.10-4.ky3.kb1.x86_64.rpm
    then
        log_error "未找到fping-3.10-4.ky3.kb1.x86_64.rpm安装包！"
        exit 1
    fi
    if ! test -e influxdb2.3.tar
    then
        log_error "未找到influxdb2.3.tar镜像包！"
        exit 1
    fi
    if ! test -e influxdb2.zip
    then
        log_error "未找到influxdb2.zip初始化安装包！"
        exit 1
    fi
    if ! test networkmonitor
    then
        log_error "未找到networkmonitor程序包！"
        exit 1
    fi
    if ! test -e docker.zip
    then
        log_error "未找到docker.zip依赖安装包！"
        exit 1
    fi
    if ! test -e config.json
    then
        log_error "未找到config.json配置文件！"
        exit 1
    fi
}


install_fping(){
    log_info "开始安装fping组件... ..."
    if fping -v >/dev/null 2>&1
    then
        log_info "检测到系统已经安装fping组件，未作任何变动!"
        return 
    fi
    rpm -ivh fping-*.rpm --nodeps 
}
install_docker(){
    log_info "开始安装docker组件... ..."
    if docker -v >/dev/null 2>&1
    then
        log_info "检测到系统已经安装docker组件，未作任何变动！"
        return
    else
        unzip -o -q docker.zip
        for i in `ls docker/*`
        do
            rpm -Uvh $i --nodeps
        done
        sleep 2
        systemctl restart docker
    fi
}
init_influxDB(){
    systemctl enable docker.service
    log_info "开始初始化influxDB... ..."
    if systemctl status docker.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        unzip -o -q influxdb2.zip
        mv influxdb2 network-influxdb2
        test -d $DATA_PATH || mkdir -p $DATA_PATH
        \cp -r network-influxdb2 $DATA_PATH
        docker load -i influxdb2.3.tar
        docker run -itd -p 18086:8086 -v $DATA_PATH/network-influxdb2:/var/lib/influxdb2 --name network-influxdb2 docker.io/influxdb:2.3.0 
        
        docker update --restart=always network-influxdb2
        sudo firewall-cmd --add-port=18086/tcp --permanent
        sudo firewall-cmd --reload
    else
        log_error "当前docker服务未启动，请确认！"
        exit 1
    fi

}

init_networkmonitor(){
    test -d $WORKSPACE || mkdir -p $WORKSPACE
    \cp networkmonitor $WORKSPACE
    \cp config.json $WORKSPACE
    serverName=networkmonitor
    cat >$serverName.service<<-EOF
[Unit]
Description=python project

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$WORKSPACE
ExecStart=$WORKSPACE/networkmonitor
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    chmod +x $WORKSPACE/networkmonitor
    \cp $serverName.service /usr/lib/systemd/system/
    cat > /usr/lib/systemd/system/$serverName.timer <<EOF
[Unit]
Description=java project

[Timer]
OnBootSec=1min
Unit=$serverName.service

[Install]
WantedBy=graphical.target
EOF
    systemctl daemon-reload &&  systemctl disable $serverName.service &&  systemctl enable $serverName.timer && systemctl start $serverName.service
}

main(){
    check
    install_fping
    install_docker
    init_influxDB
    init_networkmonitor
}

main