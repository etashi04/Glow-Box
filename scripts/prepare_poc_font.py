import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "python_packages"))

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import Glyph
from PIL import Image

ATLAS_SIZE = 2048
PADDING = 2


def read_bdf(path: Path, wanted: str):
    wanted_codes = {ord(ch): ch for ch in wanted}
    found = {}
    current = None
    bitmap = []
    in_bitmap = False
    for raw in path.read_text(encoding="utf-8", errors="strict").splitlines():
        if raw.startswith("STARTCHAR "):
            current = {"name": raw.split(maxsplit=1)[1]}
            bitmap = []
            in_bitmap = False
        elif current is not None and raw.startswith("ENCODING "):
            current["encoding"] = int(raw.split()[1])
        elif current is not None and raw.startswith("DWIDTH "):
            current["dwidth"] = int(raw.split()[1])
        elif current is not None and raw.startswith("BBX "):
            current["bbx"] = [int(v) for v in raw.split()[1:5]]
        elif current is not None and raw == "BITMAP":
            in_bitmap = True
        elif current is not None and raw == "ENDCHAR":
            code = current.get("encoding")
            if code in wanted_codes:
                current["bitmap"] = bitmap
                found[code] = current
            current = None
            in_bitmap = False
        elif current is not None and in_bitmap:
            bitmap.append(raw.strip())
    missing = wanted_codes.keys() - found.keys()
    if missing:
        raise RuntimeError(f"BDF missing codepoints: {sorted(missing)}")
    return found


def main():
    out_dir = ROOT / "analysis" / "poc"
    out_dir.mkdir(parents=True, exist_ok=True)
    source_font = ROOT / "analysis" / "KH-Dot-Kodenmachou-16.ttf"
    source_raw = ROOT / "analysis" / "JapaneseFontAtlas.rgb24"
    bdf_path = ROOT / "tools" / "Galmuri" / "Galmuri14.bdf"

    font = TTFont(source_font)
    original_order = font.getGlyphOrder()
    original_count = len(original_order)
    units_per_em = font["head"].unitsPerEm
    translations = json.loads((ROOT / "translations" / "system_text_ko.json").read_text(encoding="utf-8"))
    event_translations = json.loads((ROOT / "translations" / "main_event_ko.json").read_text(encoding="utf-8"))
    all_text = list(translations.values()) + list(event_translations.values())
    chars = "".join(dict.fromkeys(
        ch for text in all_text for ch in text
        if 0xAC00 <= ord(ch) <= 0xD7A3
    ))
    bdf = read_bdf(bdf_path, chars)

    new_order = list(original_order)
    glyph_records = []
    x_cursor = 16
    y_bottom = 16
    row_height = 0
    raw = bytearray(source_raw.read_bytes())
    expected = ATLAS_SIZE * ATLAS_SIZE * 3
    if len(raw) != expected:
        raise RuntimeError(f"Unexpected atlas size: {len(raw)} != {expected}")

    for ch in chars:
        cp = ord(ch)
        rec = bdf[cp]
        width, height, xoff, yoff = rec["bbx"]
        glyph_name = f"kr_uni{cp:04X}"
        glyph_id = len(new_order)
        new_order.append(glyph_name)
        font["glyf"].glyphs[glyph_name] = Glyph()
        advance = round(units_per_em * rec["dwidth"] / 16)
        lsb = round(units_per_em * xoff / 16)
        font["hmtx"].metrics[glyph_name] = (advance, lsb)
        for cmap_table in font["cmap"].tables:
            if cmap_table.isUnicode() and cp <= (0xFFFF if cmap_table.format == 4 else 0x10FFFF):
                cmap_table.cmap[cp] = glyph_name

        rect_w, rect_h = width + 2 * PADDING, height + 2 * PADDING
        if x_cursor + rect_w >= ATLAS_SIZE:
            x_cursor = 16
            y_bottom += row_height + 4
            row_height = 0
        if y_bottom + rect_h >= 480:
            raise RuntimeError("PoC glyphs do not fit in reserved atlas area")
        for top_row, hex_row in enumerate(rec["bitmap"]):
            bits = int(hex_row, 16)
            storage_bits = len(hex_row) * 4
            for col in range(width):
                if bits & (1 << (storage_bits - 1 - col)):
                    px = x_cursor + PADDING + col
                    py = y_bottom + PADDING + (height - 1 - top_row)
                    offset = (py * ATLAS_SIZE + px) * 3
                    raw[offset:offset + 3] = b"\xff\xff\xff"
        glyph_records.append({
            "char": ch,
            "codepoint": cp,
            "glyph_id": glyph_id,
            "atlas_x": x_cursor,
            "atlas_y": y_bottom,
            "atlas_width": rect_w,
            "atlas_height": rect_h,
            "bearing_x": xoff,
            "bearing_y": yoff + height,
            "vertical_x": -2.25,
            "vertical_y": 0.0,
            "advance_pixels": rec["dwidth"],
        })
        x_cursor += rect_w + 2
        row_height = max(row_height, rect_h)

    font.setGlyphOrder(new_order)
    font["maxp"].numGlyphs = len(new_order)
    merged_path = out_dir / "KH-Dot-Kodenmachou-16-Korean-PoC.ttf"
    font.save(merged_path)

    raw_path = out_dir / "JapaneseFontAtlas-Korean-PoC.rgb24"
    raw_path.write_bytes(raw)
    # Unity raw texture rows are bottom-up; flip for a human-readable preview.
    image = Image.frombytes("RGB", (ATLAS_SIZE, ATLAS_SIZE), bytes(raw))
    image = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    image.save(out_dir / "JapaneseFontAtlas-Korean-PoC.png")
    (out_dir / "glyphs.json").write_text(
        json.dumps({"original_glyph_count": original_count, "glyphs": glyph_records}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    check = TTFont(merged_path)
    cmap = check.getBestCmap()
    for item in glyph_records:
        mapped = cmap.get(item["codepoint"])
        actual_id = check.getGlyphID(mapped) if mapped else -1
        if actual_id != item["glyph_id"]:
            raise RuntimeError(f"Glyph mapping validation failed for {item['char']}: {actual_id}")
    print(json.dumps({
        "original_glyph_count": original_count,
        "new_glyph_count": len(check.getGlyphOrder()),
        "font": str(merged_path),
        "atlas": str(raw_path),
        "glyphs": glyph_records,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
