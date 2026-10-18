#!/usr/bin/env python3
"""Patch the pinned FFmpeg n9.0.2 CEA-608 decoder for an isolated CC1 test.

Runs from the FFmpeg ExternalProject PATCH_COMMAND. This does not rewrite
other FFmpeg files or install/deploy any Windows DLLs.
"""
import pathlib
import subprocess
import sys

REL = "libavcodec/ccaption_dec.c"
PINNED = "n9.0.2"


def git(source, *args):
    proc = subprocess.run(
        ["git", "-C", str(source), *args],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if proc.returncode:
        raise RuntimeError(
            f"git {' '.join(args)} failed (exit {proc.returncode})\n"
            f"stdout: {proc.stdout.strip()}\nstderr: {proc.stderr.strip()}"
        )
    return proc.stdout.strip()


def replace_exact(text, original, replacement, label):
    hits = text.count(original)
    if hits != 1:
        raise RuntimeError(
            f"{label}: expected exactly one source anchor; found {hits}. "
            f"The checkout may not match FFmpeg {PINNED}."
        )
    return text.replace(original, replacement, 1)


def apply(source):
    source = pathlib.Path(source)
    decoder = source / REL
    if not decoder.is_file():
        raise RuntimeError(f"Missing expected FFmpeg file: {decoder}")

    head = git(source, "rev-parse", "HEAD")
    expected = git(source, "rev-list", "-n", "1", PINNED)
    if head != expected:
        raise RuntimeError(
            f"Wrong FFmpeg source revision: HEAD={head[:12]}, "
            f"{PINNED}={expected[:12]}. Refusing to patch another version."
        )

    # Recover just the decoder from a cached earlier/partially modified build.
    # Preserve all other dependencies, checked-out source files and caches.
    git(source, "restore", f"--source={PINNED}", "--worktree", "--", REL)
    original = decoder.read_bytes()
    if b"\r\n" in original:
        raise RuntimeError("Unexpected CRLF in FFmpeg decoder source")
    contents = original.decode("utf-8")

    contents = replace_exact(
        contents,
        "    int data_field;\n    struct Screen screen[2];",
        "    int data_field;\n"
        "    /* -1: both services; 0: CC1/CC3; 1: CC2/CC4. */\n"
        "    int cc_channel;\n"
        "    int active_cc_channel;\n"
        "    struct Screen screen[2];",
        "decoder context",
    )
    contents = replace_exact(
        contents,
        "    ctx->cursor_row = 10;\n    return ff_ass_subtitle_header",
        "    ctx->cursor_row = 10;\n"
        "    ctx->active_cc_channel = 0;\n"
        "    return ff_ass_subtitle_header",
        "decoder initialization",
    )
    contents = replace_exact(
        contents,
        "    ctx->active_screen = 0;\n    ctx->last_real_time = 0;",
        "    ctx->active_screen = 0;\n"
        "    ctx->active_cc_channel = 0;\n"
        "    ctx->last_real_time = 0;",
        "decoder flush",
    )
    contents = replace_exact(
        contents,
        "        ret = process_cc608(ctx, hi & 0x7f, bptr[i + 2] & 0x7f);",
        "        /* CEA-608 carries two channels per field. Channel control and\n"
        "         * PAC pairs choose the active service; printable pairs inherit it.\n"
        "         * This is an experimental CC1 filter, not a general fix.\n"
        "         */\n"
        "        {\n"
        "            const uint8_t cc_hi = hi & 0x7f;\n"
        "            const uint8_t cc_lo = bptr[i + 2] & 0x7f;\n"
        "            if (cc_hi >= 0x10 && cc_hi <= 0x1f && cc_lo >= 0x20)\n"
        "                ctx->active_cc_channel = !!(cc_hi & 0x08);\n"
        "            if (ctx->cc_channel >= 0 &&\n"
        "                ctx->active_cc_channel != ctx->cc_channel)\n"
        "                continue;\n"
        "            ret = process_cc608(ctx, cc_hi, cc_lo);\n"
        "        }",
        "caption pair processing",
    )
    option = (
        '    { "data_field", "select data field", OFFSET(data_field), '
        'AV_OPT_TYPE_INT, { .i64 = -1 }, -1, 1, SD, .unit = "data_field" },\n'
    )
    contents = replace_exact(
        contents, option,
        option +
        '    { "cc_channel", "select first or second CEA-608 channel '
        'within field (-1=both)", OFFSET(cc_channel), '
        'AV_OPT_TYPE_INT, { .i64 = -1 }, -1, 1, SD },\n',
        "decoder option",
    )
    if contents == original.decode("utf-8"):
        raise RuntimeError("No decoder changes made")
    decoder.write_bytes(contents.encode("utf-8"))
    print(f"TVEZ CC1 test: verified FFmpeg {PINNED} {head[:12]}")
    print("TVEZ CC1 test: decoder patch applied via 5 exact source anchors")
    print("TVEZ CC1 test: cc_channel defaults to -1 (legacy behavior)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: python3 ffmpeg-0001-tvez-cc1-service-filter.py FFmpegSourceDir")
    try:
        apply(sys.argv[1])
    except Exception as exc:
        sys.exit(f"TVEZ CC1 test patch failed: {exc}")
