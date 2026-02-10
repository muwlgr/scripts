base=$(df -P $0 | { read none
                    read a b c d e f
                    echo $f
                  } )
cd $(dirname $(realpath $0))
target=$(mktemp -d)
sudo mount -o loop root.loop $target/
tb=$target/boot
sudo mount --bind boot $tb
cd $target
[ -d $base/EFI ] && sudo mount --bind $base $tb/efi
[ -d host ] && sudo mount --bind $base $target/host
df -h $target
sudo ls -l $target/root/runme.sh
GREEN=$(tput setaf 2) # green text
RESET=$(tput sgr0) # reset text color
echo 'run this :
'$GREEN'sudo sh '$target'/root/runme.sh'$RESET
