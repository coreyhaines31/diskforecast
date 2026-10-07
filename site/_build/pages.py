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
    # ------------------------------------------------------------------ OmniDiskSweeper
    # Targets "omnidisksweeper" (450/mo US, KD 5). Facts: omnigroup.com/more, and the 1.11 app itself
    # (lipo: x86_64 only; signed and notarized by The Omni Group on 2018-09-23), checked 2026-10-06.
    {
        "slug": "omnidisksweeper",
        "competitor": "OmniDiskSweeper",
        "title": "OmniDiskSweeper for Mac, compared with a free alternative",
        "description": "OmniDiskSweeper is the free size list from The Omni Group, last built in 2018 for Intel. Disk Forecast is a free alternative that says when your disk fills.",
        "eyebrow": "OmniDiskSweeper alternative",
        "h1": "OmniDiskSweeper lists the biggest files. Disk Forecast <em>says when you'll run out.</em>",
        "lede": "OmniDiskSweeper has been the plain, free way to find big files on a Mac for years: every folder, largest first, with a Trash button. Its newest version, 1.11, was built in 2018 for Intel Macs. Here's how it compares with Disk Forecast today.",
        "tldr": "OmniDiskSweeper still works as a quick size list, and it's free. But version 1.11 is an Intel app from 2018, so an Apple silicon Mac runs it through Rosetta 2, which Apple says stays available for general use through macOS 27. Disk Forecast is free too, runs natively on Apple silicon and Intel, and adds a countdown to a full disk, System Data explained, and a cleanup list sorted by risk.",
        "card_title": "OmniDiskSweeper",
        "card_blurb": "The classic free size list. Last built in 2018, for Intel.",
        "cta": "Know before it's full.",
        "faqs": [
            ("Is OmniDiskSweeper free?", "Yes. The Omni Group offers it as a free download from its website, with no purchase or account."),
            ("Does OmniDiskSweeper work on Apple silicon?", "Version 1.11, the newest on Omni's site as of October 2026, contains Intel code only. On an Apple silicon Mac it runs through Rosetta 2, which Apple says stays available as a general-purpose tool through macOS 27."),
            ("Is OmniDiskSweeper still updated?", "Omni's download page lists versions up to 1.11, for macOS 10.13 High Sierra, and the 1.11 app was signed in September 2018. We couldn't find a newer release."),
            ("Is OmniDiskSweeper safe?", "It's signed and notarized by The Omni Group, and it moves files to the Trash when you ask it to. The risk is the same as with any size list: it shows how big something is, not whether you still need it."),
            ("Is Disk Forecast free?", "Yes, at home or at work, with no account. The source is on GitHub and the app collects no telemetry."),
        ],
        "sections": [
            {"id": "why", "html": """
        <h2>What OmniDiskSweeper does well</h2>
        <p>OmniDiskSweeper does one thing. It scans a drive and shows its folders in columns, sorted largest to smallest, like Finder's column view with sizes attached. Click the biggest folder, then the biggest folder inside that, and you find the 30 GB you forgot about in under a minute. Omni's own description is exactly that: it “shows you the files on your drive, largest to smallest, and lets you quickly Trash or open them.”</p>
        <p>It's free, it comes from The Omni Group, the company behind OmniFocus and OmniGraffle, and the app is signed and notarized. For a long time it was the first answer to “what's filling my Mac?”</p>
        <h3>Where it stops</h3>
        <p><strong>It hasn't changed since 2018.</strong> The newest download on Omni's site is version 1.11, listed for macOS 10.13 High Sierra. We checked the app inside: it was signed in September 2018 and contains Intel code only. On an Apple silicon Mac, macOS runs it through Rosetta 2, and Apple says Rosetta stays available as a general-purpose tool through macOS 27.</p>
        <p><strong>Sizes, not meanings.</strong> A list tells you a folder is 18 GB. It can't tell you that the folder is Xcode's DerivedData, that Xcode rebuilds it on the next build, and that clearing it is safe. Disk Forecast puts a one-line explanation next to everything it lists.</p>
        <p><strong>It waits for you.</strong> You open OmniDiskSweeper after macOS has already warned you. Disk Forecast checks free space every hour and tells you weeks ahead.</p>
            """},
            {"id": "compare", "lit": True, "html": """
        <h2>Disk Forecast vs OmniDiskSweeper</h2>
        <p>OmniDiskSweeper facts come from Omni's download page and the 1.11 app itself, checked in October 2026.</p>
        {{TABLE}}
        <h3>What OmniDiskSweeper does better</h3>
        <p>Drilling into any folder on any drive in a plain column view. If all you want is sizes, nothing is simpler, and it costs nothing.</p>
        <h3>What Disk Forecast does better</h3>
        <p>It runs natively on Apple silicon, watches your disk all day, explains what it finds, and breaks down System Data with Apple's own fixes. It's free, with the source on GitHub.</p>
            """, "table": [
                ("Price", "Free", "Free"),
                ("Latest version", "Actively developed", "1.11, signed September 2018"),
                ("Apple silicon", "Native", "Intel only, runs through Rosetta 2"),
                ("Tells you when the disk will be full", "Yes, in the menu bar", "—"),
                ("How it shows your disk", "Lists sorted by size, each item explained", "Columns sorted by size"),
                ("System Data broken down", "Every part, in plain English, with Apple's fixes", "—"),
                ("Cleanup sorted by risk", "Yes", "—"),
                ("Deletes go to the Trash", "Yes", "Yes"),
                ("Source available", "Yes, on GitHub", "—"),
            ]},
            {"id": "switch", "html": """
        <h2>Switching takes a minute</h2>
        <ol class="steps">
          <li><b>Install Disk Forecast.</b> <code>brew install --cask coreyhaines31/tap/diskforecast</code>, or download the app from GitHub and drag it to Applications.</li>
          <li><b>Look at the top folders.</b> The menu shows the five folders taking the most space, the same first look OmniDiskSweeper gives you, with free space beside it.</li>
          <li><b>Clear what's safe.</b> “Safe to clear” is everything that rebuilds on its own. Click it, confirm, and it all goes to the Trash.</li>
          <li><b>Let the forecast build.</b> After 3 days of history, the menu bar shows when your disk will be full, so next time you're not hunting in a hurry.</li>
        </ol>
            """},
        ],
    },
    # ------------------------------------------------------------------ WinDirStat, WizTree, TreeSize
    # Targets "windirstat for mac" (450/mo US, KD 0), plus "windirstat mac", "wiztree mac", and "treesize mac".
    # Facts, checked 2026-10-06: windirstat.net and its GitHub releases (2.9.2, Windows builds only); diskanalyzer.com/download
    # and /wiztreemac-vs-wiztree (WizTreeMac 1.00, 2026-09-16, macOS 12+, Universal); jam-software.com/treesize (Windows only).
    {
        "slug": "windirstat-mac",
        "competitor": "WinDirStat",
        "footer": "WinDirStat for Mac",
        "title": "WinDirStat for Mac: what to use instead on macOS",
        "description": "WinDirStat, WizTree, and TreeSize on Windows, and what to use on a Mac: WizTree's new Mac app, the treemap apps, and Disk Forecast, which is free.",
        "eyebrow": "WinDirStat for Mac",
        "h1": "WinDirStat for Mac doesn't exist. <em>Here's what does.</em>",
        "lede": "If you came from Windows, you probably reached for WinDirStat, WizTree, or TreeSize when the disk filled up. WinDirStat and TreeSize don't run on macOS. WizTree does now, as of September 2026. Here's what each does on Windows, and the closest tools on a Mac.",
        "tldr": "WinDirStat and TreeSize are Windows only. WizTree released a Mac version, WizTreeMac, in September 2026, free for personal use. For the WinDirStat treemap, GrandPerspective is the free Mac equivalent and DaisyDisk the polished paid one. Disk Forecast does what none of them lead with: it tells you when your Mac's disk will be full and explains what's safe to clear.",
        "card_title": "WinDirStat for Mac",
        "card_blurb": "WinDirStat, WizTree, and TreeSize, and what runs on a Mac.",
        "cta": "Know before it's full.",
        "faqs": [
            ("Is there a WinDirStat for Mac?", "No. WinDirStat is a free, GPL-licensed disk analyzer for Windows, and its October 2026 release, 2.9.2, ships Windows builds only. On a Mac, GrandPerspective draws the same kind of treemap for free."),
            ("Is WizTree available for Mac?", "Yes, since September 16, 2026. WizTreeMac 1.00 needs macOS 12 or later, runs natively on Apple silicon and Intel, and like the Windows version is free for personal use."),
            ("Is there a TreeSize for Mac?", "Not from JAM Software, which lists TreeSize for Windows only: a free edition for private use, plus paid Personal and Professional editions."),
            ("What's the closest thing to WinDirStat on a Mac?", "For the treemap, GrandPerspective or WizTreeMac, both free. For a list of the biggest folders with an explanation of each, Disk Forecast. For a quick look with nothing to install, Finder's Calculate all sizes."),
            ("Is Disk Forecast free?", "Yes, at home or at work, with no account. The source is on GitHub and the app collects no telemetry."),
        ],
        "sections": [
            {"id": "why", "html": """
        <h2>What WinDirStat, WizTree, and TreeSize do on Windows</h2>
        <p><strong>WinDirStat</strong> is the original. It scans a drive and shows three views at once: a folder list, a list of file types, and a treemap where, in its own words, “each rectangle represents a file,” sized by space and colored by type. It's free under the GNU GPL and still maintained; version 2.9.2 shipped in October 2026.</p>
        <p><strong>WizTree</strong> does the same job much faster on NTFS drives, because it reads the drive's Master File Table directly instead of opening every folder. It's free for personal use, and businesses buy a supporter license priced by staff size, from $25 to $500.</p>
        <p><strong>TreeSize</strong>, from JAM Software, adds reports, scheduled scans, and a duplicate finder. TreeSize Free covers private use. Personal is $25.20 per user per year, and Professional starts at $49.</p>
        <h3>What happens on a Mac</h3>
        <p>WinDirStat and TreeSize have no Mac version. WizTree is the exception: Antibody Software released WizTreeMac 1.00 on September 16, 2026, for macOS 12 and later, native on Apple silicon and Intel. Its site says it has almost all of the Windows version's features, including the treemap. APFS has no Master File Table, so on a Mac it uses macOS's bulk folder reading across several threads instead.</p>
            """},
            {"id": "compare", "lit": True, "html": """
        <h2>Disk Forecast vs WinDirStat, WizTree, and TreeSize</h2>
        <p>Facts come from each vendor's own site and WinDirStat's GitHub releases, checked in October 2026.</p>
        {{TABLE}}
        <h3>What the Windows tools do better</h3>
        <p>Treemaps. If you think in rectangles, WinDirStat's picture of a drive is hard to give up. On a Mac, WizTreeMac and GrandPerspective draw the same kind of map, and DaisyDisk draws rings instead.</p>
        <h3>What Disk Forecast does better</h3>
        <p>It's built for the Mac's own disk. It shows free space in the menu bar, tells you when you'll run out, explains each item it finds, and breaks System Data into parts with Apple's own fixes.</p>
            """, "grid": {"head": ["", "Disk Forecast", "WinDirStat", "WizTree", "TreeSize"], "min_width": 720, "rows": [
                ("Runs on macOS", "Yes, macOS 14 or later", "No", "Yes, as WizTreeMac, macOS 12 or later", "No"),
                ("Price", "Free", "Free", "Free for personal use", "Free for private use; paid from $25.20 a year"),
                ("Treemap", "No", "Yes", "Yes", "Yes"),
                ("Tells you when the disk will be full", "Yes, in the menu bar", "—", "—", "—"),
                ("Explains what each item is", "Yes, in plain English", "—", "—", "—"),
                ("System Data broken down", "Every part, with Apple's fixes", "Not a Mac app", "—", "Not a Mac app"),
                ("Source available", "Yes, on GitHub", "Yes, GPL", "—", "—"),
            ]}},
            {"id": "switch", "html": """
        <h2>The closest Mac tools</h2>
        <ul>
          <li><strong>For the treemap:</strong> <a href="/alternatives/grandperspective">GrandPerspective</a> is free, open source, and updated in September 2026. WizTreeMac is free for personal use. <a href="/alternatives/daisydisk">DaisyDisk</a> is $9.99 and draws rings instead of rectangles.</li>
          <li><strong>For finding what to delete:</strong> Disk Forecast lists the biggest folders and a cleanup list with a plain-English line for every item, sorted into “Safe to clear” and “Worth a look.” Everything goes to the Trash.</li>
          <li><strong>With nothing to install:</strong> <strong>System Settings › General › Storage</strong> sorts your disk by category, and Finder's <strong>Calculate all sizes</strong> shows folder sizes in list view. <a href="/how-to-check-storage-on-mac">How to check Mac storage</a> walks through both.</li>
        </ul>
        <h3>One difference to expect on a Mac</h3>
        <p>On APFS, a duplicated file can share space with the original, and macOS keeps purgeable space and local Time Machine snapshots that don't show up as ordinary files. So a Mac analyzer, Finder, and Storage settings can each show a different total. <a href="/disk-space-analyzer-mac">Disk space analyzers for Mac</a> explains why, and how Disk Forecast counts shared space once.</p>
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

# ---------------------------------------------------------------------- Guides
# Each guide renders with the same template: TL;DR, prose, a shortcut section with one homepage mockup,
# its FAQ (also its FAQPage JSON-LD), related guides, and the download CTA.
# Keyword research: ~/code/diskforecast/docs/seo/keywords-2026-10-06.md, section 1.

# Targets "how to clear system data on mac" (3,500/mo US, KD 0), plus "how to delete/reduce/get rid of system data on mac" and
# "system data mac". What it is and why it's big live at /what-is-system-data-on-mac.
SYSTEM_DATA = {
    "path": "/system-data",
    "title": "How to clear System Data on Mac (and reduce it safely)",
    "description": "How to clear, reduce, and delete System Data on Mac step by step with Apple's own tools: snapshots, simulators, caches, Docker, and what to leave alone.",
    "eyebrow": "Guide",
    "h1": "How to clear System Data on Mac.",
    "lede": "System Data is the gray bar in Storage settings that keeps growing and won't say why. Here's what's inside it, which parts you can reclaim, and the exact steps, using only Apple's own tools.",
    "tldr": "System Data is a catch-all, not one thing. The big parts are usually local Time Machine snapshots, Xcode simulator runtimes, caches, and purgeable space. Restart first, then check snapshots and simulators: that's where the most space hides. Leave purgeable space alone, since macOS frees it on its own, and never delete folders under /System or /private/var by hand.",
    "faqs": [
        ("Why is System Data so big on my Mac?", "Because it's where macOS counts everything it doesn't file under a named category, and the What is System Data on Mac guide explains each part. Local Time Machine snapshots alone can take 30 to 60 GB, and Xcode simulator runtimes, caches, the Spotlight index, Apple Intelligence models, and Docker's disk image all land there too."),
        ("Is it safe to delete System Data?", "Some of it. Caches, old simulator runtimes, and local Time Machine snapshots can be removed with Apple's own tools. Purgeable space should be left for macOS to manage, and you should never delete files under /System or /private/var by hand."),
        ("Why does System Data keep coming back?", "Most of it is supposed to. Caches refill as you use apps, Time Machine makes a new local snapshot every hour, and Spotlight rebuilds its index. Clearing it buys room; it doesn't stop the growth. That's why a forecast helps."),
        ("Does restarting reduce System Data?", "Often, a little. A restart clears temporary files and swap, and gives Storage settings a chance to recalculate. It's the free first step."),
        ("How do I get rid of System Data on my Mac?", "Not all at once, and not for good. Remove local Time Machine snapshots with tmutil, delete simulator runtimes you don't use with xcrun simctl, clear caches, and prune Docker. Each step uses the owning tool, and most of System Data comes back slowly as you use your Mac."),
        ("How do I reduce System Data on Mac without breaking anything?", "Stick to the steps that use Apple's or each tool's own commands, and leave purgeable space, /System, and /private/var alone. Back up to Time Machine regularly so local snapshots don't pile up, and remove old simulator runtimes after Xcode updates."),
        ("Can an app clear System Data for me?", "Disk Forecast breaks System Data into its parts, explains each in plain English, and runs Apple's own tool for each fix after you confirm. It's free, with the source on GitHub."),
    ],
    "html": """
        <h2>First, look at what you have</h2>
        <p>Open <strong>System Settings › General › Storage</strong>. The colored bar at the top splits your disk into categories, and System Data is usually the gray slice near the end. Hover over it to see its size.</p>
        <p>Storage settings won't tell you what's inside, and its number can lag behind reality. Give it a minute after opening, and don't panic if it jumps around. For what counts as System Data, how much is normal, and why it grows, see <a href="/what-is-system-data-on-mac">what is System Data on Mac</a>.</p>
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

        <h2 style="margin-top:56px">How to clear System Data on Mac, step by step</h2>
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
          Add <code>-a</code> to also remove images no container is using. You'll download them again the next time you need them. <a href="/clear-cache/docker">Docker system prune, explained</a> covers every flag.</li>
          <li><b>Turn off Apple Intelligence, if you don't use it.</b> In <strong>System Settings › Apple Intelligence &amp; Siri</strong>, switch it off, and macOS can remove the on-device models. Turn it back on any time; they'll download again. <a href="/ai-models/apple-intelligence">What turning it off does</a> has the details.</li>
          <li><b>Rebuild the Spotlight index.</b> If it's grown large, rebuilding often shrinks it:
<pre><code>sudo mdutil -E /</code></pre>
          Search results will be incomplete for a while as it re-indexes.</li>
          <li><b>Leave purgeable space alone.</b> macOS frees it the moment something needs the room. Apps that “free” it for you are only doing what macOS would have done anyway.</li>
        </ol>

        <h2 style="margin-top:56px">How to reduce System Data and keep it down</h2>
        <p>You can't get rid of System Data for good. Most of it is macOS and your tools doing their jobs, and it comes back as you work. You can slow it down:</p>
        <ul>
          <li><strong>Back up to Time Machine regularly.</strong> Local snapshots pile up on a laptop that rarely sees its backup drive. Regular backups let macOS clear them.</li>
          <li><strong>Clean up after Xcode updates.</strong> Each update tends to bring a new simulator runtime and leave the old one behind. Run <code>xcrun simctl runtime list</code> after updating and delete the ones you don't test on.</li>
          <li><strong>Watch the trend, not the total.</strong> A big System Data that holds steady is fine. One that grows a gigabyte a day needs a look before your disk is full, not after.</li>
        </ul>
        <p>If System Data isn't your biggest category, the rest of the disk is the better place to start: <a href="/free-up-space-on-mac">the free up space checklist</a> covers everything else, and <a href="/how-to-clear-cache-on-mac">how to clear cache on Mac</a> covers caches in detail.</p>

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
    "card_title": "How to clear System Data",
    "card_blurb": "The step-by-step guide, using only Apple's own tools.",
    "footer": "Clear System Data",
    "related": ["/what-is-system-data-on-mac", "/free-up-space-on-mac", "/how-to-clear-cache-on-mac"],
    "mockup": "system-data",
    "cta": "Know before it's full.",
}

# Targets "how to clear cache on mac" (17,000/mo US, KD 1), plus "clear cache on mac", "how to clear cache and cookies on mac",
# "how to clear cache on macbook air/pro", and "is it safe to delete cache files on mac". Most searchers mean the browser.
CACHE = {
    "path": "/how-to-clear-cache-on-mac",
    "title": "How to clear cache on Mac: Safari, Chrome, and app caches",
    "description": "How to clear cache on Mac: Safari, Chrome, and Firefox in under a minute, then app caches in ~/Library/Caches and developer caches like npm and Xcode.",
    "eyebrow": "Guide",
    "h1": "How to clear cache on Mac, <em>safely.</em>",
    "lede": "Most people mean the browser cache, so that comes first: Safari, Chrome, and Firefox, each in under a minute. Then the caches that take real disk space: your apps, macOS itself, and developer tools.",
    "tldr": "In Safari, turn on <strong>Settings › Advanced › Show features for web developers</strong>, then choose <strong>Develop › Empty Caches</strong>. In Chrome, press Command-Shift-Delete, check <strong>Cached images and files</strong>, and click <strong>Delete data</strong>. For app caches, quit the app and move its folder in <code>~/Library/Caches</code> to the Trash. Leave macOS's own caches alone.",
    "card_title": "How to clear cache on Mac",
    "card_blurb": "Safari, Chrome, and Firefox first, then app and developer caches.",
    "footer": "Clear cache on Mac",
    "related": ["/free-up-space-on-mac", "/how-to-check-storage-on-mac", "/system-data"],
    "faqs": [
        ("How do I clear cache on a MacBook Air or MacBook Pro?", "The same way as on any Mac. MacBook Air, MacBook Pro, iMac, and Mac mini all run macOS, so the Safari, Chrome, Firefox, and ~/Library/Caches steps in this guide work on each one."),
        ("Is it safe to delete cache files on Mac?", "For the caches in your own Library folder, yes. A cache is a copy an app can make again, so the cost is a slower first launch while it rebuilds. Quit the app first, move the folders inside ~/Library/Caches to the Trash, and keep the Caches folder itself."),
        ("Is it safe to delete all cache files on Mac?", "Not all at once, and not the system ones. Your own app caches are fine to clear with the apps quit. Leave /Library/Caches and /System/Library/Caches to macOS, and never delete the Caches folder itself."),
        ("Will clearing the cache sign me out or delete my passwords?", "Clearing the browser cache won't. Clearing cookies signs you out of most sites. Saved passwords live in your keychain, which the Passwords app shows on macOS 15 and later, not in any cache."),
        ("Why does the cache come back after I clear it?", "Because that's its job. Apps and browsers rebuild their caches as you use them, so clearing them reclaims space for a while rather than for good. Disk Forecast shows how fast your disk is filling, so you know when it's worth doing again."),
        ("Will clearing cache fix a slow Mac?", "Rarely. Clearing a browser cache can fix a site that loads wrong, and clearing an app's cache can fix an app that misbehaves. On an SSD, free space only matters to how a Mac runs when the disk is nearly full."),
    ],
    "html": """
        <h2>How to clear browser cache on Mac</h2>
        <p>Your browser cache holds copies of images, scripts, and pages from sites you've visited, so they load faster next time. Clearing it fixes pages that look stale or broken, and usually reclaims a few hundred megabytes to a couple of gigabytes. It doesn't sign you out. Cookies do that, and they're a separate checkbox.</p>

        <h3>Safari</h3>
        <ol class="steps">
          <li><b>Show the Develop menu.</b> Choose <strong>Safari › Settings › Advanced</strong> and turn on <strong>Show features for web developers</strong>. Older versions of Safari call it Show Develop menu in menu bar.</li>
          <li><b>Empty the cache.</b> Choose <strong>Develop › Empty Caches</strong>, or press Option-Command-E. Your history, cookies, and logins stay put.</li>
        </ol>

        <h3>Chrome</h3>
        <ol class="steps">
          <li><b>Open Delete browsing data.</b> Press Command-Shift-Delete, or choose <strong>Chrome › Delete Browsing Data</strong>. Older versions call it Clear Browsing Data.</li>
          <li><b>Pick the cache only.</b> Set <strong>Time range</strong> to <strong>All time</strong>, check <strong>Cached images and files</strong>, and uncheck the rest unless you want those gone too.</li>
          <li><b>Click Delete data.</b> Chrome keeps your logins as long as cookies stay unchecked.</li>
        </ol>

        <h3>Firefox</h3>
        <ol class="steps">
          <li><b>Open Clear Data.</b> Choose <strong>Firefox › Settings › Privacy &amp; Security</strong>, scroll to <strong>Cookies and Site Data</strong>, and click <strong>Clear Data</strong>.</li>
          <li><b>Pick cached files.</b> Check <strong>Temporary cached files and pages</strong> (older versions say Cached Web Content), uncheck cookies, and click <strong>Clear</strong>.</li>
        </ol>

        <h2 style="margin-top:56px">How to clear cache and cookies on Mac</h2>
        <p>Clearing cookies signs you out of most sites, so do it on purpose: a site that keeps misbehaving, a Mac you're handing to someone else, or a clean start.</p>
        <ul>
          <li><strong>Safari:</strong> choose <strong>Safari › Clear History</strong>, pick <strong>all history</strong>, and click <strong>Clear History</strong>. That removes history, cookies, and cached data together. To keep your history, use <strong>Safari › Settings › Privacy › Manage Website Data</strong> and click <strong>Remove All</strong> instead.</li>
          <li><strong>Chrome:</strong> in Delete browsing data, check both <strong>Cookies and other site data</strong> and <strong>Cached images and files</strong>.</li>
          <li><strong>Firefox:</strong> in Clear Data, check both <strong>Cookies and site data</strong> and <strong>Temporary cached files and pages</strong>.</li>
        </ul>

        <h2 style="margin-top:56px">How to clear app caches on Mac</h2>
        <p>Every app keeps its cache in your Library folder, and this is where the gigabytes usually are. On the Mac this guide was written on, <code>~/Library/Caches</code> held 17 GB. Chrome's disk cache lives here too, in the <code>Google</code> folder, alongside folders like <code>Homebrew</code>, <code>pip</code>, and <code>com.spotify.client</code>.</p>
        <ol class="steps">
          <li><b>Quit the apps whose caches you'll clear.</b> A running app can rewrite its cache while you work, or trip over it when it disappears.</li>
          <li><b>Open the Caches folder.</b> In Finder, choose <strong>Go › Go to Folder</strong> (Command-Shift-G), type <code>~/Library/Caches</code>, and press Return.</li>
          <li><b>Sort by size.</b> Choose <strong>View › as List</strong>, then <strong>View › Show View Options</strong> and turn on <strong>Calculate all sizes</strong>. Click the Size column.</li>
          <li><b>Move the big folders to the Trash.</b> Start with apps you recognize. Move the folders inside Caches, never the Caches folder itself.</li>
          <li><b>Empty the Trash a day later.</b> Use your Mac as usual first. If an app acts up, put its folder back. Otherwise, empty the Trash and the space is yours.</li>
        </ol>
        <p>A few apps keep their cache somewhere else. Microsoft Teams, for one, keeps it inside its own containers: see <a href="/clear-cache/teams">how to clear Teams cache on Mac</a>.</p>
        <p>Want to know what else is filling the disk before you start? <a href="/how-to-check-storage-on-mac">Check your Mac's storage</a> first; caches are often only part of the story.</p>

        <h2 style="margin-top:56px">Is it safe to delete cache files on Mac?</h2>
        <p>For the caches in your own Library folder, yes. A cache is, by definition, a copy an app can make again. The cost is time: the app is slower the first time it rebuilds, and a music or video app may download things again.</p>
        <ul>
          <li><strong>Clear the contents, not the folder.</strong> Leave <code>~/Library/Caches</code> itself in place. Apps expect it to exist.</li>
          <li><strong>Skip Apple's folders.</strong> Folders that start with <code>com.apple.</code> belong to macOS and Apple's apps. macOS manages them and rebuilds them right away, so you gain little.</li>
          <li><strong>Don't expect it to last.</strong> Caches refill as you use your apps. Clear them when you need the room or an app misbehaves, not as a weekly chore.</li>
        </ul>

        <h2 style="margin-top:56px">System caches: leave them to macOS</h2>
        <p>macOS keeps its own caches in <code>/Library/Caches</code> and <code>/System/Library/Caches</code>. Leave both alone. The system folder is protected by System Integrity Protection, and on most Macs <code>/Library/Caches</code> is small anyway; on the Mac this guide was written on, it was 7 MB.</p>
        <p>If you suspect a bad system cache, start up in safe mode, which Apple says deletes some system caches as part of its checks. On a Mac with Apple silicon, shut down, press and hold the power button until the startup options appear, select your disk, then hold Shift and click <strong>Continue in Safe Mode</strong>. Restart normally afterward, and macOS rebuilds what it needs.</p>

        <h2 style="margin-top:56px">Developer caches: npm, Docker, and Xcode</h2>
        <p>If you write code, this is where cache gets big. Package managers keep every version they've ever downloaded, and Xcode keeps build products for every project you've opened. On the Mac this guide was written on, npm's cache alone was 23 GB.</p>
        <p>Each tool clears its own cache, and downloads what it needs again on the next install:</p>
<pre><code>npm cache clean --force
pnpm store prune
yarn cache clean
pip cache purge
brew cleanup --prune=all</code></pre>
        <p>Docker keeps images and build cache inside its disk image. Its own command removes what nothing is using:</p>
<pre><code>docker builder prune
docker system prune</code></pre>
        <p>For Xcode, quit it, then move the folders inside <code>~/Library/Developer/Xcode/DerivedData</code> to the Trash; Xcode rebuilds them on the next build. Folders in <code>~/Library/Developer/Xcode/iOS DeviceSupport</code> come back when you plug that device in again. Simulator runtimes are bigger still, and they count toward System Data; <a href="/system-data">the System Data guide</a> covers removing them with <code>xcrun simctl</code>.</p>
        <p>Every tool has its own page with the real path on a Mac, its flags, and what rebuilds: <a href="/clear-cache/npm">npm</a>, <a href="/clear-cache/yarn">Yarn</a>, <a href="/clear-cache/pip">pip</a>, <a href="/clear-cache/homebrew">Homebrew</a>, <a href="/clear-cache/docker">Docker</a>, <a href="/clear-cache/xcode">Xcode</a>, and more in <a href="/clear-cache">clear cache by tool</a>.</p>
    """,
    "shortcut": """
          <h2>Or reclaim every cache in one window.</h2>
          <p>Disk Forecast finds app caches, package manager caches, Xcode DerivedData and device support, and logs, and explains each one. They rebuild themselves, so they come checked. macOS&#39;s own caches are left alone, and everything goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "cta": "Know before it's full.",
}

# Targets "how to free up disk space on mac" (3,700/mo US, KD 0), plus "how to free up space on mac", "how to clear storage on mac",
# "how to get more storage on mac", and "your startup disk is almost full". "Optimize" appears once, only as Apple's setting name.
FREE_UP = {
    "path": "/free-up-space-on-mac",
    "title": "How to free up disk space on Mac: the complete checklist",
    "description": "How to free up disk space on Mac, in order: the quick wins, the big folders, the developer files, and what to do when your startup disk is almost full.",
    "eyebrow": "Guide",
    "h1": "How to free up disk space on Mac, <em>in order.</em>",
    "lede": "A checklist that starts with the steps that reclaim the most space for the least effort, and ends with the ones only some Macs need. Every step uses something built into macOS, or the tool that made the files.",
    "tldr": "Empty the Trash, then clear out <code>~/Downloads</code> and old installers. Delete apps you don't use. Turn on Apple's own recommendations in <strong>System Settings › General › Storage</strong>. Then go after the big folders: old iPhone backups, caches, developer files, and System Data. Restart when you're done.",
    "card_title": "How to free up space on Mac",
    "card_blurb": "The complete checklist, from emptying the Trash to System Data.",
    "footer": "Free up space on Mac",
    "related": ["/how-to-check-storage-on-mac", "/how-to-clear-cache-on-mac", "/what-is-system-data-on-mac"],
    "faqs": [
        ("What's the fastest way to free up space on a Mac?", "Empty the Trash, then sort your Downloads folder by size and move old installers and big files to the Trash. Restart afterward. Those three steps take five minutes and often reclaim several gigabytes."),
        ("Why is my Mac storage full when I don't have many files?", "Usually because of things you didn't save yourself: local Time Machine snapshots, caches, old iPhone backups, Xcode simulators, or a Docker disk image. Most of that shows up as System Data in Storage settings."),
        ("How much free space should a Mac have?", "There's no official number. A good rule is to keep at least 10 percent of the disk free, and more before a major macOS upgrade, which needs tens of gigabytes to install."),
        ("What does Store in iCloud do?", "It keeps your Desktop and Documents folders, photos, and messages in iCloud, and keeps only recent files and smaller photo versions on your Mac when space runs low. You can download the originals at any time. It needs enough iCloud storage for everything you store."),
        ("Is it safe to use a Mac cleaner app?", "It depends on what the app deletes and whether you can undo it. Look for one that explains each item, uses Apple's own tools for system files, and moves files to the Trash instead of deleting them. Disk Forecast does all three, and it's free."),
        ("Does freeing up space make a Mac run better?", "Only if the disk was nearly full. macOS needs free space for swap, updates, and temporary files, so a Mac with a few gigabytes left can stall. Beyond that, more free space doesn't change much."),
    ],
    "html": """
        <h2>First, see what's taking up space</h2>
        <p>Open <strong>System Settings › General › Storage</strong> and wait for the bar to finish calculating. It splits your disk into categories like Applications, Documents, Photos, and System Data. The biggest category tells you which steps below matter most for your Mac. For more ways to look, including Finder and Terminal, see <a href="/how-to-check-storage-on-mac">how to check Mac storage</a>.</p>

        <h2 style="margin-top:56px">Quick wins: how to free up space on Mac in 5 minutes</h2>
        <ol class="steps">
          <li><b>Empty the Trash.</b> Files you've deleted still take space until you do. Choose <strong>Finder › Empty Trash</strong>, or press Command-Shift-Delete in Finder. Photos and Mail have their own: <strong>Recently Deleted</strong> in Photos keeps items for up to 30 days unless you delete them there too.</li>
          <li><b>Clear out Downloads.</b> Open <code>Downloads</code> in Finder, choose <strong>View › as List</strong>, and click the Size column. Old installers (<code>.dmg</code> and <code>.pkg</code> files) and zip files you've already opened are safe to move to the Trash.</li>
          <li><b>Delete apps you don't use.</b> In Storage settings, click the info button next to <strong>Applications</strong> to see them sorted by size. Drag the ones you don't need from the Applications folder to the Trash. Big creative apps and games often take 10 GB or more each.</li>
          <li><b>Turn on Apple's recommendations.</b> At the top of Storage settings: <strong>Store in iCloud</strong> keeps your files, photos, and messages in iCloud and only recent ones on your Mac. <strong>Optimize Storage</strong> removes Apple TV movies and shows you've already watched, and keeps only recent Mail attachments. <strong>Empty Trash Automatically</strong> erases items that have been in the Trash for more than 30 days.</li>
          <li><b>Restart.</b> A restart clears temporary files and swap, and gives macOS a chance to remove old local snapshots. Storage settings also recalculates.</li>
        </ol>

        <h2 style="margin-top:56px">How to clear storage on Mac: the big folders</h2>
        <ol class="steps">
          <li><b>Delete old iPhone and iPad backups.</b> Backups made through Finder live in <code>~/Library/Application Support/MobileSync/Backup</code> and can be tens of gigabytes each. In Storage settings, click the info button next to <strong>iOS Files</strong> to see them and delete the ones for devices you no longer have.</li>
          <li><b>Trim Messages attachments.</b> In Messages, choose <strong>Messages › Settings › General</strong> and set <strong>Keep messages</strong> to 1 Year or 30 Days. Or click the info button next to <strong>Messages</strong> in Storage settings and delete the largest attachments.</li>
          <li><b>Clear caches.</b> Apps keep gigabytes of cached files in <code>~/Library/Caches</code>, and they rebuild what they need. <a href="/how-to-clear-cache-on-mac">How to clear cache on Mac</a> covers browsers, apps, and what to leave alone.</li>
          <li><b>Find large files.</b> In a Finder window, press Command-F, click <strong>This Mac</strong>, change <strong>Kind</strong> to <strong>Other › File Size</strong>, and search for files greater than 1 GB. Old screen recordings, videos, and disk images are the usual finds.</li>
          <li><b>Move big media to an external drive.</b> A Photos library, video projects, or a music collection can live on an external SSD. Copy it, confirm the copy opens, then remove the original.</li>
          <li><b>Reclaim System Data.</b> If System Data is the biggest slice, it's usually local Time Machine snapshots, simulator runtimes, or Docker. <a href="/system-data">How to clear System Data</a> walks through each with Apple's own tools.</li>
        </ol>

        <h2 style="margin-top:56px">If you write code</h2>
        <p>Developer Macs fill up differently. Build folders like <code>node_modules</code>, Xcode's DerivedData, simulator runtimes, package manager caches, Docker images, and local AI models add up fast. To list the <code>node_modules</code> folders in your home folder by size:</p>
<pre><code>find ~ -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>
        <p>Delete the ones in projects you haven't touched in a while; <code>npm install</code> brings them back. For Ollama models, <code>ollama list</code> shows what you have and <code>ollama rm &lt;model&gt;</code> removes one; <a href="/ai-models">delete local AI models</a> covers Ollama, LM Studio, and Hugging Face.</p>
        <p>Package managers and build tools keep caches of their own, and each has a command to clear it. <a href="/clear-cache">Clear cache by tool</a> has a page for npm, Docker, Xcode, pip, and six more.</p>

        <h2 style="margin-top:56px">Your startup disk is almost full: what to do now</h2>
        <p>When free space gets critically low, macOS shows a warning: “Your disk is almost full,” or on older versions, “Your startup disk is almost full.” Its <strong>Manage</strong> button opens Storage settings. Take it seriously. With too little room, apps can't save, updates won't install, Messages warns that incoming messages may be lost, and macOS can't grow swap when memory runs short.</p>
        <ol class="steps">
          <li><b>Make room right away.</b> Empty the Trash and move your biggest downloads to the Trash, then empty it again. Even 10 GB gets you out of the danger zone.</li>
          <li><b>Restart.</b> Swap and temporary files are cleared, and macOS gets a chance to release purgeable space it was holding.</li>
          <li><b>Work through the checklist.</b> Start with whichever category is biggest in Storage settings.</li>
        </ol>

        <h2 style="margin-top:56px">How to get more storage on Mac</h2>
        <p>On most Macs, internal storage can't be upgraded after you buy it. You can still get more room:</p>
        <ul>
          <li><strong>iCloud.</strong> Store in iCloud keeps the originals online and recent files on your Mac. It needs enough iCloud storage for everything you store.</li>
          <li><strong>An external SSD.</strong> Fast enough to keep a Photos library, video projects, or virtual machines on it, and inexpensive per gigabyte.</li>
          <li><strong>Time Machine on an external drive.</strong> Backing up regularly lets macOS clear its local snapshots instead of holding them for the next backup.</li>
        </ul>

        <h2 style="margin-top:56px">What not to delete</h2>
        <ul>
          <li><strong>Anything under /System.</strong> It's on a sealed, read-only volume, and macOS needs all of it.</li>
          <li><strong>Folders in ~/Library/Application Support you don't recognize.</strong> That's where apps keep their data, not their caches. Look up a folder before you remove it.</li>
          <li><strong>Commands from forums that start with <code>sudo rm</code>.</strong> If a step deletes files as administrator, make sure you know exactly which ones.</li>
        </ul>
    """,
    "shortcut": """
          <h2>Get the warning weeks ahead, not at 2 GB.</h2>
          <p>Disk Forecast checks your free space every hour and, after 3 days, tells you when you&#39;ll run out. When it&#39;s time, it shows what&#39;s safe to clear and moves it to the Trash. It&#39;s free.</p>
    """,
    "mockup": "forecast",
    "cta": "Know before it's full.",
}

# Targets "how to check mac storage" (7,600/mo US, KD 0), plus "how to check storage on mac", "how to check disk space on mac",
# "how to see what's taking up space on mac", "memory vs storage on mac", and "how to find large files on mac".
CHECK = {
    "path": "/how-to-check-storage-on-mac",
    "title": "How to check Mac storage: 5 ways built into macOS",
    "description": "How to check Mac storage in System Settings, About This Mac, Finder, Disk Utility, and Terminal, then see what's taking up space and find large files.",
    "eyebrow": "Guide",
    "h1": "How to check Mac storage, <em>five ways.</em>",
    "lede": "The fastest way takes three clicks. The others show different numbers, and it helps to know why, especially when your Mac says it's full and Finder disagrees.",
    "tldr": "Choose <strong>Apple menu › System Settings › General › Storage</strong>. The bar at the top shows what's used by category and what's available. For folder sizes, use Finder's <strong>Calculate all sizes</strong>. For exact numbers, run <code>df -h /System/Volumes/Data</code> in Terminal.",
    "card_title": "How to check Mac storage",
    "card_blurb": "Five built-in ways, plus how to find what's taking up space.",
    "footer": "Check Mac storage",
    "related": ["/free-up-space-on-mac", "/what-is-system-data-on-mac", "/how-to-clear-cache-on-mac"],
    "faqs": [
        ("How do I check storage on a MacBook Air or MacBook Pro?", "Choose Apple menu › System Settings › General › Storage. It works the same on every Mac running macOS 13 or later, laptops included. On older versions, it's Apple menu › About This Mac › Storage."),
        ("How do I see what's taking up space on my Mac?", "Storage settings groups it by category; click the info button next to a category to see the files. For folders, open your home folder in Finder in list view, turn on Calculate all sizes in View Options, and sort by size."),
        ("Why does my Mac show more free space than Terminal?", "Finder and Storage settings count purgeable space, like local snapshots and iCloud files macOS can download again, as available. The df command only counts space that's free right now. Finder also uses gigabytes where df -h uses gibibytes."),
        ("What's the difference between memory and storage on a Mac?", "Memory, or RAM, is the short-term workspace apps use while they run, and it empties when you quit them or restart. Storage is the SSD that keeps your files when the Mac is off. About This Mac shows your memory; Storage settings shows your storage."),
        ("Why does Storage settings take so long to load?", "It measures every category when you open it, which can take a minute on a full disk. Let it finish before you trust the numbers, and give it another moment after you delete something."),
    ],
    "html": """
        <h2>1. How to check storage on Mac in System Settings</h2>
        <p>This is Apple's main storage view, and the one to start with.</p>
        <ol class="steps">
          <li><b>Open Storage settings.</b> Choose <strong>Apple menu › System Settings</strong>, click <strong>General</strong> in the sidebar, then click <strong>Storage</strong>. Or press Command-Space and type “Storage.”</li>
          <li><b>Read the bar.</b> Wait for it to finish calculating. Each color is a category, like Applications, Documents, Photos, macOS, and System Data. The number above it is how much is available.</li>
          <li><b>Look inside a category.</b> Scroll down and click the info button next to a category to see its files, sorted by size, with the option to delete them.</li>
        </ol>
        <p>One category won't open up this way: System Data, the gray slice near the end. <a href="/what-is-system-data-on-mac">What is System Data on Mac</a> explains what's in it.</p>

        <h2 style="margin-top:56px">2. About This Mac</h2>
        <p>Choose <strong>Apple menu › About This Mac</strong>, then click <strong>More Info</strong>. That opens <strong>System Settings › General › About</strong>, where the Storage row shows something like “142 GB available of 494 GB.” Click <strong>Storage Settings</strong> there to jump to the full view above. On macOS 12 and earlier, About This Mac had its own Storage tab.</p>

        <h2 style="margin-top:56px">3. Finder</h2>
        <ul>
          <li><strong>The status bar.</strong> Choose <strong>View › Show Status Bar</strong>, and every Finder window shows how much space is available at the bottom.</li>
          <li><strong>Get Info.</strong> Choose <strong>Go › Computer</strong>, select <strong>Macintosh HD</strong>, and press Command-I. The window shows capacity, available, and used.</li>
          <li><strong>Folder sizes.</strong> Open a folder in list view (<strong>View › as List</strong>), choose <strong>View › Show View Options</strong>, and turn on <strong>Calculate all sizes</strong>. Click the Size column to sort. Start with your home folder: this is the quickest way to see which folders are big.</li>
        </ul>

        <h2 style="margin-top:56px">4. Disk Utility</h2>
        <p>Open <strong>Applications › Utilities › Disk Utility</strong>, and select <strong>Macintosh HD</strong> in the sidebar. You'll see used, free, and capacity for the whole disk, including other volumes in the same container. Disk Utility won't break usage down by category, but it's the place to check an external drive too.</p>

        <h2 style="margin-top:56px">5. Terminal: how to check disk space on Mac precisely</h2>
        <p>For exact numbers, open Terminal and run:</p>
<pre><code>df -h /System/Volumes/Data</code></pre>
        <p>Read the <strong>Avail</strong> column. Use <code>/System/Volumes/Data</code>, not <code>/</code>: since macOS Catalina, <code>/</code> is the read-only system volume, so <code>df -h /</code> shows only a few gigabytes used even when your disk is full. To list the biggest folders in your home folder:</p>
<pre><code>du -sh ~/* 2>/dev/null | sort -h</code></pre>
        <p>The biggest are at the bottom. Run the same command on <code>~/Library/*</code> to go one level deeper; it's where caches, app data, and developer files live. The first time, macOS may ask whether Terminal can access folders like Documents and Desktop. Allow it, or those folders are skipped.</p>

        <h2 style="margin-top:56px">Why the numbers don't match</h2>
        <ul>
          <li><strong>Purgeable space.</strong> Finder and Storage settings count space macOS can free on demand, like local snapshots and iCloud files it can download again, as available. <code>df</code> doesn't. On the Mac this guide was written on, <code>df</code> showed 32 GB available while macOS counted 270 GB available for important files.</li>
          <li><strong>GB versus GiB.</strong> Finder counts 1 GB as a billion bytes. <code>df -h</code> counts in gibibytes, about 7 percent larger, so a 994 GB disk shows as 926Gi.</li>
          <li><strong>Timing.</strong> Storage settings measures when you open it and can lag behind what you just deleted. Give it a minute.</li>
        </ul>

        <h2 style="margin-top:56px">How to see what's taking up space on Mac</h2>
        <p>Start with the biggest category in Storage settings. If it's Applications, Documents, or Photos, its info button lists the files. If it's System Data, the space is in places Storage settings doesn't name, and <a href="/system-data">the System Data guide</a> shows how to reclaim it. If nothing stands out, sort your home folder by size in Finder, and look inside <code>~/Library</code>, <code>~/Downloads</code>, and any code or video folders.</p>

        <h2 style="margin-top:56px">How to find large files on Mac</h2>
        <ol class="steps">
          <li><b>In Storage settings.</b> Click the info button next to <strong>Documents</strong> to see large files and downloads, sorted by size.</li>
          <li><b>In Finder.</b> Press Command-F, click <strong>This Mac</strong>, change <strong>Kind</strong> to <strong>Other</strong>, choose <strong>File Size</strong>, and set it to “is greater than 1 GB.”</li>
          <li><b>In Terminal.</b> Spotlight's index answers in seconds:
<pre><code>mdfind 'kMDItemFSSize > 1000000000'</code></pre>
          Or search your home folder directly, which is slower but includes files Spotlight skips:
<pre><code>find ~ -type f -size +1G 2>/dev/null</code></pre></li>
        </ol>
        <p>Found more than you expected? <a href="/free-up-space-on-mac">The free up space checklist</a> goes through what's safe to remove, in order.</p>

        <h2 style="margin-top:56px">Memory vs storage on Mac</h2>
        <p>They're easy to mix up because both are measured in gigabytes.</p>
        <ul>
          <li><strong>Memory (RAM)</strong> is the workspace apps use while they run. It empties when you quit apps or restart. About This Mac shows how much you have, and <strong>Activity Monitor › Memory</strong> shows how much is in use.</li>
          <li><strong>Storage</strong> is the SSD that keeps your files, apps, and macOS itself when the Mac is off. Everything in this guide checks storage.</li>
          <li><strong>They meet in swap.</strong> When memory runs short, macOS moves some of it to storage. That's why a nearly full disk can bring up “Your system has run out of application memory,” even on a Mac with plenty of RAM.</li>
        </ul>
    """,
    "shortcut": """
          <h2>Or keep it in your menu bar.</h2>
          <p>Disk Forecast shows your free space in the menu bar all day. Click it to see when you&#39;ll run out, the five folders taking the most space, and how much is safe to clear. It&#39;s free.</p>
    """,
    "mockup": "menu",
    "cta": "Know before it's full.",
}

# Targets "what is system data on mac" (3,600/mo US, KD 1), plus "why is system data so big mac", "system data on mac is huge",
# "how much system data is normal on mac", and "why does system data keep increasing on mac". The how-to lives at /system-data.
WHAT_IS = {
    "path": "/what-is-system-data-on-mac",
    "title": "What is System Data on Mac? A plain-English explanation",
    "description": "What System Data on Mac is, how much is normal, why it gets so big and keeps increasing, and how it relates to the old Other storage category.",
    "eyebrow": "Guide",
    "h1": "What is System Data on Mac, <em>really?</em>",
    "lede": "It's the gray slice in Storage settings that's bigger than you expect and won't say why. Here's what's in it, how much is normal, and why it keeps growing.",
    "tldr": "System Data is macOS's catch-all: everything Storage settings can't file under a named category like Applications, Documents, or Photos. On most Macs it's mostly local Time Machine snapshots, caches, simulator runtimes, Docker and virtual machine disk images, Apple Intelligence models, and the Spotlight index. Tens of gigabytes is common. It keeps increasing because most of what's in it grows as you use your Mac.",
    "card_title": "What is System Data on Mac?",
    "card_blurb": "What's inside it, how much is normal, and why it keeps growing.",
    "footer": "What is System Data",
    "related": ["/system-data", "/free-up-space-on-mac", "/how-to-check-storage-on-mac"],
    "faqs": [
        ("What is System Data in Mac storage?", "It's the category in System Settings › General › Storage for everything macOS doesn't file under a named category. That includes local Time Machine snapshots, caches, logs, simulator runtimes, virtual machine and Docker disk images, Apple Intelligence models, and the Spotlight index."),
        ("How much System Data is normal on a Mac?", "Apple doesn't publish a number. Tens of gigabytes is common on a Mac that's been in use for a while. Past 100 GB, look for local Time Machine snapshots, Xcode simulator runtimes, Docker, or virtual machines."),
        ("Why is my System Data so high on Mac?", "Usually one of three things: local Time Machine snapshots waiting for a backup, developer tools like Xcode simulators and Docker, or caches that grew over months. Purgeable space can also make it look bigger than the space you'd actually get back."),
        ("Why does System Data keep increasing?", "Because most of what's in it is supposed to grow. Time Machine takes a new local snapshot every hour, caches refill as you use apps, and Xcode and Docker add runtimes and images with each update. Clearing it reclaims space; it doesn't stop the growth."),
        ("Is System Data the same as Other storage?", "Yes, more or less. macOS Big Sur and earlier called the catch-all category Other. Apple renamed it System Data in macOS Monterey. Either way, it doesn't include macOS itself, which has its own category."),
        ("Can I delete System Data?", "Not with one button, and not by deleting folders under /System. You reclaim it one part at a time with Apple's own tools: tmutil for snapshots, xcrun simctl for simulators, and so on. The System Data guide walks through each step."),
    ],
    "html": """
        <h2>What System Data is</h2>
        <p>Open <strong>System Settings › General › Storage</strong> and the bar at the top splits your disk into categories: Applications, Documents, Photos, Messages, macOS, and more. Each named category is something macOS can recognize and count. <strong>System Data is everything else.</strong> It's a catch-all, not a single folder, which is why Storage settings can't show you what's inside it the way it can for Documents.</p>
        <p>It's also not the operating system. macOS itself has its own category, simply called macOS, on recent versions. System Data is what builds up around it: files macOS, your apps, and your tools create while you use the Mac.</p>
        <div class="callout"><p><strong>The short definition.</strong> System Data is space used by files that aren't apps, aren't your documents or media, and aren't macOS itself. Most of it is temporary, rebuildable, or both.</p></div>

        <h2 style="margin-top:56px">What's inside System Data on Mac</h2>
        <ul>
          <li><strong>Local Time Machine snapshots.</strong> If you back up with Time Machine, macOS keeps hourly snapshots on your Mac between backups, so you can restore files even when the backup drive isn't connected. They're the most common reason System Data is huge.</li>
          <li><strong>Purgeable space.</strong> Space macOS has already marked as reclaimable, like iCloud files it can download again. It frees it on its own when something needs the room.</li>
          <li><strong>Caches and logs.</strong> Copies apps keep so they don't have to download or rebuild things, plus records of what they did. Some land in named categories, but much of it counts here.</li>
          <li><strong>Simulators and runtimes.</strong> If you've installed Xcode, each iOS, watchOS, or visionOS simulator runtime can take several gigabytes.</li>
          <li><strong>Docker and virtual machines.</strong> Docker keeps all its images, containers, and build cache in one disk image (<a href="/clear-cache/docker">here's how to prune it</a>). Parallels, UTM, and VMware save whole computers as single files.</li>
          <li><strong>Apple Intelligence and Siri models.</strong> On Macs that support it, the on-device models take several gigabytes. <a href="/ai-models/apple-intelligence">Apple Intelligence storage</a> explains what turning it off does.</li>
          <li><strong>The Spotlight index.</strong> The database behind search. Usually small, occasionally not.</li>
        </ul>

        <h2 style="margin-top:56px">How much System Data is normal on a Mac?</h2>
        <p>Apple doesn't publish a number, and it varies a lot with how you use your Mac. As a rough guide:</p>
        <ul>
          <li><strong>A Mac used for everyday work:</strong> often 10 to 40 GB, mostly caches, snapshots, and models.</li>
          <li><strong>A developer's Mac:</strong> often 50 to 150 GB, because simulator runtimes, Docker, and build caches all count here.</li>
          <li><strong>Over 100 GB on a Mac that isn't used for development:</strong> look at local Time Machine snapshots first, especially on a laptop that's rarely connected to its backup drive.</li>
        </ul>
        <p>What matters more than the size is the trend. A big System Data that holds steady is fine. A small one that grows a gigabyte a day isn't.</p>

        <h2 style="margin-top:56px">Why is System Data so big on my Mac?</h2>
        <p>When System Data on a Mac is huge, it's almost always one of these:</p>
        <ol class="steps">
          <li><b>Snapshots waiting for a backup.</b> macOS counts local snapshots as purgeable and removes them after 24 hours or when space runs low, but until then Storage settings may show them as tens of gigabytes. Check with <code>tmutil listlocalsnapshots /</code> in Terminal.</li>
          <li><b>Developer tools.</b> Xcode downloads a new simulator runtime with most updates and keeps the old ones. Docker's disk image grows with every image you pull or build.</li>
          <li><b>Files Storage settings can't place.</b> App data in <code>~/Library</code> that isn't clearly a document, like a chat app's local database, or a game's downloaded content, often lands in System Data.</li>
        </ol>
        <p>Purgeable space can also make System Data look bigger than it is: space macOS would give back the moment you needed it is still drawn in the bar. <a href="/how-to-check-storage-on-mac">How to check Mac storage</a> explains why different tools show different numbers.</p>

        <h2 style="margin-top:56px">Why does System Data keep increasing on Mac?</h2>
        <p>Because most of what's in it is designed to grow. Time Machine takes a new local snapshot every hour. Caches refill as you browse and use apps. Spotlight indexes every new file. Xcode adds runtimes, Docker adds images, and macOS downloads new models with updates. Clearing System Data reclaims space, but it doesn't change the pace it comes back at.</p>
        <p>That's why it helps to watch the trend instead of the total. If System Data and everything else together fill your disk by 2 GB a week, you have months. If it's 2 GB a day, you have a problem, and it's better to know before macOS warns you that your disk is almost full.</p>

        <h2 style="margin-top:56px">System Data vs the old “Other” storage</h2>
        <p>If you remember a big gray “Other” in About This Mac, it's the same idea. macOS Big Sur and earlier called the catch-all category Other. Apple renamed it System Data in macOS Monterey; what it holds didn't change much. On macOS 13 and later, both live in <strong>System Settings › General › Storage</strong> instead of About This Mac.</p>

        <h2 style="margin-top:56px">Can you delete System Data?</h2>
        <p>Parts of it, safely, with Apple's own tools. There's no single button, and you should never delete folders under <code>/System</code> or <code>/private/var</code> by hand. The usual order is: restart, remove local snapshots with <code>tmutil</code>, delete simulator runtimes you don't use with <code>xcrun simctl</code>, clear caches, and prune Docker. <a href="/system-data">How to clear System Data on Mac</a> has every step and command.</p>
    """,
    "shortcut": """
          <h2>See your own System Data, explained.</h2>
          <p>Disk Forecast breaks System Data on your Mac into its parts, sizes each one, says what it is, and runs Apple&#39;s own fix when you confirm. Then it forecasts when your disk will be full, so the growth never surprises you. It&#39;s free.</p>
    """,
    "mockup": "system-data",
    "cta": "Know before it's full.",
}

# In reading order: the hub and every footer list them this way.
GUIDES = [CHECK, FREE_UP, CACHE, WHAT_IS, SYSTEM_DATA]

GUIDES_HUB = {
    "path": "/guides",
    "title": "Mac storage guides: check, clear, and reclaim disk space",
    "description": "Plain-English guides to Mac storage: how to check it, free up disk space, clear cache, and understand and clear System Data with macOS's own tools.",
    "h1": "Mac storage guides, <em>in plain English.</em>",
    "lede": "How to see what's filling your Mac, what's safe to clear, and how to reclaim it with the tools built into macOS. Every step is something you can do yourself, for free.",
    "cta": "Know before it's full.",
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

# ---------------------------------------------------------------------- Roundups
# Comparison and category pages that cover several apps at once. Each renders with the guide template;
# its html can hold {{TABLE:name}} placeholders for the tables in its "tables". "in_guides" also lists it on /guides.
# Competitor facts were checked against each vendor's site, store listing, GitHub, or the app itself in October 2026.
ROUNDUPS = []
