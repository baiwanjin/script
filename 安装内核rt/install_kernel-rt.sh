#!/bin/bash

rpm -qa|grep tuned-2.10.0-6|xargs rpm -e
rpm -ivh tuna-0.13-9.ky3.kb1.noarch.rpm 
rpm -ivh tuned-2.8.0-5.ky3.noarch.rpm 
rpm -ivh tuned-profiles-realtime-2.8.0-5.ky3.noarch.rpm
rpm -ivh rt-setup-1.59-5.ky3.noarch.rpm
rpm -ivh rtctl-1.13-2.ky3.noarch.rpm
rpm -ivh rt-setup-1.59-5.ky3.noarch.rpm
rpm -ivh kernel-rt-*