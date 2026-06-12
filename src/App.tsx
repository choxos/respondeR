import { useMemo, useRef, useState } from "react";
import {
  responderAnalysis,
  responderRdIndividual,
  responderCles,
  type StudyRow,
  type Method,
  type Direction,
  type Pooling,
  type CiType,
  type SeMethod,
  type Dist,
  type ResultRow,
} from "./lib/engine";
import { sampleData } from "./lib/sample";
import { parseFile, templateCsv, toCsv } from "./lib/parse";
import ForestPlot from "./components/ForestPlot";

const BASE = import.meta.env.BASE_URL;

const METHOD_LABELS: Record<Method, string> = {
  individual: "Individual",
  weighted: "Weighted mean",
  unweighted: "Unweighted mean",
  median: "Median",
  smd: "SMD (Cox)",
};

const fmtPct = (x: number | null) =>
  x == null || !Number.isFinite(x) ? "-" : (100 * x).toFixed(1);
const fmtRatio = (x: number | null) =>
  x == null || !Number.isFinite(x) ? "-" : x.toFixed(2);
const withCI = (
  p: number | null,
  lb: number | null,
  ub: number | null,
  f: (x: number | null) => string,
) => (lb == null || ub == null ? f(p) : `${f(p)} (${f(lb)} to ${f(ub)})`);

interface Options {
  mid: number;
  direction: Direction;
  methods: Method[];
  pooling: Pooling;
  ci_type: CiType;
  se_method: SeMethod;
  dist: Dist;
  df: number;
  mid_sd: number;
  conf_level: number;
}

const DEFAULT_OPTIONS: Options = {
  mid: 1,
  direction: "higher",
  methods: ["individual", "weighted", "unweighted", "median"],
  pooling: "fixed",
  ci_type: "wald",
  se_method: "binomial",
  dist: "normal",
  df: 10,
  mid_sd: 0,
  conf_level: 0.95,
};

function download(name: string, content: string, type = "text/csv") {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  a.click();
  URL.revokeObjectURL(url);
}

export default function App() {
  const [data, setData] = useState<StudyRow[]>(sampleData);
  const [dataLabel, setDataLabel] = useState("Example data");
  const [opt, setOpt] = useState<Options>(DEFAULT_OPTIONS);
  const [error, setError] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const set = <K extends keyof Options>(k: K, v: Options[K]) => setOpt((o) => ({ ...o, [k]: v }));

  const computed = useMemo(() => {
    try {
      const common = {
        mid: opt.mid,
        direction: opt.direction,
        se_method: opt.se_method,
        pooling: opt.pooling,
        dist: opt.dist,
        df: opt.dist === "t" ? opt.df : null,
        mid_sd: opt.mid_sd,
        ci_type: opt.ci_type,
        conf_level: opt.conf_level,
      };
      const results = responderAnalysis(data, { ...common, method: opt.methods });
      const perStudy = responderRdIndividual(data, common);
      const cles = responderCles(data, {
        direction: opt.direction,
        pooling: opt.pooling,
        conf_level: opt.conf_level,
      });
      return { results, perStudy, cles, err: null as string | null };
    } catch (e) {
      return { results: [], perStudy: [], cles: null, err: (e as Error).message };
    }
  }, [data, opt]);

  const liveError = error ?? computed.err;

  async function onFile(file: File) {
    try {
      setData(await parseFile(file));
      setDataLabel(file.name);
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  function loadSample() {
    setData(sampleData);
    setDataLabel("Example data");
    setError(null);
  }

  const pooledIndividual = computed.results.find((r) => r.method === "individual");

  return (
    <div className="min-h-screen">
      <Header />
      <main className="mx-auto grid max-w-7xl grid-cols-1 gap-6 px-4 py-6 lg:grid-cols-[340px_1fr]">
        <aside className="space-y-6 lg:sticky lg:top-6 lg:self-start">
          <DataCard
            dataLabel={dataLabel}
            nStudies={data.length}
            onSample={loadSample}
            onUpload={() => fileInput.current?.click()}
            onTemplate={() => download("responder_template.csv", templateCsv())}
          />
          <input
            ref={fileInput}
            type="file"
            accept=".csv,.xlsx,.xls"
            className="hidden"
            onChange={(e) => e.target.files?.[0] && onFile(e.target.files[0])}
          />
          <OptionsCard opt={opt} set={set} />
        </aside>

        <section className="space-y-6">
          {liveError && (
            <div className="card border-red-200 bg-red-50 p-4 text-sm text-red-700">{liveError}</div>
          )}

          <ResultsCard results={computed.results} conf={opt.conf_level}
            onDownload={() => download("responder_results.csv", toCsv(computed.results as unknown as Record<string, unknown>[]))} />

          <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
            <div className="card p-5">
              <h2 className="mb-1 text-sm font-semibold text-slate-700">Per-study risk differences</h2>
              <p className="mb-3 text-xs text-slate-500">Forest plot with the pooled (individual) estimate.</p>
              <ForestPlot
                studies={computed.perStudy}
                pooled={pooledIndividual ? { rd: pooledIndividual.rd, lb: pooledIndividual.rd_lb, ub: pooledIndividual.rd_ub } : null}
              />
            </div>
            {computed.cles && <ClesCard cles={computed.cles} conf={opt.conf_level} perStudy={computed.perStudy} />}
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
}

function Header() {
  return (
    <header className="border-b border-slate-200 bg-white">
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-3">
        <div className="flex items-center gap-3">
          <img src={`${BASE}logo.png`} alt="respondeR logo" className="h-11 w-11" />
          <div>
            <h1 className="text-lg font-bold text-brand-dark">respondeR</h1>
            <p className="text-xs text-slate-500">Responder analysis of continuous outcomes</p>
          </div>
        </div>
        <nav className="flex items-center gap-4 text-sm">
          <a className="text-slate-600 hover:text-brand" href="https://choxos.github.io/respondeR/" target="_blank" rel="noreferrer">Docs</a>
          <a className="text-slate-600 hover:text-brand" href="https://github.com/choxos/respondeR" target="_blank" rel="noreferrer">GitHub</a>
        </nav>
      </div>
    </header>
  );
}

function Footer() {
  return (
    <footer className="border-t border-slate-200 py-6 text-center text-xs text-slate-400">
      Runs entirely in your browser. Method: Thorlund et al. (2011), Research Synthesis Methods 2(3):188-203.
    </footer>
  );
}

function DataCard(props: {
  dataLabel: string;
  nStudies: number;
  onSample: () => void;
  onUpload: () => void;
  onTemplate: () => void;
}) {
  return (
    <div className="card p-5">
      <h2 className="text-sm font-semibold text-slate-700">Data</h2>
      <p className="mt-1 text-xs text-slate-500">
        {props.nStudies} {props.nStudies === 1 ? "study" : "studies"} ({props.dataLabel})
      </p>
      <div className="mt-3 flex flex-wrap gap-2">
        <button className="btn btn-primary" onClick={props.onUpload}>Upload CSV / Excel</button>
        <button className="btn btn-ghost" onClick={props.onSample}>Example</button>
        <button className="btn btn-ghost" onClick={props.onTemplate}>Template</button>
      </div>
      <p className="mt-3 text-xs text-slate-400">
        Columns: study, change_e, sd_e, n_e, change_c, sd_c, n_c
      </p>
    </div>
  );
}

function Segmented<T extends string>({ value, options, onChange }: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (v: T) => void;
}) {
  return (
    <div className="seg mt-1">
      {options.map((o) => (
        <button key={o.value} data-active={value === o.value} onClick={() => onChange(o.value)} type="button">
          {o.label}
        </button>
      ))}
    </div>
  );
}

function OptionsCard({ opt, set }: { opt: Options; set: <K extends keyof Options>(k: K, v: Options[K]) => void }) {
  const toggleMethod = (m: Method) => {
    const has = opt.methods.includes(m);
    const next = has ? opt.methods.filter((x) => x !== m) : [...opt.methods, m];
    if (next.length) set("methods", next);
  };
  return (
    <div className="card space-y-4 p-5">
      <h2 className="text-sm font-semibold text-slate-700">Settings</h2>

      <div>
        <label className="label">Minimal important difference (MID)</label>
        <input className="input" type="number" step="0.1" value={opt.mid}
          onChange={(e) => set("mid", Number(e.target.value))} />
      </div>

      <div>
        <label className="label">Direction of benefit</label>
        <Segmented value={opt.direction} onChange={(v) => set("direction", v)}
          options={[{ value: "higher", label: "Higher better" }, { value: "lower", label: "Lower better" }]} />
      </div>

      <div>
        <label className="label">Methods</label>
        <div className="mt-1 flex flex-wrap gap-1.5">
          {(Object.keys(METHOD_LABELS) as Method[]).map((m) => (
            <button key={m} type="button" onClick={() => toggleMethod(m)}
              data-active={opt.methods.includes(m)}
              className="seg-chip rounded-full border px-3 py-1 text-xs font-medium transition data-[active=true]:border-brand data-[active=true]:bg-brand data-[active=true]:text-white data-[active=false]:border-slate-300 data-[active=false]:text-slate-600">
              {METHOD_LABELS[m]}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="label">Effects model (individual / SMD)</label>
        <Segmented value={opt.pooling} onChange={(v) => set("pooling", v)}
          options={[{ value: "fixed", label: "Fixed" }, { value: "random", label: "Random" }]} />
      </div>

      <div>
        <label className="label">Interval type</label>
        <Segmented value={opt.ci_type} onChange={(v) => set("ci_type", v)}
          options={[{ value: "wald", label: "Wald" }, { value: "logit", label: "Logit" }]} />
      </div>

      <details className="text-sm">
        <summary className="cursor-pointer text-xs font-semibold uppercase tracking-wide text-slate-500">Advanced</summary>
        <div className="mt-3 space-y-4">
          <div>
            <label className="label">Individual SE</label>
            <Segmented value={opt.se_method} onChange={(v) => set("se_method", v)}
              options={[{ value: "binomial", label: "Binomial" }, { value: "delta", label: "Delta" }]} />
          </div>
          <div>
            <label className="label">Change-score distribution</label>
            <select className="input" value={opt.dist} onChange={(e) => set("dist", e.target.value as Dist)}>
              <option value="normal">Normal</option>
              <option value="t">Student-t</option>
              <option value="lognormal">Lognormal</option>
            </select>
          </div>
          {opt.dist === "t" && (
            <div>
              <label className="label">t degrees of freedom</label>
              <input className="input" type="number" min={3} value={opt.df}
                onChange={(e) => set("df", Number(e.target.value))} />
            </div>
          )}
          <div>
            <label className="label">SD of the MID (0 = exact)</label>
            <input className="input" type="number" min={0} step="0.1" value={opt.mid_sd}
              onChange={(e) => set("mid_sd", Number(e.target.value))} />
          </div>
          <div>
            <label className="label">Confidence level: {(100 * opt.conf_level).toFixed(0)}%</label>
            <input className="input" type="range" min={0.8} max={0.99} step={0.01} value={opt.conf_level}
              onChange={(e) => set("conf_level", Number(e.target.value))} />
          </div>
        </div>
      </details>
    </div>
  );
}

function ResultsCard({ results, conf, onDownload }: { results: ResultRow[]; conf: number; onDownload: () => void }) {
  const cl = (100 * conf).toFixed(0);
  return (
    <div className="card p-5">
      <div className="mb-3 flex items-center justify-between">
        <div>
          <h2 className="text-sm font-semibold text-slate-700">Pooled effect measures</h2>
          <p className="text-xs text-slate-500">Percentages for PE, PC and RD; ratios for RR and OR. {cl}% intervals.</p>
        </div>
        <button className="btn btn-ghost" onClick={onDownload} disabled={!results.length}>Download CSV</button>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-400">
              <th className="py-2 pr-3">Method</th>
              <th className="px-3">PE</th>
              <th className="px-3">PC</th>
              <th className="px-3">RD (%)</th>
              <th className="px-3">RR</th>
              <th className="px-3">OR</th>
              <th className="px-3">NNT</th>
              <th className="px-3">I&sup2;</th>
            </tr>
          </thead>
          <tbody>
            {results.map((r) => (
              <tr key={r.method} className="border-b border-slate-100 last:border-0">
                <td className="py-2.5 pr-3 font-medium text-slate-700">{METHOD_LABELS[r.method]}</td>
                <td className="px-3 tabular-nums">{fmtPct(r.p_e)}</td>
                <td className="px-3 tabular-nums">{fmtPct(r.p_c)}</td>
                <td className="px-3 tabular-nums">{withCI(r.rd, r.rd_lb, r.rd_ub, fmtPct)}</td>
                <td className="px-3 tabular-nums">{withCI(r.rr, r.rr_lb, r.rr_ub, fmtRatio)}</td>
                <td className="px-3 tabular-nums">{withCI(r.or, r.or_lb, r.or_ub, fmtRatio)}</td>
                <td className="px-3 tabular-nums">{fmtRatio(r.nnt)}</td>
                <td className="px-3 tabular-nums">{r.i2 == null ? "-" : `${(100 * r.i2).toFixed(0)}%`}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function ClesCard({ cles, conf, perStudy }: {
  cles: NonNullable<ReturnType<typeof responderCles>>;
  conf: number;
  perStudy: ReturnType<typeof responderRdIndividual>;
}) {
  return (
    <div className="card p-5">
      <h2 className="text-sm font-semibold text-slate-700">Common-language effect size</h2>
      <p className="text-xs text-slate-500">Probability a treated patient responds better than a control (no MID needed).</p>
      <div className="mt-3 flex items-baseline gap-3">
        <span className="text-3xl font-bold text-brand-dark">{(100 * cles.cles).toFixed(1)}%</span>
        <span className="text-xs text-slate-500">
          {(100 * conf).toFixed(0)}% CI {(100 * cles.cles_lb).toFixed(1)}% to {(100 * cles.cles_ub).toFixed(1)}%
          {cles.i2 != null ? ` · I² ${(100 * cles.i2).toFixed(0)}%` : ""}
        </span>
      </div>
      <table className="mt-4 w-full text-sm">
        <thead>
          <tr className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-400">
            <th className="py-2 pr-3">Study</th><th className="px-3">PE</th><th className="px-3">PC</th><th className="px-3">RD (%)</th>
          </tr>
        </thead>
        <tbody>
          {perStudy.map((s) => (
            <tr key={s.study} className="border-b border-slate-100 last:border-0">
              <td className="py-2 pr-3 text-slate-700">{s.study}</td>
              <td className="px-3 tabular-nums">{fmtPct(s.p_e)}</td>
              <td className="px-3 tabular-nums">{fmtPct(s.p_c)}</td>
              <td className="px-3 tabular-nums">{withCI(s.rd, s.ci_lb, s.ci_ub, fmtPct)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
