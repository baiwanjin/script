#!/bin/bash
#SCADA守护进程

#相关的服务
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
