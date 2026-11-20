#!/usr/bin/env python3
"""Build a staged demo session of the fake shop in shop.html, for the site's screenshots.

    python3 scripts/site-demo/make_session.py [out-dir]     # default: tmp/site-demo

Writes <out-dir>/2026-11-19_10-42-00/ with recording.mp4 (headless Chrome frames plus `say`
narration), marks.jsonl, activity.jsonl and browser.jsonl, then runs scripts/process_session.py
on it. Open it with `swift run ContextRecorder --library <out-dir>`. No real screen is recorded.
"""
import json
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOP = Path(__file__).with_name("shop.html")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FPS = 5  # frames rendered per second; the video itself is 15 fps
END = 48.0
SCALE = 4 / 3  # 1440x900 CSS px -> 1920x1200 video
ORIGIN = "http://localhost:5173"
NAME = "2026-11-19_10-42-00"

# (start second, page state, cursor keyframes [(second, x, y)])
SCENES = [
    (0, "product", [(0, 1000, 640), (3.5, 820, 445)]),
    (4, "product2", [(4, 820, 445), (6.5, 905, 445)]),
    (7, "product3", [(7, 905, 445), (10.5, 1240, 170)]),
    (11, "checkout", [(11, 1240, 170), (14, 1180, 375), (16.5, 1280, 470), (21, 1280, 470), (24.5, 425, 492), (29, 425, 492)]),
    (30, "settings", [(30, 900, 300), (32.5, 340, 482), (34.5, 186, 636)]),
    (36, "settings-error", [(36, 186, 636), (39.5, 186, 636), (42, 1240, 820), (48, 1240, 820)]),
]

NARRATION = [
    (1.0, "Okay, I'm checking the checkout flow on the shop before the release."),
    (5.0, "I set the quantity to two and click add to cart."),
    (11.5, "On checkout, the line item says eighty four dollars for two packs."),
    (15.5, "But the total says forty two. It looks like the total ignores the quantity."),
    (22.5, "And the express shipping option is cut off, so you can't read it."),
    (30.5, "Now settings. I'll switch the theme to dark and save."),
    (36.5, "Saving fails with just, something went wrong. And the button is stuck on saving."),
]

CHROME_CTX = {"appName": "Google Chrome", "bundleID": "com.google.Chrome"}
PAGES = {
    "product": ("/packs/ridgeline-28", "Ridgeline 28L · Northfold"),
    "checkout": ("/checkout", "Checkout · Northfold"),
    "settings": ("/account/settings", "Settings · Northfold"),
}


def page_of(state):
    return next(v for k, v in PAGES.items() if state.startswith(k))


def ctx(state):
    path, title = page_of(state)
    return {**CHROME_CTX, "browserTitle": title, "browserURL": ORIGIN + path, "windowTitle": title}


def scene_at(t):
    return [s for s in SCENES if s[0] <= t][-1]


def cursor_at(t, keys):
    if t <= keys[0][0]:
        return keys[0][1:]
    for (t0, x0, y0), (t1, x1, y1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            f = (t - t0) / (t1 - t0)
            f = f * f * (3 - 2 * f)  # ease in and out
            return x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
    return keys[-1][1:]


MARKS = [  # (second, kind)
    (17.0, "mark"),
    (25.5, "mark"),
    (40.0, "screenshot"),
]


def shoot(job):
    i, t, out = job
    if (out / f"{i:04d}.png").exists():
        return
    _, state, keys = scene_at(t)
    x, y = cursor_at(t, keys)
    marks = sum(1 for m, _ in MARKS if m <= t)
    url = f"{SHOP.as_uri()}?s={state}&x={x:.0f}&y={y:.0f}&t={int(t) // 60}:{int(t) % 60:02d}&m={marks}"
    subprocess.run([CHROME, "--headless=new", "--use-mock-keychain", "--password-store=basic", "--disable-gpu",
                    f"--user-data-dir={out.parent / 'profiles' / str(i % 8)}", "--hide-scrollbars", "--window-size=1440,900", f"--force-device-scale-factor={SCALE}",
                    f"--screenshot={out / f'{i:04d}.png'}", url], check=True, capture_output=True)


def element(selector, tag, text, components, file, line):
    return {"selector": selector, "tag": tag, "text": text, "components": components,
            "source": {"file": file, "line": line, "column": 7, "via": "react-debugSource"}}


def main():
    base = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tmp/site-demo"
    folder = base / NAME
    work = base / "work"
    for d in (folder, work / "frames"):
        d.mkdir(parents=True, exist_ok=True)

    jobs = [(i, i / FPS, work / "frames") for i in range(int(END * FPS))]
    with ThreadPoolExecutor(4) as pool:
        list(pool.map(shoot, jobs))

    # Narration: one `say` clip per line, each delayed to its start.
    inputs, filters = [], []
    for n, (t, text) in enumerate(NARRATION):
        clip = work / f"say{n}.aiff"
        subprocess.run(["say", "-v", "Samantha", "-r", "185", "-o", clip, text], check=True)
        inputs += ["-i", clip]
        filters.append(f"[{n + 1}:a]adelay={int(t * 1000)}:all=1[a{n}]")
    mix = "".join(f"[a{n}]" for n in range(len(NARRATION)))
    filters.append(f"{mix}amix=inputs={len(NARRATION)}:normalize=0,apad[a]")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS), "-i", work / "frames/%04d.png",
                    *inputs, "-filter_complex", ";".join(filters), "-map", "0:v", "-map", "[a]",
                    "-r", "15", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
                    "-c:a", "aac", "-t", str(END), folder / "recording.mp4"], check=True)

    with open(folder / "activity.jsonl", "w") as f:
        for t, state, _ in SCENES:
            if state in PAGES:
                f.write(json.dumps({"context": ctx(state), "offsetSeconds": t + 0.1}) + "\n")

    add = element('[data-testid="add-to-cart"]', "button", "Add to cart", ["AddToCart", "ProductPage"],
                  "/src/product/AddToCart.tsx", 31)
    save = element('[data-testid="save-settings"]', "button", "Save settings",
                   ["SaveButton", "SettingsForm", "SettingsPage"], "/src/account/SettingsForm.tsx", 58)
    failed = {"kind": "request", "method": "PUT", "requestUrl": ORIGIN + "/api/account/settings", "status": 500,
              "ms": 212, "body": '{"error":"theme must be one of: light, system"}', "url": ORIGIN + "/account/settings"}
    console = {"kind": "console", "level": "error", "message": "SettingsForm: save failed (500)",
               "url": ORIGIN + "/account/settings"}
    events = [
        (0.3, {"kind": "nav", "how": "load", "url": ORIGIN + "/packs/ridgeline-28"}),
        (8.6, {"kind": "click", "element": add, "url": ORIGIN + "/packs/ridgeline-28"}),
        (11.0, {"kind": "nav", "how": "pushState", "url": ORIGIN + "/checkout"}),
        (30.0, {"kind": "nav", "how": "pushState", "url": ORIGIN + "/account/settings"}),
        (35.4, {"kind": "click", "element": save, "url": ORIGIN + "/account/settings"}),
        (35.7, failed),
        (35.75, console),
    ]
    with open(folder / "browser.jsonl", "w") as f:
        for t, e in events:
            f.write(json.dumps({"offsetSeconds": t, "event": e}) + "\n")

    def recent(t):
        return [e for s, e in events if s <= t][-6:]

    total = element("aside.summary > div.row > span.total", "span", "$42.00", ["OrderTotal", "OrderSummary", "CheckoutPage"],
                    "/src/checkout/OrderTotal.tsx", 14)
    total["props"] = {"component": "OrderTotal", "props": {"items": "[2 items]", "shipping": 0, "currency": "USD"}}
    express = element("#ship-express > div.t", "div", "Express overnight to your door",
                      ["ShippingOption", "ShippingPicker", "CheckoutPage"], "/src/checkout/ShippingOption.tsx", 22)
    region = [  # what the region screenshot covers: the save button and the toast
        {"selector": '[data-testid="save-settings"]', "text": "Saving…", "source": save["source"]},
        {"selector": "div.toast", "text": "Something went wrong.",
         "source": {"file": "/src/ui/Toast.tsx", "line": 9, "via": "react-debugSource"}},
    ]
    hovered = {17.0: total, 25.5: express, 40.0: save}
    with open(folder / "marks.jsonl", "w") as f:
        for n, (t, kind) in enumerate(MARKS, 1):
            state = scene_at(t)[1]
            url = ORIGIN + page_of(state)[0]
            mark = {"context": ctx(state), "index": n, "kind": kind, "offsetSeconds": t,
                    "wallTime": f"2026-11-19T10:42:{int(t):02d}Z",
                    "browser": {"url": url, "title": page_of(state)[1], "hovered": hovered[t], "recent": recent(t)}}
            if kind == "screenshot":
                shots = folder / "screenshots"
                shots.mkdir(exist_ok=True)
                frame = work / f"frames/{int(t * FPS):04d}.png"
                # CSS box 108,560 -> 1352,850 at the 4/3 scale.
                subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", frame, "-vf", "crop=1659:387:144:747",
                                shots / f"{n:03d}.png"], check=True)
                mark["screenshot"] = f"screenshots/{n:03d}.png"
                mark["browser"]["region"] = {"method": "pointer", "elements": region}
            f.write(json.dumps(mark) + "\n")

    (folder / "session-info.json").write_text(json.dumps({"title": "Northfold checkout pass"}) + "\n")
    subprocess.run([sys.executable, ROOT / "scripts/process_session.py", folder], check=True)
    print(folder)


if __name__ == "__main__":
    main()
