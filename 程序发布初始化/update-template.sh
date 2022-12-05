#!/bin/bash
LOG_FILE=/var/log/update-template.log
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
}

update_ems(){

if test -d '/home/nas/场站系统软件(最新稳定版)/EMS'
then
    newversion=`ls -lt '/home/nas/场站系统软件(最新稳定版)/EMS'|grep EMS-WM*|head -n 1|awk '{print $9}'`
    echo $newversion
    if test -e /home/publish-template/ems3/version
    then 
        version=`cat /home/publish-template/ems3/version`
        if ! echo $version|grep $newversion
        then
            log_info "模板版本不一致"
            mkdir $version
            log_info "备份原有模板为 $version"
            \cp -r /home/publish-template/ems3/  $version
            log_info "清除/home/publish-template/ems3/目录下的windconfig,windstat,windmanager,windmanagerui,windstat目录"
            rm -rf /home/publish-template/ems3/{windconfig,windstat,windmanager,windmanagerui,windstat}
            log_info "将'/home/nas/场站系统软件(最新稳定版)/EMS/'$newversion/目录下的所有文件同步到/home/publish-template/ems3/目录下"
            \cp -r '/home/nas/场站系统软件(最新稳定版)/EMS/'$newversion/{windconfig,windstat,windmanager,windmanagerui,winddump} /home/publish-template/ems3/
            echo  $newversion > /home/publish-template/ems3/version
        else
            log_info "ems版本一致无需变更！"
        return
        fi
    else
        log_error "/home/publish-template/ems3/version文件不存在"
        version=`echo  ems3_\`date +"%Y%m%d%H%M%S"\``
        mkdir $version
        log_info "备份原有模板为 $version"
        \cp -r /home/publish-template/ems3/  $version
        log_info "清除/home/publish-template/ems3/目录下的windconfig,windstat,windmanager,windmanagerui,windstat目录"
        rm -rf /home/publish-template/ems3/{windconfig,windstat,windmanager,windmanagerui,winddump}
        log_info "将'/home/nas/场站系统软件(最新稳定版)/EMS/'$newversion/目录下的所有文件同步到/home/publish-template/ems3/目录下"
        \cp -r '/home/nas/场站系统软件(最新稳定版)/EMS/'$newversion/{windconfig,windstat,windmanager,windmanagerui,winddump} /home/publish-template/ems3/
        echo  $newversion > /home/publish-template/ems3/version
    fi
else
    log_error "'/home/nas/场站系统软件(最新稳定版)/EMS'目录不存在" 
    return
fi

}

update_ems