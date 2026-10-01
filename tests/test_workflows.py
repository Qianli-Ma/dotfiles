from pathlib import Path
import tempfile, shutil, subprocess, os
root=Path(__file__).resolve().parents[1]
base=Path(tempfile.mkdtemp(prefix='dotfiles-test-')).resolve()
repo=base/'repo'; shutil.copytree(root,repo,ignore=shutil.ignore_patterns('.git','backups','.DS_Store'))
home=base/'home'; home.mkdir()
bin=base/'bin'; bin.mkdir()
log=base/'calls'
env=os.environ.copy(); env.update(HOME=str(home),PATH=str(bin)+':/usr/bin:/bin:/usr/sbin:/sbin',TEST_LOG=str(log),OSTYPE='darwin',GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL=str(home/'.gitconfig'))
for key in ('ZSH','ZSH_CUSTOM','GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE'): env.pop(key,None)
def run(args,ok=True,extra=None):
 e=env.copy(); e.update(extra or {})
 r=subprocess.run(args,env=e,cwd=base,text=True,capture_output=True,timeout=30)
 if ok and r.returncode: raise AssertionError(f'{args}: {r.stdout}\n{r.stderr}')
 return r
real_git='/usr/bin/git'
(bin/'git').write_text('#!/bin/bash\nif [ "$1" = clone ]; then mkdir -p "${@: -1}/.git"; echo clone >> "$TEST_LOG"; exit 0; fi\nif [[ "$*" == *" push" ]]; then echo push >> "$TEST_LOG"; exit 0; fi\nif [[ "$*" == *" pull --ff-only" ]]; then echo pull >> "$TEST_LOG"; exit "${FAIL_PULL:-0}"; fi\nexec /usr/bin/git "$@"\n')
(bin/'defaults').write_text('#!/bin/bash\necho "defaults $*" >> "$TEST_LOG"\nif [ "$1" = export ]; then printf "plist snapshot" > "$3"; fi\n')
(bin/'brew').write_text('''#!/bin/bash
echo "brew $*" >> "$TEST_LOG"
if [ "$1" = bundle ] && [ "$2" = dump ]; then
    while [ "$#" -gt 0 ]; do
        if [ "$1" = --file ]; then shift; printf 'brew "test-tool"\\ncask "test-app"\\n' > "$1"; fi
        shift
    done
    exit "${FAIL_DUMP:-0}"
fi
if [ "$1" = update ]; then exit "${FAIL_BREW_UPDATE:-0}"; fi
''')
(bin/'sudo').write_text('#!/bin/bash\necho "sudo $*" >> "$TEST_LOG"\nexit 0\n')
for f in bin.iterdir(): f.chmod(0o755)
run([real_git,'init',str(repo)])
run([real_git,'config','--global','user.name','Test User'])
run([real_git,'config','--global','user.email','test@example.invalid'])
run([real_git,'config','--global','credential.helper','secret-machine-helper'])
run([real_git,'-C',str(repo),'add','.'])
run([real_git,'-C',str(repo),'commit','-m','initial'])
(home/'.zshrc').write_text('ORIGINAL MACHINE SHELL\nexport FLUTTER_HOME=/some/machine\n')
(home/'.p10k.zsh').write_text('# custom prompt\n')
(home/'.zshrc.portable').write_text("alias hello='echo hello'\n")
(home/'.zshrc.local').write_text('export LOCAL_ONLY=1\n')
starter=(repo/'macos/dotfiles/.Brewfile').read_text()
run(['/bin/bash',str(repo/'backup.sh'),'--packages'])
assert (repo/'macos/dotfiles/.Brewfile').read_text()==starter
assert 'cask "test-app"' in (repo/'macos/packages.Brewfile').read_text()
assert 'credential' not in (repo/'common/gitconfig').read_text()
assert 'ORIGINAL MACHINE SHELL' not in (repo/'common/.zshrc').read_text()
assert list((repo/'backups').glob('*/home/.zshrc'))[0].read_text().startswith('ORIGINAL')
print('PASS: full inventory preserves starter list; raw shell and credentials stay out of portable settings')
# Publish must leave unrelated staged content out of its commit.
(repo/'unrelated.txt').write_text('unrelated')
run([real_git,'-C',str(repo),'add','unrelated.txt'])
run(['/bin/bash',str(repo/'backup.sh'),'--publish'])
assert run([real_git,'-C',str(repo),'show','--name-only','--format=','HEAD']).stdout.find('unrelated.txt')==-1
assert 'unrelated.txt' in run([real_git,'-C',str(repo),'diff','--cached','--name-only']).stdout
before=run([real_git,'-C',str(repo),'rev-parse','HEAD']).stdout
run(['/bin/bash',str(repo/'backup.sh'),'--publish'])
assert run([real_git,'-C',str(repo),'rev-parse','HEAD']).stdout==before
assert log.read_text().count('push')==2
print('PASS: publish from outside repo isolates staged work and retries push with unchanged settings')
# Settings-only can run twice, preserving the target and local additions.
count=len(list((repo/'backups').iterdir()))
run(['/bin/bash',str(repo/'setup.sh'),'--dry-run'])
assert len(list((repo/'backups').iterdir()))==count
run(['/bin/bash',str(repo/'setup.sh'),'--settings-only'])
run(['/bin/bash',str(repo/'setup.sh'),'--settings-only'])
assert len(list((repo/'backups').iterdir()))==count+2
assert (home/'.zshrc.local').read_text()=='export LOCAL_ONLY=1\n'
assert run([real_git,'config','--global','credential.helper']).stdout.strip()=='secret-machine-helper'
print('PASS: dry-run is read-only; repeated deployment preserves snapshots and existing local Git settings')
# Fresh home: no optional dependencies, shell startup should not print missing sources.
fresh=base/'fresh'; fresh.mkdir()
run(['/bin/bash',str(repo/'setup.sh'),'--settings-only'],extra={'HOME':str(fresh),'GIT_CONFIG_GLOBAL':str(fresh/'.gitconfig')})
r=run(['/bin/zsh','-dfc','source "$HOME/.zshrc"'],extra={'HOME':str(fresh)})
assert not r.stderr, r.stderr
print('PASS: fresh-home shell loads without optional SDKs/plugins')
# Failed package dump must not replace inventory; failure stops upgrade before updates.
old=(repo/'macos/packages.Brewfile').read_text()
r=run(['/bin/bash',str(repo/'backup.sh'),'--packages'],ok=False,extra={'FAIL_DUMP':'1'})
assert r.returncode!=0 and (repo/'macos/packages.Brewfile').read_text()==old
print('PASS: failed inventory leaves previous inventory intact')
log.write_text('')
r=run(['/bin/bash',str(repo/'autoupdate.sh')],ok=False,extra={'FAIL_BREW_UPDATE':'1'})
assert r.returncode!=0
assert 'brew upgrade' not in log.read_text()
assert 'Local snapshot:' in r.stdout
print('PASS: update snapshots first and reports metadata failures without upgrading')
# Linux backup/settings paths work without invoking real apt.
run(['/bin/bash',str(repo/'backup.sh')],extra={'OSTYPE':'linux-gnu'})
run(['/bin/bash',str(repo/'setup.sh'),'--settings-only'],extra={'OSTYPE':'linux-gnu'})
print('PASS: Linux settings export and deployment')
# Symlinked source settings must be archived by content; deployment leaves target intact.
source_file=base/'linked-config'; source_file.write_text('LINKED ORIGINAL\n')
(home/'.zshrc').unlink(); (home/'.zshrc').symlink_to(source_file)
run(['/bin/bash',str(repo/'setup.sh'),'--settings-only'])
assert source_file.read_text()=='LINKED ORIGINAL\n'
assert not (home/'.zshrc').is_symlink()
assert any(f.read_text()=='LINKED ORIGINAL\n' for f in (repo/'backups').glob('*/home/.zshrc'))
print('PASS: symlink contents backed up without overwriting original targets')
log.write_text('')
full=base/'full'; full.mkdir()
run(['/bin/bash',str(repo/'setup.sh')],extra={'HOME':str(full),'GIT_CONFIG_GLOBAL':str(full/'.gitconfig')})
assert (full/'.zshrc').exists()
assert 'macos/dotfiles/.Brewfile' in log.read_text()
assert 'packages.Brewfile' not in log.read_text()
assert 'clone' in log.read_text()
print('PASS: full setup with mocked installers selects starter packages and installs shell plugins')
log.write_text('')
r=run(['/bin/bash',str(repo/'autoupdate.sh'),'--packages'],ok=False,extra={'FAIL_DUMP':'1'})
assert r.returncode!=0 and 'brew update' not in log.read_text()
print('PASS: failed backup blocks updates')
print('All isolated checks passed')
shutil.rmtree(base)
