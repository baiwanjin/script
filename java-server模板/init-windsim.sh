#!/bin/bash

create_group(){
	if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
	then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
	fi
    chattr -i /etc/passwd
    chattr -i /etc/shadow
    sudo usermod -G windeyapps root
    sudo usermod -G windeyapps redis
    sudo usermod -G windeyapps influxdb
    chattr +i /etc/group
    chattr +i /etc/gshadow
    chattr +i /etc/passwd
    chattr +i /etc/shadow
}
init_windsim(){
    cat > /home/data/windsim/windsim.sh <<EOF
#!/bin/bash
jarName="windsim.jar"
workDir="/home/data/windsim"
start(){
    cd \${workDir} && java -server -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=128m -Xms512m -Xmx512m -Xmn256m -Xss256k -XX:SurvivorRatio=8 -XX:+UseConcMarkSweepGC -jar \${jarName} >/dev/null 2>&1 &
}

stop(){
    ps -ef | grep -qP "(?<=-jar)\\s+\${jarName}" && kill \$(ps -ef | grep -P "(?<=-jar)\\s+\${jarName}" | awk '{print \$2}')
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

    chmod +x /home/data/windsim/windsim.sh

    cat > /usr/lib/systemd/system/windsim.service <<EOF
[Unit]
Description=java project

[Service]
Type=forking
User=root
Group=windeyapps
WorkingDirectory=/home/data/windsim
ExecStart=/bin/bash windsim.sh start
ExecStop=/bin/bash windsim.sh stop
ExecReload=/bin/bash windsim.sh restart
PrivateTmp=True

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload && systemctl enable windsim.service && systemctl restart windsim.service
    firewall-cmd --add-port=9160/tcp --permanent
    firewall-cmd --reload
}

main(){
    test -d /home/data || mkdir -p /home/data
    if ! test -e windsim
    then
        echo "当前目录下不存在 windsim文件"
        exit 1
    fi
    if test -d /home/data/windsim
    then
        mv /home/data/windsim /home/data/windsim_`date +"%Y%m%d%H%M%S"`.bak
    fi
    # unzip -o -q  windsim.zip
    \cp -r windsim /home/data/
    create_group
    init_windsim
    systemctl status windsim.service
    echo 'windsim服务安装完成'
    echo '安装路径：/home/data/windsim'
}

main