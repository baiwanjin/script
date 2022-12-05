#!/bin/bash
Date=`date -d $1 +%Y%m%d`
PLClogList=`find /home/data/Windfarm0425 -name "$1*csv"`
for PLClog in  ${PLClogList[*]}
do 
    relativePath=`dirname $PLClog|awk -F 'data/' '{print $2}'`
    mkdir -p $Date/$relativePath
    \cp $PLClog  $Date/$relativePath
    zip -v -r $Date.zip $Date
done
