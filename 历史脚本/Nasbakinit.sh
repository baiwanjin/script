#!/bin/bash
echo "请您输入NAS备份服务器的地址: "
read NFSServerIP
NASNFSDIR='/volume1/Backup'
MOUNTDIR='/data'
MainDIR=$MOUNTDIR/'SCADA'
WindCoreBackup=$MainDIR/"WindCore"
WindCorePath="/home/data/WindCore"
SqlServerDBSpace=$MainDIR/"SqlserverDB"

WindeyBackup=$MainDIR/"windeybs"
WindeyPath="/home/data/windeybs"
TcpPorts=(2049)
#需要开放的UDP端口
UdpPorts=(2049)

add_firewall_rules(){
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
	    echo "添加UDP端口:${TcpPort}到防火墙"
	    sudo firewall-cmd --add-port=${UdpPort}/udp --permanent
        fi
	done
    sudo firewall-cmd --reload
}
#备份文件
backup_WindCore(){
    sudo mkdir -p /home/data/crontablist
    cat > /home/data/crontablist/backup_WindCore.sh<<EOF
#!/bin/bash
sudo df -hT $MOUNTDIR/ >/dev/null 2>&1
if [ \$? -eq 0 ]; then
    Time=\`date +%Y%m%d%H%M\`
    sudo mkdir -p $WindCoreBackup/\$Time
    if ls $WindCorePath >/dev/null 2>&1
    then
        sudo \\cp -r $WindCorePath/ $WindCoreBackup/\$Time/
        if ls $WindCoreBackup/\$Time/WindCore >/dev/null 2>&1
        then
            echo WindCore备份成功
        else
            echo WindCore备份失败
        fi
    else
        echo 不存在此文件$WindCorePath
    fi
fi
EOF
    sudo chmod +x  /home/data/crontablist/backup_WindCore.sh
    /home/data/crontablist/backup_WindCore.sh
}

#备份文件
backup_Windey(){
    sudo mkdir -p /home/data/crontablist
    cat > /home/data/crontablist/backup_Windey.sh<<EOF
#!/bin/bash
sudo df -hT $MOUNTDIR/ >/dev/null 2>&1
if [ \$? -eq 0 ]; then
    Time=\`date +%Y%m%d%H%M\`
    sudo mkdir -p $WindeyBackup/\$Time
    if ls $WindeyPath >/dev/null 2>&1
    then
        sudo \\cp -r $WindeyPath/ $WindeyBackup/\$Time/
        if ls $WindeyBackup/\$Time/windeybs >/dev/null 2>&1
        then
            echo windeybs备份成功
        else
            echo windeybs备份失败
        fi
    else
        echo 不存在此文件$WindeyPath
    fi
fi
EOF
    sudo chmod +x /home/data/crontablist/backup_Windey.sh
    /home/data/crontablist/backup_Windey.sh
}

#NFSserver校验
check_NFSServer(){
    if sudo showmount -e $NFSServerIP | grep $NASNFSDIR
    then
        return
    fi
    echo "未检测到NFS共享文件$NASNFSDIR"
    exit
}
#挂载文件
mount_nfs(){
    sudo mkdir -p $MOUNTDIR
    sudo mount $NFSServerIP:$NASNFSDIR $MOUNTDIR 
    if ! sudo grep "^$NFSServerIP:$NASNFSDIR" /etc/fstab
    then
        echo "$NFSServerIP:$NASNFSDIR $MOUNTDIR    nfs    defaults,_netdev    0  0"|sudo tee -a /etc/fstab
    fi

}

#增加定时任务
crontab_init(){
    crontab -l  >/dev/null 2>&1 >> crontabfile
    if ! grep "/home/data/crontablist/backup_full.sh" crontabfile >/dev/null 2>&1;then echo '0 5 15 * * /home/data/crontablist/backup_full.sh' >> crontabfile;fi
    if ! grep "/home/data/crontablist/backup_diff.sh" crontabfile >/dev/null 2>&1;then echo '30 5 * * 6 /home/data/crontablist/backup_diff.sh' >> crontabfile;fi
    if ! grep "/home/data/crontablist/backup_WindCore.sh" crontabfile >/dev/null 2>&1;then echo '0 4 2,17 * * /home/data/crontablist/backup_WindCore.sh' >> crontabfile;fi
    if ! grep "/home/data/crontablist/backup_Windey.sh" crontabfile >/dev/null 2>&1;then echo '30 4 2,17 * * /home/data/crontablist/backup_Windey.sh' >> crontabfile;fi
    
    crontab crontabfile && rm -f crontabfile
}

#backup_diff.sh文件
diff_init(){
    sudo mkdir -p /home/data/crontablist/
    cat > /home/data/crontablist/backup_diff.sh<<EOF
#!/bin/bash
count1=\$(sudo rpm -qa | grep msodbcsql | wc -l)
count2=\$(sudo rpm -qa | grep mssql-tools | wc -l)
if [ \${count1} -lt 1 ] || [ \${count2} -lt 1 ];then
  echo "检测到未安装SQL Server数据库工具，脚本无法运行。请联系技术人员。"
  exit
fi

#检查nfs是否挂载
sudo df -hT $MOUNTDIR/ >/dev/null 2>&1
if [ \$? -eq 0 ]; then
    date1=\`date +%Y%m%d%H%M\`
    date2=\`date +%Y\`
    date3=\`date +%m\`
    dir=$SqlServerDBSpace/\$date2
    my_dir="\$dir/\$date3"
    sudo mkdir -p \$my_dir
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P Sa123456% -d master -Q "BACKUP DATABASE wind_data TO DISK='\$my_dir/wind_data_diff_\$date1.bak' with format, differential"
    if ls \$my_dir/wind_data_diff_\$date1.bak
    then
        echo  "wind_data数据库差异备份成功，文件保存在\$my_dir/wind_data_diff_\$date1.bak"
    else
        echo "未发现挂载NFS，请联系技术人员。"
        echo "未完成备份，脚本退出"
     
    fi


fi
EOF
    sudo chmod +x  /home/data/crontablist/backup_diff.sh
    /home/data/crontablist/backup_diff.sh
}

#backup_full.sh文件
full_init(){
    sudo mkdir -p sudo /home/data/crontablist/
    cat >/home/data/crontablist/backup_full.sh<<EOF
#!/bin/bash
count1=\$(sudo rpm -qa | grep msodbcsql | wc -l)
count2=\$(sudo rpm -qa | grep mssql-tools | wc -l)
if [ \${count1} -lt 1 ] || [ \${count2} -lt 1 ];then
  echo "检测到未安装SQL Server数据库工具，脚本无法运行。请联系技术人员。"
  exit
fi
####数据库工具检测自动安装
#检查nfs是否挂载
sudo df -hT $MOUNTDIR/ >/dev/null 2>&1
if [ \$? -eq 0 ]; then
    date1=\`date +%Y%m%d%H%M\`
    date2=\`date +%Y\`
    my_dir="$SqlServerDBSpace/\$date2"
    sudo mkdir -p \$my_dir
    sudo /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P Sa123456% -d master -Q "BACKUP DATABASE wind_data TO DISK='\$my_dir/wind_data_full_\$date1.bak'"
    if ls \$my_dir/wind_data_full_\$date1.bak
    then
        echo  "wind_data数据库全量备份成功，文件保存在\$my_dir/wind_data_full_\$date1.bak"
    else
        echo "未发现挂载NFS，请联系技术人员。"
        echo "未完成备份，脚本退出"
    fi
fi
EOF
    sudo chmod +x /home/data/crontablist/backup_full.sh
    /home/data/crontablist/backup_full.sh
}

add_firewall_rules
check_NFSServer
mount_nfs
crontab_init
echo "正在备份中，花费时间较长，请耐心等待。。。。。。"
full_init
diff_init
backup_WindCore
backup_Windey