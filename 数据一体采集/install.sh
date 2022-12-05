#!/bin/bash
DATA_COLLECT_PATH=/home/data

main(){
    if ! test -e datacollectionscript.zip
    then
        echo "datacollectionscript.zip 不存在"
        exit 1
    fi
    test -d $DATA_COLLECT_PATH || mkdir -p $DATA_COLLECT_PATH
    unzip -o -q datacollectionscript.zip -d $DATA_COLLECT_PATH
    if ! grep "DATA_COLLECT_HOME=$DATA_COLLECT_PATH" /etc/bashrc >/dev/null 2>&1
    then
        echo "export DATA_COLLECT_HOME=$DATA_COLLECT_PATH/datacollectionscript"|tee -a /etc/bashrc && source /etc/bashrc
        
    fi
}
main