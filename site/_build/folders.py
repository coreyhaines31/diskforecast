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

# ------------------------------------------------------------------ Messages
# "messages taking up space on mac" 200 / KD 0, "imessage taking up storage on mac" 50, "delete messages attachments mac" 10.
# Labels: "Keep Messages" with "30 Days", "1 Year", "Forever", "General", "iMessage", "Messages in iCloud" (MessagesSettingsUI);
# the Messages Storage category and the Store in iCloud recommendation text (StorageManagement). ~/Library/Messages answered
# "Operation not permitted" to ls from Terminal on this Mac, so no size is shown.
MESSAGES = {
    "slug": "messages",
    "title": "Messages taking up space on Mac: how to reclaim it",
    "description": "Why Messages takes up so much space on a Mac, where attachments are stored, and how to reclaim it with Keep Messages, Storage settings, or Messages in iCloud.",
    "h1": "Messages taking up space on Mac, <em>and how to trim it.</em>",
    "lede": "Every photo, video, and voice note anyone has sent you is kept on your Mac, for as long as Messages keeps the conversation. Here's where that lives and the three built-in ways to reclaim it.",
    "tldr": "Messages keeps every attachment in <code>~/Library/Messages/Attachments</code>, forever by default. To reclaim space, choose <strong>Messages › Settings › General</strong> and set <strong>Keep Messages</strong> to <strong>1 Year</strong> or <strong>30 Days</strong>. Or open <strong>System Settings › General › Storage</strong>, click the info button next to <strong>Messages</strong>, and delete the biggest attachments. Don't delete files in the folder by hand.",
    "card_title": "Messages",
    "card_blurb": "Attachments, Keep Messages, and what Messages in iCloud changes.",
    "finds_title": "Disk Forecast and Messages",
    "paths": [
        ("Photos, videos, and files people sent", "~/Library/Messages/Attachments", "Needs Full Disk Access to measure"),
        ("The message history", "~/Library/Messages/chat.db", "Usually far smaller"),
    ],
    "html": """
        <h2>Why Messages takes up so much space on Mac</h2>
        <p>With iMessage on your Mac, every conversation from your iPhone shows up there too, and so does everything in it: photos, videos, voice notes, and files. Messages keeps them all, because <strong>Keep Messages</strong> is set to <strong>Forever</strong> unless you change it. Years of group chats with video add up to tens of gigabytes.</p>
        {{PATHS}}
        <p>The text of your conversations is small. The attachments are what's big. macOS guards this folder: on the Mac this page was written on, Terminal got “Operation not permitted” trying to list it, so measure it with Storage settings instead, which can see inside.</p>

        <h2 style="margin-top:56px">How to reclaim space from Messages</h2>
        <h3>Keep messages for less time</h3>
        <ol class="steps">
          <li><b>Open Messages settings.</b> In Messages, choose <strong>Messages › Settings</strong>, then click <strong>General</strong>.</li>
          <li><b>Change Keep Messages.</b> Pick <strong>1 Year</strong> or <strong>30 Days</strong> instead of <strong>Forever</strong>.</li>
          <li><b>Let it run.</b> Messages deletes conversations older than that, attachments included, and keeps doing it from then on.</li>
        </ol>
        <p>This is the one that keeps working. It's also the bluntest: older messages are gone, text and all, and if Messages in iCloud is on, they're gone from your other devices too.</p>
        <h3>Delete the biggest attachments</h3>
        <ol class="steps">
          <li><b>Open Storage settings.</b> Choose <strong>Apple menu › System Settings › General › Storage</strong>.</li>
          <li><b>Open Messages.</b> Click the info button next to <strong>Messages</strong>. You'll see attachments sorted by size, with the biggest videos at the top.</li>
          <li><b>Delete what you don't need.</b> Select attachments, click <strong>Delete</strong>, and confirm. The conversations stay; only those files go.</li>
        </ol>
        <h3>Store messages in iCloud</h3>
        <p>In <strong>Messages › Settings › iMessage</strong>, turn on <strong>Messages in iCloud</strong>. Or use the <strong>Store in iCloud</strong> recommendation at the top of Storage settings. Apple's description: all messages and attachments are stored in iCloud, and when storage space is needed, only recent attachments are kept on this Mac. You need enough iCloud storage to hold them all, and older attachments download again when you open them.</p>

        <h2 style="margin-top:56px">Is it safe to delete Messages attachments on Mac?</h2>
        <p>From Messages or Storage settings, yes; that's what they're for. A deleted attachment is gone from that conversation, so save any photo you want to keep to Photos or Finder first.</p>
        <p>From Finder, no. Messages keeps a database, <code>chat.db</code>, of which file belongs to which message. Delete files from <code>Attachments</code> by hand and Messages still thinks they're there, so you get blank bubbles and a database that disagrees with the disk. It doesn't save you anything the two methods above don't.</p>
        <p>Messages is one of several folders that grow on their own. See also <a href="/taking-up-space/iphone-backups">iPhone backups</a>, <a href="/taking-up-space/icloud-drive">iCloud Drive</a>, and <a href="/taking-up-space">everything else taking up space</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast won&#39;t delete Messages attachments: that belongs to Messages, which keeps track of every file. Without Full Disk Access, it skips <code>~/Library/Messages</code> entirely, so it never sets off a permission prompt. With Full Disk Access, it measures the folder, and if Messages is one of your biggest, it appears under <strong>Taking the most space</strong> in the menu. Then the forecast shows whether changing Keep Messages slowed the growth. It&#39;s free.</p>
    """,
    "mockup": "menu",
    "related": ["/taking-up-space/iphone-backups", "/taking-up-space/icloud-drive", "/free-up-space-on-mac"],
    "faqs": [
        ("Why is Messages taking up so much space on my Mac?", "Because Messages keeps every photo, video, and file from every conversation, and Keep Messages is set to Forever by default. Those attachments live in ~/Library/Messages/Attachments and can reach tens of gigabytes."),
        ("How do I reduce Messages storage on Mac?", "In Messages › Settings › General, set Keep Messages to 1 Year or 30 Days. Or open System Settings › General › Storage, click the info button next to Messages, and delete the biggest attachments."),
        ("Where are Messages attachments stored on a Mac?", "In ~/Library/Messages/Attachments, organized in folders Messages names itself. macOS guards the folder, so Terminal needs Full Disk Access to read it. Storage settings lists the attachments by size."),
        ("Can I delete the Messages Attachments folder?", "Not by hand. Messages keeps a database of which file belongs to which message, so deleting files in Finder leaves blank bubbles. Delete attachments from Storage settings or shorten Keep Messages instead."),
        ("Does Messages in iCloud free up space on my Mac?", "It can. With Messages in iCloud on, macOS keeps only recent attachments on the Mac when storage space is needed, and downloads older ones when you open them. You need enough iCloud storage for everything."),
    ],
}

# ------------------------------------------------------------------ Dropbox
# "dropbox taking up space on mac" 150 / KD 0, "dropbox files taking up space on mac" 80. Dropbox isn't installed on the
# measuring Mac; ~/Library/CloudStorage holds Google Drive and iCloud Drive there. "Remove Download", "Download Now", and
# "Keep Downloaded" are Finder's own File Provider strings. Dropbox's menu labels come from Dropbox's help, not this Mac.
DROPBOX = {
    "slug": "dropbox",
    "title": "Dropbox taking up space on Mac: online-only, explained",
    "description": "Why Dropbox takes up space on a Mac, where its folder lives in ~/Library/CloudStorage, and how to make files online-only so they stay in the cloud.",
    "h1": "Dropbox taking up space on Mac, <em>and how to stop it.</em>",
    "lede": "Dropbox can keep every file on your Mac, or only the ones you use. When it's taking up more space than you expect, it's almost always because files are downloaded. Here's how to tell, and how to send them back to the cloud.",
    "tldr": "On current versions, Dropbox keeps its folder in <code>~/Library/CloudStorage</code>, using Apple's File Provider. Files can be <strong>online-only</strong>, which take almost no space, or <strong>available offline</strong>, which are fully downloaded. To reclaim space, Control-click big folders in Finder and make them online-only. Don't delete them: deleting a file in Dropbox deletes it from your Dropbox everywhere.",
    "card_title": "Dropbox",
    "card_blurb": "Online-only vs available offline, and where the folder lives.",
    "finds_title": "Disk Forecast and Dropbox",
    "paths": [
        ("Dropbox, on Apple's File Provider", "~/Library/CloudStorage/Dropbox", "Not installed on the Mac we measured"),
        ("Dropbox, older setups", "~/Dropbox", "An ordinary folder"),
    ],
    "html": """
        <h2>Where Dropbox stores files on a Mac</h2>
        <p>Dropbox for macOS now runs on File Provider, the same system iCloud Drive and Google Drive use. Its folder moved into your Library, and it shows in Finder's sidebar under <strong>Locations</strong>. Some Macs that installed Dropbox years ago still have it at <code>~/Dropbox</code> until Dropbox moves it.</p>
        {{PATHS}}
        <p>Dropbox isn't installed on the Mac this page was written on, so there's no measured size. That Mac's <code>CloudStorage</code> folder holds Google Drive and iCloud Drive, which work the same way.</p>

        <h2 style="margin-top:56px">What online-only means in Dropbox</h2>
        <ul>
          <li><strong>Online-only</strong> files show in Finder with their full name and size, but only a placeholder is on your Mac. Opening one downloads it.</li>
          <li><strong>Available offline</strong> files are fully downloaded and stay that way. They take their full size on disk.</li>
          <li><strong>Files you've opened</strong> from online-only are downloaded too, and can stay on your Mac afterward.</li>
        </ul>
        <p>That last one is why Dropbox grows on a Mac where you set everything to online-only. Every file you open comes down, and a few big video or design files undo the setting.</p>
        <div class="callout"><p><strong>Finder's size column doesn't tell you.</strong> Finder lists online-only files at their full size, even though they take almost nothing on disk. To see what's really downloaded, run <code>du -sh ~/Library/CloudStorage/Dropbox</code> in Terminal. macOS may ask Terminal for permission first.</p></div>

        <h2 style="margin-top:56px">How to free up space from Dropbox on Mac</h2>
        <ol class="steps">
          <li><b>Find the big folders.</b> In Dropbox's folder, use <strong>View › as List</strong> and look for folders with a downloaded icon, not a cloud icon.</li>
          <li><b>Make them online-only.</b> Control-click a folder and choose <strong>Make online-only</strong>. Depending on your version, Finder may show its own <strong>Remove Download</strong> instead; it does the same thing. The files stay in Dropbox, and download again when you open them.</li>
          <li><b>Check the default.</b> Dropbox's settings decide whether new files start online-only or downloaded. If yours downloads everything, change it in the Dropbox app, or the space comes back as files sync.</li>
        </ol>
        <p>The menu labels in step 2 come from Dropbox's own help, not from a Mac running Dropbox, so yours may differ slightly. <strong>Download Now</strong> and <strong>Keep Downloaded</strong> are Finder's options for the other direction.</p>

        <h2 style="margin-top:56px">What not to do</h2>
        <ul>
          <li><strong>Don't move files to the Trash to save space.</strong> Deleting a file in your Dropbox folder deletes it from Dropbox on every device. You can usually restore it from deleted files on dropbox.com, for a time that depends on your plan.</li>
          <li><strong>Don't delete the CloudStorage folder.</strong> It's where every File Provider app keeps its files. Quit or uninstall the app that owns a folder instead.</li>
          <li><strong>Don't pause syncing and forget.</strong> Paused files that haven't uploaded only exist on this Mac.</li>
        </ul>
        <p>iCloud Drive works the same way, with Apple's own setting to do it automatically: see <a href="/taking-up-space/icloud-drive">iCloud Drive taking up space</a>. Other big folders: <a href="/taking-up-space/messages">Messages</a> and <a href="/taking-up-space/developer-files">developer files</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast never scans Dropbox, or any cloud drive in <code>~/Library/CloudStorage</code>. Each one asks for its own permission, and their files mostly live online, so the app leaves them alone, with or without Full Disk Access. It won&#39;t make files online-only for you either: that&#39;s Dropbox&#39;s job. What it shows is your free space every hour and when you&#39;ll run out, so you&#39;ll see the space come back after you make folders online-only, and notice if it starts filling again. It&#39;s free.</p>
    """,
    "mockup": "forecast",
    "related": ["/taking-up-space/icloud-drive", "/taking-up-space/messages", "/taking-up-space/developer-files"],
    "faqs": [
        ("Why is Dropbox taking up space on my Mac?", "Because some files are downloaded: folders set to available offline, and online-only files you've opened. Each takes its full size on disk. Make big folders online-only in Finder to send them back to the cloud."),
        ("Where is the Dropbox folder on a Mac?", "On current versions, in ~/Library/CloudStorage/Dropbox, shown under Locations in Finder's sidebar. Older setups may still have it at ~/Dropbox."),
        ("What's the difference between online-only and available offline in Dropbox?", "Online-only files are placeholders that download when you open them and take almost no space. Available offline files are fully downloaded and stay on your Mac."),
        ("Will deleting Dropbox files free up space on my Mac?", "It will, but it deletes them from Dropbox on every device too. To reclaim space and keep the files, make them online-only instead."),
        ("Why does Finder show Dropbox files at full size?", "Finder lists online-only files at the size they are in the cloud. Run du -sh on the Dropbox folder in Terminal to see how much is really downloaded."),
    ],
}

# ------------------------------------------------------------------ iCloud Drive
# "icloud drive taking up space on mac" 100 / KD 0, "why is icloud drive taking up space on my mac" 60. "Optimize Mac Storage"
# is Apple's setting name (AOSUI's iCloud Drive nib) and the only place "optimize" appears. "Remove Download", "Download Now",
# "Keep Downloaded" (Finder), "iCloud Drive" Storage category (StorageUI), and the turn-off prompt (iCloudQuotaUI) are
# macOS 26.6 strings. iCloud Drive is off on the measuring Mac, so no size and no folder listing.
ICLOUD_DRIVE = {
    "slug": "icloud-drive",
    "title": "iCloud Drive taking up space on Mac: why and what to do",
    "description": "Why iCloud Drive takes up space on your Mac when your files are in iCloud, and how Optimize Mac Storage and Remove Download move them back off your disk.",
    "h1": "iCloud Drive taking up space on Mac, <em>explained.</em>",
    "lede": "Your files are in iCloud, so why is your Mac full of them? Because iCloud Drive also keeps downloaded copies on the Mac, and by default, it can keep all of them. Here's how to see it and how to send them back.",
    "tldr": "iCloud Drive keeps a downloaded copy of every file you open or save, and without <strong>Optimize Mac Storage</strong> it keeps them all. Turn that setting on in <strong>System Settings › [your name] › iCloud</strong>, and macOS removes downloads of older files when space runs low. To reclaim space now, Control-click big files or folders in iCloud Drive and choose <strong>Remove Download</strong>. Don't delete them: that deletes them from iCloud too.",
    "card_title": "iCloud Drive",
    "card_blurb": "Optimize Mac Storage, Remove Download, and why it uses space.",
    "finds_title": "Disk Forecast and iCloud Drive",
    "paths": [
        ("iCloud Drive in Finder's sidebar", "~/Library/Mobile Documents", "iCloud Drive was off on the Mac we measured"),
        ("Desktop and Documents, if stored in iCloud", "~/Desktop and ~/Documents", "Same rules as iCloud Drive"),
    ],
    "html": """
        <h2>Why is iCloud Drive taking up space on my Mac?</h2>
        <p>iCloud Drive is a sync service, not just storage somewhere else. Files you save there go to iCloud and stay on your Mac. Files you open from another device are downloaded and stay too. Unless you tell macOS otherwise, nothing ever leaves. So a 200 GB iCloud plan can mean close to 200 GB on your Mac.</p>
        {{PATHS}}
        <p>Finder shows it as <strong>iCloud Drive</strong> in the sidebar; the files behind it are in your Library, in a folder macOS guards. Storage settings gives it its own category, <strong>iCloud Drive</strong>. If you've turned on <strong>Desktop &amp; Documents Folders</strong> for iCloud Drive, those two folders follow the same rules.</p>
        <p>Three things decide how much of it sits on your disk:</p>
        <ul>
          <li><strong>Optimize Mac Storage is off.</strong> Then macOS keeps a full copy of everything in iCloud Drive on your Mac.</li>
          <li><strong>Files you've opened.</strong> Opening a cloud-only file downloads it, and it stays until macOS or you remove the download.</li>
          <li><strong>Keep Downloaded.</strong> On recent versions, Finder can pin a file or folder so it's never removed. Pinned items always use their full size.</li>
        </ul>

        <h2 style="margin-top:56px">Optimize Mac Storage for iCloud Drive</h2>
        <ol class="steps">
          <li><b>Open iCloud settings.</b> Choose <strong>Apple menu › System Settings</strong>, click your name at the top of the sidebar, then click <strong>iCloud</strong>.</li>
          <li><b>Find iCloud Drive's options.</b> On recent versions, the switch is inside <strong>Drive</strong> (called iCloud Drive on some versions). On macOS 14, it's at the bottom of the iCloud pane.</li>
          <li><b>Turn on Optimize Mac Storage.</b> macOS then keeps recent files on your Mac and removes the downloads of older ones when space is needed. They stay in iCloud, and download again when you open them.</li>
        </ol>
        <p>Downloads macOS can remove this way count as purgeable, which is why Finder may show more space available than you expect. <a href="/purgeable-space-mac">Purgeable space</a> explains how that works.</p>

        <h2 style="margin-top:56px">How to remove iCloud Drive downloads now</h2>
        <p>Optimize Mac Storage waits until space runs low. To reclaim it today, open iCloud Drive in Finder, choose <strong>View › as List</strong>, and find big files or folders. Control-click one and choose <strong>Remove Download</strong>. The file stays in iCloud Drive with a cloud icon, and <strong>Download Now</strong> brings it back.</p>
        <div class="callout"><p><strong>Remove Download, not Move to Trash.</strong> Deleting a file in iCloud Drive deletes it from iCloud and every device. It goes to Recently Deleted in iCloud Drive first, so you can get it back for a while.</p></div>
        <p>Turning iCloud Drive off is the bluntest option. macOS asks whether to keep your files on this Mac or remove them from it; your files stay in iCloud Drive either way. Pick remove, and your Mac only has what you copy out first.</p>
        <p>Dropbox and Google Drive work much the same way: see <a href="/taking-up-space/dropbox">Dropbox taking up space</a>. Also worth a look: <a href="/taking-up-space/messages">Messages attachments</a> and <a href="/taking-up-space/iphone-backups">iPhone backups</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast never downloads iCloud files to measure them, and never removes them. Without Full Disk Access, it skips the iCloud Drive folder. With it, the folder is measured by what&#39;s really on disk, so cloud-only files count as nothing and downloaded ones count in full. Downloads macOS can remove on its own are part of the <strong>Purgeable space</strong> row in its System Data window, which explains why Finder counts them as free. It&#39;s free.</p>
    """,
    "mockup": "system-data",
    "related": ["/taking-up-space/dropbox", "/purgeable-space-mac", "/taking-up-space/messages"],
    "faqs": [
        ("Why is iCloud Drive taking up space on my Mac?", "Because iCloud Drive keeps downloaded copies of files on your Mac. Without Optimize Mac Storage, it keeps every file. Files you open from iCloud download too, and stay until their download is removed."),
        ("How do I stop iCloud Drive from using storage on my Mac?", "Turn on Optimize Mac Storage in System Settings › [your name] › iCloud, so macOS removes downloads of older files when space is low. To reclaim space now, Control-click big files in iCloud Drive and choose Remove Download."),
        ("What does Remove Download do in iCloud Drive?", "It deletes the copy on your Mac and keeps the file in iCloud Drive, shown with a cloud icon. Download Now, or opening the file, brings it back."),
        ("Does deleting files from iCloud Drive free up space on my Mac?", "Yes, but it also deletes them from iCloud and your other devices. Use Remove Download to free space on your Mac and keep the files."),
        ("What does Optimize Mac Storage do?", "When it's on, macOS keeps recent iCloud Drive files on your Mac and removes downloads of older ones when space is needed. The files stay in iCloud and download again when you open them."),
    ],
}

# ------------------------------------------------------------------ Developer files
# Tiny volume each, so one page: "npkill" 80, "coresimulator" 30, "xcrun simctl delete unavailable" 20, "delete node_modules" 20,
# "docker.raw" 20, "deriveddata" 10, "ios devicesupport" 10. Xcode and Docker sizes are the /clear-cache pages' measurements;
# node_modules is find + du over ~/code on the same Mac (266 folders, du counted about 100 GB). npkill wasn't run here.
DEVELOPER_FILES = {
    "slug": "developer-files",
    "title": "Developer disk space on Mac: Xcode, node_modules, Docker",
    "description": "Where developer files take disk space on a Mac: DerivedData, CoreSimulator, iOS DeviceSupport, node_modules, and Docker.raw, with what each rebuilds.",
    "h1": "Developer files taking up space on Mac, <em>folder by folder.</em>",
    "lede": "On a developer's Mac, the biggest folders usually aren't documents. They're build output, simulators, dependencies, and container images. Here's where each lives, how big it got on one Mac, and the safe way to reclaim it.",
    "tldr": "Five folders do most of the damage: Xcode's <code>DerivedData</code>, simulators in <code>CoreSimulator</code>, <code>iOS DeviceSupport</code>, every project's <code>node_modules</code>, and Docker's <code>Docker.raw</code>. The first four rebuild or download again, so they're safe to remove. Docker's file isn't: prune it with <code>docker system prune</code> instead. On the Mac measured here, node_modules folders alone came to about 100 GB.",
    "card_title": "Developer files",
    "card_blurb": "DerivedData, CoreSimulator, node_modules, and Docker.raw.",
    "finds_title": "Disk Forecast and developer files",
    "paths": [
        ("Xcode build data", "~/Library/Developer/Xcode/DerivedData", "1.7 GB"),
        ("Device debug symbols", "~/Library/Developer/Xcode/iOS DeviceSupport", "4.3 GB"),
        ("Simulators and their apps", "~/Library/Developer/CoreSimulator/Devices", "10 GB, 22 simulators"),
        ("Simulator runtimes", "Managed by macOS; <code>xcrun simctl runtime list</code>", "15.7 GB"),
        ("JavaScript dependencies", "node_modules in every project", "About 100 GB, 266 folders"),
        ("Docker's disk image", "~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", "29 GB on disk"),
    ],
    "html": """
        <h2>How much space developer files take</h2>
        <p>Here's one developer Mac, measured in October 2026. The node_modules figure is what <code>du</code> counted across every project in one code folder:</p>
        {{PATHS}}
        <p>That's over 160 GB, and none of it is source code. Every row can be rebuilt or downloaded again. The question is only how long you'll wait when you need it back.</p>

        <h2 style="margin-top:56px">Xcode: DerivedData, CoreSimulator, and DeviceSupport</h2>
        <ul>
          <li><strong>DerivedData</strong> is build products and the index, one folder per project. Quit Xcode and move the folders inside it to the Trash; the next build is slower and indexing runs again.</li>
          <li><strong>CoreSimulator</strong> holds every simulator you've created, with the apps and data installed on it. Simulator runtimes, the bigger part, are managed by macOS and count toward System Data. To remove simulators whose runtime is gone, which can't run anyway:
<pre><code>xcrun simctl delete unavailable
xcrun simctl runtime list
xcrun simctl runtime delete &lt;identifier&gt;</code></pre></li>
          <li><strong>iOS DeviceSupport</strong> is debug symbols copied from each iPhone or iPad OS version you've plugged in, a few gigabytes each. Delete folders for versions you no longer debug on; Xcode copies them again when that device connects.</li>
        </ul>
        <p><a href="/clear-cache/xcode">How to clear Xcode cache</a> covers each folder, plus archives and Swift build folders.</p>

        <h2 style="margin-top:56px">How to delete node_modules</h2>
        <p>Each JavaScript project installs its own copy of every dependency, so a dozen projects means a dozen <code>node_modules</code> folders, often hundreds of megabytes each. To list yours by size:</p>
<pre><code>find ~ -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>
        <p>Or use npkill, a small tool that finds them for you. Run it from your code folder:</p>
<pre><code>cd ~/code
npx npkill</code></pre>
        <p>It lists every <code>node_modules</code> below that folder with its size. Move to one with the arrow keys and press Space to delete it. npkill deletes for good rather than moving to the Trash, so stick to projects you can reinstall. Delete <code>node_modules</code> in projects you haven't touched in a while; <code>npm install</code> brings it back from the lockfile. Package manager caches are a separate folder: see <a href="/clear-cache/npm">npm</a>, <a href="/clear-cache/yarn">Yarn</a>, and <a href="/clear-cache">every other tool</a>.</p>

        <h2 style="margin-top:56px">Docker.raw</h2>
        <p>Docker Desktop keeps every image, container, volume, and build cache inside one file, <code>Docker.raw</code>. It's a sparse file, so Finder can show it at hundreds of gigabytes while <code>du</code> shows what it really uses: on the Mac above, Finder said 926 GB and <code>du</code> said 29 GB.</p>
        <p>Never move it to the Trash: that deletes every image, container, and volume at once. Reclaim space with Docker's own command, which asks first:</p>
<pre><code>docker system df
docker system prune</code></pre>
        <p><a href="/clear-cache/docker">Docker system prune, explained</a> covers every flag, including the one that removes volumes.</p>
        <p>More folders that grow on their own: <a href="/taking-up-space/icloud-drive">iCloud Drive</a>, <a href="/taking-up-space/dropbox">Dropbox</a>, and <a href="/taking-up-space">the rest of the list</a>. For local AI models, which can outgrow all of these, see <a href="/ai-models">delete local AI models</a>.</p>
    """,
    "finds": """
          <p>Disk Forecast lists every folder on this page. Under <strong>Cleanup › Safe to clear</strong>: <strong>Xcode DerivedData</strong>, <strong>Xcode device support</strong>, <strong>Simulator caches</strong>, and <strong>Build folders in old projects</strong>, which is <code>node_modules</code> and other build folders in projects you haven&#39;t changed in 30 days. Recent projects&#39; folders are under <strong>Worth a look</strong>, unchecked, next to the <strong>Docker disk image</strong>, which it never moves to the Trash. Its System Data window deletes simulator runtimes with <code>xcrun simctl</code> and prunes Docker with <code>docker system prune -f</code>, each after you confirm. Everything else goes to the Trash. It&#39;s free.</p>
    """,
    "mockup": "cleanup",
    "related": ["/clear-cache/xcode", "/clear-cache/docker", "/clear-cache/npm"],
    "faqs": [
        ("Is it safe to delete DerivedData?", "Yes. It holds Xcode's build products and index, and Xcode rebuilds both on the next build. Quit Xcode first, then move the folders inside ~/Library/Developer/Xcode/DerivedData to the Trash."),
        ("Can I delete the CoreSimulator folder?", "Not the whole folder. Delete simulators you don't use from Xcode's Devices and Simulators window, or run xcrun simctl delete unavailable. Delete runtimes with xcrun simctl runtime delete or in Xcode › Settings › Components."),
        ("Can I delete iOS DeviceSupport folders?", "Yes. They're debug symbols for each device OS version you've connected. Xcode copies them again the next time a device running that version connects."),
        ("What is npkill?", "A command-line tool that finds every node_modules folder below the current folder, lists them by size, and deletes the ones you pick. Run it with npx npkill. It deletes for good, not to the Trash."),
        ("Can I delete Docker.raw on a Mac?", "Don't. It holds every Docker image, container, and volume. Run docker system prune to remove what nothing is using, or use Clean / Purge data in Docker Desktop to start over."),
    ],
}

FOLDER_PAGES = [SLEEPIMAGE, IPHONE_BACKUPS, MESSAGES, DROPBOX, ICLOUD_DRIVE, DEVELOPER_FILES]

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
