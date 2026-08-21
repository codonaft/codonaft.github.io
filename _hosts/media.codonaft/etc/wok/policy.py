#!/usr/bin/env python3

from collections import OrderedDict
from time import time
import argparse
import json
import os
import psutil
import sys
import tomllib


ALLOWED_PKS = '/etc/wok/allowed-pks.txt'
MUTED_PKS = '/etc/wok/muted-pks.txt' # TODO: use wok scan + subscribe to kind 10000 instead for all allowed pks? minus the allowed pks themselves?
MAX_MENTIONS = 20
NO_MENTION_KINDS = set([0, 3, 17, 20, 40, 41, 43, 44, 54, 62, 443, 1984, 1985, 2003, 2004, 5128, 10000, 10001, 10002, 10003, 10004, 10005, 10006, 10007, 10008, 10009, 10011, 10012, 10013, 10015, 10020, 10030, 10050, 10051, 10054, 10063, 10064, 10096, 10154, 10312, 13194, 13534, 15128, 17375, 23194, 23195, 24242, 28935, 28936, 30000, 30002, 30003, 30004, 30005, 30006, 30007, 30008, 30009, 30015, 30017, 30018, 30019, 30020, 30023, 34550, 30000, 30003, 30030, 30040, 30041, 30063, 30267, 30311, 30312, 30313, 30402, 30617, 30618, 30818, 30819, 31922, 31923, 31924, 31925, 34235, 34236, 35128, 38383, 39089, 39092, 39701])
MAX_PARENT_EVENTS = 1024
RESTRICTED_KINDS_FOR_ALLOWED_PKS_ONLY = set([1234, 30024, 30078, 30403, 31234])
UPDATE_INTERVAL_MIN = 5

restricted_read_kinds = set()
allowed_pks = set()
muted_pks = set()
parent_events = OrderedDict()


def main():
    print('starting wok write policy filter', file=sys.stderr)
    cmdline = psutil.Process(os.getppid()).cmdline()
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config')
    wok_path = cmdline[0]
    config_path = parser.parse_known_args(cmdline)[0].config

    last_update = update(0, wok_path, config_path)
    for line in sys.stdin:
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            print('invalid JSON', file=sys.stderr)
            continue

        if request.get('type') != 'new':
            print('unexpected request type', file=sys.stderr)
            continue

        last_update = update(last_update, wok_path, config_path)
        try:
            ev = request['event']
            eid = ev['id']
            pk = ev['pubkey']
            k = ev['kind']
            tags = ev['tags']
            content = ev['content']

            allowed_pk = (pk in allowed_pks) or (len(allowed_pks) == 0)
            mentions = set(t[1] for t in tags if len(t) > 1 and t[0] == 'p')
            mentioned = bool(allowed_pks & mentions)

            response = {'id': eid}

            def reject(reason):
                response['action'] = 'reject'
                response['msg'] = f'blocked: {reason}'

            def accept():
                print('accept event', eid, 'kind', k, file=sys.stderr)
                response['action'] = 'accept'
                if eid in parent_events:
                    del parent_events[eid]

            known_parent_event = (eid in parent_events) or bool(set(t[1] for t in tags if len(t) > 1 and t[0] == 'a') & parent_events.keys())

            if (k in (restricted_read_kinds | RESTRICTED_KINDS_FOR_ALLOWED_PKS_ONLY)) and len(mentions) == 0: # FIXME
                reject('restricted event read kinds without p-tags are not supported')
            elif pk in muted_pks:
                reject('muted by admin')
            elif (k in [31989, 31990]) or (['k', 'nym-sync'] in tags) or (['t', 'nym-vouches'] in tags) or (['t', 'nym-presence'] in tags):
                reject('no abuse pls')
            elif allowed_pk and (k in RESTRICTED_KINDS_FOR_ALLOWED_PKS_ONLY):
                accept()
            elif k in restricted_read_kinds:
                accept()
            elif allowed_pk or known_parent_event:
                accept()
                if not known_parent_event:
                    for ref in set(t[1] for t in tags if len(t) > 1 and t[0] in ['a', 'e', 'q']):
                        allow_event(ref)
                    # TODO: spawn req + event? use possible existing t[2] as priority relay?
                    # proc.stdin.write('{...}')
                    # proc.stdin.close()
            elif (k not in NO_MENTION_KINDS) and mentioned:
                if len(mentions) > MAX_MENTIONS:
                    reject('too many mentions')
                else:
                    accept()
            else:
                reject('not on allow-list')
        except Exception as e:
            print(f'failed to parse request {line.strip()}: {e}', file=sys.stderr)
            reject('internal policy error')

        print(json.dumps(response), flush=True)


def update(last_update, wok_path, config_path):
    now = time()
    if now - last_update < UPDATE_INTERVAL_MIN * 60:
        return last_update

    with open(config_path, 'rb') as f:
        config = tomllib.load(f)
        value = set(config['relay']['auth']['restricted_read_kinds']) - RESTRICTED_KINDS_FOR_ALLOWED_PKS_ONLY
        restricted_read_kinds.clear()
        restricted_read_kinds.update(value)

    parse_pks(allowed_pks, ALLOWED_PKS)
    parse_pks(muted_pks, MUTED_PKS) # TODO: use banpubkey when NIP-86 will be ready
    print('currently allowed', len(allowed_pks), 'npubs', file=sys.stderr)
    print('currently muted', len(muted_pks), 'npubs', file=sys.stderr)

    # TODO: subprocess.Popen([wok_path, 'delete', ...], stdin=subprocess.PIPE, stdout=sys.stderr, start_new_session=True)
    # - events by muted authors
    # - scan largest of the oldest restricted_read_kinds events that aren't allowed by author/mention && len(muted_pks) > 0 && diskspace < 2 * database.min_free_disk_bytes

    return now


def allow_event(ref):
    print('allow parent event', ref, file=sys.stderr)
    if len(parent_events) >= MAX_PARENT_EVENTS:
        parent_events.popitem(last=False)
    parent_events[ref] = None


def parse_pks(output, path):
    try:
        with open(path, 'r') as f:
            value = set(i.strip() for i in f.readlines() if len(i.strip()) > 0)
            output.clear()
            output.update(value)
    except Exception as e:
        print(f'cannot parse {path}: {e}', file=sys.stderr)


if __name__ == '__main__':
    main()
