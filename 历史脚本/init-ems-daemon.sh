#!/bin/bash
#ems守护进程

#相关的服务
cat >ems-daemon<<EOF
#!/bin/bash
SERVICES=(windcore.service windmanagerui.service windstat.service windconfig.service redis.service influxd.service winddump.service)

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