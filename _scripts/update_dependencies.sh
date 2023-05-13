#!/bin/bash

set -eux

script_dir=$(realpath $(dirname "$0"))
cd "${script_dir}/.."

# https://github.com/majodev/google-webfonts-helper https://gwfh.mranftl.com/fonts
api='https://gwfh.mranftl.com/api/fonts/'

# FIXME: https://github.com/majodev/google-webfonts-helper/issues/184
wget 'https://fonts.gstatic.com/s/notocoloremoji/v30/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.2.woff2' -qO 'assets/fonts/noto-color-emoji-v30-emoji-regular.woff2' &

font_uris=(
    #'noto-color-emoji?download=zip&subsets=emoji&variants=regular' # FIXME: https://github.com/majodev/google-webfonts-helper/issues/184
    'open-sans?download=zip&subsets=cyrillic,latin&variants=700,regular'
    'roboto?download=zip&subsets=cyrillic,latin&variants=100,300'
    'roboto-condensed?download=zip&subsets=cyrillic,latin&variants=regular'
)

for i in "${font_uris[@]}" ; do
    wget -qO - "${api}${i}&formats=woff2" | bsdtar -xvf- -C 'assets/fonts' &
done

# https://esm.sh/franc-min@6?bundle
wget -q 'https://esm.sh/v135/franc-min@6.2.0/es2022/franc-min.bundle.mjs' -O 'assets/js/vendor/franc-min.min.js' &
wget -q 'https://esm.sh/v135/franc-min@6.2.0/es2022/franc-min.bundle.mjs.map' -O 'assets/js/vendor/franc-min.min.js.map' &

wait
