#!/bin/bash

#技术中心@白万进
#20220530

#WindMMCS安装路径
WindMMCSPATH='/home/data/windmmcs'
WindDATE=`date +"%Y%m%d%H%M%S"`
DATE=`date +"%Y%m%d%H%M%S"`
LOG_FILE=install-wmmcs-client-$DATE.log
init_VNC(){
    echo "Windey@2022" | vncpasswd -service 1>/dev/null
    /usr/bin/vnclicense -add VKUPN-MTHHC-UDHGS-UWD76-6N36A 1>/dev/null
    systemctl enable vncserver-x11-serviced.service
    systemctl restart vncserver-x11-serviced.service
    sudo firewall-cmd --add-port=5900/tcp --permanent
    sudo firewall-cmd --reload
     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:已完成VNC的激活"|tee -a $LOG_FILE
}

#初始化WindMMCS
init_WindMMCS(){
    #初始化startup.sh
    cat > startup.sh <<EOF
#!/bin/bash
start(){
    cd $WindMMCSPATH && ./windmmcs  --no-sandbox >> /dev/null 2>&1 &
}
start
EOF
    cat > windmmcs.desktop << EOF
#!/usr/bin/env xdg-open
[Desktop Entry]
Encoding=UTF-8
Name=WindViewer3.0
Comment=windmmcs
Exec=$WindMMCSPATH/startup.sh
Icon=$WindMMCSPATH/favicon.ico
Terminal=false
Type=Application
Categories=Application
Name[en_US]=windmmcs
Comment[en_US.UTF-8]=windmmcs
EOF
    chmod +x windmmcs.desktop
    chmod +x startup.sh
}


#安装WindMMCS
install_WindMMCS(){
    if test -d $WindMMCSPATH
    then
        mv $WindMMCSPATH $WindMMCSPATH_$WindDATE.bak
    fi
    mkdir -p $WindMMCSPATH
    if ! test -d ./windmmcs
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [ERROR]:不存在WindMMCS-*文件，安装中断，请确认！"|tee -a $LOG_FILE
        exit
    fi
    \cp -r ./windmmcs/* $WindMMCSPATH
    init_WindMMCS
    chmod +x $WindMMCSPATH/windmmcs
    \cp startup.sh $WindMMCSPATH
    chmod +x $WindMMCSPATH/startup.sh
    \cp windmmcs.desktop /usr/share/applications
    chmod +x /usr/share/applications/windmmcs.desktop
    # if [[ $LANG =~ 'en_US' ]]
    # then
        if test -d ~/Desktop
        then
            \cp windmmcs.desktop ~/Desktop/
            chmod +x ~/Desktop/windmmcs.desktop
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:已完成WindMMCS的安装"|tee -a $LOG_FILE
            # return
        fi
        # echo "`date +"%Y-%m-%d %H:%M:%S"`  [ERROR]:桌面快捷方式设置失败，未在家目录下找到Desktop目录。"|tee -a $LOG_FILE
        # return
    # fi
    # if [[ $LANG =~ 'zh_CN' ]]
    # then
        if test -d ~/桌面
        then
            \cp windmmcs.desktop ~/桌面/
            chmod +x ~/桌面/windmmcs.desktop
            echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:已完成WindMMCS的安装"|tee -a $LOG_FILE
            # return
        fi
        # echo "`date +"%Y-%m-%d %H:%M:%S"`  [ERROR]:桌面快捷方式设置失败，未在家目录下找到Desktop目录。"|tee -a $LOG_FILE
        # return
    # fi
}

install_xtts(){

    if test -d xtts
    then
        if [ ! -d "/data/monitor/voice" ]; then
            mkdir -p /data/monitor/voice
        fi
        chmod 644 /data/monitor/voice
        \cp -r xtts /opt
        \cp -r /opt/xtts/libs/x64/libmsc.so /lib64
        chmod +x /opt/xtts/bin/ -R
        chmod 777 /lib64/libmsc.so
        return
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [ERROR]: 未找到xtts文件！xtts未安装！"|tee -a $LOG_FILE
}

system_setup(){
   sudo gsettings set org.mate.screensaver idle-activation-enabled false
   sudo gsettings set org.mate.power-manager sleep-display-ac 0
   echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 屏幕保护和显示器睡眠已关闭"|tee -a $LOG_FILE
   sudo systemctl stop rpcbind.socket && sudo systemctl stop rpcbind
   sudo systemctl disable rpcbind.socket && sudo systemctl disable rpcbind
   echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: rpcbind服务已禁用"|tee -a $LOG_FILE
}
system_setup
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:正在激活VNC，请稍后... ..."|tee -a $LOG_FILE
init_VNC
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:正在安装xtts，请稍后... ..."|tee -a $LOG_FILE
install_xtts
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:正在安装WindMMCS，请稍后... ..."|tee -a $LOG_FILE
install_WindMMCS



