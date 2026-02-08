for ifn in $(iw dev | awk '$1=="Interface"{print $2}') 
do cf=/etc/wpa_supplicant/wpa_supplicant-$ifn.conf
   [ -s $cf ] || {
    ls -t /etc/wpa_supplicant/wpa_supplicant-*.conf | head -n1 | while read cf0
    do [ -s "$cf0" ] && cp -av $cf0 $cf
    done
    [ -s $cf ] || { umask 022 
     egrep -i '(update_config|ctrl_interface)=' /usr/share/doc/wpasupplicant/examples/wpa-roam.conf | sed 's/^#//' > $cf
    }
   }
   systemctl is-active wpa_supplicant && systemctl stop wpa_supplicant
   systemctl start wpa_supplicant@$ifn
done
