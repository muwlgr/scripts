#!/bin/sh
set -x
[ $( id -u ) = 0 ] || exit 1
root=$( dirname $0 | sed 's/root.*//' )
cd $root &&
for i in dev dev/pts proc run sys tmp var/cache/apt/archives
do mount --bind /$i ./$i || exit 1
done &&
grep ^efivar /proc/mounts | 
while read a b c 
do mount --bind $b .$b 
done
chroot .
while [ $(fgrep -c $root /proc/mounts) -gt 0 ]
do fgrep $root /proc/mounts | while read h i j
   do umount $i
   done 
done
