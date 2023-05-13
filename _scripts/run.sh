#!/bin/sh

# npm install css-minify svgo && emerge dev-util/uglifyjs media-gfx/scour && cargo install --locked svgcleaner

DEBUG=1

HOST="127.0.0.1"
#HOST="0.0.0.0"

script_dir=$(realpath $(dirname "$0"))
cd "${script_dir}/.."

[ -e vendor ] || _scripts/prepare.sh
_scripts/build.sh "${DEBUG}"

if [[ "${DEBUG}" -eq 1 ]] ; then
    bundle exec jekyll server --drafts --future --host "${HOST}"
else
    bundle exec jekyll server --future --host "${HOST}"
fi
