#!/bin/sh

host=$(hostname)

while read lhost alias profile
do
	if ! [ "$host" = "$lhost" ]; then
		continue
	fi
	echo "$alias $profile"
	taf=".${alias}.b"
	af="${alias}.b"
	if ! perl ./bookmarks.pl --mode=export --profile $profile --output $taf; then
		echo "Export failure!"
		exit 1
	fi
	ls -l $af $taf
	tah=$(openssl sha1 < $taf | awk '{print $2}')
	ah=$(openssl sha1 < $af | awk '{print $2}')
	if [ "$tah" = "$ah" ]; then
		rm $taf
		echo "same hash, not merging $lhost:$alias"
		continue
	fi
	if perl ./bookmarks.pl --mode=merge --upstream $taf --local $af --output .tmp${alias}.b; then
		mv .tmp${alias}.b $af
	else
		echo "Merge error"
	fi
	rm -f $taf .tmp${alias}.b
done < plist
