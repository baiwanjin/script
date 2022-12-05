#!/bin/bash
source /etc/profile
export ARCLOG_PATH=/home/data/hgdb_backup/archive
export BACKUP_PATH=/home/data/hgdb_backup/backup
export PGDATA=/home/data/highgo-see/data
export PGUSER=sysdba                                    #备份用户
export PGDATABASE=wind                                  #备份库
export PGPORT=5866                                      #数据库端口号
export PGPASSWORD=Hg123456% 
DB_BACKUP='/usr/local/db_backup/db_backup'              #工具绝对路径，防止变量未加入该参数
DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=hgdb-restore-$DATE.log

###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  $1 \033[0m"|tee -a $LOG_FILE
}

check(){
    log_info "***************开始恢复数据库，请根据提示完成数据库的恢复。*******************"
    #最近一次全量备份时间点
    #LastFULL=`db_backup show|awk 'NR>3'|grep -n 'FULL'|awk -F ':' '{print $1}'|head -1`
    if [[ -f $BACKUP_PATH/db_backup.ini && -f $BACKUP_PATH/system_identifier && -d $BACKUP_PATH/timeline_history ]]; then
        log_error "db_backup工具初始化校验失败,请确认是否正确安装db_backup工具，并开启定时备份任务！"
        exit 1
    fi
}

main(){
    check
    Result=NO
    while [ ${Result} != 'yes' ]
    do
        read -p "是否关闭数据库[yes|no]:" Result
        if [ ${Result} == 'yes' ]
        then
            pg_ctl stop
            if [ $? -ne 0 ]
            then
	            log_error "数据库关闭异常，请确认！"
                exit 1
            fi
        fi
        if  [ ${Result} == 'no' ]
        then
            log_info "暂时不关闭数据库，程序正常退出。"
            exit 0
        fi
    done
    LastBackup=`$DB_BACKUP show|awk 'NR>3'|head -1|awk -F '  ' '{print $2}'`
    while true
    do  
        read -p "请输入需要恢复的指定时间节点，如'2022-06-28 11:26:42':" RestoreTime
        if ! echo $RestoreTime | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"
        then
            log_error "输入的时间节点:$RestoreTime 格式有误！请重新输入"
            continue 
        fi
        if [[ ${LastBackup} > ${RestoreTime} ]]
        then
            
            log_info "最新一次备份完成时间为${LastBackup}，恢复的时间节点为${RestoreTime}"
            log_info "执行命令 $DB_BACKUP restore --recovery-target-time $RestoreTime"
            log_info "正在恢复数据库，请稍后"
            $DB_BACKUP restore --recovery-target-time "$RestoreTime"
            if [ $? -ne 0 ]
            then
	            log_error "数据恢复异常，请确认！"
                exit 1
            fi
            sleep 10
            pg_ctl start
            if [ $? -ne 0 ]
            then
	            log_error "数据开启异常，请确认！"
                exit 1
            fi
            sleep 5
            log_info "执行命令 psql -U sysdba -d highgo -c \"select pg_wal_replay_resume();\""
            psql -U sysdba -d highgo -c "select pg_wal_replay_resume();"
            if [ $? -ne 0 ]
            then
	            log_error "执行命令 psql -U sysdba -d highgo -c \"select pg_wal_replay_resume();\"异常，请确认"
                exit 1
            fi
            sleep 2
            log_info "数据库已经恢复至${RestoreTime}。"
            exit
        else
            log_error "输入的时间:${RestoreTime}大于最新一次的数据库备份时间:${LastBackup},无法进行数据库恢复，请确认！"
            continue
        fi

    done


}

main
