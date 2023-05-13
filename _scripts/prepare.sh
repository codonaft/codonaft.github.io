#!/bin/bash

set -xeuo pipefail

script_dir=$(realpath $(dirname "$0"))
cd "${script_dir}/.."

[ -e vendor ] || {
    rm -rv Gemfile.lock .bundle || :
    gem update bundler
    gem install bundler jekyll
    bundle config set --local path 'vendor/bundle'
    bundle install
}
rm -rv _site* || :
