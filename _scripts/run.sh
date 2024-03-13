#!/bin/sh

DEBUG=1

HOST="127.0.0.1"

script_dir=$(realpath $(dirname "$0"))
cd "${script_dir}/.."

compress_options="pure_getters"
if [[ "$DEBUG" -eq 1 ]] ; then
    echo 'DEBUG'
else
    echo 'RELEASE'
    compress_options="${compress_options},drop_console"
    rm -rfv Gemfile.lock .bundle vendor
    gem update bundler
    gem install bundler jekyll faraday-retry
    bundle config set --local path 'vendor/bundle'
    bundle install
fi

find assets/js/partials -type f -name '*.js' -print0 | \
    sort --zero-terminated | \
    xargs -0 cat | \
    uglifyjs \
      --validate \
      --mangle \
      --compress "${compress_options}" \
      --output assets/js/main.min.js

cat assets/js/vendor/ytdefer.js | uglifyjs \
  --validate \
  --mangle \
  --compress "${compress_options}" \
  --output assets/js/vendor/ytdefer.min.js

if [[ "$DEBUG" -eq 1 ]] ; then
    bundle exec jekyll server --drafts --future --host "${HOST}"
else
    bundle exec jekyll server --future --host "${HOST}"
fi
