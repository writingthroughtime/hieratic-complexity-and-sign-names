#!/usr/bin/env python3

import argparse
import json
from pathlib import Path


def process_data(obj):
    """
    Recursively walk the JSON and:
    - count sentenceGlyphs blocks
    - sum all sign counts
    """
    text_count = 0
    total_signs = 0

    if isinstance(obj, dict):
        for key, value in obj.items():

            if key == "sentenceGlyphs" and isinstance(value, dict):
                text_count += 1
                total_signs += sum(v for v in value.values() if isinstance(v, (int, float)))

            else:
                tc, ts = process_data(value)
                text_count += tc
                total_signs += ts

    elif isinstance(obj, list):
        for item in obj:
            tc, ts = process_data(item)
            text_count += tc
            total_signs += ts

    return text_count, total_signs


def main():
    parser = argparse.ArgumentParser(
        description="Count number of texts and total signs in TLA corpus JSON."
    )
    parser.add_argument("corpus_json")

    args = parser.parse_args()
    input_path = Path(args.corpus_json)

    with open(input_path, "r", encoding="utf-8-sig") as f:
        data = json.load(f)

    text_count, total_signs = process_data(data)

    print(f"Number of texts: {text_count}")
    print(f"Total number of signs: {total_signs}")


if __name__ == "__main__":
    main()