#!/bin/bash

set -ex

######################## VAR EVV PATH ###################################################################
THINPOOL_DEVICE_PATH=/dev/mapper/data-pooldata
THINPOOL_DEVICE_META_PATH=/dev/mapper/data-pooldata_tmeta
DOCKER_STORAGE_PATH=/var/lib/docker
DM_IMAGE_PATH==$DOCKER_STORAGE_PATH/image/devicemapper
DM_PATH=$DOCKER_STORAGE_PATH/devicemapper


echo current utilization devicemapper size
lvs $THINPOOL_DEVICE_PATH

##########################################################################################################
###### Remove Containers , images and Volumes

if [ $(docker ps -aq | wc -l) != 0 ] ; then
echo -e "\n\n-- Removing all existing containers  --\n"
docker stop $(docker ps -aq)
docker rm -f $(docker ps -aq)
fi

if [ $(docker images -aq | wc -l) != 0 ] ; then
echo -e "\n\n-- Removing all existing images --\n"
docker rmi  -f $(docker images -aq)
fi

if [ $(ls $DOCKER_STORAGE_PATH/volumes | wc -l) != 1 ] ; then
echo -e "\n\n-- Removing volume directories --\n"
docker volume rm $(docker volume ls --quiet --filter="dangling=true")
fi


if ps h -C dockerd; then
echo Please stop the docker daemon systemctl stop Docker
systemctl stop docker
#exit 1
fi


dmsetup message $THINPOOL_DEVICE_PATH 0 reserve_metadata_snap

echo List Device Mapper before remove
thin_ls -m $THINPOOL_DEVICE_META_PATH


######## remove all

# 1./ remove all containers
rm -Rf $DOCKER_STORAGE_PATH/containers/

# 2./ Delete all metadata except three files
cd $DM_PATH/metadata/
delmeta="-f !(base|deviceset-metadata|transaction-metadata)"
rm $delmeta

# 3./ remove all mount layerdb
rm -Rf $DM_PATH/mnt/

# 4./ remove content  of  image
rm -Rf $DM_IMAGE_PATH/imagedb/content/sha256/

# 5./  remove metadata of image and devicemapper
rm -Rf $DM_IMAGE_PATH/imagedb/metadata/sha256/

# 6./  remove mount layer image
rm -Rf $DM_IMAGE_PATH/layerdb/mounts/

# 7./  Remove layer for image
rm -Rf $DM_IMAGE_PATH/layerdb/sha256/

# 8./ remove cache of image
rm -Rf $DM_IMAGE_PATH/distribution/diffid-by-digest/

# 9./ remove metadat of cache image
rm -Rf  $DM_IMAGE_PATH/distribution/v2metadata-by-diffid/

#  10./ remove metatadata for repositorie of images
rm -f  $DM_IMAGE_PATH/repositories.json

###### Clean All  Devicemapper Except devicemapper with the  id equal 1

while read device_id; do
echo " device_id : $device_id"

if [ $device_id != 1 ]; then
echo  " device_id : $device_id "
dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
fi

done < <( thin_ls -m  $THINPOOL_DEVICE_META_PATH  | awk '{if (NR!=1) {print $1}}')

systemctl start  docker && systemctl status docker

dmsetup message $THINPOOL_DEVICE_PATH 0 release_metadata_snap


### Testing if Devicemapper is cleaned #####################
dmsetup message $THINPOOL_DEVICE_PATH 0 reserve_metadata_snap
echo List Device Mapper after  remove
thin_ls -m $THINPOOL_DEVICE_META_PATH
dmsetup message $THINPOOL_DEVICE_PATH 0 release_metadata_snap
############################################################
## show devicemapper size
docker info | grep Space

