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

FOLDER_PAGES = []

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
