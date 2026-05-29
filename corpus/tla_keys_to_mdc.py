#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path


G_TAG_AT_START_RE = re.compile(r'^<g\b([^>]*)/?>(?:</g>)?')
G_TAG_WITH_CONTENT_RE = re.compile(r'^<g\b([^>]*)>(.*?)</g>')
N_ATTR_RE = re.compile(r'\bn="([^"]+)"')

LEADING_EGYPTIAN_RE = re.compile(
    r"^([\U00013000-\U0001342F\U00013460-\U000143FF])<[^>]+.*$"
)

VARIATION_SELECTOR_RE = re.compile(
    r"[\uFE00-\uFE0F\U000E0100-\U000E01EF]"
)

XML_JUNK_RE = re.compile(r"<[^>]+>")

EGYPTIAN_CONTROL_CHARS = {
    "\U00013430",
    "\U00013431",
    "\U00013432",
    "\U00013433",
    "\U00013434",
    "\U00013435",
    "\U00013436",
    "\U00013437",
    "\U00013438",
    "\U00013439",
    "\U0001343A",
    "\U0001343B",
    "\U0001343C",
    "\U0001343D",
    "\U0001343E",
    "\U0001343F",
    "\U00013440",
}


def strip_variation_selectors(text):
    return VARIATION_SELECTOR_RE.sub("", text)


def strip_xml_junk(text):
    return XML_JUNK_RE.sub("", text)


def is_extended_egyptian(char):
    cp = ord(char)
    return 0x13460 <= cp <= 0x143FF


def should_track_unmapped(text):
    return not any(is_extended_egyptian(c) for c in text)


def load_mdc_hex(path):
    char_to_mdc = {}

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()

            if not line or line.startswith("#"):
                continue

            parts = line.split()
            if len(parts) < 2:
                continue

            mdc, hex_code = parts[0], parts[1]

            try:
                char = chr(int(hex_code, 16))
            except ValueError:
                continue

            char_to_mdc[char] = mdc

    return char_to_mdc


def load_script_labels(path):
    script_labels = {}

    if path is None:
        return script_labels

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()

            if not line or line.startswith("#"):
                continue

            parts = line.split(maxsplit=1)

            if len(parts) != 2:
                continue

            url, label = parts
            script_labels[url] = label

    return script_labels


def extract_g_tag_info(key):
    key = key.strip()

    content_match = G_TAG_WITH_CONTENT_RE.match(key)
    if content_match:
        attrs = content_match.group(1)
        inner_text = content_match.group(2) or ""
    else:
        start_match = G_TAG_AT_START_RE.match(key)
        if not start_match:
            return None, None

        attrs = start_match.group(1)
        inner_text = ""

    n_match = N_ATTR_RE.search(attrs)
    n_value = n_match.group(1) if n_match else None

    return n_value, inner_text.strip()


def map_sequence_to_mdc(text, char_to_mdc, unmapped):
    text = strip_xml_junk(text)

    parts = []
    pending_dash = False

    for char in text:
        if char in EGYPTIAN_CONTROL_CHARS:
            pending_dash = True
            continue

        if char in char_to_mdc:
            if pending_dash and parts:
                parts.append("-")

            parts.append(char_to_mdc[char])
            pending_dash = False
            continue

        if should_track_unmapped(char):
            unmapped.add(char)

        return text

    if not parts:
        return text

    return "".join(parts)


def key_to_mdc(key, char_to_mdc, unmapped):
    key_clean = strip_variation_selectors(key)

    n_value, inner_text = extract_g_tag_info(key_clean)

    if n_value is not None:
        if inner_text:
            mapped_inner = map_sequence_to_mdc(inner_text, char_to_mdc, unmapped)

            if mapped_inner != inner_text:
                return mapped_inner

        return n_value

    leading_match = LEADING_EGYPTIAN_RE.match(key_clean)
    if leading_match:
        return map_sequence_to_mdc(key_clean, char_to_mdc, unmapped)

    if any(char in EGYPTIAN_CONTROL_CHARS for char in key_clean):
        return map_sequence_to_mdc(key_clean, char_to_mdc, unmapped)

    if len(key_clean) == 1:
        if key_clean in char_to_mdc:
            return char_to_mdc[key_clean]

        if should_track_unmapped(key_clean):
            unmapped.add(key_clean)

        return key_clean

    if should_track_unmapped(key_clean):
        unmapped.add(key_clean)

    return key_clean


def convert_data(obj, char_to_mdc, unmapped, scripts, script_labels):
    if isinstance(obj, dict):
        converted = {}

        for key, value in obj.items():

            if key == "script" and isinstance(value, str):
                scripts.add(value)
                converted[key] = script_labels.get(value, value)
                continue

            if key == "sentenceGlyphs" and isinstance(value, dict):
                new_sentence_glyphs = {}

                for glyph_key, count in value.items():
                    new_key = key_to_mdc(glyph_key, char_to_mdc, unmapped)

                    if new_key in new_sentence_glyphs:
                        if isinstance(new_sentence_glyphs[new_key], (int, float)) and isinstance(count, (int, float)):
                            new_sentence_glyphs[new_key] += count
                        else:
                            raise ValueError(
                                f"Key collision for {new_key!r}: cannot merge non-numeric values."
                            )
                    else:
                        new_sentence_glyphs[new_key] = count

                converted[key] = new_sentence_glyphs

            else:
                converted[key] = convert_data(
                    value,
                    char_to_mdc,
                    unmapped,
                    scripts,
                    script_labels
                )

        return converted

    if isinstance(obj, list):
        return [
            convert_data(item, char_to_mdc, unmapped, scripts, script_labels)
            for item in obj
        ]

    return obj


def main():
    parser = argparse.ArgumentParser(
        description="Convert TLA corpus frequency JSON sentenceGlyphs keys to MdC, replace script URLs with labels, track unmapped keys, and list script URLs."
    )
    parser.add_argument("corpus_json")
    parser.add_argument("mdc_hex")
    parser.add_argument(
        "-s",
        "--scripts",
        help="Text file containing script URL and label pairs."
    )
    parser.add_argument("-o", "--output")

    args = parser.parse_args()

    input_path = Path(args.corpus_json)

    output_path = Path(args.output) if args.output else input_path.with_name(
        input_path.stem + "_mdc.json"
    )

    unmapped_path = input_path.with_name(input_path.stem + "_unmapped.txt")
    scripts_path = input_path.with_name(input_path.stem + "_scripts.txt")

    char_to_mdc = load_mdc_hex(args.mdc_hex)
    script_labels = load_script_labels(args.scripts)

    with open(input_path, "r", encoding="utf-8-sig") as f:
        data = json.load(f)

    unmapped = set()
    scripts = set()

    converted = convert_data(
        data,
        char_to_mdc,
        unmapped,
        scripts,
        script_labels
    )

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(converted, f, ensure_ascii=False, indent=2)

    with open(unmapped_path, "w", encoding="utf-8") as f:
        for k in sorted(unmapped, key=lambda x: [ord(c) for c in x]):
            codepoints = " ".join(f"U+{ord(c):05X}" for c in k)
            f.write(f"{k}\t{codepoints}\n")

    with open(scripts_path, "w", encoding="utf-8") as f:
        for s in sorted(scripts):
            label = script_labels.get(s, "")
            if label:
                f.write(f"{s}\t{label}\n")
            else:
                f.write(s + "\n")

    print(f"Saved converted file to {output_path}")
    print(f"Saved unmapped keys to {unmapped_path}")
    print(f"Saved scripts list to {scripts_path}")


if __name__ == "__main__":
    main()