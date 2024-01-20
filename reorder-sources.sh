olf=/etc/apt/sources.list
set -- $(lsb_release -c)
echo $2
lf=/etc/apt/sources.list.d/$2.list
tf=$(mktemp)
tf2=$(mktemp)
awk '$1~/^deb/{k=$1" "$2" "$3; 
               s=$4; 
               for(i=5;i<=NF;i++) s=s" "$i; 
               if(k in a) a[k]=a[k]" "s; 
               else a[k]=s }
     END {for(k in a) print k" "a[k] }' $olf | sort -u > $tf
{ [ -f $lf ] && cat $lf
  cat $tf
} | sort -u > $tf2
diff $lf $tf2 || cat $tf2 > $lf
sed -r -i '/^ *deb/s/^/#/' $olf
rm $tf $tf2
