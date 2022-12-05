#!/bin/bash

cat > /etc/clean-HisDataLogCustomer << EOF
#!/bin/bash
if test -d /home/data/HisDataLogCustomer
then
    find /home/data/HisDataLogCustomer -mtime +180 -name "*.csv*" -exec rm -rf {} \;
fi
EOF

chmod +x /etc/clean-HisDataLogCustomer 

if ! grep 'clean-HisDataLogCustomer'  /var/spool/cron/root 
then
    echo '10 5 * * *  /etc/clean-HisDataLogCustomer' >> /var/spool/cron/root
    systemctl status crond.service 
fi

if test -d /home/data/HisDataLogCustomer
then
    find /home/data/HisDataLogCustomer -mtime +180 -name "*.csv*" -exec rm -rf {} \;
fi


