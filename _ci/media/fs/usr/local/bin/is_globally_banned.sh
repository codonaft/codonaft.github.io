#!/usr/bin/env bash

if [ $# -lt 1 ] ; then
    echo "Usage: $0 host"
    exit 1
fi

BANLISTS="/var/tmp/global_banlists.txt"

host="$1"
pattern=$( ( echo "${host}" ; nslookup "${host}" | tail -n +3 | grep Address: | awk '{print $2}' ) | paste -sd '|' | sed 's!\.!\\.!g')
candidates=$(grep --line-buffered --text -E "(${pattern})$" "${BANLISTS}")

matched=0
for i in ${candidates} ; do
    if [[ "${host}" == ${i} || "www.${host}" == ${i} ]] ; then
        echo "${i}" >> /dev/stderr
        matched=1
    fi
done

[ ${matched} -eq 1 ] && echo -e "\n${host} \033[31mis probably banned\033[0m" >>/dev/stderr
