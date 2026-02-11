ws=wpa_supplicant
sn=$ws@$INTERFACE
systemctl is-active $sn && return
cd /etc/$ws
cf=$ws-$INTERFACE.conf
[ -s $cf ] || { ls -t $ws-*.conf | head -n1 | while read cf0 # $ws interface-specific config missing
                                              do [ -s "$cf0" ] && cp -av $cf0 $cf # copy last-modified config for other interface
                                              done
                [ -s $cf ] || { umask 022 # could not find what to copy
                                egrep -i '(update_config|ctrl_interface)=' /usr/share/doc/wpasupplicant/examples/wpa-roam.conf | sed 's/^#//' > $cf # create empty $cf from a bundled example
                              }
              }
systemctl is-active $ws && { systemctl stop $ws
                             systemctl is-enabled $ws && systemctl disable $ws # stop and disable global $ws
                           }
systemctl --no-block start $sn # start interface-specific $ws
