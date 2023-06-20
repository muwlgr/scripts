set -x -e
[ $( id -u ) = 0 ] # fail for non-root
root=$(dirname $(dirname $0))
cd $root 
for i in dev dev/pts proc run sys tmp # var/cache/apt/archives
do mount --bind /$i ./$i 
done 
#mount --bind / ./mnt 
for i in host mnt/host
do [ -d $i ] || continue
   mount --bind / $i
   break
done
chroot . || :
while fgrep $root /proc/mounts
do fgrep $root /proc/mounts | while read h i j
   do umount $i || :
   done 
done
