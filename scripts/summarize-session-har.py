#!/usr/bin/env python3
"""Summarize DevTools HAR without printing cookies, tokens, or response bodies."""
import argparse
import collections
import json
from urllib.parse import urlsplit


def summarize(har):
    entries = [e for e in har['log']['entries'] if '/s/' in urlsplit(e['request']['url']).path]
    groups = collections.defaultdict(lambda: {'requests': 0, 'transfer': 0, 'knownBody': 0, 'unknownBodyRequests': 0})
    rows = []
    for e in entries:
        path = urlsplit(e['request']['url']).path
        file = path.split('/', 3)[-1] or '(viewer)'
        kind = 'video' if file.endswith('.mp4') else 'json' if file.endswith('.json') else 'images' if file.endswith(('.png', '.jpg')) else 'html'
        response = e['response']
        transfer = response.get('_transferSize', -1)
        body = response.get('bodySize', -1)
        group = groups[kind]
        group['requests'] += 1
        group['transfer'] += max(0, transfer)
        group['knownBody'] += max(0, body)
        group['unknownBodyRequests'] += int(body < 0)
        headers = lambda h: {x['name'].lower(): x['value'] for x in h}
        req, res = headers(e['request']['headers']), headers(response['headers'])
        rows.append({'file': file, 'started': e['startedDateTime'], 'ms': round(e['time'], 2),
                     'wait': round(e['timings'].get('wait', -1), 2), 'status': response['status'],
                     'transfer': transfer, 'body': body, 'range': req.get('range'),
                     'contentRange': res.get('content-range'), 'contentLength': res.get('content-length'),
                     'cache': res.get('cache-control'), 'mime': response['content'].get('mimeType'),
                     'encoding': res.get('content-encoding'), 'cached': e.get('_fromCache'),
                     'error': e.get('_error')})
    return {'groups': dict(groups), 'pages': [{'timings': p.get('pageTimings')} for p in har['log'].get('pages', [])], 'requests': rows}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('har')
    args = parser.parse_args()
    with open(args.har) as f:
        print(json.dumps(summarize(json.load(f)), indent=2))
