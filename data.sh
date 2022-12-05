for i in * ;do echo $i|awk -F '_' '{print $1}';done|sort -u






#!/bin/bash                                                                                                                                                                #!/bin/bash
port=`netstat -tunlp|grep mongod|awk '{print $4}'|awk -F ':' '{print $2}'`
hehe="`sh tests |grep '_id'|awk 'NR==1'|awk -F ',' '{print $1}'|awk '$1=$1'`"
MongoDB="/usr/bin/mongo 127.0.0.1:$port"
$MongoDB <<EOF
show dbs;
use windmanager;
db.windfarm0000.find().pretty();
exit;
EOF

cat >MongoDBupdate<<ABC
#!/bin/bash
MongoDB="/usr/bin/mongo 127.0.0.1:$port"
\$MongoDB <<EOF
show dbs;
use windmanager;
db.windfarm0000.update({`echo $hehe`},{\\\$set: {"T000]WUpDb": 40000000}},true);
db.windfarm0000.update({`echo $hehe`},{\\\$set: {"T000]DelWMaxForDmdWOverW": 40000000}},true);
db.windfarm0000.find().pretty();
exit;
EOF
ABC
chmod +x MongoDBupdate
./MongoDBupdate
