import { useState } from "react";
import type { PerStudyRow } from "../lib/engine";

interface Props {
  studies: PerStudyRow[];
  pooled?: { rd: number; lb: number | null; ub: number | null } | null;
}

interface Hover {
  x: number;
  y: number;
  text: string;
}

/** Interactive SVG forest plot of per-study responder risk differences (in %). */
export default function ForestPlot({ studies, pooled }: Props) {
  const [hover, setHover] = useState<Hover | null>(null);

  const rows = [
    ...studies.map((s) => ({ label: s.study, rd: s.rd * 100, lb: s.ci_lb * 100, ub: s.ci_ub * 100, pooled: false })),
    ...(pooled
      ? [{ label: "Pooled", rd: pooled.rd * 100, lb: (pooled.lb ?? pooled.rd) * 100, ub: (pooled.ub ?? pooled.rd) * 100, pooled: true }]
      : []),
  ];
  if (rows.length === 0) return null;

  const W = 520;
  const rowH = 40;
  const padL = 120;
  const padR = 28;
  const padT = 30;
  const H = padT + rows.length * rowH + 30;

  const lo = Math.min(0, ...rows.map((r) => r.lb));
  const hi = Math.max(0, ...rows.map((r) => r.ub));
  const span = hi - lo || 1;
  const x = (v: number) => padL + ((v - lo) / span) * (W - padL - padR);
  const ticks = niceTicks(lo, hi, 5);
  const fmt = (v: number) => `${v.toFixed(1)}%`;
  const show = (vx: number, vy: number, text: string) => setHover({ x: vx, y: vy - 14, text });

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full select-none" role="img"
      aria-label="Forest plot of per-study risk differences" onMouseLeave={() => setHover(null)}>
      <line x1={padL} y1={H - 26} x2={W - padR} y2={H - 26} stroke="#cbd5e1" />
      {ticks.map((t) => (
        <g key={t}>
          <line x1={x(t)} y1={padT - 8} x2={x(t)} y2={H - 26}
            stroke={t === 0 ? "#94a3b8" : "#eef2f7"} strokeDasharray={t === 0 ? "4 3" : undefined} />
          <text x={x(t)} y={H - 10} textAnchor="middle" className="fill-slate-500" fontSize="11">{t}</text>
        </g>
      ))}
      <text x={(padL + W - padR) / 2} y={14} textAnchor="middle" className="fill-slate-400" fontSize="11">
        Risk difference (%)
      </text>

      {rows.map((r, i) => {
        const y = padT + i * rowH + rowH / 2;
        const color = r.pooled ? "#2D4BD8" : "#1A1A2E";
        return (
          <g key={r.label}>
            <text x={padL - 10} y={y + 4} textAnchor="end" fontSize="12"
              className="fill-slate-700" fontWeight={r.pooled ? 600 : 400}>{r.label}</text>
            <line x1={x(r.lb)} y1={y} x2={x(r.ub)} y2={y} stroke={color} strokeWidth={2} />
            {/* CI caps with hover */}
            {([["lb", r.lb], ["ub", r.ub]] as const).map(([k, v]) => (
              <line key={k} x1={x(v)} y1={y - 6} x2={x(v)} y2={y + 6} stroke={color} strokeWidth={3}
                className="cursor-pointer" onMouseEnter={() => show(x(v), y, fmt(v))}>
                <title>{fmt(v)}</title>
              </line>
            ))}
            {/* point estimate with hover */}
            {r.pooled ? (
              <polygon points={`${x(r.rd)},${y - 8} ${x(r.ub)},${y} ${x(r.rd)},${y + 8} ${x(r.lb)},${y}`}
                fill={color} className="cursor-pointer"
                onMouseEnter={() => show(x(r.rd), y, `${fmt(r.rd)} (${fmt(r.lb)} to ${fmt(r.ub)})`)}>
                <title>{`${fmt(r.rd)} (${fmt(r.lb)} to ${fmt(r.ub)})`}</title>
              </polygon>
            ) : (
              <rect x={x(r.rd) - 6} y={y - 6} width={12} height={12} fill={color} className="cursor-pointer"
                onMouseEnter={() => show(x(r.rd), y, `${fmt(r.rd)} (${fmt(r.lb)} to ${fmt(r.ub)})`)}>
                <title>{`${fmt(r.rd)} (${fmt(r.lb)} to ${fmt(r.ub)})`}</title>
              </rect>
            )}
          </g>
        );
      })}

      {hover && (
        <g pointerEvents="none">
          <rect x={hover.x - hover.text.length * 3.4 - 6} y={hover.y - 13} width={hover.text.length * 6.8 + 12}
            height={20} rx={4} fill="#1A1A2E" />
          <text x={hover.x} y={hover.y + 1} textAnchor="middle" fontSize="11" className="fill-white">{hover.text}</text>
        </g>
      )}
    </svg>
  );
}

function niceTicks(lo: number, hi: number, n: number): number[] {
  const raw = (hi - lo) / n;
  const mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const step = [1, 2, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? mag;
  const start = Math.ceil(lo / step) * step;
  const out: number[] = [];
  for (let t = start; t <= hi + 1e-9; t += step) out.push(Math.round(t * 100) / 100);
  return out;
}
