#!/usr/bin/env sh

get () {
  sudo -u nobody curl --silent "$@" >>/dev/null
}

for view in events pubkeys ; do
  path="/nostr/spam.nostr.band/spam_api?method=get_current_spam&view=${view}"
  get --insecure --socks5-hostname '127.0.0.1:9050' --header 'origin: http://codonaftbvv4j5k7nsrdivbdblycqrng5ls2qkng6lm77svepqjyxgid.onion' "http://codonaftct3jsouvfyrjq4yumyngzv3el2msndf5oddccktgghnw7eyd.onion${path}"
  get --proxy '127.0.0.1:4444' --header 'origin: http://codonaft.i2p' "http://codnaft43k7ncna2hfsxrzi2nqoxieu22vbyjkmhkwdrrta2ghlq.b32.i2p${path}"
done

get --header 'origin: https://codonaft.com' 'https://media.codonaft.com/torbulkexitlist'
