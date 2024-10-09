#!/bin/bash

set -xeuo pipefail

HOST=mirror

script_dir=$(realpath $(dirname "$0"))
cd "${script_dir}/../.."

_ci/prepare.sh

debug="${1:-0}" # 0 is default
_ci/build.sh "${debug}"
_ci/build.sh "${debug}" --config _config.yml,_config.mirror.yml --destination _site_mirror

rsync -a -v --delete _site_mirror/ "${HOST}:/home/codonaft/"

# TODO: chattr +i /etc/conf.d/nginx
# chmod / chown - ensure permissions are correct
