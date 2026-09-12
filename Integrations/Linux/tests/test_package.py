import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[3]


class PackageTests(unittest.TestCase):
    def test_archive_installs_without_a_checkout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(['python3', str(REPO / 'Integrations/Linux/package.py'), '--binary', '/usr/bin/true',
                            '--version', 'test', '--output', str(root)], check=True, capture_output=True)
            archive_path = next(root.glob('*.tar.gz'))
            with tarfile.open(archive_path) as archive:
                self.assertEqual(len(archive.getmembers()), 7)
                self.assertFalse(any('linux.json' in name for name in archive.getnames()))
                archive.extractall(root / 'unpacked', filter='data')
            package = next((root / 'unpacked').iterdir())
            home = root / 'home'
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / 'config'),
                       XDG_DATA_HOME=str(home / 'data'))
            subprocess.run(['python3', str(package / 'Integrations/Linux/install.py'), '--cli', '/usr/bin/true'],
                           env=env, check=True, capture_output=True)
            self.assertTrue((home / '.local/bin/codexbar-linux').is_file())


if __name__ == '__main__':
    unittest.main()
