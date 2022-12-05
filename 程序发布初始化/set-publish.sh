#!/bin/bash

CURRENT=$PWD
#配置文件
CONF='initconf'
#模板目录
PUBLIST_TEMPLATE_PATH='/home/publish-template'
#WindOM模板目录名称
WINDOM_TEMPLATE_PATH="WindOM"
#SCADA模板目录名称
SCADA_TEMPLATE_PATH="scada"
#监控工作站模板目录名称
MONITOR_TEMPLATE_PATH="monitor"
#ems模板目录名称
EMS_TEMPLATE_PATH="ems3"
FILE_NAME=`basename $PWD`
#WindOM模板文件
WINDOM_MODULE_FILES=('images' 'localgetfile' 'workspace')
#SCADA模板文件
SCADA_MODULE_FILES=('automation' 'haogao-yilai-ky3' 'clean-history-data.sh' 'cron-pgsql-init.sh' 'dos2unix-6.0.3-4.ky3.kb1.x86_64.rpm' \
'GenerateConfig.sh' 'hgdb.lic' 'hgdb4.5.6-see-kylin3-x86-64-20210701.rpm' 'installDB.sh' 'installDB_expect.sh' 'install-wmmcs-server.sh' \
'node-v16.15.0-linux-x64.tar' 'root-defend-kylin20220523.sh' 'Wind-Farm-Data-Transmission.sh' 'init-scada-daemon.sh')
#SCADA服务文件夹
SCADA_SERVICE_FILES=('WindBES' 'WindCore' 'WindDP')
#windOM的scada工作目录
SCADA_WORKSPACE="$CURRENT/WindOM/workspace/scada"

#EMS模板文件
EMS_MODULE_FILES=('automation' 'clean-history-data.sh' 'influxdb-2.0.0.x86_64.rpm' 'install-EMS3.sh' 'node-v16.15.0-linux-x64.tar' 'root-defend-kylin20220523.sh' \
'windstat' 'init-ems-daemon.sh' 'windmanagerui' 'windmanager' 'windconfig')
EMS_WORKSPACE="$CURRENT/WindOM/workspace/ems"
# EMS_CONFIG_FILES=('./emsconf/windconfig' './emsconf/windcore' './emsconf/windstat')


#monitor模板文件
MONITOR_MODULE_FILES=('windmmcs' 'xtts' 'install-wmmcs-client.sh' 'root-defend-kylin20220523.sh')
MONITOR_WORKSPACE="$CURRENT/WindOM/workspace/monitor"

DATE=`date +"%Y%m%d%H%M%S"`
#日志文件
LOG_FILE=set-installation-package-$DATE.log


###
#log
###
log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
}
# check_ems_config(){
#     for EMS_CONFIG_FILE in ${EMS_CONFIG_FILES[*]}
#     do
#         if ! test -e $EMS_CONFIG_FILE
#         then
#             log_error "$EMS_CONFIG_FILES文件或目录不存在！"
#             exit 1
#         fi 
#     done 
# }
read_conf(){
    dos2unix $CONF
    WindfarmID=`grep 'WindfarmID=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到WindfarmID的值为$WindfarmID"
    TurbineNumber=`grep 'TurbineNumber=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到TurbineNumber的值为$TurbineNumber"
    AIRDENSITY=`grep 'AIRDENSITY=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到AIRDENSITY的值为$AIRDENSITY"
    Pressure=`grep 'Pressure=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到Pressure的值为$Pressure"
    RatedPower=`grep 'RatedPower=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到RatedPower的值为$RatedPower"
    OffsetPower=`grep 'OffsetPower=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到OffsetPower的值为$OffsetPower"
    MaxWindSpeed=`grep 'MaxWindSpeed=' $CONF|awk -F '=' '{print $2}'`
    log_info "获取到MaxWindSpeed的值为$MaxWindSpeed"
    Type=`grep 'Type=' $CONF|awk -F '=' '{print $2}'`
    log_info  "获取到Type的值为$Type"
}


check_WindOM_template(){
    if ! test -d $PUBLIST_TEMPLATE_PATH/$WINDOM_TEMPLATE_PATH
    then
        log_error "$PUBLIST_TEMPLATE_PATH/$WINDOM_TEMPLATE_PATH文件不存在！"
        exit 1
    fi
    for WINDOM_MODULE_FILE in ${WINDOM_MODULE_FILES[*]}
    do
        if ! test -e $PUBLIST_TEMPLATE_PATH/$WINDOM_TEMPLATE_PATH/$WINDOM_MODULE_FILE
        then
            log_error "$PUBLIST_TEMPLATE_PATH/$WINDOM_TEMPLATE_PATH/$WINDOM_MODULE_FILE文件或目录不存在！"
            exit 1
        fi 
    done
}

chenk_scada_template(){
    
    if ! test -d $PUBLIST_TEMPLATE_PATH/$SCADA_TEMPLATE_PATH
    then
        log_error "$PUBLIST_TEMPLATE_PATH/$SCADA_TEMPLATE_PATH文件不存在！"
        exit 1
    fi
    for SCADA_MODULE_FILE in ${SCADA_MODULE_FILES[*]}
    do
        if ! test -e $PUBLIST_TEMPLATE_PATH/$SCADA_TEMPLATE_PATH/$SCADA_MODULE_FILE
        then
            log_error " 当前目录下不存在服务$PUBLIST_TEMPLATE_PATH/$SCADA_TEMPLATE_PATH/$SCADA_MODULE_FILE包！"
            exit 1
        fi
    done

    for SCADA_SERVICE_FILE in ${SCADA_SERVICE_FILES[*]}
    do
        if ! test -e $PUBLIST_TEMPLATE_PATH/$SCADA_SERVICE_FILE
        then
            log_error " $PUBLIST_TEMPLATE_PATH/$SCADA_SERVICE_FILE文件或目录不存在！"
            exit 1
        fi
    done
    
}

chenk_ems_template(){
    for EMS_MODULE_FILE in ${EMS_MODULE_FILES[*]}
    do
        if ! test -e $PUBLIST_TEMPLATE_PATH/$EMS_TEMPLATE_PATH/$EMS_MODULE_FILE
        then
            log_error " $PUBLIST_TEMPLATE_PATH/$EMS_TEMPLATE_PATH/$EMS_MODULE_FILE文件或目录不存在！"
            exit 1
        fi
    done
}

chenk_monitor_template(){
    for MONITOR_MODULE_FILE in ${MONITOR_MODULE_FILES[*]}
    do
        if ! test -e $PUBLIST_TEMPLATE_PATH/$MONITOR_TEMPLATE_PATH/$MONITOR_MODULE_FILE
        then
            log_error " $PUBLIST_TEMPLATE_PATH/$MONITOR_TEMPLATE_PATH/$MONITOR_MODULE_FILE文件或目录不存在！"
            exit 1
        fi
    done
}

set_scada_installation_package(){
    
    while true
    do
        # read -p "请输入风场编号,如'0409':" WindfarmID
        if ! echo $WindfarmID | grep -E "^[0-9]{4}$" >/dev/null 2>&1
        then
            log_error "风场编号:$WindfarmID 格式有误！"
            exit 1
        fi
        break
    done

    while true
    do
        # read -p "请输入风场风机数量,如'29':" TurbineNumber
        if ! echo $TurbineNumber | grep -E "^[0-9]*[0-9]*$" >/dev/null 2>&1
        then
            log_error "风场风机数量:$TurbineNumber 格式有误！"
            exit 1
        fi
        if [ $TurbineNumber -gt 200 ]
        then
            log_error "风场风机数量:$TurbineNumber 大于200！"
            exit 1
        fi
        break
    done
    # while true
    # do
    #     read -p "请输入空气密度,如'1.22':" AIRDENSITY
    #     break
    # done
    
    # while true
    # do
    #     read -p "请输入气压值(单位百帕),如'902':" Pressure
    #     break
    # done
    log_info "*********************配置SCADA*****************************"
    log_info "拷贝模板文件$PUBLIST_TEMPLATE_PATH/$SCADA_TEMPLATE_PATH到$PWD目录下"
    \cp -r $PUBLIST_TEMPLATE_PATH/$SCADA_TEMPLATE_PATH $PWD
    for SCADA_SERVICE_FILE in ${SCADA_SERVICE_FILES[*]}
    do
        log_info "拷贝模板文件$PUBLIST_TEMPLATE_PATH/$SCADA_SERVICE_FILE到$PWD目录下"
        \cp -r $PUBLIST_TEMPLATE_PATH/$SCADA_SERVICE_FILE $PWD
    done
    log_info "配置初始化，替换需要修改的文件"
    chmod +x init-scada-conf.sh
    if ! test -x ./init-scada-conf.sh
    then
    log_error "./set_scada_conf.sh文件没有执行权限"
    exit 1
    fi
    ./init-scada-conf.sh $TurbineNumber $WindfarmID $AIRDENSITY $Pressure $LOG_FILE
    if [ $? -ne 0 ]
    then
        exit 1
    fi
    log_info "... ..."
    log_info "拷贝服务文件"
    for SCADA_SERVICE_FILE in ${SCADA_SERVICE_FILES[*]}
    do
        log_info "拷贝文件$SCADA_SERVICE_FILE到$SCADA_TEMPLATE_PATH目录中"
        \cp -r $SCADA_SERVICE_FILE  $SCADA_TEMPLATE_PATH
    done
    \cp -r dump-wind-*.backup $SCADA_TEMPLATE_PATH
    log_info "压缩文件$SCADA_TEMPLATE_PATH为$SCADA_TEMPLATE_PATH.zip"
    zip -v -r $SCADA_TEMPLATE_PATH.zip $SCADA_TEMPLATE_PATH
    log_info "拷贝WindOM模板文件"
    \cp -r $PUBLIST_TEMPLATE_PATH/$WINDOM_TEMPLATE_PATH $PWD
    log_info "将SCADA安装包拷贝至WindOM的scada工作目录中"
    \cp -r $SCADA_TEMPLATE_PATH.zip $SCADA_WORKSPACE
   
}

set_ems_installation_package(){
    log_info "*************************配置EMS********************************"
    \cp -r $PUBLIST_TEMPLATE_PATH/$EMS_TEMPLATE_PATH $PWD
    chmod +x init-ems-conf.sh
    if ! test -x ./init-ems-conf.sh
    then
        log_error "./init-ems-config.sh文件没有执行权限"
        exit 1
    fi
    ./init-ems-conf.sh $TurbineNumber $WindfarmID $RatedPower $OffsetPower  `grep 'PowerCurve=' $CONF|awk -F '=' '{print $2}'` $Type $MaxWindSpeed $LOG_FILE
    if [ $? -ne 0 ]
    then
        log_error "./init-ems-conf.sh $TurbineNumber $WindfarmID $RatedPower $OffsetPower  `grep 'PowerCurve=' $CONF|awk -F '=' '{print $2}'` $Type $MaxWindSpeed $LOG_FILE 执行异常"
        exit 1
    fi
    log_info "压缩文件$EMS_TEMPLATE_PATH 为 $EMS_TEMPLATE_PATH.zip"
    zip -v -r $EMS_TEMPLATE_PATH.zip $EMS_TEMPLATE_PATH
    log_info "拷贝文件$EMS_TEMPLATE_PATH.zip 到 $EMS_WORKSPACE目录"
    \cp -r $EMS_TEMPLATE_PATH.zip $EMS_WORKSPACE
}

set_monitor_installation_package(){
    log_info "*********************配置前台监控工作站**************************"
    \cp -r $PUBLIST_TEMPLATE_PATH/$MONITOR_TEMPLATE_PATH $PWD
    log_info "压缩文件 $MONITOR_TEMPLATE_PATH 为 $MONITOR_TEMPLATE_PATH.zip"
    zip -v -r $MONITOR_TEMPLATE_PATH.zip $MONITOR_TEMPLATE_PATH
    log_info "拷贝文件 $MONITOR_TEMPLATE_PATH.zip 到 $MONITOR_WORKSPACE"
    \cp -r  $MONITOR_TEMPLATE_PATH.zip $MONITOR_WORKSPACE
}

main(){
if ! test -e $CONF
then
    log_error "未找到配置文件$CONF"
    exit 1
fi
log_info "开始进行文件检测"
check_WindOM_template
chenk_scada_template
chenk_ems_template
chenk_monitor_template
read_conf
if ! test -e ./init-scada-conf.sh
then
    log_error "不存在./set_scada_conf.sh文件"
    exit 1
fi
if ! test -e ./init-ems-conf.sh
then
    log_error "不存在./set_scada_conf.sh文件"
    exit 1
fi
log_info "文件检测完成"
set_scada_installation_package
set_ems_installation_package
set_monitor_installation_package
log_info "将文件$WINDOM_TEMPLATE_PATH重命名为$FILE_NAME$DATE！"
mv $WINDOM_TEMPLATE_PATH $FILE_NAME$DATE
log_info "压缩文件$FILE_NAME$DATE为$FILE_NAME$DATE.zip ！"
zip -v -r $FILE_NAME$DATE.zip $FILE_NAME$DATE
}
main