#! /bin/bash -e

for i in $(seq 5); do
  (
    while true; do
      docker run --rm busybox
      docker run --rm alpine
      sleep 1
    done
  )&
done

sleep 10
pkill -f leak.sh
