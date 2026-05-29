#!/usr/bin/env python3
"""
Batch-convert a folder of SVG files to high-resolution TIFF files.

What it does
- Recursively finds all .svg files in the input folder
- Renders each SVG at a higher resolution than its native size
- Preserves the original artboard/viewBox aspect ratio
- Writes TIFF files into the output folder, preserving subfolder structure

Dependencies
    pip install cairosvg pillow

Usage
    python svg_to_tiff.py /path/to/input_svgs /path/to/output_tiffs

Optional examples
    python svg_to_tiff.py in out --scale 4
    python svg_to_tiff.py in out --scale 6 --dpi 600
    python svg_to_tiff.py in out --workers 8 --compression tiff_lzw
"""

from __future__ import annotations

import argparse
import io
import os
import sys
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import cairosvg
from PIL import Image


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert a folder of SVGs to high-resolution TIFFs."
    )
    parser.add_argument("input_folder", type=Path, help="Folder containing SVG files")
    parser.add_argument("output_folder", type=Path, help="Folder to write TIFF files into")
    parser.add_argument(
        "--scale",
        type=float,
        default=4.0,
        help="Resolution multiplier relative to the SVG's own artboard size (default: 4.0)",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=600,
        help="TIFF DPI metadata to embed (default: 600)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=max(1, min(8, (os.cpu_count() or 4))),
        help="Number of parallel workers (default: min(8, CPU count))",
    )
    parser.add_argument(
        "--compression",
        type=str,
        default="tiff_lzw",
        choices=["raw", "tiff_lzw", "tiff_adobe_deflate", "packbits"],
        help="TIFF compression method (default: tiff_lzw)",
    )
    parser.add_argument(
        "--background",
        type=str,
        default=None,
        help="Optional background color, e.g. white, '#ffffff', 'black'. "
             "If omitted, transparency is preserved where possible.",
    )
    return parser.parse_args()


def collect_svg_files(root: Path) -> list[Path]:
    return sorted(p for p in root.rglob("*.svg") if p.is_file())


def svg_to_tiff(
    svg_path: Path,
    input_root: Path,
    output_root: Path,
    scale: float,
    dpi: int,
    compression: str,
    background: str | None,
) -> tuple[bool, str]:
    try:
        rel = svg_path.relative_to(input_root)
        out_path = output_root / rel.with_suffix(".tiff")
        out_path.parent.mkdir(parents=True, exist_ok=True)

        svg_bytes = svg_path.read_bytes()

        # CairoSVG uses the SVG's intrinsic size / viewBox and scales it up.
        # This preserves the original artboard proportions while increasing resolution.
        png_bytes = cairosvg.svg2png(
            bytestring=svg_bytes,
            scale=scale,
            dpi=dpi,
        )

        with Image.open(io.BytesIO(png_bytes)) as im:
            # Convert for a predictable TIFF output mode.
            if background is not None:
                rgba = im.convert("RGBA")
                bg = Image.new("RGBA", rgba.size, background)
                composited = Image.alpha_composite(bg, rgba).convert("RGB")
                save_im = composited
            else:
                # Preserve alpha if present; otherwise use RGB.
                if "A" in im.getbands():
                    save_im = im.convert("RGBA")
                else:
                    save_im = im.convert("RGB")

            save_im.save(
                out_path,
                format="TIFF",
                compression=compression,
                dpi=(dpi, dpi),
            )

        return True, f"OK   {svg_path} -> {out_path}"

    except Exception:
        err = traceback.format_exc(limit=1).strip().replace("\n", " | ")
        return False, f"FAIL {svg_path} -> {err}"


def main() -> int:
    args = parse_args()

    input_root = args.input_folder.resolve()
    output_root = args.output_folder.resolve()

    if not input_root.exists() or not input_root.is_dir():
        print(f"Input folder does not exist or is not a directory: {input_root}", file=sys.stderr)
        return 1

    output_root.mkdir(parents=True, exist_ok=True)

    svg_files = collect_svg_files(input_root)
    if not svg_files:
        print(f"No SVG files found in: {input_root}")
        return 0

    print(f"Found {len(svg_files)} SVG files")
    print(f"Input:  {input_root}")
    print(f"Output: {output_root}")
    print(f"Scale:  {args.scale}x")
    print(f"DPI:    {args.dpi}")
    print(f"Workers:{args.workers}")
    print()

    ok_count = 0
    fail_count = 0

    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = [
            ex.submit(
                svg_to_tiff,
                svg_path,
                input_root,
                output_root,
                args.scale,
                args.dpi,
                args.compression,
                args.background,
            )
            for svg_path in svg_files
        ]

        for fut in as_completed(futures):
            ok, msg = fut.result()
            print(msg)
            if ok:
                ok_count += 1
            else:
                fail_count += 1

    print()
    print(f"Done. Success: {ok_count}, Failed: {fail_count}")
    return 0 if fail_count == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())








# python svg_to_tiff.py ./svgs/ht ./tiffs/ht --scale 1 --dpi 600