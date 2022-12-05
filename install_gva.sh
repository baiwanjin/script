#!/bin/bash
if ! lsmod | grep nouveau
then
    chmod +x /opt/NVIDIA-Linux-x86_64-470.141.03-730.run && /opt/NVIDIA-Linux-x86_64-470.141.03-730.run -s && systemctl set-default graphical.target && reboot
else
    echo "安装失败！nouveau未禁用成功！"
fi