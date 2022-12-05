#!/bin/sh
#技术中心
#20220523@白万进
#1、修改文件名
#2021/09/23 10:11



if [ ! -d "/home/data/WindManagerBS" ];then
   echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未找到WindManagerBS，脚本无法运行。请确认是否已在能管服务器上运行脚本。"
   exit 1
fi
### 查询风场ID编号
# if ! grep "WindfarmID" /home/data/WindCore/cfg/WindfarmID >/dev/null 2>&1
# then
#     echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未找到WindfarmID，脚本无法运行！"
#     exit 1
# fi

#reset_reboot_service
count1=$(ps -ef | grep mongod | grep -v grep | wc -l)
if [ ${count1} -lt 1 ];then
   echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:未检测到MongoDB进程，脚本无法运行。请联系技术人员。"
   exit 1
fi


current_path=$(cd `dirname $0`; pwd)
cd $current_path
Windfarm=`grep WindfarmID /home/data/WindCore/cfg/WindfarmID|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
time3=$(date "+%Y%m%d%H%M%S")
gethostname=$(hostname)
ConfigName="${gethostname}_windfarm$Windfarm""_${time3}"

if [ ! -d "$current_path/$ConfigName" ];then
    mkdir -m 777 $current_path/$ConfigName
else
    chmod 777 $current_path/$ConfigName
fi
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:程序升级所需的现场数据将导出并打包为$ConfigName.zip"
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:开始导出数据......"

rm -f $current_path/$ConfigName/disk_usage.txt
df -h > $current_path/$ConfigName/disk_usage.txt 2>&1
redis-cli -a windey get WM.Version > $current_path/$ConfigName/Version.txt 2>&1

rm -rf $current_path/$ConfigName/WindCore
mkdir -m 777 $current_path/$ConfigName/WindCore
cp -a /home/data/WindCore/cfg $current_path/$ConfigName/WindCore
cp -p /home/data/WindCore/startup.sh $current_path/$ConfigName/WindCore
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场WindCore配置文件已导出！"

rm -rf $current_path/$ConfigName/WindManagerBS
mkdir -m 777 $current_path/$ConfigName/WindManagerBS
cp -p /home/data/WindManagerBS/application.properties $current_path/$ConfigName/WindManagerBS
cp -p /home/data/WindManagerBS/startup.sh $current_path/$ConfigName/WindManagerBS
if [ -f "/home/data/WindManagerBS/application.yml" ];then
   cp -p /home/data/WindManagerBS/application.yml $current_path/$ConfigName/WindManagerBS
fi
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场WindManagerBS配置文件已导出！"

rm -rf $current_path/$ConfigName/WindSeer
mkdir -m 777 $current_path/$ConfigName/WindSeer
cp -p /home/data/WindSeer/application.properties $current_path/$ConfigName/WindSeer
cp -p /home/data/WindSeer/startup.sh $current_path/$ConfigName/WindSeer
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场WindSeer配置文件已导出！"

rm -rf $current_path/$ConfigName/WindSine
if [ -d "/home/data/WindSine" ];then
   mkdir -m 777 $current_path/$ConfigName/WindSine
   cp -p /home/data/WindSine/application.properties $current_path/$ConfigName/WindSine
   cp -p /home/data/WindSine/startup.sh $current_path/$ConfigName/WindSine
   echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场WindSine配置文件已导出！"
fi

rm -rf $current_path/$ConfigName/mongodb-backup
mongodbport=$(netstat -nalp | grep mongod | awk 'NR==1'| awk '{print $4}' | awk '{split($0,a,":");print a[2]}')
mongodump -h 127.0.0.1:$mongodbport -d windmanager -o $current_path/$ConfigName/mongodb-backup
rm -f $current_path/$ConfigName/windfarm0000.json
mongoexport -h 127.0.0.1:$mongodbport -d windmanager -c windfarm0000 -o $current_path/$ConfigName/windfarm0000.json
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:现场MongoDB数据库已备份！"

zip -q -r ./$ConfigName.zip ./$ConfigName
rm -rf $current_path/$ConfigName

echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:程序升级所需的现场数据已全部导出并打包为$ConfigName.zip"
echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:请将名为$ConfigName.zip的压缩包文件发送给技术人员。"
