#!/bin/sh
set -x -e
[ $( id -u ) = 0 ] # fail for non-root
root=$(dirname $(dirname $(realpath $0)))
cd $root
for i in dev dev/pts proc run sys tmp var/cache/apt/archives
do [ -d /$i ] && mount --bind /$i ./$i
done
grep ^efivar /proc/mounts | 
while read a b c 
do mount --bind $b .$b 
done || :
chroot . || :
while fgrep $root/ /proc/mounts
do fgrep $root/ /proc/mounts | while read h i j
   do umount $i || :
   done 
done
