#!/bin/bash
#技术中心
#2022/3/4

###
#检测服务状态
###


SQLSERVERPASSWD='Sa123456%'
RedisPasswd='Sa123456%'
HGPasswd="Sa123456%"
sudo groupadd windeyapps
sudo usermod -G windeyapps sysadm
sudo usermod -G windeyapps root

server_status(){
    for server in $*
    do
        Active=`systemctl status ${server}|grep Active |awk '{print $2}'`
        if [[ ${Active} != "active" ]]
        then
            echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m ${server}服务未正常启动，请确认！\033[0m"
        else
            echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: ${server}服务启动正常"
        fi
    done
}

										
read_Affirm(){
    Affirm=NO
    while [ ${Affirm} != 'yes' ]
    do
        echo $1
        read Affirm
    done
    
}

###
#添加防火墙策略
###
#需要开放的TCP端口
TcpPorts=(21 22 80 501 502 503 504 505 506 507 508 509 510 511 512 513 514 515 516 517 518 519 520 521 522 523 524 525 987 1433 1601 1625 1640 3306 5900 6379 8080 8082 48898 48899 8086 8182 8184 8185 9166 27017 2404 2405 2406 2407 2408 2409 2410 2411 2412 2413 2414 2415 2416 2417 2418 2419 2420 2421 2422 2423 2425 2426 2427 2428 2429 2430 2431 2432 2433 2434 2435 2436 2437 2438 2439 2440 2441 2442 2443 2444 2445 2446 2447 2448 2449 2450 2451 2452 2453 2454 2455 2456 2457 2458 2459 2460 2461 2462 2463 2464 2465 2466 2467 2468 2469 2470 2471 2472 2473 2474 2475 2476 2477 2478 2479 2480 2481 2482 2483 2484 2485
 2486 2487 2488 2489 2490 2491 2492 2493 2494 2495 2496 2497 2498 2499 2500 2501 2502 2503 2504 5901 5902 5903 5904 5866 8086)
#需要开放的UDP端口
UdpPorts=(123 1434 4747 4848 8086 8182 8184 8185 9166 27017)

#添加防火墙策略方法（日志待完善）
add_firewall_rules(){
    sudo systemctl enable firewalld
    sudo systemctl restart firewalld
    for TcpPort in ${TcpPorts[*]}
    do
        port_status=`sudo firewall-cmd --query-port=${TcpPort}/tcp`
	if [ $port_status == 'no' ]
	then
	    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 添加TCP端口:${TcpPort}到防火墙"
        sudo firewall-cmd --add-port=${TcpPort}/tcp --permanent
	fi
    done
    for UdpPort in ${UdpPorts[*]}
    do
	port_status=`sudo firewall-cmd --query-port=${UdpPort}/udp`
	if [ $port_status == 'no' ]
	then
	   echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 添加UDP端口:${UdpPort}到防火墙"
	    sudo firewall-cmd --add-port=${UdpPort}/udp --permanent
        fi
	done
    sudo systemctl restart firewalld
}



install_HGDB(){
    chmod +x installDB_expect.sh
    ./installDB_expect.sh $SCADA_PATH
    sudo firewall-cmd --add-port=5866/tcp --permanent
    sudo firewall-cmd --reload
}


###
#系统相关设置
###

system_setup(){
   #sudo gsettings set org.mate.screensaver idle-activation-enabled false
   #sudo gsettings set org.mate.power-manager sleep-display-ac 0
   #echo "屏幕保护和显示器睡眠已关闭"
   sudo systemctl stop rpcbind.socket && sudo systemctl stop rpcbind
   sudo systemctl disable rpcbind.socket && sudo systemctl disable rpcbind
   echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: rpcbind服务已禁用"
}

###
#安装tomcat
###

#获取tomcat小版本号
TomcatVer=`rpm -qa | grep tomcat-9 | awk '{split($0,a,"[-.]");print a[4]}'`
#查寻当前目录下tomcat的安装包数量
Count=`ls *tomcat-9*.rpm 2> /dev/null | wc -w`

#安装tomcat
install_tomcat(){
    if [ ${Count} -eq 0 ];
    then 
	echo "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未找到tomcat"
	exit

    elif [ ${Count} -gt 1 ];
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 当前目录下存在多个Tomcat9的rpm安装文件，脚本执行中断，请删除当前目录下多余的rpm文件，再运行。\033[0m"
        unset TomcatVer
        unset Count
        exit
    else
        RpmVer=`rpm -qpi *tomcat-9*.rpm | awk 'NR==2' | awk '{split($0,a,".");print a[3]}'`
        if [ ${TomcatVer} -lt ${RpmVer} ];
        then
            sudo systemctl stop tomcat.service && sudo rpm -Uvh *tomcat-9*.rpm && sudo rm -rf /usr/local/apache-tomcat-9.0.${TomcatVer}
            TomcatVer=${RpmVer}
            echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: Tomcat版本已升级到9.0.${TomcatVer}"
        else
            echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 已安装9.0.${TomcatVer}版Tomcat，高于或等于当前目录下rpm安装文件的版本，无需升级！"
        fi
        unset RpmVer
    fi
    unset Count
}

#配置tomcat
init_tomcat(){
    if [ ! -d "/home/data" ];
    then
         sudo mkdir -p /home/data
    fi
	sudo chown sysadm:sysadm /home/data
    sudo chmod 777 /home/data
    sudo systemctl stop tomcat.service
    sudo sed -i "s?juli.AsyncFileHandler.level = FINE?juli.AsyncFileHandler.level = OFF?" /usr/local/apache-tomcat-9.0.$TomcatVer/conf/logging.properties
    sudo sed -i "s?java.util.logging.ConsoleHandler.level = FINE?java.util.logging.ConsoleHandler.level = OFF?" /usr/local/apache-tomcat-9.0.$TomcatVer/conf/logging.properties
    sudo sed -i "s?\[localhost\].level = INFO?\[localhost\].level = OFF?" /usr/local/apache-tomcat-9.0.$TomcatVer/conf/logging.properties
    sudo sed -i "s?\[localhost\].\[/manager\].level = INFO?\[localhost\].\[/manager\].level = OFF?" /usr/local/apache-tomcat-9.0.$TomcatVer/conf/logging.properties
    sudo sed -i "s?\[/host-manager\].level = INFO?\[/host-manager\].level = OFF?" /usr/local/apache-tomcat-9.0.$TomcatVer/conf/logging.properties
    if ! grep -q 'CATALINA_OUT=/dev/null' /usr/local/apache-tomcat-9.0.$TomcatVer/bin/catalina.sh
    then
        sudo sed -i 's?CATALINA_OUT="$CATALINA_BASE"/logs/catalina.out?#CATALINA_OUT="$CATALINA_BASE"/logs/catalina.out?' /usr/local/apache-tomcat-9.0.$TomcatVer/bin/catalina.sh
        sudo sed -i '/#CATALINA_OUT="$CATALINA_BASE"\/logs\/catalina.out/a \  CATALINA_OUT=\/dev\/null' /usr/local/apache-tomcat-9.0.$TomcatVer/bin/catalina.sh
    fi
    if ! grep -q "JAVA_OPTS='-server -Xms4096m -Xmx6144m -XX:MetaspaceSize=1024m -XX:MaxMetaspaceSize=1024m'" /usr/local/apache-tomcat-9.0.$TomcatVer/bin/catalina.sh
    then
        sudo sed -i "/cygwin=false/i JAVA_OPTS='-server -Xms4096m -Xmx6144m -XX:MetaspaceSize=1024m -XX:MaxMetaspaceSize=1024m'" /usr/local/apache-tomcat-9.0.$TomcatVer/bin/catalina.sh
    fi
    sudo sed -i 's?<Connector port="8080" protocol="HTTP/1.1"?<Connector port="9166" protocol="HTTP/1.1"?' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    if ! grep -q '<!-- <Valve className="org.apache.catalina.valves.AccessLogValve"' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    then
        sudo sed -i 's?<Valve className="org.apache.catalina.valves.AccessLogValve"?<!-- <Valve className="org.apache.catalina.valves.AccessLogValve"?' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    fi
    if ! grep -q 'pattern="%h %l %u %t &quot;%r&quot; %s %b" /> -->' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    then
        sudo sed -i 's?pattern="%h %l %u %t \&quot;%r\&quot; %s %b" />?pattern="%h %l %u %t \&quot;%r\&quot; %s %b" /> -->?' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    fi
    if ! grep -q '<Context path =""  docBase="/home/data/windeybs" debug="0" reloadable="true"/>' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    then
        sudo sed -i '/<\/Host>/i \<Context path =""  docBase="/home/data/windeybs" debug="0" reloadable="true"/>' /usr/local/apache-tomcat-9.0.$TomcatVer/conf/server.xml
    fi
    sleep 2
    sudo chown sysadm:sysadm /usr/local/apache-tomcat-9.0.$TomcatVer/ -R
    sudo mv /usr/lib/systemd/system/tomcat.service /usr/lib/systemd/system/tomcat.service.bak
    mkdir -p SystemServers
    cat > tomcat.service <<-EOF
[Unit]
Description=tomcat
[Service]
User=sysadm
Group=windeyapps
Type=oneshot
ExecStart=/usr/local/apache-tomcat-9.0.$TomcatVer/bin/startup.sh
ExecStop=/usr/local/apache-tomcat-9.0.$TomcatVer/bin/shutdown.sh
ExecReload=/bin/kill -s HUP $MAINPID
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target	
EOF
    sudo cp tomcat.service /usr/lib/systemd/system/tomcat.service
    unset TomcatVer
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: Tomcat9相关配置完成！"
}


###
#stopmongod
###


stop_mongod(){
    mongodCheck=`rpm -qa | grep mongodb | wc -l`
    if [ ${mongodCheck} -gt 0 ];then
        sudo systemctl stop mongod && sudo systemctl disable mongod
    fi
}


###
#配置WindViewer
##

init_WindViewer(){
    influxdbCheck=`rpm -qa | grep influxdb | wc -l`
    if [ ${influxdbCheck} -gt 0 ];then
        sudo systemctl stop influxd && sudo systemctl disable influxd
	    sudo systemctl stop influxdb && sudo systemctl disable influxdb
    fi
    unset influxdbCheck
    if ! grep -q "Exec=/usr/bin/chromium-browser %U --no-sandbox" /usr/share/applications/chromium-browser.desktop
    then
        sudo sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U --no-sandbox?" /usr/share/applications/chromium-browser.desktop
    fi
    \cp -f -p /usr/share/applications/chromium-browser.desktop /sysadm/WindViewer.desktop
    sudo sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U 127.0.0.1:9166?" /sysadm/WindViewer.desktop
    sudo sed -i "s?Name=Chromium Web Browser?Name=WindViewer?" /sysadm/WindViewer.desktop
    sudo sed -i "s?Name\[zh_CN\]=Chromium 网页浏览器?Name\[zh_CN\]=WindViewer?" /sysadm/WindViewer.desktop
    if [ -d "/sysadm/桌面" ];then
        \cp -f -p /sysadm/WindViewer.desktop /sysadm/桌面
        chmod +x /sysadm/桌面/WindViewer.desktop
    fi
    if [ -d "/sysadm/Desktop" ];then
        \cp -f -p /sysadm/WindViewer.desktop /sysadm/Desktop
        sudo chmod +x /sysadm/Desktop/WindViewer.desktop
    fi
    sudo rm -f /sysadm/WindViewer.desktop
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 谷歌浏览器配置完成！"
}

###
#配置redis
###

init_redis(){
    sudo mkdir -p /home/data/redis
    sudo cp dump.rdb /home/data/redis
    sudo chown redis:redis /home/data/redis -R
    sudo sed -i "s?logfile /var/log/redis/redis.log?logfile /home/data/redis/redis.log?" /etc/redis.conf
    sudo sed -i "s?dir /var/lib/redis?dir /home/data/redis?" /etc/redis.conf
    sudo sed -i "s?bind 127.0.0.1?bind 0.0.0.0?" /etc/redis.conf
    sudo sed -i "s?daemonize no?daemonize yes?" /etc/redis.conf
    if ! sudo grep -q '#save 900 1' /etc/redis.conf
    then
        sudo sed -i "s?save 900 1?#save 900 1?" /etc/redis.conf
    fi

    if ! sudo grep -q '#save 300 10' /etc/redis.conf
    then
        sudo sed -i "s?save 300 10?#save 300 10?" /etc/redis.conf
    fi

    if ! sudo grep -q '#save 60 10000' /etc/redis.conf
    then
        sudo sed -i "s?save 60 10000?#save 60 10000?" /etc/redis.conf
    fi

    if ! sudo grep -q "requirepass ${RedisPasswd}" /etc/redis.conf
    then
        sudo sed -i "s?# requirepass foobared?requirepass ${RedisPasswd}?" /etc/redis.conf
    fi
	sudo systemctl daemon-reload
	mongodCheck=`rpm -qa | grep mongodb | wc -l`
    if [ ${mongodCheck} -gt 0 ];then
	sudo systemctl restart mongod && sudo systemctl enable mongod
    fi
    sudo systemctl restart influxdb && sudo systemctl enable influxdb
    sudo systemctl restart redis && sudo systemctl enable redis
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: Redis配置完成！"
}


###
#安装SQLserver
###

read_sqlpasswd(){
    Result=NO
    while [ ${Result} != 'yes' ]
    do
        echo "Enter the sqlserver database password:"                         
        read SqlserverPwsswd
        echo "Please confirm the password you entered: ${SqlserverPwsswd}"
	echo "[yes|no]"
	read result
	Result=${result}
        SQLSERVERPASSWD=${SqlserverPwsswd}
    done
}



###
#导入SQL
###

init_Sql(){

    turbine_num=$(sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P ${SQLSERVERPASSWD} -Q "select count(*) from wind.dbo.windturbine" | awk 'NR==3' | sed s/[[:space:]]//g)

    job4="Wind2.0_job4_4.sql"
    if [ ${turbine_num} -gt 0 ] && [ ${turbine_num} -le 33 ];then
       job4="Wind2.0_job4_1.sql"
    elif [ ${turbine_num} -gt 33 ] && [ ${turbine_num} -le 66 ];then
       job4="Wind2.0_job4_2.sql"
    elif [ ${turbine_num} -gt 66 ] && [ ${turbine_num} -le 99 ];then
       job4="Wind2.0_job4_3.sql"
    elif [ ${turbine_num} -gt 99 ] && [ ${turbine_num} -le 132 ];then
       job4="Wind2.0_job4_4.sql"
    else
       job4="Wind2.0_job4_4.sql"
    fi
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/Wind2.0_job1.sql &>$PWD/output.txt
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/Wind2.0_job2.sql &>>$PWD/output.txt
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/Wind2.0_job3.sql &>>$PWD/output.txt
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/$job4 &>>$PWD/output.txt
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/Wind2.0_job5.sql &>>$PWD/output.txt
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/Wind2.0_job6.sql &>>$PWD/output.txt
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/Wind2.0_job7.sql &>>$PWD/output.txt

    if [ -f "$PWD/job2.0/job_calculate_powercurve_scada.sql" ] && [ -f "$PWD/job2.0/job_calculate_windturbine_power_loss.sql" ]; then
       sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/job_calculate_powercurve_scada.sql &>>$PWD/output.txt
       sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -b -i $PWD/job2.0/job_calculate_windturbine_power_loss.sql &>>$PWD/output.txt
    fi
    sudo sed -i '/^$/d' $PWD/output.txt
    sudo sed -i '/Changed database context to/d' $PWD/output.txt
    sudo sed -i '/rows affected)/d' $PWD/output.txt
    if [ -s $PWD/output.txt ]; then
        unset turbine_num
        unset job4
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 数据库job导入时出错，请查看job2.0文件夹下的output.txt文件！\033[0m"
        exit 1
    else
        sudo rm -f $PWD/output.txt
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 数据库job导入完毕！"
    fi

    unset turbine_num
    unset job4
}

install_SQLserver(){
    IsInstalled1=`rpm -qa | grep "mssql-server" | wc -l`
    IsInstalled2=`rpm -qa | grep "mssql-tools" | wc -l`
    if [ ${IsInstalled1} -gt 0 ]&&[ ${IsInstalled2} -gt 0 ];then
        unset IsInstalled1
        unset IsInstalled2
    	if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' /sysadm/.bash_profile
        then
            echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /sysadm/.bash_profile
        fi
    	if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' /sysadm/.bashrc
        then
            echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /sysadm/.bashrc
        fi
       echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 已安装MS SQL Server数据库和数据库命令行工具，无需再次安装！"
        
    fi
    unset IsInstalled1
    unset IsInstalled2
    
    if [ ! -d "$PWD/mssqlrpm" ];then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]:\033[31m 未在当前目录下找到存放数据库安装文件的mssqlrpm文件夹，脚本执行中断！\033[0m"
        exit
    fi
    
    Count=`ls $PWD/mssqlrpm/*.rpm 2> /dev/null | wc -w`
    if [ ${Count} -lt 4 ] || [ ! -d "$PWD/mssqlrpm/tools" ] ;then
        unset Count
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m mssqlrpm文件夹内的rpm安装文件文件不符合要求，脚本运行中断，MS SQL Server数据库安装未完成！\033[0m"
        exit
    fi
    unset Count
    if ! rpm -qa | grep "mssql-server-14"
    then
	    sudo rpm -ivh $PWD/mssqlrpm/gdb-7*.rpm
        sudo rpm -ivh $PWD/mssqlrpm/cyrus-sasl-2*.rpm
        sudo rpm -ivh $PWD/mssqlrpm/cyrus-sasl-gssapi-2*.rpm
        sudo rpm -ivh $PWD/mssqlrpm/mssql-server-14.0.3*.rpm   
    fi
   
  
    sudo systemctl stop mssql-server
    sudo /opt/mssql/bin/mssql-conf setup
    
    mssqlCheck=`systemctl status mssql-server | grep "active (running)" | wc -l`
    if [ $mssqlCheck -lt 1 ]
    then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m mssql-server状态异常,请勿继续操作,联系技术人员！\033[0m"
	    exit
    fi
    if ! rpm -qa | grep "msodbcsql17"
    then
        sudo rpm -ivh $PWD/mssqlrpm/tools/unixODBC-2.3*.rpm
        sudo rpm -ivh $PWD/mssqlrpm/tools/unixODBC-devel-2.3*.rpm
        sudo rpm -ivh $PWD/mssqlrpm/tools/msodbcsql17*.rpm
    fi
    AcceptCheck1=`rpm -qa | grep "msodbcsql17" | wc -l`
    if [ $AcceptCheck1 -lt 1 ]
    then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 数据库工具msodbcsql组件安装失败,请勿继续操作,联系技术人员！ \033[0m"
	    exit
    fi
    if ! rpm -qa | grep "mssql-tools-17"
    then
	sudo rpm -ivh $PWD/mssqlrpm/tools/mssql-tools-17*.rpm
    fi
    AcceptCheck2=`rpm -qa | grep "mssql-tools-17" | wc -l`
    if [ $AcceptCheck2 -lt 1 ]
    then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 数据库工具mssql-tools组件安装失败,请勿继续操作,联系技术人员！\033[0m"
	    exit
    fi
    if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' /sysadm/.bash_profile
    then
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /sysadm/.bash_profile
    fi
    
    if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' /sysadm/.bashrc
    then
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> /sysadm/.bashrc
    fi

    sudo /opt/mssql/bin/mssql-conf set sqlagent.enabled true 1>/dev/null
    mem=`cat /proc/meminfo | grep MemTotal | grep -o '[0-9]\{1,\}'`
    cat /proc/meminfo | grep MemTotal
    if [ ${mem} -le 20000000 ]
    then
        sudo /opt/mssql/bin/mssql-conf set memory.memorylimitmb 2048 1>/dev/null
    elif [ ${mem} -le 40000000 ]
    then
        sudo /opt/mssql/bin/mssql-conf set memory.memorylimitmb 12288 1>/dev/null
    else
        sudo /opt/mssql/bin/mssql-conf set memory.memorylimitmb 16384 1>/dev/null
    fi
    unset mem
    sudo systemctl restart mssql-server 
    sleep 10
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d msdb -U sa -P ${SQLSERVERPASSWD} -Q "IF EXISTS (SELECT * FROM [dbo].[sysjobs] WHERE name=N'syspolicy_purge_history') EXEC [dbo].[sp_update_job] @job_name = 'syspolicy_purge_history', @enabled =0" 1>/dev/null
    if [ $? -ne 0 ]; then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m MS SQL Server数据库和数据库命令行工具安装配置出现问题，脚本执行中断！请勿继续操作，并联系技术人员！\033[0m"
        exit
    fi
	
    Countbak=`ls /home/data/wind_*.bak 2> /dev/null | wc -w`
    Countmdf=`ls /home/data/wind*.mdf 2> /dev/null | wc -w`
    if [ -d "/home/data/WindCore" ] || [ -d "/home/data/windeybs" ] || [ ${Countbak} -gt 0 ] || [ ${Countmdf} -gt 0 ];then
        unset Countbak
        unset Countmdf
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]:\033[31m 检测到/home/data下已存在SCADA应用程序或数据库，脚本运行中断！\033[0m"
        exit
    fi
    unset Countbak
    unset Countmdf

    if [ ! -d "$PWD/bak" ];then
        mkdir -p $PWD/bak
    fi
    Countw=`ls $PWD/bak/wind_2*.bak 2> /dev/null | wc -w`
    Countd=`ls $PWD/bak/wind_data_2*.bak 2> /dev/null | wc -w`
    Counts=`ls $PWD/bak/wind_sw_2*.bak 2> /dev/null | wc -w`
    if [ ${Countw} -ne 1 ] || [ ${Countd} -ne 1 ] || [ ${Counts} -ne 1 ];then
        unset Countw
        unset Countd
        unset Counts
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m bak文件夹的数据库备份文件数量不符合要求，脚本运行中断！\033[0m"
        exit
    fi
    unset Countw
    unset Countd
    unset Counts
    
	    
    if [ ! -d "$PWD/job2.0" ];then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 未在当前目录下找到数据库job2.0文件夹，脚本运行中断！\033[0m"
        exit
    fi
    
    if [ ! -f "$PWD/job2.0/Wind2.0_job1.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job2.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job3.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job5.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job6.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job7.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job4_1.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job4_2.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job4_3.sql" ] || [ ! -f "$PWD/job2.0/Wind2.0_job4_4.sql" ];then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m job2.0文件夹内的文件不符合要求，脚本运行中断！\033[0m"
        exit
    fi
	
    IsInstalled1=`rpm -qa | grep "mssql-server" | wc -l`
    IsInstalled2=`rpm -qa | grep "mssql-tools" | wc -l`
    if [ ${IsInstalled1} -eq 0 ] || [ ${IsInstalled2} -eq 0 ];then
        unset IsInstalled1
        unset IsInstalled2
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m MS SQL Server数据库相关程序未安装！\033[0m"
        exit
    fi
    unset IsInstalled1
    unset IsInstalled2
    #read_sqlpasswd
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -Q "SELECT @@VERSION" 1>/dev/null
    if [ $? -ne 0 ]; then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m MS SQL Server数据库和数据库命令行工具安装配置出现问题，脚本执行中断，请联系技术人员！\033[0m"
        exit
    fi
    
    if [ ! -d "/home/data/SCADA_APP_Backup" ];then
        mkdir -p /home/data/SCADA_APP_Backup
        mkdir -p /home/data/SCADA_APP_Backup/WindCore_Backup
        mkdir -p /home/data/SCADA_APP_Backup/windeybs_Backup
    fi
    sudo chmod 750 /home/data/SCADA_APP_Backup
    \cp -p $PWD/bak/wind_*.bak /home/data
    sudo chmod 777 /home/data/wind_*.bak
	mkdir -p  /home/data/mssql
    sudo chown mssql /home/data/mssql
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 开始从bak备份文件还原wind、wind_data、wind_sw数据库......"
    wind_name=$(ls /home/data/wind_2*.bak 2> /dev/null)
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -Q "RESTORE DATABASE wind FROM DISK='$wind_name' WITH MOVE 'wind' TO '/home/data/mssql/wind.mdf', Move 'wind_log' TO '/home/data/mssql/wind_1.ldf'" >/dev/null
    data_name=$(ls /home/data/wind_data_2*.bak 2> /dev/null)
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -Q "RESTORE DATABASE wind_data FROM DISK='$data_name' WITH MOVE 'wind_sw' TO '/home/data/mssql/wind_sw.mdf', Move 'wind_sw_log' TO '/home/data/mssql/wind_sw_log.ldf'" >/dev/null
    sw_name=$(ls /home/data/wind_sw_2*.bak 2> /dev/null)
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P ${SQLSERVERPASSWD} -Q "RESTORE DATABASE wind_sw FROM DISK='$sw_name' WITH MOVE 'wind_data' TO '/home/data/mssql/wind_data.mdf', Move 'wind_data_log' TO '/home/data/mssql/wind_data_log.ldf'" >/dev/null
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: wind、wind_data、wind_sw数据库bak备份文件还原完成！"
    
    if ! crontab -l >/dev/null 2>&1|grep "wind_2*.bak" >/dev/null 2>&1
    then
        echo "20 2 * * * sysadm find /home/data/mssql/ -maxdepth 1 -name \"wind_2*.bak\" -mtime +90 -exec rm -f {} \;" >> crontabfile
        crontab crontabfile && rm -f crontabfile
    fi
	
	
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 开始导入数据库job......"
    init_Sql
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: MS SQL Server数据库和数据库命令行工具安装配置完成！"
    
}



###
#安装配置Wincore、windeyappsbs
###

install_winCoreorwindeyappsbs(){
    
    if [ ! -d "/home/data" ];then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m /home/data目录不存在，请确认！\033[0m"
        exit
    fi
    
    if [ ! -f "$PWD/WindCore.zip" ]&&[ ! -d "$PWD/WindCore" ];then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 未在当前目录下找到WindCore程序文件，脚本运行中断！\033[0m" 
        exit
    fi

    if [ ! -f "$PWD/windeybs.zip" ]&&[ ! -d "$PWD/windeybs" ];then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 未在当前目录下找到windeybs程序文件，脚本运行中断！\033[0m"
        exit
    fi

    RedisCheck=`systemctl status redis | grep "0.0.0.0:6379" | wc -l`
    if [ ${RedisCheck} -lt 1 ];then
        unset RedisCheck
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m redis状态异常！\033[0m"
        exit
    fi
    unset RedisCheck

    if [ -f "$PWD/WindCore.zip" ]&&[ ! -d "$PWD/WindCore" ];then
        \cp -p $PWD/WindCore.zip /home/data
        unzip -q ./WindCore.zip
        rm -f /home/data/WindCore.zip
    fi
    if [ -d "$PWD/WindCore" ];then
        \cp -a $PWD/WindCore /home/data
    fi
    sudo chmod +x /home/data/WindCore/startup.sh
    sudo chmod +x /home/data/WindCore/WindCore.jar
    if ! grep -q "RedisPassword,${RedisPasswd}" /home/data/WindCore/cfg/ConnectValue.csv
    then
        sudo sed -i "/RedisPort,6379/a RedisPassword,${RedisPasswd}" /home/data/WindCore/cfg/ConnectValue.csv
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: WindCore程序部署完成！"
    if [ -f "$PWD/windeybs.zip" ]&&[ ! -d "$PWD/windeybs" ];then
        \cp -p $PWD/windeybs.zip /home/data
        unzip -q ./windeybs.zip
        rm -f /home/data/windeybs.zip
    fi
    if [ -d "$PWD/windeybs" ];then
        \cp -a $PWD/windeybs /home/data
    fi
	 
    sudo chmod +x /home/data/windeybs/restart-tomcat.sh
    sudo chmod +x /home/data/windeybs/windeyapp/farmmonitoring.sh
    redispasswd=`grep "^redis.pass" /home/data/windeybs/WEB-INF/classes/application.properties`
    if [ -z $redispasswd ]
    then
        sudo sed -i "/^redis.host/a\^redis.pass=${RedisPasswd}" /home/data/windeybs/WEB-INF/classes/application.properties
    else
        sudo sed -i "s#${redispasswd}#redis.pass=${RedisPasswd}#g" /home/data/windeybs/WEB-INF/classes/application.properties
    fi
    mkdir -p SystemServers
    cat > SystemServers/windcore.service <<-EOF
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
    sudo \cp SystemServers/* /usr/lib/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl start windcore.service && server_status windcore.service && sudo systemctl enable windcore.service
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: windeybs程序部署完成！"
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: WindCore开机自启设置完成！"
    sudo systemctl restart tomcat.service && sudo systemctl enable tomcat.service
    sh /home/data/windeybs/restart-tomcat.sh &>/dev/null
    
    if [ $? -ne 0 ]; then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 脚本执行中断，请联系技术人员！\033[0m"
        exit
    fi
   
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 已选择自动启动SCADA程序。"
    sudo chromium-browser %U 127.0.0.1:9166 --no-sandbox &>/dev/null &
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: SCADA应用程序和数据库已部署完成！请检查WindCore和Windviewer是否运行正常。"
    
}



###
#安装PostgreSql
###

install_PostgreSql(){
    #sudo rpm -ivh postgresql/*.rpm
    if ! rpm -qa|grep libpq-12*
    then
	sudo rpm -ivh postgresql/libpq-12*.rpm
    fi
    if ! rpm -qa|grep postgresql-12*
    then
	sudo rpm -ivh postgresql/postgresql-12*.rpm
    fi
    if ! rpm -qa|grep postgresql-server-12*
    then
	sudo rpm -ivh postgresql/postgresql-server-12*.rpm
    fi
    sudo \cp /usr/lib/systemd/system/postgresql.service /usr/lib/systemd/system/postgresql.service.bak
    sudo sed -i 's#Environment=PGDATA=/var/lib/pgsql/data#Environment=PGDATA=/home/data/pgsql#g' /usr/lib/systemd/system/postgresql.service
    sudo /usr/bin/postgresql-setup --initdb
    sudo -u sysadm sshpass -p "$SecadmPasswd" ssh secadm@$IP sudo chcon -u unconfined_u /home/data && sudo chcon -t home_root_t /home/data
    sudo systemctl restart postgresql
    sudo systemctl enable postgresql
	
}


###
#安装自动交互工具
###ro
install_automation(){
    if ls $PWD/automation/*.rpm >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 正在安装自动化交互工具"
        if ! rpm -qa|grep expect 1>/dev/null
        then
	    sudo rpm -ivh $PWD/automation/tcl*.rpm
            sudo rpm -ivh $PWD/automation/expect*.rpm
	fi
        if ! rpm -qa|grep sshpass 1>/dev/null
	then
	    sudo rpm -ivh $PWD/automation/sshpass*.rpm
	fi
        
    else
	echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 未找到任何安装包，请确认！ \033[0m"
	exit
    fi
}

IP=127.0.0.1
expect_ssh(){
    cat > expect_ssh.sh <<-EOF
#!/usr/bin/expect -f	
spawn sudo -u sysadm ssh $1@$IP
expect {
"yes/no" { send "yes\r"; exp_continue}
"password:" { send "$2\r" }
}
EOF
    chmod +x expect_ssh.sh && ./expect_ssh.sh && rm -f expect_ssh.sh 
}

###
#获取secadm用户密码
###
#IP=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
read_user_passwd(){
    Result=NO
    while [ ${Result} != 'yes' ]
    do
        echo "请您输入$1用户的password: "
        read -s Passwd
	expect_ssh $1 $Passwd 1>/dev/null
        sudo -u sysadm sshpass -p $Passwd ssh $1@$IP ls 1>/dev/null
        if [ $? -ne 0 ]
        then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1用户密码错误，请确认！ \033[0m"
            exit
        fi
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1用户密码验证通过" 	
        Result="yes"
    done
    unset Result
}


###
#验证secadm用户密码
###

check_SecadmPasswd(){
    echo $SecadmPasswd
    #获取本机IP
    sudo -u sysadm sshpass -p "$SecadmPasswd" ssh secadm@$IP sudo getenforce 1>/dev/null
    if [ $? -ne 0 ]
    then
	    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m secadm用户密码错误，请确认！ \033[0m"
	    exit
    fi 

}


###
#安装Syncovery
###
install_Syncovery(){
    if ! rpm -qa|grep Syncovery >/dev/null 2>&1
    then
	    if ls $PWD/automation/Syncovery* >/dev/null 2>&1
	    then
	        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 正在安装Syncovery"
	        sudo rpm -ivh $PWD/automation/Syncovery*.rpm
	    else
	        echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 未找到Syncovery安装包！ \033[0m"
	    fi
    fi
}

init_VNC(){
    echo "Windey@2022" | vncpasswd -service 1>/dev/null
    /usr/bin/vnclicense -add VKUPN-MTHHC-UDHGS-UWD76-6N36A 1>/dev/null
    systemctl enable vncserver-x11-serviced.service
    systemctl restart vncserver-x11-serviced.service
    sudo firewall-cmd --add-port=5900/tcp --permanent
    sudo firewall-cmd --reload
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:已完成VNC的激活"
}

main(){
    
    #安装自动交互工具
    if [ $? -eq 0 ]
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 添加防火墙策略"
        add_firewall_rules
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 系统相关设置"
        system_setupmain
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 安装tomcat"
        install_tomcat
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 配置tomcat"
        init_tomcat
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 配置VNC"
        init_VNC
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 关闭mongod服务"
        stop_mongod
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 配置WindViewer"
        init_WindViewer
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 配置redis"
        init_redis
	    sudo usermod -G windeyapps redis
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 服务状态检测"
        server_status redis influxdb 
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 安装瀚高数据库"
        install_HGDB
        echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 安装配置Windcore、windeybs"
        install_winCoreorwindeyappsbs
	    install_Syncovery
	    sudo chown :windeyapps -R /home/data/
	    sudo chmod 750 /home/data/
	    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 安装完成请重启主机"
    fi
	
}
main

