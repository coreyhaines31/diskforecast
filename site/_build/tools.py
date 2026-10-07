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

SECTIONS = []
for _hub, _tools in SECTIONS:
    for _t in _tools:
        _t["path"] = f"{_hub['path']}/{_t['slug']}"

# The hubs appear on /guides and in every footer, after the guides.
GUIDE_HUBS = [hub for hub, _ in SECTIONS]
