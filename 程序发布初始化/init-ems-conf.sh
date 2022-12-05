#!/bin/bash

#需要键入的信息
#TurbineNumber=风机数量
TurbineNumber=$1

#WindfarmID=风场编号
WindfarmID=$2
#额定功率
RatedPower=$3
OffsetPower=$4
#功率曲线
PowerCurve=$5
#机型数（种）
Type=$6
#最大风速
MaxWindSpeed=$7
echo "MaxWindSpeed=$MaxWindSpeed"
LOG_FILE=$8

#需要修改的文件
WINDCONFING_DB_EMSCONFIG='./ems3/windconfig/db/emsconfig.db'
windmanager_CFG_ADSCollect='./ems3/windmanager/cfg/ADSCollect.csv'
WINDSTAT_CONFIG='./ems3/windstat/config'
#新增文件
WINDCONFING_WindfarmID='./ems3/windconfig/WindfarmID'

log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
}

set_windmanager_cfg_ADSCollect(){
    if ! test -e $windmanager_CFG_ADSCollect
    then
        log_error "$windmanager_CFG_ADSCollect文件不存在"
        exit 1
    fi
    if [ $TurbineNumber -gt 100 ]
    then
        for i in `seq -w 100 $TurbineNumber`
        do 
            echo "T$i,10.200.200.$i,10.200.200.$i.1.1,801,T0,,,,"|tee -a $windmanager_CFG_ADSCollect
        done
    else

        log_info "删除$windmanager_CFG_ADSCollect文件中$TurbineNumber以后多余的风机配置"
        nextline=$[$TurbineNumber+1]
        if [ $nextline -lt 10 ]
        then
            num='00'$nextline
        elif [ $nextline -lt 100 ]
        then
            num='0'$nextline
        fi
        sed -i "/T$num,/,\$d" $windmanager_CFG_ADSCollect
        log_info "将$windmanager_CFG_ADSCollect文件中的SWITCH值改为‘1’！"
        sed -i 's/SWITCH,.*/SWITCH,1,,,,,,,/g' $windmanager_CFG_ADSCollect
    fi
}

set_windconfig_db_emsconfig(){
    if ! test -e setemsconfig.py 
    then
        log_error "$PWD目录下setemsconfig.py文件不存在！"
        exit 1
    fi
    if ! test -e $WINDCONFING_DB_EMSCONFIG
    then
        log_error "$WINDCONFING_DB_EMSCONFIG文件不存在！"
        exit 1
    fi
    if ! python3 -V >/dev/null 2>&1
    then
        log_error "python3 未安装，找不到这样的命令！"
        exit 1
    fi
    sed -i "s/temp=.*/temp=$RatedPower/g" setemsconfig.py
    sed -i "s/totalnum=.*/totalnum=$TurbineNumber/g" setemsconfig.py
    sed -i "s#sqlitepath=.*#sqlitepath='$WINDCONFING_DB_EMSCONFIG'#g" setemsconfig.py
    sed -i "s/OffsetPower=.*/OffsetPower=$OffsetPower/g" setemsconfig.py
    python3 setemsconfig.py
    log_info "初始化数据库 windturbine"
}

set_windstat_config(){
    rm -f $WINDSTAT_CONFIG/powercurve.csv
    PowerCurve=`echo $PowerCurve|cut -d '(' -f2|cut -d ')' -f1`
    for i in `echo $PowerCurve|sed 's/;/ /g'`;do echo $i|tee -a $WINDSTAT_CONFIG/powercurve.csv;done
    MaxPower=`awk 'END {print}' $WINDSTAT_CONFIG/powercurve.csv|awk -F ',' '{print $2}'`
    echo $MaxWindSpeed,$MaxPower |tee -a $WINDSTAT_CONFIG/powercurve.csv
    log_info "`cat $WINDSTAT_CONFIG/powercurve.csv`"
    if [ $Type -ne 1 ]
    then
        \cp $WINDSTAT_CONFIG/powercurve.csv $WINDSTAT_CONFIG/powercurve-T001.csv
        echo '由于该项目为多机型，机位未确定，暂无法配置机组功率曲线' | tee $WINDSTAT_CONFIG/注意.txt
    fi
    
}

main(){
    set_windmanager_cfg_ADSCollect
    set_windconfig_db_emsconfig
    set_windstat_config
    log_info "将WindfarmID,Windfarm$WindfarmID写入$WINDCONFING_WindfarmID"
    cat >$WINDCONFING_WindfarmID<<EOF
WindfarmID,Windfarm$WindfarmID
EOF

}

main