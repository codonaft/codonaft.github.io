#!/usr/bin/env sh

get () {
  sudo -u nobody curl --silent "$@" >>/dev/null
}

get --header 'origin: https://codonaft.com' 'https://media.codonaft.com/torbulkexitlist'
