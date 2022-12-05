#!/bin/bash

current_path=$(cd `dirname $0`; pwd)
cd $current_path
WindCoreCfg="/home/data/WindCore/cfg"
WindfarmID=`grep 'WindfarmID,' $WindCoreCfg/Application_HistoryData.csv|awk -F ',' '{print $2}'`
# WindfarmID=Windfarm0430
HisDataLogPath="/home/data/HisDataLog/`date -d '1 day ago' +"%Y-%m-%d"`/$WindfarmID"

#二区信息前置机信息
oldMessageHostIP='10.245.5.20'
oldMessageUser='root'
oldMessagePasswd='Sysadm.2020'
oldMessagePlcPath="/home/data/HisDataLogTrans/$WindfarmID/`date -d '1 day ago' +"%Y-%m-%d"`/$WindfarmID"
oldMessageStatus='True'
oldMessageSSHPort='22'

#三区的信息前置机信息
newMessageStatus='False'
newMessagePlcPath="/home/data/HisDataLogTrans/$WindfarmID/`date -d '1 day ago' +"%Y-%m-%d"`/$WindfarmID"

#排除文件
SyncRule="*csv"

DATE=`date +"%Y%m%d"`
# CrontabList='/etc/crontablist'
#日志文件
Speed='2408000:2408000'
LOG_FILE=/var/log/sync/hisdatalog-other-$DATE.log
LOG_ERROT_FILE=/var/log/sync/hisdatalog-other-error-$DATE.log
test -d /var/log/sync || mkdir -p /var/log/sync


startDate=`date -d '1 day ago' +"%Y-%m-%d %H:%M:%S"`
endDate=`date +"%Y-%m-%d %H:%M:%S"`

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
    if ! test -d $WindCoreCfg
    then
        log_error "$WindCoreCfg不存在"
    fi
}

# expect_ssh(){
#     cat > expect_ssh.sh <<-EOF
# #!/usr/bin/expect -f	
# spawn ssh $2@$1
# expect {
# "yes/no" { send "yes\r"; exp_continue}
# "password:" { send "$3\r" }
# }
# EOF
#     chmod +x expect_ssh.sh && ./expect_ssh.sh && rm -f expect_ssh.sh 
# }

# read_user_passwd(){
# 	expect_ssh $1 $2 $3 1>/dev/null
#     sshpass -p $3 ssh $2@$1 ls 1>/dev/null
#     if [ $? -ne 0 ]
#     then
# 	    log_error "$2@$1用户登录失败，请确认！ "
#         exit 1
#     fi
# }


filetoserver(){
    # read_user_passwd $1 $2 $3
    # if test -d $5 >/dev/null 2>&1
    # then
    #     cd $5 >/dev/null 2>&1 || continue
    #     echo '#!/bin/sh' > filelist.sh
    #     echo "sshpass -p \"$3\" ssh $2@$1 \"mkdir -p $4\"">> filelist.sh
    #     echo -n "sshpass -p \"$oldMessagePasswd\" scp -l 16000 " >> filelist.sh
    #     find  $PWD -newermt "$startDate" ! -newermt "$endDate" -type f ! -name "$SyncRule" |awk -F '/' '{print $NF}' >> filelist
    #     num=`wc -l filelist|awk '{print $1}'`
    #     if [ $num -eq 0 ]
    #     then
    #         rm -f filelist.sh filelist
    #         continue
    #     fi
    #     for n in `seq 1 $num`
    #     do
    #         echo -n "\"`sed -n \"$n\"p filelist`\" " >> filelist.sh
    #     done
    #     echo -n "$2@$1:$4" >> filelist.sh
    #     log_info "开始同步日志文件 $4 到 $2@$1:$4"
    #     timeout 600 sh filelist.sh
    #     if [ $? -ne 0 ]
    #     then
    #         log_error "同步日志文件 scp $4 到 $2@$1:$4 失败!"
    #     else
    #         log_info "同步日志文件 $4 到 $2@$1:$4 成功!"
    #     fi
    #     rm -f filelist.sh filelist        
    # fi
    ping=`ping -c 3 $1 |grep received |awk '{print $4}'`
    if [ $ping -eq 0 ]
    then
        log_error "未连接到服务端器地址: $1  !"
        break
    fi
    if ! test -d  $5
    then
        log_error "$5目录不存在"
        break
    fi
    log_info "$2:\"$3\"@$1:$4 开始同步。"
    timeout 1800 lftp -u $2,$3 -p $6 sftp://$1 -e "set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 2;set net:reconnect-interval-base 5;set net:timeout 10;set ftp:ssl-allow false;set net:limit-rate $Speed; mirror -c -R -x \".csv$\" --newer-than=now-1days $5 $4;exit"
    if [[ $? -ne 0 ]]
    then
        log_error "$2:\"$3\"@$1:$4 目录同步失败。"
    else
        log_info "$2:\"$3\"@$1:$4 目录同步成功。"
    fi  
}

filetodir(){
    if test -d $2 >/dev/null 2>&1
    then

        cd $2 >/dev/null 2>&1 || continue
        echo '#!/bin/bash' > filelist.sh
        echo "mkdir -p $1">> filelist.sh
        echo -n "\cp -r " >> filelist.sh
        find  $PWD -newermt "$startDate" ! -newermt "$endDate" -type f ! -name "$SyncRule" |awk -F '/' '{print $NF}' >> filelist
        num=`wc -l filelist|awk '{print $1}'`
        if [ $num -eq 0 ]
        then
            rm -f filelist.sh filelist
            continue
        fi
        for n in `seq 1 $num`
        do
            echo -n "\"`sed -n \"$n\"p filelist`\" " >> filelist.sh
        done
        echo -n "$1" >> filelist.sh
        log_info "开始将 $2 目录同步到 $1"
        timeout 600 sh filelist.sh
        if [ $? -ne 0 ]
        then
            log_error "同步日志文件 cp $2 到 $1 失败!"
        else
            log_info "同步日志文件 $2 到 $1 成功!"
        fi
        rm -f filelist.sh filelist

    fi
}

main(){
    check
    if [ $oldMessageStatus = "True" ]
    then
        filetoserver $oldMessageHostIP $oldMessageUser $oldMessagePasswd $oldMessagePlcPath $HisDataLogPath $oldMessageSSHPort
    fi
    if [ $newMessageStatus = "True" ]
    then
        filetodir $newMessagePlcPath $HisDataLogPath
    fi
}


main