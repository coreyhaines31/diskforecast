import {Composition} from 'remotion';
import {OgVideo, type OgVideoProps} from './OgVideo';

// 6 s at 60 fps. Frame 225 (3.75 s) is the resting frame, rendered as the og:image still.
export const RemotionRoot = () => (
  <Composition
    id="OgVideo"
    component={OgVideo}
    durationInFrames={360}
    fps={60}
    width={1200}
    height={630}
    defaultProps={
      {
        name: 'Disk Forecast',
        icon: 'icon.svg',
        badge: 'Free for Mac',
        headline: 'Know before your Mac runs',
        headlineAccent: 'out of space.',
        sub: 'Free for macOS · diskforecast.com',
        accent: '#2f63d3',
      } satisfies OgVideoProps
    }
  />
);
