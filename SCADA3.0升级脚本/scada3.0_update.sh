#!/bin/bash
NODEHOME='/usr/local/node'
SCADA_PATH='/home/data'
WorkingDirectory='/etc/windeyapps/startup'


init_WindBES(){
    if ! test -d WindBES
    then
	    log_error "不存在 WindBES安装包,请确认！"
	    exit 1
    fi
    if test -d $SCADA_PATH/WindBES
    then
        \cp -r $SCADA_PATH/WindBES/exported  ./WindBES/
        mv $SCADA_PATH/WindBES $SCADA_PATH/WindBES_`date +"%Y%m%d%H%M%S"`
    fi
    \cp -r WindBES/ $SCADA_PATH
    test -d $WorkingDirectory || mkdir -p $WorkingDirectory
    cat > $WorkingDirectory/windbes.sh<<EOF
#!/bin/bash
NODE_PATH=$NODEHOME/bin/node
start(){
    cd $SCADA_PATH/WindBES/ && nohup \$NODE_PATH index.js >/dev/null 2>&1 &
}
start
EOF
cat > windbes.service <<EOF
[Unit]
Description=node project

[Service]
Type=forking 
User=root
Group=windeyapps
ExecStart=$WorkingDirectory/windbes.sh
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target
EOF

    sudo firewall-cmd --add-port=9161/tcp --permanent
    sudo firewall-cmd --add-port=9162/tcp --permanent
    sudo firewall-cmd --reload
    chmod +x $WorkingDirectory/windbes.sh
    sudo systemctl daemon-reload
    \cp windbes.service /usr/lib/systemd/system/
    chown root:windeyapps /home/data/ -R
    sudo systemctl enable windbes.service && sudo systemctl start windbes.service && systemctl status windbes.service

}

backup_sql(){
    echo "正在备份wind数据库，请稍后... ..."
    test -d /home/data/highgo-see/backup|| mkdir -p /home/data/highgo-see/backup
    PGPASSWORD=Hg123456% /opt/HighGo456-see/bin/pg_dump -F c -f /home/data/highgo-see/backup/wind_`date +"%Y%m%d%H%M%S"`.dmp -C -E UTF8 -h 127.0.0.1 -U sysdba wind
    if [[ $? -ne 0 ]]
    then
        echo "wind数据库备份失败，请确认！"
        exit 1
    fi
    echo "wind数据库备份完成。"
}


update_sql(){
    PGPASSWORD=Hg123456% /opt/HighGo456-see/bin/psql -d wind -U sysdba -f drop_view.sql
    if [[ $? -ne 0 ]]
    then
        echo "drop_view.sql执行失败，请确认！"
        exit 1
    fi
    PGPASSWORD=Hg123456% /opt/HighGo456-see/bin/psql -d wind -U sysdba -f create_table.sql
    if [[ $? -ne 0 ]]
    then
        echo "create_table.sql执行失败，请确认！"
        exit 1
    fi
    PGPASSWORD=Hg123456% /opt/HighGo456-see/bin/psql -d wind -U sysdba -f create_view.sql
    if [[ $? -ne 0 ]]
    then
        echo "create_view.sql执行失败，请确认！"
        exit 1
    fi
    for file in csv/*
    do
        TableName=`echo $file|awk -F '/' '{print $2}'|awk -F '.' '{print $1}'`
        PGPASSWORD=Hg123456% /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.$TableName FROM ""'"$PWD/$file"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
        if [[ $? -ne 0 ]]
        then
            echo "$file执行失败，请确认！！"
            exit 1
        fi
    done
}



main(){
    systemctl stop scada-daemon.service
systemctl stop monitor-backend.service && systemctl disable monitor-backend.service
cat >scada-daemon<<EOF
#!/bin/bash
SERVICES=(windcore.service winddp.service windbes.service redis.service influxd.service)

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
init_WindBES
systemctl start scada-daemon.service

}

backup_sql
update_sql

main
