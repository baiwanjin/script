#!/bin/bash
#样机服务器十秒级数据上传到阿里云
# for i in `find /home/data/HisDataLog_RT/$dirDate ! -newermt "$Date" -type f -name *.csv`;do echo "上传$i文件";sshpass -p '&Y1EmPos' scp "$i" sftp1@10.168.1.212:;echo "清除文件$i";rm -f "$i";done
# for i in `find /home/data/HisDataLog_RT/$dirDate -newermt "$startDate" ! -newermt "$endDate" -type f -name *.csv`;do echo "上传$i文件";sshpass -p '&Y1EmPos' scp "$i" sftp1@10.168.1.212:;echo "清除文件$i";done     

cat > /usr/local/bin/uploading-hisdatalogrt <<EOF
#!/bin/bash
while true
do
    endDate=\`date -d '-10 second' +"%Y-%m-%d %H:%M:%S"\`
    startDate=\`date -d '-20 second' +"%Y-%m-%d %H:%M:%S"\`
    dirDate=\`date +"%Y-%m-%d"\`
    fileName=\`find /home/data/HisDataLog_RT/\$dirDate -newermt "\$startDate" ! -newermt "\$endDate" -type f -name "*.csv"\`
    if [ -z \$fileName ] ;then continue;fi
    sshpass -p '&Y1EmPos' scp "\$fileName" sftp1@10.168.1.212:
    echo "\`date +"%Y-%m-%d %H:%M:%S"\` 上传\$fileName成功"|tee -a /var/log/uploading-hisdatalogrt.log 
    sleep 10
done
EOF

chmod +x /usr/local/bin/uploading-hisdatalogrt


cat > /usr/lib/systemd/system/uploading-hisdatalogrt.service <<EOF
[Unit]

Description=uploading-hisdatalogrt service

[Service]
Type=simple
ExecStart=/usr/local/bin/uploading-hisdatalogrt
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=True


[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload && systemctl enable uploading-hisdatalogrt.service &&  systemctl start uploading-hisdatalogrt.service