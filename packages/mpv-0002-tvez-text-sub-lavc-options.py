#!/usr/bin/env python3
"""Forward MPV v0.41.0 --sub-lavc-o to the text subtitle decoder.

Use the avcodec_open2() call within lavc_conv_create() instead of matching
several adjacent source lines, which can differ across cached checkouts.
"""
from pathlib import Path
import re
import subprocess
import sys

REL = 'sub/lavc_conv.c'
TAG = 'v0.41.0'
FUNC_START = 'struct lavc_conv *lavc_conv_create('
FUNC_END = 'char *lavc_conv_get_extradata('
OPTION_CALL = 'mp_set_avopts(sd->log, avctx, sd->opts->sub_avopts);'


def git(source, *args):
    result = subprocess.run(['git', '-C', str(source), *args],
                            text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def patch_content(text):
    # Bound insertion to lavc_conv_create(), avoiding accidental matches in
    # other subtitle-decoder functions.
    start = text.find(FUNC_START)
    end = text.find(FUNC_END, start + len(FUNC_START))
    if start < 0 or end < 0 or end <= start:
        raise RuntimeError('Could not locate lavc_conv_create() source region')
    function = text[start:end]
    # Ignore harmless spacing differences around the avcodec_open2 call.
    pattern = r'(?m)^(?P<indent>[ \t]*)if[ \t]*\([ \t]*avcodec_open2[ \t]*\('
    matches = list(re.finditer(pattern, function))
    if len(matches) != 1:
        excerpt = '\n'.join(line for line in function.splitlines()
                            if 'avcodec_open2' in line)
        raise RuntimeError(
            f'Expected one avcodec_open2() in lavc_conv_create(), '
            f'found {len(matches)}. Lines: {excerpt!r}')
    if OPTION_CALL in function:
        raise RuntimeError('Source already has sub-lavc-o forwarding in this function')
    match = matches[0]
    insertion = match.group('indent') + OPTION_CALL + '\n'
    return text[:start + match.start()] + insertion + text[start + match.start():]


def apply(source):
    source = Path(source)
    dest = source / REL
    if not dest.is_file():
        raise RuntimeError(f'Missing MPV source: {dest}')
    head = git(source, 'rev-parse', 'HEAD')
    pinned = git(source, 'rev-list', '-n', '1', TAG)
    if head != pinned:
        raise RuntimeError(f'Unexpected MPV checkout: {head[:12]} != {TAG}={pinned[:12]}')
    # GitHub Actions can reuse a checkout from a previous failed patch step.
    # Restore only the target file. Do not touch the TVEZ version marker.
    git(source, 'restore', f'--source={TAG}', '--worktree', '--', REL)
    original = dest.read_bytes()
    text = original.decode('utf-8')
    newline = '\r\n' if '\r\n' in text else '\n'
    patched = patch_content(text.replace('\r\n', '\n'))
    dest.write_bytes(patched.replace('\n', newline).encode('utf-8'))
    print(f'TVEZ MPV {TAG} text subtitle AVOptions forwarding: applied ({head[:12]})')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('Usage: python3 mpv-0002-tvez-text-sub-lavc-options.py MPVSourceDir')
    try:
        apply(sys.argv[1])
    except Exception as exc:
        sys.exit(f'TVEZ MPV text AVOptions forwarding patch failed: {exc}')
