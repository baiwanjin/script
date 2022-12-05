#!/bin/bash
ConfigList=('/etc/rsyslog.conf' '/etc/vsftpd/vsftpd.conf' '/etc/ftpusers' '/etc/vsftpd/ftpusers' '/etc/profile' '/etc/host.conf' \
'/etc/aliases' '/etc/passwd' '/etc/pam.d/su' '/etc/pam.d/system-auth' '/etc/login.defs' '/etc/security/limits.conf' '/root/.bashrc' \
'/etc/csh.cshrc' '/etc/bashrc' '/etc/sysctl.conf' '/etc/hosts.allow' '/etc/ssh/sshd_config ' '/etc/audit/audit.rules' '/etc/logrotate.d/audit')
restore_config(){
    for i in ${ConfigList[*]}
    do
        if test -e $i
        then
            dir=/etc/config_backup_`date +"%Y%m%d%H%M%S"`${i%/*}
            mkdir -p $dir
            \cp $i $dir
            \cp .$i ${i%/*}
            chmod +r $i
            echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: 还原$i文件夹"
        fi
    done
}
on_CD(){
    if ! ls /opt/sr_mod.ko.* >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未找到sr_mod.ko相关设备文件"
    fi
    sudo mv /opt/sr_mod.ko.* /usr/lib/modules/`uname -r`/kernel/drivers/scsi/
    sudo modprobe -i sr_mod
}
on_usb(){
    if ! ls /opt/usb-storage.ko* >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未找到USB相关设备文件"
    fi
    sudo mv /opt/usb-storage.ko* /lib/modules/`uname -r`/kernel/drivers/usb/storage/
    sudo modprobe -i usb_storage
}
chattr -i /etc/gshadow
chattr -i /etc/passwd
chattr -i /etc/shadow
chattr -i /etc/group
on_CD
on_usb
restore_config