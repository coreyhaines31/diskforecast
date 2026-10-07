# Per-tool pages: /clear-cache/[tool] and /ai-models/[tool], plus their hubs.
# Each record renders with the guide template (render.py): TL;DR answer, prose with a {{PATHS}} table, a
# "Disk Forecast finds this for you" section naming the exact Cleanup or System Data row, FAQ, siblings, CTA.
#
# Every Disk Forecast claim traces to CleanupRules.swift, CleanupCatalog.swift, ArtifactKind.swift, and
# SystemDataModel.swift. Measured sizes come from du, docker system df, pip cache info, and xcrun simctl on one
# developer Mac (macOS 26.6, October 2026), and are labelled as one example.
# Keyword research: ~/code/diskforecast/docs/seo/keywords-2026-10-06.md, sections 2a and 2b.
#
# Copy rules: never "optimize", "boost", "speed up", or "junk"; say "reclaim" and "explain".
# Say "free, source available", never "open source". No em dashes. Subheads list 1 or 3 items, never 2.

# ------------------------------------------------------------------ Docker
# "docker system prune" 800, "clear docker cache" 250, "docker disk space" 50, "docker clean up disk space" 30, "docker.raw" 20.
DOCKER = {
    "slug": "docker",
    "title": "Docker system prune: clear Docker cache on Mac",
    "description": "What docker system prune deletes, how to clear Docker build cache, where Docker.raw lives on a Mac, and why Finder shows it far bigger than it is.",
    "h1": "Docker system prune on Mac, <em>explained.</em>",
    "lede": "On a Mac, everything Docker stores sits inside one disk image. Here's how to see what's in it, what each prune command removes, and why you should never delete the file itself.",
    "tldr": "Run <code>docker system prune</code>. It asks first, then removes stopped containers, networks no container uses, dangling images, and unused build cache. Add <code>-a</code> to also remove every image no container is using. Volumes stay unless you add <code>--volumes</code>, and volumes hold data, like your local databases. Docker Desktop keeps all of it in one file, <code>Docker.raw</code>, so reclaim space with Docker's commands, never by deleting that file.",
    "card_title": "Docker",
    "card_blurb": "docker system prune, build cache, and the Docker.raw file.",
    "paths": [
        ("The disk image", "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", "29 GB on disk"),
        ("Images, containers, volumes, build cache", "Inside Docker.raw; <code>docker system df</code> lists them", "27.4 GB of images, 15.4 GB unused"),
    ],
    "html": """
        <h2>Where Docker stores data on a Mac</h2>
        <p>Docker Desktop runs Linux in a small virtual machine, and that machine's disk is a single file. Every image you pull, every container, every volume, and all your build cache live inside it.</p>
        {{PATHS}}
        <p>Sizes are from one developer Mac in October 2026. Two commands tell you what's really there:</p>
<pre><code>docker system df
du -h ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw</code></pre>
        <p><code>docker system df</code> breaks usage into images, containers, local volumes, and build cache, with a RECLAIMABLE column for what nothing is using. Add <code>-v</code> for a line per image and volume.</p>
        <div class="callout"><p><strong>Why Finder shows a huge number.</strong> <code>Docker.raw</code> is a sparse file: its listed size is the most it may grow to, not what it uses. On the Mac above, Finder and <code>ls</code> showed 926 GB while <code>du</code> showed 29 GB. Trust <code>du</code>, or Docker's own numbers.</p></div>

        <h2 style="margin-top:56px">What docker system prune deletes</h2>
        <p>By default, <code>docker system prune</code> removes:</p>
        <ul>
          <li><strong>Stopped containers.</strong> Anything you ran and didn't remove. Running containers stay.</li>
          <li><strong>Unused networks.</strong> Networks no container is attached to.</li>
          <li><strong>Dangling images.</strong> Untagged layers left behind when you rebuild or pull a newer tag. Tagged images stay.</li>
          <li><strong>Unused build cache.</strong> Layers BuildKit saved to make the next build faster.</li>
        </ul>
        <p>Is it safe? For the default command, yes. Everything it removes can be pulled or rebuilt; the cost is a slower next build. Two flags change that. <code>-a</code> removes every image no container uses, so you'll download them again. <code>--volumes</code> removes unused anonymous volumes, and a volume may be the only copy of a local database. Use it only when you know what's in them.</p>

        <h2 style="margin-top:56px">How to clear Docker cache, flag by flag</h2>
<pre><code>docker system prune                 # stopped containers, unused networks, dangling images, build cache
docker system prune -a              # plus every image no container uses
docker system prune --volumes       # plus unused anonymous volumes (data)
docker builder prune                # build cache only
docker builder prune -a             # all build cache, not just dangling
docker image prune -a               # unused images only
docker volume prune                 # unused anonymous volumes only</code></pre>
        <ul>
          <li><strong><code>-f</code></strong> skips the confirmation prompt. Leave it off when you type the command yourself.</li>
          <li><strong><code>--filter "until=24h"</code></strong> keeps anything created in the last day, which is handy when you want old layers gone but today's builds kept.</li>
          <li><strong><code>docker builder prune</code></strong> is the answer to “clear Docker cache” when you mean build cache. It leaves images and containers alone.</li>
        </ul>
        <p>If you really want to start over, Docker Desktop's <strong>Troubleshoot</strong> screen has <strong>Clean / Purge data</strong>, which erases every image, container, and volume. That's the supported way to empty <code>Docker.raw</code>.</p>

        <h2 style="margin-top:56px">How much disk space Docker uses</h2>
        <p>It depends on what you pull. A few base images and a database take a few gigabytes; a year of rebuilding multi-stage images can take tens. On the developer Mac above, Docker held 27.4 GB of images, and 15.4 GB of that was unused by any container. Volumes were 2.8 GB, half of it unused.</p>
        <p>The file grows up to the disk limit set in Docker Desktop's <strong>Settings › Resources</strong>. Changing that limit can make Docker Desktop recreate the disk image, which erases everything in it, so read its warning before you apply. Prune first; Docker Desktop hands the freed space back to macOS, though <code>du</code> can take a few minutes to show it.</p>

        <h2 style="margin-top:56px">Don't delete Docker.raw</h2>
        <p>Moving <code>Docker.raw</code> to the Trash deletes every image, container, and volume at once, and Docker Desktop makes a new empty one. If that's what you want, use <strong>Clean / Purge data</strong> instead, so Docker does it cleanly.</p>
        <p>Docker is also one of the usual reasons <a href="/what-is-system-data-on-mac">System Data</a> looks huge in Storage settings. More caches: <a href="/clear-cache">every tool's cache, one page each</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast lists Docker under <strong>Cleanup › Worth a look › Docker disk image</strong>, sized by what the file really uses. It never moves that file to the Trash. Its <strong>Reclaim in System Data…</strong> button opens the <strong>Docker</strong> row in System Data, which shows images, containers, volumes, and build cache, each with how much is unused. <strong>Prune unused Docker data…</strong> shows you <code>docker system prune -f</code> and runs it only after you confirm. Volumes, running containers, and tagged images stay. It&#39;s free.</p>
    """,
    "mockup": "system-data",
    "related": ["/clear-cache/npm", "/clear-cache/xcode", "/system-data"],
    "faqs": [
        ("What does docker system prune do?", "It removes stopped containers, networks no container uses, dangling images, and unused build cache, after asking you to confirm. With -a it also removes every image no container is using, and with --volumes it removes unused anonymous volumes."),
        ("Is docker system prune safe?", "The default command is. Everything it removes can be pulled or rebuilt, so the cost is time on your next build. Be careful with --volumes: a volume may hold the only copy of a local database."),
        ("How do I clear Docker build cache?", "Run docker builder prune to remove dangling build cache, or docker builder prune -a to remove all of it. Images and containers aren't touched. The next build takes longer while BuildKit rebuilds its cache."),
        ("Where is Docker.raw on a Mac, and can I delete it?", "It's at ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw. Don't delete it: it holds every image, container, and volume. Use docker system prune, or Clean / Purge data in Docker Desktop's Troubleshoot screen."),
        ("Why is Docker taking up so much space on my Mac?", "Images pile up as you pull and rebuild, and build cache grows with every build. Run docker system df to see which. Finder can also show Docker.raw at its maximum size, because it's a sparse file; du shows what it really uses."),
    ],
}

CACHE_TOOLS = [DOCKER]

CLEAR_CACHE_HUB = {
    "path": "/clear-cache",
    "title": "Clear cache by tool on Mac: Docker, npm, Teams, and more",
    "description": "How to clear the cache of Docker, npm, pip, Teams, Yarn, Xcode, Gradle, Go, Cargo, and Homebrew on Mac: where each lives, its command, and what rebuilds.",
    "h1": "Clear any tool's cache on Mac, <em>one at a time.</em>",
    "lede": "Developer tools keep their own caches, in their own places, with their own commands to clear them. Each page has the real path on a Mac, the command with its flags explained, and what you'll wait for afterward.",
    "card_title": "Clear cache by tool",
    "card_blurb": "Docker, npm, pip, Teams, Xcode, and five more, one page each.",
    "footer": "Clear cache by tool",
    "cta": "Know before it's full.",
    "html": """
        <h2>Which cache is the big one?</h2>
        <p>Usually npm, Docker, or Xcode. On one developer Mac measured for these pages, npm's cache was 23 GB, Docker's disk image 29 GB, and Xcode's simulators and device support about 30 GB. pip, Go, and Homebrew were under a gigabyte each. To see yours, run <code>du -sh</code> on the paths each page lists, or <code>du -sh ~/Library/Caches/* ~/.* 2>/dev/null | sort -h | tail</code> for a quick look.</p>
        <p>Every cache here is safe to clear, because every tool downloads or rebuilds what it needs. The cost is time: a slower next install or build, and a network connection to get it. For browser and app caches, start with <a href="/how-to-clear-cache-on-mac">how to clear cache on Mac</a>. For local AI models, which are bigger still, see <a href="/ai-models">delete local AI models</a>.</p>
    """,
    "faqs": [
        ("Is it safe to clear developer caches on Mac?", "Yes. npm, pip, Yarn, Go, Cargo, Gradle, and Homebrew caches only hold downloads and build results the tool can make again. You'll wait longer on the next install or build, and need to be online for it."),
        ("Which developer cache takes the most space?", "Usually npm's ~/.npm, Docker's disk image, or Xcode's simulators and device support. Project folders like node_modules and Rust target folders often add up to more than any shared cache."),
        ("Why do developer caches come back after I clear them?", "Because they're doing their job. Each install or build fills the cache again. Clearing reclaims space for a while; it doesn't change how fast the cache refills."),
    ],
}

SECTIONS = [(CLEAR_CACHE_HUB, CACHE_TOOLS)]
for _hub, _tools in SECTIONS:
    for _t in _tools:
        _t["path"] = f"{_hub['path']}/{_t['slug']}"

# The hubs appear on /guides and in every footer, after the guides.
GUIDE_HUBS = [hub for hub, _ in SECTIONS]
