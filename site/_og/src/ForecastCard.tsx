import {Easing, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {INK, INK_2} from './OgVideo';

// Disk Forecast's free-space card: disk use climbs and free space ticks down to 142 GB, the forecast line reaches
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

export const ForecastCard = ({accentInk, accentFill, tint}: {accentInk: string; accentFill: string; tint: string}) => {
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
      style={{width: '100%', height: '100%', boxSizing: 'border-box', padding: '30px 32px', borderRadius: 30, background: 'rgba(251,251,253,0.9)',
        boxShadow: `0 0 0 1px rgba(0,0,0,0.06), 0 2px 6px rgba(0,0,0,0.05), 0 16px 36px rgba(${tint},0.12)`, fontVariantNumeric: 'tabular-nums'}}
    >
      <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start'}}>
        <div>
          <div style={{fontSize: 28, fontWeight: 600, letterSpacing: '-0.02em', color: INK}}>Macintosh HD</div>
          <div style={{fontSize: 22, color: INK_2, marginTop: 2}}>Free of {DISK} GB</div>
        </div>
        <div style={{fontSize: 54, fontWeight: 700, letterSpacing: '-0.04em', color: accentInk, lineHeight: 1}}>
          {Math.round(DISK - gb)}
          <span style={{fontSize: 28, letterSpacing: '-0.02em', marginLeft: 4}}>GB</span>
        </div>
      </div>
      <div style={{position: 'relative', height: 10, borderRadius: 5, background: 'rgba(0,0,0,0.08)', margin: '18px 0 20px', overflow: 'hidden'}}>
        <div style={{position: 'absolute', inset: 0, width: `${(gb / DISK) * 100}%`, borderRadius: 5, background: accentFill}} />
      </div>
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{display: 'block', overflow: 'visible'}}>
        <line x1={0} y1={y(DISK)} x2={W} y2={y(DISK)} stroke="#8e8e93" strokeWidth={2} strokeDasharray="3 5" opacity={0.6} />
        <line x1={0} y1={H - 4} x2={W} y2={H - 4} stroke="rgba(0,0,0,0.12)" strokeWidth={2} />
        <path d={area} fill={accentFill} opacity={0.14} />
        <path d={d} fill="none" stroke={accentFill} strokeWidth={4} strokeLinejoin="round" />
        <g opacity={fadeOut}>
          {proj > 0.001 && (
            <path d={`M${NOW * W} ${y(TODAY)} L${projX * W} ${y(projGb)}`} fill="none" stroke={accentFill} strokeWidth={4} strokeDasharray="7 8" />
          )}
          <line x1={OUT * W} y1={y(DISK)} x2={OUT * W} y2={H - 4} stroke={accentInk} strokeWidth={2} strokeDasharray="4 5" opacity={verdictIn * 0.7} />
          {dot > 0.01 && <circle cx={OUT * W} cy={y(DISK)} r={9 * dot} fill={accentInk} stroke="#fff" strokeWidth={3 * Math.min(1, dot)} />}
        </g>
        <circle cx={xNow * W} cy={y(gb)} r={7} fill={accentFill} stroke="#fff" strokeWidth={3} />
      </svg>
      <div style={{position: 'relative', height: 28, marginTop: 8, fontSize: 20, color: INK_2, whiteSpace: 'nowrap'}}>
        <span style={{position: 'absolute', left: 0}}>Sep 5</span>
        <span style={{position: 'absolute', right: 0}}>Dec 1</span>
      </div>
      <div style={{position: 'absolute', marginTop: 18, fontSize: 30, fontWeight: 600, letterSpacing: '-0.02em', color: '#8e8e93', opacity: watching}}>
        Measuring your pace…
      </div>
      <div style={{marginTop: 18, opacity: shown, transform: `translateY(${(1 - verdictIn) * 8}px)`}}>
        <div style={{fontSize: 38, fontWeight: 700, letterSpacing: '-0.03em', color: accentInk}}>Full in ~41 days</div>
        <div style={{fontSize: 22, color: INK_2, marginTop: 4}}>Nov 15 · using 3.5 GB a day</div>
      </div>
    </div>
  );
};
