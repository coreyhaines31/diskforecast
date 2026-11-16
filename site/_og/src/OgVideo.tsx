import {loadFont as loadBarlow} from '@remotion/google-fonts/Barlow';
import {loadFont as loadSemiCondensed} from '@remotion/google-fonts/BarlowSemiCondensed';
import {AbsoluteFill, Img, staticFile} from 'remotion';
import {ForecastCard} from './ForecastCard';

loadBarlow('normal', {weights: ['400', '500', '600'], subsets: ['latin']});
loadSemiCondensed('normal', {weights: ['300', '600', '700'], subsets: ['latin']});

export type OgVideoProps = {
  name: string;
  icon: string;
  badge: string;
  headline: string;
  headlineAccent: string;
  sub: string;
  // The app's pilot light: the only place its colour appears.
  accent: string;
};

export const DISPLAY = '"Barlow Semi Condensed", "Helvetica Neue", system-ui, sans-serif';
export const BODY = 'Barlow, "Helvetica Neue", system-ui, sans-serif';
export const INK = '#161616';
export const INK_2 = '#3d3f41';
export const MUTED = '#5b5d5e';
export const STOP = '#e0452b';

// Brushed aluminium, as on the site's hero (brushed.css --bx-brush).
const BRUSH = [
  'repeating-linear-gradient(0deg, rgba(255,255,255,.22) 0 1px, rgba(0,0,0,.035) 1px 2px, transparent 2px 3px)',
  'repeating-linear-gradient(0deg, rgba(0,0,0,.035) 0 1px, transparent 1px 7px)',
  'linear-gradient(100deg, rgba(255,255,255,0) 18%, rgba(255,255,255,.5) 40%, rgba(255,255,255,0) 64%)',
  'linear-gradient(180deg, #e7e8e9, #c3c5c7)',
].join(', ');

// The family shell: a brushed plate, brand and headline on the left. The right slot is per site.
export const OgVideo = (props: OgVideoProps) => (
  <AbsoluteFill style={{background: BRUSH, color: INK, fontFamily: BODY, WebkitFontSmoothing: 'antialiased'}}>
    <div style={{position: 'absolute', left: 72, top: 70, width: 560, height: 490, display: 'flex', flexDirection: 'column', justifyContent: 'space-between'}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 18, fontFamily: DISPLAY, fontSize: 38, fontWeight: 700}}>
        <Img src={staticFile(props.icon)} style={{width: 80, height: 80}} />
        {props.name}
      </div>
      <div>
        <div
          style={{display: 'inline-flex', alignItems: 'center', gap: 12, fontFamily: DISPLAY, fontWeight: 600, fontSize: 17, letterSpacing: '0.26em',
            textTransform: 'uppercase', background: '#1b1b1b', color: '#d8d9da', padding: '9px 16px 9px 13px', borderRadius: 2}}
        >
          <i style={{width: 10, height: 10, borderRadius: '50%', background: props.accent, boxShadow: `0 0 8px ${props.accent}`}} />
          {props.badge}
        </div>
        <div style={{marginTop: 22, fontFamily: DISPLAY, fontSize: 84, lineHeight: 0.97, fontWeight: 600}}>
          {props.headline} <span style={{fontWeight: 300, whiteSpace: 'nowrap'}}>{props.headlineAccent}</span>
        </div>
      </div>
      <div style={{fontSize: 26, color: INK_2}}>{props.sub}</div>
    </div>
    <div
      style={{position: 'absolute', left: 676, top: 70, width: 452, height: 490, boxSizing: 'border-box', padding: 22, borderRadius: 14, background: '#1b1b1b',
        backgroundImage: 'radial-gradient(rgba(255,255,255,.045) 1px, transparent 1.3px)', backgroundSize: '5px 5px', boxShadow: '0 0 0 1px rgba(0,0,0,.5)'}}
    >
      {[{left: 9, top: 9}, {right: 9, top: 9}, {left: 9, bottom: 9}, {right: 9, bottom: 9}].map((p, i) => (
        <span key={i} style={{position: 'absolute', ...p, width: 10, height: 10, borderRadius: '50%', background: 'radial-gradient(circle at 40% 35%, #fff, #b9bbbd 45%, #77797b 80%)'}} />
      ))}
      <ForecastCard accent={props.accent} />
    </div>
  </AbsoluteFill>
);
