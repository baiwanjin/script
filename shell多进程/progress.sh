#!bin/bash
num=5
fifofile="/tmp/$$.fifo"

#创建管道文件，以8作为管道符，删除不影响句柄使用
mkfifo $fifofile
exec 8<> $fifofile
rm $fifofile

#创建for循环使得管道中初始化已存在5行空行
for i in `seq $num`
do
        echo "" >&8
done
#创建for循环执行ping语句，通过管道控制最大同时并行进程数，使用完一次管道后再重新写入一次，始终保持管道中有5行可读
for i in {1..254}
do
        read -u 8
        {
        ip="10.220.99.$i"
        ping -c1 -W2 $ip &> /dev/null
        if [ $? -eq 0 ];then
                echo "$ip up..."
        else
                echo "$ip done..."
        fi
        echo >&8
        }&
done
wait
echo "Script run finish..."