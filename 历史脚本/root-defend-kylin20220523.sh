#!/bin/bash
#麒麟系统安全防护检测脚本

#################################################################################################################################################
DATE=`date +"%Y%m%d%H%M%S"`
#配置文件集合
ConfigList=('/etc/rsyslog.conf' '/etc/vsftpd/vsftpd.conf' '/etc/ftpusers' '/etc/vsftpd/ftpusers' '/etc/profile' '/etc/host.conf' '/etc/aliases' '/etc/passwd' \
'/etc/pam.d/su' '/etc/pam.d/system-auth' '/etc/login.defs' '/etc/security/limits.conf' '/root/.bashrc' '/etc/csh.cshrc' '/etc/bashrc' '/etc/sysctl.conf' \
'/etc/hosts.allow' '/etc/ssh/sshd_config ' '/etc/audit/audit.rules' '/etc/logrotate.d/audit')
#更换定时任务文件存放位置
CrontabList='/etc/crontablist'
#需要开放的TCP端口
TcpPorts=(21 22 80 501 502 503 504 505 506 507 508 509 510 511 512 513 514 515 516 517 518 519 520 521 \
522 523 524 525 987 1433 1601 1625 1640 3306 5900 6379 8080 8082 48898 48899 8086 8182 8184 8185 9166 \
27017 2404 2405 2406 2407 2408 2409 2410 2411 2412 2413 2414 2415 2416 2417 2418 2419 2420 2421 2422 \
2423 2425 2426 2427 2428 2429 2430 2431 2432 2433 2434 2435 2436 2437 2438 2439 2440 2441 2442 2443 \
2444 2445 2446 2447 2448 2449 2450 2451 2452 2453 2454 2455 2456 2457 2458 2459 2460 2461 2462 2463 \
2464 2465 2466 2467 2468 2469 2470 2471 2472 2473 2474 2475 2476 2477 2478 2479 2480 2481 2482 2483 \
2484 2485 2486 2487 2488 2489 2490 2491 2492 2493 2494 2495 2496 2497 2498 2499 2500 2501 2502 2503 \
2504 5866 5432 7777 9160 9161 9162 9163 9164 9165 9166 9167 9168 9169 9170 9171 9172 9173 9174 9175 9176 9177 9178 9179 9180)
#需要开放的UDP端口
UdpPorts=(123 1434 4747 4848 8086 8182 8184 8185 9166 27017)
#相关的server服务
services=(redis postgres WindCore postgresql-12 WindManagerBS WindSeer WindSine influxdb mongodb mysqld CMS)
backup_config(){
    if ! test -d /etc/config_backup_$DATE
    then
        for i in ${ConfigList[*]}
        do
            dir=/etc/config_backup_$DATE/${i%/*}
            mkdir -p $dir
            \cp $i $dir
        done
        cat > /etc/config_backup_$DATE/reset-defend.sh<<EOF
#!/bin/bash
ConfigList=('/etc/rsyslog.conf' '/etc/vsftpd/vsftpd.conf' '/etc/ftpusers' '/etc/vsftpd/ftpusers' '/etc/profile' '/etc/host.conf' \
'/etc/aliases' '/etc/passwd' '/etc/pam.d/su' '/etc/pam.d/system-auth' '/etc/login.defs' '/etc/security/limits.conf' '/root/.bashrc' \
'/etc/csh.cshrc' '/etc/bashrc' '/etc/sysctl.conf' '/etc/hosts.allow' '/etc/ssh/sshd_config ' '/etc/audit/audit.rules' '/etc/logrotate.d/audit')
restore_config(){
    for i in \${ConfigList[*]}
    do
        if test -e \$i
        then
            dir=/etc/config_backup_\`date +"%Y%m%d%H%M%S"\`\${i%/*}
            mkdir -p \$dir
            \\cp \$i \$dir
            \\cp .\$i \${i%/*}
            chmod +r \$i
            echo "\`date +"%Y-%m-%d %H:%M:%S"\` [INFO]: 还原\$i文件夹"
        fi
    done
}
on_CD(){
    if ! ls /opt/sr_mod.ko.* >/dev/null 2>&1
    then
        echo "\`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]: 未找到sr_mod.ko相关设备文件"
    fi
    sudo mv /opt/sr_mod.ko.* /usr/lib/modules/\`uname -r\`/kernel/drivers/scsi/
    sudo modprobe -i sr_mod
}
on_usb(){
    if ! ls /opt/usb-storage.ko* >/dev/null 2>&1
    then
        echo "\`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]: 未找到USB相关设备文件"
    fi
    sudo mv /opt/usb-storage.ko* /lib/modules/\`uname -r\`/kernel/drivers/usb/storage/
    sudo modprobe -i usb_storage
}
chattr -i /etc/gshadow
chattr -i /etc/passwd
chattr -i /etc/shadow
chattr -i /etc/group
on_CD
on_usb
restore_config

EOF
    fi
}

create_group(){
	if ! grep "windeyapps" /etc/group  >/dev/null 2>&1
	then
	    chattr -i /etc/group
        chattr -i /etc/gshadow
        groupadd windeyapps
	fi
}
set_service_config(){
	for service in ${services[*]}
	do  
	    systemctl daemon-reload
	    if systemctl|grep $service.service >/dev/null 2>&1
		then
		    conf=`systemctl status $service|grep Loaded|awk -F '(' '{print $2}'|awk -F ';' '{print $1}' 2>/dev/null`
		    if grep '^Group' $conf >/dev/null 2>&1
		    then
		        sed -i "s/Group.*/Group=windeyapps/g"  $conf
		    else
		        sed -i '/^\[Service\]/a\Group=windeyapps' $conf
		    fi
			systemctl daemon-reload && systemctl restart $service.service
		    serviceUser=`grep '^User' $conf|awk -F '=' '{print $2}' 2>/dev/null`
		    if [ $serviceUser ]
		    then 
		        usermod -G windeyapps $serviceUser 
		    else
			    usermod -G windeyapps root
			fi
			
		fi
		
	done
	chown :windeyapps /home/data/ -R
}
# set_restart-tomcat_sh(){
#     if grep /home/data/windeybs/restart-tomcat.sh >/dev/null 2>&1
# 	then
# 	    mv /home/data/windeybs/restart-tomcat.sh /home/data/windeybs/restart-tomcat_`date +"%Y%m%d"`.sh
# 		echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 将文件/home/data/windeybs/restart-tomcat.sh备份为/home/data/windeybs/restart-tomcat_`date +"%Y%m%d"`.sh"|sudo tee -a  /var/log/set_passwd.log 
		
# 	fi
	
#     cat >restart-tomcat.sh<<EOF
# #!/bin/sh
# sh /home/data/windeybs/windeyapp/farmmonitoring.sh
# echo "Restarting Tomcat......"

# OSname=\$(cat /etc/redhat-release)
# echo \${OSname}
# if [[ \${OSname} =~ "UniKylin" ]] || [[ \${OSname} =~ "KylinSec" ]];then
#    systemctl stop tomcat >/dev/null 2>&1
#    sleep 2
#    systemctl start tomcat && systemctl status tomcat
#    echo "tomcat started"
# else  
#    catalina=\`ps -ef | grep catalina| grep -v grep | wc -l\`
#    if [ \$catalina -ge 1 ];then
#       ps -ef | grep catalina | grep -v grep | awk {'print \$2'} | xargs kill -9 >/dev/null 2>&1
#       echo "tomcat killed"
#       sleep 2
#    fi
#    if systemctl|grep tomcat >/dev/null 2>&1
#    then
#        systemctl daemon-reload && systemctl restart tomcat && systemctl status tomcat
#    else
#        sh /usr/local/tomcat/bin/startup.sh
#    fi
#    echo "tomcat started"
   
# fi
# EOF
#     chmod +x restart-tomcat.sh && mv restart-tomcat.sh /home/data/windeybs/
# }

# set_tomcat(){
#     if grep -q '/usr/local/tomcat/bin/startup.sh' /etc/profile 
#     then
#         sed -i '/\/usr\/local\/tomcat\/bin\/startup.sh/  s/^\(.*\)$/#\1/g' /etc/profile 
#     fi
#     TomcatPID=`ps -ef|grep TomcatPID|grep -v grep|awk 'NR>1 {print $2}'`
# 	if [[ -n $TomcatPID ]]
#     then 
# 	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在多个TomcatPID进程$TomcatPID"|tee -a precautions_`date +"%Y%m%d"`.log
#         ps -ef|grep tomcat|grep -v grep|awk 'NR>1 {print $2}'|xargs kill -9
# 	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:杀死多余的TomcatPID进程：$TomcatPID"|tee -a precautions_`date +"%Y%m%d"`.log
# 	fi
#     cat > tomcat.service <<-EOF
# [Unit]
# Description=tomcat
# After=network.target-

# [Service]
# Type=oneshot
# User=root
# Group=windeyapps
# ExecStart=/usr/local/tomcat/bin/startup.sh
# ExecStop=/usr/local/tomcat/bin/shutdown.sh
# ExecReload=/bin/kill -s HUP $MAINPID
# RemainAfterExit=yes

# [Install]
# WantedBy=multi-user.target
# EOF
#     \cp tomcat.service /usr/lib/systemd/system/
#     systemctl daemon-reload && systemctl enable tomcat.service 
# }
# set_windcore(){
# if grep -q '/home/data/WindCore/startup.sh' /etc/profile
# then
#     sed -i '/WindCore/ s/^\(.*\)$/#\1/g' /etc/profile 
# fi
# WindCorePID=`ps -ef|grep WindCore|grep -v grep|awk 'NR>1 {print $2}'`
# 	    if [[ -n $WindCorePID ]]
#         then 
# 	        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在多个WindCore进程$WindCorePID"|tee -a precautions_`date +"%Y%m%d"`.log
#             ps -ef|grep WindCore|grep -v grep|awk 'NR>1 {print $2}'|xargs kill -9
# 	        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:杀死多余的WindCore进程：$WindCorePID"|tee -a precautions_`date +"%Y%m%d"`.log
# 	    fi
# cat > WindCore.service <<-EOF
# [Unit]
# Description=java project
# After=WindCore.service

# [Service]
# Type=forking 
# User=root
# Group=windeyapps
# ExecStart=/home/data/WindCore/startup.sh
# ExecReload=/bin/kill -s HUP $MAINPID
# ExecStop=/bin/kill -s QUIT $MAINPID
# PrivateTmp=True

# [Install]
# WantedBy=multi-user.target

# EOF
#     \cp WindCore.service /usr/lib/systemd/system/
#     systemctl daemon-reload && systemctl enable WindCore.service 
# }


setup_passwd(){

cat > setpasswd.sh <<EOF
#!/bin/bash
set_passwd(){
    if [[ \$1 != "" ]] && sudo grep "^\$1" /etc/passwd 1>/dev/null
    then 
        if [[ \$2 == "" ]]
        then
            echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 密码为空，退出修改！"|sudo tee -a  /var/log/set_passwd.log 
            return
        fi
        echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 更新用户\$1的密码为\$2"|sudo tee -a  /var/log/set_passwd.log 
        echo \$1:\$2|sudo chpasswd 
        return
    fi
    echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 不存在这个用户！"|sudo tee -a  /var/log/set_passwd.log
}
main(){
    passwdON=yes
    shadowON=yes
    if sudo lsattr /etc/passwd|awk '{print \$1}'|grep 'i'
    then
        sudo chattr -i /etc/passwd
        passwdON=no
        echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 执行sudo chattr -i /etc/passwd指令"|sudo tee -a  /var/log/set_passwd.log
    fi
    if sudo lsattr /etc/shadow|awk '{print \$1}'|grep 'i'
    then
        sudo chattr -i /etc/shadow
        shadowON=no
        echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 执行sudo chattr -i /etc/shadow指令"|sudo tee -a  /var/log/set_passwd.log
    fi
    set_passwd root 'WindeyXT@2022'
    set_passwd chinawindey 'WindeyXT@2022'
    set_passwd sysadm 'WindeyXT@2022'
    set_passwd audadm 'WindeySJ@2022'
    set_passwd secadm 'WindeyAQ@2022'
    if [[ \$passwdON == "no" ]]
    then
        sudo chattr +i /etc/passwd
        echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 执行sudo chattr +i /etc/passwd指令"|sudo tee -a  /var/log/set_passwd.log
    fi
    if [[ \$shadowON == "no" ]]
    then
        sudo chattr +i /etc/shadow
        echo "\`date +"%Y-%m-%d %H:%M:%S"\`  [INFO]: 执行sudo chattr +i /etc/shadow指令"|sudo tee -a  /var/log/set_passwd.log
    fi

}
main
EOF
sudo mkdir -p $CrontabList
sudo chmod +x setpasswd.sh && sudo mv setpasswd.sh  $CrontabList
crontab -l  >/dev/null 2>&1 >> crontabfile
if ! grep $CrontabList'/setpasswd.sh' crontabfile >/dev/null 2>&1;then echo '50 23 15 2,4,6,8,10,12 * '$CrontabList'/setpasswd.sh' >> crontabfile;fi
crontab crontabfile && rm -f crontabfile
$CrontabList'/setpasswd.sh'

}
set_rsyslog(){
    if ! ls /etc/rsyslog.conf_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
    then
        \cp /etc/rsyslog.conf /etc/rsyslog.conf_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/rsyslog.conf备份为/etc/rsyslog.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    if ! ls /etc/rsyslog.conf_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
    then
        \cp /etc/rsyslog.d/*.conf /etc/rsyslog.d/*.conf_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/rsyslog.d/*.conf备份为/etc/rsyslog.d/*.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    if ! grep ^\$FileCreateMode /etc/rsyslog.conf >/dev/null 2>&1
    then
        echo "\$FileCreateMode 0640"| tee -a /etc/rsyslog.conf 
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/rsyslog.conf中添加$FileCreateMode 0640"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    if ! grep ^\$FileCreateMode /etc/rsyslog.d/*.conf >/dev/null 2>&1
    then
        echo "\$FileCreateMode 0640"| tee -a /etc/rsyslog.d/*.conf 
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/rsyslog.d/*.conf中添加$FileCreateMode 0640"|tee -a precautions_`date +"%Y%m%d"`.log
    fi

}

#检查是否禁止匿名VSFTP用户登录
check_Vsftp(){
    anonymous_enable=`grep "^anonymous_enable" /etc/vsftpd/vsftpd.conf | awk -F '=' '{print $2}'`
    if [[ $anonymous_enable != "NO" ]]
    then
    if ! ls /etc/vsftpd/vsftpd.conf_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
    then
        \cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/vsftpd/vsftpd.conf备份为/etc/vsftpd/vsftpd.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
        sed -i "s/anonymous_enable.*/anonymous_enable=NO/g"  /etc/vsftpd/vsftpd.conf
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将/etc/vsftpd/vsftpd.conf文件中的anonymous_enable=$anonymous_enable设置为anonymous_enable=NO"|tee -a precautions_`date +"%Y%m%d"`.log
    fi

}
#需要删除的用户
del_User(){
    delUserList=(ftp)
    for user in ${delUserLis[*]}
    do
        userdel $user
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 删除用户$user"|tee -a precautions_`date +"%Y%m%d"`.log
    done

}

#检查是否禁止root用户远程telnet登录
check_telnet(){
    if ! ls /etc/pam.d/login_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
    then
    if !  grep "^auth" /etc/pam.d/login|grep "required"|grep "pam_securetty.so"
        then
            \cp /etc/pam.d/login /etc/pam.d/login_`date +"%Y%m%d"`.bak
            echo -e "auth    required    pam_securetty.so" | tee -a /etc/pam.d/login
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 添加auth    required    pam_securetty.so到文件/etc/pam.d/login"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    fi
}
#检查是否删除.rhosts 文件
check_rhosts(){
#find / -maxdepth 3 -name .rhosts
#find / -maxdepth 3 -name .netrc
#find / -maxdepth 3 -name hosts.equiv
    rhostsfiles=`$1 2>/dev/null`
    if [[ $rhostsfiles != "" ]]
    then
    for file in $rhostsfiles
    do
            mv $file $file_`date +"%Y%m%d"`.bak
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件$file重命名为$file_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        done
     fi

}
#检查是否禁止root登录VSFTP
check_rootLoginVsftp(){
    if ls /etc/ftpusers >/dev/null 2>&1
    then
        if ! ls /etc/ftpusers_`date +"%Y%m%d"`.bak >/dev/null 2>&1
        then
            \cp /etc/ftpusers /etc/ftpusers_`date +"%Y%m%d"`.bak
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/ftpusers备份为/etc/ftpusers_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        fi
        if ! grep "^root" /etc/ftpusers
        then
            echo "root" | tee -a /etc/ftpusers
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将root追加到文件/etc/ftpusers"|tee -a precautions_`date +"%Y%m%d"`.log
        fi
    fi
    if ls /etc/vsftpd/ftpusers >/dev/null 2>&1
    then
        if ! ls /etc/vsftpd/ftpusers_`date +"%Y%m%d"`.bak >/dev/null 2>&1
        then
            \cp /etc/vsftpd/ftpusers /etc/vsftpd/ftpusers_`date +"%Y%m%d"`.bak
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/vsftpd/ftpusers备份为/etc/vsftpd/ftpusers_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        fi
        if !  grep "^root" /etc/vsftpd/ftpusers
        then
            echo "root" | tee -a /etc/vsftpd/ftpusers
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将root追加到文件/etc/vsftpd/ftpusers"|tee -a precautions_`date +"%Y%m%d"`.log
        fi
    fi

}
#历史命令配置策略
history_strategy(){
    if ! ls /etc/profile_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        \cp /etc/profile /etc/profile_`date +"%Y%m%d"`.bak
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/profile备份为/etc/profile_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    if  grep "^HISTSIZE" /etc/profile >/dev/null 2>&1
    then
        sed -i 's/^HISTSIZE.*/HISTSIZE=5/g' /etc/profile
        echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/profile中HISTSIZE的值改为5"|tee -a precautions_`date +"%Y%m%d"`.log
    else
        echo -e "HISTSIZE=5" | tee -a /etc/profile
        echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将HISTSIZE=5追加到文件/etc/profile中"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    if  grep "^ HISTFILESIZE" /etc/profile >/dev/null 2>&1
    then
        sed -i 's/HISTFILESIZE.*/HISTFILESIZE=5/g' /etc/profile
        echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/profile中 HISTFILESIZE的值改为5"|tee -a precautions_`date +"%Y%m%d"`.log
    else
        echo -e "HISTFILESIZE=5" | tee -a /etc/profile
        echo -e " `date +"%Y-%m-%d %H:%M:%S"`  [INFO]: HISTFILESIZE=5追加到文件/etc/profile中"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
}

#关闭IP伪装和绑定多IP功能
stop_VIP(){
    if ls /etc/host.conf >/dev/null 2>&1
    then
        if ! ls /etc/host.conf_`date +"%Y%m%d"`.bak >/dev/null 2>&1
        then
            \cp /etc/host.conf /etc/host.conf_`date +"%Y%m%d"`.bak
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/host.conf备份为/etc/host.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        fi
    fi
    if ! grep "^multi off" /etc/host.conf
	then
        echo -e "multi off"| tee -a /etc/host.conf
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/host.conf末尾追加multi off"|tee -a precautions_`date +"%Y%m%d"`.log
        chmod 644 /etc/host.conf
	fi
}

#别名文件/etc/aliase（或/etc/mail/aliases）配置策略
set_aliases(){
    if ! ls /etc/aliases_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        \cp /etc/aliases /etc/aliases_`date +"%Y%m%d"`.bak
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/aliases备份为/etc/aliases_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    sed -i 's/^games.*root/#&/g' /etc/aliases
    sed -i 's/^ingres.*root/#&/g' /etc/aliases
    sed -i 's/^system.*root/#&/g' /etc/aliases
    sed -i 's/^toor.*root/#&/g' /etc/aliases
    sed -i 's/^uucp.*root/#&/g' /etc/aliases
    sed -i 's/^manager.*root/#&/g' /etc/aliases
    sed -i 's/^dumper.*root/#&/g' /etc/aliases
    sed -i 's/^operator.*root/#&/g' /etc/aliases
    sed -i 's/^decode.*root/#&/g' /etc/aliases
    sed -i 's/^root.*marc /#&/g' /etc/aliases
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 注释/etc/aliases文件中的root别名"|tee -a precautions_`date +"%Y%m%d"`.log

}

#结束权限设置
end(){
     chmod 750 /etc/rc.d/init.d/
     chmod 750 /etc/rc3.d    
     chmod 750 /etc/rc6.d
     chmod 600 /boot/grub2/grub.cfg
     chmod 750 /etc/rc5.d/
     chmod 750 /etc/rc1.d/
     chmod 600 /etc/security
     chmod 750 /etc/rc4.d
     chmod 644 /etc/passwd
     chmod 750 /etc/rc0.d/
     chmod 644 /etc/services
     chmod 750 /etc/rc2.d/
     chmod 644 /etc/group        
     chmod 750 /tmp
     chmod 400 /etc/shadow
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/rc.d/init.d/，/etc/rc3.d，/etc/rc6.d，/etc/rc5.d/，/etc/rc1.d/，/etc/rc4.d，/etc/rc0.d/，/etc/rc2.d/，/tmp的权限为750"|tee -a precautions_`date +"%Y%m%d"`.log
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/boot/grub2/grub.cfg，/etc/security的权限为600"|tee -a precautions_`date +"%Y%m%d"`.log
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/passwd，/etc/services，/etc/group的权限为644"|tee -a precautions_`date +"%Y%m%d"`.log
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/shadow的权限为400"|tee -a precautions_`date +"%Y%m%d"`.log
     chattr +i /etc/gshadow
     chattr +i /etc/passwd
     chattr +i /etc/shadow
     chattr +i /etc/group
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 文件/etc/gshadow，/etc/passwd，/etc/shadow，/etc/group增加权限“i”"|tee -a precautions_`date +"%Y%m%d"`.log
}


#################################################################################################################################################
#删除或禁用系统无关的用户
drop_UnusedUser(){
    UnusedUser=`cat /etc/passwd |grep "/bin/bash"|grep -v "chinawindey\|root\|sysadm\|daemon\|adm\|lp\|sync\|shutdown\|halt\|mail\|uucp\|operator\|gopher\|ftp\|nobody\|rpm\|nscd\|avahi\|mailnull\|smmsp\|vcsa\|rpc\|sshd\|rpcuser\|nfsnobody\|pcap\|ntp\|haldaemon\|xfs\|gdm\|secadm\|audadm"|awk -F ":" '{print $1}'`
    if [[ $UnusedUser != "" ]]
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 存在无关用户，正在备份/etc/passwd文件为/etc/passwd_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	\cp /etc/passwd /etc/passwd_`date +"%Y%m%d"`.bak
	for unuseduser in $UnusedUser
        do
            if grep "^$unuseduser" /etc/passwd
	    then
		sed -i "/^$unuseduser/s#/bin/bash#/sbin/nologin#g" /etc/passwd
		echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将$unuseduser用户设置为/sbin/nologin"|tee -a precautions_`date +"%Y%m%d"`.log
	    fi
	done
    fi
}
#开启屏幕保护程序
open_ScreenProtect(){
    gsettings set org.mate.screensaver idle-activation-enabled true
	gsettings set org.mate.power-manager sleep-display-ac 300
}

#安全用户查看
check_User(){
    user_Count=`egrep "sysadm|audadm|secadm" /etc/passwd|wc -l`
	if [ $user_Count -ne 3 ]
	then
	    echo -e "\033[31m`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:  安全用户检测不通过! \033[0m" |tee -a precautions_`date +"%Y%m%d"`.log
        users=`cat /etc/passwd|egrep "sysadm|audadm|secadm"`
        echo -e "\033[31m`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: $users \033[0m" |tee -a precautions_`date +"%Y%m%d"`.log
		return
	fi
	echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:  安全用户检查通过。" |tee -a precautions_`date +"%Y%m%d"`.log
}

#系统重要数据访问控制
set_FileAuthority(){
    ls -l $1|tee -a precautions_`date +"%Y%m%d"`.log

}
#禁止wheel组之外的用户su到root
ban_Su(){
    if ! ls /etc/pam.d/su_`date +"%Y%m%d"`.bak  >/dev/null 2>&1
    then
        \cp /etc/pam.d/su /etc/pam.d/su_`date +"%Y%m%d"`.bak >/dev/null 2>&1
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/pam.d/su备份为/etc/pam.d/su_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    sed -i '/pam_wheel.so/s/^#//' /etc/pam.d/su
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将/etc/pam.d/su中的pam_wheel.so行取消注解"|tee -a precautions_`date +"%Y%m%d"`.log
    if !  grep "^auth" /etc/pam.d/su|grep pam_rootok.so >/dev/null 2>&1
    then
        echo "auth            sufficient      pam_rootok.so" | tee -a /etc/pam.d/su
        echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将auth            sufficient      pam_rootok.so追加到/etc/pam.d/su"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    if !  grep "^auth" /etc/pam.d/su|grep "required"|grep "pam_wheel.so"|grep "group=wheel" >/dev/null 2>&1
    then
        echo -e "auth            required     pam_wheel.so    group=wheel" | tee -a /etc/pam.d/su
        echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将auth            required      pam_wheel.so    group=wheel追加到/etc/pam.d/su"|tee -a precautions_`date +"%Y%m%d"`.log
    fi
    suUsers=`cat /etc/passwd |grep "/bin/bash"|grep -v "root"`
    for suuser in $suUsers 
    do
	if grep -e "^$suuser" /etc/sudoers
	then
            echo "\033[31m`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: $suuser用户可以通过su命令登录root,请确认！\033[0m"|tee -a precautions_`date +"%Y%m%d"`.log
	fi
    done
}

#避免系统出现相同的UID账户 （待定）
check_Uid(){
     users=`cat /etc/passwd|awk -F ":" '{print $1}'`
	 uids=`cat /etc/passwd|awk -F ":" '{print $3}'`
	  for ((i=0;i<${#uids[*]};i++))
            do
            echo ${uids[$i]}
            done
	 
	 
    for i in ${!uids[@]}
    do
        user=getent passwd ${uids[$i]}|cut -d
        if [ $user != ${users[$i]} ]
	then
	    echo "ERREO"
	fi
    done

}

#禁止存在空密码账户

ban_User(){
    noPasswdUsers=`cat /etc/shadow|grep '!!'|awk -F ":" '{print $1}'`
    if [[ $noPasswdUsers != "" ]]
    then
        for nopasswduser in $noPasswdUsers
	do
	    echo "Windey@2022"| passwd --stdin $nopasswduser >/dev/null 2>&1
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改$nopasswduser用户的密码为Windey@2022"|tee -a precautions_`date +"%Y%m%d"`.log
	done
	fi
}

###
#身份鉴别
###
#用户口令复杂度策略
passwd_rule(){
    if ! grep -e "^password *required *pam_passwdqc.so" /etc/pam.d/system-auth >/dev/null 2>&1
    then
	if ! ls /etc/pam.d/system-auth_`date +"%Y%m%d"`.bak >/dev/null 2>&1
	then
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/pam.d/system-auth为/etc/pam.d/system-auth_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	    \cp /etc/pam.d/system-auth /etc/pam.d/system-auth_`date +"%Y%m%d"`.bak
	fi
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在/etc/pam.d/system-auth文件中添加'password    required    pam_passwdqc.so min=disabled,40,8,8,8 max=40 retry=3'"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i '/^password *required/a\password    required    pam_passwdqc.so min=disabled,40,8,8,8 max=40 retry=3' /etc/pam.d/system-auth
    fi
}

#用户登录失败锁定
login_failed(){
    if ! grep -e "^auth *required *pam_tally2.so" /etc/pam.d/system-auth >/dev/null 2>&1
    then
        if ! ls /etc/pam.d/system-auth_`date +"%Y%m%d"`.bak >/dev/null 2>&1
	then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/pam.d/system-auth为/etc/pam.d/system-auth_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	    \cp /etc/pam.d/system-auth /etc/pam.d/system-auth_`date +"%Y%m%d"`.bak
	fi
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在/etc/pam.d/system-auth文件中添加'auth  required    pam_tally2.so   per_user onerr=fail    deny=5    unlock_time=600 even_deny_root_account audit'"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i '/auth *required *pam_deny.so/a\auth  required    pam_tally2.so   per_user onerr=fail    deny=5    unlock_time=600 even_deny_root_account audit' /etc/pam.d/system-auth    
    fi
}


#用户口令
passwd_Deadline(){
    if ! ls  /etc/login.defs_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/login.defs为/etc/login.defs_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	    \cp /etc/login.defs /etc/login.defs_`date +"%Y%m%d"`.bak
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/login.defs文件中的PASS_MAX_DAYS值为90"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/^PASS_MAX_DAYS .*/PASS_MAX_DAYS   90/g"  /etc/login.defs
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/login.defs文件中的PASS_MIN_DAYS值为10"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/^PASS_MIN_DAYS .*/PASS_MIN_DAYS   10/g"  /etc/login.defs
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/login.defs文件中的/PASS_WARN_AGE值为30"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/^PASS_WARN_AGE .*/PASS_WARN_AGE   10/g"  /etc/login.defs
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/login.defs文件中的/PASS_MIN_LEN值为8"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/^PASS_MIN_LEN.*/PASS_MIN_LEN   8/g"  /etc/login.defs
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/login.defs文件中的/PASS_MIN_LEN值为8"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/^PASS_MIN_LEN.*/PASS_MIN_LEN   8/g"  /etc/login.defs
    
    for user in ` cat /etc/passwd |grep "/bin/bash"|awk -F ":" '{print $1}'`
    do
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改用户$user的PASS_WARN_AGE值为10、PASS_MAX_DAYS值为90、PASS_MIN_DAYS值为10"|tee -a precautions_`date +"%Y%m%d"`.log
        chage $user -M 90
        chage -W 30 $user
        chage -m 10 $user  	
    done
    echo root:WindeyXT@2022|chpasswd 
}
##################
#操作系统补丁管理#
##################
#操作系统补丁更新



##########
#主机配置#
##########
#1.4.1修改核心转储core dump状态
#1.4.2限制用户对资源的使用
core_dump(){
    #coreDumpStatus=`ulimit -c`
    #if [[ $coreDumpStatus -ne 0 ]]
    #then
        if ! ls /etc/security/limits.conf_`date +"%Y%m%d"`.bak >/dev/null 2>&1
	then
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/security/limits.conf为/etc/security/limits.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	    \cp /etc/security/limits.conf /etc/security/limits.conf_`date +"%Y%m%d"`.bak
	fi
	#不要用这种方式，不同的系统文件存在空格差
	#if  grep "^\* soft core" /etc/security/limits.conf
	if   grep "^\*" /etc/security/limits.conf|grep "soft"|grep "core"
	
	
	then
            sed -i "s/^\* soft core.*/\* soft core 0/g" /etc/security/limits.conf
	else
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在/etc/security/limits.conf文件末尾插入* soft core 0"
	    echo '* soft core 0'|tee -a /etc/security/limits.conf 1>/dev/null
	fi
	if  grep "^\*" /etc/security/limits.conf|grep "statck"|grep "10000"
	#if  grep "^\* - statck 10000" /etc/security/limits.conf
	then
            sed -i "s/^\* - statck.*/\* - statck 10000/g" /etc/security/limits.conf
	else	
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在/etc/security/limits.conf文件末尾插入 * - statck 10000"
	    echo '* - statck 10000'|tee -a /etc/security/limits.conf 1>/dev/null
	fi
	if   grep "^\*" /etc/security/limits.conf |grep "rss"|grep "10000"
	#if  grep "^\* - rss 10000" /etc/security/limits.conf
	then
	    sed -i "s/^\* - rss.*/\* - rss 10000/g" /etc/security/limits.conf
	else
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在/etc/security/limits.conf文件末尾插入* - rss 10000"
	    echo '* - rss 10000'|tee -a /etc/security/limits.conf 1>/dev/null
	fi
        if  grep "^\*" /etc/security/limits.conf|grep " hard"|grep "core"|grep "0"
        then
            echo '* hard core 0'|  tee -a /etc/security/limits.conf
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在/etc/security/limits.conf文件末尾插入* hard core 0"

        fi
	#sudo ulimit -c 0
	#fi
}
#为root用户 rm设置别名
alias_rm(){
    if ! sudo grep "^alias rm" /root/.bashrc >/dev/null 2>&1
	then
	    echo "alias rm='rm -i'"|tee -a /root/.bashrc 1>/dev/null
	fi
}

#1.4.4设置文件缺省权限
set_Files(){
    if ! ls /etc/profile_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/profile为/etc/profile_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/profile  /etc/profile_`date +"%Y%m%d"`.bak
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/profile文件中的umask值为027"
    sed -i 's/umask.*/umask 027/g' /etc/profile
    if ! ls /etc/csh.cshrc_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/csh.cshrc为/etc/csh.cshrc_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/csh.cshrc  /etc/csh.cshrc_`date +"%Y%m%d"`.bak
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/csh.cshrc文件中的umask值为027"
    sed -i 's/umask.*/umask 027/g' /etc/csh.cshrc
	if ! ls /etc/bashrc_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/bashrc为/etc/bashrc_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/bashrc  /etc/bashrc`date +"%Y%m%d"`.bak
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改/etc/bashrc文件中的umask值为027"
    sed -i 's/umask.*/umask 027/g' /etc/bashrc


}

#1.4.5查找未授权的SUID-SGID文件
find_S(){
    if find / -type f -perm -04000 -o -perm -02000 -ls 2>/dev/null|awk '{print $11,$5}'|grep -v root
	then
	    for i in `find / -type f -perm -04000 -o -perm -02000 -ls 2>/dev/null|awk '{print $11,$5}'|grep -v root`
	    do
		    chmod u-s $i -R
		done
	fi
	

}
#安全操作系统加固检查

kernel_reinforce(){
    semanage user -l
    if [ $? -eq 0 ]
    then
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 系统拥有安全的内核"|tee -a precautions_`date +"%Y%m%d"`.log
	    return
    fi
    echo "\033[31m`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 系统内核存在安全问题需要加固,请确认!\033[0m"|tee -a precautions_`date +"%Y%m%d"`.log
    return
}

##########
#网络管理#
##########
#关闭不必要的服务
stop_service(){
    servicesList=(samba)
    for service in ${servicesList[*]}
    do
        sudo systemctl status $service >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
            systemctl stop  $service >/dev/null 2>&1 && systemctl disable $service >/dev/null 2>&1
        fi
    done
}

#2.1.2关闭不必要的系统端口
#stop_ports(){

#}

#禁止icmp重定向
#2.1.4启用SYN攻击保护
off_icmp(){
    #if ! cat /etc/sysctl.conf |grep "^net.ipv4.conf.all.accept_redirects" >/dev/null 2>&1
    #then
    if ! ls /etc/sysctl.conf_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/sysctl.conf为/etc/sysctl.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/sysctl.conf /etc/sysctl.conf_`date +"%Y%m%d"`.bak 
    fi
    if ! cat /etc/sysctl.conf |grep "^net.ipv4.conf.all.accept_redirects" >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/sysctl.conf中添加net.ipv4.conf.all.accept_redirects = 0"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "net.ipv4.conf.all.accept_redirects = 0"|tee -a /etc/sysctl.conf 1>/dev/null
	return
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/sysctl.conf中net.ipv4.conf.all.accept_redirects 的值改为 0"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/net.ipv4.conf.all.accept_redirects.*/net.ipv4.conf.all.accept_redirects = 0/g" /etc/sysctl.conf
if ! cat /etc/sysctl.conf |grep "^net.ipv4.conf.all.send_redirects" >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/sysctl.conf中添加net.ipv4.conf.all.send_redirects = 0"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "net.ipv4.conf.all.send_redirects = 0"| tee -a /etc/sysctl.conf 1>/dev/null
    return
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/sysctl.conf中net.ipv4.conf.all.send_redirects 的值改为 0"|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/net.ipv4.conf.all.send_redirects.*/net.ipv4.conf.all.send_redirects = 0/g" /etc/sysctl.conf
}

#2.1.4启用SYN攻击保护
start_SYN(){
    if ! ls /etc/sysctl.conf_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/sysctl.conf为/etc/sysctl.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/sysctl.conf /etc/sysctl.conf_`date +"%Y%m%d"`.bak
    fi
    if ! cat /etc/sysctl.conf |grep "^net.ipv4.tcp_syncookies" >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/sysctl.conf中添加net.ipv4.tcp_syncookies = 1"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "net.ipv4.tcp_syncookies = 1"|tee -a /etc/sysctl.conf 1>/dev/null
        return
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/sysctl.conf中net.ipv4.tcp_syncookies的值改为 1 "|tee -a precautions_`date +"%Y%m%d"`.log
    sed -i "s/^net.ipv4.tcp_syncookies.*/net.ipv4.tcp_syncookies = 1/g" /etc/sysctl.conf
}

#禁止ip源路由
off_IpRoute(){
    if ! ls /etc/sysctl.conf_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/sysctl.conf为/etc/sysctl.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/sysctl.conf /etc/sysctl.conf_`date +"%Y%m%d"`.bak
    fi
    if ! cat /etc/sysctl.conf |grep "^net.ipv4.conf.all.accept_source_route" >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/sysctl.conf中添加net.ipv4.conf.all.accept_source_route = 0"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "net.ipv4.conf.all.accept_source_route = 0"|tee -a /etc/sysctl.conf 1>/dev/null
        return
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/sysctl.conf中net.ipv4.conf.all.accept_source_route 的值改为 0"|tee -a precautions_`date +"%Y%m%d"`.log 
    sed -i "s/^net.ipv4.conf.all.accept_source_route.*/net.ipv4.conf.all.accept_source_route = 0/g" /etc/sysctl.conf
}

#2.1.6禁止ip路由转发
off_IpRouteTransmit(){
    if ! ls /etc/sysctl.conf_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/sysctl.conf为/etc/sysctl.conf_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
        \cp /etc/sysctl.conf /etc/sysctl.conf_`date +"%Y%m%d"`.bak
    fi
    if ! cat /etc/sysctl.conf |grep "^net.ipv4.ip_forward" >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/sysctl.conf中添加net.ipv4.ip_forward = 0"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "net.ipv4.ip_forward = 0"|tee -a /etc/sysctl.conf 1>/dev/null
        return
    fi
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 将文件/etc/sysctl.conf中net.ipv4.ip_forward 的值改为 0"|tee -a precautions_`date +"%Y%m%d"`.log
	sed -i "s/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 0/g" /etc/sysctl.conf

}

#2.1.7配置NTP
#set_NTP(){
    

#}

#2.1.8配置NFS服务限制
stop_nfs(){

   systemctl stop nfs && systemctl disable nfs
}

#2.2.1配置防火墙规则
get_Iptables(){
    systemctl enable firewalld && systemctl restart firewalld

    for TcpPort in ${TcpPorts[*]}
    do
        port_status=` firewall-cmd --query-port=${TcpPort}/tcp`
        if [ $port_status == 'no' ]
        then
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 添加TCP端口:${TcpPort}到防火墙"|tee -a precautions_`date +"%Y%m%d"`.log
            firewall-cmd --add-port=${TcpPort}/tcp --permanent
        fi
    done
    for UdpPort in ${UdpPorts[*]}
    do
        port_status=` firewall-cmd --query-port=${UdpPort}/udp`
        if [ $port_status == 'no' ]
        then
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 添加UDP端口:${UdpPort}到防火墙"|tee -a precautions_`date +"%Y%m%d"`.log
            firewall-cmd --add-port=${UdpPort}/udp --permanent
        fi
    done
    systemctl restart firewalld
}

##########
#接口管理#
##########

#3.1.1禁用USB存储设备
off_usb(){
    mv /lib/modules/`uname -r`/kernel/drivers/usb/storage/usb-storage.ko*  /opt >/dev/null 2>&1
    #sudo rmmod uas
    #sudo rmmod usb_storage
}

#3.1.2禁用光驱存储设备
off_CD(){
    mv /usr/lib/modules/`uname -r`/kernel/drivers/scsi/sr_mod.ko*  /opt/ >/dev/null 2>&1
    #sudo rmmod sr_mod
}

##########
#远程登录#
##########
#限制远程登录的IP
limited_sshLogin(){
     
    if ! sudo grep -e "^sshd: 10.0.0.,172.16.16.,172.16.160.\|^sshd: 192.168.0.\|^sshd:127.0.0.1" /etc/hosts.allow >/dev/null 2>&1
    then
	if ! ls /etc/hosts.allow_`date +"%Y%m%d"`.bak >/dev/null 2>&1
        then
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/hosts.allow为/etc/hosts.allow_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
            \cp /etc/hosts.allow /etc/hosts.allow_`date +"%Y%m%d"`.bak
	fi
        echo -e "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/hosts.allow中添加sshd: 10.0.0.,172.16.16.,172.16.160.\nsshd: 192.168.0.\nsshd:127.0.0.1"|tee -a precautions_`date +"%Y%m%d"`.log
        echo -e "sshd: 10.0.0.,172.16.16.,172.16.160.\nsshd: 192.168.0.\nsshd:127.0.0.1" |tee -a /etc/hosts.allow 1>/dev/null
    fi
#    if ! sudo grep "^sshd: all" /etc/hosts.deny >/dev/null 2>&1
#	then
#	    if ! ls /etc/hosts.deny_`date +"%Y%m%d"`.bak >/dev/null 2>&1
#        then
#		echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件/etc/hosts.deny为/etc/hosts.deny_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
#		\cp /etc/hosts.deny /etc/hosts.deny_`date +"%Y%m%d"`.bak
#	    fi
#	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/hosts.deny中添加sshd: all"|tee -a precautions_`date +"%Y%m%d"`.log
	    #echo -e "sshd: all"|tee -a /etc/hosts.deny 1>/dev/null
#    fi
}

#限制root用户远程登录
limited_rootLogin(){
    if ! ls /etc/ssh/sshd_config_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件 /etc/ssh/sshd_config为/etc/ssh/sshd_config_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	sudo \cp /etc/ssh/sshd_config /etc/ssh/sshd_config_`date +"%Y%m%d"`.bak
    fi
    if sudo cat /etc/ssh/sshd_config|grep ^PermitRootLogin >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的PermitRootLogin值为no"|tee -a precautions_`date +"%Y%m%d"`.log
        sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/g' /etc/ssh/sshd_config
	return
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加PermitRootLogin值为no"|tee -a precautions_`date +"%Y%m%d"`.log
    echo "PermitRootLogin no"|sudo tee -a /etc/ssh/sshd_config 1>/dev/null
}

#限制远程登录超时时间
limited_sshTimout(){
    if ! grep -i "TMOUT" /etc/profile >/dev/null 2>&1
    then
	if ! ls /etc/profile_`date +"%Y%m%d"`.bak >/dev/null 2>&1
	then 
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件 cp /etc/profile为/etc/profile_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	    cp /etc/profile /etc/profile_`date +"%Y%m%d"`.bak
	fi
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/etc/profile中添加export TMOUT=600"|tee -a precautions_`date +"%Y%m%d"`.log
	echo "export TMOUT=600" |tee -a /etc/profile 1>/dev/null
    fi
}

#3.2.4主机间登录禁止使用公钥验证
limited_loginKey(){
    if ! ls /etc/ssh/sshd_config_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件 /etc/ssh/sshd_config为/etc/ssh/sshd_config_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	\cp /etc/ssh/sshd_config /etc/ssh/sshd_config_`date +"%Y%m%d"`.bak
    fi
    if grep -e "^RSAAuthentication"  /etc/ssh/sshd_config >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的RSAAuthentication值为no"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i 's/^RSAAuthentication.*/RSAAuthentication no/g' /etc/ssh/sshd_config
    else
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加RSAAuthentication值为no"|tee -a precautions_`date +"%Y%m%d"`.log
	echo "RSAAuthentication no"|tee -a /etc/ssh/sshd_config 1>/dev/null
    fi
    if grep -e "^PubkeyAuthentication"  /etc/ssh/sshd_config >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的PubkeyAuthentication值为no"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication no/g' /etc/ssh/sshd_config
    else
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加PubkeyAuthentication值为no"|tee -a precautions_`date +"%Y%m%d"`.log
	echo "PubkeyAuthentication no"|tee -a /etc/ssh/sshd_config 1>/dev/null
    fi
}
#3.2.5修改SSH的Banner信息
set_sshBanner(){
    if ! ls /etc/ssh/sshd_config_`date +"%Y%m%d"`.bak >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 备份文件 /etc/ssh/sshd_config为/etc/ssh/sshd_config_`date +"%Y%m%d"`.bak"|tee -a precautions_`date +"%Y%m%d"`.log
	\cp /etc/ssh/sshd_config /etc/ssh/sshd_config_`date +"%Y%m%d"`.bak
    fi
    if grep -e "^Banner"  /etc/ssh/sshd_config >/dev/null 2>&1
    then
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的Banner值为none"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i 's/^Banner.*/Banner none/g' /etc/ssh/sshd_config
    else
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加Banner值为none"|tee -a precautions_`date +"%Y%m%d"`.log
	echo "Banner none"|tee -a /etc/ssh/sshd_config 1>/dev/null
    fi
    if grep -e "^PermitEmptyPasswords"  /etc/ssh/sshd_config >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的PermitEmptyPasswords值为no"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i 's/^PermitEmptyPasswords.*/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
    else
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加PermitEmptyPasswords值为no"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "PermitEmptyPasswords no"|tee -a /etc/ssh/sshd_config 1>/dev/null
    fi
    if grep -e "^MaxAuthTries"  /etc/ssh/sshd_config >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的MaxAuthTries值为4"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i 's/^MaxAuthTries.*/MaxAuthTries 4/g' /etc/ssh/sshd_config
    else
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加MaxAuthTries值为4"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "MaxAuthTries 4"|tee -a /etc/ssh/sshd_config 1>/dev/null
    fi
    if grep -e "^LoginGraceTime"  /etc/ssh/sshd_config >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改文件/etc/ssh/sshd_config中的LoginGraceTime值为60"|tee -a precautions_`date +"%Y%m%d"`.log
        sed -i 's/^LoginGraceTime.*/LoginGraceTime 60/g' /etc/ssh/sshd_config
    else
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 在文件/etc/ssh/sshd_config中添加LoginGraceTime值为60"|tee -a precautions_`date +"%Y%m%d"`.log
        echo "LoginGraceTime 60"|tee -a /etc/ssh/sshd_config 1>/dev/null
    fi
}
##############
#4.日志与审计#
##############


#4.1配置日志策略
set_log(){
   
    auditdStatus=`service auditd status 2>/dev/null|grep Active|awk '{print $3}'`
    if [ $auditdStatus != '(running)' ]
	then
	    service auditd start
	fi
	if ! grep "$1" /etc/audit/audit.rules
	then
	    return
	fi
	if ! ls /etc/audit/audit.rules_`date +"%Y%m%d"`.bak >/dev/null 2>&1
	then
	    \cp /etc/audit/audit.rules /etc/audit/audit.rules_`date +"%Y%m%d"`.bak
	fi
	echo "-w $1 -p wxa -k file_monitor"|tee -a /etc/audit/audit.rules
	service auditd restart	
}

#日志配置文件大小
set_logSize(){
    if ls /etc/logrotate.d/audit >/dev/null 2>&1
    then
	   mv /etc/logrotate.d/audit /etc/logrotate.d/audit_`date +"%Y%m%d"`.bak
    fi
	cat >/etc/logrotate.d/audit <<EOF
	 /var/log/audit/audit.log {
          compress
          delaycompress
          notifempty
          daily
          rotate 60
          size  60M
}
EOF
}

#################
#5.agent探针配置#
#################
set_agent(){

   echo "no"
}

#########################
#6.配置umask 022#
#########################
set_umask(){
if  grep -q '#umask' /home/data/WindCore/startup.sh ;then
      sed -i 's/#umask/umask/' /home/data/WindCore/startup.sh
   elif ! grep -q 'umask 022' /home/data/WindCore/startup.sh ;then
      sed -i '2i\umask 022' /home/data/WindCore/startup.sh
fi

find /home/data/WindManagerBS -name "startup.sh" >/dev/null 2>&1
if [ $? == 0 ]; then
    if  grep -q '#umask' /home/data/WindManagerBS/startup.sh ;then
        sed -i 's/#umask/umask/' /home/data/WindManagerBS/startup.sh
       elif ! grep -q 'umask 022' /home/data/WindManagerBS/startup.sh ;then
          sed -i '2i\umask 022' /home/data/WindManagerBS/startup.sh
    fi
fi

find /home/data/WindSeer -name "startup.sh" >/dev/null 2>&1
if [ $? == 0 ]; then
    if  grep -q '#umask' /home/data/WindSeer/startup.sh ;then
        sed -i 's/#umask/umask/' /home/data/WindSeer/startup.sh
        elif ! grep -q 'umask 022' /home/data/WindSeer/startup.sh ;then
          sed -i '2i\umask 022' /home/data/WindSeer/startup.sh
    fi
fi

find /home/data/WindSine -name "startup.sh" >/dev/null 2>&1
if [ $? == 0 ]; then
    if  grep -q '#umask' /home/data/WindSine/startup.sh ;then
        sed -i 's/#umask/umask/' /home/data/WindSine/startup.sh
       elif ! grep -q 'umask 022' /home/data/WindSine/startup.sh ;then
          sed -i '2i\umask 022' /home/data/WindSine/startup.sh
    fi
fi
}

#root用户环境变量的安全性
root_ENV(){
    echo $PATH|tee -a precautions_`date +"%Y%m%d"`.log
	if echo $PATH|awk -F ":" '{for(i=1;i<=NF;i++){print $i;}}'|grep -e "\./\|\.\./"
    then
	    echo "\033[31mroot`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 用户的环境变量中存在相对路径，请确认！\033[0m"|tee -a precautions_`date +"%Y%m%d"`.log 
	fi
}
main(){
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止匿名VSFTP用户登录"|tee -a precautions_`date +"%Y%m%d"`.log
    check_Vsftp
    # echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 删除无关用户"|tee -a precautions_`date +"%Y%m%d"`.log
    # del_User
        #1.1.1删除或禁用系统无关用户
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 删除或禁用系统无关用户"|tee -a precautions_`date +"%Y%m%d"`.log
	drop_UnusedUser
	#1.1.2开启屏幕保护程序(方法待定)
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止root用户远程telnet登录"|tee -a precautions_`date +"%Y%m%d"`.log
    check_telnet
        #open_ScreenProtect
        #1.1.3安全用户查看
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 安全用户查看"|tee -a precautions_`date +"%Y%m%d"`.log
    check_User
	#1.1.4系统重要数据访问控制（方法待定）
        #set_FileAuthority
	#1.1.5禁止wheel组之外的用户su为root
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止wheel组之外的用户su为root"|tee -a precautions_`date +"%Y%m%d"`.log
	ban_Su
	#1.1.6root用户环境变量的安全性
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 用户环境变量的安全性"|tee -a precautions_`date +"%Y%m%d"`.log
	root_ENV
	#1.1.7避免系统存在相同UID的用户账号（方法待定）
        #1.1.8禁止存在空密码的帐户
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止存在空密码的帐户"|tee -a precautions_`date +"%Y%m%d"`.log
	ban_User
	#1.2.1用户口令复杂度策略
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 用户口令复杂度策略"|tee -a precautions_`date +"%Y%m%d"`.log
    passwd_rule
	#1.2.2用户登录失败锁定
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 用户登录失败锁定"|tee -a precautions_`date +"%Y%m%d"`.log
    login_failed
	#1.2.3用户口令
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 用户口令加固"|tee -a precautions_`date +"%Y%m%d"`.log
    passwd_Deadline
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 删除.rhosts 文件"|tee -a precautions_`date +"%Y%m%d"`.log
    check_rhosts "find / -maxdepth 3 -name .rhosts"
    check_rhosts "find / -maxdepth 3 -name .netrc"
    check_rhosts "find / -maxdepth 3 -name hosts.equiv"
    #echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止root登录VSFTP"|tee -a precautions_`date +"%Y%m%d"`.log
    #check_rootLoginVsftp
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 历史命令配置策略"|tee -a precautions_`date +"%Y%m%d"`.log
    history_strategy
    #echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 关闭IP伪装和绑定多IP功能"|tee -a precautions_`date +"%Y%m%d"`.log
    #stop_VIP
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 别名文件/etc/aliase（或/etc/mail/aliases）配置策略"|tee -a precautions_`date +"%Y%m%d"`.log
    set_aliases
	#1.3.1操作系统补丁更新（方法待定）
	#1.4.1修改核心转储core dump状态 1.4.2限制用户对资源的使用
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改核心转储core dump状态、限制用户对资源的使用"|tee -a precautions_`date +"%Y%m%d"`.log
    core_dump
	#1.4.3为root用户 rm设置别名(方法待定)
	#1.4.4设置文件缺省权限
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 设置文件缺省权限"|tee -a precautions_`date +"%Y%m%d"`.log
    set_Files
	#1.4.5查找未授权的SUID-SGID文件
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 查找未授权的SUID-SGID文件"|tee -a precautions_`date +"%Y%m%d"`.log
	find_S
	#1.4.6安全操作系统加固检查
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 安全操作系统加固检查"|tee -a precautions_`date +"%Y%m%d"`.log
    kernel_reinforce
	#1.5.1卸载无关软件（方法待定）
	#2.1.1关闭不必要的服务(方法待定)
	# stop_service
	#2.1.2关闭不必要的系统端口（方法待定）
	#stop_ports
	#2.1.3禁止icmp重定向
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止icmp重定向"|tee -a precautions_`date +"%Y%m%d"`.log
    off_icmp
	#2.1.4启用SYN攻击保护
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 启用SYN攻击保护"|tee -a precautions_`date +"%Y%m%d"`.log
    start_SYN
	#2.1.5禁止ip源路由
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止ip源路由"|tee -a precautions_`date +"%Y%m%d"`.log
    off_IpRoute
	#2.1.6禁止ip路由转发
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁止ip路由转发"|tee -a precautions_`date +"%Y%m%d"`.log
    off_IpRouteTransmit
	#2.1.7配置NTP（无NTP）
	#2.1.8配置NFS服务限制（目前是禁用）
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 配置NFS服务限制"|tee -a precautions_`date +"%Y%m%d"`.log
    stop_nfs
	#2.2.1配置防火墙规则（开启防火墙）
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 配置防火墙规则"|tee -a precautions_`date +"%Y%m%d"`.log
    get_Iptables
	#3.1.1禁用USB存储设备
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁用USB存储设备"|tee -a precautions_`date +"%Y%m%d"`.log
    off_usb
	#3.1.2禁用光驱存储设备
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 禁用光驱存储设备"|tee -a precautions_`date +"%Y%m%d"`.log
    off_CD
	#3.2.1限制远程登录的IP
	#echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 限制远程登录的IP"|tee -a precautions_`date +"%Y%m%d"`.log
        #limited_sshLogin
	#3.2.2限制root用户远程登录
	#echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 限制root用户远程登录"|tee -a precautions_`date +"%Y%m%d"`.log
    #    limited_rootLogin
	#3.2.3限制远程登录超时时间
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 限制远程登录超时时间"|tee -a precautions_`date +"%Y%m%d"`.log
    limited_sshTimout
	#3.2.4主机间登录禁止使用公钥验证
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 主机间登录禁止使用公钥验证"|tee -a precautions_`date +"%Y%m%d"`.log
    limited_loginKey
	#3.2.5修改SSH的Banner信息
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 修改SSH的Banner信息"|tee -a precautions_`date +"%Y%m%d"`.log
    set_sshBanner
	#4.1配置日志策略（$1代表被审计文件，需要配置）
    set_rsyslog
	#set_log $1
	    set_log "/var/log/boot.log"
		set_log "/var/log/cron"
		set_log "/var/log/firewalld"
		set_log "/var/log/lastlog"
		set_log "/var/log/memory.log"
		set_log "/var/log/messages"
		set_log "/var/log/secure"
	#4.2配置日志文件大小
	echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 配置日志文件大小"|tee -a precautions_`date +"%Y%m%d"`.log
	set_logSize
	#5.1agent探针配置（无）
        
    #6.WindCore配置umask 022
    # set_umask
    # echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:配置软件umask"
	setup_passwd
	# set_windcore
    # set_tomcat
	# set_restart-tomcat_sh
	# create_group
	# set_service_config
	end
	#mv .bashrc .bashrc__`date +"%Y%m%d"`.bak
	chmod 777 /home/data/
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 请重启主机"
}
backup_config
main
