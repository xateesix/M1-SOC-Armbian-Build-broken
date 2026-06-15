#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

PW = 'ztfalxtspv'
HOST = 'xateesix@10.22.2.208'
ROOT = Path('/mnt/c/Workspaces/Armbian-M1-SOC')
PNG = Path(
    '/mnt/c/Users/john.X86/.cursor/projects/c/assets/'
    'c__Users_john.X86_AppData_Roaming_Cursor_User_workspaceStorage_7eb384456178061732f760d9a02e7aa7_images_'
    'Copilot_20260614_112021-35a4b838-46fe-4e3c-bae3-60c5fb7611a4.png'
)
REL = ROOT / 'releases/1.0.0'
RDIR = '/tmp/armbian-m1-logo-v56'


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def main() -> int:
    run(['sshpass', '-p', PW, 'ssh', '-o', 'StrictHostKeyChecking=no', HOST, 'mkdir -p ' + RDIR])
    run([
        'sshpass', '-p', PW, 'scp', '-o', 'StrictHostKeyChecking=no',
        str(ROOT / 'tools/make-logo-bmp.py'),
        str(ROOT / 'tools/patch-resource-logos.py'),
        HOST + ':' + RDIR + '/',
    ])
    run([
        'sshpass', '-p', PW, 'scp', '-o', 'StrictHostKeyChecking=no',
        str(PNG),
        HOST + ':' + RDIR + '/source.png',
    ])
    run([
        'sshpass', '-p', PW, 'scp', '-o', 'StrictHostKeyChecking=no',
        str(REL / '_resource-v53.img'),
        HOST + ':' + RDIR + '/_resource-v53.img',
    ])
    run([
        'sshpass', '-p', PW, 'ssh', '-o', 'StrictHostKeyChecking=no', HOST,
        'echo ' + PW + ' | sudo -S DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pil',
    ])
    remote = '; '.join([
        'set -e',
        'cd ' + RDIR,
        'python3 make-logo-bmp.py source.png logo.bmp',
        'cp logo.bmp logo_kernel.bmp',
        'python3 patch-resource-logos.py --template _resource-v53.img --logo logo.bmp --logo-kernel logo_kernel.bmp --output _resource-v56-logo.img',
    ])
    run(['sshpass', '-p', PW, 'ssh', '-o', 'StrictHostKeyChecking=no', HOST, remote])
    run([
        'sshpass', '-p', PW, 'scp', '-o', 'StrictHostKeyChecking=no',
        HOST + ':' + RDIR + '/logo.bmp', str(REL / '_logo-artillery.bmp'),
    ])
    run([
        'sshpass', '-p', PW, 'scp', '-o', 'StrictHostKeyChecking=no',
        HOST + ':' + RDIR + '/_resource-v56-logo.img', str(REL / '_resource-v56-logo.img'),
    ])
    (REL / '_logo-artillery-kernel.bmp').write_bytes((REL / '_logo-artillery.bmp').read_bytes())
    print('DONE')
    return 0


if __name__ == '__main__':
    sys.exit(main())
