# Content for the alternative pages, the System Data guide, and the privacy page.
# Competitor facts trace to ~/.config/makerskills/deep-research/archive/2026-10-05-macos-menubar-wifi-and-storage-apps.md.
# Anything that file doesn't support is shown as "—" in the tables. Keep it honest.
#
# Copy rules: never "optimize", "boost", "speed up", or "junk"; say "reclaim" and "explain".
# Say "free, source available" and "source on GitHub", never "open source".

PAGES = [
    # ------------------------------------------------------------------ DiskBuddy
    {
        "slug": "diskbuddy",
        "competitor": "DiskBuddy",
        "title": "DiskBuddy for Mac, compared with a free alternative",
        "description": "DiskBuddy is a capable paid disk app for Mac. Disk Forecast is the free, source-available DiskBuddy alternative that tells you when your disk will be full.",
        "eyebrow": "DiskBuddy alternative",
        "h1": "DiskBuddy shows where the space went. Disk Forecast shows <em>when it runs out.</em>",
        "lede": "DiskBuddy launched in September 2026 and has shipped fast since, adding a finder for local AI models in its 3.0 release. It's a strong paid app. Disk Forecast is the free one that warns you weeks before your disk fills.",
        "tldr": "Pick DiskBuddy if you want the biggest toolbox in one paid app, including duplicates, compression, and a Windows license on the same key. Pick Disk Forecast if you want a countdown to a full disk, System Data explained with Apple's own fixes, and the source on GitHub, for free.",
        "card_title": "DiskBuddy",
        "card_blurb": "The closest match. Paid, fast-moving, and packed with tools.",
        "cta": "Get the forecast, free.",
        "faqs": [
            ("How much does DiskBuddy cost?", "DiskBuddy launched at $19 with a limited run of launch copies, and its site has since listed it at $49. Check DiskBuddy's site for the current price."),
            ("Does DiskBuddy move files to the Trash?", "Yes. DiskBuddy sends deletions to the Trash, and so does Disk Forecast."),
            ("Does DiskBuddy tell you when your disk will be full?", "We couldn't find a forecast in DiskBuddy's own materials as of October 2026. In Disk Forecast it's the headline feature: a countdown in the menu bar, built from your own daily history."),
            ("Is Disk Forecast free?", "Yes, at home or at work, with no account. The source is on GitHub and the app collects no telemetry."),
        ],
        "sections": [
            {"id": "why", "html": """
        <h2>What DiskBuddy does well</h2>
        <p>DiskBuddy launched on September 5, 2026, changed hands about a month later, and shipped version 2.0 on September 23 and 3.0 on October 4. It's ambitious. There's an overview, a space map, a tiered cleanup list, duplicates, apps, a monitor, snapshots, activity, compression, a menu bar item, and a finder for local LLM models.</p>
        <p>It sends deletions to the Trash, it scans about 3 million files in roughly 20 seconds by its own numbers, and one license covers a Mac and a Windows PC.</p>
        <h3>Where it stops</h3>
        <p><strong>It's paid, and the price has moved.</strong> It launched at $19 with a counter of copies left, and the site now lists $49.</p>
        <p><strong>It answers “what's using my space?”</strong> We couldn't find anything in its materials that answers “when will I run out?”, which is the question Disk Forecast is built around.</p>
        <p><strong>System Data gets a snapshots view.</strong> Disk Forecast breaks System Data into every part it can measure, explains each in plain English, and fixes it with Apple's own tools.</p>
            """},
            {"id": "compare", "lit": True, "html": """
        <h2>Disk Forecast vs DiskBuddy</h2>
        <p>DiskBuddy facts come from its launch and release posts, September to October 2026.</p>
        {{TABLE}}
        <h3>What DiskBuddy does better</h3>
        <p>Breadth. Duplicates, an apps view, compression, activity history, and a Windows version on the same license. If you want one paid app that does all of it, DiskBuddy is a good one.</p>
        <h3>What Disk Forecast does better</h3>
        <p>It tells you ahead of time. Free space and a countdown sit in the menu bar, System Data comes with a plain-English explanation for every part, and the whole thing is free with the source on GitHub.</p>
            """, "table": [
                ("Price", "Free", "$19 at launch, now $49"),
                ("Tells you when the disk will be full", "Yes, in the menu bar", "—"),
                ("System Data broken down", "Every part, in plain English, with Apple's fixes", "Snapshots view"),
                ("Cleanup sorted by risk", "Yes", "Yes"),
                ("Deletes go to the Trash", "Yes", "Yes"),
                ("Finds local AI models", "Ollama, LM Studio, Hugging Face", "Yes"),
                ("Duplicate finder", "No", "Yes"),
                ("Windows version", "No", "Yes, same license"),
                ("Source available", "Yes, on GitHub", "—"),
                ("Telemetry", "None", "—"),
            ]},
            {"id": "switch", "html": """
        <h2>Trying it takes a minute</h2>
        <ol class="steps">
          <li><b>Install Disk Forecast.</b> <code>brew install --cask coreyhaines31/tap/diskforecast</code>, or download the app from GitHub and drag it to Applications.</li>
          <li><b>Let it learn for 3 days.</b> Free space shows in the menu bar right away. The forecast appears after 3 days of history.</li>
          <li><b>Open System Data….</b> See what macOS has been filing under the gray bar, and fix the parts worth fixing.</li>
          <li><b>Keep DiskBuddy if you use its extras.</b> They don't conflict. Plenty of people will want both.</li>
        </ol>
            """},
        ],
    },
    # ------------------------------------------------------------------ DaisyDisk
    {
        "slug": "daisydisk",
        "competitor": "DaisyDisk",
        "title": "DaisyDisk for Mac, compared with a free alternative",
        "description": "DaisyDisk is the $9.99 disk visualizer for Mac. Disk Forecast is a free, source-available DaisyDisk alternative that tells you when your disk will be full.",
        "eyebrow": "DaisyDisk alternative",
        "h1": "DaisyDisk draws the map. Disk Forecast <em>reads the weather.</em>",
        "lede": "DaisyDisk is the visual standard for seeing what's on a Mac's disk, and $9.99 once is a fair price. It answers “what's using my space?” Disk Forecast answers the question that comes first: “when will I run out?”",
        "tldr": "Keep DaisyDisk if you love exploring your disk as a picture and dragging folders out by hand. Get Disk Forecast for a countdown in the menu bar, a plain-English breakdown of System Data, and a cleanup list sorted by risk. One costs $9.99, the other is free, and they get along fine.",
        "card_title": "DaisyDisk",
        "card_blurb": "The visual standard. A $9.99 picture of your disk, sold on the App Store and direct.",
        "cta": "Know before it's full.",
        "faqs": [
            ("How much does DaisyDisk cost?", "$9.99, one-time. It's sold on the Mac App Store and directly from its developer."),
            ("What's the difference between DaisyDisk's App Store and direct versions?", "The App Store build runs in Apple's sandbox, so it can't scan as an administrator or see hidden and system files. The direct build can. Disk Forecast skips the App Store for the same reason."),
            ("Is DaisyDisk still updated?", "Yes. It shipped an update in July 2026."),
            ("Is Disk Forecast free?", "Yes, at home or at work, with no account. The source is on GitHub and the app collects no telemetry."),
        ],
        "sections": [
            {"id": "why", "html": """
        <h2>What DaisyDisk does well</h2>
        <p>DaisyDisk turns your disk into a picture you can click through. Big folders look big, you drill in, and you drag what you don't want to a collector at the bottom. It's been the visual standard on the Mac for years, and it's still maintained, with an update as recent as July 2026.</p>
        <p>It costs $9.99 once, with no subscription.</p>
        <h3>Where it stops</h3>
        <p><strong>It's a snapshot.</strong> DaisyDisk shows you what's on the disk right now. Most people open it when they're already out of space. Disk Forecast sits in the menu bar the rest of the time and tells you weeks ahead.</p>
        <p><strong>The App Store version sees less.</strong> In Apple's sandbox it can't scan as an administrator or see hidden and system files, which is why DaisyDisk also sells a direct build. Know which one you have.</p>
        <p><strong>The judgment is yours.</strong> A picture shows size, not meaning. Disk Forecast sorts what it finds into “Safe to clear” and “Worth a look,” with a one-line explanation of every item.</p>
            """},
            {"id": "compare", "lit": True, "html": """
        <h2>Disk Forecast vs DaisyDisk</h2>
        <p>DaisyDisk facts come from its own site and App Store listing as of October 2026.</p>
        {{TABLE}}
        <h3>What DaisyDisk does better</h3>
        <p>Exploring. If you want to see your whole disk as one picture and wander through it, nothing on the Mac is nicer to use.</p>
        <h3>What Disk Forecast does better</h3>
        <p>Warning you ahead of time, explaining System Data, and telling you what's safe to clear. It's also free, with the source on GitHub.</p>
            """, "table": [
                ("Price", "Free", "$9.99 one-time"),
                ("Tells you when the disk will be full", "Yes, in the menu bar", "—"),
                ("How it shows your disk", "Lists sorted by size, each item explained", "An interactive picture you click through"),
                ("System Data broken down", "Every part, in plain English, with Apple's fixes", "—"),
                ("Cleanup sorted by risk", "Yes", "—"),
                ("Deletes go to the Trash", "Yes", "—"),
                ("Where to get it", "GitHub or Homebrew", "Mac App Store or direct"),
                ("Sees hidden and system files", "Yes", "Direct build only"),
                ("Source available", "Yes, on GitHub", "No"),
                ("Last update", "Actively developed", "July 2026"),
            ]},
            {"id": "switch", "html": """
        <h2>Using them together</h2>
        <ol class="steps">
          <li><b>Install Disk Forecast.</b> <code>brew install --cask coreyhaines31/tap/diskforecast</code>, or download the app from GitHub.</li>
          <li><b>Let the forecast build.</b> Free space shows right away. The countdown appears after 3 days of history.</li>
          <li><b>Clear the safe stuff first.</b> “Safe to clear” in the menu is everything that rebuilds on its own. Click it, confirm, and it's all in the Trash.</li>
          <li><b>Open DaisyDisk for the rest.</b> When you want to hunt for one forgotten 40 GB folder, a picture is still the fastest way to find it.</li>
        </ol>
            """},
        ],
    },
    # ------------------------------------------------------------------ CleanMyMac
    {
        "slug": "cleanmymac",
        "competitor": "CleanMyMac",
        "title": "CleanMyMac, compared with a free storage app for Mac",
        "description": "CleanMyMac starts at $47.50 a year. Disk Forecast is a free, source-available CleanMyMac alternative that warns before your disk fills and reclaims space.",
        "eyebrow": "CleanMyMac alternative",
        "h1": "CleanMyMac bills you every year. Disk Forecast <em>reclaims space for free.</em>",
        "lede": "CleanMyMac is a big suite, and since July 2025 it starts at $47.50 a year. If what you actually need is room on your disk, you don't need to pay every year for it.",
        "tldr": "Stay with CleanMyMac if you use the whole suite and the yearly price is worth it to you. If you mostly opened it to get disk space back, Disk Forecast does that part for free: it tells you when you'll run out, explains System Data, and sends what it clears to the Trash.",
        "card_title": "CleanMyMac",
        "card_blurb": "The big suite. Now a subscription from $47.50 a year.",
        "cta": "Reclaim space, free.",
        "faqs": [
            ("How much does CleanMyMac cost?", "MacPaw raised CleanMyMac's price in July 2025, and it now starts at $47.50 a year. Check MacPaw's store for current plans."),
            ("Do I need a Mac cleaner app?", "For disk space, a careful tool helps when you're running low. Beyond that, usually not. macOS manages its own caches and memory, and on an SSD, free space doesn't change how a Mac runs until the disk is nearly full."),
            ("Can I use Disk Forecast and CleanMyMac together?", "Yes. They don't conflict. Disk Forecast only moves files to the Trash when you ask it to."),
            ("Is Disk Forecast free?", "Yes, at home or at work, with no account. The source is on GitHub and the app collects no telemetry."),
        ],
        "sections": [
            {"id": "why", "html": """
        <h2>What CleanMyMac is</h2>
        <p>CleanMyMac is MacPaw's long-running Mac suite, with storage cleanup as one part of a larger set of tools. In July 2025 its pricing moved to a subscription that starts at $47.50 a year, and some users have pushed back on the billing.</p>
        <p>If you use everything in it, that may be fine. Many people open it for one reason: the disk is full.</p>
        <h3>Do you need a cleaner at all?</h3>
        <p>Regulars on Apple's own support forums have warned against Mac cleaner apps for years, and they have a point. On a modern Mac with APFS and an SSD, there's nothing to tune. A Mac with 100 GB free runs the same as one with 300 GB free.</p>
        <p>The real reasons to clear space are practical: room for a macOS update, a project, a phone backup, a video export. That's what Disk Forecast is for. It tells you when you'll need the room, shows you what's taking it, and reclaims it safely.</p>
            """},
            {"id": "compare", "lit": True, "html": """
        <h2>Disk Forecast vs CleanMyMac</h2>
        <p>CleanMyMac facts come from MacPaw's store and coverage of the 2025 price change.</p>
        {{TABLE}}
        <h3>What CleanMyMac does better</h3>
        <p>Scope. It's a suite with many tools beyond storage, a polished interface, and a company behind it with a support team.</p>
        <h3>What Disk Forecast does better</h3>
        <p>It costs nothing, warns you before the disk fills, explains System Data in plain English, and uses Apple's own tools for system fixes. The source is on GitHub, so you can see exactly what it moves to the Trash.</p>
            """, "table": [
                ("Price", "Free", "From $47.50 a year"),
                ("Tells you when the disk will be full", "Yes, in the menu bar", "—"),
                ("System Data broken down", "Every part, in plain English, with Apple's fixes", "—"),
                ("Deletes go to the Trash", "Yes", "—"),
                ("System fixes use Apple's own tools", "Yes: tmutil, mdutil, xcrun simctl", "—"),
                ("Account needed", "No", "—"),
                ("Source available", "Yes, on GitHub", "No"),
                ("Telemetry", "None", "—"),
            ]},
            {"id": "switch", "html": """
        <h2>Switching</h2>
        <ol class="steps">
          <li><b>Install Disk Forecast.</b> <code>brew install --cask coreyhaines31/tap/diskforecast</code>, or download the app from GitHub.</li>
          <li><b>Clear what's safe.</b> The menu shows a “Safe to clear” total. Click it, confirm, and it all goes to the Trash.</li>
          <li><b>Look at System Data.</b> Snapshots, simulators, the Spotlight index: each one explained, each fix confirmed first.</li>
          <li><b>Decide on the subscription.</b> If storage was the reason you paid, you can let it lapse. MacPaw's account page handles cancellation.</li>
        </ol>
            """},
        ],
    },
    # ------------------------------------------------------------------ GrandPerspective
    {
        "slug": "grandperspective",
        "competitor": "GrandPerspective",
        "title": "GrandPerspective for Mac, compared with a free alternative",
        "description": "GrandPerspective draws a free treemap of your disk. Disk Forecast is the free GrandPerspective alternative that says when your Mac fills up and what to clear.",
        "eyebrow": "GrandPerspective alternative",
        "h1": "GrandPerspective shows the blocks. Disk Forecast <em>says what they are.</em>",
        "lede": "GrandPerspective is a free treemap: every file a rectangle, sized by the space it takes. It's a great way to spot one giant file. It won't tell you what that file is, whether it's safe to remove, or when your disk will fill.",
        "tldr": "Use GrandPerspective for a quick picture of everything on a drive. Use Disk Forecast to keep watch over your Mac's own disk, with a forecast in the menu bar, System Data explained, and a cleanup list sorted by risk. Both are free.",
        "card_title": "GrandPerspective",
        "card_blurb": "The free treemap. Every file a block, and the judgment is up to you.",
        "cta": "Know before it's full.",
        "faqs": [
            ("Is GrandPerspective free?", "Yes. GrandPerspective is a free disk visualizer for the Mac."),
            ("What is a treemap?", "A picture of a folder where every file is a rectangle sized by how much space it takes. Big files jump out, but the rectangles don't say what anything is."),
            ("How is Disk Forecast different?", "It lives in the menu bar, tracks free space every day, and tells you when you'll run out. When you need room, it lists what it found with a plain-English line for each item, sorted by how safe it is to clear."),
            ("Is Disk Forecast free?", "Yes, at home or at work, with no account. The source is on GitHub and the app collects no telemetry."),
        ],
        "sections": [
            {"id": "why", "html": """
        <h2>What GrandPerspective does well</h2>
        <p>GrandPerspective draws a folder or a whole drive as a treemap. Every file is a block, sized by the space it uses, so the giant movie export or the forgotten VM disk jumps out at a glance. It's free and has been around a long time.</p>
        <h3>Where it stops</h3>
        <p><strong>Blocks, not answers.</strong> A treemap shows size. It can't tell you that the big block is Xcode's build cache, that it rebuilds itself, and that clearing it is safe.</p>
        <p><strong>You have to remember to look.</strong> You open it when the disk is already full. Disk Forecast watches every day and tells you weeks ahead.</p>
        <p><strong>System Data stays a mystery.</strong> Snapshots, purgeable space, and simulator runtimes don't show up as tidy blocks. Disk Forecast breaks them out and explains each one.</p>
            """},
            {"id": "compare", "lit": True, "html": """
        <h2>Disk Forecast vs GrandPerspective</h2>
        {{TABLE}}
        <h3>What GrandPerspective does better</h3>
        <p>A whole-drive picture in one window. For finding the single biggest thing on a disk, a treemap is hard to beat.</p>
        <h3>What Disk Forecast does better</h3>
        <p>Everything after you spot the big block: what it is, whether it's safe, how to clear it without regret. Plus the forecast, so you're not doing this in a hurry.</p>
            """, "table": [
                ("Price", "Free", "Free"),
                ("Tells you when the disk will be full", "Yes, in the menu bar", "—"),
                ("How it shows your disk", "Lists sorted by size, each item explained", "A treemap of every file"),
                ("Explains what each item is", "Yes, in plain English", "—"),
                ("System Data broken down", "Every part, with Apple's fixes", "—"),
                ("Cleanup sorted by risk", "Yes", "—"),
                ("Source available", "Yes, on GitHub", "—"),
            ]},
            {"id": "switch", "html": """
        <h2>Using them together</h2>
        <ol class="steps">
          <li><b>Install Disk Forecast.</b> <code>brew install --cask coreyhaines31/tap/diskforecast</code>, or download the app from GitHub.</li>
          <li><b>Start with Safe to clear.</b> Caches, logs, and build folders in old projects, each explained, sent to the Trash after one confirm.</li>
          <li><b>Reach for the treemap when you're hunting.</b> If you're after one mystery file, GrandPerspective is still a great flashlight.</li>
        </ol>
            """},
        ],
    },
]

HUB = {
    "title": "Mac disk space apps compared: DiskBuddy, DaisyDisk and more",
    "description": "Honest comparisons of DiskBuddy, DaisyDisk, CleanMyMac and GrandPerspective, and where Disk Forecast fits: the free Mac app that warns before your disk fills.",
    "h1": "Every way to see what's filling your Mac, <em>compared.</em>",
    "lede": "Four popular storage apps, what each does well, and where it stops. Sometimes the other app is the right one, and we say so.",
    "glance": [
        ("You want…", "Use"),
        ("A beautiful picture of your disk, paid for once", "DaisyDisk"),
        ("A free treemap and nothing else", "GrandPerspective"),
        ("Duplicates, compression, and a Windows license too", "DiskBuddy"),
        ("A broad suite of Mac tools on a subscription", "CleanMyMac"),
        ("To know when you'll run out, before you do", "Disk Forecast"),
        ("System Data explained and fixed with Apple's own tools", "Disk Forecast"),
    ],
    "cta": "Know before it's full.",
    "html": """
        <h2>How we compare</h2>
        <p>Every page here draws on the competitor's own site, store listing, and release posts as of October 2026, and says plainly what the other app does better. Where we couldn't confirm a feature either way, the table shows “—” instead of guessing. If something is out of date, <a href="https://github.com/coreyhaines31/diskforecast/issues">open an issue</a> and we'll fix it.</p>
        <p>The short version of the category: <strong>DaisyDisk</strong> is the beautiful one. <strong>GrandPerspective</strong> is the free treemap. <strong>DiskBuddy</strong> is the new, fast-moving one with the most tools. <strong>CleanMyMac</strong> is the big suite, now a subscription. Disk Forecast is free with its source on GitHub, and it's built for the question none of them lead with: when will I run out?</p>
    """,
}

# ---------------------------------------------------------------------- System Data guide
# Targets "how to clear system data on mac" (3,500/mo US, KD 0), plus "how to delete system data on mac" and "system data mac".
GUIDE = {
    "path": "/system-data",
    "title": "How to clear System Data on Mac, safely",
    "description": "What's inside System Data on your Mac, which parts you can safely reclaim, and how to clear System Data step by step using only Apple's own tools.",
    "eyebrow": "Guide",
    "h1": "How to clear System Data on your Mac.",
    "lede": "System Data is the gray bar in Storage settings that keeps growing and won't say why. Here's what's inside it, which parts you can reclaim, and the exact steps, using only Apple's own tools.",
    "tldr": "System Data is a catch-all, not one thing. The big parts are usually local Time Machine snapshots, Xcode simulator runtimes, caches, and purgeable space. Restart first, then check snapshots and simulators: that's where the most space hides. Leave purgeable space alone, since macOS frees it on its own, and never delete folders under /System or /private/var by hand.",
    "faqs": [
        ("Why is System Data so big on my Mac?", "Because it's where macOS counts everything it doesn't file under a named category. Local Time Machine snapshots alone can take 30 to 60 GB, and Xcode simulator runtimes, caches, the Spotlight index, Apple Intelligence models, and Docker's disk image all land there too."),
        ("Is it safe to delete System Data?", "Some of it. Caches, old simulator runtimes, and local Time Machine snapshots can be removed with Apple's own tools. Purgeable space should be left for macOS to manage, and you should never delete files under /System or /private/var by hand."),
        ("Why does System Data keep coming back?", "Most of it is supposed to. Caches refill as you use apps, Time Machine makes a new local snapshot every hour, and Spotlight rebuilds its index. Clearing it buys room; it doesn't stop the growth. That's why a forecast helps."),
        ("Does restarting reduce System Data?", "Often, a little. A restart clears temporary files and swap, and gives Storage settings a chance to recalculate. It's the free first step."),
        ("Can an app clear System Data for me?", "Disk Forecast breaks System Data into its parts, explains each in plain English, and runs Apple's own tool for each fix after you confirm. It's free, with the source on GitHub."),
    ],
    "html": """
        <h2>First, look at what you have</h2>
        <p>Open <strong>System Settings › General › Storage</strong>. The colored bar at the top splits your disk into categories, and System Data is usually the gray slice near the end. Hover over it to see its size.</p>
        <p>Storage settings won't tell you what's inside, and its number can lag behind reality. Give it a minute after opening, and don't panic if it jumps around.</p>
        <div class="callout"><p><strong>What System Data is not.</strong> It isn't your documents, photos, or apps, which have their own categories. And it isn't “wasted.” Most of it is macOS doing its job, just more of it than you'd like.</p></div>

        <h2 style="margin-top:56px">What's inside System Data</h2>
        <ul>
          <li><strong>Local Time Machine snapshots.</strong> If you use Time Machine, macOS keeps hourly snapshots on your Mac between backups. They can take 30 to 60 GB. macOS counts them as purgeable and removes them after 24 hours or when space runs low, but Storage settings may show them in the meantime.</li>
          <li><strong>Purgeable space.</strong> Files macOS has already marked as reclaimable, like iCloud copies it can download again. It's freed on demand, so it isn't really in your way.</li>
          <li><strong>Simulators and runtimes.</strong> If you've ever installed Xcode, iOS and watchOS simulator runtimes can take tens of gigabytes, including ones for versions you no longer test on.</li>
          <li><strong>Caches and logs.</strong> Apps and package managers keep downloaded and generated files so they don't have to fetch or build them again. They come back on their own.</li>
          <li><strong>Apple Intelligence models.</strong> On Macs that support it, the on-device models live on your disk.</li>
          <li><strong>The Spotlight index.</strong> Your search index, which can grow out of date and larger than it needs to be.</li>
          <li><strong>Docker and virtual machines.</strong> Docker keeps its images and build cache in one large disk image, and VM apps do something similar.</li>
        </ul>

        <h2 style="margin-top:56px">How to clear it, step by step</h2>
        <p>In order of how much space each step usually frees for the least risk. Commands go in Terminal. Read each one before you run it.</p>
        <ol class="steps">
          <li><b>Restart your Mac.</b> It clears temporary files and swap, and Storage settings recalculates. Free, and sometimes enough.</li>
          <li><b>Remove local Time Machine snapshots.</b> List them, then delete by date:
<pre><code>tmutil listlocalsnapshots /
sudo tmutil deletelocalsnapshots 2026-10-05-093012</code></pre>
          Replace the date with one from the list. Time Machine keeps taking new ones, and macOS removes each after 24 hours anyway, so this is for when you need the room right now. Recent macOS versions no longer let you turn local snapshots off with <code>tmutil disablelocal</code>.</li>
          <li><b>Delete simulator runtimes you don't use.</b> Remove simulators for runtimes no installed Xcode supports:
<pre><code>xcrun simctl delete unavailable</code></pre>
          To remove whole runtimes, list them and delete by identifier, or use <strong>Xcode › Settings › Components</strong>:
<pre><code>xcrun simctl runtime list
xcrun simctl runtime delete &lt;identifier&gt;</code></pre></li>
          <li><b>Clear caches.</b> Quit your apps, then in Finder choose <strong>Go › Go to Folder</strong> and open <code>~/Library/Caches</code>. Move folders for apps you know to the Trash; they'll rebuild. Do the same for Xcode's build data in <code>~/Library/Developer/Xcode/DerivedData</code>. Package managers clear their own caches:
<pre><code>npm cache clean --force
pnpm store prune
pip cache purge</code></pre>
          Each tool downloads what it needs again on the next install.</li>
          <li><b>Prune Docker.</b> If you use Docker, its own command removes stopped containers, unused networks, dangling images, and build cache:
<pre><code>docker system prune</code></pre>
          Add <code>-a</code> to also remove images no container is using. You'll download them again the next time you need them.</li>
          <li><b>Turn off Apple Intelligence, if you don't use it.</b> In <strong>System Settings › Apple Intelligence &amp; Siri</strong>, switch it off, and macOS can remove the on-device models. Turn it back on any time; they'll download again.</li>
          <li><b>Rebuild the Spotlight index.</b> If it's grown large, rebuilding often shrinks it:
<pre><code>sudo mdutil -E /</code></pre>
          Search results will be incomplete for a while as it re-indexes.</li>
          <li><b>Leave purgeable space alone.</b> macOS frees it the moment something needs the room. Apps that “free” it for you are only doing what macOS would have done anyway.</li>
        </ol>

        <h2 style="margin-top:56px">What not to touch</h2>
        <ul>
          <li><strong>Anything under /System.</strong> It's on a sealed, read-only volume for a reason.</li>
          <li><strong>/private/var/vm.</strong> That's swap and the sleep image, managed by macOS. Deleting files there by hand can crash your Mac.</li>
          <li><strong>Random folders in /Library.</strong> If you don't know what installed it, look it up before you remove it.</li>
          <li><strong>Apps that promise a performance miracle.</strong> On an SSD, free space doesn't change how a Mac runs until the disk is nearly full. Reclaim space when you need room, not for a mystery gain.</li>
        </ul>
    """,
    "shortcut": """
          <h2>Or do it in one window.</h2>
          <p>Disk Forecast breaks System Data into the parts above, explains each one, and runs Apple&#39;s own tool for each fix after you confirm. It&#39;s free.</p>
    """,
}

# ---------------------------------------------------------------------- Privacy
PRIVACY = {
    "path": "/privacy",
    "title": "Disk Forecast privacy policy",
    "description": "The Disk Forecast app collects nothing; its only network request is checking GitHub for updates. The website counts visits with cookie-free Fathom Analytics.",
    "h1": "Privacy policy",
    "html": """
        <p><strong>Last updated October 2026.</strong></p>
        <h2>The Disk Forecast app</h2>
        <p>The app collects nothing about you. There's no account, no analytics, and no telemetry.</p>
        <p>To do its job it reads file and folder names and sizes on your Mac, and keeps a small daily history of free space for the forecast. It doesn't read what's inside your files, and it never scans cloud drives like Google Drive, Dropbox, or OneDrive. All of that stays on your Mac. Nothing about your files, folders, or disk is ever sent anywhere.</p>
        <p>The app's only network request is Sparkle's check for updates, which fetches a small update feed from the latest GitHub release. GitHub sees that request like any other web request, including your IP address. You can turn automatic checks off in Settings › General.</p>
        <h2>diskforecast.com</h2>
        <p>This website counts visits with Fathom Analytics, a cookie-free analytics service. It sets no cookies and doesn't collect personal data. The site is static pages hosted on Vercel, which keeps standard server logs. The homepage asks GitHub's public API for the repository's star count from your browser, and the pages load their fonts from Google Fonts. Both see those requests like any other web request.</p>
        <h2>Downloads</h2>
        <p>The app is downloaded from GitHub Releases, or through Homebrew, which downloads it from GitHub. Their privacy policies cover those downloads.</p>
        <h2>Questions</h2>
        <p>Open an issue on <a href="https://github.com/coreyhaines31/diskforecast/issues">GitHub</a>. The source is public, so you can check every claim on this page yourself.</p>
    """,
}
