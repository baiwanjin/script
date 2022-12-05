#!/bin/bash
current_path=$(cd `dirname $0`; pwd)
cd $current_path
WindCoreCfg="/home/data/WindCore/cfg"
WindfarmID=`grep 'WindfarmID,' $WindCoreCfg/Application_HistoryData.csv|awk -F ',' '{print $2}'`
#本机信息
# WindfarmID=Windfarm0425
PlcPath='/home/data'
User='root'
Passwd='Sysadm.2020'
Port='22'

#另外需要同步的SCADA服务器IP
SCADAHostIP='10.200.200.200'
SCADAUser='root'
SCADAPasswd='Sysadm.2020'
SCADASSHPort='22'
SCADAStatus="True"
SCADAPlcPath='/home/data'

#二区信息前置机信息
oldMessageHostIP='10.245.5.20'
oldMessageUser='root'
oldMessagePasswd='Sysadm.2020'
oldMessagePlcPath='/home/data/LogTrans'
oldMessageSSHPort='22'
oldMessageStatus='True'
#三区的信息前置机信息
newMessageStatus='False'
newMessagePlcPath='/home/data/LogTrans'

Speed='2408000:2408000'
# startDate=`date -d '1 day ago' +"%Y-%m-%d %H:%M:%S"`
# endDate=`date +"%Y-%m-%d %H:%M:%S"`

# find $PlcPath/$WindfarmID/ -newermt "$startDate" ! -newermt "$endDate" -type f
DATE=`date +"%Y%m%d"`
# CrontabList='/etc/crontablist'
#日志文件

LOG_FILE=/var/log/sync/scadaplc-other-$DATE.log
LOG_ERROT_FILE=/var/log/sync/scadaplc-other-error-$DATE.log
test -d /var/log/sync || mkdir -p /var/log/sync


log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|tee -a $LOG_ERROT_FILE
}

check(){
    if ! lftp --version >/dev/null 2>&1
    then
        log_error "lftp 工具未安装"
        exit 1
    fi
    
}

plctotherserver(){
    ping=`ping -c 3 $1 |grep received |awk '{print $4}'`
    if [ $ping -eq 0 ]
    then
        log_error "未连接到服务端器地址: $1  !"
        break
    fi
    if ! test -d  $PlcPath/$WindfarmID
    then
        log_error "$PlcPath/$WindfarmID目录不存在"
        break
    fi
    log_info "$2:\"$3\"@$1:$4 开始同步。"
    timeout 1800 lftp -u $2,$3 -p $5 sftp://$1 -e "set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 2;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed; mirror -c -R --newer-than=now-1days $PlcPath/$WindfarmID $4/$WindfarmID;exit"
    if [[ $? -ne 0 ]]
    then
        log_error "$2:\"$3\"@$1:$4 目录同步失败。"
    else
        log_info "$2:\"$3\"@$1:$4 目录同步成功。"
    fi  
}

main(){
    check
    if [ $SCADAStatus = "True" ]
    then
        plctotherserver $SCADAHostIP $SCADAUser $SCADAPasswd $SCADAPlcPath $SCADASSHPort
    fi
    if [ $oldMessageStatus = "True" ]
    then
        plctotherserver $oldMessageHostIP $oldMessageUser $oldMessagePasswd $oldMessagePlcPath $oldMessageSSHPort
    fi
    if [ $newMessageStatus = "True" ]
    then
        plctotherserver '127.0.0.1' $User $Passwd $newMessagePlcPath $Port
    fi
}

main

