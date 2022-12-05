#!/bin/bash
#能管3.0配置导出
#技术中心@白万进
#20221103
Windfarm=`/usr/bin/grep WindfarmID /home/data/windconfig/WindfarmID|/usr/bin/awk -F ',' '{print $2}'|/usr/bin/awk -F 'Windfarm' '{print $2}'`
if [ -z $Windfarm ]
then
    Windfarm=$1
fi
time3=$(/usr/bin/date "+%Y%m%d%H%M%S")
gethostname=$(/usr/bin/hostname)
ConfigName="${gethostname}-ems3_Windfarm$Windfarm""_${time3}"

#时间戳
DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=Error-$DATE.log

log_error(){
    /usr/bin/echo -e "`/usr/bin/date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|/usr/bin/tee -a $LOG_FILE
}

#收集系统信息

collect_message(){    
    mkdir -p $ConfigName
    /usr/bin/echo "主机名:">> $ConfigName/system_message
    /usr/bin/hostnamectl >> $ConfigName/system_message
    /usr/bin/echo "服务器类型:">> $ConfigName/system_message
    /usr/bin/cat /etc/.kyinfo >> $ConfigName/system_message
    /usr/bin/echo "磁盘信息:">> $ConfigName/system_message
    /usr/bin/df -Th >> $ConfigName/system_message
    /usr/bin/echo "负载信息:">> $ConfigName/system_message
    /usr/bin/uptime >> $ConfigName/system_message
    /usr/bin/echo "查看磁盘历史IO信息:">> $ConfigName/system_message
    /usr/bin/sar -d 1 1 >> $ConfigName/system_message
    /usr/bin/echo "磁盘的使情况:" >> $ConfigName/system_message
    /usr/bin/iostat -d -x -k 1 1 >> $ConfigName/system_message
    /usr/bin/echo "占用内存(MEM)最高的前10个进程:" >> $ConfigName/system_message
    /usr/bin/ps aux|/usr/bin/head -1;/usr/bin/ps aux|/usr/bin/grep -v PID|/usr/bin/sort -rn -k +4|/usr/bin/head >> $ConfigName/system_message
    /usr/bin/echo "占用 cpu 最高的前10个进程:" >> $ConfigName/system_message
    /usr/bin/ps aux|/usr/bin/head -1;/usr/bin/ps aux|/usr/bin/grep -v PID|/usr/bin/sort -rn -k +3|/usr/bin/head >> $ConfigName/system_message
}

#windconfig配置备份
backup_windconfig(){
    if /usr/bin/test -d /home/data/windconfig
    then
        /usr/bin/mkdir -p $ConfigName/windconfig 
        /usr/bin/\cp -a /home/data/windconfig/db $ConfigName/windconfig 
        /usr/bin/\cp -a /home/data/windconfig/application.properties $ConfigName/windconfig 
    else
        log_error "/home/data/windconfig目录不存在！"
    fi
}

#winddump配置备份
backup_winddump(){
    if /usr/bin/test -d /home/data/winddump
    then
        /usr/bin/mkdir -p $ConfigName/winddump
        /usr/bin/\cp -a /home/data/winddump/application.properties $ConfigName/winddump
    else
        log_error "/home/data/winddump目录不存在！"
    fi
}

#windmanager配置备份
backup_windmanager(){
    if /usr/bin/test -d /home/data/windmanager
    then
        /usr/bin/mkdir -p $ConfigName/windmanager
        /usr/bin/\cp -a /home/data/windmanager/cfg $ConfigName/windmanager
    else
        log_error "/home/data/windmanager目录不存在！"
    fi
}

#windmanager配置备份
backup_windmanagerui(){
    if /usr/bin/test -d /home/data/windmanagerui
    then
        /usr/bin/mkdir -p  $ConfigName/windmanagerui
        /usr/bin/\cp -a /home/data/windmanagerui/config  $ConfigName/windmanagerui
    else
        log_error "/home/data/windmanagerui目录不存在！"
    fi
}

# windstat配置备份：
backup_windstat(){
    if /usr/bin/test -d /home/data/windstat
    then
        /usr/bin/mkdir -p  $ConfigName/windstat
        /usr/bin/\cp -a /home/data/windstat/config  $ConfigName/windstat
        /usr/bin/\cp -a /home/data/windstat/application.properties  $ConfigName/windstat
    else
        log_error "/home/data/windstat目录不存在！"
    fi
}


#
main(){
    /usr/bin/test -d $ConfigName || /usr/bin/mkdir -p $ConfigName
    collect_message
    backup_windconfig
    backup_winddump
    backup_windmanager
    backup_windmanagerui
    backup_windstat
    redis-cli -a windey mget EMS.A.Ver EMS.D.Ver EMS.E.Ver EMS.F.Ver EMS.G.Ver > $ConfigName/version.txt
    /usr/bin/zip -v -r  $ConfigName.zip $ConfigName
    echo "******************************************************************"
    echo "****能管系统配置备份完成，请将$ConfigName.zip文件返回给技术人员*****"
    echo "******************************************************************"
}

main