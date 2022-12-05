#!/bin/bash
cat >> /etc/profile<<EOF
    export readonly PROMPT_COMMAND=/etc/operation.sh
EOF
cat > /etc/operation.sh <<EOF
{
    if [ ! -d /var/log/operation ]
    then
        mkdir /var/log/operation
        if [ \`id -u\` -eq 0 ]
        then
            chattr +a /var/log/operation
        fi
    fi
    historylog=/var/log/operation/history\`date -d today +"%Y-%m-%d"\`.log
    if [ ! -f \$historylog ]
    then
        touch \$historylog
        chmod 777 \$historylog
        chattr +a \$historylog
    fi
    records=\`echo "[\$(date -d today +"%Y-%m-%d")][\$(who -u -m | awk '{print \$NF}'| sed 's/[()]//g')][\$(whoami)][\$(pwd)]\$(history 1 | sed 's/^[ \t]*//g' |cut -d ' ' -f2-)"\`
    echo "\$records" >>\$historylog
    caudit --op "\$records" >/dev/null 2>&1
} 2>/dev/null
EOF
chmod +x /etc/operation.sh
source /etc/profile