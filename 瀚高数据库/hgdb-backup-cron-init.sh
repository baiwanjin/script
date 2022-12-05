#bin/bash
#注：此脚本暂时不考虑主从模式下的备机备份，只备份主数据库。
export ARCLOG_PATH='/home/data/hgdb_backup/archive'     #归档路径（添加至环境变量）
export BACKUP_PATH='/home/data/hgdb_backup/backup'      #备份路径（添加至环境变量）
export PGUSER=sysdba                                    #备份用户
export PGDATABASE=wind                                  #备份库
export PGPORT=5866                                      #数据库端口号
export PGPASSWORD=Hg123456%                             #数据库密码
export SRVLOG_PATH='/home/data/hgdb_backup/srvlog'      #设置数据库日志路径，需要开启数据库日志备份才有效
DBBACK_HOST=localhost                                   #查询所用IP，通常为localhost
BAK_LOG_PATH='/home/data/hgdb_backup/log'               #设置备份工具日志参数
DB_BACKUP='/usr/local/db_backup/db_backup'              #工具绝对路径，防止变量未加入该参数
DB_LOG_BAK=no                                           #是否开启数据库日志备份，开启为'yes'。
BAK_LOG_DAYS=15                                         #备份工具日志保留天数
BAK_FORWARD=no                                          #备份转发参数,适用于备节点做备份的场景，开启的话设置为'yes'。
HGDATA='/opt/HighGo456-see/data'                        #瀚高数据库数据文件路径
DATE=`date +"%Y%m%d%H%M%S"`
CrontabList='/etc/crontablist'
#日志文件
LOG_FILE=hgdb-backup-cron-init-$DATE.log
#设置哪天进行全备和0级备份；如下设置的意思是：周六全备，周天0级，周一到周五增备
FULL_DAY=6 #周*进行全备
INC0_DAY=7 #周*进行0级备
INC_KEEP=2 #全量备份保留份数
#设置归档清理策略，e表示每次备份后都执行清理，f表示只有全备后才清理。
ARCH_DEL=e #归档清理策略

###################需要设置postgresql.conf文件
#wal_level = 'replica'
#archive_mode = 'on'
#archive_command = 'cp %p /home/data/hgdbbak/archive/%f'

###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]:  $1 \033[0m"|tee -a $LOG_FILE
}

#检测环境
check(){
    if ! test -e db_backup*.rpm && ! test -e postgresql-libs*.rpm && ! test -e hgdb_backup.sh
    then
        log_error '缺少安装文件，请确认!'
        exit 1
    fi
    test -d $ARCLOG_PATH || mkdir -p $ARCLOG_PATH
}

#环境变量注入
set_env(){
    sed -i "s#ARCLOG_PATH=.*#ARCLOG_PATH=$ARCLOG_PATH#g" hgdb_backup.sh
    sed -i "s#BACKUP_PATH=.*#BACKUP_PATH=$BACKUP_PATH#g" hgdb_backup.sh
    sed -i "s#PGUSER=.*#PGUSER=$PGUSER#g" hgdb_backup.sh
    sed -i "s#PGDATABASE=.*#PGDATABASE=$PGDATABASE#g" hgdb_backup.sh
    sed -i "s#PGPORT=.*#PGPORT=$PGPORT#g" hgdb_backup.sh
    sed -i "s#PGPASSWORD=.*#PGPASSWORD=$PGPASSWORD#g" hgdb_backup.sh
    sed -i "s#SRVLOG_PATH=.*#SRVLOG_PATH=$SRVLOG_PATH#g" hgdb_backup.sh
    sed -i "s#DBBACK_HOST=.*#DBBACK_HOST=$DBBACK_HOST#g" hgdb_backup.sh
    sed -i "s#BAK_LOG_PATH=.*#BAK_LOG_PATH=$BAK_LOG_PATH#g" hgdb_backup.sh
    sed -i "s#DB_BACKUP=.*#DB_BACKUP=$DB_BACKUP#g" hgdb_backup.sh
    sed -i "s#DB_LOG_BAK=.*#DB_LOG_BAK=$DB_LOG_BAK#g" hgdb_backup.sh
    sed -i "s#BAK_LOG_DAYS=.*#BAK_LOG_DAYS=$BAK_LOG_DAYS#g" hgdb_backup.sh
    sed -i "s#BAK_FORWARD=.*#BAK_FORWARD=$BAK_FORWARD#g" hgdb_backup.sh
    sed -i "s#FULL_DAY=.*#FULL_DAY=$FULL_DAY#g" hgdb_backup.sh
    sed -i "s#INC0_DAY=.*#INC0_DAY=$INC0_DAY#g" hgdb_backup.sh
    sed -i "s#INC_KEEP=.*#INC_KEEP=$INC_KEEP#g" hgdb_backup.sh
    sed -i "s#ARCH_DEL=.*#ARCH_DEL=$ARCH_DEL#g" hgdb_backup.sh
}

#安装初始化db_backup工具
init_db_backup(){
    if ! rpm -qa|grep db_backup >/dev/null 2>&1
    then
        log_info "db_backup工具未安装，正在安装... ..."        
        if ! rpm -qa|grep postgresql-libs*.rpm >/dev/null 2>&1
        then
            log_info "正在安装postgresql-libs*.rpm... ..."
            rpm -ivh postgresql-libs*.rpm
        fi
        rpm -ivh db_backup*.rpm
    fi 
    if ! grep 'postgres' /etc/passwd >/dev/null 2>&1
    then
        log_info "未检测到postgres用户，创建postgres用户。"
        chattr -i /etc/group
        chattr -i /etc/gshadow
        chattr -i /etc/passwd
        chattr -i /etc/shadow
        useradd postgres
        chattr +i /etc/group
        chattr +i /etc/gshadow
        chattr +i /etc/passwd
        chattr +i /etc/shadow
    fi

    if grep 'ARCLOG_PATH=' /etc/profile >/dev/null 2>&1
    then
        log_info "将文件/etc/profile中的ARCLOG_PATH的值修改为#ARCLOG_PATH=$ARCLOG_PATH"
        sed -i "s#ARCLOG_PATH=.*#ARCLOG_PATH=$ARCLOG_PATH#g" /etc/profile
    else
        log_info "在文件/etc/profile中添加export ARCLOG_PATH=$ARCLOG_PATH"
        echo "export ARCLOG_PATH=$ARCLOG_PATH" >> /etc/profile
    fi

    if grep 'BACKUP_PATH=' /etc/profile >/dev/null 2>&1
    then
        log_info "将文件/etc/profile中的BACKUP_PATH的值修改为#BACKUP_PATH=$BACKUP_PATH"
        sed -i "s#BACKUP_PATH=.*#BACKUP_PATH=$BACKUP_PATH#g" /etc/profile
    else
        log_info "在文件/etc/profile中添加exportBACKUP_PATH=$BACKUP_PATH"
        echo "export BACKUP_PATH=$BACKUP_PATH" >> /etc/profile
    fi

    source /etc/profile
    log_info "将/usr/local/db_backup/db_backup文件拷贝至/usr/bin/目录下"
    \cp /usr/local/db_backup/db_backup /usr/bin/
    log_info "执行db_backup init -B $BACKUP_PATH 命令，进行db_backup初始化"
    db_backup init -B $BACKUP_PATH

}

init_pgconf(){
    conf=('wal_level:replica' 'archive_mode:on' 'archive_command:cp %p '$ARCLOG_PATH'/%f')
    for i in $(seq ${#conf[*]})
    do 
        str=`echo ${conf[i-1]}`
        key=`echo ${str%:*}`
        value=`echo ${str#*:}`
        if grep "^$key =" $HGDATA/postgresql.conf >/dev/null 2>&1
        then
            echo "将$HGDATA/postgresql.conf文件中$key的值修改为$value"
            sed -i "s#^$key =.*#$key = \'$value\'#g" $HGDATA/postgresql.conf
        else
            echo "在文件$HGDATA/postgresql.conf中添加$key = $value"
            echo "$key = '"$value"'" >> $HGDATA/postgresql.conf
        fi
    done
    pg_ctl restart
    sleep 5
    
}

init_crontab(){
    test -d $CrontabList || mkdir -p $CrontabList
    log_info "将文件hgdb_backup.sh以覆盖的形式拷贝至$CrontabList目录下"
    \cp hgdb_backup.sh $CrontabList
    chmod +x $CrontabList/hgdb_backup.sh
    log_info "添加定时任务$CrontabList'/hgdb_backup.sh'"
    crontab -l >/dev/null 2>&1 >> crontabfile
    if ! grep $CrontabList/'hgdb_backup.sh' crontabfile >/dev/null 2>&1;then echo '0 3 * * *  '$CrontabList'/hgdb_backup.sh' >> crontabfile;fi
    crontab crontabfile && rm -f crontabfile
}


main(){
    check
    set_env
    init_db_backup
    init_pgconf
    init_crontab
    log_info "瀚高数据库备份任务已经添加完成，请确认！"
    log_info "正在进行第一次全量备份，请稍后！"
    db_backup backup -b full
    log_info "备份完成，请确认！"
    db_backup show
}

main






