#/bin/bash

#技术中心@白万进
#20220530

SCADA_Path='/home/data'
Windfarm=`grep WindfarmID $SCADA_Path/WindCore/cfg/Application_HistoryData.csv|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
if [ -z $Windfarm ]
then
    Windfarm=$1
fi
time3=$(date "+%Y%m%d%H%M%S")
gethostname=$(hostname)

BACKUP_NAME="${gethostname}_Windfarm$Windfarm""_${time3}"
current_path=$(cd `dirname $0`; pwd)

create_group(){
	if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
	then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
	fi
}

set_tomcat(){
    if grep -q '/usr/local/tomcat/bin/startup.sh' /etc/profile 
    then
        sed -i '/\/usr\/local\/tomcat\/bin\/startup.sh/  s/^\(.*\)$/#\1/g' /etc/profile 
    fi
    TomcatPID=`ps -ef|grep TomcatPID|grep -v grep|awk 'NR>1 {print $2}'`
	if [[ -n $TomcatPID ]]
    then 
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在多个TomcatPID进程$TomcatPID"
        ps -ef|grep tomcat|grep -v grep|awk 'NR>1 {print $2}'|xargs kill -9
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:杀死多余的TomcatPID进程：$TomcatPID"
	fi
    systemctl status tomcat.service >/dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        return
    fi
    cat > tomcat.service <<-EOF
[Unit]
Description=tomcat
After=network.target

[Service]
Type=oneshot
User=root
Group=windeyapps
ExecStart=/usr/local/tomcat/bin/startup.sh
ExecStop=/usr/local/tomcat/bin/shutdown.sh
ExecReload=/bin/kill -s HUP $MAINPID
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    \cp tomcat.service /usr/lib/systemd/system/
    systemctl daemon-reload && systemctl enable tomcat.service
}

set_WindCore(){
    systemctl status WindCore.service >/dev/null 2>&1
    if [[ $? -eq 0 ]]
    then
        return
    fi
cat > WindCore.service <<-EOF
[Unit]
Description=java project
After=WindCore.service

[Service]
Type=forking 
User=root
Group=windeyapps
ExecStart=/home/data/WindCore/startup.sh
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    \cp WindCore.service /usr/lib/systemd/system/
    systemctl daemon-reload && systemctl enable WindCore.service
}


repair_WindCore(){
#用来修正历史遗留问题开机自启动脚本在/etc/profile中的问题
    #WindCore
    if grep '/home/data/WindCore/startup.sh' /etc/profile >/dev/null 2>&1
    then
	    WindCorePID=`ps -ef|grep WindCore|grep -v grep|awk 'NR>1 {print $2}'`
	    if [[ -n $WindCorePID ]]
        then 
	        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在多个WindCore进程$WindCorePID"
            ps -ef|grep WindCore|grep -v grep|awk 'NR>1 {print $2}'|xargs kill -9
	        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:杀死多余的WindCore进程：$WindCorePID"
	    fi
	    sed -i  '/\/home\/data\/WindCore/ s/^\(.*\)$/#\1/g' /etc/profile
        set_WindCore
    fi
}




main(){
    #create_group
    #repair_WindCore
    #set_tomcat
    count1=$(rpm -qa | grep msodbcsql | wc -l)
    count2=$(rpm -qa | grep mssql-tools | wc -l)
    if [ ${count1} -lt 1 ] || [ ${count2} -lt 1 ];then
       unset count1
       unset count2
       echo "`date +"%Y-%m-%d %H:%M:%S"`  [ERROR]:检测到未安装SQL Server数据库工具，脚本无法运行。请联系技术人员。"
       exit 1
    fi
    cd $current_path
    if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' ~/.bash_profile
    then
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
    fi
    if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' ~/.bashrc
    then
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
    fi
    if [ ! -d "$current_path/$BACKUP_NAME" ];then
        mkdir -m 777 $current_path/$BACKUP_NAME
    else
        chmod 777 $current_path/$BACKUP_NAME
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:程序升级所需的现场数据将导出并打包为$BACKUP_NAME.zip"
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:开始导出数据......"
    if [ -d "$current_path/$BACKUP_NAME/temp" ];then
        rm -rf $current_path/$BACKUP_NAME/temp
    fi
    mkdir -m 777 $current_path/$BACKUP_NAME/temp

    /opt/mssql-tools/bin/bcp "select distinct windturbinetypeid from wind.dbo.windturbine" queryout $current_path/$BACKUP_NAME/temp/typeid.txt -c -S 127.0.0.1 -U sa -P Sa123456% -d wind

    for line in `cat $current_path/$BACKUP_NAME/temp/typeid.txt`
    do
        /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select distinct name from wind.dbo.windturbinetype where windturbinetypeid = $line" 1>>$current_path/$BACKUP_NAME/temp/name.txt
    done

    sed -i '/affected/d' $current_path/$BACKUP_NAME/temp/name.txt
    sed -i '/name/d' $current_path/$BACKUP_NAME/temp/name.txt
    sed -i '/------/d' $current_path/$BACKUP_NAME/temp/name.txt
    sed -i '/^$/d' $current_path/$BACKUP_NAME/temp/name.txt
    sed -i s/[[:space:]]//g $current_path/$BACKUP_NAME/temp/name.txt


    for line in `cat $current_path/$BACKUP_NAME/temp/name.txt`
    do
        /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[wind_powercurve_50_$line] order by windspeedid" -o "$current_path/$BACKUP_NAME/[dbo].[wind_powercurve_50_$line].csv" -W -w 700 -s","
        sed -i '/-----/d' $current_path/$BACKUP_NAME/[dbo].[wind_powercurve_50_$line].csv
        sed -i '/^$/d' $current_path/$BACKUP_NAME/[dbo].[wind_powercurve_50_$line].csv
        sed -i '/affected/d' $current_path/$BACKUP_NAME/[dbo].[wind_powercurve_50_$line].csv
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场风机型号功率曲线数据已导出！"
    done

    rm -rf $current_path/$BACKUP_NAME/temp

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windalarm] order by id" -o "$current_path/$BACKUP_NAME/windalarm.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windalarm.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windalarm.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windalarm.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windalarm.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windalarm数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windturbine] order by windturbineid" -o "$current_path/$BACKUP_NAME/windturbine.csv" -W -w 3200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windturbine.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windturbine.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windturbine.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windturbine.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windturbine数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "if exists (select * from sys.all_objects where object_id = OBJECT_ID(N'[dbo].[windline]') and type IN ('U')) begin select * from [dbo].[windline] order by windlineid end" -o "$current_path/$BACKUP_NAME/windline.csv" -W -w 700 -s","
    if [ -s $current_path/$BACKUP_NAME/windline.csv ]; then
        sed -i '/-----/d' $current_path/$BACKUP_NAME/windline.csv
        sed -i '/^$/d' $current_path/$BACKUP_NAME/windline.csv
        sed -i '/affected/d' $current_path/$BACKUP_NAME/windline.csv
        sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windline.csv
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windline数据库表的数据已导出！"
    else
        rm -f $current_path/$BACKUP_NAME/windline.csv
    fi

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windfarm] order by windfarmid" -o "$current_path/$BACKUP_NAME/windfarm.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windfarm.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windfarm.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windfarm.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windfarm.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windfarm数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windunitstate] order by unitstateid" -o "$current_path/$BACKUP_NAME/windunitstate.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windunitstate.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windunitstate.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windunitstate.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windunitstate.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windunitstate数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windsetup] order by id" -o "$current_path/$BACKUP_NAME/windsetup.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windsetup.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windsetup.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windsetup.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windsetup.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windsetup数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windtagpageview] order by id" -o "$current_path/$BACKUP_NAME/windtagpageview.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windtagpageview.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windtagpageview.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windtagpageview.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windtagpageview.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windtagpageview数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windtag] order by id" -o "$current_path/$BACKUP_NAME/windtag.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windtag.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windtag.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windtag.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windtag.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:windtag数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[security_module] order by id" -o "$current_path/$BACKUP_NAME/security_module.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/security_module.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/security_module.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/security_module.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/security_module.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:security_module数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[security_role] order by id" -o "$current_path/$BACKUP_NAME/security_role.csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/security_role.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/security_role.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/security_role.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/security_role.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:security_role数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[security_role_permission] order by role_id" -o "$current_path/$BACKUP_NAME/security_role_permission.csv" -W -w 700 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/security_role_permission.csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/security_role_permission.csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/security_role_permission.csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/security_role_permission.csv
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:security_role_permission数据库表的数据已导出！"

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[windturbine_day] where date = (select max(date) from dbo.windturbine_day) order by windturbineid" -o "$current_path/$BACKUP_NAME/windturbine_day[end].csv" -W -w 1200 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windturbine_day[end].csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windturbine_day[end].csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windturbine_day[end].csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windturbine_day[end].csv

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select * from [dbo].[winddata_hour] where date = (select max(date) from dbo.winddata_hour) order by windturbineid" -o "$current_path/$BACKUP_NAME/winddata_hour[end].csv" -W -w 1500 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/winddata_hour[end].csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/winddata_hour[end].csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/winddata_hour[end].csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/winddata_hour[end].csv

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "if exists (select * from sys.all_objects where object_id = OBJECT_ID(N'[dbo].[wind_powercurve_day]') and type IN ('U')) begin select * from [dbo].[wind_powercurve_day] where date = (select max(date) from dbo.wind_powercurve_day) order by windturbineid end" -o "$current_path/$BACKUP_NAME/wind_powercurve_day[end].csv" -W -w 3000 -s","
    if [ -s $current_path/$BACKUP_NAME/wind_powercurve_day[end].csv ]; then
        sed -i '/-----/d' $current_path/$BACKUP_NAME/wind_powercurve_day[end].csv
        sed -i '/^$/d' $current_path/$BACKUP_NAME/wind_powercurve_day[end].csv
        sed -i '/affected/d' $current_path/$BACKUP_NAME/wind_powercurve_day[end].csv
        sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/wind_powercurve_day[end].csv
    else 
        rm -f $current_path/$BACKUP_NAME/wind_powercurve_day[end].csv
    fi

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "if exists (select * from sys.all_objects where object_id = OBJECT_ID(N'[dbo].[windturbine_power_loss]') and type IN ('U')) begin select * from [dbo].[windturbine_power_loss] where date = (select max(date) from dbo.windturbine_power_loss) order by windturbineid end" -o "$current_path/$BACKUP_NAME/windturbine_power_loss[wind].csv" -W -w 2000 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windturbine_power_loss[wind].csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windturbine_power_loss[wind].csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windturbine_power_loss[wind].csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windturbine_power_loss[wind].csv

    /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind_sw -U sa -P Sa123456% -Q "if exists (select * from sys.all_objects where object_id = OBJECT_ID(N'[dbo].[windturbine_power_loss]') and type IN ('U')) begin select * from [dbo].[windturbine_power_loss] where date = (select max(date) from dbo.windturbine_power_loss) order by windturbineid end" -o "$current_path/$BACKUP_NAME/windturbine_power_loss[wind_sw].csv" -W -w 2000 -s","
    sed -i '/-----/d' $current_path/$BACKUP_NAME/windturbine_power_loss[wind_sw].csv
    sed -i '/^$/d' $current_path/$BACKUP_NAME/windturbine_power_loss[wind_sw].csv
    sed -i '/affected/d' $current_path/$BACKUP_NAME/windturbine_power_loss[wind_sw].csv
    sed -i s/,NULL/,/g $current_path/$BACKUP_NAME/windturbine_power_loss[wind_sw].csv

    rm -rf $current_path/$BACKUP_NAME/cfg
    cp -a /home/data/WindCore/cfg $current_path/$BACKUP_NAME
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场WindCore配置文件已导出！"

    rm -f $current_path/$BACKUP_NAME/application.properties
    if [ -d "/home/data/windeybs" ];then
        cp -p /home/data/windeybs/WEB-INF/classes/application.properties $current_path/$BACKUP_NAME
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场windeybs配置文件已导出！"
    fi

    if [ -d "/home/data/windeybs/static/Voice" ];then
        cp -a /home/data/windeybs/static/Voice $current_path/$BACKUP_NAME
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场windeybs的Voice文件夹已导出！"
    fi

    if [ -d "/home/data/windeybs/Voice" ];then
        rm -rf $current_path/$BACKUP_NAME/Voice
        cp -a /home/data/windeybs/Voice $current_path/$BACKUP_NAME
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场windeybs的Voice文件夹已导出！"
    fi

    firewalld_status=`systemctl status firewalld.service | grep "active (running)" | wc -l`
    if [ ${firewalld_status} -gt 0 ];then
        firewall-cmd --add-port=8182/tcp --permanent >/dev/null 2>&1
        firewall-cmd --add-port=8182/udp --permanent >/dev/null 2>&1
        firewall-cmd --add-port=8184/tcp --permanent >/dev/null 2>&1
        firewall-cmd --add-port=8184/udp --permanent >/dev/null 2>&1
        firewall-cmd --add-port=8185/tcp --permanent >/dev/null 2>&1
        firewall-cmd --add-port=8185/udp --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        systemctl list-unit-files | grep firewalld.service >$current_path/$BACKUP_NAME/firewall_opend.txt 2>&1
        echo "以下是开放的端口号：" >>$current_path/$BACKUP_NAME/firewall_opend.txt
        firewall-cmd --list-ports >>$current_path/$BACKUP_NAME/firewall_opend.txt 2>&1
    fi
    zip -q -r ./$BACKUP_NAME.zip ./$BACKUP_NAME
    rm -rf $current_path/$BACKUP_NAME
    echo  WindfarmID,Windfarm$Windfarm > WindfarmID
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:程序升级所需的现场数据已全部导出并打包为$BACKUP_NAME.zip"
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:请将名为$BACKUP_NAME.zip的压缩包文件发送给技术人员。"    
}


main