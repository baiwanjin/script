#!/bin/bash

#技术中心@白万进
#20221114
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

init_jar "WindSine.jar" "/home/data/WindSine/" "windsine"