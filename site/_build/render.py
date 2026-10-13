#!/usr/bin/env python3
"""Renders site/alternatives/*.html, the roundups, the alternatives hub, the guides, and /privacy from pages.py,
the per-tool pages under /clear-cache and /ai-models and their hubs from tools.py,
rewrites the homepage footer list and JSON-LD between their <!-- alternatives --> and <!-- schema --> markers,
and writes sitemap.xml.

    python3 site/_build/render.py
"""
import datetime
import html
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pages import GUIDES, GUIDES_HUB, HUB, PAGES, PRIVACY, ROUNDUPS  # noqa: E402
from tools import GUIDE_HUBS, SECTIONS  # noqa: E402

TOOLS = [t for _, tools in SECTIONS for t in tools]

ROOT = os.path.join(os.path.dirname(__file__), "..")
SITE = "https://diskforecast.com"
DOWNLOAD = "https://github.com/coreyhaines31/diskforecast/releases/latest"
REPO = "https://github.com/coreyhaines31/diskforecast"
BREW = "brew install --cask coreyhaines31/tap/diskforecast"

DOWNLOAD_ICON = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v11m-5-5 5 5 5-5M5 20h14" fill="none" '
                 'stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>')
GITHUB_ICON = ('<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 '
               '5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52'
               '-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59'
               '.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82'
               '.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 '
               '.21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>')
# The two main calls to action, everywhere a page offers the download.
CTAS = (f'<a class="btn" href="{DOWNLOAD}">{DOWNLOAD_ICON}Download free</a>\n'
        f'        <a class="btn-quiet" href="{REPO}">{GITHUB_ICON}View source code</a>')
FONTS = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"


def esc(t):
    return html.escape(t, quote=True)


def head(title, description, path):
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{esc(title)}</title>
  <meta name="description" content="{esc(description)}">
  <link rel="canonical" href="{SITE}{path}">
  <meta property="og:title" content="{esc(title)}">
  <meta property="og:description" content="{esc(description)}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Disk Forecast">
  <meta property="og:image" content="{SITE}/images/og.png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:url" content="{SITE}{path}">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{esc(title)}">
  <meta name="twitter:description" content="{esc(description)}">
  <meta name="theme-color" content="#dceaf6" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#0b141e" media="(prefers-color-scheme: dark)">
  <link rel="icon" href="/images/icon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/images/icon.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="{FONTS}">
  <link rel="stylesheet" href="/site.css">
  <script src="https://cdn.usefathom.com/script.js" data-site="CNKCFAST" defer></script>
</head>
<body>
'''


def nav():
    return f'''  <div class="sky" aria-hidden="true"><i></i><i></i><i></i><i></i></div>
  <div class="nav">
    <div class="wrap">
      <a class="brand" href="/"><img src="/images/icon.svg" alt="" width="28" height="28"> Disk Forecast</a>
      <nav>
        <a href="/#forecast">Features</a>
        <a href="/guides">Guides</a>
        <a href="/system-data">System Data</a>
        <a href="/alternatives">Compare</a>
        <a href="/#faq">FAQ</a>
        <a class="btn" href="{DOWNLOAD}">Download</a>
      </nav>
    </div>
  </div>
'''


def footer_alternatives():
    """Every alternative page, linked from every footer for internal linking."""
    links = "".join(f'<a href="/alternatives/{p["slug"]}">{esc(p.get("footer", p["competitor"] + " alternative"))}</a>' for p in PAGES)
    links += "".join(f'<a href="{r["path"]}">{esc(r["footer"])}</a>' for r in ROUNDUPS)
    return f'      <nav class="footer-alts" aria-label="Alternatives"><a class="label" href="/alternatives">Alternatives</a>{links}</nav>\n'


def footer_guides():
    """Every guide, linked from every footer for internal linking."""
    links = "".join(f'<a href="{g["path"]}">{esc(g["footer"])}</a>' for g in GUIDES + GUIDE_HUBS)
    return f'      <nav class="footer-alts" aria-label="Guides"><a class="label" href="/guides">Guides</a>{links}</nav>\n'


def footer():
    return f'''  <footer>
    <div class="wrap">
{footer_guides()}{footer_alternatives()}      <div class="footer-links"><span>© 2026 Corey Haines. <a href="{REPO}/blob/main/LICENSE">FSL-1.1-MIT License</a>.</span></div>
      <div class="footer-links"><a href="{REPO}">GitHub</a><a href="{REPO}/releases">Releases</a><a href="{REPO}/issues">Issues</a><a href="/privacy">Privacy</a></div>
    </div>
  </footer>
'''


def homepage():
    with open(os.path.join(ROOT, "index.html")) as f:
        return f.read()


def render_homepage_footer():
    """The homepage is hand-written; keep its footer lists in sync between the markers."""
    path = os.path.join(ROOT, "index.html")
    page = homepage()
    start, end = "<!-- alternatives -->\n", "<!-- /alternatives -->"
    i, j = page.index(start) + len(start), page.index(end)
    with open(path, "w") as f:
        f.write(page[:i] + footer_guides() + footer_alternatives() + "      " + page[j:])


def homepage_schema():
    """SoftwareApplication plus a FAQPage built from the homepage's own FAQ, so the two never drift."""
    page = homepage()
    faqs = [(html.unescape(q), html.unescape(re.sub(r"<[^>]+>", "", a)))
            for q, a in re.findall(r"<details><summary>(.*?)</summary><p>(.*?)</p></details>", page)]
    app = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Disk Forecast",
           "operatingSystem": "macOS 14 or later", "applicationCategory": "UtilitiesApplication",
           "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
           "downloadUrl": DOWNLOAD, "url": f"{SITE}/", "image": f"{SITE}/images/icon.png",
           "author": {"@type": "Person", "name": "Corey Haines"}}
    return f'  <script type="application/ld+json">{json.dumps(app)}</script>\n  {faq_schema(faqs)}\n'


def render_homepage_schema():
    path = os.path.join(ROOT, "index.html")
    page = homepage()
    start, end = "<!-- schema -->\n", "  <!-- /schema -->"
    i, j = page.index(start) + len(start), page.index(end)
    schema = homepage_schema()
    with open(path, "w") as f:
        f.write(page[:i] + schema + page[j:])


def mockup(name):
    """Reuse a hand-drawn mockup from the homepage so there's one copy of it."""
    page = homepage()
    start, end = f"<!-- mockup:{name} -->", f"<!-- /mockup:{name} -->"
    return page[page.index(start) + len(start):page.index(end)].strip()


def staged(name):
    """App windows sit on a glass stage, like on the homepage; the menu bar and chart bring their own frame."""
    if name in ("system-data", "cleanup"):
        return f'<div class="stage glass">\n          {mockup(name)}\n        </div>'
    return mockup(name)


# Newer features every comparison table lists. A competitor shows "—" unless its page sets "new_rows".
NEW_ROWS = [
    ("Shows which folders grew, and when", "Yes, day by day"),
    ("Command line for scripts and AI agents", "Yes, <code>diskforecast</code>"),
]


def with_new_rows(rows, them):
    """Adds NEW_ROWS ahead of the "Source available" row, if there is one. `them` gives the competitor
    cells for a label, as a list (one per competitor column)."""
    added = [(label, us, *them(label)) for label, us in NEW_ROWS]
    at = next((i for i, r in enumerate(rows) if r[0].startswith("Source available")), len(rows))
    return list(rows[:at]) + added + list(rows[at:])


def table(rows, competitor):
    out = ['        <div class="table-card glass"><div class="table-scroll"><table class="compare">',
           f'          <thead><tr><td></td><th scope="col" class="us">Disk Forecast</th><th scope="col">{esc(competitor)}</th></tr></thead><tbody>']
    for label, us, them in rows:
        cls = ' class="n"' if them == "—" else ""
        out.append(f'            <tr><th scope="row">{label}</th><td class="us">{us}</td><td{cls}>{them}</td></tr>')
    out.append('          </tbody></table></div></div>')
    out.append('        <p class="table-foot">“—” means we couldn\'t confirm it from the vendor\'s own materials as of October 2026.</p>')
    return "\n".join(out)


def grid_table(t):
    """A table with any number of columns. The Disk Forecast column, or row, is highlighted."""
    head, rows = t["head"], t["rows"]
    style = f' style="min-width:{t["min_width"]}px"' if t.get("min_width") else ""
    first = f'<th scope="col">{esc(head[0])}</th>' if head[0] else "<td></td>"
    cols = "".join(f'<th scope="col"{" class=\"us\"" if h == "Disk Forecast" else ""}>{esc(h)}</th>' for h in head[1:])
    out = [f'        <div class="table-card glass"><div class="table-scroll"><table class="compare"{style}>',
           f'          <thead><tr>{first}{cols}</tr></thead><tbody>']
    for label, *cells in rows:
        tds = ""
        for h, c in zip(head[1:], cells):
            cls = "n" if c == "—" else "us" if "Disk Forecast" in (h, label) else ""
            tds += f'<td class="{cls}">{c}</td>' if cls else f"<td>{c}</td>"
        out.append(f'            <tr><th scope="row">{label}</th>{tds}</tr>')
    out.append('          </tbody></table></div></div>')
    if any("—" in row[1:] for row in rows):
        out.append('        <p class="table-foot">“—” means we couldn\'t confirm it from the vendor\'s own materials as of October 2026.</p>')
    return "\n".join(out)


def tables(body, page):
    """Swap each {{TABLE:name}} for the page's table of that name."""
    for name, t in page.get("tables", {}).items():
        body = body.replace("{{TABLE:" + name + "}}", grid_table(t))
    return body


def faq_schema(faqs):
    data = {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
        {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": a}} for q, a in faqs]}
    return f'<script type="application/ld+json">{json.dumps(data)}</script>'


def faq_block(faqs):
    items = "".join(f'          <details><summary>{esc(q)}</summary><p>{esc(a)}</p></details>\n' for q, a in faqs)
    return f'''    <section class="tight lit">
      <div class="wrap">
        <div class="head center head-sm"><h2>Questions</h2></div>
        <div class="faq glass">
{items}        </div>
      </div>
    </section>
'''


def cta(text):
    return f'''    <section class="cta lit">
      <div class="wrap">
        <div class="cta-card glass">
          <img src="/images/icon.svg" alt="" width="96" height="96" loading="lazy">
          <h2>{text}</h2>
          <p>Free. No account, no subscription.</p>
          <div class="actions">
            {CTAS}
          </div>
          <p class="fineprint">macOS 14 or later · Apple Silicon and Intel · <code>{BREW}</code></p>
        </div>
      </div>
    </section>
'''


def page_names():
    """Short names for breadcrumbs, by path."""
    names = {"/guides": "Guides", "/alternatives": "Alternatives", PRIVACY["path"]: "Privacy"}
    for g in GUIDES + GUIDE_HUBS + TOOLS + ROUNDUPS:
        names[g["path"]] = g["card_title"]
    for p in PAGES:
        names[f"/alternatives/{p['slug']}"] = p["card_title"]
    return names


def breadcrumb_schema(path):
    """Home, then the section a page sits in, then the page itself."""
    names = page_names()
    if path.startswith("/alternatives/") or (path in [r["path"] for r in ROUNDUPS if not r.get("in_guides")]):
        trail = ["/alternatives", path]
    elif path.count("/") == 2:
        trail = ["/" + path.split("/")[1], path]
    elif path in ("/guides", "/alternatives", PRIVACY["path"]):
        trail = [path]
    else:
        trail = ["/guides", path]
    items = [{"@type": "ListItem", "position": 1, "name": "Disk Forecast", "item": f"{SITE}/"}]
    items += [{"@type": "ListItem", "position": i + 2, "name": names.get(p, p), "item": f"{SITE}{p}"}
              for i, p in enumerate(trail)]
    data = {"@context": "https://schema.org", "@type": "BreadcrumbList", "itemListElement": items}
    return f'<script type="application/ld+json">{json.dumps(data)}</script>'


def collection_schema(path, title, cards):
    """A hub page and the pages it lists."""
    data = {"@context": "https://schema.org", "@type": "CollectionPage", "name": title, "url": f"{SITE}{path}",
            "mainEntity": {"@type": "ItemList", "itemListElement": [
                {"@type": "ListItem", "position": i + 1, "name": name, "url": f"{SITE}{href}"}
                for i, (name, href) in enumerate(cards)]}}
    return f'<script type="application/ld+json">{json.dumps(data)}</script>\n'


def write(path, body):
    """Writes the page and adds its breadcrumb trail. "/x/index" is the page at "/x"."""
    url = path[:-len("/index")] if path.endswith("/index") else path
    body = body.replace("</body>", breadcrumb_schema(url) + "\n</body>", 1)
    out = os.path.join(ROOT, path.strip("/") + ".html")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        f.write(body)


def render_page(p):
    path = f"/alternatives/{p['slug']}"
    parts = [head(p["title"], p["description"], path), nav(), "  <main>\n"]
    parts.append(f'''    <div class="sub-hero">
      <div class="wrap narrow">
        <div class="eyebrow">{esc(p["eyebrow"])}</div>
        <h1>{p["h1"]}</h1>
        <p class="lede">{p["lede"]}</p>
        <div class="actions">
          {CTAS}
        </div>
        <div class="tldr glass"><h2>The short version</h2><p>{p["tldr"]}</p></div>
      </div>
    </div>
''')
    for sec in p["sections"]:
        cls = "tight" + (" lit" if sec.get("lit") else "")
        sid = f' id="{sec["id"]}"' if sec.get("id") else ""
        body = sec["html"]
        theirs = p.get("new_rows", {})
        if sec.get("table"):
            rows = with_new_rows(sec["table"], lambda label: [theirs.get(label, "—")])
            body = body.replace("{{TABLE}}", table(rows, p["competitor"]))
        if sec.get("grid"):
            columns = len(sec["grid"]["head"]) - 2
            rows = with_new_rows(sec["grid"]["rows"], lambda label: theirs.get(label, ["—"] * columns))
            body = body.replace("{{TABLE}}", grid_table({**sec["grid"], "rows": rows}))
        parts.append(f'    <section class="{cls}"{sid}>\n      <div class="wrap narrow"><div class="prose">\n{body}\n      </div></div>\n    </section>\n')
    parts.append(faq_block(p["faqs"]))
    others = [q for q in PAGES if q["slug"] != p["slug"]]
    rel = "".join(f'          <a class="glass" href="/alternatives/{q["slug"]}"><b>{esc(q["card_title"])}</b><span>{esc(q["card_blurb"])}</span></a>\n' for q in others)
    parts.append(f'''    <section class="tight lit">
      <div class="wrap">
        <div class="head center head-sm"><h2>Other Mac storage apps, compared</h2></div>
        <div class="related">
{rel}          <a class="glass" href="/system-data"><b>Clearing System Data</b><span>The step-by-step guide, using only Apple's own tools.</span></a>
        </div>
      </div>
    </section>
''')
    parts.append(cta(p["cta"]))
    parts.append("  </main>\n")
    parts.append(footer())
    parts.append(faq_schema(p["faqs"]) + "\n</body>\n</html>\n")
    write(path, "".join(parts))


def render_hub():
    path = "/alternatives"
    cards = "".join(f'          <a class="glass" href="/alternatives/{q["slug"]}"><b>{esc(q["card_title"])}</b><span>{esc(q["card_blurb"])}</span></a>\n' for q in PAGES)
    cards += "".join(f'          <a class="glass" href="{r["path"]}"><b>{esc(r["card_title"])}</b><span>{esc(r["card_blurb"])}</span></a>\n' for r in ROUNDUPS)
    rows = "".join(f'<tr><th scope="row">{esc(a)}</th><td class="{"us" if b == "Disk Forecast" else ""}">{esc(b)}</td></tr>' for a, b in HUB["glance"][1:])
    body = f'''{head(HUB["title"], HUB["description"], path)}{nav()}  <main>
    <div class="sub-hero">
      <div class="wrap narrow">
        <div class="eyebrow">Alternatives</div>
        <h1>{HUB["h1"]}</h1>
        <p class="lede">{HUB["lede"]}</p>
      </div>
    </div>
    <section class="tight lit" style="padding-top:0">
      <div class="wrap narrow">
        <div class="table-card glass glance"><table class="compare">
          <thead><tr><th scope="col">{esc(HUB["glance"][0][0])}</th><th scope="col">{esc(HUB["glance"][0][1])}</th></tr></thead>
          <tbody>{rows}</tbody>
        </table></div>
        <div class="related">
{cards}        </div>
      </div>
    </section>
    <section class="tight">
      <div class="wrap narrow"><div class="prose">
{HUB["html"]}
      </div></div>
    </section>
{cta(HUB["cta"])}  </main>
{footer()}{collection_schema(path, HUB["title"], [(q["card_title"], f"/alternatives/{q['slug']}") for q in PAGES] + [(r["card_title"], r["path"]) for r in ROUNDUPS])}</body>
</html>
'''
    write("/alternatives/index", body)


def related_guides(g):
    """Cards for the guides, hubs, and tool pages this one points to, by path."""
    alternatives = [{**p, "path": f"/alternatives/{p['slug']}"} for p in PAGES]
    by_path = {q["path"]: q for q in GUIDES + GUIDE_HUBS + TOOLS + ROUNDUPS + alternatives}
    related = [by_path[path] for path in g.get("related", []) if path in by_path]
    if not related:
        return ""
    cards = "".join(f'          <a class="glass" href="{q["path"]}"><b>{esc(q["card_title"])}</b><span>{esc(q["card_blurb"])}</span></a>\n'
                    for q in related)
    return f'''    <section class="tight lit">
      <div class="wrap">
        <div class="head center head-sm"><h2>Related guides</h2></div>
        <div class="related">
{cards}        </div>
      </div>
    </section>
'''


def render_guide(g):
    body = f'''{head(g["title"], g["description"], g["path"])}{nav()}  <main>
    <div class="sub-hero">
      <div class="wrap narrow">
        <div class="eyebrow">{esc(g["eyebrow"])}</div>
        <h1>{g["h1"]}</h1>
        <p class="lede">{g["lede"]}</p>
        <div class="tldr glass"><h2>The short version</h2><p>{g["tldr"]}</p></div>
      </div>
    </div>
    <section class="tight">
      <div class="wrap narrow"><div class="prose">
{tables(g["html"], g)}
      </div></div>
    </section>
    <section class="tight lit" id="shortcut">
      <div class="wrap">
        <div class="head center">
{g["shortcut"]}
          <div class="actions">
            {CTAS}
          </div>
        </div>
        {staged(g["mockup"])}
      </div>
    </section>
{faq_block(g["faqs"])}{related_guides(g)}{g.get("more", "")}{cta(g["cta"])}  </main>
{footer()}{faq_schema(g["faqs"])}
</body>
</html>
'''
    write(g["path"], body)


def render_guides_hub():
    d = GUIDES_HUB
    listed = GUIDES + GUIDE_HUBS + [r for r in ROUNDUPS if r.get("in_guides")]
    cards = "".join(f'          <a class="glass" href="{g["path"]}"><b>{esc(g["card_title"])}</b><span>{esc(g["card_blurb"])}</span></a>\n' for g in listed)
    body = f'''{head(d["title"], d["description"], d["path"])}{nav()}  <main>
    <div class="sub-hero">
      <div class="wrap narrow">
        <div class="eyebrow">Guides</div>
        <h1>{d["h1"]}</h1>
        <p class="lede">{d["lede"]}</p>
      </div>
    </div>
    <section class="tight lit" style="padding-top:0">
      <div class="wrap narrow">
        <div class="related" style="grid-template-columns:1fr">
{cards}        </div>
      </div>
    </section>
{cta(d["cta"])}  </main>
{footer()}{collection_schema(d["path"], d["title"], [(g["card_title"], g["path"]) for g in listed])}</body>
</html>
'''
    write(d["path"], body)


def paths_table(rows):
    """Where a tool keeps its files, and how big each was on the Mac we measured."""
    out = ['        <div class="table-card glass" style="margin:16px 0 24px"><div class="table-scroll"><table class="compare">',
           '          <thead><tr><th scope="col">What</th><th scope="col">Default location</th><th scope="col">On one Mac</th></tr></thead><tbody>']
    for what, where, size in rows:
        loc = where if "<" in where else f"<code>{esc(where)}</code>"
        out.append(f'            <tr><th scope="row">{esc(what)}</th><td>{loc}</td><td>{esc(size)}</td></tr>')
    out.append('          </tbody></table></div></div>')
    return "\n".join(out)


def more_in(hub, tools, current):
    """Every other page in the same section, as a compact list, so each one is linked from all its siblings."""
    links = "".join(f'<a href="{t["path"]}">{esc(t["card_title"])}</a>' for t in tools if t["path"] != current["path"])
    if not links:
        return ""
    return f'''    <section class="tight">
      <div class="wrap narrow">
        <nav class="more-links" aria-label="{esc(hub["card_title"])}"><a class="label" href="{hub["path"]}">{esc(hub["card_title"])}</a>{links}</nav>
      </div>
    </section>
'''


def render_tool(t, more=""):
    """A per-tool page is a guide: the TL;DR answers it, the shortcut names the Disk Forecast row.
    Pages where the app does less can title that section themselves with "finds_title"."""
    finds_title = t.get("finds_title", "Disk Forecast finds this for you")
    render_guide({**t, "eyebrow": t.get("eyebrow", "Guide"), "cta": t.get("cta", "Know before it's full."),
                  "html": t["html"].replace("{{PATHS}}", paths_table(t["paths"])),
                  "shortcut": f"          <h2>{finds_title}</h2>\n{t['finds']}", "more": more})


def render_tool_hub(d, tools):
    """A hub lists its tool pages as cards, then short prose, an FAQ, and the CTA."""
    cards = "".join(f'          <a class="glass" href="{t["path"]}"><b>{esc(t["card_title"])}</b><span>{esc(t["card_blurb"])}</span></a>\n' for t in tools)
    body = f'''{head(d["title"], d["description"], d["path"])}{nav()}  <main>
    <div class="sub-hero">
      <div class="wrap narrow">
        <div class="eyebrow">Guides</div>
        <h1>{d["h1"]}</h1>
        <p class="lede">{d["lede"]}</p>
      </div>
    </div>
    <section class="tight lit" style="padding-top:0">
      <div class="wrap narrow">
        <div class="related">
{cards}        </div>
      </div>
    </section>
    <section class="tight">
      <div class="wrap narrow"><div class="prose">
{d["html"]}
      </div></div>
    </section>
{faq_block(d["faqs"])}{cta(d["cta"])}  </main>
{footer()}{faq_schema(d["faqs"])}
{collection_schema(d["path"], d["title"], [(t["card_title"], t["path"]) for t in tools])}
</body>
</html>
'''
    write(d["path"] + "/index", body)


def last_modified(path):
    """The day a page's file last changed: today if it has changes not yet committed, else its last commit."""
    name = "index.html" if path == "/" else path.strip("/") + ".html"
    if not os.path.exists(os.path.join(ROOT, name)):
        name = path.strip("/") + "/index.html"
    git = ["git", "-C", ROOT]
    if subprocess.run(git + ["diff", "--quiet", "HEAD", "--", name]).returncode != 0:
        return datetime.date.today().isoformat()
    day = subprocess.run(git + ["log", "-1", "--format=%cs", "--", name], capture_output=True, text=True).stdout.strip()
    return day or datetime.date.today().isoformat()


def render_sitemap():
    paths = ["/", GUIDES_HUB["path"]] + [g["path"] for g in GUIDES]
    for hub, tools in SECTIONS:
        paths += [hub["path"]] + [t["path"] for t in tools]
    paths += ["/alternatives"] + [f"/alternatives/{p['slug']}" for p in PAGES] + [r["path"] for r in ROUNDUPS] + [PRIVACY["path"]]
    urls = "".join(f"  <url><loc>{SITE}{p}</loc><lastmod>{last_modified(p)}</lastmod></url>\n" for p in paths)
    with open(os.path.join(ROOT, "sitemap.xml"), "w") as f:
        f.write(f'<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n{urls}</urlset>\n')


def render_privacy():
    d = PRIVACY
    body = f'''{head(d["title"], d["description"], d["path"])}{nav()}  <main>
    <div class="sub-hero">
      <div class="wrap narrow"><h1>{esc(d["h1"])}</h1></div>
    </div>
    <section class="tight" style="padding-top:0">
      <div class="wrap narrow"><div class="prose">
{d["html"]}
      </div></div>
    </section>
  </main>
{footer()}</body>
</html>
'''
    write(d["path"], body)


if __name__ == "__main__":
    for p in PAGES:
        render_page(p)
    for r in ROUNDUPS:
        render_guide(r)
    render_hub()
    render_homepage_footer()
    render_homepage_schema()
    for g in GUIDES:
        render_guide(g)
    for hub, tools in SECTIONS:
        for t in tools:
            render_tool(t, more_in(hub, tools, t))
        render_tool_hub(hub, tools)
    render_guides_hub()
    render_privacy()
    render_sitemap()
    print(f"rendered {len(PAGES)} pages + {len(ROUNDUPS)} roundups + hub + homepage footer and schema + {len(GUIDES)} guides and their hub"
          f" + {len(TOOLS)} tool pages and {len(SECTIONS)} hubs + privacy + sitemap")
