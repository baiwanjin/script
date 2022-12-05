#!/bin/bash
SCADA_Path='/home/data'
Windfarm=`grep WindfarmID $SCADA_Path/WindCore/cfg/Application_HistoryData.csv|awk -F ',' '{print $2}'|awk -F 'Windfarm' '{print $2}'`
echo $Windfarm > WindfarmID-$Windfarm.txt