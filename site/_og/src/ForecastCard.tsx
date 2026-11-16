import {Easing, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {DISPLAY, INK, INK_2, MUTED, STOP} from './OgVideo';

// Disk Forecast's free-space card, in Brushed materials (matte card, black label strip, graphite tape, ink lines;
// colour only in the forecast reading and the red full mark): disk use climbs and free space ticks down to 142 GB, the forecast line reaches
// full, the verdict lands, then the line drains back to where it starts, so the loop has no seam.
const W = 372;
const H = 150;
const NOW = 0.345;
const OUT = 0.816;
const DISK = 494;
const FLOOR = 200;
const START = 265;
const TODAY = 352;
const y = (gb: number) => H - 4 - ((gb - FLOOR) / (DISK - FLOOR)) * (H - 14);
// A steady climb with a little day-to-day wobble that is zero at both ends, so the head lands exactly on today.
const used = (x: number) => {
  const r = x / NOW;
  return START + (TODAY - START) * r + 5 * Math.sin(3 * Math.PI * r) + 2.5 * Math.sin(8 * Math.PI * r);
};

const STANDARD = Easing.bezier(0.4, 0, 0.2, 1);
const IN_OUT = Easing.bezier(0.65, 0, 0.35, 1);
const OUT_EASE = Easing.bezier(0, 0, 0.2, 1);

const GRAPHITE = '#2c2c2d';

export const ForecastCard = ({accent}: {accent: string}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const t = frame / fps;
  const ease = (input: number[], output: number[], easing: (n: number) => number) =>
    interpolate(t, input, output, {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing});

  // 0–2.2s climb · 1.9–2.8s forecast draws · 2.7–3.0s verdict in · hold to 4.5s · 4.5–4.8s verdict out · 4.6–5.8s drain
  const climb = ease([0, 2.2], [0, 1], STANDARD);
  const drain = ease([4.6, 5.8], [0, 1], IN_OUT);
  const grow = climb * (1 - drain);
  const proj = ease([1.9, 2.8], [0, 1], IN_OUT);
  // Text swaps overlap only briefly, so the two lines never sit on top of each other at half opacity.
  const verdictIn = ease([2.8, 3.0], [0, 1], OUT_EASE);
  const shown = verdictIn * ease([4.5, 4.68], [1, 0], STANDARD);
  const watching = 1 - ease([2.7, 2.88], [0, 1], STANDARD) + ease([4.68, 4.88], [0, 1], STANDARD);
  const fadeOut = ease([4.5, 4.8], [1, 0], STANDARD);
  const dot = spring({frame: frame - Math.round(2.6 * fps), fps, config: {damping: 14, stiffness: 160}}) * fadeOut;

  const xNow = interpolate(grow, [0, 1], [NOW * 0.08, NOW]);
  const gb = used(xNow);
  let d = `M0 ${y(used(0)).toFixed(2)}`;
  for (let px = 1; px < xNow * W; px++) d += ` L${px} ${y(used(px / W)).toFixed(2)}`;
  d += ` L${(xNow * W).toFixed(2)} ${y(gb).toFixed(2)}`;
  const area = `${d} V${H - 4} H0 Z`;
  const projX = NOW + (OUT - NOW) * proj;
  const projGb = TODAY + (DISK - TODAY) * proj;

  return (
    <div
      style={{position: 'relative', width: '100%', height: '100%', boxSizing: 'border-box', padding: '24px 18px', borderRadius: 10, background: '#eeeeed',
        boxShadow: '0 18px 40px rgba(0,0,0,.32), 0 0 0 .5px rgba(0,0,0,.35)', fontVariantNumeric: 'tabular-nums'}}
    >
      <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start'}}>
        <div>
          <div style={{display: 'inline-block', fontFamily: DISPLAY, fontSize: 15, fontWeight: 600, letterSpacing: '0.26em', textTransform: 'uppercase',
            background: '#1b1b1b', color: '#d8d9da', padding: '6px 10px', borderRadius: 2}}>Macintosh HD</div>
          <div style={{fontSize: 22, color: INK_2, marginTop: 8}}>Free of {DISK} GB</div>
        </div>
        <div style={{fontFamily: DISPLAY, fontSize: 62, fontWeight: 600, color: INK, lineHeight: 1}}>
          {Math.round(DISK - gb)}
          <span style={{fontSize: 30, fontWeight: 300, marginLeft: 4}}>GB</span>
        </div>
      </div>
      <div style={{position: 'relative', height: 8, borderRadius: 1, background: '#d6d7d7', margin: '18px 0 20px', overflow: 'hidden'}}>
        <div style={{position: 'absolute', inset: 0, width: `${(gb / DISK) * 100}%`, background: GRAPHITE}} />
      </div>
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{display: 'block', overflow: 'visible'}}>
        <line x1={0} y1={y(DISK)} x2={W} y2={y(DISK)} stroke="#66686a" strokeWidth={1.5} strokeDasharray="4 4" opacity={0.8} />
        <line x1={0} y1={H - 4} x2={W} y2={H - 4} stroke="rgba(0,0,0,0.12)" strokeWidth={2} />
        <path d={area} fill={GRAPHITE} opacity={0.08} />
        <path d={d} fill="none" stroke={GRAPHITE} strokeWidth={3} strokeLinejoin="round" />
        <g opacity={fadeOut}>
          {proj > 0.001 && (
            <path d={`M${NOW * W} ${y(TODAY)} L${projX * W} ${y(projGb)}`} fill="none" stroke={accent} strokeWidth={3} strokeDasharray="8 6" />
          )}
          <line x1={OUT * W} y1={y(DISK)} x2={OUT * W} y2={H - 4} stroke={STOP} strokeWidth={1.5} strokeDasharray="4 5" opacity={verdictIn * 0.7} />
          {dot > 0.01 && <circle cx={OUT * W} cy={y(DISK)} r={8 * dot} fill={STOP} stroke="#eeeeed" strokeWidth={3 * Math.min(1, dot)} />}
        </g>
        <circle cx={xNow * W} cy={y(gb)} r={6.5} fill={GRAPHITE} stroke="#eeeeed" strokeWidth={3} />
      </svg>
      <div style={{position: 'relative', height: 28, marginTop: 8, fontFamily: DISPLAY, fontSize: 17, fontWeight: 600, letterSpacing: '0.16em', textTransform: 'uppercase', color: MUTED, whiteSpace: 'nowrap'}}>
        <span style={{position: 'absolute', left: 0}}>Sep 5</span>
        <span style={{position: 'absolute', right: 0}}>Dec 1</span>
      </div>
      <div style={{position: 'absolute', marginTop: 18, fontFamily: DISPLAY, fontSize: 32, fontWeight: 300, color: MUTED, opacity: watching}}>
        Measuring your pace…
      </div>
      <div style={{marginTop: 18, opacity: shown, transform: `translateY(${(1 - verdictIn) * 8}px)`}}>
        <div style={{fontFamily: DISPLAY, fontSize: 42, fontWeight: 600, color: INK, lineHeight: 1.05}}>Full in ~41 days</div>
        <div style={{fontSize: 22, color: INK_2, marginTop: 4}}>Nov 15 · using 3.5 GB a day</div>
      </div>
    </div>
  );
};
