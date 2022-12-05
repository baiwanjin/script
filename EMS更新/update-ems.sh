#!/bin/bash
#@20220916
WindfarmID='0000'
#去除帽子
dislodge_cap(){
    port=`netstat -tunlp|grep mongod|awk '{print $4}'|awk -F ':' '{print $2}'`
    cat > getMongoDBupdate_id<<ABC
#!/bin/bash
MongoDB="/usr/bin/mongo 127.0.0.1:$port"
\$MongoDB <<EOF
show dbs;
use windmanager;
db.windfarm0000.find().pretty();
exit;
EOF
ABC
    MongoDBupdate_id="`sh getMongoDBupdate_id |grep '_id'|awk 'NR==1'|awk -F ',' '{print $1}'|awk '$1=$1'`"
    str=`sh getMongoDBupdate_id |grep "T*]WUpDb"|awk '{split($0,a,"[TW]");print a[2]}'|grep -v '000]' || sh getMongoDBupdate_id |grep "T*]DelWMaxForDmdWOverW"|awk '{split($0,a,"[TW]");print a[2]}'|grep -v '000]'`
cat >MongoDBupdate.sh<<ABC
#!/bin/bash
MongoDB="/usr/bin/mongo 127.0.0.1:$port"
\$MongoDB <<EOF 
show dbs;
use windmanager;
db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {"T000]WUpDb": 20000000}},true);
db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {"T000]DelWMaxForDmdWOverW": 20000000}},true);
db.windfarm0000.find().pretty();
exit;
EOF
ABC
    if sh getMongoDBupdate_id |grep "T*]WUpDb"|awk '{split($0,a,"[TW]");print a[2]}'|grep -v '000]' || sh getMongoDBupdate_id |grep "T*]DelWMaxForDmdWOverW"|awk '{split($0,a,"[TW]");print a[2]}'|grep -v '000]'  >/dev/null 2>&1
    then
        if echo $str |grep ']'  >/dev/null 2>&1
        then
#             cat >MongoDBupTurbineData.sh<<ABD
# #!/bin/bash
# MongoDB="/usr/bin/mongo 127.0.0.1:$port"
# ABD
#             echo '$MongoDB <<EOF'|tee -a MongoDBupTurbineData.sh
#             echo 'show dbs;'|tee -a MongoDBupTurbineData.sh
#             echo 'use windmanager;'|tee -a MongoDBupTurbineData.sh
            
#             for TurbineData in `sh getMongoDBupdate_id |grep "T*]WUpDb"|awk -F ':' '{print $1}'|awk '$1=$1'|awk -F ']' '{print $1}'|awk -F '"' '{print $2}'|uniq`
#             do
#                 echo "db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {\"$TurbineData]WUpDb\": 20000000}},true);"|tee -a MongoDBupTurbineData.sh
#             done
            
#             for TurbineData in `sh getMongoDBupdate_id |grep "T*]DelWMaxForDmdWOverW"|awk -F ':' '{print $1}'|awk '$1=$1'|awk -F ']' '{print $1}'|awk -F '"' '{print $2}'|uniq`
#             do
#                 echo "db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {\"$TurbineData]DelWMaxForDmdWOverW\": 20000000}},true);"|tee -a MongoDBupTurbineData.sh
#             done
#             echo 'db.windfarm0000.find().pretty();'|tee -a MongoDBupTurbineData.sh
#             echo 'exit;'|tee -a MongoDBupTurbineData.sh
#             echo 'EOF'|tee -a MongoDBupTurbineData.sh
#             chmod +x MongoDBupTurbineData.sh
#             ./MongoDBupTurbineData.sh
#         fi
            if ! test -e /home/data/WindCore/cfg/ADSCollect.csv
            then
                echo "未找到 /home/data/WindCore/cfg/ADSCollect.csv文件！"
                exit 1
            fi
            if ! test -e /home/data/WindCore/cfg/ModbusCollect_TCP_1.csv
            then
                echo "未找到 /home/data/WindCore/cfg/ModbusCollect_TCP_1.csv文件！"
                exit 1
            fi
            cat >MongoDBupTurbineData.sh<<ABD
#!/bin/bash
MongoDB="/usr/bin/mongo 127.0.0.1:$port"
ABD
            echo '$MongoDB <<EOF'|tee -a MongoDBupTurbineData.sh
            echo 'show dbs;'|tee -a MongoDBupTurbineData.sh
            echo 'use windmanager;'|tee -a MongoDBupTurbineData.sh
            if grep 'SWITCH' /home/data/WindCore/cfg/ADSCollect.csv|awk -F ',' '{print $2}'|grep '1' >/dev/null 2>&1
            then
                if sh getMongoDBupdate_id |grep "T*]WUpDb"|grep -v '000]'  >/dev/null 2>&1
                then
                    for TurbineData in `cat /home/data/WindCore/cfg/ADSCollect.csv |grep -E "^T[0-9][0-9][0-9],"|awk -F ',' '{print $1}'`
                    do
                        echo "db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {\"$TurbineData]WUpDb\": 20000000}},true);"|tee -a MongoDBupTurbineData.sh
                    done
                fi
                if sh getMongoDBupdate_id |grep "T*]DelWMaxForDmdWOverW"|grep -v '000]'  >/dev/null 2>&1
                then
                    for TurbineData in `cat /home/data/WindCore/cfg/ADSCollect.csv |grep -E "^T[0-9][0-9][0-9],"|awk -F ',' '{print $1}'`
                    do
                        echo "db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {\"$TurbineData]DelWMaxForDmdWOverW\": 20000000}},true);"|tee -a MongoDBupTurbineData.sh
                    done
                fi
            fi

            if  awk '/SERVICEON/{getline a;print a}' /home/data/WindCore/cfg/ModbusCollect_TCP_1.csv|grep '1' >/dev/null 2>&1
            then
                if sh getMongoDBupdate_id |grep "T*]WUpDb"|grep -v '000]'  >/dev/null 2>&1
                then
                    for TurbineDataa in `cat /home/data/WindCore/cfg/ModbusCollect_TCP_1.csv |grep -E "^T[0-9][0-9][0-9],"|awk -F ',' '{print $1}'`
                    do
                        echo "db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {\"$TurbineDataa]WUpDb\": 20000000}},true);"|tee -a MongoDBupTurbineData.sh
                    done
                fi
                if sh getMongoDBupdate_id |grep "T*]DelWMaxForDmdWOverW"|grep -v '000]'  >/dev/null 2>&1
                then
                    for TurbineDataa in `cat /home/data/WindCore/cfg/ModbusCollect_TCP_1.csv |grep -E "^T[0-9][0-9][0-9],"|awk -F ',' '{print $1}'`
                    do
                        echo "db.windfarm0000.update({`echo $MongoDBupdate_id`},{\\\$set: {\"$TurbineData]DelWMaxForDmdWOverW\": 20000000}},true);"|tee -a MongoDBupTurbineData.sh
                    done
                fi
                
            fi
            echo 'db.windfarm0000.find().pretty();'|tee -a MongoDBupTurbineData.sh
            echo 'exit;'|tee -a MongoDBupTurbineData.sh
            echo 'EOF'|tee -a MongoDBupTurbineData.sh
            chmod +x MongoDBupTurbineData.sh
            ./MongoDBupTurbineData.sh

        else
            echo "获取的MongoDB数据异常，请确认！"
            exit 1
        fi
    fi
    
  
  
    chmod +x MongoDBupdate.sh
    ./MongoDBupdate.sh
 
    
}
#配置风场编号
set_windfarmID(){
    if ! test -d /home/data/WindCore/cfg
    then
        echo "不存在 /home/data/WindCore/cfg 目录！"
        exit 1
    fi
    while true
    do
        # read -p "请输入风场编号,如'0409':" WindfarmID
        if ! echo $WindfarmID | grep -E "^[0-9]{4}$" >/dev/null 2>&1
        then
            echo "风场编号:$WindfarmID 格式有误！"
            return
        fi
        break
    done
    cat >/home/data/WindCore/cfg/WindfarmID<<EOF
WindfarmID,Windfarm$WindfarmID
EOF
}

#修改配置
set_Application_WMHisData(){
    if ! test -e Application_WMHisData.csv
    then
        echo "当前目录下Application_WMHisData.csv模板文件不存在"
        exit
    fi
    if ! test -e /home/data/WindCore/cfg/Application_WMHisData.csv
    then
        echo "/home/data/WindCore/cfg/目录下Application_WMHisData.csv文件不存在"
        exit
    fi
    \cp /home/data/WindCore/cfg/Application_WMHisData.csv /home/data/WindCore/cfg/Application_WMHisData_`date +"%Y%m%d%H%M%S"`.bak
    for value in `cat Application_WMHisData.csv|awk 'NR>3'`
    do
        if ! grep "^`echo $value|awk -F ',' '{print $1}'`," /home/data/WindCore/cfg/Application_WMHisData.csv
        then
            echo $value|tee -a /home/data/WindCore/cfg/Application_WMHisData.csv
            echo "将$value插入到/home/data/WindCore/cfg/Application_WMHisData.csv文件中"
        fi 
    done
}

if grep 'CentOS' /etc/redhat-release
then
    \cp /home/data/.windmanager/mongodb/bin/* /usr/bin
fi

dislodge_cap
set_windfarmID
set_Application_WMHisData
