# Folder pages: /taking-up-space/[thing], plus their hub. One section in tools.SECTIONS, rendered with the per-tool
# template: TL;DR answer, prose with a {{PATHS}} table, an honest "Disk Forecast and [thing]" section ("finds_title"),
# FAQ, siblings, CTA.
#
# Every Disk Forecast claim traces to SystemDataModel.swift, CleanupRules.swift, and FullDiskAccess.swift: the scan covers
# the home folder only, skips ~/Library/CloudStorage always, and skips Messages, MobileSync, Mobile Documents, and the
# Photos library without Full Disk Access. Measurements come from one MacBook Pro (M4 Pro, 48 GB, macOS 26.6.2) in
# October 2026. Settings labels come from the English strings in macOS 26.6's own frameworks.
# Keyword research: ~/code/diskforecast/docs/seo/keywords-2026-10-06.md, section 2c.
#
# Copy rules: never "optimize" except Apple's "Optimize Mac Storage" and "Optimize Storage" settings, and never "boost",
# "speed up", or "junk"; say "reclaim" and "explain". Say "free, source available", never "open source". No em dashes.
# Subheads list 1 or 3 items, never 2.

# ------------------------------------------------------------------ sleepimage
# "sleepimage" 600 / KD 2, "sleepimage mac" 10, "delete sleepimage" 0. Facts: pmset -g (hibernatemode 3, hibernatefile
# /var/vm/sleepimage), ls -l /private/var/vm, man pmset, ls /System/Volumes/VM, diskutil apfs list. Nothing was changed.
SLEEPIMAGE = {
    "slug": "sleepimage",
    "title": "Sleepimage on Mac: what it is and why to leave it",
    "description": "What the sleepimage file in /private/var/vm is, how hibernatemode decides its size, how to check yours, and why deleting it gains you little or nothing.",
    "h1": "Sleepimage on Mac, <em>explained.</em>",
    "lede": "It's a single file macOS writes when your Mac goes to sleep, and it's one of the first big files people find when they go looking. Here's what it does, how big it gets, and why it's not worth deleting.",
    "tldr": "<code>/private/var/vm/sleepimage</code> is where macOS saves a copy of memory when your Mac sleeps, so nothing is lost if the battery runs out. On the MacBook Pro this page was written on, it was 2 GB. Deleting it gains nothing: macOS writes it again the next time the Mac sleeps. The only way to keep it gone is to change <code>hibernatemode</code>, which trades away that safety net.",
    "card_title": "sleepimage",
    "card_blurb": "The hibernation file in /private/var/vm, and why it comes back.",
    "finds_title": "Disk Forecast and the sleepimage",
    "paths": [
        ("Sleep image", "/private/var/vm/sleepimage", "2 GB, with 48 GB of memory"),
        ("Swap files", "/System/Volumes/VM", "20 GB, 19 files"),
    ],
    "html": """
        <h2>What is sleepimage on a Mac?</h2>
        <p>When a Mac sleeps, it keeps memory powered so it can wake in a second. Laptops also write a copy of that memory to disk, in case the battery dies while the lid is closed. That copy is the sleep image. If power runs out, the Mac restores from it on the next start, with your apps and windows as you left them.</p>
        <p>It lives at <code>/private/var/vm/sleepimage</code>. <code>/var</code> is a shortcut to <code>/private/var</code>, so <code>pmset</code> calls it <code>/var/vm/sleepimage</code>. It belongs to the system, only root can read it, and Finder doesn't show the folder unless you go looking.</p>
        {{PATHS}}
        <p>Sizes are from one MacBook Pro with an M4 Pro and 48 GB of memory, running macOS 26.6. The sleep image there was 2 GB. Swap is a different thing: memory macOS moves to disk while the Mac is awake. On recent versions of macOS it has its own volume, <code>/System/Volumes/VM</code>, and it shrinks after a restart.</p>

        <h2 style="margin-top:56px">Hibernatemode: how to check yours</h2>
        <p>Whether macOS writes a sleep image depends on one power setting. To see yours, run this in Terminal. It only reads the setting:</p>
<pre><code>pmset -g | grep hibernatemode
ls -lh /private/var/vm/sleepimage</code></pre>
        <p>Apple's <code>pmset</code> manual lists three values:</p>
        <ul>
          <li><strong>0</strong>, the default on desktops. Memory isn't copied to disk, and a power cut while asleep loses whatever wasn't saved.</li>
          <li><strong>3</strong>, the default on laptops. Memory stays powered and a copy goes to disk too. The Mac wakes from memory unless power ran out.</li>
          <li><strong>25</strong>, true hibernation. Memory is written to disk and powered off: slower to sleep and wake, easier on the battery.</li>
        </ul>
        <p>The MacBook Pro above reports <code>hibernatemode 3</code>, and <code>standby 1</code>, which means it also hibernates on its own after sleeping for a while.</p>

        <h2 style="margin-top:56px">Can you delete sleepimage?</h2>
        <p>You can, with administrator rights, but it doesn't reclaim anything for long. In mode 3 or 25, macOS writes the file again the next time your Mac sleeps, so the space comes back within the hour. Deleting it while it's in use is the risky part: if the Mac then loses power asleep, there's no image to restore from.</p>
        <p>To keep it gone for good, you'd have to change the setting. The <code>pmset</code> manual says that to stop hibernation images completely, <code>hibernatemode</code>, <code>standby</code>, and <code>autopoweroff</code> all have to be 0. The manual itself says “please use caution” next to these settings. On a laptop, the cost is real: a flat battery in your bag means a cold start and any unsaved work gone. For 2 GB on a modern Mac, we don't think it's worth it, and this page doesn't give the commands to do it.</p>
        <div class="callout"><p><strong>When it is worth a look.</strong> If your sleep image is many times bigger than 2 GB, check <code>pmset -g</code> for a <code>hibernatefile</code> someone moved, or a mode other than the default. Restoring the default is safer than deleting the file.</p></div>

        <h2 style="margin-top:56px">Why is sleepimage so big?</h2>
        <p>It has to hold what was in memory, so its size depends on your Mac and how much memory is in use. On the Apple silicon MacBook Pro above, it was 2 GB with 48 GB of memory. Older Intel Macs often had one close to the size of their memory, which is why forum threads talk about 8 or 16 GB files. Either way, it's usually not the biggest thing on your disk. Storage settings doesn't name it, so if you're hunting a big System Data number, local snapshots and simulators are better bets. <a href="/system-data">How to clear System Data</a> covers those.</p>
        <p>Other folders that fill up without asking: <a href="/taking-up-space/iphone-backups">iPhone backups</a>, <a href="/taking-up-space/messages">Messages attachments</a>, and the rest on <a href="/taking-up-space">what's taking up space</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast doesn&#39;t list the sleep image, and it won&#39;t offer to delete it. It scans your home folder, and <code>/private/var/vm</code> isn&#39;t in it. What it does show is the number that matters: your free space, checked every hour, and after 3 days, a forecast like “Full in ~41 days.” If a 2 GB file decides whether you make it to Friday, the forecast tells you weeks ahead. It&#39;s free.</p>
    """,
    "mockup": "forecast",
    "related": ["/taking-up-space/iphone-backups", "/taking-up-space/messages", "/system-data"],
    "faqs": [
        ("What is sleepimage on Mac?", "It's the file at /private/var/vm/sleepimage where macOS saves a copy of memory when the Mac sleeps. If the battery runs out while it's asleep, the Mac restores your apps and windows from it."),
        ("Can I delete sleepimage on my Mac?", "You can, but it doesn't reclaim anything for long: macOS writes it again the next time the Mac sleeps. Stopping it for good means setting hibernatemode, standby, and autopoweroff to 0, which removes the safety net if the battery dies while asleep."),
        ("Why is my sleepimage file so big?", "It holds a copy of memory, so it grows with how much memory your Mac has and uses. On an Apple silicon MacBook Pro with 48 GB of memory, it was 2 GB. Older Intel Macs often had one about the size of their memory."),
        ("How do I check my Mac's hibernatemode?", "Run pmset -g | grep hibernatemode in Terminal. 0 is the desktop default, 3 is the laptop default, and 25 is full hibernation. The command only reads the setting."),
        ("Is sleepimage the same as swap?", "No. Swap is memory moved to disk while the Mac is awake, and on recent macOS it lives on its own volume, /System/Volumes/VM. The sleep image is written when the Mac goes to sleep."),
    ],
}

# ------------------------------------------------------------------ iPhone backups
# "where are iphone backups stored on mac" 500 / KD 0, "delete iphone backups on mac" 0, "ios backups mac" 0.
# Labels: "Manage Backups…" and "Delete Backup" (AMPDevices), "iOS Files" and its subtitle (StorageManagement), and the
# iOS Files extension's own paths (MobileSync/Backup, ~/Library/iTunes/iPhone Software Updates). No backups on this Mac.
IPHONE_BACKUPS = {
    "slug": "iphone-backups",
    "title": "Where are iPhone backups stored on Mac? Find and delete",
    "description": "Where iPhone and iPad backups are stored on a Mac, how to open the folder, and how to delete old backups in Finder or Storage settings without breaking any.",
    "h1": "Where iPhone backups are stored on Mac, <em>and how to delete them.</em>",
    "lede": "Every iPhone or iPad you've backed up to this Mac left a folder behind, often tens of gigabytes each. Here's where they are, and the two built-in ways to remove the ones you no longer need.",
    "tldr": "iPhone and iPad backups are stored in <code>~/Library/Application Support/MobileSync/Backup</code>, one folder per backup. To delete one, open <strong>System Settings › General › Storage</strong>, click the info button next to <strong>iOS Files</strong>, select the backup, and click <strong>Delete</strong>. Or select the device in Finder's sidebar and click <strong>Manage Backups…</strong>. Delete whole backups, never files inside one.",
    "card_title": "iPhone backups",
    "card_blurb": "Where they're stored, and how to delete old ones safely.",
    "finds_title": "Disk Forecast and iPhone backups",
    "paths": [
        ("Device backups", "~/Library/Application Support/MobileSync/Backup", "One folder per backup"),
        ("iPhone software updates", "~/Library/iTunes/iPhone Software Updates", "Only if you've restored a device"),
    ],
    "html": """
        <h2>Where are iPhone backups stored on Mac?</h2>
        <p>When you back up an iPhone or iPad to your Mac, through Finder or, on older versions of macOS, iTunes, the backup goes in your Library folder:</p>
        {{PATHS}}
        <p>Each backup is a folder named with a long device identifier, not the device's name, so you can't tell them apart by looking. Inside are thousands of files with hashed names. That's normal: a backup only makes sense to the Mac that restores it. The Mac this page was written on has never backed up a phone, so there's no size to show. Expect a backup to be roughly the size of what's on the device, minus what's already in iCloud, like iCloud Photos.</p>
        <p>To open the folder in Finder, choose <strong>Go › Go to Folder</strong>, paste the path, and press Return. Terminal is different: macOS guards this folder, so <code>ls</code> and <code>du</code> answer “Operation not permitted” unless Terminal has Full Disk Access in <strong>System Settings › Privacy &amp; Security</strong>.</p>

        <h2 style="margin-top:56px">How to delete iPhone backups on Mac</h2>
        <p>There are two ways to do it. Both show which device each backup belongs to and when it was made, which the folder itself won't.</p>
        <h3>In Storage settings</h3>
        <ol class="steps">
          <li><b>Open Storage settings.</b> Choose <strong>Apple menu › System Settings › General › Storage</strong> and wait for it to finish calculating.</li>
          <li><b>Open iOS Files.</b> Click the info button next to <strong>iOS Files</strong>. macOS describes it as device backups and software updates you can erase to free storage space.</li>
          <li><b>Delete what you don't need.</b> Select a backup, click <strong>Delete</strong>, and confirm. The space comes back right away; nothing goes to the Trash.</li>
        </ol>
        <h3>In Finder</h3>
        <ol class="steps">
          <li><b>Connect the device.</b> Plug it in, or use Wi-Fi if you've set that up, and select it under <strong>Locations</strong> in Finder's sidebar.</li>
          <li><b>Open Manage Backups.</b> On the <strong>General</strong> tab, click <strong>Manage Backups…</strong>. You'll see every backup on this Mac, with its device name and date.</li>
          <li><b>Delete one.</b> Select it, click <strong>Delete Backup</strong>, and confirm.</li>
        </ol>
        <div class="callout"><p><strong>Don't delete files inside a backup.</strong> Remove whole backups, with one of the methods above. A backup missing some of its files won't restore, and you'll only find out when you need it.</p></div>

        <h2 style="margin-top:56px">Which backups are safe to delete?</h2>
        <ul>
          <li><strong>Backups of devices you no longer own.</strong> If the phone was sold, traded in, or replaced, its backup is only useful for digging up something old.</li>
          <li><strong>Backups you also have in iCloud.</strong> If the device backs up to iCloud (on the iPhone, <strong>Settings › [your name] › iCloud › iCloud Backup</strong>), the copy on your Mac is a second one.</li>
          <li><strong>Old software updates.</strong> The iOS Files list includes downloaded update files, used when you restore or update a device from the Mac. Finder downloads them again when it needs one.</li>
        </ul>
        <p>Keep at least one recent backup of any device you still use and don't back up to iCloud. Encrypted backups also hold saved passwords and Health data, so make sure you have a newer one before you remove an old encrypted backup.</p>
        <p>More folders that fill a Mac quietly: <a href="/taking-up-space/messages">Messages attachments</a>, <a href="/taking-up-space/icloud-drive">iCloud Drive</a>, and the full checklist in <a href="/free-up-space-on-mac">how to free up space on Mac</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast never deletes iPhone backups, and it doesn&#39;t list them as something to clear: deleting the wrong one isn&#39;t a mistake you can rebuild from. Without Full Disk Access, it skips the MobileSync folder entirely, the same way Terminal is blocked. With Full Disk Access, it measures the folder, and if it&#39;s one of your biggest, it shows up under <strong>Taking the most space</strong> in the menu, one click from Finder. Delete backups with Storage settings or Finder&#39;s Manage Backups. It&#39;s free.</p>
    """,
    "mockup": "menu",
    "related": ["/taking-up-space/messages", "/taking-up-space/icloud-drive", "/free-up-space-on-mac"],
    "faqs": [
        ("Where are iPhone backups stored on a Mac?", "In ~/Library/Application Support/MobileSync/Backup, one folder per backup, named with the device's identifier. Open it in Finder with Go › Go to Folder. Terminal needs Full Disk Access to read it."),
        ("How do I delete old iPhone backups on my Mac?", "Open System Settings › General › Storage, click the info button next to iOS Files, select the backup, and click Delete. Or select the device in Finder's sidebar, click Manage Backups…, and click Delete Backup."),
        ("Is it safe to delete iPhone backups on a Mac?", "Yes, for backups you don't need: devices you no longer own, or ones that also back up to iCloud. Keep a recent backup of any device you still use, and delete whole backups, never the files inside one."),
        ("Why is iOS Files so big in Storage settings?", "It includes every device backup on this Mac, plus downloaded iPhone and iPad software updates. Each backup can be tens of gigabytes, and old ones stay until you delete them."),
        ("Can I move iPhone backups to an external drive?", "Finder has no setting for it; backups always go to the MobileSync folder on your startup disk. Backing the device up to iCloud instead keeps it off your Mac."),
    ],
}

FOLDER_PAGES = [SLEEPIMAGE, IPHONE_BACKUPS]

TAKING_UP_SPACE_HUB = {
    "path": "/taking-up-space",
    "title": "What's taking up space on Mac: folder by folder",
    "description": "The folders that quietly fill a Mac: the sleep image, iPhone backups, Messages, Dropbox, iCloud Drive, and developer files, with what's safe to remove.",
    "h1": "What's taking up space on your Mac, <em>folder by folder.</em>",
    "lede": "Some of the biggest folders on a Mac are ones you never open. Each page says where one lives, why it grows, and how to reclaim it with the tool that owns it.",
    "card_title": "What's taking up space",
    "card_blurb": "Sleep image, iPhone backups, Messages, cloud drives, and dev files.",
    "footer": "What's taking up space",
    "cta": "Know before it's full.",
    "html": """
        <h2>Where to look first</h2>
        <p>Open <strong>System Settings › General › Storage</strong> and find the biggest category. Messages, iOS Files, and iCloud Drive each have their own row there, with an info button that lists what's inside. Other folders on these pages, like the sleep image and developer files, don't get a row. They're counted in System Data or Documents, or not named at all.</p>
        <p>A rule that holds for every folder here: remove things with the app that made them. Finder deletes iPhone backups, Messages deletes old attachments, Dropbox and iCloud Drive turn files online-only, and Xcode and Docker have their own commands. Deleting the raw files by hand works for some of them and breaks others, and each page says which. For the categories themselves, see <a href="/how-to-check-storage-on-mac">how to check Mac storage</a> and <a href="/what-is-system-data-on-mac">what System Data is</a>.</p>
    """,
    "faqs": [
        ("How do I see what's taking up space on my Mac?", "Open System Settings › General › Storage and wait for the bar to finish. Click the info button next to a category to see its files. For folders Storage settings doesn't name, sort your home folder by size in Finder with Calculate all sizes turned on."),
        ("Which folders take the most space on a Mac?", "Often iPhone backups, Messages attachments, downloaded iCloud Drive or Dropbox files, and, on developer Macs, Xcode simulators, node_modules folders, and Docker's disk image."),
        ("Is it safe to delete folders in ~/Library?", "Only the ones you know. Caches rebuild themselves, but Application Support and Messages hold real data. Delete backups, attachments, and cloud files with the app that owns them."),
    ],
}
