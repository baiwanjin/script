#!/bin/bash

if ! grep /etc/crontablist/setpasswd.sh /var/spool/cron/root 
then
    mkdir -p /etc/crontablist
    cat > /etc/crontablist/setpasswd.sh <<EOF
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

chmod +x /etc/crontablist/setpasswd.sh
fi
sed -i '/setpasswd.sh/d' /var/spool/cron/root
echo '50 23 15 2,4,6,8,10,12 * /etc/crontablist/setpasswd.sh' >> /var/spool/cron/root