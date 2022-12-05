#!/bin/bash
#能管3.0更新脚本
#服务更新列表
# SERVICES=(windmanager windmanagerui windstat windconfig winddump)

DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=update_ems3_$DATE.log
#数据文件路径
Data_Path='/home/data'

###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: \033[31m $1 \033[0m"|tee -a $LOG_FILE
}


for dir in *
do
    if test -d $Data_Path/$dir
    then
        systemctl stop $dir
        log_info "检测到$Data_Path目录下存在$dir服务！"
        log_info "将$Data_Path/$dir目录备份为$Data_Path/$dir_$DATE"
        cp $Data_Path/$dir $Data_Path/$dir_$DATE
        log_info "将$dir目录中的所有文件覆盖到$Data_Path/$dir目录中！"
        \cp -rf $dir $Data_Path
        chown :windeyapps -R $Data_Path/$dir
        systemctl restart $dir
    else
        log_error "$Data_Path目录下不存在$dir，请确认！"
    fi

done