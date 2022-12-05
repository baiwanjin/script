#!/bin/bash
#技术中心
#当前脚本只适用于麒麟系统
Url=$PWD

DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=install-smokeping-$DATE.log
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
    if ! test -e installsmkeping.zip
    then
        log_error "该目录下不存在installsmkeping.zip文件"
        echo 1
    fi 
    if test -d /usr/local/echoping
    then
        log_error "/usr/local/目录下存在echoping目录，请确认！"
        exit 1
    fi
    if test -d /usr/local/smokeping
    then
        log_error "/usr/local/目录下存在smokeping目录，请确认！"
        exit 1
    fi
}

install_relyon(){
    cd $Url/installsmkeping/smokepingrely/
    for i in */*
    do 
        rpm -Uvh $i --nodeps  >/dev/null 2>&1
    done
}
install_fping(){
    cd $Url/installsmkeping/
    tar xf fping-4.1.tar.gz
    cd fping-4.1
    ./configure
    make && make install
}
install_echoping(){
    cd $Url/installsmkeping/
    tar xf echoping-6.0.2.tar.gz
    cd echoping-6.0.2
    ./configure --prefix=/usr/local/echoping --with-ssl --without-libidn
    make && make install
}
install_smokeping(){
    cd $Url/installsmkeping/
    tar xf smokeping-2.7.3.tar.gz
    cd smokeping-2.7.3
    ./configure --prefix=/usr/local/smokeping
    /usr/bin/gmake install
}
init_smokeping(){
    cd /usr/local/smokeping/
    mkdir cache data var
    touch /var/log/smokeping.log  
    chown apache:apache cache data var
    chown apache:apache /var/log/smokeping.log  
    chmod 600 /usr/local/smokeping/etc/smokeping_secrets.dist
    cd /usr/local/smokeping/htdocs
    mv smokeping.fcgi.dist smokeping.fcgi
    cd $Url/installsmkeping/
    \cp config /usr/local/smokeping/etc/
    mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
    \cp httpd.conf /etc/httpd/conf/
    echo 'export PATH=/usr/local/smokeping/bin/:$PATH' >> /etc/profile
    source /etc/profile

    chown apache.apache -R /usr/local/smokeping/

  cat > smokeping.service <<-EOF
[Unit]
Description=network project
After=smokeping.service

[Service]
Type=forking 
User=root
Group=apache
ExecStart=/usr/local/smokeping/bin/smokeping --logfile=/var/log/smokeping.log
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=True

[Install]
WantedBy=multi-user.target

EOF
    \cp smokeping.service /usr/lib/systemd/system/
    systemctl daemon-reload && systemctl enable smokeping.service && systemctl start smokeping.service 

}


main(){
    log_info "开始执行install_smokeping.sh脚本... ..."
    log_info '正在检测部署环境... ...'
    check
    log_info '开始部署... ...'
    unzip -o -q installsmkeping.zip
    log_info '正在安装其他依赖组件... ...'
    install_relyon
    log_info '正在安装fping工具... ...'
    install_fping
    log_info '正在安装echoping工具... ...'
    install_echoping
    log_info '正在安装smokeping工具... ...'
    install_smokeping
    log_info '正在配置smokeping工具... ...'
    init_smokeping
    systemctl enable httpd.service  && systemctl start httpd.service 
    log_info '已经完成smokeping工具的安装及配置，请登录“http:127.0.0.1/smokeping”地址查看。'
}