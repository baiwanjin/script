#!/bin/bash

#2022/08/12 10:05

current_path=$(cd `dirname $0`; pwd)
cd $current_path

SCADA_Path='/home/data'

#环境检查
runtimeCheck()
{
   if [ ! -f "$current_path/WindCore.zip" ]&&[ ! -d "$current_path/WindCore" ]&&[ ! -f "$current_path/windeybs.zip" ]&&[ ! -d "$current_path/windeybs" ]&&[ ! -f "$current_path/windalarm.sql" ];then
      echo "未在当前目录下找到SCADA相关升级文件，shell脚本无法运行。"
      exit 1
   fi

   mssql_status=`systemctl status mssql-server | grep "active (running)" | wc -l` 
   if [ ${mssql_status} -eq 0 ];then
      echo "检测到SQL Server数据库服务未运行，shell脚本无法运行。请确认是否已在SCADA服务器上运行这个脚本。"
      exit 1
   fi

   count1=$(rpm -qa | grep msodbcsql | wc -l)
   count2=$(rpm -qa | grep mssql-tools | wc -l)
   if [ ${count1} -lt 1 ] || [ ${count2} -lt 1 ];then
      echo "检测到未安装SQL Server数据库工具，shell脚本无法运行。请联系技术人员。"
      exit 1
   fi

   if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' ~/.bash_profile
      then
      echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
   fi
   if ! grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' ~/.bashrc
      then
      echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
   fi

   count_alarm=$(/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "SELECT count(*) FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[windalarm]')  AND type in (N'U')" | awk '{sub(/^[ \t]+/, "")};1'| awk 'NR==3')
   if [ ${count_alarm} -eq 0 ];then
      echo "检测到SCADA数据库中不存在windalarm表，shell脚本无法运行。请联系技术人员！"
      exit 1
   fi

   if [ -f "$current_path/WindCore.zip" ]&&[ ! -d "$current_path/WindCore" ];then
      unzip -q $current_path/WindCore.zip
   fi
   if [ -d "$current_path/WindCore" ];then
      Windfarm=`grep WindfarmID $SCADA_Path/WindCore/cfg/Application_HistoryData.csv|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
      Windfarm1=`grep WindfarmID $current_path/WindCore/cfg/Application_HistoryData.csv|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
      if [ $Windfarm !=  $Windfarm1 ];then
         echo "程序包中的风场编号和服务器中的风场编号不匹配，请确认更新的程序包是否是本风场的程序包！"
         exit 1
      fi
   fi

   cd /home/data
   if [ ! -d "/home/data/SCADA_APP_Backup" ];then
      mkdir -p SCADA_APP_Backup
      mkdir -p SCADA_APP_Backup/WindCore_Backup
      mkdir -p SCADA_APP_Backup/windeybs_Backup
   fi
   chmod 777 /home/data/SCADA_APP_Backup

   if [ ! -d "/home/data/tools" ];then
      mkdir -p tools
   fi
   chmod 777 /home/data/tools
}


#WindCore备份
WindCoreBackup()
{
   cd /home/data
   echo "开始备份现有WindCore..."
   rm -rf /home/data/WindCoreBak
   cp -p -r WindCore WindCoreBak
   rm -f /home/data/WindCoreBak/nohup.out
   zip -q -r /home/data/SCADA_APP_Backup/WindCore_Backup/WindCoreBak-`date +%Y%m%d%H%M%S`.zip WindCoreBak
   rm -rf /home/data/WindCoreBak
   echo "WindCore已备份到/home/data/SCADA_APP_Backup/WindCore_Backup目录下。"
}


#windeybs备份
windeybsBackup()
{
   cd /home/data
   echo "开始备份现有windeybs..."
   rm -rf /home/data/windeybsBak
   cp -p -r windeybs windeybsBak
   zip -q -r /home/data/SCADA_APP_Backup/windeybs_Backup/windeybsBak-`date +%Y%m%d%H%M%S`.zip windeybsBak
   rm -rf /home/data/windeybsBak
   echo "windeybs已备份到/home/data/SCADA_APP_Backup/windeybs_Backup目录下。"
}


#windalarm表更新（不包括WindCore的停止和启动。但是如果更新出错，会启动WindCore）
windalarmUpdate()
{
   cd $current_path
   if [ -f "$current_path/windalarm.sql" ];then
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[windalarm_old]') AND type in (N'U')) DROP TABLE [dbo].[windalarm_old]" 1>/dev/null
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "EXEC sp_rename 'dbo.windalarm' ,  'windalarm_old'" 1>/dev/null
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P Sa123456% -d wind -b -i windalarm.sql &>$current_path/output.txt
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "UPDATE dbo.windalarm SET AlarmState = (SELECT AlarmState FROM wind.dbo.windalarm_old WHERE dbo.windalarm_old.Alarmid = dbo.windalarm.Alarmid) WHERE dbo.windalarm.Alarmid IN (SELECT dbo.windalarm_old.Alarmid from dbo.windalarm_old)" &>$current_path/output.txt
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "UPDATE dbo.windalarm SET DefaultAlarmState = (SELECT DefaultAlarmState FROM wind.dbo.windalarm_old WHERE dbo.windalarm_old.Alarmid = dbo.windalarm.Alarmid) WHERE dbo.windalarm.Alarmid IN (SELECT dbo.windalarm_old.Alarmid from dbo.windalarm_old)" &>>$current_path/output.txt

      sed -i '/^$/d' $current_path/output.txt
      sed -i '/Changed database context to/d' $current_path/output.txt
      sed -i '/rows affected)/d' $current_path/output.txt

      if [ -s $current_path/output.txt ]; then
         /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[windalarm]') AND type in (N'U')) DROP TABLE [dbo].[windalarm]" 1>/dev/null
         /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "EXEC sp_rename 'dbo.windalarm_old' ,  'windalarm'" 1>/dev/null
	 sh /home/data/WindCore/startup.sh
         echo "shell脚本更新windalarm时出错，请查看当前目录下的output.txt文件并联系技术人员！"
         exit 1
       else
        #rm -f $current_path/output.txt
        /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "update wind.dbo.windalarm set DefaultAlarmState = 1, AlarmState = 1 where Alarmid = 6101" 1>/dev/null
        /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "DROP TABLE [dbo].[windalarm_old]" 1>/dev/null
      fi
   fi

   /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "UPDATE wind.dbo.windtag SET labelcn = '滤芯堵塞（红：堵塞）' WHERE windtagtype = 'D0308'" 1>/dev/null
   /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "UPDATE wind.dbo.windtagpageview SET unit = 'rpm' WHERE unit = 'rmp'" 1>/dev/null

   num1=$(/opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "select count(*) from wind.dbo.windturbine" | awk '{sub(/^[ \t]+/, "")};1'| awk 'NR==3')
   while [ $num1 -gt 0 ]
   do
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "update wind.dbo.windsetup set tagname = 'WINDFARM\MT$num1\A0536' where windturbineid = $num1 and columnid = 137" 1>/dev/null
      (( num1-- ))
   done
   unset num1
}


#WindCore更新（不包含windlarm更新、WindCore的停止和启动）
WindCoreUpdate()
{
   echo "开始更新WindCore......"

   if [ -d "$current_path/WindCore" ];then
      rm -rf /home/data/WindCore
      cp -a $current_path/WindCore /home/data
   fi

   chmod 777 /home/data/WindCore/startup.sh
   chmod 777 /home/data/WindCore/WindCore.jar
}


#CentOS和老Kylin tomcat做成服务
setTomcatService()
{
    if ! systemctl list-unit-files|grep 'tomcat'|grep 'enabled'
    then
        if ps -ef | grep farmmonitoring.jar  >/dev/null 2>&1
        then
            ps -ef | grep farmmonitoring.jar | grep -v grep | awk {'print $2'} | xargs kill -9 
            sleep 2
        fi
        if grep -q '/home/data/windeybs/windeyapp/farmmonitoring.jar' /etc/profile 
        then
            sed -i '/\/home\/data\/windeybs\/windeyapp\/farmmonitoring.jar/  s/^\(.*\)$/#\1/g' /etc/profile 
        fi
        if grep -q '/usr/local/tomcat/bin/startup.sh' /etc/profile 
        then
            sed -i '/\/usr\/local\/tomcat\/bin\/startup.sh/  s/^\(.*\)$/#\1/g' /etc/profile 
        fi

	TomcatPID=`ps -ef|grep TomcatPID|grep -v grep|awk 'NR>1 {print $2}'`
	if [[ -n $TomcatPID ]]
        then
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:存在多个TomcatPID进程$TomcatPID"|tee -a precautions_`date +"%Y%m%d"`.log
            ps -ef|grep tomcat|grep -v grep|awk 'NR>1 {print $2}'|xargs kill -9
	    echo "`date +"%Y-%m-%d %H:%M:%S"`  [INFO]:杀死多余的TomcatPID进程：$TomcatPID"|tee -a precautions_`date +"%Y%m%d"`.log
	fi

        isKylin=$(cat /etc/redhat-release)
	if [[ ${isKylin} =~ "Kylin" ]];then
           if ! grep '^JAVA_HOME' /usr/local/tomcat/bin/catalina.sh
           then
                 sed -i '/^# OS specific support/a\CLASSPATH=.:$JAVA_HOME/lib/rt.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar' /usr/local/tomcat/bin/catalina.sh
                 sed -i '/^# OS specific support/a\JAVA_HOME=/usr/java/jdk1.8.0_152' /usr/local/tomcat/bin/catalina.sh
           fi
	fi
	unset isKylin

    cat > tomcat.service <<-EOF
[Unit]
Description=tomcat
After=network.target

[Service]
Type=forking
User=root
Group=root
ExecStart=/usr/local/tomcat/bin/startup.sh
ExecStop=/usr/local/tomcat/bin/shutdown.sh
ExecReload=/bin/kill -s HUP \$MAINPID
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

   \cp tomcat.service /usr/lib/systemd/system/
   systemctl daemon-reload && systemctl enable tomcat.service 
  fi
}


#windeybs更新
windeybsUpdate()
{
   echo "开始更新windeybs......"
   OSname=$(cat /etc/redhat-release)
   if [[ ${OSname} =~ "UniKylin" ]];then
      systemctl stop tomcat
    else
      sh /usr/local/tomcat/bin/shutdown.sh >/dev/null 2>&1
      ps -ef | grep tomcat | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1
   fi

   rm -rf /home/data/windeybs
   if [ -f "$current_path/windeybs.zip" ]&&[ ! -d "$current_path/windeybs" ];then
      unzip -q $current_path/windeybs.zip -d /home/data
   fi

   if [ -d "$current_path/windeybs" ];then
      cp -a $current_path/windeybs /home/data
   fi

   chmod 777 /home/data/windeybs/restart-tomcat.sh
   if [ ! -d "/home/data/windeybs/windeyapp" ];then
      chmod 777 /home/data/windeybs/windeyapp/farmmonitoring.sh
   fi

   sleep 5
   if [[ ${OSname} =~ "UniKylin" ]];then
      systemctl start tomcat
    else
      setTomcatService
      systemctl start tomcat
   fi
   unset OSname
}


#SCADA更新后操作
afterUpdate()
{
   OSname=$(cat /etc/redhat-release)
   if [[ ${OSname} =~ "UniKylin" ]];then
      if ! grep -q 'find /home/data -maxdepth 1' /etc/crontab
      then
         echo "20 2 * * * root find /home/data -maxdepth 1 -name \"wind_2*.bak\" -mtime +90 -exec rm -f {} \;" >>/etc/crontab
      fi
      if ! grep -q 'find /home/.Trash-0' /etc/crontab
      then
         echo "20 2 * * * root find /home/.Trash-0/files -maxdepth 1 -mtime +60 ! -name \"files\" -exec rm -rf {} \;" >>/etc/crontab
         echo "20 2 * * * root find /home/.Trash-0/info -maxdepth 1 -name \"*.trashinfo\" -mtime +60 -exec rm -rf {} \;" >>/etc/crontab
      fi
    else
      if [ -d "$current_path/script" ]&&[ ! -d "/home/data/script" ]&&[ ! -d "/home/data/scripts" ];then
         cp -a $current_path/script /home/data
         chmod 644 /home/data/script
         chmod 777 /home/data/script/clean.sh
         echo "20 2 * * * root /home/data/script/clean.sh" >>/etc/crontab
      fi
   fi

   if [[ ${OSname} =~ "CentOS" ]];then
      if ! grep -q 'killall -9 gnome-shell' /etc/crontab
      then
         echo "12 3 * * * root killall -9 gnome-shell" >>/etc/crontab
     fi
   fi
   chmod 644 /etc/crontab

   firewalld_status=`systemctl status firewalld.service | grep "active (running)" | wc -l`
   if [ ${firewalld_status} -gt 0 ];then
      firewall-cmd --add-port=8182/tcp --permanent >/dev/null 2>&1
      firewall-cmd --add-port=8182/udp --permanent >/dev/null 2>&1
      firewall-cmd --add-port=8184/tcp --permanent >/dev/null 2>&1
      firewall-cmd --add-port=8184/udp --permanent >/dev/null 2>&1
      firewall-cmd --add-port=8185/tcp --permanent >/dev/null 2>&1
      firewall-cmd --add-port=8185/udp --permanent >/dev/null 2>&1
      firewall-cmd --reload >/dev/null 2>&1
   fi
}


#windeybs服务自检
checkWindyebs(){
num=0
while true
do 
    num=$[$num+1]
    if netstat -tunlp|grep java|grep -E 9166\|8080\|80
    then
	    echo "SCADA程序更新全部完成！"
        return		
    fi
	if [[ $num -gt 5 ]]
	then
	    echo "SCADA程序服务启动异常！请确认！"
	    exit 1
	fi
    sleep 5
    systemctl restart tomcat.service 
    unset OSname
done

}


#运行sqlupdate文件夹中的sql语句
sqlUpdate()
{
   if [ -d "$current_path/sqlupdate" ]&&[ -f "$current_path/sqlupdate/sqlupdate.sh" ];then
      sh $current_path/sqlupdate/sqlupdate.sh
      if [ $? -ne 0 ]; then
         unset current_path
         echo "sql语句执行异常，请联系技术人员！"
         exit 1
      fi
   fi
}


#导入table文件夹中的功率曲线文件
powerCurveUpdate()
{
   if [ -d "$current_path/table" ];then
      cd $current_path/table
      count=$(ls \[dbo\].\[wind_powercurve_50_*\].csv 2> /dev/null | wc -w)
      if [ ${count} -gt 0 ];then
         rm -f $current_path/filename.txt
         ls -l \[dbo\].\[wind_powercurve_50_*\].csv |awk '/^-/ {print $NF}' > $current_path/filename.txt
         sed -i 's/.csv//g' $current_path/filename.txt

         for line in `cat $current_path/filename.txt`
         do
         sed -i '/power_emulation/d' $current_path/table/$line.csv
         sed -i '/NULL/d' $current_path/table/$line.csv
         sed -i 's/\r//' $current_path/table/$line.csv
         /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "truncate table $line"
         /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -d wind -U sa -P Sa123456% -Q "if not exists ( select * from syscolumns where id = object_id('$line') and name='power_emulation' ) begin if exists ( select * from syscolumns where id = object_id('$line') and name='factor' ) alter table $line drop column [factor] alter table $line add [power_emulation] [numeric](18, 6) NULL alter table $line add [factor] [numeric](18, 6) NULL end"
         /opt/mssql-tools/bin/bcp $line in $current_path/table/$line.csv -c -t , -S 127.0.0.1 -U sa -P Sa123456% -d wind
         done

         unset line
         rm -f $current_path/filename.txt
      fi
      unset count
   fi
   cd $current_path
}


#部署损失电量数据导出工具
PLDataExportInstall()
{
   if [ -d "$current_path/PLDataExport" ];then
      rm -rf /home/data/tools/PLDataExport
      rm -f /root/桌面/PLDataExport.desktop
      rm -f /root/Desktop/PLDataExport.desktop
      mv $current_path/PLDataExport /home/data/tools
      chmod 777 /home/data/tools/PLDataExport/jre/linux/bin/java
      chmod 777 /home/data/tools/PLDataExport/startup.sh
      if [ -d "/root/桌面" ];then
         cp -p /home/data/tools/PLDataExport/PLDataExport.desktop /root/桌面
         chmod 777 /root/桌面/PLDataExport.desktop
      fi
      if [ -d "/root/Desktop" ];then
         cp -p /home/data/tools/PLDataExport/PLDataExport.desktop /root/Desktop
         chmod 777 /root/Desktop/PLDataExport.desktop
      fi
      echo "PLDataExport安装完成！"
   fi
}


#添加wfcode
Addwfcode()
{
   if [ -f "$current_path/add_wfcode.sql" ];then
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P Sa123456% -b -i add_wfcode.sql &>/dev/null
   fi
}


#---------------SCADA程序和sql更新---------------
cd $current_path

#脚本运行环境检查
runtimeCheck

#如果存在sqlupdate文件夹，先导入其中的sql语句
sqlUpdate

#如果存在table文件夹，则导入其中的功率曲线文件
powerCurveUpdate

#如果存在add_wfcode.sql文件，则添加wfcode
Addwfcode


#如果没有WindCore程序包但有windalarm.sql时，更新windalarm表
if [ -f "$current_path/windalarm.sql" ]&&[ ! -f "$current_path/WindCore.zip" ]&&[ ! -d "$current_path/WindCore" ];then
   ps -ef | grep WindCore.jar | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1
   sleep 1

   windalarmUpdate

   sleep 1
   sh /home/data/WindCore/startup.sh
   #如果也没有windeybs程序包，则作为机组状态码更新脚本，只更新机组状态码后退出
   if [ ! -f "$current_path/windeybs.zip" ]&&[ ! -d "$current_path/windeybs" ];then
      afterUpdate
      echo "数据库更新脚本执行完毕，机组状态码已更新！"
      exit
   fi
   echo "机组状态码更新完成！"
fi


#如果有WindCore程序包，则更新WindCore，如果有windalarm.sql也一并更新
if [ -f "$current_path/WindCore.zip" ] || [ -d "$current_path/WindCore" ];then
   WindCoreBackup
   ps -ef | grep WindCore.jar | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1
   sleep 1

   windalarmUpdate
   WindCoreUpdate

   sleep 1
   sh /home/data/WindCore/startup.sh
   echo "WindCore更新完成！"
fi


#如果有windeybs程序包，则更新windeybs
if [ -f "$current_path/windeybs.zip" ] || [ -d "$current_path/windeybs" ];then
   windeybsBackup
   windeybsUpdate
   #如果目录下有insert_module.sql文件，则导入
   cd $current_path
   if [ -f "$current_path/insert_module.sql" ];then
      /opt/mssql-tools/bin/sqlcmd -S 127.0.0.1 -U sa -P Sa123456% -b -i insert_module.sql &>/dev/null
   fi
   echo "windeybs更新完成！"
fi


#如果存在PLDataExport文件夹，则部署导出工具
PLDataExportInstall

#更新后操作
afterUpdate


#导出数据
if [ -f "$current_path/export.sh" ];then
   sh $current_path/export.sh
fi


#如果更新了windeybs，需要检查和重启windeybs
if [ -f "$current_path/windeybs.zip" ] || [ -d "$current_path/windeybs" ];then
   checkWindyebs
fi