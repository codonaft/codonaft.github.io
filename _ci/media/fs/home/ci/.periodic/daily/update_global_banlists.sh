#!/usr/bin/env bash

# retrieves various block-lists that might create connection issues for some users

BANLISTS="/var/tmp/global_banlists.txt"

NEW="${BANLISTS}.new"
DEDUP="${NEW}.dedup"

echo -n > "${NEW}"

( wget -qO - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts || wget -qO - http://sbc.io/hosts/hosts ) | \
    awk '/Title: Hosts contributed by Steven Black/{p=1; fflush()} p' | \
    grep --line-buffered --invert-match --extended-regexp '(^0.0.0.0 0.0.0.0$|^#)' | \
    grep --line-buffered '^0\.0\.0\.0 ' | \
    awk '{print $2; fflush()}' >> "${NEW}"

wget -qO zapret-info.zip https://github.com/zapret-info/z-i/archive/refs/heads/master.zip
unzip -p zapret-info.zip 'z-i-master/nxdomain.txt' 'z-i-master/dump*.csv' | \
    cat | \
    iconv -fcp1251 | \
    grep --line-buffered --text --invert-match '^Updated: ' | \
    cut -d ';' -f2 | \
    tr '|' '\n' >> "${NEW}"
rm -f zapret-info.zip

sort -u < "${NEW}" | sed '/^$/d' > "${DEDUP}"

[ -s "${DEDUP}" ] && [ $(stat -c "%s" "${DEDUP}") -gt 1 ] && mv -f "${DEDUP}" "${BANLISTS}" && rm -f "${NEW}" && echo "Received banlists update"
