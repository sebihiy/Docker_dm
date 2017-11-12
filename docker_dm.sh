#!/bin/bash

VP=/dev/sdb
VG=data
 
### thinpool && direct LVM

pvcreate $VP 
vgcreate $VG $VP 
lvcreate --wipesignatures y -n pooldata $VG -l 95%VG
lvcreate --wipesignatures y -n poolmeta $VG -l 1%VG
lvconvert -y --zero n -c 512K --thinpool $VG/pooldata --poolmetadata $VG/poolmeta 

rpm -Uvh https://storebits.docker.com/ee/centos/sub-43f20f5b-6abf-448e-952a-6f1741b31d6e/centos/7/x86_64/stable-17.03/Packages/docker-ee-selinux-17.03.2.ee.7-1.el7.centos.noarch.rpm
rpm -Uvh https://storebits.docker.com/ee/centos/sub-43f20f5b-6abf-448e-952a-6f1741b31d6e/centos/7/x86_64/stable-17.03/Packages/docker-ee-17.03.2.ee.7-1.el7.centos.x86_64.rpm
#### Configuration docker

sed -i -e "s/ExecStart/ExecStart=\/usr\/bin\/dockerd --storage-driver=devicemapper --storage-opt=dm.thinpooldev=\/dev\/mapper\/data-pooldata --storage-opt dm.use_deferred_removal=true --storage-opt dm.use_deferred_deletion=true/g" /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl start docker
systemctl status docker

