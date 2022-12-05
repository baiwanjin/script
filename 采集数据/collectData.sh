#!/bin/bash

#分拣数据

Data_Path='/home/data/collectData'

#获取风场面编号
SCADA_Path='/home/data'
Windfarm=`grep WindfarmID $SCADA_Path/WindCore/cfg/Application_HistoryData.csv|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
WindfarmID='Windfarm'$Windfarm

#当前时间
nowTime=`date "+%Y-%m-%d"`
#获取前一天的时间
yesterdayTime=`date -d"1 month ago $nowTime" +%Y-%m-%d`
#获取十五天前的时间
fifteendayTime=`date -d"15 day ago $nowTime" +%Y-%m-%d`

#文件类型
#1、PLC日志
#2、损失电量
#3、月报信息
#4、首触故障
#5、配置文件导出

#获取指定时间段内的文件
#find /home/data/ -name '*' -newermt '2022-09-08' ! -newermt '2022-09-30'

#生成方式
#*********************************************************************************************
