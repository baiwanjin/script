#!/bin/bash
#技术中心
#2022/05/17
#标准化能管安装脚本


#安装路径
ServerPath='/home/data'
#数据文件路径
DataPath='/home/data'
#当前路径
CurrentPath=$PWD
#需要开放的TCP端口
TcpPorts=(21 22 80 501 502 503 504 505 506 507 508 509 510 511 512 513 514 515 516 517 518 519 520 521 522 523 524 525 987 1433 1601 1625 1640 3306 6379 8080 8082 48898 48899 8086 8182 8184 8185 9166 27017 2404 2405 2406 2407 2408 2409 2410 2411 2412 2413 2414 2415 2416 2417 2418 2419 2420 2421 2422 2423 2425 2426 2427 2428 2429 2430 2431 2432 2433 2434 2435 2436 2437 2438 2439 2440 2441 2442 2443 2444 2445 2446 2447 2448 2449 2450 2451 2452 2453 2454 2455 2456 2457 2458 2459 2460 2461 2462 2463 2464 2465 2466 2467 2468 2469 2470 2471 2472 2473 2474 2475 2476 2477 2478 2479 2480 2481 2482 2483 2484 2485
 2486 2487 2488 2489 2490 2491 2492 2493 2494 2495 2496 2497 2498 2499 2500 2501 2502 2503 2504 5900 5901 5902 5903 5904)
#需要开放的UDP端口
UdpPorts=(123 1434 4747 4848 8086 8182 8184 8185 9166 27017)

##########################################method#######################################

###
#文件目录检测
###
check_files(){
    if [ ! -d "$CurrentPath/WindCore" ] || [ ! -d "$CurrentPath/WindManagerBS" ] || [ ! -d "$CurrentPath/WindSeer" ] || [ ! -d "$CurrentPath/WindSine" ];then
    echo "当前目录下的能管服务器部署文件不符合要求，脚本运行中断！"
    exit
    fi
}

###
#工作目录初始化,(待定)
###

init_workspace(){
    if [ -d $DataPath ];then
	    sudo mv $DataPath $DataPath_`date +"%Y%m%d%H%M%S"`.bak
    fi
	
	if [ -d $ServerPath ];then
	    sudo mv $ServerPath $ServerPath_`date +"%Y%m%d%H%M%S"`.bak
    fi
	#创建数据目录
	sudo mkdir -p $DataPath
    #创建安装目录
    sudo mkdir -p $ServerPath
	#数据目录
    sudo mkdir -p $DataPath/.windmanager/mongodb
	sudo mkdir -p $DataPath/.windmanager/mongodata
	sudo mkdir -p $DataPath/.windmanager/mongolog
	#sudo mkdir -p $DataPath/.windmanager/influxdata
	#sudo mkdir -p $DataPath/.windmanager/influxmeta
	#sudo mkdir -p $DataPath/.windmanager/influxwal
	sudo mkdir -p $DataPath/redis
	#添加windeyapps用户
	sudo groupadd windeyapps 
	sudo usermod -G windeyapps influxdb
	sudo usermod -G windeyapps mongod
	sudo usermod -G windeyapps root
	sudo usermod -G windeyapps sysadm
	sudo usermod -G windeyapps redis
	#确定组文件夹
	sudo chown mongod $DataPath/.windmanager/mongodb
    sudo chown mongod $DataPath/.windmanager/mongodata
	sudo chown mongod $DataPath/.windmanager/mongolog
	#sudo chown influxdb $DataPath/.windmanager/influxdata
	#sudo chown influxdb $DataPath/.windmanager/influxmeta
	#sudo chown influxdb $DataPath/.windmanager/influxwal
	sudo chown redis $DataPath/redis
	sudo chown :windeyapps $DataPath -R
	sudo chown :windeyapps $ServerPath -R
	sudo chmod 750  $DataPath -R
	sudo chmod 750  $ServerPath -R
}


###
#添加防火墙策略
###

add_firewall_rules(){
    sudo systemctl enable firewalld
    sudo systemctl restart firewalld
    for TcpPort in ${TcpPorts[*]}
    do
	    port_status=`sudo firewall-cmd --query-port=${TcpPort}/tcp`
		if [ $port_status == 'no' ]
		then
	        echo "添加TCP端口:${TcpPort}到防火墙"
            sudo firewall-cmd --add-port=${TcpPort}/tcp --permanent
		fi
    done
    for UdpPort in ${UdpPorts[*]}
    do
	    port_status=`sudo firewall-cmd --query-port=${UdpPort}/udp`
	    if [ $port_status == 'no' ]
	    then
	        echo "添加UDP端口:${UdpPort}到防火墙"
	        sudo firewall-cmd --add-port=${UdpPort}/udp --permanent
        fi
	done
    sudo systemctl restart firewalld
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
   echo "rpcbind服务已禁用"
   #设置root用户自动登录
   sudo sed -i '/autologin-user=root/d' /etc/lightdm/lightdm.conf
   sudo sed -i "/greeter-hide-users=true/a autologin-user=root" /etc/lightdm/lightdm.conf
   echo "已设置root用户自动登录"
}

###
#安装自动交互工具
###

install_automation(){
    if ls $CurrentPath/automation/*.rpm >/dev/null 2>&1
    then
        echo "正在安装自动化交互工具"
        if ! rpm -qa|grep expect 1>/dev/null
        then
	        sudo rpm -ivh $CurrentPath/automation/tcl*.rpm
            sudo rpm -ivh $CurrentPath/automation/expect*.rpm
	    fi
        if ! rpm -qa|grep sshpass 1>/dev/null
	    then
	        sudo rpm -ivh $CurrentPath/automation/sshpass*.rpm
	    fi
        
    else
	    echo "未找到任何安装包，请确认"
	    exit
    fi
}

###
#VNC的配置
###

init_tigervncVNC(){
    tar -xzvf tigervnc.tar.gz 1>/dev/null
	echo "正在卸载realvnc"
	rpm -qa|grep realvnc|xargs sudo rpm -e
	rpm -qa|grep tigervnc|xargs sudo rpm -e --nodeps
    sudo rpm -ivh tigervnc/tigervnc-icons-1.8.0-13.ky3.kb3.noarch.rpm
    sudo rpm -ivh tigervnc/tigervnc-license-1.8.0-13.ky3.kb3.noarch.rpm
    sudo rpm -ivh tigervnc/tigervnc-server-minimal-1.8.0-13.ky3.kb3.x86_64.rpm
    sudo rpm -ivh tigervnc/tigervnc-server-1.8.0-13.ky3.kb3.x86_64.rpm
    sudo rpm -ivh tigervnc/mesa-libGLU-9.0.0-4.ky3.kb5.x86_64.rpm
    sudo rpm -ivh tigervnc/fltk-1.3.4-1.ky3.kb5.x86_64.rpm
    sudo rpm -ivh tigervnc/tigervnc-1.8.0-13.ky3.kb3.x86_64.rpm
	cat >vncserver-sysadm@.service<<EOF
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking

# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStart=/usr/sbin/runuser -l sysadm -c "/usr/bin/vncserver %i"
PIDFile=/sysadm/.vnc/%H%i.pid
ExecStop=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'

[Install]
WantedBy=multi-user.target
EOF
    sudo cp vncserver-sysadm@.service  /etc/systemd/system/vncserver-sysadm@.service

	cat >vncpasswd.sh<<EOF
#!/usr/bin/expect -f
set timeout 10
spawn vncpasswd
expect "Password"
send "Windey@2022\r"
expect "Verify"
send "Windey@2022\r"
expect "*password"
send "n\r"
interact
EOF
    chmod +x vncpasswd.sh && ./vncpasswd.sh && rm -f vncpasswd.sh
	sudo systemctl daemon-reload && sudo systemctl start vncserver-sysadm@\:2.service > /dev/null 2>&1 && sudo systemctl enable vncserver-sysadm@\:2.service
    echo "VNC配置完成！"
}

init_VNC(){

    echo "Windey@2022" | vncpasswd -service 1>/dev/null
    /usr/bin/vnclicense -add VKUPN-MTHHC-UDHGS-UWD76-6N36A 1>/dev/null
    systemctl enable vncserver-x11-serviced.service
    systemctl restart vncserver-x11-serviced.service
    echo "VNC配置完成！"
 
}

###
#谷歌浏览器配置
###
init_Chrome(){
    influxdbCheck=`rpm -qa | grep influxdb | wc -l`
    if [ ${influxdbCheck} -gt 0 ];then
        sudo systemctl stop influxd && sudo systemctl disable influxd
	    sudo systemctl stop influxdb && sudo systemctl disable influxdb
    fi
    unset influxdbCheck
    if ! sudo grep -q "Exec=/usr/bin/chromium-browser %U --no-sandbox" /usr/share/applications/chromium-browser.desktop
    then
        sudo sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U --no-sandbox?" /usr/share/applications/chromium-browser.desktop
    fi
        sudo \cp -f -p /usr/share/applications/chromium-browser.desktop /root/WindViewer.desktop
        sudo sed -i "s?Exec=/usr/bin/chromium-browser %U?Exec=/usr/bin/chromium-browser %U 127.0.0.1:9166?" /root/WindViewer.desktop
        sudo sed -i "s?Name=Chromium Web Browser?Name=WindViewer?" /root/WindViewer.desktop
        sudo sed -i "s?Name\[zh_CN\]=Chromium 网页浏览器?Name\[zh_CN\]=WindViewer?" /root/WindViewer.desktop
    if [ -d "/root/桌面" ];then
        sudo \cp -f -p /root/WindViewer.desktop /root/桌面
        sudo chmod +x /rppt/桌面/WindViewer.desktop
    fi
    if [ -d "/root/Desktop" ];then
        sudo \cp -f -p /root/WindViewer.desktop /root/Desktop
        sudo chmod +x /root/Desktop/WindViewer.desktop
    fi
    sudo rm -f /root/WindViewer.desktop
    echo "谷歌浏览器配置完成！"
}

###
#检测服务状态
###

server_status(){
    for server in $*
    do
        Active=`systemctl status ${server}|grep Active |awk '{print $2}'`
        if [ $Active != active ]
	    then
            echo "${server}服务未正常启动，请确认！"
        else
            echo "${server}服务启动正常"
        fi
    done
}


###
#服务检测
###

check_servers(){
    tomcatCheck=$(rpm -qa | grep tomcat | wc -l)
    if [ ${tomcatCheck} -eq 1 ];then
        sudo rpm -qa | grep tomcat | awk '{print $1}' | xargs sudo rpm -e
    fi
    unset tomcatCheck

    SyncoveryC=$(rpm -qa | grep Syncovery | wc -l)
    if [ ${SyncoveryC} -eq 1 ];then
        sudo rpm -qa | grep Syncovery | awk '{print $1}' | xargs sudo rpm -e 1>/dev/null
    fi
    unset SyncoveryC
}

###
#redis配置
###

init_redis(){
   
    sudo \cp /etc/redis.conf /etc/redis.conf_`date +"%Y%m%d%H%M%S"`.backup
    sudo sed -i "s#^bind.*#bind 0.0.0.0#g" /etc/redis.conf
    sudo sed -i "s#^daemonize.*#daemonize yes#g" /etc/redis.conf
	sudo sed -i "s#^logfile.*#logfile $DataPath/redis/redis.log#g" /etc/redis.conf
	sudo sed -i "s#^dir.*#dir $DataPath/redis#g" /etc/redis.conf
	sudo sed -i "s#^requirepass.*#requirepass windey#g" /etc/redis.conf
    sudo mkdir -p $DataPath/redis
	sudo chown redis $DataPath/redis
    chmod 644 /etc/redis.conf
	sudo sed -i "s/Group.*/Group=windeyapps/g" /usr/lib/systemd/system/redis.service 
    sudo systemctl daemon-reload
	sudo systemctl restart redis
    echo "Redis配置完成！"
}


###
#mongodb配置
###

init_mongodb(){
    if ! rpm -qa|grep mongodb  >/dev/null 2>&1
	then
	    echo -e "\033[31m mongod服务未安装，请确认！\033[0m" 
	    return
	fi
    sudo \cp /etc/mongod.conf /etc/mongod.conf_`date +"%Y%m%d%H%M%S"`.backup
    sudo sed -i "s#path:.*#path: $DataPath/.windmanager/mongolog/mongod.log#g" /etc/mongod.conf
    sudo sed -i "s#dbPath:.*#dbPath: $DataPath/.windmanager/mongodata#g" /etc/mongod.conf
	sudo sed -i "s#port:.*#port: 48017#g" /etc/mongod.conf
	sudo sed -i "s#bindIp:.*#bindIp: 0.0.0.0#g" /etc/mongod.conf
    sudo chmod 644 /etc/mongod.conf
    sleep 1
	sudo  sed -i "s/Group.*/Group=windeyapps/g" /usr/lib/systemd/system/mongod.service
	sudo systemctl daemon-reload
	sudo systemctl restart mongod
    echo "MongoDB配置完成！"
}


###
#influxdb配置
###
init_influxdb_old(){
    sudo \cp /etc/influxdb/influxdb.conf /etc/influxdb/influxdb.conf_`date +"%Y%m%d%H%M%S"`.backup
    sudo sed -i "s#dir =.*meta#dir =\"$DataPath/.windmanager/influxmeta#g" /etc/influxdb/influxdb.conf
	sudo sed -i "s#dir =.*data#dir =\"$DataPath/.windmanager/influxdata#g" /etc/influxdb/influxdb.conf
	sudo sed -i "s#dir =.*wal#dir =\"$DataPath/.windmanager/influxwal#g" /etc/influxdb/influxdb.conf
    sudo chmod 644 /etc/influxdb/influxdb.conf
	sudo sed -i "s/Group.*/Group=windeyapps/g" /usr/lib/systemd/system/influxdb.service
	sudo systemctl daemon-reload
    sudo systemctl restart influxdb
    echo "InfluxDB配置完成！"
}
init_influxdb(){
    cat > expect.sh <<-EOF
#!/usr/bin/expect
set timeout -1 
spawn influx setup
expect "*username"
send "root\r"
expect "*password"
send "WindeyXT@2022\r"
expect "*again"
send "WindeyXT@2022\r"
expect "*name"
send "windey\r"
expect "*name"
send windmanager\r"
expect "*infinite."
send "\r"
expect "*y/n"
send "y\r"
interact
EOF
chmod +x expect.sh && ./expect.sh && rm -f expect.sh
cat /root/.influxdbv2/configs|grep -v '#'|grep token|awk '$1=$1' > test
}


###
#systemd模板
###
init_jar(){
    jarName=$1
	workDir=$2
	serverName=$3
	sudo touch /var/log/${serverName}.log
	sudo chown root:windeyapps /var/log/${serverName}.log
    cat >$workDir/$serverName.sh<<-EOF
#!/bin/bash

jarName="$jarName"
workDir="$workDir"
start(){
    cd \${workDir} && java -jar \${jarName} > /var/log/${serverName}.log 2>&1 &
}

stop(){
    ps -ef | grep -qP "(?<=-jar)\s+\${jarName}" && kill \$(ps -ef | grep -P "(?<=-jar)\s+\${jarName}" | awk '{print \$2}')
}

case \$1 in
    start)
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
    chmod +x $workDir/$serverName.sh
    cat >$serverName.service<<-EOF
[Unit]
Description=java project
After=$serverName.service

[Service]
Type=forking
User=root
Group=windeyapps
WorkingDirectory=$workDir
ExecStart=/bin/bash $serverName.sh start
ExecStop=/bin/bash $serverName.sh stop
ExecReload=/bin/bash $serverName.sh restart
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    sudo \cp $serverName.service /usr/lib/systemd/system/
	sudo systemctl daemon-reload && sudo systemctl start $serverName.service && systemctl enable $serverName.service
}


###
#部署WindCore
###
init_WindCore(){
    if [ ! -d "$ServerPath/WindCore" ];then
        \cp -a $CurrentPath/WindCore $ServerPath
		sudo chmod +x $ServerPath/WindCore/WindCore.jar
		init_jar "WindCore.jar" "$ServerPath/WindCore" "windcore"
    fi
    
}

###
#部署WindManagerBS
###
init_WindManagerBS(){
    if [ ! -d "$ServerPath/WindManagerBS" ];then
        sudo \cp -a $CurrentPath/WindManagerBS $ServerPath
		sudo chmod +x $ServerPath/WindManagerBS/WindManagerBS.jar
	    init_jar "WindManagerBS.jar" "$ServerPath/WindManagerBS" "windmanagerbs"
    fi
    
}

###
#WindSeer程序部署
###
init_WindSeer(){
    if [ ! -d "$ServerPath/WindSeer" ];then
        sudo \cp -a $CurrentPath/WindSeer $ServerPath
	    sudo chmod +x $ServerPath/WindSeer/wseer.jar
	    init_jar "wseer.jar" "$ServerPath/WindSeer" "windseer"
    fi
    
}

###
#WindSineb部署
###

init_WindSine(){
    if [ ! -d "$ServerPath/WindSine" ];then
        sudo \cp -a $CurrentPath/WindSine $ServerPath
		sudo chmod +x $ServerPath/WindSine/WindSine.jar
	    init_jar "WindSine.jar" "$ServerPath/WindSine" "windsine"
    fi
    
}

#########################################END#################################################

######################################################MAIN############################################

main(){
  
	#检测必要文件
	check_files
    install_automation
    echo 添加防火墙策略
    add_firewall_rules
    echo 系统相关设置
    system_setup
    echo 初始化工作空间
    init_workspace
    echo 检测卸载服务
    check_servers
    echo 配置VNC
    init_VNC
    echo 配置谷歌浏览器
    init_Chrome
    echo 配置redis
    init_redis
    echo 配置mongodb
    init_mongodb
    echo 配置influxdb
    init_influxdb
    echo 配置WindCore
    init_WindCore
    echo 配置WindManagerBS
    init_WindManagerBS
    echo 配置WindSeer
    init_WindSeer
    echo 配置WindSine
    init_WindSine
	sudo chown mongod $DataPath/.windmanager/mongodb
    sudo chown mongod $DataPath/.windmanager/mongodata
	sudo chown mongod $DataPath/.windmanager/mongolog
	sudo chown influxdb $DataPath/.windmanager/influxdata
	sudo chown influxdb $DataPath/.windmanager/influxmeta
	sudo chown influxdb $DataPath/.windmanager/influxwal
	sudo chown redis $DataPath/redis
	sudo chown :windeyapps $DataPath -R
	sudo chown :windeyapps $ServerPath -R
	sudo chmod 750  $DataPath -R
	sudo chmod 750  $ServerPath -R
    echo "EMS.sh脚本运行完毕，请重启操作系统！"
}
main
 