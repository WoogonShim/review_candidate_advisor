#!/bin/sh
#git rev-list --objects --all | awk '"" != $2' | sort -k2 | uniq -cf1 | sort -rn | 
# grep -E '*.(h|hh|hpp|c|cc|cxx|cpp)$'
git rev-list --since='one month ago' --no-merges --objects --all | grep -E '*.(h|hh|hpp|c|cc|cxx|cpp)$' | awk '"" != $2' | sort -k2 | uniq -cf1 | sort -rn | 
while read frequency sha1 path 
	do 
		[ "blob" == "$(git cat-file -t $sha1)" ] && echo -e "$frequency\t$path"; 
	done

