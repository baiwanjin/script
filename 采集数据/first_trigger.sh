/bin/bash
ADDRIP='10.220.101.116'
SQLUSER='sa'
SQLPASSWD='Sa123456%'
SQLDB='wind'

#生成上个月的月报
last_month_statement(){
    /opt/mssql-tools/bin/sqlcmd \
-S $ADDRIP \
-d msdb \
-U $SQLUSER \
-P $SQLPASSWD \
-Q "use $SQLDB;select * from view_alarm where datediff(month,starttime,getdate())=1  order by starttime  DESC and groupid=1 " \
|awk 'NR>=4' > firstmalfunction



}



main(){
#默认生成上个月的时间



}

main