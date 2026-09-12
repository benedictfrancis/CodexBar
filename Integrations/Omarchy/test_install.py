import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class InstallTests(unittest.TestCase):
    def test_reinstall_preserves_layout_and_keeps_backups_out_of_discovery(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary)
            shell = config / 'omarchy' / 'shell.json'
            shell.parent.mkdir()
            shell.write_text(json.dumps({'bar': {'layout': {'right': [{'id': 'omarchy.clock'}]}},
                                         'idle': {'lock': 123}}))
            script = Path(__file__).with_name('install.py')
            environment = dict(os.environ, XDG_CONFIG_HOME=str(config))
            for attempt in range(2):
                if attempt == 1:
                    custom = json.loads(shell.read_text())
                    custom['bar']['layout']['right'][0].update(provider='claude', refreshSeconds=900)
                    shell.write_text(json.dumps(custom))
                subprocess.run(['python3', str(script), '--executable', '/usr/bin/true'],
                               env=environment, check=True, capture_output=True)
            result = json.loads(shell.read_text())
            self.assertEqual(result['idle'], {'lock': 123})
            self.assertEqual(result['bar']['layout']['right'][0]['provider'], 'claude')
            self.assertEqual(result['bar']['layout']['right'][0]['refreshSeconds'], 900)
            self.assertEqual([e['id'] for e in result['bar']['layout']['right']],
                             ['steipete.codexbar', 'omarchy.clock'])
            manifests = list((shell.parent / 'plugins').glob('*/manifest.json'))
            self.assertEqual(len(manifests), 1)
            self.assertEqual(len(list((shell.parent / 'backups').iterdir())), 1)


if __name__ == '__main__':
    unittest.main()
