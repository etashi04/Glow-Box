import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "python_packages"))

from PIL import Image, ImageDraw, ImageFont

TITLE = "빛날 뿐인 기계"
WIDTH, HEIGHT = 512, 32


def main():
    out_dir = ROOT / "analysis" / "poc"
    out_dir.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype(str(ROOT / "tools" / "Galmuri" / "Galmuri14.ttf"), 28)
    mask = Image.new("1", (WIDTH, HEIGHT), 0)
    draw = ImageDraw.Draw(mask)
    bbox = draw.textbbox((0, 0), TITLE, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    # Match the title menu's established left edge. The sprite is reused in
    # multiple scenes, and centering inside the texture shifts it away from
    # the left-aligned menu items.
    x = 78 - bbox[0]
    y = (HEIGHT - text_height) // 2 - bbox[1]
    draw.text((x, y), TITLE, font=font, fill=1)

    # The title shader samples RGB as a mask. Transparent pixels therefore
    # need black RGB, not transparent white, or the full sprite can obscure UI.
    logo = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    alpha = mask.convert("L").point(lambda v: 255 if v else 0)
    logo.paste(Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, 255)), (0, 0), alpha)
    logo.save(out_dir / "GameTitleLogo-Korean.png")

    # Unity stores this RGBA32 texture bottom-up.
    raw = logo.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes()
    (out_dir / "GameTitleLogo-Korean.rgba32").write_bytes(raw)

    preview = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 255))
    preview.alpha_composite(logo)
    preview.resize((WIDTH * 2, HEIGHT * 2), Image.Resampling.NEAREST).convert("RGB").save(
        out_dir / "GameTitleLogo-Korean-preview.png"
    )
    print(f"title={TITLE!r} size={WIDTH}x{HEIGHT} text={text_width}x{text_height} raw={len(raw)}")


if __name__ == "__main__":
    main()
