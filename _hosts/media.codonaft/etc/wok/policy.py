#!/usr/bin/env python3

import json
import sys
import tomllib

ALLOWED_NPUBS = {
    '11b00436df807d4f5ea10d403469bad77f0de1dd6363ced32c65fa31b4786b12',
    '56e4a1fa307c501cd4febe1d08b29c1b5bb8c1be3775dc34c8f302bf3b69cb30',
    '72eb9cb6904ba596383eb264538fc559e2a31149856e6c0f2700ddca7f97fe67',
    '9a21569255d0a3a9e75f1de2e4c883c9be2e5615887f22b2ecf6b1813bcd587d',
    'b7ed68b062de6b4a12e51fd5285c1e1e0ed0e5128cda93ab11b4150b55ed32fc',
    'e681745398e44c2ed67f116a02bc9e53d63d7de5eb26039224486801b0ac3c39',
    'ea91ee2eff0942115b5515bbdbee1259bcf899f8dc79b33d58524d104e3d5eb5',
    'efc2b6e59480f0e55cc87c69af06b6d1a11fa25e4ea95a439878c41799c53c19',
    'efd4d4a38bcd0004d31031a17972a6a6a3b32fe6f3953958c47d6325f2b8d106',
}

MAX_MENTIONS = 20

NO_MENTION_KINDS = [0, 3, 17, 20, 40, 41, 43, 44, 54, 62, 443, 1984, 1985, 2003, 2004, 5128, 10000, 10001, 10002, 10003, 10004, 10005, 10006, 10007, 10008, 10009, 10011, 10012, 10013, 10015, 10020, 10030, 10050, 10051, 10054, 10063, 10064, 10096, 10154, 10312, 13194, 13534, 15128, 17375, 23194, 23195, 24242, 28935, 28936, 30000, 30002, 30003, 30004, 30005, 30006, 30007, 30008, 30009, 30015, 30017, 30018, 30019, 30020, 30023, 34550, 30000, 30003, 30030, 30040, 30041, 30063, 30267, 30311, 30312, 30313, 30402, 30617, 30618, 30818, 30819, 31922, 31923, 31924, 31925, 34235, 34236, 35128, 38383, 39089, 39092, 39701]

print('starting wok policy filter', file=sys.stderr)

restricted_read_kinds = []
with open('/etc/wok/wok.toml', 'rb') as f:
    config = tomllib.load(f)
    restricted_read_kinds = config['relay']['auth']['restricted_read_kinds']

for line in sys.stdin:
    try:
        request = json.loads(line)
    except json.JSONDecodeError:
        print('invalid JSON', file=sys.stderr)
        continue

    if request.get('type') != 'new':
        print('unexpected request type', file=sys.stderr)
        continue

    try:
        response = {'id': request['event']['id']}
        k = request['event']['kind']
        allowed = (request['event']['pubkey'] in ALLOWED_NPUBS) or (len(ALLOWED_NPUBS) == 0)
        mentions = set(t[1] for t in request['event']['tags'] if len(t) > 1 and t[0] == 'p')
        mentioned = bool(ALLOWED_NPUBS & mentions)
        if (k in restricted_read_kinds) or allowed:
            response['action'] = 'accept'
        elif (k not in NO_MENTION_KINDS) and mentioned:
            if len(mentions) > MAX_MENTIONS:
                response['action'] = 'reject'
                response['msg'] = 'blocked: too many mentions'
            else:
                response['action'] = 'accept'
        else:
            response['action'] = 'reject'
            response['msg'] = 'blocked: not on allow-list'
    except Exception as e:
        print(f'failed to parse request {line.strip()}: {e}', file=sys.stderr)
        response['action'] = 'reject'
        response['msg'] = 'blocked: internal policy error'

    print(json.dumps(response), flush=True)
