#!/bin/sh

# npm install css-minify svgo && emerge dev-util/uglifyjs media-gfx/scour && cargo install --locked svgcleaner

set -xeuo pipefail

DEBUG="$1"
shift

script_dir=$(realpath $(dirname "$0"))
cd "${script_dir}/.."

which css-minify >>/dev/null || exit 1
which uglifyjs >>/dev/null || exit 1

for i in $(grep --recursive vim:nofixendofline _includes | cut -d ':' -f1) ; do
    if [[ $(wc --lines "$i" | awk '{print $1}') -ne 0 ]] ; then
        echo "unexpected newline in $i"
        exit 1
    fi
done

compress_options="pure_getters"
if [[ "${DEBUG}" -eq 1 ]] ; then
    echo 'DEBUG'
else
    echo 'RELEASE'
    compress_options="${compress_options},drop_console"
    _scripts/prepare.sh
fi

css-minify --dir assets/css/vendor/ --output assets/css/vendor/ &

find assets/js/partials -type f -name '*.js' -print0 | \
    sort --zero-terminated | \
    xargs -0 cat | \
    uglifyjs \
      --validate \
      --mangle \
      --compress "${compress_options}" \
      --output assets/js/main.min.js &

for i in $(find assets/js/vendor -name '*.js' -not -name '*.min.js') ; do
    uglifyjs \
      "$i" \
      --validate \
      --mangle \
      --compress "${compress_options}" \
      --output "${i%*.js}.min.js" &
done

wait

if [[ "${DEBUG}" -eq 1 ]] ; then
    bundle exec jekyll build --drafts --future "$@"
else
    bundle exec jekyll build --future "$@"
fi
