#!/bin/bash
DATE=`date +"%Y%m%d%H%M%S"`
parameter=''
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
    cd \${workDir} && java $parameter -jar \${jarName} >> /var/log/${serverName}.log 2>&1 &
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


main(){
    if ! test -d $1
    then
        echo "不存在$1文件，请确认！"
        exit 1
    fi
    if test -d $3/$1
    then
        echo "$3目录下存在$1文件夹，将$1命名为$1_$DATE.bak"
        mv $3/$1 $3/$1_$DATE.bak
    fi
    \cp -r  $1 $3
    chown :windeyapps $3/$1 -R
    init_jar $2 $3/$1 $4
    sleep 3
    systemctl status $4.service|grep 'Active'|grep 'active' && echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 服务$4安装成功！" && return
    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 服务$4安装失败！ \033[0m"
}

#$1:包名
#$2:jar包名
#$3:安装目录
#$4:服务名
main winddps "winddps.jar" "/home/data" "winddps"
