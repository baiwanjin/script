#!/bin/bash

#redis-scada
REDIS_SCADA_PASSWD='Sa123456%'
#redis-ems
REDIS_EMS_PASSWD='windey'
#influx-scada
INFLUX_USER='root'
INFLUX_PASSWD='root'
INFLUX_DATABASE='wind_tsdb'
INFLUX_DATABASE_DURATION='720h0m0s'
#influx-ems
INFLUX2_USER='windey'
INFLUX2_PASSWD='WindeyXT@2022'
INFLUX2_DATABASE='windmanager'
INFLUX2_DATABASE_DURATION='720h0m0s'
#hgdb
HGDB_USER='sysdba'
HGDB_PASSWD='Hg123456%'
HGDB_DATABASE='wind'
HGDB_PORT='5866'
HGDB_CONF='/home/data/highgo-see/data/postgresql.conf'

#瀚高数据库配置文件检测项
HGDB_postgresql_conf=('max_connections:2000' 'shared_buffers:1024MB' 'listen_addresses:\*')
#瀚高数据库参数检测项
HGDB_select_show_secure_param=('hg_sepofpowers:off' 'hg_macontrol:min' 'hg_rowsecure:off')
#瀚高数据库定时任务
crontab_list=('/etc/crontablist/sch_calc_wt_power_curve_3mouth.sh' '/etc/crontablist/sch_calc_avg_power_day.sh')
#清理脚本路径
CLEACLEAN_HISTORY_DATA='/etc/crontablist/clean-history-data.sh'

#总的输出字节数
NUM_BYTE=100

DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=hgdb-restore-$DATE.log
###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  $1 \033[0m"|tee -a $LOG_FILE
}

print_ok(){
    #输出字符的字节数
    #STR_BYTE=`echo $1|wc -L`
    STR_BYTE=$(echo `date +"%Y-%m-%d %H:%M:%S"` $1|wc -L)
    #输出的补充字符个数
    SUPPLEMENT_NUM=$[$NUM_BYTE-$STR_BYTE]
    SPACES=$(seq -s '-' $SUPPLEMENT_NUM | sed 's/[0-9]//g')
    echo -e "#`date +"%Y-%m-%d %H:%M:%S"` $1 $SPACES [OK]#"|tee -a $2
}
print_no(){
    #输出字符的字节数
    STR_BYTE=$(echo `date +"%Y-%m-%d %H:%M:%S"` $1|wc -L)
    #输出的补充字符个数
    SUPPLEMENT_NUM=$[$NUM_BYTE-$STR_BYTE]
    SPACES=$(seq -s '-' $SUPPLEMENT_NUM | sed 's/[0-9]//g')
    echo -e "#`date +"%Y-%m-%d %H:%M:%S"` $1 $SPACES [NO]#"|tee -a $2
}

################hostname
check_hostname(){
    hostname=`hostnamectl --static`
    echo -e "当前服务器主机名为:\"$hostname\""|tee -a $1
}

##############VNC
vnc_status(){
    if systemctl status vncserver-x11-serviced|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "vncserver-x11-serviced服务是否为开启状态" $1
    else
        print_no "vncserver-x11-serviced服务是否为开启状态" $1
    fi
}
vnc_enabled(){
    if systemctl list-unit-files|grep 'vncserver-x11-serviced'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "vncserver-x11-serviced服务是否为开机自启" $1
    else
        print_no "vncserver-x11-serviced服务是否为开机自启" $1
    fi
}
#############守护进程
daemon_status(){
    if systemctl status $1-daemon|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "$1守护进程$1-daemon服务是否为开启状态" $2
    else
        print_no "$1守护进程$1-daemon服务是否为开启状态" $2
    fi
}
daemon_enabled(){
    if systemctl list-unit-files|grep "$1-daemon"|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "$1守护进程$1-daemon服务是否为开机自启" $2
    else
        print_no "$1守护进程$1-daemon服务是否为开机自启" $2
    fi
}



#################INFLUX
influx1_database(){
    if influx -username $INFLUX_USER -password $INFLUX_PASSWD -execute "SHOW DATABASES"|grep $INFLUX_DATABASE  >/dev/null 2>&1
    then
        print_ok "influx数据库\"$INFLUX_DATABASE\"是否存在" $1
    else
        print_no "influx数据库\"$INFLUX_DATABASE\"是否存在" $1
    fi
}

influx2_database(){
    if sudo -u influxdb  influx bucket list|grep $INFLUX2_DATABASE  >/dev/null 2>&1
    then
        print_ok "influx数据库\"$INFLUX2_DATABASE\"是否存在" $1
    else
        print_no "influx数据库\"$INFLUX2_DATABASE\"是否存在" $1
    fi
}




influx1_database_duration(){
    if influx -username $INFLUX_USER -password $INFLUX_PASSWD -execute "SHOW RETENTION POLICIES ON $INFLUX_DATABASE"|grep $INFLUX_DATABASE_DURATION  >/dev/null 2>&1
    then
        print_ok "influx数据库\"$INFLUX_DATABASE\"数据保留时间为:\"$INFLUX_DATABASE_DURATION\"" $1
    else
        print_no "influx数据库\"$INFLUX_DATABASE\"数据保留时间为:\"$INFLUX_DATABASE_DURATION\"" $1
    fi
}

influx2_database_duration(){
    if  sudo -u influxdb influx bucket list|grep $INFLUX2_DATABASE|grep $INFLUX2_DATABASE_DURATION  >/dev/null 2>&1
    then
        print_ok "influx数据库\"$INFLUX2_DATABASE\"数据保留时间为:\"$INFLUX2_DATABASE_DURATION\"" $1
    else
        print_no "influx数据库\"$INFLUX2_DATABASE\"数据保留时间为:\"$INFLUX2_DATABASE_DURATION\"" $1
    fi
}

influx1_login(){
    if influx -username $INFLUX_USER -password $INFLUX_PASSWD -execute "SHOW DATABASES" >/dev/null 2>&1
    then
        print_ok "influx数据库$INFLUX_USER:$INFLUX_PASSWD是否登录成功" $1
        influx1_database $1
        influx1_database_duration $1
    else
        print_no "influx数据库$INFLUX_USER:$INFLUX_PASSWD是否登录成功" $1
    fi
}

influx_status(){
    if systemctl status influxd|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "influx数据库是否为开启状态" $1
    else
        print_no "influx数据库是否为开启状态" $1
    fi
}

influx_enabled(){
    if systemctl list-unit-files|grep 'influxd'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "influx数据库是否为开机自启" $1
    else
        print_no "influx数据库是否为开机自启" $1
    fi
}

check_influx(){
    
    echo -e "********************"|tee -a $2
    echo -e " influx数据库检测"|tee -a $2
    echo -e "********************"|tee -a $2
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $2
    if [[ $1 == 'SCADA' ]]
    then
        influx_status $2
        influx_enabled $2
        influx1_login $2
    fi
    if [[ $1 == 'EMS' ]]
    then
        influx_status $2
        influx_enabled $2
        influx2_database $2
        influx2_database_duration $2
       
    fi
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $2
}


redis_status(){
    if systemctl status redis|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "数据库redis.service是否为开启状态" $1
    else
        print_no "数据库redis.service是否为开启状态" $1
    fi
}

redis_enabled(){
    if systemctl list-unit-files|grep 'redis'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "数据库redis.service是否为开机自启" $1
    else
        print_no "数据库redis.service是否为开机自启" $1
    fi
}
redis_login(){
    if  redis-cli -h 127.0.0.1 -a $REDIS_SCADA_PASSWD select 5|grep 'OK' >/dev/null 2>&1
    then
        print_ok "redis数据库密码:$REDIS_SCADA_PASSWD是否可以登录数据库" $1
    else
        print_ok "redis数据库密码:$REDIS_SCADA_PASSWD是否可以登录数据库" $1
    fi
}
redis2_login(){
    if  redis-cli -h 127.0.0.1 -a $REDIS_EMS_PASSWD select 5|grep 'OK' >/dev/null 2>&1
    then
        print_ok "redis数据库密码:$REDIS_EMS_PASSWD是否可以登录数据库" $1
    else
        print_ok "redis数据库密码:$REDIS_EMS_PASSWD是否可以登录数据库" $1
    fi
}


check_redis(){
    echo -e "********************"|tee -a $2
    echo -e " redis 数据库检测"|tee -a $2
    echo -e "********************"|tee -a $2
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $2
    if [[ $1 == 'SCADA' ]]
    then
        redis_status $2
        redis_enabled $2
        redis_login $2

    fi
    if [[ $1 == 'EMS' ]]
    then
        redis_status $2
        redis_enabled $2
        redis2_login $2

    fi
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $2
}


hgdb_database(){
    if PGPASSWORD=$HGDB_PASSWD psql -h 127.0.0.1 -p $HGDB_PORT -U $HGDB_USER -c "select datname from pg_database" |grep  $HGDB_DATABASE >/dev/null 2>&1
    then
        print_ok "瀚高数据库$HGDB_DATABASE是否存在" $1 
    else
        print_no "瀚高数据库$HGDB_DATABASE是否存在" $1 
    fi
}

hgdb_show_secure_param(){
    for i in $(seq ${#HGDB_select_show_secure_param[*]})
    do 
        str=`echo ${HGDB_select_show_secure_param[i-1]}`
        key=`echo ${str%:*}`
        value=`echo ${str#*:}`
        if PGPASSWORD=$HGDB_PASSWD psql -h 127.0.0.1 -p $HGDB_PORT -U $HGDB_USER -c "select show_secure_param()"|grep $key|grep $value >/dev/null 2>&1
        then
            print_ok "瀚高数据库select datname from pg_database参数$key的值是否为$value" $1
        else
            print_no "瀚高数据库select datname from pg_database参数$key的值是否为$value" $1
        fi
    done
}

hgdb_conf(){
    for i in $(seq ${#HGDB_postgresql_conf[*]})
    do
        str=`echo ${HGDB_postgresql_conf[i-1]}`
        key=`echo ${str%:*}`
        value=`echo ${str#*:}`
        if grep ^$key $HGDB_CONF | grep $value >/dev/null 2>&1
        then
            print_ok "瀚高数据库配置文件postgresql_conf中$key的值是否为$value" $1
        else
            print_no "瀚高数据库配置文件postgresql_conf中$key的值是否为$value" $1
        fi
    done
}

hgdb_login(){ 
    PGPASSWORD=$HGDB_PASSWD psql -h 127.0.0.1 -p $HGDB_PORT -U $HGDB_USER -c "select datname from pg_database" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_ok "瀚高数据库用户sysdba登录" $1
        hgdb_database $1
        hgdb_show_secure_param $1
        hgdb_conf $1
    else
        print_no "瀚高数据库用户sysdba登录" $1
    fi
}

hgdb_status(){
    if systemctl status hgdb-see-4.5.6.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "数据库hgdb-see-4.5.6.service是否为开启状态" $1
    else
        print_no "数据库hgdb-see-4.5.6.service是否为开启状态" $1
    fi
}


hgdb_enabled(){
    if systemctl list-unit-files|grep 'hgdb-see-4.5.6.service'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "数据库hgdb-see-4.5.6.service是否为开机自启" $1
    else
        print_no "数据库hgdb-see-4.5.6.service是否为开机自启" $1
    fi
}

crontab_task(){
    for cron in ${crontab_list[*]}
    do
        if crontab -l|grep $cron  >/dev/null 2>&1
        then
            print_ok "定时任务:$cron是否存在" $1
        else
            print_no "定时任务:$cron是否存在" $1
        fi
    done
}
check_hgdb(){
    echo -e "********************"|tee -a $1
    echo -e " 瀚高数据库检测"|tee -a $1
    echo -e "********************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    hgdb_status $1
    hgdb_enabled $1
    hgdb_login $1
    crontab_task $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

check_node(){
    echo -e "*****************"|tee -a $1
    echo -e " node环境检测"|tee -a $1
    echo -e "*****************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    if node -v |grep ^v >/dev/null 2>&1
    then
        print_ok "node环境是否已经安装" $1
    else
        print_no "node环境是否已经安装" $1
    fi
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

check_java(){
    echo -e "*****************"|tee -a $1
    echo -e " JAVA环境检测"|tee -a $1
    echo -e "*****************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    if javac -version >/dev/null 2>&1
    then
        print_ok "java环境是否已经安装" $1
    else
        print_no "java环境是否已经安装" $1
    fi
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

windcore_status(){
    if systemctl status windcore.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "windcore.service服务是否为开启状态" $1
    else
        print_no "windcore.service服务是否为开启状态" $1
    fi
}

windcore_enabled(){
    if systemctl list-unit-files|grep 'windcore.timer'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "windcore.service服务是否为开机自启" $1
    else
        print_no "windcore.service服务是否为开机自启" $1
    fi
}

check_windcore(){
    echo -e "********************"|tee -a $1
    echo -e " WindCore服务检测"|tee -a $1
    echo -e "********************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    windcore_status $1
    windcore_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

winddp_status(){
    if systemctl status winddp.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "winddp.service服务是否为开启状态" $1
    else
        print_no "winddp.service服务是否为开启状态" $1
    fi
}

winddp_enabled(){
    if systemctl list-unit-files|grep 'winddp.service'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "winddp.service服务是否为开机自启" $1
    else
        print_no "winddp.service服务是否为开机自启" $1
    fi
}

check_winddp(){
    echo -e "*******************"|tee -a $1
    echo -e " WindDP服务检测"|tee -a $1
    echo -e "*******************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    winddp_status $1
    winddp_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}


monitor_backend_status(){
    if systemctl status monitor-backend.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "monitor-backend.service服务是否为开启状态" $1
    else
        print_no "monitor-backend.service服务是否为开启状态" $1
    fi
}

monitor_backend_enabled(){
    if systemctl list-unit-files|grep 'monitor-backend.service'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "monitor-backend.service服务是否为开机自启" $1
    else
        print_no "monitor-backend.service服务是否为开机自启" $1
    fi
}

check_monitor-backend(){
    echo -e "***************************"|tee -a $1
    echo -e " monitor-backend服务检测"|tee -a $1
    echo -e "***************************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    monitor_backend_status $1
    monitor_backend_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

clean_history_data(){
    if crontab -l | grep $CLEACLEAN_HISTORY_DATA >/dev/null 2>&1
    then
        print_ok "是否存在系统定时清理任务:$CLEACLEAN_HISTORY_DATA" $1
    else
        print_no "是否存在系统定时清理任务:$CLEACLEAN_HISTORY_DATA" $1
    fi
}

check_defend(){
    echo -e "********************"|tee -a $1
    echo -e " 基线加固检测及其他"|tee -a $1
    echo -e "********************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    if ls /etc/config_backup* >/dev/null 2>&1
    then
        print_ok "该系统是否执行过基线加固" $1
    else 
        print_no "该系统是否执行过基线加固" $1
    fi
    clean_history_data $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    vnc_status $1
    vnc_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    daemon_status $2 $1
    daemon_enabled $2 $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    check_hostname $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    echo -e "磁盘详情:"|tee -a $1
    lsblk -m |tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    echo -e "CPU详情:"|tee -a $1
    lscpu|grep -v 'Flags:'|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    echo -e "内存详情:"|tee -a $1
    free -h|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1

}


windmanagerui_status(){
    if systemctl status windmanagerui.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "windmanagerui.service服务是否为开启状态" $1
    else
        print_no "windmanagerui.service服务是否为开启状态" $1
    fi
}

windmanagerui_enabled(){
    if systemctl list-unit-files|grep 'windmanagerui.service'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "windmanagerui.service服务是否为开机自启" $1
    else
        print_no "windmanagerui.service服务是否为开机自启" $1
    fi
}

check_windmanagerui(){
    echo -e "*************************"|tee -a $1
    echo -e " windmanagerui服务检测"|tee -a $1
    echo -e "************************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    windmanagerui_status $1
    windmanagerui_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

windstat_status(){
    if systemctl status windstat.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "windstat.service服务是否为开启状态" $1
    else
        print_no "windstat.service服务是否为开启状态" $1
    fi
}

windstat_enabled(){
    if systemctl list-unit-files|grep 'windstat.service'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "windstat.service服务是否为开机自启" $1
    else
        print_no "windstat.service服务是否为开机自启" $1
    fi
}

check_windstat(){
    echo -e "*******************"|tee -a $1
    echo -e " windstat服务检测"|tee -a $1
    echo -e "*******************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    windstat_status $1
    windstat_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}


windconfig_status(){
    if systemctl status windconfig.service|grep 'Active'|grep 'active' >/dev/null 2>&1
    then
        print_ok "windconfig.service服务是否为开启状态" $1
    else
        print_no "windconfig.service服务是否为开启状态" $1
    fi
}

windconfig_enabled(){
    if systemctl list-unit-files|grep 'windconfig.service'|grep 'enabled' >/dev/null 2>&1
    then
        print_ok "windconfig.service服务是否为开机自启" $1
    else
        print_no "windconfig.service服务是否为开机自启" $1
    fi
}

check_windconfig(){
    echo -e "*********************"|tee -a $1
    echo -e " windconfig服务检测"|tee -a $1
    echo -e "*********************"|tee -a $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
    windconfig_status $1
    windconfig_enabled $1
    SPACES=$(seq -s '=' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES========"|tee -a $1
}

scada_check(){

    SPACES=$(seq -s '#' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES########"|tee -a $1
    check_influx SCADA $1
    check_redis SCADA $1
    check_hgdb $1
    check_node $1
    check_java $1
    check_windcore $1
    check_winddp $1
    check_monitor-backend $1
    check_defend $1 scada
    SPACES=$(seq -s '#' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES########"|tee -a $1
}

ems_check(){
    SPACES=$(seq -s '#' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES########"|tee -a $1
    check_influx EMS $1
    check_redis EMS $1
    check_node $1
    check_java $1
    check_windcore $1
    check_windmanagerui $1
    check_windstat $1
    check_windconfig $1
    check_defend $1 ems
    SPACES=$(seq -s '#' $NUM_BYTE | sed 's/[0-9]//g')
    echo -e "$SPACES########"|tee -a $1

}
main(){

    case $1 in
    scada)
        if ! cat /etc/.kyinfo | grep SCADA-Server  >/dev/null 2>&1
        then
            echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  这不是一台SCADA-Server类型的服务器，请确认！ \033[0m"
            exit 1
        fi
        scada_check scada-check-$DATE.txt
        ;;
    ems)
        if ! cat /etc/.kyinfo | grep EMS-Server  >/dev/null 2>&1
        then
            echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  这不是一台EMS-Server类型的服务器，请确认！ \033[0m"
            exit 1
        fi
        ems_check ems-check-$DATE.txt
        ;;
    cms)
        echo "待维护"
        ;;
    *)
        echo "请选择检测系统类型"
        echo "windey-check scada 检测SCADA主机部署状态"
        echo "windey-check ems 检测能管主机部署状态"
        echo "windey-check cms 检测CMS主机部署状态"
        ;;
    esac
}

main $1