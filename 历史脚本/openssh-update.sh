#!/bin/bash

##适用于centos7.5 7.4版本的openssh升级至9.0p1 #受影响的服务 mssql
work=$PWD

#依赖安装
install_relyon(){
    cd $work
    rpm -Uvh gcc/* --nodeps
    rpm -Uvh libselinux-devel/* --nodeps
    rpm -Uvh pam-devel/* --nodeps
    rpm -Uvh zlib-devel/* --nodeps
}

update_perl(){
    cd $work
    tar -xzvf perl-5.30.1.tar.gz
    cd perl-5.30.1
    ./Configure -des -Dprefix=$HOME/localperl
    make && make install
}

update_openssl(){
    cd $work
    rpm -qa|grep ^openssl-1|xargs rpm -e --nodeps
    tar -xzvf openssl-1.1.1l.tar.gz
    cd openssl-1.1.1l
    ./config
    make && make install
    ln -s /usr/local/lib64/libssl.so.1.1 /usr/lib64/
    ln -s /usr/local/lib64/libcrypto.so.1.1 /usr/lib64/
    \cp /usr/local/bin/openssl /usr/bin/openssl
}

update_openssh(){
    cd $work
    \cp /etc/ssh/sshd_config .
    rpm -qa|grep ^openssh|xargs rpm -e --nodeps
    \cp -r /etc/ssh /etc/ssh.old-`date +"%Y%m%d%H%M%S"`
    tar -xzvf openssh-9.0p1.tar.gz
    cd openssh-9.0p1
    ./configure --prefix=/usr/local/openssh --with-zlib=/usr/local/zlib --with-ssl-dir=/usr/local/ssl
    make && make install
    \cp sshd_config /usr/local/openssh/etc/sshd_config
    echo 'PermitRootLogin yes' >>/usr/local/openssh/etc/sshd_config
    echo 'PubkeyAuthentication yes' >>/usr/local/openssh/etc/sshd_config
    echo 'PasswordAuthentication yes' >>/usr/local/openssh/etc/sshd_config
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    \cp /usr/local/openssh/etc/sshd_config /etc/ssh/sshd_config
    mv /usr/sbin/sshd /usr/sbin/sshd.bak
    \cp /usr/local/openssh/sbin/sshd /usr/sbin/sshd
    mv /usr/bin/ssh /usr/bin/ssh.bak
    \cp /usr/local/openssh/bin/ssh /usr/bin/ssh
    mv /usr/bin/ssh-keygen /usr/bin/ssh-keygen.bak
    \cp /usr/local/openssh/bin/ssh-keygen /usr/bin/ssh-keygen
    mv /etc/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub.bak
    \cp /usr/local/openssh/etc/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ecdsa_key.pub
    cd $work
    \cp sshd.service /usr/lib/systemd/system/
    chmod 600 /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ed25519_key
    systemctl daemon-reload
    systemctl enable sshd.service 
    echo "SSH_USE_STRONG_RNG=0" > /etc/sysconfig/sshd
    systemctl start sshd.service 

}
install_relyon
update_perl
update_openssl
update_openssh