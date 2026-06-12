// TypeScript port of the respondeR engine. It mirrors the R functions exactly
// so the browser app reproduces the package results (see the parity test).

import { pnorm, dnorm, qnorm, pt, pchisq, qt } from "./special";

export type Direction = "higher" | "lower";
export type Dist = "normal" | "lognormal" | "t";
export type SeMethod = "binomial" | "delta";
export type Pooling = "fixed" | "random";
export type CiType = "wald" | "logit";
export type CiMethod = "wald" | "hksj";
export type Control = "matched" | "median";
export type Method = "individual" | "weighted" | "unweighted" | "median" | "smd";

// Smallest distance a responder probability may sit from 0 or 1 when it feeds a
// log, a logit or an inverse-variance weight. Mirrors RESP_EPS in the R package.
const RESP_EPS = 1e-10;
const clampP = (p: number) => Math.min(Math.max(p, RESP_EPS), 1 - RESP_EPS);

// True when every experimental and control responder probability is pinned to
// the same bound (all ~0 or all ~1). The risk difference is then well defined
// but the ratio measures are clamp artifacts and are reported as null.
const isBoundary = (pe: number[], pc: number[]) =>
  (pe.every((p) => p <= RESP_EPS) && pc.every((p) => p <= RESP_EPS)) ||
  (pe.every((p) => p >= 1 - RESP_EPS) && pc.every((p) => p >= 1 - RESP_EPS));

export interface StudyRow {
  study: string;
  change_e: number;
  sd_e: number;
  n_e: number;
  change_c: number;
  sd_c: number;
  n_c: number;
}

export interface AnalysisOptions {
  mid: number;
  direction?: Direction;
  method?: Method[];
  se_method?: SeMethod;
  pooling?: Pooling;
  control?: Control;
  dist?: Dist;
  df?: number | null;
  mid_sd?: number;
  ci_type?: CiType;
  ci_method?: CiMethod;
  conf_level?: number;
}

export interface ResultRow {
  method: Method;
  pooling: Pooling | null;
  k: number;
  p_e: number | null;
  p_c: number | null;
  rd: number;
  rd_lb: number | null;
  rd_ub: number | null;
  rr: number | null;
  rr_lb: number | null;
  rr_ub: number | null;
  or: number | null;
  or_lb: number | null;
  or_ub: number | null;
  nnt: number | null;
  nnt_lb: number | null;
  nnt_ub: number | null;
  var_rd: number | null;
  tau2: number | null;
  i2: number | null;
  q: number | null;
  q_p: number | null;
  pi_lb: number | null;
  pi_ub: number | null;
}

const qlogis = (p: number) => Math.log(p / (1 - p));
const plogis = (x: number) => 1 / (1 + Math.exp(-x));
const median = (v: number[]) => {
  const s = [...v].sort((a, b) => a - b);
  const n = s.length;
  return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2;
};
const sum = (v: number[]) => v.reduce((a, b) => a + b, 0);
const mean = (v: number[]) => sum(v) / v.length;

export function responderP(
  mu: number,
  sigma: number,
  mid: number,
  direction: Direction,
  dist: Dist = "normal",
  df: number | null = null,
): number {
  let pGt: number;
  if (dist === "normal") {
    pGt = pnorm((mu - mid) / sigma);
  } else if (dist === "t") {
    if (df == null || df <= 2) throw new Error("df must be greater than 2 for the t distribution.");
    const scale = sigma * Math.sqrt((df - 2) / df);
    pGt = pt((mu - mid) / scale, df);
  } else {
    if (mu <= 0) throw new Error("The lognormal model requires positive mean change.");
    if (mid <= 0) throw new Error("The lognormal model requires mid > 0.");
    const sdlog = Math.sqrt(Math.log(1 + (sigma / mu) ** 2));
    const meanlog = Math.log(mu) - (sdlog * sdlog) / 2;
    pGt = 1 - pnorm((Math.log(mid) - meanlog) / sdlog);
  }
  return direction === "higher" ? pGt : 1 - pGt;
}

interface ProbInfo {
  p: number;
  dpDmu: number;
  dpDsigma: number;
  dpDmid: number;
  varSampling: number;
}

function probInfo(
  mu: number,
  sigma: number,
  n: number,
  mid: number,
  direction: Direction,
  dist: Dist,
  df: number | null,
): ProbInfo {
  const p = responderP(mu, sigma, mid, direction, dist, df);
  let dpDmu: number, dpDsigma: number, dpDmid: number;
  if (dist === "normal") {
    const sgn = direction === "higher" ? 1 : -1;
    const g = (sgn * (mu - mid)) / sigma;
    const phi = dnorm(g);
    dpDmu = (phi * sgn) / sigma;
    dpDsigma = (-phi * sgn * (mu - mid)) / (sigma * sigma);
    dpDmid = -dpDmu;
  } else {
    const f = (m: number, s: number, md: number) => responderP(m, s, md, direction, dist, df);
    const hm = 1e-5 * Math.max(1, Math.abs(mu));
    const hs = 1e-5 * Math.max(1, Math.abs(sigma));
    const hd = 1e-5 * Math.max(1, Math.abs(mid));
    dpDmu = (f(mu + hm, sigma, mid) - f(mu - hm, sigma, mid)) / (2 * hm);
    dpDsigma = (f(mu, sigma + hs, mid) - f(mu, sigma - hs, mid)) / (2 * hs);
    dpDmid = (f(mu, sigma, mid + hd) - f(mu, sigma, mid - hd)) / (2 * hd);
  }
  const varSampling = dpDmu * dpDmu * (sigma * sigma) / n + dpDsigma * dpDsigma * (sigma * sigma) / (2 * (n - 1));
  return { p, dpDmu, dpDsigma, dpDmid, varSampling };
}

function pooledSd(sd: number[], n: number[]): number {
  const dfv = n.map((x) => x - 1);
  return Math.sqrt(sum(dfv.map((d, i) => d * sd[i] * sd[i])) / sum(dfv));
}

interface Pool {
  k: number;
  fixed: number;
  fixedVar: number;
  est: number;
  var: number;
  tau2: number;
  i2: number | null;
  q: number | null;
  qP: number | null;
  ciLb: number;
  ciUb: number;
  se: number; // the SE actually used for the random-effects interval
  piLb: number | null;
  piUb: number | null;
}

function dlPool(y: number[], v: number[], conf: number, ciMethod: CiMethod = "wald"): Pool {
  const k = y.length;
  const wf = v.map((x) => 1 / x);
  const sw = sum(wf);
  const fixed = sum(y.map((e, i) => wf[i] * e)) / sw;
  const fixedVar = 1 / sw;
  const z = qnorm((1 + conf) / 2);
  if (k < 2) {
    return {
      k, fixed, fixedVar, est: fixed, var: fixedVar, tau2: 0, i2: null, q: null, qP: null,
      ciLb: fixed - z * Math.sqrt(fixedVar), ciUb: fixed + z * Math.sqrt(fixedVar),
      se: Math.sqrt(fixedVar), piLb: null, piUb: null,
    };
  }
  const q = sum(y.map((e, i) => wf[i] * (e - fixed) ** 2));
  const cc = sw - sum(wf.map((w) => w * w)) / sw;
  const tau2 = cc > 0 ? Math.max(0, (q - (k - 1)) / cc) : 0;
  const i2 = q > 0 ? Math.max(0, (q - (k - 1)) / q) : 0;
  const wr = v.map((x) => 1 / (x + tau2));
  const swr = sum(wr);
  const est = sum(y.map((e, i) => wr[i] * e)) / swr;
  const variance = 1 / swr;

  let se: number;
  let crit: number;
  if (ciMethod === "hksj") {
    // Hartung-Knapp-Sidik-Jonkman: a t-interval with a quadratic-form variance.
    const qHk = sum(y.map((e, i) => wr[i] * (e - est) ** 2)) / ((k - 1) * swr);
    se = Math.sqrt(qHk);
    crit = qt((1 + conf) / 2, k - 1);
  } else {
    se = Math.sqrt(variance);
    crit = z;
  }

  let piLb: number | null = null;
  let piUb: number | null = null;
  if (k > 2) {
    const tcrit = qt((1 + conf) / 2, k - 2);
    piLb = est - tcrit * Math.sqrt(tau2 + variance);
    piUb = est + tcrit * Math.sqrt(tau2 + variance);
  }
  return {
    k, fixed, fixedVar, est, var: variance, tau2, i2, q, qP: 1 - pchisq(q, k - 1),
    ciLb: est - crit * se, ciUb: est + crit * se, se, piLb, piUb,
  };
}

function pickPool(p: Pool, pooling: Pooling, conf: number) {
  if (pooling === "random") return { est: p.est, var: p.var, lb: p.ciLb, ub: p.ciUb };
  const z = qnorm((1 + conf) / 2);
  const se = Math.sqrt(p.fixedVar);
  return { est: p.fixed, var: p.fixedVar, lb: p.fixed - z * se, ub: p.fixed + z * se };
}

function armSummary(change: number[], sd: number[], n: number[], method: "median" | "unweighted" | "weighted") {
  if (method === "median") return { mu: median(change), sigma: median(sd), varMu: NaN };
  if (method === "unweighted") return { mu: mean(change), sigma: mean(sd), varMu: NaN };
  const w = n.map((nn, i) => nn / (sd[i] * sd[i]));
  return { mu: sum(change.map((c, i) => w[i] * c)) / sum(w), sigma: pooledSd(sd, n), varMu: 1 / sum(w) };
}

function propCi(p: number, varP: number, conf: number, ciType: CiType): [number, number] {
  const z = qnorm((1 + conf) / 2);
  if (ciType === "wald") return [p - z * Math.sqrt(varP), p + z * Math.sqrt(varP)];
  const g = qlogis(p);
  const varG = varP / (p * (1 - p)) ** 2;
  return [plogis(g - z * Math.sqrt(varG)), plogis(g + z * Math.sqrt(varG))];
}

function moverRd(pe: number, pc: number, ciE: [number, number], ciC: [number, number]): [number, number] {
  const rd = pe - pc;
  return [
    rd - Math.sqrt((pe - ciE[0]) ** 2 + (ciC[1] - pc) ** 2),
    rd + Math.sqrt((ciE[1] - pe) ** 2 + (pc - ciC[0]) ** 2),
  ];
}

function nntFromRd(rd: number, rdLb: number | null, rdUb: number | null) {
  const nnt = rd === 0 ? Infinity : 1 / rd;
  if (rdLb == null || rdUb == null) return { nnt, nntLb: null, nntUb: null };
  if (rdLb > 0 || rdUb < 0) {
    const b = [1 / rdLb, 1 / rdUb].sort((a, c) => a - c);
    return { nnt, nntLb: b[0], nntUb: b[1] };
  }
  return { nnt, nntLb: null, nntUb: null };
}

interface Measures {
  rd: number; rd_lb: number | null; rd_ub: number | null;
  rr: number | null; rr_lb: number | null; rr_ub: number | null;
  or: number | null; or_lb: number | null; or_ub: number | null;
  nnt: number | null; nnt_lb: number | null; nnt_ub: number | null;
}

function effectMeasures(
  pe: number, pc: number, varPe: number, varPc: number, conf: number, ciType: CiType,
  extraRd = 0, extraLnrr = 0, extraLnor = 0,
): Measures {
  const z = qnorm((1 + conf) / 2);
  const rd = pe - pc;
  const pec = clampP(pe), pcc = clampP(pc);
  const rr = pec / pcc;
  const or = (pec / (1 - pec)) / (pcc / (1 - pcc));
  const hasVar = !Number.isNaN(varPe) && !Number.isNaN(varPc);
  let rdLb: number | null = null, rdUb: number | null = null;
  let rrLb: number | null = null, rrUb: number | null = null;
  let orLb: number | null = null, orUb: number | null = null;
  if (hasVar) {
    if (ciType === "logit" && extraRd === 0) {
      const ciE = propCi(pec, varPe, conf, "logit");
      const ciC = propCi(pcc, varPc, conf, "logit");
      [rdLb, rdUb] = moverRd(pe, pc, ciE, ciC);
    } else {
      const seRd = Math.sqrt(varPe + varPc + extraRd);
      rdLb = rd - z * seRd;
      rdUb = rd + z * seRd;
    }
    const seLnrr = Math.sqrt(varPe / pec ** 2 + varPc / pcc ** 2 + extraLnrr);
    rrLb = rr * Math.exp(-z * seLnrr);
    rrUb = rr * Math.exp(z * seLnrr);
    const seLnor = Math.sqrt(varPe / (pec * (1 - pec)) ** 2 + varPc / (pcc * (1 - pcc)) ** 2 + extraLnor);
    orLb = or * Math.exp(-z * seLnor);
    orUb = or * Math.exp(z * seLnor);
  }
  const nnt = nntFromRd(rd, rdLb, rdUb);
  if (isBoundary([pe], [pc])) {
    return {
      rd, rd_lb: rdLb, rd_ub: rdUb,
      rr: null, rr_lb: null, rr_ub: null, or: null, or_lb: null, or_ub: null,
      nnt: null, nnt_lb: null, nnt_ub: null,
    };
  }
  return {
    rd, rd_lb: rdLb, rd_ub: rdUb, rr, rr_lb: rrLb, rr_ub: rrUb, or, or_lb: orLb, or_ub: orUb,
    nnt: nnt.nnt, nnt_lb: nnt.nntLb, nnt_ub: nnt.nntUb,
  };
}

export interface PerStudyRow {
  study: string;
  p_e: number;
  p_c: number;
  rd: number;
  se: number;
  ci_lb: number;
  ci_ub: number;
}

interface PerStudyStat extends PerStudyRow {
  var_pe: number; var_pc: number; var_rd: number;
  lnrr: number; var_lnrr: number; lnor: number; var_lnor: number;
}

function perStudyStats(
  data: StudyRow[], mid: number, direction: Direction, seMethod: SeMethod,
  dist: Dist, df: number | null, midSd: number,
): PerStudyStat[] {
  const midVar = midSd * midSd;
  return data.map((d) => {
    const ie = probInfo(d.change_e, d.sd_e, d.n_e, mid, direction, dist, df);
    const ic = probInfo(d.change_c, d.sd_c, d.n_c, mid, direction, dist, df);
    const pe = ie.p, pc = ic.p;
    // Clamp the probabilities that feed logs, logits and weights; report pe, pc
    // and the risk difference unclamped.
    const pec = clampP(pe), pcc = clampP(pc);
    const varPe = seMethod === "binomial" ? (pec * (1 - pec)) / d.n_e : ie.varSampling;
    const varPc = seMethod === "binomial" ? (pcc * (1 - pcc)) / d.n_c : ic.varSampling;
    const dRd = (ie.dpDmid - ic.dpDmid) ** 2 * midVar;
    const dLnrr = (ie.dpDmid / pec - ic.dpDmid / pcc) ** 2 * midVar;
    const dLnor = (ie.dpDmid / (pec * (1 - pec)) - ic.dpDmid / (pcc * (1 - pcc))) ** 2 * midVar;
    return {
      study: d.study, p_e: pe, p_c: pc, var_pe: varPe, var_pc: varPc,
      rd: pe - pc, var_rd: varPe + varPc + dRd, se: 0, ci_lb: 0, ci_ub: 0,
      lnrr: Math.log(pec / pcc), var_lnrr: varPe / pec ** 2 + varPc / pcc ** 2 + dLnrr,
      lnor: qlogis(pec) - qlogis(pcc),
      var_lnor: varPe / (pec * (1 - pec)) ** 2 + varPc / (pcc * (1 - pcc)) ** 2 + dLnor,
    };
  });
}

const opt = <T>(v: T | undefined, d: T): T => (v === undefined ? d : v);

export function responderRdIndividual(data: StudyRow[], o: AnalysisOptions): PerStudyRow[] {
  const direction = opt(o.direction, "higher");
  const seMethod = opt(o.se_method, "binomial");
  const conf = opt(o.conf_level, 0.95);
  const ps = perStudyStats(data, o.mid, direction, seMethod, opt(o.dist, "normal"), opt(o.df, null), opt(o.mid_sd, 0));
  const z = qnorm((1 + conf) / 2);
  return ps.map((s) => {
    const se = Math.sqrt(s.var_rd);
    return { study: s.study, p_e: s.p_e, p_c: s.p_c, rd: s.rd, se, ci_lb: s.rd - z * se, ci_ub: s.rd + z * se };
  });
}

export function responderAnalysis(data: StudyRow[], o: AnalysisOptions): ResultRow[] {
  const direction = opt(o.direction, "higher");
  const seMethod = opt(o.se_method, "binomial");
  const pooling = opt(o.pooling, "fixed");
  const dist = opt(o.dist, "normal");
  const df = opt(o.df, null);
  const midSd = opt(o.mid_sd, 0);
  const ciType = opt(o.ci_type, "wald");
  const ciMethod = opt(o.ci_method, "wald");
  const conf = opt(o.conf_level, 0.95);
  const control = opt(o.control, "matched");
  const methodOpt = opt(o.method, ["individual", "weighted", "unweighted", "median"] as Method[]);
  const methods = Array.isArray(methodOpt) ? methodOpt : [methodOpt];
  const k = data.length;
  const z = qnorm((1 + conf) / 2);

  if (dist === "lognormal" && (data.some((d) => d.change_e <= 0 || d.change_c <= 0) || o.mid <= 0)) {
    throw new Error(
      "The lognormal model requires every study-arm mean change and the MID to be positive.",
    );
  }

  const change_e = data.map((d) => d.change_e);
  const sd_e = data.map((d) => d.sd_e);
  const n_e = data.map((d) => d.n_e);
  const change_c = data.map((d) => d.change_c);
  const sd_c = data.map((d) => d.sd_c);
  const n_c = data.map((d) => d.n_c);

  const row = (
    method: Method, pool: Pooling | null, pE: number | null, pC: number | null,
    m: Measures, het: Pool | null, varRd: number | null,
  ): ResultRow => ({
    method, pooling: pool, k, p_e: pE, p_c: pC,
    rd: m.rd, rd_lb: m.rd_lb, rd_ub: m.rd_ub, rr: m.rr, rr_lb: m.rr_lb, rr_ub: m.rr_ub,
    or: m.or, or_lb: m.or_lb, or_ub: m.or_ub, nnt: m.nnt, nnt_lb: m.nnt_lb, nnt_ub: m.nnt_ub,
    var_rd: varRd,
    tau2: het ? het.tau2 : null, i2: het ? het.i2 : null, q: het ? het.q : null,
    q_p: het ? het.qP : null, pi_lb: het ? het.piLb : null, pi_ub: het ? het.piUb : null,
  });

  const summaryMethod = (mth: "median" | "unweighted" | "weighted"): ResultRow => {
    // Baseline-risk rule: "matched" pools the control arm like the experimental
    // arm; "median" always takes the control from the median control arm (the
    // Sofi-Mahmudi 2024 baseline), which has no variance model so it yields
    // point estimates only.
    const controlM = control === "median" ? "median" : mth;
    const ae = armSummary(change_e, sd_e, n_e, mth);
    const ac = armSummary(change_c, sd_c, n_c, controlM);
    const ie = probInfo(ae.mu, ae.sigma, 2, o.mid, direction, dist, df);
    const ic = probInfo(ac.mu, ac.sigma, 2, o.mid, direction, dist, df);
    const pe = ie.p, pc = ic.p;
    if (mth === "weighted") {
      // Full delta variance: propagate uncertainty in both the pooled mean and
      // the pooled SD. Var(sigma) ~= sigma^2 / (2 * df_total).
      const varSigmaE = (ae.sigma * ae.sigma) / (2 * sum(n_e.map((n) => n - 1)));
      const varSigmaC = (ac.sigma * ac.sigma) / (2 * sum(n_c.map((n) => n - 1)));
      const varPe = ie.dpDmu ** 2 * ae.varMu + ie.dpDsigma ** 2 * varSigmaE;
      const varPc = ic.dpDmu ** 2 * ac.varMu + ic.dpDsigma ** 2 * varSigmaC;
      const pec = clampP(pe), pcc = clampP(pc);
      const mv = midSd * midSd;
      const extraRd = (ie.dpDmid - ic.dpDmid) ** 2 * mv;
      const extraLnrr = (ie.dpDmid / pec - ic.dpDmid / pcc) ** 2 * mv;
      const extraLnor = (ie.dpDmid / (pec * (1 - pec)) - ic.dpDmid / (pcc * (1 - pcc))) ** 2 * mv;
      const m = effectMeasures(pe, pc, varPe, varPc, conf, ciType, extraRd, extraLnrr, extraLnor);
      return row(mth, null, pe, pc, m, null, varPe + varPc + extraRd);
    }
    const m = effectMeasures(pe, pc, NaN, NaN, conf, ciType);
    return row(mth, null, pe, pc, m, null, null);
  };

  const individualMethod = (): ResultRow => {
    const ps = perStudyStats(data, o.mid, direction, seMethod, dist, df, midSd);
    const pRd = dlPool(ps.map((s) => s.rd), ps.map((s) => s.var_rd), conf, ciMethod);
    const pRr = dlPool(ps.map((s) => s.lnrr), ps.map((s) => s.var_lnrr), conf, ciMethod);
    const pOr = dlPool(ps.map((s) => s.lnor), ps.map((s) => s.var_lnor), conf, ciMethod);
    const sRd = pickPool(pRd, pooling, conf);
    const sRr = pickPool(pRr, pooling, conf);
    const sOr = pickPool(pOr, pooling, conf);
    const nnt = nntFromRd(sRd.est, sRd.lb, sRd.ub);
    const bdry = isBoundary(ps.map((s) => s.p_e), ps.map((s) => s.p_c));
    const m: Measures = {
      rd: sRd.est, rd_lb: sRd.lb, rd_ub: sRd.ub,
      rr: bdry ? null : Math.exp(sRr.est), rr_lb: bdry ? null : Math.exp(sRr.lb), rr_ub: bdry ? null : Math.exp(sRr.ub),
      or: bdry ? null : Math.exp(sOr.est), or_lb: bdry ? null : Math.exp(sOr.lb), or_ub: bdry ? null : Math.exp(sOr.ub),
      nnt: bdry ? null : nnt.nnt, nnt_lb: bdry ? null : nnt.nntLb, nnt_ub: bdry ? null : nnt.nntUb,
    };
    const het = pooling === "fixed" ? { ...pRd, piLb: null, piUb: null } : pRd;
    return row("individual", pooling, null, null, m, het, sRd.var);
  };

  const smdMethod = (): ResultRow => {
    const sgn = direction === "higher" ? 1 : -1;
    const sPool = data.map((d) => Math.sqrt(((d.n_e - 1) * d.sd_e ** 2 + (d.n_c - 1) * d.sd_c ** 2) / (d.n_e + d.n_c - 2)));
    const dd = data.map((d, i) => (sgn * (d.change_e - d.change_c)) / sPool[i]);
    const jc = data.map((d) => 1 - 3 / (4 * (d.n_e + d.n_c) - 9));
    const g = dd.map((x, i) => jc[i] * x);
    const varG = dd.map((x, i) => jc[i] ** 2 * ((data[i].n_e + data[i].n_c) / (data[i].n_e * data[i].n_c) + (x * x) / (2 * (data[i].n_e + data[i].n_c))));
    const pG = dlPool(g, varG, conf, ciMethod);
    const sG = pickPool(pG, pooling, conf);
    const cf = Math.PI / Math.sqrt(3);
    const lnOr = cf * sG.est;
    const seLnor = cf * Math.sqrt(sG.var);
    const or = Math.exp(lnOr);
    const orLb = Math.exp(lnOr - z * seLnor);
    const orUb = Math.exp(lnOr + z * seLnor);
    const ac = armSummary(change_c, sd_c, n_c, "weighted");
    const pc = responderP(ac.mu, ac.sigma, o.mid, direction, dist, df);
    const peFromOr = ( orr: number) => (orr * pc) / (1 - pc + orr * pc);
    const pe = peFromOr(or);
    const rd = pe - pc;
    const nnt = nntFromRd(rd, peFromOr(orLb) - pc, peFromOr(orUb) - pc);
    const bdry = isBoundary([pe], [pc]);
    const m: Measures = {
      rd, rd_lb: peFromOr(orLb) - pc, rd_ub: peFromOr(orUb) - pc,
      rr: bdry ? null : pe / pc, rr_lb: bdry ? null : peFromOr(orLb) / pc, rr_ub: bdry ? null : peFromOr(orUb) / pc,
      or: bdry ? null : or, or_lb: bdry ? null : orLb, or_ub: bdry ? null : orUb,
      nnt: bdry ? null : nnt.nnt, nnt_lb: bdry ? null : nnt.nntLb, nnt_ub: bdry ? null : nnt.nntUb,
    };
    const het = pooling === "fixed" ? { ...pG, piLb: null, piUb: null } : pG;
    return row("smd", pooling, pe, pc, m, het, null);
  };

  return methods.map((mth) => {
    if (mth === "individual") return individualMethod();
    if (mth === "smd") return smdMethod();
    return summaryMethod(mth as "median" | "unweighted" | "weighted");
  });
}

export interface ClesResult {
  studies: { study: string; delta: number; cles: number; cles_lb: number; cles_ub: number }[];
  cles: number; cles_lb: number; cles_ub: number;
  delta: number; se_delta: number;
  tau2: number; i2: number | null; q: number | null; q_p: number | null;
  pi_lb: number | null; pi_ub: number | null;
  pooling: Pooling; k: number;
}

export interface PerStudyCalc {
  study: string;
  p_e: number;
  p_c: number;
  rd: number;
  se: number;
  weight: number;
}

export interface CalcTrace {
  se_method: SeMethod;
  pooling: Pooling;
  ci_type: CiType;
  conf_level: number;
  perStudy: PerStudyCalc[];
  sumWeight: number;
  fixed: { rd: number; se: number; lb: number; ub: number };
  random: {
    rd: number; se: number; lb: number; ub: number;
    tau2: number; i2: number | null; q: number | null; q_p: number | null;
    pi_lb: number | null; pi_ub: number | null;
  };
  weighted: {
    mu_e: number; sigma_e: number; var_mu_e: number; p_e: number; var_pe: number;
    mu_c: number; sigma_c: number; var_mu_c: number; p_c: number; var_pc: number;
    rd: number; se: number;
  };
}

/**
 * Expose the intermediate quantities behind the individual and weighted
 * methods, so the app can show the calculation step by step (and so the effect
 * of the se_method, pooling and interval toggles is visible).
 */
export function traceCalculations(data: StudyRow[], o: AnalysisOptions): CalcTrace {
  const direction = opt(o.direction, "higher");
  const seMethod = opt(o.se_method, "binomial");
  const pooling = opt(o.pooling, "fixed");
  const dist = opt(o.dist, "normal");
  const df = opt(o.df, null);
  const midSd = opt(o.mid_sd, 0);
  const ciType = opt(o.ci_type, "wald");
  const ciMethod = opt(o.ci_method, "wald");
  const conf = opt(o.conf_level, 0.95);
  const z = qnorm((1 + conf) / 2);

  const ps = perStudyStats(data, o.mid, direction, seMethod, dist, df, midSd);
  const perStudy: PerStudyCalc[] = ps.map((s) => ({
    study: s.study, p_e: s.p_e, p_c: s.p_c, rd: s.rd,
    se: Math.sqrt(s.var_rd), weight: 1 / s.var_rd,
  }));
  const sumWeight = sum(perStudy.map((s) => s.weight));
  const pool = dlPool(ps.map((s) => s.rd), ps.map((s) => s.var_rd), conf, ciMethod);

  const seF = Math.sqrt(pool.fixedVar);

  const nE = data.map((d) => d.n_e);
  const nC = data.map((d) => d.n_c);
  const ae = armSummary(data.map((d) => d.change_e), data.map((d) => d.sd_e), nE, "weighted");
  const ac = armSummary(data.map((d) => d.change_c), data.map((d) => d.sd_c), nC, "weighted");
  const ie = probInfo(ae.mu, ae.sigma, 2, o.mid, direction, dist, df);
  const ic = probInfo(ac.mu, ac.sigma, 2, o.mid, direction, dist, df);
  // Same full weighted variance as the result path: mean + pooled-SD + MID terms.
  const varSigmaE = (ae.sigma * ae.sigma) / (2 * sum(nE.map((n) => n - 1)));
  const varSigmaC = (ac.sigma * ac.sigma) / (2 * sum(nC.map((n) => n - 1)));
  const varPe = ie.dpDmu ** 2 * ae.varMu + ie.dpDsigma ** 2 * varSigmaE;
  const varPc = ic.dpDmu ** 2 * ac.varMu + ic.dpDsigma ** 2 * varSigmaC;
  const extraRd = (ie.dpDmid - ic.dpDmid) ** 2 * midSd * midSd;

  return {
    se_method: seMethod, pooling, ci_type: ciType, conf_level: conf,
    perStudy, sumWeight,
    fixed: { rd: pool.fixed, se: seF, lb: pool.fixed - z * seF, ub: pool.fixed + z * seF },
    random: {
      rd: pool.est, se: pool.se, lb: pool.ciLb, ub: pool.ciUb,
      tau2: pool.tau2, i2: pool.i2, q: pool.q, q_p: pool.qP,
      pi_lb: pool.piLb, pi_ub: pool.piUb,
    },
    weighted: {
      mu_e: ae.mu, sigma_e: ae.sigma, var_mu_e: ae.varMu, p_e: ie.p, var_pe: varPe,
      mu_c: ac.mu, sigma_c: ac.sigma, var_mu_c: ac.varMu, p_c: ic.p, var_pc: varPc,
      rd: ie.p - ic.p, se: Math.sqrt(varPe + varPc + extraRd),
    },
  };
}

export function responderCles(
  data: StudyRow[],
  o: { direction?: Direction; pooling?: Pooling; ci_method?: CiMethod; conf_level?: number } = {},
): ClesResult {
  const direction = opt(o.direction, "higher");
  const pooling = opt(o.pooling, "fixed");
  const ciMethod = opt(o.ci_method, "wald");
  const conf = opt(o.conf_level, 0.95);
  const sgn = direction === "higher" ? 1 : -1;
  const z = qnorm((1 + conf) / 2);
  const delta = data.map((d) => (sgn * (d.change_e - d.change_c)) / Math.sqrt(d.sd_e ** 2 + d.sd_c ** 2));
  const varDelta = data.map((d) => {
    const s2 = d.sd_e ** 2 + d.sd_c ** 2;
    const dnum = sgn * (d.change_e - d.change_c);
    return (d.sd_e ** 2 / d.n_e + d.sd_c ** 2 / d.n_c) / s2 +
      (dnum * dnum) * (d.sd_e ** 4 / (2 * (d.n_e - 1)) + d.sd_c ** 4 / (2 * (d.n_c - 1))) / s2 ** 3;
  });
  const studies = data.map((d, i) => ({
    study: d.study, delta: delta[i], cles: pnorm(delta[i]),
    cles_lb: pnorm(delta[i] - z * Math.sqrt(varDelta[i])),
    cles_ub: pnorm(delta[i] + z * Math.sqrt(varDelta[i])),
  }));
  const pool = dlPool(delta, varDelta, conf, ciMethod);
  const sD = pickPool(pool, pooling, conf);
  return {
    studies, cles: pnorm(sD.est), cles_lb: pnorm(sD.lb), cles_ub: pnorm(sD.ub),
    delta: sD.est, se_delta: Math.sqrt(sD.var),
    tau2: pool.tau2, i2: pool.i2, q: pool.q, q_p: pool.qP,
    pi_lb: pooling === "random" && pool.piLb != null ? pnorm(pool.piLb) : null,
    pi_ub: pooling === "random" && pool.piUb != null ? pnorm(pool.piUb) : null,
    pooling, k: data.length,
  };
}
