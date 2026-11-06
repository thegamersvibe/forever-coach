"""Public release must contain only our own Coach, never private Journey data."""
from pathlib import Path
import hashlib,json,unittest,zipfile
ROOT=Path(__file__).resolve().parents[1]

class PublicBundleTests(unittest.TestCase):
    def test_public_archive_scope(self):
        archive=ROOT/'dist/public/RelaxCoach-1.4.0.zip'
        self.assertTrue(archive.exists(),'public bundle not assembled')
        with zipfile.ZipFile(archive) as z:
            names=z.namelist()
            self.assertIn('ForeverCoach/ForeverCoach.toc',names)
            self.assertIn('RelaxCoach.exe',names)
            self.assertIn('manifest.json',names)
            for n in names:
                self.assertTrue(n.startswith('ForeverCoach/') or n in {'RelaxCoach.exe','README.md','LICENSE','manifest.json'},n)
                self.assertFalse(any(s in n.lower() for s in ['catalog','journey/','guides.html','evidence/','wtf/','fixture','private']))
            manifest=json.loads(z.read('manifest.json'))
            self.assertEqual(manifest['kind'],'coach-public')
            self.assertEqual(manifest['version'],'1.4.0')
            self.assertEqual({r['path'] for r in manifest['files']},set(names)-{'manifest.json'})
            for r in manifest['files']:
                self.assertEqual(hashlib.sha256(z.read(r['path'])).hexdigest(),r['sha256'])

if __name__=='__main__':unittest.main(verbosity=2)
