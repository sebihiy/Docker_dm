#!/bin/bash
set -ex

DOCKER_STORAGE_PATH=/var/lib/docker
THINPOOL_DEVICE_PATH=/dev/mapper/data-pooldata
THINPOOL_DEVICE_META_PATH=/dev/mapper/data-pooldata_tmeta
layerdb_mounts_path=$DOCKER_STORAGE_PATH/image/devicemapper/layerdb/mounts
metadata_path=$DOCKER_STORAGE_PATH/devicemapper/metadata
mnt_path=$DOCKER_STORAGE_PATH/devicemapper/mnt
image_path=$DOCKER_STORAGE_PATH/image/devicemapper
image_path_diffid=$image_path/distribution/diffid-by-digest/sha256
image_path_diffid_meta=$image_path/distribution/v2metadata-by-diffid/sha256
image_layer=$DOCKER_STORAGE_PATH/image/devicemapper/layerdb/sha256


if ps h -C dockerd; then
echo Please stop the docker daemon
exit 1
fi

test "$1" != "-y " && export DO_THIN_CLEAN=yes
test -v DO_THIN_CLEAN && echo DRY RUN

echo current utilization
lvs $THINPOOL_DEVICE_PATH
echo

# 1. establish the set of untracked container ids in the layerdb
# (container id in layerdb mounts but not in containerdb)
# 2. from those, extract the devicemapper metadata init-id and mount-id
# 3. from those, extract the devicemapper integer device id
# 4. issue devicemapper thinpool delete against the device id
# 5. clean up devicemapper metadata, layerdb mount files, and
# containerdb. containerdb cleanup covers case of historical shm
# mount leak

#dmsetup message $THINPOOL_DEVICE_PATH 0 reserve_metadata_snap

while read leaked_container_id; do
 echo reaping storage for absent container::: $leaked_container_id

    while read metadata_id; do

       echo  " ******************** $metadata_id ******************** "

       device_id=$(awk -F: 'BEGIN {RS= ","} /device_id/ {print $2}' ${metadata_path}/${metadata_id})

       echo  " ***************************** $device_id **************************** "

       #${DO_THIN_CLEAN+echo} 
        dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
       #${DO_THIN_CLEAN+echo} 
       rm -Rf ${metadata_path}/${metadata_id}
       rm -Rf ${metadata_mnt}/${metadata_id}

       echo  "***** thinpool dvicemapper list *****"
      # echo $(thin_ls -m $THINPOOL_DEVICE_META_PATH)
    done < <(grep -h '.*' ${layerdb_mounts_path}/${leaked_container_id}/{init-id,mount-id})

    #${DO_THIN_CLEAN+echo} 
    rm -Rf ${DOCKER_STORAGE_PATH}/containers/${leaked_container_id}
    #${DO_THIN_CLEAN+echo} 
    rm -Rf ${layerdb_mounts_path}/${leaked_container_id}

done < <(comm -23 <(ls ${layerdb_mounts_path}/ | sort) \
                  <(find $DOCKER_STORAGE_PATH -name config.v2.json -printf '%h\n'| awk -F/ '{print $NF}'| sort))

test -v metadata_id || echo "No leaked thin devices found"

echo "**** thinpool devicemapper release ***"

echo
lvs $THINPOOL_DEVICE_PATH

test -v DO_THIN_CLEAN && echo DRY RUN

# metadata image layer

while read metadata_id; do


echo  " ******************** $metadata_id ******************** "
device_id=$(awk -F: 'BEGIN {RS= ","} /device_id/ {print $2}' ${metadata_path}/${metadata_id})

echo  " ***************************** $device_id **************************** "
dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
rm -Rf ${metadata_path}/${metadata_id}
rm -Rf ${metadata_mnt}/${metadata_id}

done < <( grep -h '.*' $image_layer/*/cache-id)

while read device_id; do 
echo " ============ $dm_id =============="

#if [ $device_id != 1 ]; then
#echo  " ******************** $device_id ******************** "
#dmsetup message $THINPOOL_DEVICE_PATH 0 "delete $device_id"
#fi


#done < <( thin_ls -m  $THINPOOL_DEVICE_META_PATH  | awk '{if (NR!=1) {print $1}}')

#dmsetup message $THINPOOL_DEVICE_PATH 0 release_metadata_snap
rm -Rf $image_layer/
