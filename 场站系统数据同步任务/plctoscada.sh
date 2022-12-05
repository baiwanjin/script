#!/bin/bash
current_path=$(cd `dirname $0`; pwd)
cd $current_path
#配置文件路径
SyncoveryCfg='SyncConfig.csv'
#限速
#上传下载速度限制为200K
Speed='500000:500000'
#当前时间戳
DATE=`date +"%Y%m%d"`
#屏蔽文件夹
SyncRule=".temp|FL.*|._gsdata_|.tmp|ST.*"
#并行数
number=10
#超时时间
TimeOut=1800

# CrontabList='/etc/crontablist'
#日志文件

LOG_FILE=/var/log/sync/plc-scada-$DATE.log
LOG_ERROT_FILE=/var/log/sync/plc-scada-error-$DATE.log
test -d /var/log/sync || mkdir -p /var/log/sync

###
#log
###
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
    if ! test -e $SyncoveryCfg
    then
        log_error "未找到配置文件: $SyncoveryCfg"
        exit 1
    fi
    if ! rpm -qa dos2unix|grep dos2unix >/dev/null 2>&1
    then
        log_error "dos2unix软件未安装！"
        exit 1
    fi
}

main(){
    log_info "--------------------------------------------------start-----------------------------------------------------"
    check
    dos2unix $SyncoveryCfg 
    # plcSum=$((`cat SyncConfig.csv|wc -l`-1))
    # plcGroup=$(($plcSum / $number + 1))
    # num=5
    fifofile="/tmp/$$.fifo"
    
    #创建管道文件，以8作为管道符，删除不影响句柄使用
    mkfifo $fifofile
    exec 8<> $fifofile
    rm $fifofile

    #创建for循环使得管道中初始化已存在5行空行
    for i in `seq $number`
    do
        echo "" >&8
    done
    #创建for循环执行语句，通过管道控制最大同时并行进程数，使用完一次管道后再重新写入一次，始终保持管道中有5行可读
    for line in `cat $SyncoveryCfg |awk 'NR>1{print $1}'`
    do
        read -u 8
        {
        Name=`echo $line|awk -F ',' '{print $1}'`
        ftpIP=`echo $line|awk -F ',' '{print $2}'`
        ftpUser=`echo $line|awk -F ',' '{print $3}'`
        ftpPasswd=`echo $line|awk -F ',' '{print $4}'`
        Port=`echo $line|awk -F ',' '{print $5}'`
        TriplogLeft=`echo $line|awk -F ',' '{print $6}'`
        StatuslogLeft=`echo $line|awk -F ',' '{print $7}'`
        FivelogLeft=`echo $line|awk -F ',' '{print $8}'`
        WindfarmID=`echo $line|awk -F ',' '{print $9}'`
        bh=`echo $Name|awk -F 'WINDFARM-MT' '{print $2}'`
        dir=$(printf "%04d\n" $bh)
        ping=`ping -c 3 $ftpIP|grep received |awk '{print $4}'`
        if [ $ping -eq 0 ]
        then
            log_error "未连接到FTP服务端地址: $ftpIP !"
            continue
        fi
        if echo $ftpUser|grep 'anonymous' >/dev/null 2>&1
        then
            string='-a'
        else
            string=''
        fi
        Right="/home/data/$WindfarmID/Wind$dir"
        test -d $Right$TriplogLeft || mkdir -p $Right$TriplogLeft
        cd $Right$TriplogLeft && cd ../
        log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$TriplogLeft 开始同步。"
        timeout $TimeOut lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;mirror -c -x \"$SyncRule\" $TriplogLeft;bye;"
        status=$?
        echo=$status 
        if [[ $status -eq 124 ]]
        then
            log_error "$ftpIP服务端FTP服务不支持批量下载，采用逐个下载模式！"
            ##############################################################################################
            cd $Right$TriplogLeft
            echo '#!/bin/sh' >> TriplogLeft.sh
            echo "timeout $TimeOut lftp $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port <<EOF" >> TriplogLeft.sh
            echo "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speedcd ;cd  $TriplogLeft;" >> TriplogLeft.sh
            for file  in `lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;cd  $TriplogLeft;ls;bye;" |awk '{print $4}'|grep -v -E '*.temp|FL*_.*|_gsdata_|*.tmp|ST*_.*|_gsdata_'`
            do 
                echo "mget -c $file" >> TriplogLeft.sh
                #timeout 10 lftp $ftpUser:"$ftpPasswd"@$ftpIP -e "set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;cd $TriplogLeft; get $file;bye;"
            done
            echo 'bye' >> TriplogLeft.sh
            echo 'EOF' >> TriplogLeft.sh
            sh TriplogLeft.sh
            if [[ $? -ne 0 ]]
            then
                log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$TriplogLeft 目录同步失败。"
            fi
            rm -f TriplogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$TriplogLeft 目录同步成功。"
            ################################################################################################
            test -d $Right$StatuslogLeft || mkdir -p $Right$StatuslogLeft
            cd $Right$StatuslogLeft
            echo '#!/bin/sh' >> StatuslogLeft.sh
            echo "timeout $TimeOut lftp $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port <<EOF" >> StatuslogLeft.sh
            echo "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speedcd ;cd  $StatuslogLeft;" >> StatuslogLeft.sh
            for file  in `lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set ftp:list-options $string;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;cd  $StatuslogLeft;ls;bye;" |awk '{print $4}'|grep -v -E '*.temp|FL*_.*|_gsdata_|*.tmp|ST*_.*|_gsdata_'`
            do 
                echo "mget -c $file" >> StatuslogLeft.sh
                #timeout 10 lftp $ftpUser:"$ftpPasswd"@$ftpIP -e "set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;cd $TriplogLeft; get $file;bye;"
            done
            echo 'bye' >> StatuslogLeft.sh
            echo 'EOF' >> StatuslogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 开始同步。"
            sh StatuslogLeft.sh
            if [[ $? -ne 0 ]]
            then
                log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 目录同步失败。"
            fi
            rm -f StatuslogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 目录同步成功。"
            #####################################################################################################
            test -d $Right$FivelogLeft || mkdir -p $Right$FivelogLeft
            cd $Right$FivelogLeft
            echo '#!/bin/sh' >> FivelogLeft.sh
            echo "timeout $TimeOut lftp $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port <<EOF" >> FivelogLeft.sh
            echo "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speedcd ;cd  $FivelogLeft;" >> FivelogLeft.sh
            for file  in ` lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;cd  $FivelogLeft;ls;bye;" |awk '{print $4}'|grep -v -E '*.temp|FL*_.*|_gsdata_|*.tmp|ST*_.*|_gsdata_'`
            do 
                echo "mget -c $file" >> FivelogLeft.sh
                #timeout 10 lftp $ftpUser:"$ftpPasswd"@$ftpIP -e "set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;cd $TriplogLeft; get $file;bye;"
            done
            echo 'bye' >> FivelogLeft.sh
            echo 'EOF' >> FivelogLeft.sh
            sh FivelogLeft.sh
            if [[ $? -ne 0 ]]
            then
                log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步失败。"
            fi
            rm -f FivelogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步成功。"
            continue
        elif [[ $status -eq 0 ]]
        then
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$TriplogLeft 目录同步成功。"
        else
            log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$TriplogLeft 目录同步失败。"
        fi
        test -d $Right$StatuslogLeft || mkdir -p $Right$StatuslogLeft
        cd $Right$StatuslogLeft && cd ../
        log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 开始同步。"
        timeout $TimeOut lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;mirror -c -x \"$SyncRule\" $StatuslogLeft;bye;"
        status=$?
        if [[ $status -eq 124 ]]
        then
            log_error "$ftpIP服务端FTP服务不支持批量下载，采用逐个下载模式！"
            ################################################################################################
            test -d $Right$StatuslogLeft || mkdir -p $Right$StatuslogLeft
            cd $Right$StatuslogLeft
            echo '#!/bin/sh' >> StatuslogLeft.sh
            echo "timeout $TimeOut lftp $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port <<EOF" >> StatuslogLeft.sh
            echo "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speedcd ;cd $StatuslogLeft" >> StatuslogLeft.sh
            for file  in `lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;cd  $StatuslogLeft;ls;bye;" |awk '{print $4}'|grep -v -E '*.temp|FL*_.*|_gsdata_|*.tmp|ST*_.*|_gsdata_'`
            do 
                echo "mget -c $file" >> StatuslogLeft.sh
                #timeout 10 lftp $ftpUser:"$ftpPasswd"@$ftpIP -e "set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;cd $TriplogLeft; get $file;bye;"
            done
            echo 'bye' >> StatuslogLeft.sh
            echo 'EOF' >> StatuslogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 开始同步。"
            sh StatuslogLeft.sh
            if [[ $? -ne 0 ]]
            then
                log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 目录同步失败。"
            fi
            rm -f StatuslogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 目录同步成功。"
            #####################################################################################################
            test -d $Right$FivelogLeft || mkdir -p $Right$FivelogLeft
            cd $Right$FivelogLeft
            echo '#!/bin/sh' >> FivelogLeft.sh
            echo "timeout $TimeOut lftp $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port <<EOF" >> FivelogLeft.sh
            echo "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speedcd ;cd $FivelogLeft" >> FivelogLeft.sh
            for file  in `lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;cd  $FivelogLeft;ls;bye;" |awk '{print $4}'|grep -v -E '*.temp|FL*_.*|_gsdata_|*.tmp|ST*_.*|_gsdata_'`
            do 
                echo "mget -c $file" >> FivelogLeft.sh
                #timeout 10 lftp $ftpUser:"$ftpPasswd"@$ftpIP -e "set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;cd $TriplogLeft; get $file;bye;"
            done
            echo 'bye' >> FivelogLeft.sh
            echo 'EOF' >> FivelogLeft.sh
            sh FivelogLeft.sh
            if [[ $? -ne 0 ]]
            then
                log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步失败。"
            fi
            rm -f FivelogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步成功。"
            continue
        elif [[ $status -eq 0 ]]
        then
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 目录同步成功。"
            
        else
            log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$StatuslogLeft 目录同步失败"
        fi
        test -d $Right$FivelogLeft || mkdir -p $Right$FivelogLeft
        cd $Right$FivelogLeft && cd ../
        log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 开始同步。"
        timeout $TimeOut lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;mirror -c -x \"$SyncRule\" $FivelogLeft;bye;"
        status=$?
        if [[ $status -eq 124 ]]
        then
            #####################################################################################################
            test -d $Right$FivelogLeft || mkdir -p $Right$FivelogLeft
            cd $Right$FivelogLeft
            echo '#!/bin/sh' >> FivelogLeft.sh
            echo "timeout $TimeOut lftp $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port <<EOF" >> FivelogLeft.sh
            echo "set ftp:list-options $string;set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speedcd ;cd $FivelogLeft" >> FivelogLeft.sh
            for file  in `lftp $ftpUser:"$ftpPasswd"@$ftpIP:$Port -e "set pget:default-n 2;set use-feat no;set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;cd  $FivelogLeft;ls;bye;" |awk '{print $4}'|grep -v -E '*.temp|FL*_.*|_gsdata_|*.tmp|ST*_.*|_gsdata_'`
            do 
                echo "mget -c $file" >> FivelogLeft.sh
                #timeout 10 lftp $ftpUser:"$ftpPasswd"@$ftpIP -e "set net:timeout 10;set net:reconnect-interval-multiplier 1;set net:max-retries 3;set net:reconnect-interval-base 5;set ftp:ssl-allow false;set net:limit-rate $Speed;cd $TriplogLeft; get $file;bye;"
            done
            echo 'bye' >> FivelogLeft.sh
            echo 'EOF' >> FivelogLeft.sh
            sh FivelogLeft.sh
            if [[ $? -ne 0 ]]
            then
                log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步失败。"
            fi
            rm -f FivelogLeft.sh
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步成功。"
            continue
        elif [[ $status -eq 0 ]]
        then
            log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步成功。"
        else
            log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步失败。"
        fi  
        # if [[ $? -ne 0 ]]
        # then
        #     log_error "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步失败。"
        # else
        #     log_info "$Name $ftpUser:\"$ftpPasswd\"@$ftpIP:$Port:$FivelogLeft 目录同步成功。"
        # fi    
        echo >&8
        }&
    done
    wait
    log_info "-----------------------------------------------Over-----------------------------------------------------------"
    
}
main