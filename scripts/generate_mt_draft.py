import json
import subprocess
import time
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "extracted" / "main_event" / "p28.json"
OUTPUT = ROOT / "translations" / "main_event_mt_draft_721_1410.json"
START, END = 721, 1411


def split_prefix(text: str):
    if text.startswith("*"):
        return "*", text[1:]
    if ":" in text:
        prefix, body = text.split(":", 1)
        if prefix in {"SYSTEM", "TOKOYO", "ERROR"}:
            return prefix + ":", body
    return "", text


def translate_one(index: int, source: str):
    prefix, body = split_prefix(source)
    if source == "終":
        return index, "끝"
    query = urllib.parse.urlencode({
        "client": "gtx", "sl": "ja", "tl": "ko", "dt": "t", "q": body
    })
    url = "https://translate.googleapis.com/translate_a/single?" + query
    last_error = None
    for attempt in range(5):
        try:
            result = subprocess.run(
                ["curl.exe", "-sS", "-L", "--max-time", "20", url],
                capture_output=True, check=True,
            )
            payload = json.loads(result.stdout.decode("utf-8"))
            translated = "".join(part[0] for part in payload[0] if part and part[0])
            return index, prefix + translated.strip()
        except Exception as exc:
            last_error = exc
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"index {index}: {last_error}")


def main():
    source = json.loads(SOURCE.read_text(encoding="utf-8"))["m_Structure"]["texts"]["values"]
    draft = {}
    if OUTPUT.exists():
        draft.update(json.loads(OUTPUT.read_text(encoding="utf-8")))
    pending = [(i, source[i]) for i in range(START, END) if str(i) not in draft]
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {pool.submit(translate_one, i, text): i for i, text in pending}
        completed = 0
        for future in as_completed(futures):
            index, translated = future.result()
            draft[str(index)] = translated
            completed += 1
            if completed % 50 == 0:
                OUTPUT.write_text(json.dumps(draft, ensure_ascii=False, indent=2), encoding="utf-8")
                print(f"completed {completed}/{len(pending)}")
    ordered = {str(i): draft[str(i)] for i in range(START, END)}
    OUTPUT.write_text(json.dumps(ordered, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {len(ordered)} lines to {OUTPUT}")


if __name__ == "__main__":
    main()
