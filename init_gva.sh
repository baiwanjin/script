#!/bin/bash
DATE=`/usr/bin/date +"%Y%m%d%H%M%S"`
if ! lsmod | grep nouveau
then
    if ! grep nouveau /usr/lib/modprobe.d/dist-blacklist.conf
    then
        \cp /usr/lib/modprobe.d/dist-blacklist.conf /usr/lib/modprobe.d/dist-blacklist.conf$DATE
        echo 'blacklist nouveau' /usr/lib/modprobe.d/dist-blacklist.conf
        echo 'options nouveau modeset=0' /usr/lib/modprobe.d/dist-blacklist.conf
    fi
    mv /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img$DATE.bak
    dracut /boot/initramfs-$(uname -r).img $(uname -r)
fi
\cp NVIDIA-Linux-x86_64-470.141.03-730.run /opt/ && systemctl set-default multi-user.target  && reboot
