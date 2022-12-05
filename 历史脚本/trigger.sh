#!/bin/bash

CrontabList='/etc/crontablist'

if ! test -e clean-history-data.sh
then
    echo -e " \033[31m 缺少clean-history-data.sh脚本 \033[31m"
    echo -e " \033[31m 未设置历史数据清理脚本！\033[31m"
else
    mkdir -p $CrontabList
    \cp clean-history-data.sh $CrontabList
    crontab -l  >/dev/null 2>&1 >> crontabfile
    if ! grep 'clean-history-data.sh' crontabfile >/dev/null 2>&1;then echo '10 5 * * *  '$CrontabList'/clean-history-data.sh' >> crontabfile;fi
    crontab crontabfile && rm -f crontabfile
    chmod +x $CrontabList'/clean-history-data.sh'
    
fi

if ! test -e ems-set-influxDB-strategy.sh
then
    echo -e " \033[31m 缺少ems-set-influxDB-strategy.sh脚本 \033[31m"
    echo -e " \033[31m 未设置InfluxDB数据库保留策略！\033[31m"
else
    chmod +x ems-set-influxDB-strategy.sh
    /bin/bash ems-set-influxDB-strategy.sh
fi
