#!/bin/sh

check(){
    if ! test -e EMS-exportConfig.sh
    then
        echo "EMS-exportConfig.sh脚本不存在，请确认！"
        exit 1
    fi
    if ! test -e update-ems.sh
    then
        echo "update-ems.sh脚本不存在，请确认！"
        exit 1
    fi
    if ! test -e standardization.sh
    then
        echo "standardization.sh脚本不存在，请确认！"
        exit 1
    fi
    if ! test -e Application_WMHisData.csv
    then
        echo "Application_WMHisData.csv文件不存在，请确认！"
        exit 1
    fi
}

main(){
    check
    chmod +x *.sh
    ./EMS-exportConfig.sh
    if [[ $? -ne 0 ]]
    then
        echo "EMS-exportConfig.sh脚本执行中段，请确认！"
        exit 1
    fi
    echo -e "\nEMS-exportConfig.sh脚本执行完成！\n"
    ./standardization.sh ems
    if [[ $? -ne 0 ]]
    then
        echo "standardization.sh脚本执行中段，请确认！"
        exit 1
    fi
    echo -e "\nstandardization.sh脚本执行完成！\n"
    ./update-ems.sh
    if [[ $? -ne 0 ]]
    then
        echo "update-ems.sh脚本执行中段，请确认！"
        exit 1
    fi
    echo -e "\nupdate-ems.sh脚本执行完成！\n"
    ./EMS-exportConfig.sh
    if [[ $? -ne 0 ]]
    then
        echo "EMS-exportConfig.sh脚本执行中段，请确认！"
        exit 1
    fi
    echo -e "\nEMS-exportConfig.sh脚本执行完成！\n"
    echo "******************************************************************************************************************"
    echo "*****任务执行已完成，请截图保留，并将当前目录下名为EMS-CONF_XXXXXXXXX.zip的压缩包文件发送给技术人员*******"
    echo "******************************************************************************************************************"
 

}

main