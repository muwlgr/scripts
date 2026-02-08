# you plug in an USB flash with FAT32 volume, you mount it and cd into it in your bash shell
# there you run the script

df -h .
grep ^efivar /proc/mounts && ! [ -d efi ] && mkdir -pv efi

#The filesystem is FAT32, so the single file size is limited to 4 GB.
#The  cluster size is 32 KB or 64 logical sectors of 512 bytes each.
#Set the  size limit as 4 GB minus 1 cluster, or 
sz=$((2**22-2**5))K 

type eatmydata && emd=eatmydata # to save time on sync writes
base=$(pwd)

[ -d linux ] || mkdir linux
cd linux

[ -d boot ] || mkdir boot
find boot | egrep -i '(config|initrd\.img|system\.map|vmlinuz)-' | xargs -r rm -v
for i in root home var swap
do [ -f $i.loop ] || time $emd fallocate -l $sz $i.loop # 8..9 minutes on slow flash
   case $i in swap) time $emd mkswap    $i.loop ;; # 2..3 seconds
              *)    time $emd mkfs.ext4 $i.loop ;; # 30..31 seconds
   esac
done
