#!/bin/bash
#源文件夹地址
SOURCE_PATH='/home/data/HisDataLogTrans/Windfarm0401'
#目的文件夹地址
DESTINATION_PATH='/home/data/HisDataLogTrans-backup'
#______________________________________________________________________________________________________________
CrontabList='/etc/crontablist'

#日志文件
LOG_FILE=/var/log/copy_to_tf.log

check(){
    if ! test -d $SOURCE_PATH
    then
        echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m 不存在$SOURCE_PATH目录，请确认！ \033[0m"
        exit 1
    fi
}

cat >copy_to_tf.sh<<EOF
#!/bin/bash
SOURCE_PATH=$SOURCE_PATH
DESTINATION_PATH=$DESTINATION_PATH
CrontabList=$CrontabList
#日志文件
LOG_FILE=$LOG_FILE
###
#log
###
log_info(){
    echo "\`date +"%Y-%m-%d %H:%M:%S"\` [INFO]: \$1"|tee -a \$LOG_FILE
}

log_error(){
    echo -e "\`date +"%Y-%m-%d %H:%M:%S"\` [ERROR]: \\033[31m \$1 \\033[0m"|tee -a \$LOG_FILE
}




check(){
    if ! test -d \$SOURCE_PATH
    then
        log_error "不存在\$SOURCE_PATH目录，请确认！"
        exit 1
    fi
}

main(){
    check
    test -d \$DESTINATION_PATH || mkdir -p \$DESTINATION_PATH
    for file in \`find \$SOURCE_PATH -name "*-*-*" -type d  -mtime 1\`
    do
        log_info "正在压缩文件\$file为\$file.zip"
        zip -v -r \$file.zip \$file
        log_info "将文件\$file.zip拷贝至\$DESTINATION_PATH"
        \\cp \$file.zip \$DESTINATION_PATH
    done
}

main
EOF
check
test -d $CrontabList || mkdir -p $CrontabList
\cp copy_to_tf.sh $CrontabList
chmod +x $CrontabList/copy_to_tf.sh
if ! crontab -l|grep "$CrontabList/copy_to_tf.sh" 
then
   cat >> /var/spool/cron/root <<EOF
10 3 * * *  $CrontabList/copy_to_tf.sh
EOF
else
    echo "$CrontabList/copy_to_tf.sh任务已存在"
fi
echo "执行完成，使用“crontab -l”命令查看$CrontabList/copy_to_tf.sh任务是否存在！"