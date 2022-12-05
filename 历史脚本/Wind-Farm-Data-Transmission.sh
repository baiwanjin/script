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
Speed='2'
###################################################################################

# SyncoveryCL /list|sed -n '/-->/{g;1!p;};h'|awk '{print $2}'



#环境检测

check_ENV(){

    if ! test -e $SyncoveryCfg
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未找到$SyncoveryCfg文件，请确认！"
        exit
    fi
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

PLCtoSCADA(){
    if grep $Name SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务$Name。"
        SyncoveryCL DELETE $Name
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除$Name任务。"
    fi
    if ! test -d $Right
    then
        mkdir -p $Right
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 创建任务$Name"
    SyncoveryCL ADD \
/Name=$Name \
/Left=ftp://$ftpUser:$ftpPasswd@$ftpIP/ \
/Right=$Right \
/L2R \
/UseSel \
/Sel='"'$FivelogLeft*'","'$StatuslogLeft*'","'$TriplogLeft*'"/' \
/BinComp=bcmNone \
/UseSpeed \
/Speed=$Speed \
/LeftFTPSettings="FTP1:Port=$Port,Passive=Y,ASCII=N,CanRenameFolders=N,AbsolutePath=Y,ForceTimestamps=N,FTPCommand=0,Flags=UTF8+UTC+DetectTimezone+AvoidIPV6,""Proxy=no"",TLS=no,TimZoneOfs=0/0,""Cert=none""" \
/Excl='_gsdata_;FL*_.*;ST*_.*;*.tmp;*.temp' \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/IgnoreFileSymLinks=No \
/IgnoreDirSymLinks=No \
/Sched \
/Rep \
/Orig=01:10:00 \
/SecurityFlag=85 \
/SecurityFlag2=32 \
/NameForDatabase=$Name \
/DBLeftBasePath=ftp://$ftpUser:$ftpPasswd@$ftpIP/ \
/DBRightBasePath=$Right


}
 

#
StatuslogtoSCADA(){
    if grep $Name-Statuslog SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务$Name-Statuslog。"
        SyncoveryCL DELETE $Name-Statuslog
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除$Name-Statuslog任务。"
    fi
    if ! test -d $Right
    then
        mkdir -p $Right
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 创建任务$Name-Statuslog"
    SyncoveryCL ADD \
/Name=$Name-Statuslog \
/Left=ftp://$ftpUser:$ftpPasswd@$ftpIP$StatuslogLeft \
/Right=$Right \
/L2R \
/BinComp=bcmNone \
/DontScanDest \
/MaxParallelCopiers=1 \
/UseSpeed \
/Speed=$Speed \
/LeftFTPSettings="FTP1:Port=$Port,Passive=Y,ASCII=N,CanRenameFolders=N,AbsolutePath=Y,ForceTimestamps=N,FTPCommand=0,Flags=UTF8+UTC+DetectTimezone+AvoidIPV6,""Proxy=no"",TLS=no,TimZoneOfs=0/0,""Cert=none""" \
/ScanningThreads=1 \
/Excl='_gsdata_;FL*_.*;ST*_.*;*.tmp;*.temp' \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/AlwaysUnattended=yes \
/Sched \
/Rep \
/Orig=01:10:00 \
/HandleMissedJobs=No \
/SecurityFlag=85 \
/SecurityFlag2=32 \
/NameForDatabase=$Name \
/DBLeftBasePath=ftp://$ftpUser:$ftpPasswd@$ftpIP$StatuslogLeft \
/DBRightBasePath=$Right
    
}
 
TriplogtoSCADA(){

    if grep $Name-Triplog SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务$Name-Triplog。"
        SyncoveryCL DELETE $Name-Triplog
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除$Name-Triplog任务。"
    fi
    if ! test -d $Right
    then
        mkdir -p $Right
    fi

    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 创建任务$Name-Triplog"
    SyncoveryCL ADD \
/Name=$Name-Triplog \
/Left=ftp://$ftpUser:$ftpPasswd@$ftpIP$TriplogLeft \
/Right=$Right \
/L2R \
/BinComp=bcmNone \
/DontScanDest \
/MaxParallelCopiers=1 \
/UseSpeed \
/Speed=$Speed \
/LeftFTPSettings="FTP1:Port=$Port,Passive=Y,ASCII=N,CanRenameFolders=N,AbsolutePath=Y,ForceTimestamps=N,FTPCommand=0,Flags=UTF8+UTC+DetectTimezone+AvoidIPV6,""Proxy=no"",TLS=no,TimZoneOfs=0/0,""Cert=none""" \
/ScanningThreads=1 \
/Excl='_gsdata_;FL*_.*;ST*_.*;*.tmp;*.temp' \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/AlwaysUnattended=yes \
/Sched \
/Rep \
/Orig=01:20:00 \
/HandleMissedJobs=No \
/SecurityFlag=85 \
/SecurityFlag2=32 \
/NameForDatabase=$Name \
/DBLeftBasePath=ftp://$ftpUser:$ftpPasswd@$ftpIP$TriplogLeft \
/DBRightBasePath=$Right
   
}

FivelogtoSCADA(){
    if grep $Name-Fivelog SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务$Name-Fivelog。"
        SyncoveryCL DELETE $Name-Fivelog
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除$Name-Fivelog任务。"
    fi
    if ! test -d $Right
    then
        mkdir -p $Right
    fi
    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]: 创建任务$Name-Fivelog"
    
    SyncoveryCL ADD \
/Name=$Name-Fivelog \
/Left=ftp://$ftpUser:$ftpPasswd@$ftpIP$FivelogLeft \
/Right=$Right \
/L2R \
/BinComp=bcmNone \
/DontScanDest \
/MaxParallelCopiers=1 \
/UseSpeed \
/Speed=$Speed \
/LeftFTPSettings="FTP1:Port=$Port,Passive=Y,ASCII=N,CanRenameFolders=N,AbsolutePath=Y,ForceTimestamps=N,FTPCommand=0,Flags=UTF8+UTC+DetectTimezone+AvoidIPV6,""Proxy=no"",TLS=no,TimZoneOfs=0/0,""Cert=none""" \
/ScanningThreads=1 \
/Excl='_gsdata_;FL*_.*;ST*_.*;*.tmp;*.temp' \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/AlwaysUnattended=yes \
/Sched \
/Rep \
/Orig=01:30:00 \
/HandleMissedJobs=No \
/SecurityFlag=85 \
/SecurityFlag2=32 \
/NameForDatabase=$Name \
/DBLeftBasePath=ftp://$ftpUser:$ftpPasswd@$ftpIP$FivelogLeft \
/DBRightBasePath=$Right

  
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
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/AlwaysUnattended=yes \
/Sched \
/Rep \
/Orig=02:10:00 \
/Days=0 \
/Hours=6 \
/HandleMissedJobs=No \
/RunWhenAvailable \
/UseMinimumPause \
/PauseSeconds=5 \
/SecurityFlag=85 \
/SecurityFlag2=32

}

PLClogtoLogTrans(){
    if grep LogTrans SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务LogTrans。"
        SyncoveryCL DELETE LogTrans
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除LogTrans任务。"
    fi
    if ! test -d $TransferPLClog
    then
        mkdir -p $TransferPLClog
    fi
    SyncoveryCL ADD \
/Name=LogTrans \
/Left=$PLClog \
/Right=$TransferPLClog \
/L2R \
/MoveMode \
/BinComp=bcmNone \
/RecycleDel=No \
/ScanningThreads=30 \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/AlwaysUnattended=yes \
/Sched \
/Rep \
/Orig=01:10:00 \
/Days=0 \
/Hours=6 \
/HandleMissedJobs=No \
/RunWhenAvailable \
/UseMinimumPause \
/PauseSeconds=5 \
/SecurityFlag=85 \
/SecurityFlag2=32

}


SCADAStandbyPLClogtoSCADAMainPLCLog(){
    if grep ToSCADAMainPLCLog SyncoveryCL_list
    then
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在任务ToSCADAMainPLCLog。"
        SyncoveryCL DELETE ToSCADAMainPLCLog
        echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:清除ToSCADAMainPLCLog任务。"
    fi
    if ! test -d $TransferPLClog
    then
        mkdir -p $TransferPLClog
    fi
    SyncoveryCL ADD \
/Name=ToSCADAMainPLCLog \
/Left=$PLClog \
/Right=sftp://$SCADAmainftpUser:$SCADAmainftpPasswd@$SCADAmianIP$PLClog \
/L2R \
/BinComp=bcmNone \
/DontScanDest \
/MaxParallelCopiers=1 \
/LeftFTPSettings="SFTP:Port=22,AbsolutePath=N,Flags=UTC+DetectTimezone+AvoidIPV6,""Proxy=no"",TimZoneOfs=0/0,""Cert=none"",SSHAuth=[],RecursLst=N" \
/AdvancedSSHSettings=9/YY/8454664191/1048575/137438953471/524287/8192/32768/131072/32/SFTP01234 \
/ScanningThreads=1 \
/Excl='_gsdata_;FL*_.*;ST*_.*;*.tmp;*.temp' \
/FollowFileSymLinks=No \
/FollowDirSymLinks=No \
/Sched \
/Rep \
/Orig=02:10:00 \
/HandleMissedJobs=No \
/SecurityFlag=85 \
/SecurityFlag2=32 \
/NameForDatabase=ToSCADAMainPLCLog \
/DBLeftBasePath=$PLClog \
/DBRightBasePath=sftp://$SCADAmainftpUser:$SCADAmainftpPasswd@$SCADAmianIP$PLClog
 
}


main(){
 
    check_ENV
    use_syncovery
    dos2unix $SyncoveryCfg 
    SyncoveryCL /list > SyncoveryCL_list
    for line in ` cat $SyncoveryCfg |awk 'NR>1{print $1}'`
    do
        Name=`echo $line|awk -F ',' '{print $1}'`
        ftpIP=`echo $line|awk -F ',' '{print $2}'`
        ftpUser=`echo $line|awk -F ',' '{print $3}'`
        ftpPasswd=`echo $line|awk -F ',' '{print $4}'`
        Port=`echo $line|awk -F ',' '{print $5}'`
        TriplogLeft=`echo $line|awk -F ',' '{print $6}'`
        StatuslogLeft=`echo $line|awk -F ',' '{print $7}'`
        FivelogLeft=`echo $line|awk -F ',' '{print $8}'`
        WindfarmID=`echo $line|awk -F ',' '{print $9}'`
        dir=`echo $Name|awk -F 'WINDFARM-MT' '{print $2}'`
        if [ $dir -gt 99 ] 
        then
            dir=0$dir
        elif [ $dir -le 9 ]
        then
            dir=000$dir 
        else
            dir=00$dir
        fi
        Right="/home/data/$WindfarmID/Wind$dir"
        #TriplogtoSCADA
        #StatuslogtoSCADA
        #FivelogtoSCADA
        PLCtoSCADA
    done
    PLClog="$PLClog/$WindfarmID"
    TransferPLClog="$TransferPLClog/$WindfarmID"
    TransferSecondsData="$TransferSecondsData/$WindfarmID"
    HisDataLogtoHisDataLogTrans
    PLClogtoLogTrans
    SCADAStandbyPLClogtoSCADAMainPLCLog
    rm -rf SyncoveryCL_list
    

}
main