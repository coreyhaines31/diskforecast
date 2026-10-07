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

# ------------------------------------------------------------------ Teams
# "clear teams cache mac" 250. Teams isn't installed on the measuring Mac, so there's no measured size.
TEAMS = {
    "slug": "teams",
    "title": "Clear Teams cache on Mac: the new Microsoft Teams app",
    "description": "How to clear Teams cache on Mac for the new Microsoft Teams app: the two folders Microsoft names, what you lose, and when clearing it won't help at all.",
    "h1": "How to clear Teams cache on Mac, <em>the right way.</em>",
    "lede": "Microsoft's own steps for the new Teams on Mac, done with the Trash instead of a permanent delete, and the problems Microsoft says clearing the cache won't fix.",
    "tldr": "Quit Teams with Command-Q. Then move two folders to the Trash: <code>~/Library/Group Containers/UBF8T346G9.com.microsoft.teams</code> and <code>~/Library/Containers/com.microsoft.teams2</code>. Those are the folders Microsoft names for the new Teams on Mac. Open Teams again; the first launch is slower while it rebuilds. Your chats and files live in Microsoft 365, so they aren't affected.",
    "card_title": "Microsoft Teams",
    "card_blurb": "The two folders Microsoft names for the new Teams on Mac.",
    "paths": [
        ("New Teams, shared data", "~/Library/Group Containers/UBF8T346G9.com.microsoft.teams", "Not installed on the Mac we measured"),
        ("New Teams, app container", "~/Library/Containers/com.microsoft.teams2", "Not installed on the Mac we measured"),
        ("Classic Teams", "~/Library/Application Support/Microsoft/Teams", "Not installed on the Mac we measured"),
    ],
    "html": """
        <h2>Where the Teams cache lives on a Mac</h2>
        <p>The new Teams app doesn't keep its cache in <code>~/Library/Caches</code> like most apps. It keeps it inside its own containers, mixed in with its settings and logs:</p>
        {{PATHS}}
        <p>If <code>~/Library/Containers/com.microsoft.teams2</code> exists, you have the new Teams. The classic app's folder only matters if you still have the old app. To see how much space yours uses:</p>
<pre><code>du -sh ~/Library/Group\\ Containers/UBF8T346G9.com.microsoft.teams ~/Library/Containers/com.microsoft.teams2</code></pre>
        <p>The first time, macOS may ask whether Terminal can access data from other apps. Allow it, or the numbers will be incomplete.</p>

        <h2 style="margin-top:56px">How to clear Teams cache on Mac, step by step</h2>
        <ol class="steps">
          <li><b>Quit Teams completely.</b> Press Command-Q in Teams, or right-click its Dock icon and choose <strong>Quit</strong>. Closing the window isn't enough.</li>
          <li><b>Trash the group container.</b> In Finder, choose <strong>Go › Go to Folder</strong>, type <code>~/Library/Group Containers</code>, and move <code>UBF8T346G9.com.microsoft.teams</code> to the Trash.</li>
          <li><b>Trash the app container.</b> Go to <code>~/Library/Containers</code> and move the new Teams container to the Trash. Finder may list it by name, as Microsoft Teams, instead of <code>com.microsoft.teams2</code>.</li>
          <li><b>Open Teams.</b> It rebuilds both folders. The first launch takes longer, and you may need to sign in again.</li>
          <li><b>Empty the Trash later.</b> Once Teams works the way you want, empty the Trash to reclaim the space.</li>
        </ol>
        <p>Microsoft's article gives the same two folders as Terminal commands using <code>rm -rf</code>, which deletes them permanently. The Finder steps above do the same job and leave you a way back.</p>
        <p>Using Teams in a browser instead? Then its cache is your browser's: see <a href="/how-to-clear-cache-on-mac">how to clear cache on Mac</a> for Safari, Chrome, and Firefox.</p>

        <h2 style="margin-top:56px">What clearing the Teams cache deletes</h2>
        <p>Cached images and web content, local settings, and Teams' diagnostic logs. Your messages, channels, meetings, and files are stored in Microsoft 365, and Teams downloads what it needs again.</p>
        <p>Microsoft is specific about when not to do it. For missing messages, chat history that won't load, a missing team or channel, or wrong notifications and unread counts, clearing the cache doesn't help, and it deletes the logs IT needs to find the cause. It's a targeted fix for problems with the app itself: Teams that won't open, won't sign in, or shows stale content after a change.</p>

        <h2 style="margin-top:56px">How big the Teams cache gets</h2>
        <p>Microsoft doesn't publish a typical size, and we couldn't measure it: Teams isn't installed on the Mac this page was written on. It grows with use, since it holds web content and logs, so check yours with the <code>du</code> command above before deciding it's worth clearing. If it's only a few hundred megabytes, clearing it won't change much on your disk.</p>
        <p>More caches, one tool at a time: <a href="/clear-cache/xcode">Xcode</a>, <a href="/clear-cache/docker">Docker</a>, or <a href="/clear-cache">the full list</a>.</p>
    """,
    "finds": """
          <p>Here&#39;s the honest answer: Disk Forecast doesn&#39;t list the Teams cache. Its <strong>App caches</strong> row covers <code>~/Library/Caches</code>, and Teams keeps its cache in its own containers instead. What Disk Forecast does show is where your space went, with <code>~/Library</code> in its <strong>Taking the most space</strong> list, and when your disk will be full at the rate it&#39;s filling. It&#39;s free.</p>
    """,
    "mockup": "menu",
    "related": ["/how-to-clear-cache-on-mac", "/clear-cache/xcode", "/clear-cache/docker"],
    "faqs": [
        ("How do I clear Teams cache on a Mac?", "Quit Teams with Command-Q, then move ~/Library/Group Containers/UBF8T346G9.com.microsoft.teams and ~/Library/Containers/com.microsoft.teams2 to the Trash. Those are the folders Microsoft names for the new Teams. Open Teams again and it rebuilds them."),
        ("Will clearing the Teams cache delete my chats?", "No. Messages, channels, meetings, and files are stored in Microsoft 365, not in the cache. You may need to sign in again, and local settings reset."),
        ("Where is the Teams cache on a Mac?", "For the new Teams, in ~/Library/Group Containers/UBF8T346G9.com.microsoft.teams and ~/Library/Containers/com.microsoft.teams2. The classic app used ~/Library/Application Support/Microsoft/Teams."),
        ("Should I clear the Teams cache if messages are missing?", "No. Microsoft says clearing the cache doesn't fix missing messages, chat history that won't load, or wrong unread counts, and it deletes the logs needed to find the cause. Contact your IT team instead."),
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

# ------------------------------------------------------------------ Xcode
# "clear xcode cache" 50, "delete derived data xcode" 40, "deriveddata" 10, "xcode deriveddata" 10, "xcode storage" 10.
XCODE = {
    "slug": "xcode",
    "title": "Clear Xcode cache on Mac: DerivedData, simulators, and more",
    "description": "How to clear Xcode cache on Mac: delete DerivedData, old device support, and simulator runtimes, what each rebuilds, and the archives you may want to keep.",
    "h1": "How to clear Xcode cache on Mac, <em>folder by folder.</em>",
    "lede": "Xcode spreads its storage across several folders, and DerivedData usually isn't the biggest. Here's each one, what it holds, and what happens when you delete it.",
    "tldr": "Quit Xcode, then move the folders inside <code>~/Library/Developer/Xcode/DerivedData</code> to the Trash; Xcode rebuilds them on the next build. The bigger wins are usually simulator runtimes, which you delete in <strong>Xcode › Settings › Components</strong> or with <code>xcrun simctl runtime delete</code>, and folders in <code>iOS DeviceSupport</code> for devices you no longer plug in.",
    "card_title": "Xcode",
    "card_blurb": "DerivedData, device support, simulators, and archives.",
    "paths": [
        ("DerivedData", "~/Library/Developer/Xcode/DerivedData", "1.7 GB"),
        ("Device support", "~/Library/Developer/Xcode/iOS DeviceSupport", "4.3 GB"),
        ("Simulators and their apps", "~/Library/Developer/CoreSimulator/Devices", "10 GB, 22 simulators"),
        ("Simulator runtimes", "Managed by macOS; <code>xcrun simctl runtime list</code>", "15.7 GB, 2 iOS runtimes"),
        ("Archives", "~/Library/Developer/Xcode/Archives", "None"),
    ],
    "html": """
        <h2>Xcode storage: where it goes</h2>
        <p>Here's every folder that grows as you use Xcode, measured on one developer Mac running Xcode 27 in October 2026:</p>
        {{PATHS}}
        <p>DerivedData was the smallest of the big ones. That's typical: it gets the attention, but simulators and device support usually take more. Check yours with <code>du -sh ~/Library/Developer/Xcode/* ~/Library/Developer/CoreSimulator</code>.</p>

        <h2 style="margin-top:56px">How to delete DerivedData in Xcode</h2>
        <p>DerivedData holds build products, intermediate files, and the index Xcode uses for code completion and search, one folder per project. It's always safe to delete. Xcode rebuilds it, and the cost is one slow build and a few minutes of indexing.</p>
        <ol class="steps">
          <li><b>For one project:</b> choose <strong>Product › Clean Build Folder</strong>, or press Shift-Command-K. That removes the project's build products, not its index.</li>
          <li><b>For everything:</b> quit Xcode, open <code>~/Library/Developer/Xcode/DerivedData</code> in Finder with <strong>Go › Go to Folder</strong>, and move the folders inside it to the Trash.</li>
          <li><b>To find the folder from Xcode:</b> <strong>Xcode › Settings › Locations</strong> shows the DerivedData path, with an arrow that opens it in Finder.</li>
        </ol>

        <h2 style="margin-top:56px">Device support, simulators, and archives</h2>
        <ul>
          <li><strong>Device support.</strong> When you plug in an iPhone, Apple Watch, or Apple TV, Xcode copies debug symbols for its OS version into <code>iOS DeviceSupport</code> (and <code>watchOS</code>, <code>tvOS</code>, or <code>visionOS DeviceSupport</code>). Each version is a few gigabytes, and old ones never leave. Delete folders for OS versions you no longer debug on; Xcode copies them again the next time that device connects.</li>
          <li><strong>Simulator runtimes.</strong> Each iOS runtime is several gigabytes, and Xcode keeps old ones after updates. Delete them in <strong>Xcode › Settings › Components</strong>, or in Terminal:
<pre><code>xcrun simctl runtime list
xcrun simctl runtime delete &lt;identifier&gt;
xcrun simctl delete unavailable</code></pre>
          The last command removes simulators whose runtime is gone, which can't run anyway. Runtimes count toward System Data, not toward any folder you can see.</li>
          <li><strong>Archives.</strong> Builds you archived for App Store or TestFlight, in <strong>Window › Organizer</strong>. They hold the symbols for reading crash reports from that release, so keep the ones for versions people still run.</li>
        </ul>
        <p>Simulators also keep caches in <code>~/Library/Developer/CoreSimulator/Caches</code>, which the Simulator rebuilds on its own. The simulators themselves, with every app you've installed on them, are in <code>CoreSimulator/Devices</code>; erase or delete ones you don't use from Xcode's <strong>Window › Devices and Simulators</strong>.</p>

        <h2 style="margin-top:56px">How big Xcode gets</h2>
        <p>Xcode itself is several gigabytes, and everything above comes on top. On the developer Mac measured here, the folders in the table added up to about 32 GB. A Mac that has followed iOS betas for a few years, with several devices plugged in, can easily pass 100 GB.</p>

        <h2 style="margin-top:56px">Build folders outside Xcode</h2>
        <p>Swift packages built from the command line keep their output in a <code>.build</code> folder beside <code>Package.swift</code>; <code>swift package clean</code> empties it, or delete the folder. Projects using CocoaPods have a <code>Pods</code> folder that <code>pod install</code> rebuilds. Packages Xcode resolves for an app project live in DerivedData, so clearing it clears them too.</p>
        <p>For simulators in System Data, see <a href="/system-data">how to clear System Data</a>. Or browse <a href="/clear-cache">every tool's cache</a>, like <a href="/clear-cache/docker">Docker</a> and <a href="/clear-cache/homebrew">Homebrew</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast lists each Xcode folder on its own row. Under <strong>Cleanup › Safe to clear</strong>: <strong>Xcode DerivedData</strong>, <strong>Xcode device support</strong> (iOS, watchOS, tvOS, and visionOS), and <strong>Simulator caches</strong>. Under <strong>Worth a look</strong>: <strong>Xcode archives</strong>, unchecked. Swift <code>.build</code> folders and CocoaPods show up under the build folder rows. Simulators are in <strong>System Data › Simulators</strong>, with each runtime&#39;s size and a button that runs <code>xcrun simctl runtime delete</code> after you confirm. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/docker", "/clear-cache/homebrew", "/system-data"],
    "faqs": [
        ("How do I clear the Xcode cache?", "Quit Xcode and move the folders inside ~/Library/Developer/Xcode/DerivedData to the Trash. For one project, choose Product › Clean Build Folder. To reclaim more, delete old simulator runtimes in Xcode › Settings › Components and old folders in iOS DeviceSupport."),
        ("Is it safe to delete DerivedData?", "Yes. It holds build products and the index, and Xcode rebuilds both. The next build is slower and indexing runs again, but no source code or settings are affected."),
        ("Where is DerivedData on a Mac?", "In ~/Library/Developer/Xcode/DerivedData by default. Xcode › Settings › Locations shows the current path and can open it in Finder."),
        ("Why does Xcode take so much storage?", "Simulator runtimes and device support files add up: each iOS runtime and each device OS version is several gigabytes, and Xcode keeps old ones after updates. DerivedData and archives add more."),
        ("Can I delete iOS DeviceSupport folders?", "Yes. They're debug symbols copied from devices you've connected. Xcode copies them again the next time you connect a device running that OS version."),
    ],
}

# ------------------------------------------------------------------ Gradle
# "clear gradle cache" 80, "gradle cache location" 10. Gradle isn't installed on the measuring Mac.
GRADLE = {
    "slug": "gradle",
    "title": "Clear Gradle cache on Mac: what to delete in ~/.gradle",
    "description": "How to clear Gradle cache on Mac: where ~/.gradle keeps dependencies and wrapper downloads, why to stop the daemon first, and what Gradle cleans on its own.",
    "h1": "How to clear Gradle cache on Mac, <em>without breaking builds.</em>",
    "lede": "Gradle keeps downloaded dependencies, transformed jars, and a full copy of every Gradle version your projects' wrappers ask for. All of it lives in one folder, and most of it is safe to clear.",
    "tldr": "Stop the Gradle daemon with <code>./gradlew --stop</code>, then move <code>~/.gradle/caches</code> to the Trash. Gradle downloads dependencies again on the next build. For old Gradle versions, move folders you don't need out of <code>~/.gradle/wrapper/dists</code>. Leave <code>~/.gradle/gradle.properties</code> and <code>init.d</code> alone: those are your settings. Each project's own <code>build</code> folder clears with <code>./gradlew clean</code>.",
    "card_title": "Gradle",
    "card_blurb": "~/.gradle caches, wrapper downloads, and build folders.",
    "paths": [
        ("Dependencies and transforms", "~/.gradle/caches", "Not installed on the Mac we measured"),
        ("Gradle versions for the wrapper", "~/.gradle/wrapper/dists", "Not installed on the Mac we measured"),
        ("Daemon logs", "~/.gradle/daemon", "Not installed on the Mac we measured"),
        ("Each project's build output", "your-project/build", "Per project"),
    ],
    "html": """
        <h2>Gradle cache location on Mac</h2>
        <p>Gradle keeps everything in its user home, <code>~/.gradle</code>, unless <code>GRADLE_USER_HOME</code> points somewhere else. The same folder serves the command line, Android Studio, and IntelliJ IDEA.</p>
        {{PATHS}}
        <p>Gradle isn't installed on the Mac this page was written on, so there are no measured sizes here. Check yours with:</p>
<pre><code>du -sh ~/.gradle/* 2>/dev/null | sort -h</code></pre>

        <h2 style="margin-top:56px">What's safe to delete in ~/.gradle</h2>
        <ul>
          <li><strong><code>caches</code>: safe.</strong> Downloaded dependencies in <code>modules-2</code>, transformed jars, the local build cache, and per-version script caches. Gradle downloads or rebuilds what it needs. The first build afterward is slow, and it needs a network connection.</li>
          <li><strong><code>wrapper/dists</code>: safe, folder by folder.</strong> One full Gradle distribution for each version a project's wrapper asked for, each a hundred megabytes or more. Delete versions no current project uses; <code>./gradlew</code> downloads its version again if needed.</li>
          <li><strong><code>daemon</code>: safe.</strong> Logs from background Gradle processes.</li>
        </ul>
        <p>Keep <code>gradle.properties</code> (often with signing keys or repository credentials) and <code>init.d</code> (init scripts). They aren't cache.</p>

        <h2 style="margin-top:56px">How to clear Gradle cache, step by step</h2>
        <ol class="steps">
          <li><b>Stop the daemon.</b> Run <code>./gradlew --stop</code> in a project, or <code>gradle --stop</code>. Quit Android Studio too. A running daemon keeps files in the cache open.</li>
          <li><b>Clear project build folders, if you want.</b> <code>./gradlew clean</code> deletes the current project's <code>build</code> folder.</li>
          <li><b>Move the cache to the Trash.</b> In Terminal, <code>mv ~/.gradle/caches ~/.Trash/gradle-caches</code>, or open <code>~/.gradle</code> in Finder with <strong>Go › Go to Folder</strong>. It's hidden, so type the path.</li>
          <li><b>Build once.</b> Run your usual build while online. If it succeeds, empty the Trash.</li>
        </ol>
        <p>To force fresh dependencies without deleting anything, <code>./gradlew build --refresh-dependencies</code> checks every dependency against its repository again. It's the better fix when one library looks stale.</p>

        <h2 style="margin-top:56px">How big the Gradle cache gets</h2>
        <p>On an Android developer's Mac, several gigabytes is normal, and 10 GB or more is common after a few years, because each Android Gradle Plugin and Gradle upgrade brings a new set of transformed files. Gradle cleans the cache on a schedule by default, removing downloaded files unused for 30 days and files it created itself after 7 days; since Gradle 8 you can change those limits in an init script. Old Gradle versions' folders still pile up when no project uses them anymore.</p>
        <p>Android projects have more: the Android SDK in <code>~/Library/Android/sdk</code>, with system images for every emulator you've made, and the emulators themselves in <code>~/.android/avd</code>. Delete those from Android Studio's SDK Manager and Device Manager rather than Finder.</p>
        <p>Also on the JVM? Maven keeps its downloads in <code>~/.m2/repository</code>. More caches: <a href="/clear-cache/cargo">Cargo</a>, <a href="/clear-cache/go">Go</a>, or <a href="/clear-cache">every tool</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast lists <code>~/.gradle/caches</code> and <code>~/.gradle/wrapper/dists</code> under <strong>Cleanup › Safe to clear › Package manager caches</strong>. A project&#39;s <code>build</code> folder shows up as a Gradle build only when a <code>build.gradle</code> or <code>build.gradle.kts</code> sits beside it, so a random folder named build is never listed: under <strong>Build folders in old projects</strong> after 30 days without changes, or <strong>Build folders in active projects</strong> before that. Everything goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/cargo", "/clear-cache/go", "/clear-cache/xcode"],
    "faqs": [
        ("How do I clear the Gradle cache?", "Stop the daemon with ./gradlew --stop, quit Android Studio, then delete or move ~/.gradle/caches to the Trash. Gradle downloads dependencies again on the next build, which needs a network connection."),
        ("Where is the Gradle cache located on a Mac?", "In ~/.gradle/caches, inside Gradle's user home. Set GRADLE_USER_HOME to move it. Wrapper downloads of Gradle itself are in ~/.gradle/wrapper/dists."),
        ("Is it safe to delete ~/.gradle?", "Mostly. caches, wrapper/dists, and daemon can all go. Keep gradle.properties and init.d if you have them: they're your settings, and gradle.properties may hold credentials."),
        ("Does ./gradlew clean clear the Gradle cache?", "No. It deletes the current project's build folder. The shared cache in ~/.gradle/caches stays. To refetch dependencies without deleting the cache, use --refresh-dependencies."),
    ],
}

# ------------------------------------------------------------------ Go
# "go clean cache" 70, "go clean -modcache".
GO = {
    "slug": "go",
    "title": "go clean -cache: how to clear Go cache on Mac",
    "description": "How to clear Go cache on Mac: go clean -cache for builds, go clean -modcache for modules, where GOCACHE and GOMODCACHE are, and why Finder can't trash them.",
    "h1": "How to clear Go cache on Mac, <em>with go clean.</em>",
    "lede": "Go keeps two caches in two different places: one for build results, one for downloaded modules. Each has its own flag, and the module cache is read-only on purpose.",
    "tldr": "Run <code>go clean -cache</code> to empty the build cache, which on a Mac is <code>~/Library/Caches/go-build</code>. Run <code>go clean -modcache</code> to remove every downloaded module from <code>~/go/pkg/mod</code>. Both rebuild on the next <code>go build</code>, which downloads modules again. Use <code>go clean</code> for the module cache: its files are read-only, so the Trash and <code>rm</code> both fail.",
    "card_title": "Go",
    "card_blurb": "go clean -cache, -modcache, and where GOCACHE lives.",
    "paths": [
        ("Build cache (GOCACHE)", "~/Library/Caches/go-build", "258 MB"),
        ("Module cache (GOMODCACHE)", "~/go/pkg/mod", "24 MB"),
    ],
    "html": """
        <h2>Where Go keeps its cache on a Mac</h2>
<pre><code>go env GOCACHE GOMODCACHE</code></pre>
        {{PATHS}}
        <p>Sizes are from one developer Mac with Go 1.26 in October 2026. The build cache follows the Mac convention and lives in <code>~/Library/Caches</code>. The module cache lives under <code>GOPATH</code>, which is <code>~/go</code> unless you've changed it. Set <code>GOCACHE</code> or <code>GOMODCACHE</code> with <code>go env -w</code> to move them.</p>

        <h2 style="margin-top:56px">go clean flags for every cache</h2>
<pre><code>go clean -cache        # the build cache
go clean -testcache    # only cached test results
go clean -modcache     # every downloaded module
go clean -fuzzcache    # inputs saved by go test -fuzz</code></pre>
        <ul>
          <li><strong><code>-cache</code></strong> removes compiled packages and cached test results. The next build compiles everything from source, which takes longer for big projects. Safe.</li>
          <li><strong><code>-testcache</code></strong> keeps compiled code and only forgets test results, so <code>go test</code> runs every test again. Use it when a cached “ok” is hiding a flaky test; it frees almost nothing.</li>
          <li><strong><code>-modcache</code></strong> removes the source of every module you've downloaded. The next build downloads them again, from the Go module proxy by default. Safe if you're online; vendored projects don't need it at all.</li>
          <li><strong><code>-fuzzcache</code></strong> removes the inputs that fuzzing found interesting. Only clear it if you don't need to replay them.</li>
        </ul>

        <h2 style="margin-top:56px">Why go clean -modcache, not the Trash</h2>
        <p>Go makes every file in the module cache read-only, so nothing edits a dependency by accident. That's why moving <code>~/go/pkg/mod</code> to the Trash fails partway, and <code>rm -rf</code> prints “Permission denied” over and over. <code>go clean -modcache</code> fixes the permissions and removes it cleanly. If you'd rather have a cache you can delete normally, build with <code>-modcacherw</code>, or add it to <code>GOFLAGS</code>.</p>
        <p>The build cache has no such problem. You can move <code>~/Library/Caches/go-build</code> to the Trash, though <code>go clean -cache</code> does the same thing.</p>

        <h2 style="margin-top:56px">How big Go caches get</h2>
        <p>Go trims its own build cache: entries unused for about five days are removed as you build. So the build cache stays at a few hundred megabytes to a few gigabytes; on the Mac above, it was 258 MB. The module cache is never trimmed. Each version of each module stays until you clear it, so a Mac that has built many projects over a few years can hold several gigabytes. The <code>go</code> toolchains Go downloads for <code>toolchain</code> lines in <code>go.mod</code> live in the module cache too, at a few hundred megabytes each.</p>
        <p>Also writing Rust? See <a href="/clear-cache/cargo">cargo clean</a>. Or <a href="/clear-cache/homebrew">Homebrew</a>, and <a href="/clear-cache">every tool's cache</a>.</p>
    """,
    "finds": """
          <p>Go&#39;s build cache lives in <code>~/Library/Caches</code>, so Disk Forecast lists it as the <code>go-build</code> entry under <strong>Cleanup › Safe to clear › App caches</strong>, and moves it to the Trash. The module cache in <code>~/go/pkg/mod</code> isn&#39;t listed, since its read-only files are a job for <code>go clean -modcache</code>. Disk Forecast also shows where your space goes and forecasts when your disk will be full. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/cargo", "/clear-cache/homebrew", "/clear-cache/gradle"],
    "faqs": [
        ("How do I clear the Go cache?", "Run go clean -cache to empty the build cache, and go clean -modcache to remove downloaded modules. Both are safe; the next build compiles from source and downloads modules again."),
        ("What does go clean -modcache do?", "It removes the entire module download cache, ~/go/pkg/mod by default, including the unpacked source of every module version. Go downloads what a project needs again on the next build."),
        ("Where is the Go build cache on a Mac?", "In ~/Library/Caches/go-build. Run go env GOCACHE to confirm. The module cache is separate, in ~/go/pkg/mod; go env GOMODCACHE shows it."),
        ("Why can't I delete ~/go/pkg/mod?", "Go makes module cache files read-only so dependencies can't be edited by accident. Use go clean -modcache, which handles the permissions, instead of the Trash or rm."),
    ],
}

# ------------------------------------------------------------------ Cargo
# "cargo clean" 70, "clear cargo cache". Rust isn't installed on the measuring Mac.
CARGO = {
    "slug": "cargo",
    "title": "cargo clean: how to clear Cargo cache on Mac",
    "description": "How to clear Cargo cache on Mac: cargo clean for a project's target folder, what ~/.cargo/registry holds, and the cleanup Cargo does on its own since 1.88.",
    "h1": "cargo clean on Mac, <em>and what it misses.</em>",
    "lede": "In Rust, the big folder is almost never the shared cache. It's the target folder in every project you've built. Here's how to clear each, and what Cargo now clears on its own.",
    "tldr": "Run <code>cargo clean</code> in a project to delete its <code>target</code> folder, which is usually the biggest thing Rust leaves on your disk. For the shared cache of downloaded crates, move <code>~/.cargo/registry/cache</code> and <code>~/.cargo/registry/src</code> to the Trash; Cargo downloads what it needs again. Leave <code>~/.cargo/bin</code> alone: that's where <code>cargo</code> and your installed tools live.",
    "card_title": "Cargo",
    "card_blurb": "cargo clean, target folders, and ~/.cargo/registry.",
    "paths": [
        ("Each project's build output", "your-project/target", "Per project"),
        ("Downloaded crates", "~/.cargo/registry/cache", "Not installed on the Mac we measured"),
        ("Unpacked crate source", "~/.cargo/registry/src", "Not installed on the Mac we measured"),
        ("Git dependencies", "~/.cargo/git", "Not installed on the Mac we measured"),
    ],
    "html": """
        <h2>Where Cargo keeps its cache on a Mac</h2>
        <p>Cargo's home is <code>~/.cargo</code>, or wherever <code>CARGO_HOME</code> points. Build output doesn't go there: it goes in a <code>target</code> folder inside each project.</p>
        {{PATHS}}
        <p>Rust isn't installed on the Mac this page was written on, so there are no measured sizes here. Check yours with:</p>
<pre><code>du -sh ~/.cargo/registry ~/.cargo/git 2>/dev/null
find ~ -name target -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>
        <p>Not every folder named <code>target</code> is Rust's: check for a <code>Cargo.toml</code> beside it before you delete one.</p>

        <h2 style="margin-top:56px">What cargo clean deletes</h2>
<pre><code>cargo clean                  # the whole target folder
cargo clean --release        # only target/release
cargo clean --doc            # only target/doc
cargo clean -p some-crate    # one package's artifacts</code></pre>
        <p><code>cargo clean</code> removes compiled dependencies, incremental compilation data, and your binaries for that one project. It's safe: <code>cargo build</code> makes it all again, which can take minutes for a project with many dependencies. It doesn't touch <code>~/.cargo</code>.</p>
        <p>Why <code>target</code> gets so big: it keeps separate builds for debug and release, for every target triple you build, and incremental data for every crate. Changing compiler versions or features adds more rather than replacing. A medium project's <code>target</code> folder is often several gigabytes, and tens of gigabytes isn't unusual.</p>

        <h2 style="margin-top:56px">How to clear Cargo cache in ~/.cargo</h2>
        <ul>
          <li><strong><code>registry/cache</code>: safe.</strong> The compressed <code>.crate</code> file for every crate version you've downloaded.</li>
          <li><strong><code>registry/src</code>: safe.</strong> Those crates unpacked. Cargo unpacks them again from the cache, or downloads them.</li>
          <li><strong><code>git</code>: safe.</strong> Clones of dependencies that point at a git repository. Cargo clones them again.</li>
          <li><strong><code>bin</code>: keep.</strong> <code>cargo</code>, <code>rustc</code> shims from rustup, and everything you installed with <code>cargo install</code>.</li>
        </ul>
        <p>Cargo has no stable command to clear its home folder, so moving those folders to the Trash is the usual way. Do it with no build running. Toolchains themselves live in <code>~/.rustup/toolchains</code>; remove old ones with <code>rustup toolchain uninstall</code>.</p>

        <h2 style="margin-top:56px">How big the Cargo cache gets</h2>
        <p>Less than it used to. Since Rust 1.88, Cargo cleans its own cache automatically: it removes downloaded files it hasn't used in three months, and unpacked files it hasn't used in one month. So <code>~/.cargo/registry</code> usually holds a gigabyte or two. The <code>target</code> folders are another story: nothing cleans those, so ten old projects can mean tens of gigabytes. <code>cargo-sweep</code>, a third-party tool, can remove only the stale parts of a <code>target</code> folder if you'd rather not rebuild from scratch.</p>
        <p>Also writing Go? See <a href="/clear-cache/go">go clean -cache</a>. Or <a href="/clear-cache/gradle">Gradle</a>, and <a href="/clear-cache">every tool's cache</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast finds <code>target</code> folders only where a <code>Cargo.toml</code> sits beside them, so a folder that just happens to be called target is never listed. They appear as Rust build folders under <strong>Cleanup › Safe to clear › Build folders in old projects</strong> after 30 days without changes, or under <strong>Build folders in active projects</strong> before that. <code>~/.cargo/registry</code> is under <strong>Package manager caches</strong>. Everything goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/go", "/clear-cache/gradle", "/clear-cache/homebrew"],
    "faqs": [
        ("What does cargo clean do?", "It deletes the target folder of the current project: compiled dependencies, incremental data, and binaries. cargo build recreates it. It doesn't touch ~/.cargo or other projects."),
        ("How do I clear the Cargo cache?", "Move ~/.cargo/registry/cache, ~/.cargo/registry/src, and ~/.cargo/git to the Trash with no build running. Cargo downloads crates again as needed. Keep ~/.cargo/bin, which holds cargo and installed tools."),
        ("Is it safe to delete the Rust target folder?", "Yes. It only holds build output, and cargo build makes it again. The next build of that project takes as long as a first build."),
        ("Does Cargo clean its cache automatically?", "Since Rust 1.88, yes: Cargo removes downloaded files unused for three months and unpacked files unused for one month from its home folder. It never cleans target folders."),
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

CACHE_TOOLS = [DOCKER, NPM, PIP, TEAMS, YARN, XCODE, GRADLE, GO, CARGO, HOMEBREW]

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

# ------------------------------------------------------------------ Ollama
# "ollama remove model" 600, "ollama delete model" 450, "uninstall ollama" 350, "uninstall ollama mac" 150,
# "where are ollama models stored" 90, plus delete-all and location variants. Ollama isn't installed on the measuring Mac.
OLLAMA = {
    "slug": "ollama",
    "title": "Ollama remove model: delete, find, and uninstall on Mac",
    "description": "How to remove an Ollama model with ollama rm, delete all models at once, find where Ollama models are stored on Mac, and uninstall Ollama completely.",
    "h1": "Ollama remove model on Mac, <em>step by step.</em>",
    "lede": "A single local model can take more space than every app on your Mac. Here's how to see what you have, remove what you don't use, find where the files live, and uninstall Ollama completely.",
    "tldr": "Run <code>ollama list</code> to see your models and their sizes, then <code>ollama rm</code> with a model's name, like <code>ollama rm llama3.2</code>. Ollama deletes the model's files unless another model shares them. On a Mac, models live in <code>~/.ollama/models</code>. To uninstall Ollama, quit it, move the app to the Trash, and delete <code>~/.ollama</code>.",
    "card_title": "Ollama",
    "card_blurb": "ollama rm, where models are stored, and a full uninstall.",
    "paths": [
        ("Models", "~/.ollama/models", "Not installed on the Mac we measured"),
        ("Model files", "~/.ollama/models/blobs", "One sha256 file per layer"),
        ("Model names and tags", "~/.ollama/models/manifests", "Tiny"),
    ],
    "html": """
        <h2>How to remove an Ollama model</h2>
<pre><code>ollama list                 # every model, with its size
ollama ps                   # models loaded in memory right now
ollama stop llama3.2        # unload one from memory
ollama rm llama3.2          # delete one from disk
ollama rm llama3.2 qwen3:8b # delete several</code></pre>
        <p>Use the name exactly as <code>ollama list</code> shows it, tag included if it isn't <code>latest</code>: <code>ollama rm qwen3:8b</code> and <code>ollama rm qwen3</code> are different models. Ollama needs to be running for these commands; open the app or run <code>ollama serve</code>.</p>
        <p>Removing a model is safe. <code>ollama pull</code> downloads it again, and nothing else on your Mac depends on it. Custom models you made with <code>ollama create</code> are the exception: keep the Modelfile, or you'll have to recreate them by hand.</p>

        <h3>How to delete all Ollama models</h3>
        <p>There's no built-in command for it. This removes every model <code>ollama list</code> shows:</p>
<pre><code>ollama list | awk 'NR>1 {print $1}' | xargs ollama rm</code></pre>
        <p>Run <code>ollama list</code> first and make sure that's what you want.</p>

        <h2 style="margin-top:56px">Where are Ollama models stored on Mac?</h2>
        <p>In <code>~/.ollama/models</code>, a hidden folder in your home folder. To open it in Finder, choose <strong>Go › Go to Folder</strong> and type the path.</p>
        {{PATHS}}
        <p>Ollama isn't installed on the Mac this page was written on, so there are no measured sizes here. Check yours with <code>du -sh ~/.ollama/models</code>.</p>
        <p>Inside, <code>blobs</code> holds the actual weights as files named by their hash, and <code>manifests</code> maps names like <code>llama3.2:latest</code> to those blobs. Models that share a base share blobs, which is why <code>ollama rm</code> sometimes frees less than the size <code>ollama list</code> showed. Don't delete individual blobs by hand; you'll break whichever model uses them. Use <code>ollama rm</code>.</p>
        <p>To keep models somewhere else, like an external SSD, set <code>OLLAMA_MODELS</code>. On a Mac, Ollama's docs say to do it with <code>launchctl</code>, then restart Ollama:</p>
<pre><code>launchctl setenv OLLAMA_MODELS "/Volumes/External/ollama-models"</code></pre>
        <p>Existing models don't move by themselves. Copy the contents of <code>~/.ollama/models</code> to the new folder first, then check <code>ollama list</code>.</p>

        <h2 style="margin-top:56px">How big Ollama models are</h2>
        <p>Roughly the parameter count times the bits per weight. At the 4-bit quantization most Ollama tags use, a 3B model is about 2 GB, an 8B model about 5 GB, a 30B model close to 20 GB, and a 70B model over 40 GB. Pull a few sizes of the same family to compare, and it's easy to pass 100 GB without noticing. <code>ollama list</code> shows each model's size before you decide.</p>

        <h2 style="margin-top:56px">How to uninstall Ollama on Mac</h2>
        <ol class="steps">
          <li><b>Quit Ollama.</b> Click the llama in the menu bar and choose <strong>Quit Ollama</strong>.</li>
          <li><b>Delete the app.</b> Move <code>Ollama.app</code> from Applications to the Trash.</li>
          <li><b>Delete your models.</b> Move <code>~/.ollama</code> to the Trash. This is where the gigabytes are.</li>
          <li><b>Remove what's left.</b> Ollama's own uninstall instructions list these too:
<pre><code>sudo rm /usr/local/bin/ollama
rm -rf ~/Library/Application\\ Support/Ollama
rm -rf ~/Library/Saved\\ Application\\ State/com.electron.ollama.savedState
rm -rf ~/Library/Caches/com.electron.ollama ~/Library/Caches/ollama
rm -rf ~/Library/WebKit/com.electron.ollama</code></pre>
          The first line removes the <code>ollama</code> command Ollama linked into your path. Check what each path holds before running a <code>rm</code> line.</li>
        </ol>
        <p>Installed with Homebrew instead? Run <code>brew uninstall ollama</code>, then delete <code>~/.ollama</code>. Homebrew doesn't remove your models.</p>
        <p>Using other local AI tools too? <a href="/ai-models">Delete local AI models</a> covers LM Studio, Hugging Face, and ComfyUI. Apple's own models are different: see <a href="/ai-models/apple-intelligence">Apple Intelligence storage</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast lists your Ollama models under <strong>Cleanup › Worth a look › Ollama models</strong>, with the size of <code>~/.ollama/models</code>. Nothing in Worth a look is checked until you choose it, and checking it moves every model to the Trash at once. To remove one model, use <code>ollama rm</code>, as the row itself explains. LM Studio and Hugging Face models get their own rows, one entry per model. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/ai-models/apple-intelligence", "/ai-models", "/clear-cache/docker"],
    "faqs": [
        ("How do I remove a model from Ollama?", "Run ollama rm followed by the model's name as ollama list shows it, like ollama rm llama3.2 or ollama rm qwen3:8b. Ollama deletes its files from disk unless another model shares them. ollama pull downloads it again."),
        ("How do I delete all Ollama models?", "There's no single command. Run ollama list | awk 'NR>1 {print $1}' | xargs ollama rm to remove every listed model, or quit Ollama and move ~/.ollama/models to the Trash."),
        ("Where are Ollama models stored on a Mac?", "In ~/.ollama/models: blobs holds the model files and manifests maps model names to them. Set OLLAMA_MODELS with launchctl setenv to store them somewhere else, then restart Ollama."),
        ("How do I uninstall Ollama on a Mac?", "Quit Ollama from the menu bar, move Ollama.app to the Trash, and delete ~/.ollama, which holds the models. Ollama's docs also list /usr/local/bin/ollama and a few folders in ~/Library to remove."),
        ("Why didn't ollama rm free as much space as the model's size?", "Models can share files. If two models use the same base weights, removing one keeps the shared blobs for the other. The space comes back when you remove the last model that uses them."),
    ],
}

AI_TOOLS = [OLLAMA]

AI_MODELS_HUB = {
    "path": "/ai-models",
    "title": "Delete local AI models on Mac: Ollama, LM Studio, and more",
    "description": "Where Ollama, LM Studio, Hugging Face, ComfyUI, and Apple Intelligence keep AI models on a Mac, how big they get, and how to delete each with its own tool.",
    "h1": "Delete local AI models on Mac, <em>tool by tool.</em>",
    "lede": "Local models are the biggest files most Macs have ever held, and every tool keeps them somewhere different. Here's where each one puts them, and how to remove them without breaking anything.",
    "card_title": "Delete local AI models",
    "card_blurb": "Ollama, LM Studio, Hugging Face, ComfyUI, and Apple's own.",
    "footer": "Delete local AI models",
    "cta": "Know before it's full.",
    "html": """
        <h2>LM Studio</h2>
        <p>LM Studio keeps models in <code>~/.lmstudio/models</code>, in a folder per publisher and a folder per model inside that. Older versions used <code>~/.cache/lm-studio/models</code>, and you may still have both. The simplest way to delete one is LM Studio's own <strong>My Models</strong> tab, which shows the folder and lets you remove a model; you can also move a model's folder to the Trash with LM Studio quit. To uninstall, delete the app and both folders. LM Studio can download any model again.</p>

        <h2 style="margin-top:56px">Hugging Face</h2>
        <p>Python libraries like <code>transformers</code> and <code>diffusers</code> download models into the Hugging Face cache, <code>~/.cache/huggingface/hub</code>, or wherever <code>HF_HOME</code> or <code>HF_HUB_CACHE</code> point. One developer Mac measured for these pages had 1.6 GB there. Use the <code>hf</code> command to manage it:</p>
<pre><code>hf cache ls                  # every cached model and dataset, with sizes
hf cache rm model/gpt2       # remove one
hf cache prune               # remove old revisions and incomplete downloads</code></pre>
        <p>The older <code>huggingface-cli delete-cache</code> and <code>scan-cache</code> commands are deprecated; current versions of the library point you to <code>hf</code>. A model removed from the cache downloads again the next time a script asks for it.</p>

        <h2 style="margin-top:56px">ComfyUI</h2>
        <p>ComfyUI keeps models inside its own folder, in <code>models</code>, split by type: <code>checkpoints</code>, <code>loras</code>, <code>vae</code>, <code>controlnet</code>, <code>upscale_models</code>, and more. Where that folder is depends on how you installed it: wherever you cloned it, or the location you picked when setting up the desktop app. If you've set <code>extra_model_paths.yaml</code>, models can live in other folders too. Checkpoints are often 2 to 7 GB each, and some are larger. To delete one, quit ComfyUI and move the file to the Trash. Workflows that use it will ask for it again.</p>
        <p>The two tools with the most to explain have their own pages: <a href="/ai-models/ollama">Ollama</a>, with list, remove, and a full uninstall, and <a href="/ai-models/apple-intelligence">Apple Intelligence</a>, which you can turn off but not delete. For caches from developer tools, see <a href="/clear-cache">clear cache by tool</a>.</p>
    """,
    "faqs": [
        ("Where does LM Studio store models on a Mac?", "In ~/.lmstudio/models, one folder per publisher. Older versions used ~/.cache/lm-studio/models. LM Studio's My Models tab shows the folder and can delete models."),
        ("Where is the Hugging Face cache directory on a Mac?", "In ~/.cache/huggingface/hub by default, or under HF_HOME or HF_HUB_CACHE if you've set them. Run hf cache ls to see what's in it and hf cache rm to remove a model."),
        ("Where is the ComfyUI models folder?", "Inside your ComfyUI folder, in models, with subfolders like checkpoints, loras, and vae. The ComfyUI folder is wherever you installed it. extra_model_paths.yaml can add more model folders."),
        ("Is it safe to delete local AI models?", "Yes, for models you downloaded. Each tool downloads them again when you need them. Keep anything you trained or fine-tuned yourself, since that can't be downloaded."),
    ],
}

# Each hub and its pages: the hub's path is the route, and each page renders at <route>/<slug>.
SECTIONS = [(CLEAR_CACHE_HUB, CACHE_TOOLS), (AI_MODELS_HUB, AI_TOOLS)]
for _hub, _tools in SECTIONS:
    for _t in _tools:
        _t["path"] = f"{_hub['path']}/{_t['slug']}"

# The hubs appear on /guides and in every footer, after the guides.
GUIDE_HUBS = [hub for hub, _ in SECTIONS]
