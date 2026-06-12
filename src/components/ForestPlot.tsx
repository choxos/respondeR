import type { PerStudyRow } from "../lib/engine";

interface Props {
  studies: PerStudyRow[];
  pooled?: { rd: number; lb: number | null; ub: number | null } | null;
}

/** A compact SVG forest plot of per-study responder risk differences (in %). */
export default function ForestPlot({ studies, pooled }: Props) {
  const rows = [
    ...studies.map((s) => ({ label: s.study, rd: s.rd * 100, lb: s.ci_lb * 100, ub: s.ci_ub * 100, pooled: false })),
    ...(pooled
      ? [{ label: "Pooled", rd: pooled.rd * 100, lb: (pooled.lb ?? pooled.rd) * 100, ub: (pooled.ub ?? pooled.rd) * 100, pooled: true }]
      : []),
  ];
  if (rows.length === 0) return null;

  const W = 520;
  const rowH = 38;
  const padL = 120;
  const padR = 24;
  const padT = 28;
  const H = padT + rows.length * rowH + 28;

  const lo = Math.min(0, ...rows.map((r) => r.lb));
  const hi = Math.max(0, ...rows.map((r) => r.ub));
  const span = hi - lo || 1;
  const x = (v: number) => padL + ((v - lo) / span) * (W - padL - padR);

  const ticks = niceTicks(lo, hi, 5);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="Forest plot of per-study risk differences">
      {/* axis */}
      <line x1={padL} y1={H - 24} x2={W - padR} y2={H - 24} stroke="#cbd5e1" />
      {ticks.map((t) => (
        <g key={t}>
          <line x1={x(t)} y1={padT - 8} x2={x(t)} y2={H - 24} stroke={t === 0 ? "#94a3b8" : "#eef2f7"} strokeDasharray={t === 0 ? "4 3" : undefined} />
          <text x={x(t)} y={H - 8} textAnchor="middle" className="fill-slate-500" fontSize="11">{t}</text>
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
            <text x={padL - 10} y={y + 4} textAnchor="end" fontSize="12" className="fill-slate-700" fontWeight={r.pooled ? 600 : 400}>
              {r.label}
            </text>
            <line x1={x(r.lb)} y1={y} x2={x(r.ub)} y2={y} stroke={color} strokeWidth={2} />
            <line x1={x(r.lb)} y1={y - 4} x2={x(r.lb)} y2={y + 4} stroke={color} strokeWidth={2} />
            <line x1={x(r.ub)} y1={y - 4} x2={x(r.ub)} y2={y + 4} stroke={color} strokeWidth={2} />
            {r.pooled ? (
              <polygon
                points={`${x(r.rd)},${y - 7} ${x(r.ub)},${y} ${x(r.rd)},${y + 7} ${x(r.lb)},${y}`}
                fill={color}
              />
            ) : (
              <rect x={x(r.rd) - 5} y={y - 5} width={10} height={10} fill={color} />
            )}
          </g>
        );
      })}
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
