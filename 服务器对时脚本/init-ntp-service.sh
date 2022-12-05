#!/bin/bash
#配置NTP服务

check(){
    if ! systemctl list-unit-files |grep ntpd.service >/dev/null 2>&1
    then
        echo "未找到ntpd.service服务"
        exit 1
    fi
    # if ! ping -c 3 10.220.195.253|grep received |awk '{print $4}' |grep -v 0 >/dev/null 2>&1
    # then
    #     if ! ping -c 3 10.220.195.254|grep received |awk '{print $4}' |grep -v 0 >/dev/null 2>&1
    #     then
    #         echo "连接ntpd服务端地址10.220.195.253、10.220.195.254失败！"
    #         exit 1
    #     fi
    # fi
}

main(){
    check
    if test -e /etc/ntp.conf
    then
        mv /etc/ntp.conf /etc/ntp.conf_`date +"%Y%m%d%H%M%S"`.bak
    fi
    cat > /etc/ntp.conf <<EOF
driftfile /var/lib/ntp/drift
restrict default nomodify notrap nopeer noquery
restrict 127.0.0.1 
restrict ::1
server 10.220.195.253 iburst
server 10.220.195.254 iburst
fudge 10.220.195.253 stratum 10
fudge 10.220.195.254 stratum 12
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
disable monitor
EOF
    systemctl daemon-reload && systemctl enable ntpd.service && systemctl restart ntpd.service
    sleep 3
    if ! systemctl status ntpd.service|grep Active|grep running
    then
        echo "ntp服务启动异常！"
        exit 1
    else
        echo "ntp服务配置完成，服务启动正常！"
    fi
}

main