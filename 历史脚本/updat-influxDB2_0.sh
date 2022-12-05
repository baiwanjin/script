#!/bin/bash

#influxDB1.x数据库配置文件路径
INFLUX1_CONF='/etc/influxdb/influxdb.conf'

#influxDB1.x数据库数据文件存放路径(默认路径'/var/lib/influxdb/data')
INFLUX1_DATA='/var/lib/influxdb/data'
#INFLUX1_DATA='/home/data/.windmanager/' #(EMS部署未对数据库文件有详细的分类，指定该目录，对该目录进行全备)

#influxDB1.x数据库家目录(默认路径'/var/lib/influxdb')
INFLUX1_HOME="`cat /etc/passwd|grep 'influxdb'|awk -F ':' '{print $6}'`"

#influx2.x数据文件存放目录
INFLUX2_DATA='/home/data/.windmanager/influx2'

DATE=`date +"%Y%m%d%H%M%S"`
INFLUX1_BACKUP="/home/influx1_backup-$DATE"
#日志文件
LOG_FILE=update-influxDB2-$DATE.log
###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  $1 \033[0m"|tee -a $LOG_FILE
}

install_automation(){
    if ls $PWD/automation/*.rpm >/dev/null 2>&1
    then
        if ! rpm -qa|grep expect 1>/dev/null
        then
	        sudo rpm -ivh $PWD/automation/tcl*.rpm >/dev/null 2>&1
            sudo rpm -ivh $PWD/automation/expect*.rpm >/dev/null 2>&1
	    fi
        if ! rpm -qa|grep sshpass 1>/dev/null
	    then
	        sudo rpm -ivh $PWD/automation/sshpass*.rpm >/dev/null 2>&1
	    fi
        
    else
	log_error "未找到缺少expect安装包，请确认！"
	exit 1
    fi
}

check_disk_space(){
    FILE_SIZE=`du -sm $1|awk '{print $1}'`
    log_info "$1目录的占用空间为: $FILE_SIZE M"
    NEED_SIZE=$[$FILE_SIZE*2]
    log_info "本次升级需要实际空间大小为: $NEED_SIZE M"
    DISK_Avail=`df -m $2|awk 'NR>1{print $4}'`
    log_info "当前分区:$2 的可用空间为: $DISK_Avail M"
    if [[ $DISK_Avail -lt $NEED_SIZE ]]
    then
        log_error "当前分区:$2 可用空间不足，升级终止！"
        exit 1
    fi
}

update_influxdb(){
#     cat > expect.sh <<-EOF
# #!/usr/bin/expect
# set timeout -1 
# spawn sudo -u influxdb influxd upgrade --config-file $INFLUX1_HOME/influxdb.conf --engine-path=$INFLUX2_DATA
# expect "*username"
# send "root\r"
# expect "*password"
# send "WindeyXT@2022\r"
# expect "*again"
# send "WindeyXT@2022\r"
# expect "*name"
# send "windey\r"
# expect "*name"
# send "ems\r"
# expect "*infinite."
# send "720\r"
# expect "*y/n"
# send "y\r"
# interact
# EOF
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
    chmod +x expect.sh && ./expect.sh 2>> $LOG_FILE
    if [ $? -ne 0 ]; then
        log_error "数据库upgrade_influxdb失败！"
        exit 1
    fi
rm -f expect.sh
cat /var/lib/influxdb/.influxdbv2/configs|grep -v '#'|grep token|awk -F '[""]' '{print $2}' > token.txt
}
start_infludb2(){
     for i in {1..10}
        do  
            if  netstat -tunlp|grep 8086
            then
			    sleep 5
                update_influxdb
                return
            fi
            log_info "正在等待influxdb启动完成！"
            sleep 3
        done
}
init_influxdb2(){
    log_info "正在进行升级前环境检测，请稍后... ..."
    influxdbVersion=`rpm -qa|grep influxdb|awk -F '-' '{print $2}'|awk -F '.' '{print $NR}'`
    if [[ $influxdbVersion -lt 2 ]]
    then
        log_info "influxdb当前版本小于2.0，升级influxdb。"
        if ! systemctl status influxd|grep Active|awk -F "[()]" '{print $2}'|grep running >/dev/null 2>&1
        then
            log_error "influxDB1服务未正常运行，请确认数据库服务状态！" 
            exit 1
        fi
        install_automation
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
        if influx -execute "SHOW DATABASES"|awk  'NR>4{print $1}'|wc -l |grep 0 >/dev/null 2>&1
        then
            log_info "influxDB1数据库中不存在库"
        else
            log_info "influxDB数据库全备至$INFLUX1_BACKUP"
            test -d $INFLUX1_BACKUP || mkdir -p $INFLUX1_BACKUP
            check_disk_space $INFLUX1_HOME $INFLUX1_BACKUP
            influxd backup -portable  $INFLUX1_BACKUP
        fi
        systemctl stop influxd && systemctl stop influxdb
        # log_info "创建名为sysadm的influx用户，密码为WindeyXT@2022"
        # influx -username root -password root -execute "CREATE USER sysadm WITH PASSWORD 'WindeyXT@2022'"
        # for DATABASE in `influx -username root -password root -execute "SHOW DATABASES"|awk  'NR>4{print $1}'`
        # do  
        #     log_info "赋予sysadm用户数据库$DATABASE库的可读权限"
        #     influx -username root -password root -execute "GRANT READ ON $DATABASE TO sysadm"
        # done
        # log_info "开启influxDB数据库认证"
        # if grep "^auth-enabled" $INFLUX1_CONF >/dev/null 2>&1
        # then
        #     sed -i 's/^auth-enabled.*/auth-enabled=true/g' $INFLUX1_CONF
        # else
        #     sed -i '/auth-enabled/a\auth-enabled=true' $INFLUX1_CONF
        # fi
        # systemctl restart influxd
        # sleep 2
        
       

      
        

        
        check_disk_space $INFLUX1_HOME $INFLUX1_HOME
        log_info "拷贝$INFLUX1_HOME为$INFLUX1_HOME-$DATE,请稍后... ..."
        cp -R $INFLUX1_HOME $INFLUX1_HOME-$DATE
        
        log_info "拷贝$INFLUX1_CONF为$INFLUX1_CONF-$DATE"
        cp -R $INFLUX1_CONF $INFLUX1_CONF-$DATE
        
        check_disk_space $INFLUX1_DATA $INFLUX1_DATA
        log_info "拷贝$INFLUX1_DATA为$INFLUX1_DATA-$DATE,请稍后... ..."
        cp -R $INFLUX1_DATA $INFLUX1_DATA-$DATE
        log_info "将$INFLUX1_CONF文件拷贝至本地"

        cp $INFLUX1_CONF $INFLUX1_HOME
        chown influxdb:influxdb $INFLUX1_HOME/influxdb.conf
        sleep 2
        log_info "升级influxDB数据库"
        rpm -Uvh influxdb-2.*.x86_64.rpm 
        # sleep 2
        # log_info "开始转换1.X数据库为2.Xbucket"
        chmod 777 $PWD
        rpm -Uvh influxdb-2.*.x86_64.rpm 
        sed -i "s#ExecStart=.*#ExecStart=/usr/bin/influxd --engine-path=$INFLUX2_DATA#g" /usr/lib/systemd/system/influxdb.service
        systemctl daemon-reload && systemctl start influxd && systemctl start influxdb
        sleep 5
        start_infludb2
        log_info "配置命令行认证"
        cp /var/lib/influxdb/.influxdbv2/configs $INFLUX1_HOME/.influxdbv2/configs-$DATE
        sed -i 's/org = ""/org = "windey"/' $INFLUX1_HOME/.influxdbv2/configs 
        systemctl enable influxd
        log_info "influxDB数据库升级完成，请确认！"
    fi

}

init_influxdb2