#!/bin/bash

if test /home/data/windmmcs
then
    mv /home/data/windmmcs /home/data/windmmcs_`date "+%Y%m%d%H%M%S"`
fi

mv windmmcs  /home/data

chmod +x /home/data/windmmcs/windmmcs
chmod +x /home/data/windmmcs/startup.sh
