#!/usr/bin/env python3
"""Forward MPV v0.41.0 --sub-lavc-o to text subtitle converters.

In unpatched mpv v0.41.0, sub/sd_ass.c creates text decoders through
sub/lavc_conv.c; unlike sub/sd_lavc.c, lavc_conv_create omits sub_avopts.
This matters for the experimental FFmpeg CC1/CC2 decoder option.
"""
from pathlib import Path
import subprocess
import sys

REL = 'sub/lavc_conv.c'
TAG = 'v0.41.0'


def git(source, *args):
    result = subprocess.run(['git', '-C', str(source), *args],
                            text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def apply(source):
    source = Path(source)
    dest = source / REL
    if not dest.is_file():
        raise RuntimeError(f'Missing MPV source: {dest}')
    head = git(source, 'rev-parse', 'HEAD')
    pinned = git(source, 'rev-list', '-n', '1', TAG)
    if head != pinned:
        raise RuntimeError(f'Unexpected MPV checkout: {head[:12]} != {TAG}={pinned[:12]}')
    # Restore only this source file from the pinned revision for repeatable
    # patching if GitHub Actions reuses a previously modified source cache.
    git(source, 'restore', f'--source={TAG}', '--worktree', '--', REL)
    original = dest.read_bytes()
    if b'\r\n' in original:
        raise RuntimeError('Unexpected CRLF in MPV source')
    text = original.decode('utf-8')
    old = ('    if (mp_set_avctx_codec_headers(avctx, sd->codec) < 0)\n'
           '        goto error;\n'
           '    MP_VERBOSE(sd, "Using subtitle decoder %s\\n", codec->name);\n')
    new = ('    if (mp_set_avctx_codec_headers(avctx, sd->codec) < 0)\n'
           '        goto error;\n'
           '    // Text subtitles (including EIA-608) decode through lavc_conv.\n'
           '    // Forward --sub-lavc-o here just as sd_lavc.c does.\n'
           '    mp_set_avopts(sd->log, avctx, sd->opts->sub_avopts);\n'
           '    MP_VERBOSE(sd, "Using subtitle decoder %s\\n", codec->name);\n')
    if text.count(old) != 1:
        raise RuntimeError(f'Expected exactly one MPV v0.41.0 source anchor, found {text.count(old)}')
    dest.write_text(text.replace(old, new, 1), encoding='utf-8', newline='\n')
    print(f'TVEZ MPV {TAG} text subtitle AVOptions forwarding: applied ({head[:12]})')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Usage: python3 mpv-0002-tvez-text-sub-lavc-options.py MPVSourceDir')
    try:
        apply(sys.argv[1])
    except Exception as exc:
        sys.exit(f'TVEZ MPV text AVOptions forwarding patch failed: {exc}')
