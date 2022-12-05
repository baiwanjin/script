#/bin/bash
#SCADA3.0配置导出
#技术中心@白万进
#20221103
HGPASSWD=Hg123456%
SCADA_Path='/home/data'
Windfarm=`grep WindfarmID $SCADA_Path/WindCore/cfg/Application_HistoryData.csv|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
if [ -z $Windfarm ]
then
    Windfarm=$1
fi
time3=$(date "+%Y%m%d%H%M%S")
gethostname=$(hostname)
ConfigName="${gethostname}_Windfarm$Windfarm""_${time3}"

#时间戳
DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=Error-$DATE.log

log_error(){
    /usr/bin/echo -e "`/usr/bin/date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|/usr/bin/tee -a $LOG_FILE
}

#收集系统信息

collect_message(){    
    /usr/bin/test -d $ConfigName || /usr/bin/mkdir -p $ConfigName
    /usr/bin/echo "主机名:"> $ConfigName/system_message
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

backup_windbes(){
    if /usr/bin/test -d /home/data/WindBES
    then
        /usr/bin/mkdir -p $ConfigName/WindBES/config/
        /usr/bin/\cp -a /home/data/WindBES/config/config.js  $ConfigName/WindBES/config/
    else
        log_error "/home/data/WindBES目录不存在！"
    fi
}

backup_winddp(){
    if /usr/bin/test -d /home/data/WindDP
    then
        /usr/bin/mkdir -p $ConfigName/WindDP/cfg
        /usr/bin/\cp -a /home/data/WindDP/cfg/*  $ConfigName/WindDP/cfg/
    else
        log_error "/home/data/WindDP目录不存在！"
    fi
}


backup_winddps(){
    if /usr/bin/test -d /home/data/winddps
    then
        /usr/bin/mkdir -p $ConfigName/winddps/config
        /usr/bin/\cp -a /home/data/winddps/config/*  $ConfigName/winddps/config/
    else
        log_error "/home/data/winddps目录不存在！"
    fi
}

backup_windcore(){
    if /usr/bin/test -d /home/data/WindCore
    then
        /usr/bin/mkdir -p $ConfigName/WindCore/cfg
        /usr/bin/\cp -a /home/data/WindCore/cfg/*  $ConfigName/WindCore/cfg/
    else
        log_error "/home/data/WindCore目录不存在！"
    fi
}

up_sql(){
    mkdir -p $ConfigName/sql


    # PGPASSWORD=$HGPASSWD pg_dump -U sysdba -d wind -t config.wind_farm > test.sql
    # PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "SELECT * FROM config.wind_farm;" > config_wind_farm
    # PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "SELECT * FROM config.wt_power_curve;" > config_wt_power_curve
    # PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "SELECT * FROM config.wind_turbine;" > config_wind_turbine
    # PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY (SELECT * FROM config.wind_farm) TO '/root/output.csv' WITH csv;" 
    # PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY (SELECT * FROM config.wind_farm) TO ""'" $ConfigName/output.csv"'"" WITH csv;" 
    # PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.wind_farm TO 'root/output.csv WITH csv;" 

    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.wind_farm TO ""'"$PWD/$ConfigName/sql/config_wind_farm.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.wt_power_curve TO ""'"$PWD/$ConfigName/sql/config_wt_power_curve.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.wind_turbine TO ""'"$PWD/$ConfigName/sql/config_wind_turbine.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.data_storage TO ""'"$PWD/$ConfigName/sql/config_data_storage.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.tpl_data_item TO ""'"$PWD/$ConfigName/sql/config_tpl_data_item.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.ems_wf_data_storage TO ""'"$PWD/$ConfigName/sql/config_ems_wf_data_storage.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.ems_wf_data_table TO ""'"$PWD/$ConfigName/sql/config_ems_wf_data_table.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.ems_wt_data_storage TO ""'"$PWD/$ConfigName/sql/config_ems_wt_data_storage.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.tpl_ems_wf_data_item TO ""'"$PWD/$ConfigName/sql/config_tpl_ems_wf_data_item.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY config.tpl_ems_wt_data_item TO ""'"$PWD/$ConfigName/sql/config_tpl_ems_wt_data_item.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY public.sys_admin TO ""'"$PWD/$ConfigName/sql/public_sys_admin.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY public.sys_menu TO ""'"$PWD/$ConfigName/sql/public_sys_menu.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY public.sys_role TO ""'"$PWD/$ConfigName/sql/public_sys_role.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"
    PGPASSWORD=$HGPASSWD /opt/HighGo456-see/bin/psql -U sysdba -d wind -c "COPY public.sys_setting TO ""'"$PWD/$ConfigName/sql/public_sys_setting.csv"'"" WITH delimiter ',' CSV HEADER encoding 'UTF8';"

}

main(){
    /usr/bin/test -d $ConfigName || /usr/bin/mkdir -p $ConfigName
    collect_message
    backup_windbes
    backup_winddp
    backup_winddps
    backup_windcore
    up_sql
    redis-cli -a Sa123456% mget SCADA.A.Ver SCADA.B.Ver SCADA.C.Ver SCADA.E.Ver SCADA.G.Ver > $ConfigName/version.txt
    /usr/bin/zip -v -r  $ConfigName.zip $ConfigName
    echo "*****************************************************************************************************"
    echo "****SCADA系统配置备份完成，请将$ConfigName.zip文件返回给技术人员*****"
    echo "*****************************************************************************************************"
}

main