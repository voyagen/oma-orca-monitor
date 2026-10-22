#!/usr/bin/env python3
"""Bounded, read-only Orca snapshots and explicit click-to-focus navigation."""
import json
import math
import os
import selectors
import shutil
import signal
import subprocess
import sys
import time

MAX_BYTES = 4 * 1024 * 1024
MAX_ROWS = 2000
PRIORITY = {'attention': 0, 'interrupted': 1, 'working': 2, 'done': 3, 'ready': 4, 'unknown': 5}


class MonitorError(Exception):
    pass


def run(args, timeout=8):
    """Do not buffer unlimited CLI output or expose its stderr (which can contain secrets)."""
    try:
        process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
    except FileNotFoundError as exc:
        raise MonitorError('missing_cli') from exc
    data = bytearray()
    deadline = time.monotonic() + timeout
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise MonitorError('timeout')
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    break
                data.extend(chunk)
                if len(data) > MAX_BYTES:
                    raise MonitorError('oversized')
        try:
            code = process.wait(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired as exc:
            raise MonitorError('timeout') from exc
        if code:
            raise MonitorError('unavailable')
        return bytes(data)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        process.stdout.close()


def call(*args):
    binary = shutil.which('orca')
    if not binary:
        # Quickshell can predate Orca's CLI registration in the login environment.
        shim = os.path.expanduser('~/.config/orca/linux-orca-cli-shim/orca')
        binary = shim if os.access(shim, os.X_OK) else None
    if not binary:
        raise MonitorError('missing_cli')
    try:
        return json.loads(run([binary, *args, '--json']))
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise MonitorError('invalid_response') from exc


def result(value):
    if not isinstance(value, dict) or value.get('ok') is not True or not isinstance(value.get('result'), dict):
        raise MonitorError('invalid_response')
    return value['result']


def rows(value):
    if not isinstance(value, list) or len(value) > MAX_ROWS or any(not isinstance(x, dict) for x in value):
        raise MonitorError('invalid_response')
    return value


def text(value, limit=180):
    if not isinstance(value, str):
        return ''
    return ' '.join(''.join(c for c in value if c >= ' ' or c in '\n\t').split())[:limit]


def identity(value):
    if not isinstance(value, str) or not value or len(value) > 4096 or any(ord(c) < 32 for c in value):
        return ''
    return value


def timestamp(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) and 0 < value < 1e15 else 0


def terminal_index(payload):
    data = result(payload)
    scope = data.get('hostScope', {})
    covered = scope.get('hostIds', []) if isinstance(scope, dict) else []
    if not isinstance(covered, list):
        raise MonitorError('invalid_response')
    index = {}
    for t in rows(data.get('terminals')):
        host = identity(t.get('executionHostId'))
        key = (identity(t.get('worktreeId')), host,
               identity(t.get('tabId')) + ':' + identity(t.get('leafId')))
        handle = identity(t.get('handle'))
        if host in covered and host and key[0] and handle and t.get('connected') is True and not t.get('orphaned'):
            # Ambiguous duplicate identities must never select an arbitrary terminal.
            index[key] = None if key in index else handle
    return index


def normalize(snapshot, terminals, repositories=None):
    data = result(snapshot)
    repos = {identity(repo.get('id')): repo for repo in rows(result(repositories).get('repos'))} if repositories is not None else {}
    index = terminal_index(terminals)
    terminal_agents = {}
    for terminal in rows(result(terminals).get('terminals')):
        kind = text(terminal.get('agentIdentity'), 40)
        tab, leaf = identity(terminal.get('tabId')), identity(terminal.get('leafId'))
        if not kind or kind == 'shell' or not tab or not leaf or terminal.get('connected') is not True or terminal.get('orphaned'):
            continue
        key = (identity(terminal.get('executionHostId')), identity(terminal.get('worktreeId')))
        terminal_agents.setdefault(key, []).append({
            'paneKey': tab + ':' + leaf, 'agentType': kind,
            'displayName': terminal.get('title'), 'updatedAt': terminal.get('lastOutputAt')})
    projects = {}
    seen_workspaces = set()
    counts = dict.fromkeys(PRIORITY, 0)
    total = 0
    for w in rows(data.get('worktrees')):
        agents = rows(w.get('agents', []))
        wid, host = identity(w.get('worktreeId')), identity(w.get('hostId'))
        if not wid or not host:
            if agents:
                raise MonitorError('invalid_response')
            continue
        if (host, wid) in seen_workspaces:
            continue
        seen_workspaces.add((host, wid))
        # Activity summaries omit some idle agents; terminal discovery fills only missing panes.
        reported_panes = {identity(a.get('paneKey')) for a in agents}
        agents = agents + [a for a in terminal_agents.get((host, wid), []) if a['paneKey'] not in reported_panes]
        items, seen_panes = [], set()
        for a in agents:
            pane = identity(a.get('paneKey'))
            if not pane or pane in seen_panes:
                continue
            seen_panes.add(pane)
            total += 1
            if total > MAX_ROWS:
                raise MonitorError('oversized')
            state = a.get('state')
            if state in ('blocked', 'waiting'):
                state = 'attention'
            elif state == 'done' and a.get('interrupted') is True:
                state = 'interrupted'
            elif state == 'done' and a.get('sessionBoundary') is True:
                state = 'ready'
            elif state not in ('working', 'done'):
                state = 'unknown'
            counts[state] += 1
            kind = text(a.get('agentType'), 40) or 'Agent'
            label = next((text(a.get(k)) for k in ('taskTitle', 'displayName', 'prompt') if text(a.get(k))), kind)
            items.append({'pane': pane, 'workspace': wid, 'type': kind, 'label': label,
                          'state': state, 'tool': text(a.get('toolName'), 40),
                          'since': timestamp(a.get('stateStartedAt')),
                          'activityAt': max(timestamp(a.get('updatedAt')), timestamp(a.get('stateStartedAt'))),
                          'selectable': bool(index.get((wid, host, pane)))})
        if not items:
            continue
        items.sort(key=lambda a: (-a['activityAt'], a['pane']))
        project_key = (host, identity(w.get('repoId')) or wid)
        repo = repos.get(project_key[1], {}) if host == 'local' else {}
        icon = repo.get('repoIcon')
        emoji = text(icon.get('emoji'), 32) if isinstance(icon, dict) and icon.get('type') == 'emoji' else ''
        project = projects.setdefault(project_key, {'name': text(repo.get('displayName')) or text(w.get('repo')) or 'Orca',
                                                   'icon': emoji, 'host': host, 'workspaces': []})
        project['workspaces'].append({'id': wid, 'name': text(w.get('displayName')) or text(w.get('path')),
                                      'branch': text(w.get('branch')).removeprefix('refs/heads/'),
                                      'active': w.get('isActive') is True, 'primary': w.get('isMainWorktree') is True, 'agents': items,
                                      'activityAt': max(timestamp(w.get('lastActivityAt')),
                                                        timestamp(w.get('lastOutputAt')), items[0]['activityAt']),
                                      'state': min((a['state'] for a in items), key=PRIORITY.get)})
    groups = list(projects.values())
    for p in groups:
        p['workspaces'].sort(key=lambda w: (-w['activityAt'], w['name'], w['id']))
    groups.sort(key=lambda p: (-p['workspaces'][0]['activityAt'], p['name'], p['host']))
    warnings = []
    for source in (data, result(terminals)):
        if source.get('truncated') is True and 'truncated' not in warnings:
            warnings.append('truncated')
        scope = source.get('hostScope')
        if not isinstance(scope, dict) or scope.get('omittedHostIds'):
            if 'hosts' not in warnings:
                warnings.append('hosts')
    return {'version': 1, 'projects': groups, 'counts': counts, 'total': total,
            'warnings': warnings, 'observedAt': int(time.time() * 1000)}


def snapshot():
    worktrees, terminals = call('worktree', 'ps'), call('terminal', 'list')
    try:
        repositories = call('repo', 'list')
    except MonitorError:
        repositories = None
    return normalize(worktrees, terminals, repositories)


def focus(workspace_id, pane_key):
    # Re-resolve both status and handle: never reuse a handle from a stale popup.
    summary = result(call('worktree', 'ps'))
    matches = [identity(w.get('hostId')) for w in rows(summary.get('worktrees'))
               if w.get('worktreeId') == workspace_id]
    if len(matches) != 1:
        raise MonitorError('gone')
    host = matches[0]
    handle = terminal_index(call('terminal', 'list')).get((workspace_id, host, pane_key))
    if not handle:
        raise MonitorError('gone')
    result(call('terminal', 'switch', '--terminal', handle))
    # Only raise an existing Orca window; never launch or type into a terminal.
    try:
        run(['hyprctl', 'dispatch', 'hl.dsp.focus({ window = "class:^orca$" })'], timeout=3)
    except MonitorError:
        run(['hyprctl', 'dispatch', 'focuswindow', 'class:^orca$'], timeout=3)


def main():
    try:
        if len(sys.argv) == 4 and sys.argv[1] == 'focus':
            focus(sys.argv[2], sys.argv[3])
            output = {'ok': True}
        elif len(sys.argv) == 1:
            output = {'ok': True, 'snapshot': snapshot()}
        else:
            raise MonitorError('invalid_request')
    except MonitorError as exc:
        output = {'ok': False, 'error': str(exc)}
    except (OSError, ValueError, TypeError, RecursionError):
        output = {'ok': False, 'error': 'invalid_response'}
    print(json.dumps(output, ensure_ascii=True, allow_nan=False), flush=True)


if __name__ == '__main__':
    main()
