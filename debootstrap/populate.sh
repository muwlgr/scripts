# you plug in an USB flash with FAT32 volume, you mount it and cd into it in your sh/bash/dash/ash/ksh/zsh shell
# there you run the following script including it into your current session using "."

base=$(df -P . | { read none
                   read a b c d e f
                   echo $f
                 } )
cd $base
pwd

grep ^efivar /proc/mounts && ! [ -d efi ] && mkdir -pv efi # create efi folder under $base if it is absent

#The filesystem is FAT32, so the single file size is limited to 4 GB.
#The  cluster size is 32 KB or 64 logical sectors of 512 bytes each.
#Set the  size limit as 4 GB minus 1 cluster, or 
sz=$((2**22-2**5))K 

type eatmydata && emd=eatmydata # to save time on sync writes

inst=linux
[ -d $inst ] || mkdir -pv $inst
cd $inst
pwd

ghdb=https://raw.githubusercontent.com/muwlgr/scripts/refs/heads/main/debootstrap
[ -f mount-$inst.sh ] || wget $ghdb/mount-$inst.sh

[ -d boot ] || mkdir boot
find boot | egrep -i '(config|initrd\.img|system\.map|vmlinuz)-' | xargs -r rm -v

for i in root swap
do [ -f $i.loop ] || time $emd fallocate -v -l $sz $i.loop    # 8..9 minutes on slow flash
   case $i in swap)  time $emd mkswap    --verbose $i.loop ;; # 2..3 seconds or less
              *)     time $emd mkfs.ext4 -v        $i.loop ;; # 30..31 seconds
   esac
done

target=$(mktemp -d)
mirror=http://mirror.mirohost.net/debian # or what else would you like
dist=stable # trixie or forky if you like

sudo mount -v -o loop root.loop $target

df -h $target # before debootstrap
[ "$emd" ] && dpkg -L $(dpkg-query -f='${Package} ' -W '*'$emd'*' ) | egrep 'bin/|\.so' | sudo tar -T - -cS | sudo tar -C $target -xvpS
time sudo $emd debootstrap $dist $target $mirror # 6..16 minutes on slow flash with eatmydata

GREEN=$(tput setaf 2) # green text
YELLOW=$(tput setaf 3) # yellow text
RESET=$(tput sgr0) # reset text color

while [ $(cat $target/etc/hostname) = $(hostname) ]
do echo $YELLOW'Please enter a different host name for a new instance :'$RESET
   read hn
   sudo sh -c 'echo '$hn' > '$target'/etc/hostname'
done
df -h $target # after debootstrap

tb=$target/boot
sudo mount -v --bind boot $tb # boot folder on FAT
[ -d $base/EFI ] && {
 tbe=$tb/efi
 [ -d $tbe ] || sudo mkdir -pv $tbe
 sudo mount -v --bind $base $tbe
}

for i in host 
do ti=$target/$i
   [ -d $ti ] || sudo mkdir -pv $ti
   sudo mount -v --bind $base $ti
done

fgrep -il proxy /etc/apt/apt.conf.d/* | while read f
do sudo cp -av $f $target/etc/apt/apt.conf.d/
done # copy apt http proxy configuration if present

( cd /tmp
  for i in runme complete-stable
  do wget $ghdb/$i.sh 
     sudo mv -v $i.sh $target/root/ 
  done )

echo invoking $YELLOW$target/root/runme.sh$RESET
echo 'please run 
'$GREEN'. root/complete-stable.sh'$RESET' 
afterwards'
sudo sh $target/root/runme.sh
