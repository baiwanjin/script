#!/bin/bash

# 
WindCoreCfg="/home/data/WindCore/cfg"
CrontabList='/etc/crontablist'

#检测文件
check(){
    filelist=('getConfig.sh' 'hisdatalogto.sh' 'lftp-4.4.8-11.ky3.kb2.x86_64.rpm' 'plcsync.sh' 'plctoscada.sh' 'scadaplctoother.sh' 'syncrun' 'dos2unix-6.0.3-4.ky3.kb1.x86_64.rpm')
    for file in ${filelist[*]}
    do
        if ! test -e $file
        then
            echo "$file文件不存在"
            exit 1
        fi
    done
    if ! grep 'WindfarmID,' $WindCoreCfg/Application_HistoryData.csv|awk -F ',' '{print $2}' >/dev/null 2>&1
    then
        echo "未获取到WindfarmID"
        exit 1
    fi


}

#准备
prepare(){
    #设置
    systemctl stop syncoverycl.service 
    systemctl disable syncoverycl.service
    systemctl mask syncoverycl.service
    systemctl enable crond.service
    systemctl restart crond.service
}

#init

init(){
    check
    prepare
    chmod +x *.sh
    ./getConfig.sh $1
    test -d $CrontabList || mkdir -p $CrontabList
    \cp `ls|grep -v rpm|grep -v update.sh` $CrontabList
    if ! rpm -qa|grep lftp  >/dev/null 2>&1
    then
        rpm -ivh lftp-4.4.8-11.ky3.kb2.x86_64.rpm
    fi
    if ! rpm -qa|grep dos2unix  >/dev/null 2>&1
    then
        rpm -ivh dos2unix-6.0.3-4.ky3.kb1.x86_64.rpm
    fi
    if ! grep $CrontabList'/plcsync.sh' /var/spool/cron/root >/dev/null 2>&1;then echo '10 0 * * * '$CrontabList'/plcsync.sh' >> /var/spool/cron/root;fi
    # if ! grep $CrontabList'/hisdatalogto.sh' /var/spool/cron/root >/dev/null 2>&1;then echo '10 3 * * * '$CrontabList'/hisdatalogto.sh' >> /var/spool/cron/root;fi
    chmod +x $CrontabList/*.sh
    chmod +x $CrontabList/syncrun
    ln -s  $CrontabList/syncrun /usr/bin/syncrun
}

main(){

    case $1 in
    mt)
        init mt
        ;;
    bf)
        init bf
        ;;

    *)
        init bf
        ;;
    esac
}

main $1