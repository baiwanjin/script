#!/bin/bash

SCADAPATH="/home/data"
WindCoreCfg="/home/data/WindCore/cfg"
WindfarmID=`grep 'WindfarmID,' $WindCoreCfg/Application_HistoryData.csv|awk -F ',' '{print $2}'`

initBf(){
ftpUser='anonymous'
ftpPasswd='xx@xx'
Port=21
Left="/WEC_Data"

TriplogLeft="$Left/TripLog"
StatuslogLeft="$Left/StatuscodesLog"
FivelogLeft="$Left/Mean"
echo 'Name,ftpIP,ftpUser,ftpPasswd,Port,TriplogLeft,StatuslogLeft,FivelogLeft,WindfarmID' > SyncConfig.csv
for DEVICEID in `grep 'WINDFARM'  $WindCoreCfg/ADSCollect.csv`
do  
    Name=`echo $DEVICEID|awk -F ',' '{print $1}'|awk -F '\' '{print $1}'`-`echo $DEVICEID|awk -F ',' '{print $1}'|awk -F '\' '{print $2}'`
    ftpIP=`echo $DEVICEID|awk -F ',' '{print $2}'`
    echo "$Name,$ftpIP,$ftpUser,$ftpPasswd,$Port,$TriplogLeft,$StatuslogLeft,$FivelogLeft,$WindfarmID" >> SyncConfig.csv
done
}


initMT(){
ftpUser='fred'
ftpPasswd='fish'
Port=21
Left="/Log"

TriplogLeft="$Left/Totlog"
StatuslogLeft="$Left/Stslog"
FivelogLeft="$Left/Fiveminlog"
echo 'Name,ftpIP,ftpUser,ftpPasswd,Port,TriplogLeft,StatuslogLeft,FivelogLeft,WindfarmID' > SyncConfig.csv
for DEVICEID in `grep 'WINDFARM'  $WindCoreCfg/ADSCollect.csv`
do  
    Name=`echo $DEVICEID|awk -F ',' '{print $1}'|awk -F '\' '{print $1}'`-`echo $DEVICEID|awk -F ',' '{print $1}'|awk -F '\' '{print $2}'`
    ftpIP=`echo $DEVICEID|awk -F ',' '{print $2}'`
    echo "$Name,$ftpIP,$ftpUser,$ftpPasswd,$Port,$TriplogLeft,$StatuslogLeft,$FivelogLeft,$WindfarmID" >> SyncConfig.csv
done
}


main(){

    case $1 in
    mt)
        initMT
        echo "SyncConfig.csv配置文件已生成!"
        ;;
    bf)
        initBf
        echo "SyncConfig.csv配置文件已生成!"
        ;;

    *)
        initBf
        echo "SyncConfig.csv配置文件已生成!"
        ;;
    esac
}

main $1