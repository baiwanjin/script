#!/bin/bash
#需要键入的信息
#TurbineNumber=风机数量
TurbineNumber=$1
#WindfarmID=风场编号
WindfarmID=$2
#空气密度
AIRDENSITY=$3
#气压值
Pressure=$4

#需要修改替换的文件
# ①./monitor-backend/config/devConfig.js (默认配置，无需修改)
# ②./WindCore/cfg/ConnectValue-PG.csv （需修改TurbineNumber的值为项目风机实际数量）
# ③./WindCore/cfg/Application_HistoryData.csv （需修改WindfarmID的值为项目风机编号）
# ④./WindCore/cfg/Application_Turbinestate.csv （需修改windfarm1,1的值为项目风机数量）
# ⑤./WindCore/cfg/Application_TheoreticalPower.csv （以下项需按项目实际数量填写）
# ⑥./WindCore/cfg/Application.csv （以下项的值修改为‘1’）
# ⑦./WindCore/cfg/Application_Arithmetic.csv (删减A1021气压至实际项目风机数量，并更新气压值)
# ⑧./WindDP/cfg/ConnectValue.csv (默认配置，无需修改)
# ⑨./WindDP/cfg/Application.csv  (默认配置，无需修改)
# ⑩./WindCore/cfg/ADSCollect.csv (WINDFARM风机数量和项目保持一致)
# ⑪./WindCore/cfg/Application_PowerLossPgHighgo.csv（配置空气密度；标杆风机默认填1）

#WindCore需要需修改的文件
WINDCORE_CFG_ConnectValue='./WindCore/cfg/ConnectValue.csv'
WINDCORE_CFG_Application_HistoryData='./WindCore/cfg/Application_HistoryData.csv'
WINDCORE_CFG_Application_Turbinestate='./WindCore/cfg/Application_Turbinestate.csv '
WINDCORE_CFG_Application_TheoreticalPower='./WindCore/cfg/Application_TheoreticalPower.csv'
WINDCORE_CFG_Application='./WindCore/cfg/Application.csv'
WINDCORE_CFG_Application_Value=('TurbineState_statistics,1' 'HistoryData,1' 'redisdump,1' 'MaxMinStatistics,1' 'Arithmetic,1' 'AvgStatistics,1' 'TurbineAlarm,1' 'DataTransport,1' 'TheoreticalPower,1' 'TimeSeriesData,1' 'TurbineVersion,1' 'AlarmIntern,1' 'PowerLossPgHighgo,1' 'Cumulant,1')
WINDCORE_CFG_Application_Arithmetic='./WindCore/cfg/Application_Arithmetic.csv'
WINDCORE_CFG_ADSCollect='./WindCore/cfg/ADSCollect.csv'
WINDCORE_CFG_Application_PowerLoss='./WindCore/cfg/Application_PowerLossPgHighgo.csv'


LOG_FILE=$5
if [ -z $TurbineNumber ]
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未获取到TurbineNumber的值  \033[0m"
    exit 1
fi 
if ! echo $TurbineNumber | grep -E "^[0-9]*[0-9]*$" >/dev/null 2>&1
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 输入的风场风机数量:$TurbineNumber 格式有误！请重新输入！ \033[0m"
    exit 1
fi
if [ -z $WindfarmID ]
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未获取到WindfarmID的值  \033[0m"
    exit 1
fi
if ! echo $WindfarmID | grep -E "[0-9]{4}$" >/dev/null 2>&1
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 输入的风场编号:$WindfarmID 格式有误！请重新输入！  \033[0m"
    exit 1
fi

if [ -z $AIRDENSITY ]
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未获取到AIRDENSITY的值  \033[0m"
    exit 1
fi 

if [ -z $Pressure ]
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未获取到Pressure的值  \033[0m"
    exit 1
fi 


if [ -z $LOG_FILE ]
then
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: 未获取到LOG_FILE的值  \033[0m"
    exit 1
fi 

log_info(){
    echo "`date +"%Y-%m-%d %H:%M:%S"` [INFO]: $1"|tee -a $LOG_FILE
}

log_error(){
    echo -e "\033[31m `date +"%Y-%m-%d %H:%M:%S"` [ERROR]: $1 \033[0m"|tee -a $LOG_FILE
}

set_WindCore_cfg_Application_PowerLoss(){
    log_info "将文件$WINDCORE_CFG_Application_PowerLoss中AIRDENSITY的值修改为$AIRDENSITY"
    sed -i "/AIRDENSITY,/{n;s#.*#$AIRDENSITY#;}" $WINDCORE_CFG_Application_PowerLoss
    log_info "将文件$WINDCORE_CFG_Application_PowerLoss中STANDARDTURBINE的值修改为1"
    sed -i "/STANDARDTURBINE,/{n;s#.*#id,1#;}" $WINDCORE_CFG_Application_PowerLoss
}


set_WindCore_cfg_ConnectValue(){
    #修改TurbineNumber的值为项目风机实际数量
    if ! test -e $WINDCORE_CFG_ConnectValue
    then
        log_error "$WINDCORE_CFG_ConnectValue文件不存在"
        exit 1
    fi
    if ! grep "^TurbineNumber," $WINDCORE_CFG_ConnectValue >/dev/null 2>&1
    then
        log_error "$WINDCORE_CFG_ConnectValue文件中不存在TurbineNumber键"
        exit 1
    else
        log_info "将$WINDCORE_CFG_ConnectValue文件中TurbineNumber的值修改为$TurbineNumber"
        sed -i "s#^TurbineNumber,.*#TurbineNumber,$TurbineNumber#g" $WINDCORE_CFG_ConnectValue
    fi
}

set_WindCore_cfg_Application_HistoryData(){
    if ! test -e $WINDCORE_CFG_Application_HistoryData
    then
        log_error "$WINDCORE_CFG_Application_HistoryData文件不存在"
        exit 1
    fi
    if ! grep "^WindfarmID," $WINDCORE_CFG_Application_HistoryData >/dev/null 2>&1
    then
        log_error "$WINDCORE_CFG_Application_HistoryData文件中不存在WindfarmID键"
        exit 1
    else
        log_info "将$WINDCORE_CFG_Application_HistoryData文件中WindfarmID的值修改为Windfarm$WindfarmID"
        sed -i "s#^WindfarmID,.*#WindfarmID,Windfarm$WindfarmID,#g" $WINDCORE_CFG_Application_HistoryData
    fi
}

set_WindCore_cfg_Application_Turbinestate(){
    if ! test -e $WINDCORE_CFG_Application_Turbinestate
    then
        log_error "$WINDCORE_CFG_Application_Turbinestate文件不存在"
        exit 1
    fi
    if ! grep "^windfarm1," $WINDCORE_CFG_Application_Turbinestate >/dev/null 2>&1
    then
        log_error "$WINDCORE_CFG_Application_Turbinestate文件中不存在windfarm1键"
        exit 1
    else
        log_info "将$WINDCORE_CFG_Application_Turbinestate文件中windfarm1的值修改为$TurbineNumber"
        sed -i "s#^windfarm1,.*#windfarm1,1,$TurbineNumber,,,,,#g" $WINDCORE_CFG_Application_Turbinestate
    fi
}

set_WindCore_cfg_Application_TheoreticalPower(){
    if ! test -e $WINDCORE_CFG_Application_TheoreticalPower
    then
        log_error "$WINDCORE_CFG_Application_TheoreticalPower文件不存在"
        exit 1
    fi
    if ! grep "^1,.*,WINDFARM," $WINDCORE_CFG_Application_TheoreticalPower >/dev/null 2>&1
    then
        log_error "$WINDCORE_CFG_Application_TheoreticalPower文件中不存在1,.*,WINDFARM字符串"
        exit 1
    else
        log_info "将$WINDCORE_CFG_Application_TheoreticalPower文件中^1,.*,WINDFARM,.*修改为1,$TurbineNumber,WINDFARM,,"
        sed -i "s#^1,.*,WINDFARM,.*#1,$TurbineNumber,WINDFARM,,#g" $WINDCORE_CFG_Application_TheoreticalPower
    fi
    if ! grep "^1,.*,WINDFARM1," $WINDCORE_CFG_Application_TheoreticalPower >/dev/null 2>&1
    then
        log_error "$WINDCORE_CFG_Application_TheoreticalPower文件中不存在1,.*,WINDFARM1字符串"
        exit 1
    else
        log_info "将$WINDCORE_CFG_Application_TheoreticalPower文件中^1,.*,WINDFARM1,.*修改为1,$TurbineNumber,WINDFARM1,,"
        sed -i "s#^1,.*,WINDFARM1,.*#1,$TurbineNumber,WINDFARM1,,#g" $WINDCORE_CFG_Application_TheoreticalPower
    fi
}

set_WindCore_cfg_Application(){
    if ! test -e $WINDCORE_CFG_Application
    then
        log_error "$WINDCORE_CFG_Application文件不存在"
        exit 1
    fi
    for i in $(seq ${#WINDCORE_CFG_Application_Value[*]})
    do
        str=`echo ${WINDCORE_CFG_Application_Value[i-1]}`
        key=`echo ${str%,*}`
        value=`echo ${str#*,}`
        if ! grep "^$key," $WINDCORE_CFG_Application >/dev/null 2>&1
        then
            log_error "$WINDCORE_CFG_Application文件中不存在$key键"
            exit 1
        else
            log_info "将$WINDCORE_CFG_Application文件中的$key行修改为$str"
            sed -i "s#^$key,.*#$str#g" $WINDCORE_CFG_Application
        fi
    done
}

set_WindCore_cfg_Application_Arithmetic(){
    if ! test -e $WINDCORE_CFG_Application_Arithmetic
    then
        log_error "$WINDCORE_CFG_Application_Arithmetic文件不存在"
        exit 1
    fi
    if [ $TurbineNumber -gt 100 ]
    then
        echo "operator,,,,,,,,,,,,">$WINDCORE_CFG_Application_Arithmetic
        echo "add,(+),,,,,,,,,,," >> $WINDCORE_CFG_Application_Arithmetic
        echo "sub,(-),,,,,,,,,,,"|tee -a $WINDCORE_CFG_Application_Arithmetic
        echo "mul,(*),,,,,,,,,,,"|tee -a $WINDCORE_CFG_Application_Arithmetic
        echo "div,(/),,,,,,,,,,,"|tee -a $WINDCORE_CFG_Application_Arithmetic
        echo "formula,,,,,,,,,,,,"|tee -a $WINDCORE_CFG_Application_Arithmetic
        echo "result,coefficient_A,TagA,operator,coefficient_B,TagB,operator,coefficient_C,TagC,operator,coefficient_D,TagD,const"|tee -a $WINDCORE_CFG_Application_Arithmetic
        for i in `seq 1 $TurbineNumber`
        do
            echo "WINDFARM\MT$i\A0216,1,WINDFARM\MT$i\A0409,,,,,,,,,,0"|tee -a $WINDCORE_CFG_Application_Arithmetic
        done
        for i in `seq 1 $TurbineNumber`
        do
            echo "WINDFARM\MT$i\A1021,,,,,,,,,,,,1013.25"|tee -a $WINDCORE_CFG_Application_Arithmetic
        done    
    else
        log_info "删除$WINDCORE_CFG_Application_Arithmetic文件中A0216点MT$TurbineNumber以后的行"
        sed -i "/^WINDFARM\\\\MT$TurbineNumber\\\\A0216,1,/,/^WINDFARM\\\\MT1\\\\A1021,/{/^WINDFARM\\\\MT$TurbineNumber\\\\A0216,1,/!{/^WINDFARM\\\\MT1\\\\A1021,/!d}}" $WINDCORE_CFG_Application_Arithmetic
        nextline=$[$TurbineNumber+1]
        log_info "删除$WINDCORE_CFG_Application_Arithmetic文件中A1021点MT$TurbineNumber以后的行"
        sed -i "/^WINDFARM\\\\MT$nextline\\\\A1021/,\$d" $WINDCORE_CFG_Application_Arithmetic
        sleep 1
    fi
    value=`grep "A1021" $WINDCORE_CFG_Application_Arithmetic |awk -F ',' '{print $NF}'|head -n 1`
    sed -i "/.*1021.*$value$/ s/$value/$Pressure/g" $WINDCORE_CFG_Application_Arithmetic

}

set_WindCore_cfg_ADSCollect(){
    if ! test -e $WINDCORE_CFG_ADSCollect
    then
        log_error "$WINDCORE_CFG_ADSCollect文件不存在"
        exit 1
    fi
    if [ $TurbineNumber -gt 100 ]
    then
        for i in `seq 101 $TurbineNumber`
        do
            echo "WINDFARM\\MT$i,10.200.200.$i,10.200.200.$i.1.1,801,T0,,,,"|tee -a $WINDCORE_CFG_ADSCollect
        done

    else

        log_info "删除$WINDCORE_CFG_ADSCollect文件中MT$TurbineNumbe以后多余的风机配置"
        nextline=$[$TurbineNumber+1]
        sed -i "/^WINDFARM\\\\MT$nextline,/,\$d" $WINDCORE_CFG_ADSCollect
    fi
   
}

main(){
set_WindCore_cfg_ConnectValue
set_WindCore_cfg_Application_HistoryData
set_WindCore_cfg_Application_Turbinestate
set_WindCore_cfg_Application_TheoreticalPower
set_WindCore_cfg_Application
set_WindCore_cfg_Application_Arithmetic
set_WindCore_cfg_ADSCollect
set_WindCore_cfg_Application_PowerLoss
}

main