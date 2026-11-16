# Link preview video

Remotion source for `images/og.mp4` (the `og:video` iMessage and Discord autoplay) and `images/og-video.png` (the `og:image` still, frame 225 of the 6-second, 60 fps loop). Needs Node and ffmpeg.

```sh
cd site/_og && npm install && npm run render
```

`npm run studio` opens a live preview. `OgVideo.tsx` is the shared Brushed shell (brushed aluminium, brand, pilot-light badge, Barlow Semi Condensed headline, a black mount on the right) and takes its text and accent as props in `Root.tsx`; `ForecastCard.tsx` is the Disk Forecast animation on the mount. The loop ends on its first frame, so keep the first and last frames identical when changing the timing.

This folder is in `.vercelignore`, so none of it is deployed.
