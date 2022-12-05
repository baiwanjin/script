#!/bin/bash
if ps -ef | grep farmmonitoring.jar  >/dev/null 2>&1
then
    ps -ef | grep farmmonitoring.jar | grep -v grep | awk {'print $2'} | xargs kill -9 
    sleep 2
fi
chmod +x /home/data/windeybs/windeyapp/farmmonitoring.sh
/bin/bash /home/data/windeybs/windeyapp/farmmonitoring.sh

echo "Restarting Tomcat......"

OSname=$(cat /etc/redhat-release)
echo ${OSname}
if [[ ${OSname} =~ "UniKylin" ]] || [[ ${OSname} =~ "KylinSec" ]];then
   systemctl restart tomcat
   sleep 5
   systemctl status tomcat
   echo "tomcat started"
else  
   catalina=`ps -ef | grep catalina| grep -v grep | wc -l`
   if [ $catalina -ge 1 ];then
      ps -ef | grep catalina | grep -v grep | awk {'print $2'} | xargs kill -9 >/dev/null 2>&1
      echo "tomcat killed"
      sleep 2
   fi
   chmod +x /usr/local/tomcat/bin/startup.sh
   /bin/bash /usr/local/tomcat/bin/startup.sh
   echo "tomcat started"
   
fi
 

