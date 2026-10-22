import copy
import unittest
import sys
from unittest.mock import patch

import monitor


def envelope(**values):
    return {'ok': True, 'result': values}


def workspace(**values):
    return dict(worktreeId='repo::/project', repoId='repo', repo='Project', hostId='local',
                displayName='Main', branch='refs/heads/main', isActive=True,
                agents=[], **values)


def agent(key='tab:leaf', state='working', **values):
    return dict(paneKey=key, state=state, agentType='pi', prompt='Fix a bug',
                stateStartedAt=1000, **values)


def terminals(**values):
    row = dict(handle='term_live', worktreeId='repo::/project', executionHostId='local',
               tabId='tab', leafId='leaf', connected=True)
    row.update(values)
    return envelope(terminals=[row], hostScope={'hostIds': ['local'], 'omittedHostIds': []})


class NormalizeTests(unittest.TestCase):
    def normalize(self, rows, ts=None, **extra):
        return monitor.normalize(envelope(worktrees=rows, **extra), ts or terminals())

    def test_live_agent_terminals_missing_from_activity_summary_are_included_once(self):
        row = workspace()
        row['agents'] = [agent()]
        ts = terminals()
        extra = dict(ts['result']['terminals'][0], tabId='idle', leafId='agent',
                     handle='term_idle', agentIdentity='pi', title='Pi idle session', lastOutputAt=5000)
        ts['result']['terminals'] += [extra, dict(extra)]
        group = self.normalize([row], ts)['projects'][0]
        agents = group['workspaces'][0]['agents']
        self.assertEqual(len(agents), 2)
        idle = next(a for a in agents if a['pane'] == 'idle:agent')
        self.assertEqual((idle['type'], idle['label'], idle['state']), ('pi', 'Pi idle session', 'unknown'))
        self.assertFalse(idle['selectable'])  # Duplicate terminal identities are unsafe to navigate.
        ts['result']['terminals'].pop()
        result = self.normalize([row], ts)
        self.assertEqual(result['total'], 2)
        self.assertEqual(result['counts']['unknown'], 1)
        self.assertTrue(result['projects'][0]['workspaces'][0]['agents'][0]['selectable'])
        row['agents'] = []
        self.assertEqual(self.normalize([row], ts)['total'], 1)

    def test_terminal_fallback_ignores_shells_disconnected_and_orphaned_sessions(self):
        row = workspace()
        for changes in [{}, {'agentIdentity': 'pi', 'connected': False},
                        {'agentIdentity': 'pi', 'orphaned': True}, {'agentIdentity': 'shell'}]:
            with self.subTest(changes=changes):
                self.assertEqual(self.normalize([row], terminals(**changes))['total'], 0)

    def test_project_metadata_refreshes_names_and_configured_emoji(self):
        row = workspace()
        row['agents'] = [agent()]
        repos = envelope(repos=[{'id': 'repo', 'displayName': 'Renamed project',
                                 'repoIcon': {'type': 'emoji', 'emoji': '✈️'}}])
        group = monitor.normalize(envelope(worktrees=[row]), terminals(), repos)['projects'][0]
        self.assertEqual(group['name'], 'Renamed project')
        self.assertEqual(group['icon'], '✈️')
        self.assertEqual(group['workspaces'][0]['name'], 'Main')
        repos['result']['repos'][0].update(displayName='Changed again', repoIcon=None)
        group = monitor.normalize(envelope(worktrees=[row]), terminals(), repos)['projects'][0]
        self.assertEqual(group['name'], 'Changed again')
        self.assertEqual(group['icon'], '')

    def test_project_metadata_does_not_load_icon_urls_or_override_remote_projects(self):
        row = workspace()
        row['agents'] = [agent()]
        repos = envelope(repos=[{'id': 'repo', 'displayName': 'Local project',
                                 'repoIcon': {'type': 'image', 'url': 'https://example.invalid/icon.svg'}}])
        group = monitor.normalize(envelope(worktrees=[row]), terminals(), repos)['projects'][0]
        self.assertEqual(group['icon'], '')
        row['hostId'] = 'remote'
        group = monitor.normalize(envelope(worktrees=[row]), terminals(), repos)['projects'][0]
        self.assertEqual(group['name'], 'Project')

    def test_recent_agent_activity_overrides_attention_without_hiding_workspace_status(self):
        row = workspace()
        row['agents'] = [agent('c:c', 'waiting', updatedAt=2000),
                         agent(updatedAt=3000), agent('b:b', 'done', updatedAt=4000)]
        result = self.normalize([row])
        self.assertEqual(result['total'], 3)
        self.assertEqual(result['counts']['attention'], 1)
        card = result['projects'][0]['workspaces'][0]
        self.assertEqual([a['state'] for a in card['agents']], ['done', 'working', 'attention'])
        self.assertEqual(card['state'], 'attention')
        self.assertEqual(card['branch'], 'main')

    def test_projects_and_workspaces_follow_their_most_recent_activity(self):
        rows = []
        for wid, repo, state, updated, visited, output in [
            ('old', 'Alpha', 'waiting', 2000, 0, 0),
            ('visit', 'Beta', 'done', 3000, 7000, 0),
            ('output', 'Beta', 'done', 4000, 0, 8000),
            ('agent', 'Gamma', 'done', 9000, 0, 0),
        ]:
            row = workspace(lastActivityAt=visited, lastOutputAt=output)
            row.update(worktreeId=wid, repoId=repo, repo=repo, displayName=wid,
                       agents=[agent(state=state, updatedAt=updated)])
            rows.append(row)
        groups = self.normalize(rows)['projects']
        self.assertEqual([p['name'] for p in groups], ['Gamma', 'Beta', 'Alpha'])
        self.assertEqual([w['id'] for w in groups[1]['workspaces']], ['output', 'visit'])

    def test_activity_falls_back_to_state_start_and_rejects_invalid_timestamps(self):
        for invalid in [None, '9000', True, -1, float('nan'), float('inf'), 1e15]:
            with self.subTest(invalid=invalid):
                row = workspace(lastActivityAt=invalid, lastOutputAt=invalid)
                fallback = agent('z:z', 'done', updatedAt=invalid)
                fallback['stateStartedAt'] = 6000
                row['agents'] = [agent('a:a', 'working', updatedAt=5000), fallback]
                card = self.normalize([row])['projects'][0]['workspaces'][0]
                self.assertEqual([a['pane'] for a in card['agents']], ['z:z', 'a:a'])
                self.assertEqual(card.get('activityAt'), 6000)

    def test_equal_activity_keeps_deterministic_order_when_input_is_reversed(self):
        row = workspace()
        row['agents'] = [agent('b:b', 'done', updatedAt=3000), agent('a:a', updatedAt=3000)]
        first = self.normalize([row])['projects']
        row['agents'].reverse()
        second = self.normalize([row])['projects']
        self.assertEqual(first, second)
        self.assertEqual([a['pane'] for a in first[0]['workspaces'][0]['agents']], ['a:a', 'b:b'])

    def test_primary_badge_requires_explicit_main_worktree_flag(self):
        for flag, expected in [(True, True), (False, False), (None, False), ('true', False)]:
            row = workspace(isMainWorktree=flag)
            row['agents'] = [agent()]
            item = self.normalize([row])['projects'][0]['workspaces'][0]
            self.assertEqual(item.get('primary'), expected)

    def test_navigation_identity_joins_workspace_host_and_leaf(self):
        row = workspace()
        row['agents'] = [agent()]
        self.assertTrue(self.normalize([row])['projects'][0]['workspaces'][0]['agents'][0]['selectable'])
        for changes in [{'worktreeId': 'other'}, {'executionHostId': 'remote'},
                        {'leafId': 'other'}, {'connected': False}, {'orphaned': True}]:
            result = self.normalize([row], terminals(**changes))
            self.assertFalse(result['projects'][0]['workspaces'][0]['agents'][0]['selectable'])

    def test_done_does_not_hide_interrupted_or_session_boundary(self):
        row = workspace()
        row['agents'] = [agent('a:a', 'done', interrupted=True),
                         agent('b:b', 'done', sessionBoundary=True)]
        result = self.normalize([row])
        self.assertEqual([a['state'] for a in result['projects'][0]['workspaces'][0]['agents']],
                         ['interrupted', 'ready'])

    def test_unknown_state_and_plain_shell_are_not_working(self):
        row = workspace()
        row['agents'] = [agent(state='future-state')]
        shell = workspace(workspaceKind='folder-workspace')
        shell['worktreeId'] = 'shell::/other'
        result = self.normalize([shell, row])
        self.assertEqual(result['total'], 1)
        self.assertEqual(result['counts']['unknown'], 1)
        self.assertEqual(len(result['projects'][0]['workspaces']), 1)

    def test_labels_remain_plain_and_bounded_and_private_details_are_omitted(self):
        row = workspace()
        row['agents'] = [agent(taskTitle='<img src="https://example.invalid">\n' + 'x' * 1000,
                              toolInput='SECRET', lastAssistantMessage='PRIVATE')]
        result = self.normalize([row])
        a = result['projects'][0]['workspaces'][0]['agents'][0]
        self.assertTrue(a['label'].startswith('<img'))
        self.assertLessEqual(len(a['label']), 180)
        self.assertNotIn('\n', a['label'])
        self.assertNotIn('SECRET', str(result))
        self.assertNotIn('PRIVATE', str(result))

    def test_truncation_and_host_omission_are_visible(self):
        result = self.normalize([], truncated=True,
                                hostScope={'hostIds': ['local'], 'omittedHostIds': ['remote']})
        self.assertIn('truncated', result['warnings'])
        self.assertIn('hosts', result['warnings'])

    def test_bad_envelopes_and_shapes_are_errors_not_empty_success(self):
        for value in [None, {}, {'ok': False}, envelope(), envelope(worktrees={}),
                      envelope(worktrees=[None]), envelope(worktrees=[{'agents': 'bad'}])]:
            with self.subTest(value=value), self.assertRaises(monitor.MonitorError):
                monitor.normalize(value, terminals())

    def test_duplicate_rows_cannot_duplicate_agents(self):
        row = workspace()
        row['agents'] = [agent(), agent()]
        result = self.normalize([row, copy.deepcopy(row)])
        self.assertEqual(result['total'], 1)

    def test_archived_sessions_stay_visible_if_they_have_agents(self):
        row = workspace()
        row['isArchived'] = True
        row['agents'] = [agent()]
        self.assertEqual(self.normalize([row])['total'], 1)

    def test_missing_terminal_scope_cannot_enable_navigation(self):
        row = workspace()
        row['agents'] = [agent()]
        ts = terminals()
        del ts['result']['hostScope']
        self.assertFalse(self.normalize([row], ts)['projects'][0]['workspaces'][0]['agents'][0]['selectable'])


class TransportTests(unittest.TestCase):
    def test_reads_real_process_output(self):
        self.assertEqual(monitor.run([sys.executable, '-c', 'print("hello")']), b'hello\n')

    def test_timeout_terminates_process(self):
        with self.assertRaisesRegex(monitor.MonitorError, 'timeout'):
            monitor.run([sys.executable, '-c', 'import time; time.sleep(5)'], timeout=0.05)

    def test_oversized_output_is_rejected(self):
        with self.assertRaisesRegex(monitor.MonitorError, 'oversized'):
            monitor.run([sys.executable, '-c', 'import sys; sys.stdout.write("x" * 5000000)'])

    def test_nonzero_exit_is_not_success(self):
        with self.assertRaisesRegex(monitor.MonitorError, 'unavailable'):
            monitor.run([sys.executable, '-c', 'raise SystemExit(2)'])

    def test_focus_re_resolves_handle_and_only_switches_explicit_target(self):
        row = workspace()
        row['agents'] = [agent()]
        replies = [envelope(worktrees=[row]), terminals(), envelope()]
        with patch.object(monitor, 'call', side_effect=replies) as call, patch.object(monitor, 'run') as run:
            monitor.focus('repo::/project', 'tab:leaf')
            self.assertEqual(call.call_args_list[-1].args, ('terminal', 'switch', '--terminal', 'term_live'))
            run.assert_called_once_with(['hyprctl', 'dispatch', 'hl.dsp.focus({ window = "class:^orca$" })'], timeout=3)

    def test_focus_can_open_live_agent_missing_from_activity_summary(self):
        replies = [envelope(worktrees=[workspace()]), terminals(agentIdentity='pi'), envelope()]
        with patch.object(monitor, 'call', side_effect=replies) as call, patch.object(monitor, 'run'):
            monitor.focus('repo::/project', 'tab:leaf')
            self.assertEqual(call.call_args_list[-1].args, ('terminal', 'switch', '--terminal', 'term_live'))

    def test_missing_target_cannot_send_a_switch(self):
        with patch.object(monitor, 'call', return_value=envelope(worktrees=[])) as call:
            with self.assertRaisesRegex(monitor.MonitorError, 'gone'):
                monitor.focus('missing', 'tab:leaf')
            self.assertEqual(call.call_count, 1)

    def test_ambiguous_terminal_identity_cannot_focus(self):
        data = terminals()
        duplicate = copy.deepcopy(data['result']['terminals'][0])
        duplicate['handle'] = 'term_other'
        data['result']['terminals'].append(duplicate)
        self.assertIsNone(monitor.terminal_index(data)[('repo::/project', 'local', 'tab:leaf')])


if __name__ == '__main__':
    unittest.main()
