"""Contract for the combined guild download; never include player saves."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile,unittest,zipfile
ROOT=Path(__file__).resolve().parents[1]

class GuildBuilderExeTests(unittest.TestCase):
    """Exercise the real CLI with bounded fixtures, not production executables."""
    def setUp(self):
        temporary=tempfile.TemporaryDirectory(prefix='guild-bundle-')
        self.addCleanup(temporary.cleanup)
        self.root=Path(temporary.name)
        fixtures={
            'addon/ForeverCoach/ForeverCoach.toc':'## Title: Relax Coach\n## Version: 1.4.0\n',
            'addon/Journey/Journey.toc':'## Title: Relax Journey\n',
            'content/Journey-Content/guide.html':'<html>Synthetic guide fixture</html>\n',
            'README.md':'Synthetic guild packaging fixture\n',
            'LICENSE':'Synthetic license fixture\n',
            'scripts/Install-RelaxCoach.ps1':'# Synthetic installer fixture\n',
            'scripts/Restore-RelaxCoach.ps1':'# Synthetic restore fixture\n',
        }
        for name,text in fixtures.items():
            path=self.root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
        shutil.copy2(ROOT/'scripts/build_guild_bundle.py',self.root/'scripts/build_guild_bundle.py')
        self.payload=b'MZsynthetic packaging fixture; not a runnable Windows EXE\n'
        self.exe=self.root/'candidate/Coach.exe'
        self.exe.parent.mkdir();self.exe.write_bytes(self.payload)
        self.standalone=self.root/'dist/RelaxCoach.exe'
        self.standalone.parent.mkdir()

    def run_builder(self,exe):
        return subprocess.run([sys.executable,str(self.root/'scripts/build_guild_bundle.py'),'--exe',str(exe)],cwd=self.root,capture_output=True,text=True)

    def assert_matching_assets(self,exe):
        result=self.run_builder(exe)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertEqual(self.standalone.read_bytes(),self.payload)
        archive=self.root/'dist/RelaxCoach-Guild-1.4.0.zip'
        with zipfile.ZipFile(archive) as z:
            self.assertEqual(z.read('RelaxCoach.exe'),self.payload)
            row=next(r for r in json.loads(z.read('manifest.json'))['files'] if r['path']=='RelaxCoach.exe')
            self.assertEqual(row,{'path':'RelaxCoach.exe','sha256':hashlib.sha256(self.payload).hexdigest(),'bytes':len(self.payload)})
        sums={name:sha for sha,name in (line.split('  ',1) for line in (self.root/'dist/SHA256SUMS.txt').read_text().splitlines())}
        self.assertEqual(sums,{
            'RelaxCoach.exe':hashlib.sha256(self.payload).hexdigest(),
            archive.name:hashlib.sha256(archive.read_bytes()).hexdigest(),
        })

    def test_alternate_exe_replaces_missing_or_stale_standalone(self):
        for state in ('missing','stale'):
            with self.subTest(standalone=state):
                if state=='stale':self.standalone.write_bytes(b'MZstale synthetic fixture\n')
                self.assert_matching_assets(self.exe)
                self.assertEqual(self.exe.read_bytes(),self.payload)

    def test_previous_package_exe_survives_package_cleanup(self):
        previous=self.root/'dist/guild-package/RelaxCoach.exe'
        previous.parent.mkdir();previous.write_bytes(self.payload)
        self.standalone.write_bytes(b'MZstale synthetic fixture\n')
        self.assert_matching_assets(previous)
        self.assertEqual(previous.read_bytes(),self.payload)

    def test_canonical_exe_does_not_copy_onto_itself(self):
        self.standalone.write_bytes(self.payload)
        self.assert_matching_assets(self.standalone)

    def test_hardlinked_exe_does_not_copy_onto_itself(self):
        self.standalone.hardlink_to(self.exe)
        self.assert_matching_assets(self.exe)

    def test_symlink_exe_is_rejected_before_standalone_changes(self):
        self.standalone.write_bytes(b'MZstale synthetic fixture\n')
        link=self.root/'linked.exe';link.symlink_to(self.exe)
        parent=self.root/'linked-directory';parent.symlink_to(self.exe.parent,target_is_directory=True)
        for exe in (link,parent/self.exe.name):
            with self.subTest(exe=exe):
                result=self.run_builder(exe)
                self.assertNotEqual(result.returncode,0)
                self.assertIn('Symlink input rejected: RelaxCoach.exe',result.stderr)
                self.assertEqual(self.standalone.read_bytes(),b'MZstale synthetic fixture\n')
                self.assertFalse((self.root/'dist/guild-package').exists())

class GuildBundleTests(unittest.TestCase):
    def test_original_journey_bytes_are_not_git_normalized(self):
        import subprocess
        paths=['addon/Journey/services/Catalog.lua','content/Journey-Content/'+next((ROOT/'content/Journey-Content').glob('*.html')).name]
        result=subprocess.check_output(['git','check-attr','text','--',*paths],cwd=ROOT,text=True)
        self.assertEqual(len(result.splitlines()),len(paths))
        for line in result.splitlines():self.assertTrue(line.endswith(': text: unset'),line)

    def test_combined_archive_preserves_runtime_and_excludes_saves(self):
        path=ROOT/'dist/RelaxCoach-Guild-1.4.0.zip'
        self.assertTrue(path.is_file(),'combined guild archive is missing')
        with zipfile.ZipFile(path) as z:
            names=z.namelist()
            self.assertEqual(len(names),len(set(names)))
            mandatory={'Interface/AddOns/ForeverCoach/ForeverCoach.toc','Interface/AddOns/Journey/Journey.toc','RelaxCoach.exe','Install-RelaxCoach.ps1','Restore-RelaxCoach.ps1','README.md','LICENSE-Coach','manifest.json'}
            self.assertTrue(mandatory.issubset(names))
            self.assertTrue(any(n.startswith('Interface/Content/Journey-Content/') for n in names))
            for name in names:
                parts=name.lower().split('/')
                self.assertFalse(set(parts)&{'wtf','private','evidence','backups','.git','__pycache__'},name)
                self.assertNotIn('..',parts)
                self.assertFalse(name.startswith('/') or '\\' in name or ':' in name,name)
            manifest=json.loads(z.read('manifest.json'))
            self.assertEqual(manifest['kind'],'guild-combined')
            self.assertEqual(manifest['version'],'1.4.0')
            self.assertEqual({r['path'] for r in manifest['files']},set(names)-{'manifest.json'})
            for row in manifest['files']:
                raw=z.read(row['path'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(),row['sha256'],row['path'])
                self.assertEqual(len(raw),row['bytes'])
            for folder in ('ForeverCoach','Journey'):
                for source in (ROOT/'addon'/folder).rglob('*'):
                    if source.is_file():self.assertEqual(z.read('Interface/AddOns/'+str(source.relative_to(ROOT/'addon')).replace('\\','/')),source.read_bytes())
            for source in (ROOT/'content').rglob('*'):
                if source.is_file():self.assertEqual(z.read('Interface/Content/'+source.relative_to(ROOT/'content').as_posix()),source.read_bytes())
            self.assertEqual(z.read('RelaxCoach.exe'),(ROOT/'dist/RelaxCoach.exe').read_bytes())
            self.assertIn(b'## SavedVariables: Journey_Account',z.read('Interface/AddOns/Journey/Journey.toc'))
            self.assertIn(b'## SavedVariablesPerCharacter: Journey_Character',z.read('Interface/AddOns/Journey/Journey.toc'))
            self.assertIn('guild',z.read('README.md').decode().lower())
            self.assertNotIn('Do not publish it to GitHub',z.read('README.md').decode())
if __name__=='__main__':unittest.main(verbosity=2)
