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

echo -e "\n\n-- Removing all existing containers  --\n"
docker stop $(docker ps -aq) && docker rm -f $(docker ps -aq)

echo -e "\n\n-- Removing all existing images --\n"
docker rmi  -f $(docker images -aq)

echo -e "\n\n-- Removing volume directories --\n"
docker volume rm $(docker volume ls --quiet --filter="dangling=true")
#######################################################################

#####  remove  metadata wich images do not existe

while read image_id; do
echo " id imagedb does not existe :  $image_id"
rm -f $DM_IMAGE_PATH/imagedb/content/sha256/$image_id*
done < <(comm  -3 <(docker images -aq | sort) <(ls $DM_IMAGE_PATH/imagedb/content/sha256  |  awk '{print substr ($0, 0, 12)}'))

if ps h -C dockerd; then
echo Please stop the docker daemon <systemctl stop Docker 
systemctl docker stop
#exit 1
fi

echo

############## Clean devicemapper for the containers do not exist <docker ps -aq >
#
# 1. establish the set of untracked container_id in the layerdb (container id in layerdb mounts but not in containerdb)
# 2. from those, extract the devicemapper metadata init-id and mount-id
# 3. from those, extract the devicemapper integer device id
# 4. issue devicemapper thinpool delete against the device id
# 5. clean up devicemapper metadata, layerdb mount files, and containerdb. containerdb cleanup covers case of historical shm

#dmsetup message $THINPOOL_DEVICE_PATH 0 reserve_metadata_snap

while read leaked_container_id; do
 echo reaping storage for absent container::: $leaked_container_id

    while read metadata_id; do

       echo  "metadata_id :  $metadata_id "
	   
       device_id=$(awk -F: 'BEGIN {RS= ","} /device_id/ {print $2}' ${DM_PATH/metadata}/${metadata_id})
	   
       echo  "device_id :  $device_id "

        dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
       rm -Rf ${DM_PATH/metadata}/${metadata_id}
       rm -Rf ${DM_PATH/mnt}/${metadata_id}

    done < <(grep -h '.*' ${DM_IMAGE_PATH/layerdb/mounts}/${leaked_container_id}/{init-id,mount-id})

 rm -Rf ${DOCKER_STORAGE_PATH}/containers/${leaked_container_id}
 rm -Rf ${DM_IMAGE_PATH/layerdb}/mounts/${leaked_container_id}

done < <(comm -23 <(ls ${DM_IMAGE_PATH/layerdb}/mounts/ | sort) \
                  <(find $DOCKER_STORAGE_PATH -name config.v2.json -printf '%h\n'| awk -F/ '{print $NF}'| sort))

test -v metadata_id || echo "No leaked thin devices found"

echo
lvs $THINPOOL_DEVICE_PATH

######## Clean devicemapper for the images  do not exist < docker images -aq>
#
# if image deleted but the layer always exist (./image/devicemapper/layerdb/sha256/)
# extract  the id layer and in the recover metadata id
# in metadat extract device_id
# if device_id existe in devicemapper delete it
# and delete metatdata in  ${DM_PATH/metadata}/${metadata_id}, ${metadata_mnt}/${metadata_id}

while read layer_id; do

echo "layer_id : $layer_id"
metadata_id=$(cat $DM_IMAGE_PATH/layerdb/sha256/$layer_id/cache-id)
echo  "**************  metadata_id : $metadata_id "
device_id=$(awk -F: 'BEGIN {RS= ","} /device_id/ {print $2}' ${DM_PATH/metadata}/${metadata_id})
echo  " device_id : $device_id "
dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
rm -Rf ${DM_PATH/metadata}/${metadata_id}
rm -Rf ${DM_PATH/mnt}/${metadata_id}
rm -Rf $DM_IMAGE_PATH/layerdb/sha256/$layer_id

done < <(ls $DM_IMAGE_PATH/layerdb/sha256/)

rm -Rf $DM_IMAGE_PATH/distribution/diffid-by-digest/*
rm -Rf $DM_IMAGE_PATH/distribution/v2metadata-by-diffid/*
rm -f $DM_IMAGE_PATH/repositories.json

systemctl start  docker && systemctl status docker
echo  thin_ls -m $THINPOOL_DEVICE_META_PATH

###### Clean All  Devicemapper Except devicemapper with the  id equal 1

while read device_id; do
echo " device_id : $device_id"

if [ $device_id != 1 ]; then
echo  " device_id : $device_id "
dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
fi

done < <( thin_ls -m  $THINPOOL_DEVICE_META_PATH  | awk '{if (NR!=1) {print $1}}')

#dmsetup message $THINPOOL_DEVICE_PATH 0 release_metadata_snap
