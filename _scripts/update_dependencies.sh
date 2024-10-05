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

HLS_VERSION="1.5.15"
wget -q "https://cdn.jsdelivr.net/npm/hls.js@${HLS_VERSION}/dist/hls.min.js" -O 'assets/js/vendor/hls.min.js' &
wget -q "https://cdn.jsdelivr.net/npm/hls.js@${HLS_VERSION}/dist/hls.min.js.map" -O 'assets/js/vendor/hls.min.js.map' &

# https://www.jsdelivr.com/package/npm/p2p-media-loader-core?tab=files&path=dist
# https://www.jsdelivr.com/package/npm/p2p-media-loader-hlsjs?tab=files&path=dist
#P2P_MEDIA_LOADER_VERSION="1.0.5"
P2P_MEDIA_LOADER_VERSION="2.0.1"
wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-core@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-core.es.min.js" -O 'assets/js/vendor/p2p-media-loader-core.es.min.js' &
wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-core@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-core.es.min.js.map" -O "assets/js/vendor/p2p-media-loader-core.es.min.js.map" &

wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-hlsjs@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-hlsjs.es.min.js" -O "assets/js/vendor/p2p-media-loader-hlsjs.es.min.js" &
wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-hlsjs@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-hlsjs.es.min.js.map" -O "assets/js/vendor/p2p-media-loader-hlsjs.es.min.js.map" &

#wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-core@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-core.es.js" -O 'assets/js/vendor/p2p-media-loader-core.es.js' &
#wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-core@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-core.es.js.map" -O "assets/js/vendor/p2p-media-loader-core.es.js.map" &
#
#wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-hlsjs@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-hlsjs.es.js" -O "assets/js/vendor/p2p-media-loader-hlsjs.es.js" &
#wget -q "https://cdn.jsdelivr.net/npm/p2p-media-loader-hlsjs@${P2P_MEDIA_LOADER_VERSION}/dist/p2p-media-loader-hlsjs.es.js.map" -O "assets/js/vendor/p2p-media-loader-hlsjs.es.js.map" &


#git clone https://github.com/codonaft/vidstack-player vidstack-player
#cd vidstack-player
#git checkout 5f1d317944d0d4fa8a772a15e83a4996fbe727a2
#pnpm i
#pnpm build:vidstack
#cd ..
#rsync -a -v --delete packages/vidstack/dist-npm/cdn/with-layouts/ assets/js/vendor/vidstack-player/
#mkdir -p assets/css/vendor/vidstack-player
#cp -vf ./packages/vidstack/dist-npm/player/styles/default/theme.css ./packages/vidstack/dist-npm/player/styles/default/layouts/video.css assets/css/vendor/vidstack-player/

wait
