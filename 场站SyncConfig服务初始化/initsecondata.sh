#!/bin/bash
#技术中心@白万进
#风电场数据传输

#配置文件路径
SyncoveryCfg='SyncConfig.csv'


###################################PLC到SCADA#######################################
#控制器PLC日志文件路径
#PLCTraplog=
#PLCStatuslog=
#PLC5Secondslog=
#scada存放控制器PLC日志文件路径
#PLC_SCADATraplog=
#PLC_SCADAStatuslog=
#PLC_SCADA5Secondslog=
#同步规则
# SyncTraplogRule=
# SyncStatuslogRule=
# Sync5SecondslogRule=
##################################SCADA到其他区########################################
#SCADA目标日志文件路径
PLClog="/home/data"
#秒级数据存放路径
SecondsData="/home/data/HisDataLog"
#十秒级数据存放路径
TenSecondsData=
#文件传输路径
TransferPLClog="/home/data/LogTrans"
TransferSecondsData="/home/data/HisDataLogTrans"
TransferTenSecondsData=
#同步规则
#注意：控制器日志和秒级数据不能删除
#控制器日志每天3-5次
SyncPLClog=
#秒级数据传输前一天的
SyncSecondsData=
#十秒级数据，传输十秒以前的
SyncTenSecondsData=
#主SCADA服务器
SCADAmianIP='10.200.200.200'
SCADAmainftpUser='root'
SCADAmainftpPasswd='WindeyXT@2022'
#限速（M）
Speed='0.5'
###################################################################################
WindfarmID=`grep 'WindfarmID,' $WindCoreCfg/Application_HistoryData.csv|awk -F ',' '{print $2}'`
WindfarmID='Windfarm0430'



#环境检测

check_ENV(){

    # if ! test -e $SyncoveryCfg
    # then
    #     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未找到$SyncoveryCfg文件，请确认！"
    #     exit
    # fi
    systemctl status syncoverycl.service >/dev/null 2>&1
    if [[ $? -ne 0 ]]
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未找到syncoverycl.service服务，请安装syncoverycl！"
        exit
    fi 
    syncoveryclStatus=`systemctl status syncoverycl.service |grep Active|awk -F "[()]" '{print $2}'`
    if [[ $syncoveryclStatus != 'running' ]]
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:syncoverycl.service服务状态为$syncoveryclStatus,请确认是否启动，启动命令“systemctl start syncoverycl.service”！"
        exit
    fi
    if ! rpm -qa dos2unix|grep dos2unix >/dev/null 2>&1
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:dos2unix软件未安装！"
        if ! test -e dos2unix-*.rpm
        then
            echo  "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未找到dos2unix安装包！"
            exit
        fi
        echo  "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:正在安装dos2unix"
        rpm -ivh dos2unix-*.rpm
    fi
}

#激活
use_syncovery(){
	echo  '[**REGISTRY**]'  > /etc/.Syncovery/Syncovery.ini
	echo  'RegNameV8=Zhejiang Windey Co.,Ltd.'  >> /etc/.Syncovery/Syncovery.ini
	echo  'RegCodeV8=!CEDQC3NRDIRFK476'  >> /etc/.Syncovery/Syncovery.ini
	systemctl restart  syncoverycl.service
}

HisDataLogtoHisDataLogTrans(){
    if grep HisDataLogTrans SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务HisDataLogTrans。"
        SyncoveryCL DELETE HisDataLogTrans
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除HisDataLogTrans任务。"
    fi
    if ! test -d $TransferSecondsData
    then
        mkdir -p $TransferSecondsData
    fi
    SyncoveryCL ADD \
/Name=HisDataLogTrans \
/Left=$SecondsData \
/Right=$TransferSecondsData \
/L2R \
/MoveMode \
/BinComp=bcmNone \
/RecycleDel=No \
/ScanningThreads=30 \
/Excl='*.csv' \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/AlwaysUnattended=yes \
/FilterTimestamps \
/FromDaysOld=1 \
/Sched \
/Rep \
/Orig=02:10:00 \
/HandleMissedJobs=No \
/RunWhenAvailable \
/UseMinimumPause \
/PauseSeconds=5 \
/SecurityFlag=85 \
/SecurityFlag2=32

}



main(){
 
    check_ENV
    use_syncovery
    SyncoveryCL /list > SyncoveryCL_list
    TransferSecondsData="$TransferSecondsData/$WindfarmID"
    HisDataLogtoHisDataLogTrans
}
main