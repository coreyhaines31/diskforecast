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

# ------------------------------------------------------------------ npm
# "npm cache clean" 400, "clear npm cache" 300, "how to clear npm cache" 150, "npm cache location" 60.
NPM = {
    "slug": "npm",
    "title": "npm cache clean: how to clear npm cache on Mac",
    "description": "How to clear npm cache on Mac with npm cache clean --force, where the npm cache is located, why it never shrinks, and the npx folder it doesn't clear.",
    "h1": "How to clear npm cache on Mac, <em>and what it keeps.</em>",
    "lede": "npm keeps a copy of every package version it has ever downloaded, and it never deletes any of them on its own. Here's where that lives on a Mac and how to reclaim it.",
    "tldr": "Run <code>npm cache clean --force</code>. It empties <code>~/.npm/_cacache</code>, where npm keeps every package it has downloaded. Your projects and their <code>node_modules</code> folders aren't touched, and npm downloads packages again as you install them. It doesn't clear the npx cache: move <code>~/.npm/_npx</code> to the Trash for that.",
    "card_title": "npm",
    "card_blurb": "npm cache clean --force, the npx folder, and node_modules.",
    "paths": [
        ("Package cache", "~/.npm/_cacache", "19 GB"),
        ("Packages run with npx", "~/.npm/_npx", "4.8 GB"),
        ("Debug logs", "~/.npm/_logs", "Small"),
    ],
    "html": """
        <h2>npm cache location on Mac</h2>
        <p>On a Mac, npm's cache folder is <code>~/.npm</code>, a hidden folder in your home folder. To confirm where yours is:</p>
<pre><code>npm config get cache</code></pre>
        {{PATHS}}
        <p>Sizes are from one developer Mac in October 2026: 23 GB in all. It's one folder per user, so every Node version you install with nvm, fnm, or Homebrew shares it. To move it, run <code>npm config set cache /path/to/folder</code>, or set the <code>npm_config_cache</code> environment variable.</p>

        <h2 style="margin-top:56px">What npm cache clean deletes</h2>
        <p><code>_cacache</code> is a content-addressable store: the tarball and metadata for every package version npm has fetched, checked against its hash every time it's read. Clearing it is safe. Nothing in your projects depends on it; it only saves downloads.</p>
        <ul>
          <li><strong>What rebuilds:</strong> the next <code>npm install</code> downloads what it needs and puts it back in the cache.</li>
          <li><strong>What you lose:</strong> offline installs. <code>--offline</code> and <code>--prefer-offline</code> only work for packages that are cached.</li>
          <li><strong>What stays:</strong> <code>_npx</code>, <code>_logs</code>, your <code>~/.npmrc</code> settings, and every <code>node_modules</code> folder.</li>
        </ul>
        <p>npm's own documentation says the cache is self-healing: corrupted data is detected and fetched again. So clearing it rarely fixes an install error. Its real use is reclaiming disk space, which is why npm makes you add <code>--force</code>.</p>

        <h2 style="margin-top:56px">npm cache commands</h2>
<pre><code>npm config get cache                   # where the cache is
du -sh ~/.npm/_cacache ~/.npm/_npx     # how big it is
npm cache verify                       # check it and garbage-collect unneeded data
npm cache clean --force                # empty _cacache</code></pre>
        <ul>
          <li><strong><code>npm cache verify</code></strong> is the gentle option. It checks every entry and removes data nothing points to anymore. It reclaims some space, not most.</li>
          <li><strong><code>npm cache clean --force</code></strong> deletes everything in <code>_cacache</code>. Without <code>--force</code>, npm refuses and explains why.</li>
          <li><strong>The npx cache</strong> holds whole installs of every package you've run with <code>npx</code>, one folder per package. Quit anything running through npx, then move <code>~/.npm/_npx</code> to the Trash. npx downloads a package again the next time you run it.</li>
        </ul>

        <h2 style="margin-top:56px">How big the npm cache gets</h2>
        <p>npm never deletes cached data on its own, so the cache only grows. Every new version of every dependency, across every project, adds to it. A few gigabytes is normal after a year; on the developer Mac above, it reached 19 GB, plus 4.8 GB of npx installs. If you've never cleared it, it's likely one of the biggest folders in your home folder.</p>

        <h2 style="margin-top:56px">node_modules: usually the bigger folder</h2>
        <p>The cache is one folder. <code>node_modules</code> is one per project, and a single Next.js app can have hundreds of megabytes in it. To list them by size:</p>
<pre><code>find ~ -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>
        <p>Delete the ones in projects you haven't worked on in a while. <code>npm install</code> brings them back from the lockfile, and <code>npm ci</code> deletes and reinstalls them from scratch. If you use pnpm, its shared store at <code>~/Library/pnpm/store</code> is the equivalent of the npm cache: <code>pnpm store prune</code> removes packages no project uses. On the same Mac, it held 12 GB.</p>
        <p>Using Yarn instead? See <a href="/clear-cache/yarn">how to clear Yarn cache</a>. All the others: <a href="/clear-cache">clear cache by tool</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast lists <code>~/.npm/_cacache</code> and <code>~/.npm/_npx</code> as separate entries under <strong>Cleanup › Safe to clear › Package manager caches</strong>, next to the pnpm store and Bun&#39;s cache. Your <code>node_modules</code> folders show up too, only where a <code>package.json</code> sits beside them: under <strong>Build folders in old projects</strong> if the project hasn&#39;t changed in 30 days, or <strong>Build folders in active projects</strong> if it has. Everything goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/yarn", "/clear-cache/docker", "/clear-cache/homebrew"],
    "faqs": [
        ("How do I clear the npm cache?", "Run npm cache clean --force. It empties ~/.npm/_cacache, and npm downloads packages again as you install them. npm requires --force because its cache is self-healing and rarely needs clearing for any reason other than disk space."),
        ("Where is the npm cache located on a Mac?", "In ~/.npm, a hidden folder in your home folder. The package cache is ~/.npm/_cacache and npx installs are in ~/.npm/_npx. Run npm config get cache to confirm the location on your Mac."),
        ("Is it safe to delete the npm cache?", "Yes. It's only a store of downloaded packages; no project depends on it. The next npm install downloads what it needs, so it takes longer once and offline installs stop working until the cache refills."),
        ("Does npm cache clean delete node_modules?", "No. It only empties ~/.npm/_cacache. Each project's node_modules folder stays until you delete it yourself. They're often bigger in total than the cache, and npm install brings them back."),
        ("Why is my npm cache so big?", "npm never deletes cached data on its own. Every version of every package you've installed, across every project and Node version, stays in it. npx adds a full install for each package you run in ~/.npm/_npx."),
    ],
}

# ------------------------------------------------------------------ pip
# "clear pip cache" 300, "pip cache purge" 200.
PIP = {
    "slug": "pip",
    "title": "Clear pip cache on Mac with pip cache purge",
    "description": "How to clear pip cache on Mac with pip cache purge, where pip keeps its cache, what's inside it, and how to clear uv, conda, and virtual environments too.",
    "h1": "How to clear pip cache on Mac, <em>with pip itself.</em>",
    "lede": "pip keeps the packages it downloads and the wheels it builds, so installing them again is fast. On a Mac that cache lives in your Library folder, and pip has its own command to empty it.",
    "tldr": "Run <code>pip cache purge</code>. It empties pip's cache, which on a Mac is <code>~/Library/Caches/pip</code>. Installed packages and your virtual environments aren't touched; pip downloads what it needs again on the next install. With more than one Python, run <code>python3 -m pip cache purge</code> so you clear the cache of the pip you actually use.",
    "card_title": "pip",
    "card_blurb": "pip cache purge, uv, conda, and virtual environments.",
    "paths": [
        ("Downloaded packages and index pages", "~/Library/Caches/pip/http-v2", "612 MB in 1,502 files"),
        ("Wheels pip built from source", "~/Library/Caches/pip/wheels", "19 MB, 4 wheels"),
    ],
    "html": """
        <h2>Where pip keeps its cache on a Mac</h2>
        <p>pip follows the Mac convention and keeps its cache in <code>~/Library/Caches/pip</code>, not in the <code>~/.cache</code> folder it uses on Linux. Ask pip directly:</p>
<pre><code>pip cache dir
pip cache info</code></pre>
        {{PATHS}}
        <p>Sizes are from <code>pip cache info</code> on one developer Mac in October 2026. pip 23.3 and later use <code>http-v2</code>; older versions used <code>http</code>, and both can be there if you've upgraded. If you set <code>PIP_CACHE_DIR</code> or <code>XDG_CACHE_HOME</code>, the cache moves with it.</p>

        <h2 style="margin-top:56px">Is it safe to clear pip cache?</h2>
        <p>Yes. The cache is only a shortcut. It holds package files pip downloaded and wheels it compiled from source, so the next install of the same version skips the download or the build.</p>
        <ul>
          <li><strong>What stays:</strong> every package you've installed, in every Python and every virtual environment. Purging the cache uninstalls nothing.</li>
          <li><strong>What rebuilds:</strong> the next install downloads again. Packages without a wheel for your Mac compile again, which can take minutes for some scientific packages.</li>
          <li><strong>When it helps:</strong> reclaiming space, or forcing pip to fetch a fresh copy of a package that installed wrong.</li>
        </ul>

        <h2 style="margin-top:56px">pip cache commands</h2>
<pre><code>pip cache list                    # wheels in the cache
pip cache remove numpy            # one package's wheels
pip cache purge                   # everything
pip install --no-cache-dir torch  # install without reading or writing the cache</code></pre>
        <ul>
          <li><strong><code>pip cache purge</code></strong> removes all items from both the HTTP cache and the wheels folder.</li>
          <li><strong><code>pip cache remove</code></strong> takes a package name or a glob, like <code>"torch*"</code>, and removes matching wheels. Use it when one big package is the problem.</li>
          <li><strong><code>--no-cache-dir</code></strong> is useful for a one-off install of something huge, so it never lands in the cache.</li>
        </ul>
        <p>If pip says the cache is disabled or empty when you know it isn't, you're probably running a different pip than you think. <code>which -a pip pip3</code> lists them; <code>python3 -m pip</code> always uses the pip of that Python.</p>

        <h2 style="margin-top:56px">How big the pip cache gets</h2>
        <p>Usually hundreds of megabytes. On the developer Mac above, it was 605 MB. It gets bigger if you work with machine learning packages, since each version of a framework like PyTorch is a large download, and pip keeps every version you've installed.</p>

        <h2 style="margin-top:56px">Other Python caches</h2>
        <ul>
          <li><strong>uv:</strong> keeps its cache in <code>~/.cache/uv</code>. <code>uv cache clean</code> empties it; <code>uv cache prune</code> removes only entries nothing uses.</li>
          <li><strong>conda:</strong> keeps downloaded packages in the <code>pkgs</code> folder of your conda install. <code>conda clean --all</code> removes unused packages, tarballs, and index caches.</li>
          <li><strong>Virtual environments:</strong> a <code>.venv</code> folder holds a full copy of every package a project uses. Delete the ones in old projects; <code>pip install -r requirements.txt</code> or <code>uv sync</code> rebuilds them.</li>
        </ul>
        <p>Next, <a href="/clear-cache/homebrew">Homebrew's cache</a> sits right beside pip's in <code>~/Library/Caches</code>. Or see <a href="/clear-cache">every tool's cache</a>.</p>
    """,
    "finds": """
          <p>pip&#39;s cache sits in <code>~/Library/Caches</code>, so Disk Forecast lists it as the <code>pip</code> entry under <strong>Cleanup › Safe to clear › App caches</strong>. If you&#39;ve moved it to <code>~/.cache/pip</code>, it shows under <strong>Package manager caches</strong> instead, alongside uv. Virtual environments show up under the build folder rows, as long as a <code>pyproject.toml</code>, <code>requirements.txt</code>, <code>setup.py</code>, or <code>Pipfile</code> sits beside the <code>.venv</code>. Everything goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/npm", "/clear-cache/homebrew", "/clear-cache/go"],
    "faqs": [
        ("How do I clear pip cache?", "Run pip cache purge, or python3 -m pip cache purge to target a specific Python. It removes everything in pip's cache. To remove one package instead, run pip cache remove followed by its name."),
        ("Where is the pip cache on a Mac?", "In ~/Library/Caches/pip. Run pip cache dir to confirm. It holds downloaded files in http-v2 (http on older pip) and wheels pip built from source in wheels."),
        ("Does pip cache purge uninstall packages?", "No. It only empties the cache of downloaded files and built wheels. Every installed package, in every environment, stays. pip downloads again the next time you install."),
        ("Is it safe to delete the pip cache folder?", "Yes. You can also move ~/Library/Caches/pip to the Trash yourself; pip recreates it. pip cache purge does the same thing without leaving Terminal."),
        ("How do I install a package without using the cache?", "Add --no-cache-dir: pip install --no-cache-dir package-name. pip neither reads from nor writes to the cache for that install."),
    ],
}

# ------------------------------------------------------------------ Yarn
# "yarn cache clean" 100, "clear yarn cache" 70, "yarn cache location".
YARN = {
    "slug": "yarn",
    "title": "Yarn cache clean: clear Yarn cache on Mac, for every version",
    "description": "How to clear Yarn cache on Mac for Yarn 1 and Yarn Berry: where each keeps its cache, what yarn cache clean --all removes, and the folder not to delete.",
    "h1": "Yarn cache clean on Mac, <em>for every Yarn.</em>",
    "lede": "Yarn 1 and Yarn 2 and later keep their caches in different places and clear them with different flags. Start by finding out which one a project uses.",
    "tldr": "For Yarn 1 (classic), run <code>yarn cache clean</code>; its cache is <code>~/Library/Caches/Yarn</code> on a Mac. For Yarn 2 and later (Berry), run <code>yarn cache clean --all</code> inside a project to clear both the shared cache in <code>~/.yarn/berry/cache</code> and that project's cache. If a project commits <code>.yarn/cache</code> to git, leave that folder alone.",
    "card_title": "Yarn",
    "card_blurb": "yarn cache clean for Yarn 1 and Berry, and where each cache lives.",
    "paths": [
        ("Yarn 1 cache", "~/Library/Caches/Yarn/v6", "424 MB"),
        ("Yarn Berry shared cache", "~/.yarn/berry/cache", "Not present on the Mac we measured"),
        ("Yarn Berry project cache", "your-project/.yarn/cache", "Per project"),
    ],
    "html": """
        <h2>Yarn cache location on Mac</h2>
        <p>First, check which Yarn a project runs. Inside the project folder:</p>
<pre><code>yarn --version</code></pre>
        <p>1.x is classic Yarn. 2.x, 3.x, or 4.x is Berry, usually pinned by the <code>packageManager</code> field in <code>package.json</code>, so one Mac can run both. Each keeps its cache in a different place:</p>
        {{PATHS}}
        <p>Sizes are from one developer Mac in October 2026, which only had classic Yarn caches. To print the location yourself, use <code>yarn cache dir</code> for Yarn 1, or <code>yarn config get cacheFolder</code> inside a Berry project. Yarn 4 uses the shared cache by default; Yarn 2 and 3 keep a cache per project unless <code>enableGlobalCache</code> is on.</p>

        <h2 style="margin-top:56px">How to clear Yarn cache</h2>
        <h3>Yarn 1 (classic)</h3>
<pre><code>yarn cache list               # what's cached
yarn cache clean              # everything
yarn cache clean lodash       # one package</code></pre>
        <h3>Yarn 2 and later (Berry)</h3>
<pre><code>yarn cache clean              # this project's cache
yarn cache clean --mirror     # the shared cache in ~/.yarn/berry/cache
yarn cache clean --all        # both</code></pre>
        <p>Run Berry's commands from inside a Berry project, since that's where Yarn decides which version to use. In Yarn 4, plain <code>yarn cache clean</code> may have little to clear because packages go to the shared cache; <code>--all</code> is the one that reclaims space.</p>

        <h2 style="margin-top:56px">Is it safe to clear Yarn cache?</h2>
        <p>Yes, with one exception. The cache only holds package archives, and the next <code>yarn install</code> fetches what's missing. Your lockfile decides what gets installed, so nothing changes about your dependencies.</p>
        <div class="callout"><p><strong>The exception: zero-installs.</strong> Some Berry projects commit <code>.yarn/cache</code> to git so a fresh clone runs without an install. In those, the folder is part of the repository. Deleting it shows up as hundreds of changed files. Check <code>git status</code> before you touch it.</p></div>

        <h2 style="margin-top:56px">How big the Yarn cache gets</h2>
        <p>Like npm, Yarn keeps every version you've downloaded. Classic Yarn also keeps unpacked copies, so it grows faster than you'd expect. On the developer Mac above, it was 424 MB, which is small because most projects there use npm and pnpm. On a Mac that's used Yarn for years, a few gigabytes is common.</p>

        <h2 style="margin-top:56px">What about node_modules?</h2>
        <p>Projects using classic Yarn, or Berry with <code>nodeLinker: node-modules</code>, have a <code>node_modules</code> folder in each project, and those usually add up to more than the cache. Delete them in old projects; <code>yarn install</code> brings them back. Berry's default Plug'n'Play mode has no <code>node_modules</code> at all: it reads packages straight from the cache, which is why the cache matters more there.</p>
        <p>Also clearing npm? See <a href="/clear-cache/npm">npm cache clean</a>. Or browse <a href="/clear-cache">every tool's cache</a>.</p>
    """,
    "finds": """
          <p>Classic Yarn&#39;s cache is in <code>~/Library/Caches</code>, so Disk Forecast lists it as the <code>Yarn</code> entry under <strong>Cleanup › Safe to clear › App caches</strong>. Berry&#39;s shared cache in <code>~/.yarn/berry/cache</code> isn&#39;t listed; clear it with <code>yarn cache clean --mirror</code>. <code>node_modules</code> folders next to a <code>package.json</code> show up under <strong>Build folders in old projects</strong> or <strong>Build folders in active projects</strong>, depending on when you last changed the project. Everything goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/npm", "/clear-cache/homebrew", "/clear-cache/docker"],
    "faqs": [
        ("How do I clear the Yarn cache?", "For Yarn 1, run yarn cache clean. For Yarn 2 and later, run yarn cache clean --all inside a project to clear the shared cache and that project's cache. Check which you have with yarn --version."),
        ("Where is the Yarn cache located on a Mac?", "Yarn 1 uses ~/Library/Caches/Yarn; run yarn cache dir to confirm. Yarn 2 and later use ~/.yarn/berry/cache for the shared cache and .yarn/cache inside each project."),
        ("What's the difference between yarn cache clean and yarn cache clean --all?", "In Yarn 2 and later, yarn cache clean removes the current project's cache, --mirror removes the shared cache, and --all removes both. In Yarn 1, yarn cache clean removes the whole cache."),
        ("Is it safe to delete the Yarn cache?", "Yes, unless the project commits .yarn/cache to git for zero-installs. Then the folder is part of the repository. Otherwise, yarn install downloads what's missing."),
    ],
}

# ------------------------------------------------------------------ Homebrew
# "brew cleanup" 50, "clear homebrew cache" 10.
HOMEBREW = {
    "slug": "homebrew",
    "title": "brew cleanup: how to clear Homebrew cache on Mac",
    "description": "How to clear Homebrew cache on Mac with brew cleanup: where brew --cache points, what --prune=all and -s remove, and how to reclaim old versions too.",
    "h1": "brew cleanup on Mac, <em>flag by flag.</em>",
    "lede": "Homebrew keeps every bottle and installer it downloads, and old versions of formulae you've upgraded. One command handles both, and a few flags decide how far it goes.",
    "tldr": "Run <code>brew cleanup</code>. It removes old versions of upgraded formulae and downloads more than 120 days old from <code>~/Library/Caches/Homebrew</code>. To empty the download cache completely, run <code>brew cleanup --prune=all</code>. Add <code>-n</code> first to see what would go. Installed formulae and casks keep working.",
    "card_title": "Homebrew",
    "card_blurb": "brew cleanup, --prune=all, and brew --cache.",
    "paths": [
        ("Downloads (bottles, casks)", "~/Library/Caches/Homebrew", "813 MB"),
        ("Installed formulae, all versions", "/opt/homebrew/Cellar (Apple silicon), /usr/local/Cellar (Intel)", "Not measured"),
    ],
    "html": """
        <h2>Where the Homebrew cache is on a Mac</h2>
<pre><code>brew --cache</code></pre>
        <p>That prints <code>~/Library/Caches/Homebrew</code> unless you've set <code>HOMEBREW_CACHE</code>.</p>
        {{PATHS}}
        <p>The cache size is from one developer Mac running Homebrew 7 in October 2026. The cache holds the bottle (prebuilt package) for each formula version you've installed, and the <code>.dmg</code> or <code>.zip</code> for each cask. The other place space builds up is the Cellar, where old versions of a formula can stay after an upgrade.</p>

        <h2 style="margin-top:56px">What brew cleanup removes</h2>
<pre><code>brew cleanup -n                # show what would be removed, remove nothing
brew cleanup                   # old versions, plus downloads over 120 days old
brew cleanup --prune=all       # every download in the cache
brew cleanup -s                # scrub: downloads even for the latest versions
brew cleanup node              # only one formula</code></pre>
        <ul>
          <li><strong>Plain <code>brew cleanup</code></strong> removes old versions of installed formulae, stale lock files, and downloads more than 120 days old. Change that age with <code>HOMEBREW_CLEANUP_MAX_AGE_DAYS</code>.</li>
          <li><strong><code>--prune=all</code></strong> removes every cache file regardless of age. <code>--prune=30</code> keeps the last 30 days.</li>
          <li><strong><code>-s</code></strong> scrubs the cache, including downloads for the latest versions. Downloads for anything currently installed still stay; Homebrew's help says to delete <code>"$(brew --cache)"</code> yourself if you want those gone too.</li>
        </ul>
        <p>Is it safe? Yes. Everything in the cache can be downloaded again, and installed packages don't need their bottles to run. The only thing you give up is reinstalling an old version offline. If you pinned a formula with <code>brew pin</code>, cleanup leaves its versions alone.</p>

        <h2 style="margin-top:56px">Homebrew already cleans up, mostly</h2>
        <p>Homebrew runs a cleanup for each formula you upgrade or reinstall, and a full cleanup every 30 days. So on most Macs, running it by hand reclaims hundreds of megabytes, not tens of gigabytes. On the Mac above, the cache was 813 MB. If you've set <code>HOMEBREW_NO_INSTALL_CLEANUP</code>, none of that happens, and the cache and Cellar keep growing until you run <code>brew cleanup</code> yourself.</p>

        <h2 style="margin-top:56px">The bigger wins in Homebrew</h2>
        <p>The cache is rarely the problem. What's installed is:</p>
<pre><code>brew leaves                    # formulae you installed on purpose
brew autoremove -n             # dependencies nothing needs anymore
du -sh $(brew --prefix)/Cellar/* | sort -h | tail</code></pre>
        <p>Uninstall what you don't use with <code>brew uninstall</code>, then run <code>brew autoremove</code> to remove the dependencies it left behind. Big ones are usually language runtimes and databases: several Python, Node, or PostgreSQL versions installed side by side.</p>
        <p>Next: <a href="/clear-cache/pip">pip's cache</a> sits beside Homebrew's, and <a href="/clear-cache/npm">npm's</a> is often the biggest. Or see <a href="/clear-cache">every tool's cache</a>.</p>
    """,
    "finds": """
          <p>Homebrew&#39;s cache lives in <code>~/Library/Caches</code>, so Disk Forecast lists it as the <code>Homebrew</code> entry under <strong>Cleanup › Safe to clear › App caches</strong>, checked by default, and moves it to the Trash. Old versions in the Cellar aren&#39;t listed; <code>brew cleanup</code> is the right tool for those. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/pip", "/clear-cache/npm", "/clear-cache/xcode"],
    "faqs": [
        ("What does brew cleanup do?", "It removes old versions of installed formulae, stale lock files, and downloads more than 120 days old from Homebrew's cache. Add -n to see what it would remove first."),
        ("How do I clear the Homebrew cache completely?", "Run brew cleanup --prune=all. It removes every file in the cache regardless of age. Downloads for installed packages can stay; delete the folder brew --cache prints to remove those too."),
        ("Where is the Homebrew cache on a Mac?", "In ~/Library/Caches/Homebrew. Run brew --cache to confirm, or set HOMEBREW_CACHE to move it."),
        ("Is it safe to delete the Homebrew cache?", "Yes. Installed formulae and casks don't need their downloads to run, and Homebrew downloads them again if you reinstall. You only lose the ability to reinstall an old version offline."),
    ],
}

CACHE_TOOLS = [DOCKER, NPM, PIP, YARN, HOMEBREW]

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
