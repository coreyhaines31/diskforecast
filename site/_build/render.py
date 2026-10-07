#!/usr/bin/env python3
"""Renders site/alternatives/*.html, the alternatives hub, the guides, and /privacy from pages.py,
rewrites the homepage footer list and JSON-LD between their <!-- alternatives --> and <!-- schema --> markers,
and writes sitemap.xml.

    python3 site/_build/render.py
"""
import html
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pages import GUIDES, HUB, PAGES, PRIVACY  # noqa: E402

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
    links = "".join(f'<a href="/alternatives/{p["slug"]}">{esc(p["competitor"])} alternative</a>' for p in PAGES)
    return f'      <nav class="footer-alts" aria-label="Alternatives"><a class="label" href="/alternatives">Alternatives</a>{links}</nav>\n'


def footer():
    return f'''  <footer>
    <div class="wrap">
{footer_alternatives()}      <div class="footer-links"><span>© 2026 Corey Haines. <a href="{REPO}/blob/main/LICENSE">FSL-1.1-MIT License</a>.</span></div>
      <div class="footer-links"><a href="{REPO}">GitHub</a><a href="{REPO}/releases">Releases</a><a href="{REPO}/issues">Issues</a><a href="/system-data">Clear System Data</a><a href="/privacy">Privacy</a></div>
    </div>
  </footer>
'''


def homepage():
    with open(os.path.join(ROOT, "index.html")) as f:
        return f.read()


def render_homepage_footer():
    """The homepage is hand-written; keep its footer list in sync between the markers."""
    path = os.path.join(ROOT, "index.html")
    page = homepage()
    start, end = "<!-- alternatives -->\n", "<!-- /alternatives -->"
    i, j = page.index(start) + len(start), page.index(end)
    with open(path, "w") as f:
        f.write(page[:i] + footer_alternatives() + "      " + page[j:])


def homepage_schema():
    """SoftwareApplication plus a FAQPage built from the homepage's own FAQ, so the two never drift."""
    page = homepage()
    faqs = [(html.unescape(q), html.unescape(re.sub(r"<[^>]+>", "", a)))
            for q, a in re.findall(r"<details><summary>(.*?)</summary><p>(.*?)</p></details>", page)]
    app = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Disk Forecast",
           "operatingSystem": "macOS 14 or later", "applicationCategory": "UtilitiesApplication",
           "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
           "downloadUrl": DOWNLOAD, "url": f"{SITE}/", "image": f"{SITE}/images/icon.png",
           "author": {"@type": "Person", "name": "Corey Haines"}, "softwareVersion": "1.0.0"}
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


def table(rows, competitor):
    out = ['        <div class="table-card glass"><div class="table-scroll"><table class="compare">',
           f'          <thead><tr><td></td><th scope="col" class="us">Disk Forecast</th><th scope="col">{esc(competitor)}</th></tr></thead><tbody>']
    for label, us, them in rows:
        cls = ' class="n"' if them == "—" else ""
        out.append(f'            <tr><th scope="row">{label}</th><td class="us">{us}</td><td{cls}>{them}</td></tr>')
    out.append('          </tbody></table></div></div>')
    out.append('        <p class="table-foot">“—” means we couldn\'t confirm it from the vendor\'s own materials as of October 2026.</p>')
    return "\n".join(out)


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


def write(path, body):
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
        if sec.get("table"):
            body = body.replace("{{TABLE}}", table(sec["table"], p["competitor"]))
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
{footer()}</body>
</html>
'''
    with open(os.path.join(ROOT, "alternatives", "index.html"), "w") as f:
        f.write(body)


def related_guides(g):
    """Cards for the guides this one points to, by path."""
    if not g.get("related"):
        return ""
    by_path = {q["path"]: q for q in GUIDES}
    cards = "".join(f'          <a class="glass" href="{q["path"]}"><b>{esc(q["card_title"])}</b><span>{esc(q["card_blurb"])}</span></a>\n'
                    for q in (by_path[path] for path in g["related"]))
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
{g["html"]}
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
        <div class="stage glass">
          {mockup(g["mockup"])}
        </div>
      </div>
    </section>
{faq_block(g["faqs"])}{related_guides(g)}{cta(g["cta"])}  </main>
{footer()}{faq_schema(g["faqs"])}
</body>
</html>
'''
    write(g["path"], body)


def render_sitemap():
    paths = ["/"] + [g["path"] for g in GUIDES] + ["/alternatives"] + [f"/alternatives/{p['slug']}" for p in PAGES] + [PRIVACY["path"]]
    urls = "".join(f"  <url><loc>{SITE}{p}</loc></url>\n" for p in paths)
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
    render_hub()
    render_homepage_footer()
    render_homepage_schema()
    for g in GUIDES:
        render_guide(g)
    render_privacy()
    render_sitemap()
    print(f"rendered {len(PAGES)} pages + hub + homepage footer and schema + {len(GUIDES)} guides + privacy + sitemap")
