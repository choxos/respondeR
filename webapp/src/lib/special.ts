// High-accuracy special functions, ported to match R's stats functions closely
// enough for numerical parity (better than 1e-9 on the ranges used here).

const SQRT2PI = 2.5066282746310002;

/** Standard normal density. */
export function dnorm(x: number, mean = 0, sd = 1): number {
  const z = (x - mean) / sd;
  return Math.exp(-0.5 * z * z) / (sd * SQRT2PI);
}

/**
 * Standard normal CDF (Graeme West, 2009), accurate to ~1e-15.
 */
export function pnorm(x: number, mean = 0, sd = 1): number {
  const z = (x - mean) / sd;
  const az = Math.abs(z);
  let c: number;
  if (az > 37) {
    c = 0;
  } else {
    const e = Math.exp(-(az * az) / 2);
    if (az < 7.07106781186547) {
      let b = 3.52624965998911e-2 * az + 0.700383064443688;
      b = b * az + 6.37396220353165;
      b = b * az + 33.912866078383;
      b = b * az + 112.079291497871;
      b = b * az + 221.213596169931;
      b = b * az + 220.206867912376;
      let d = 8.83883476483184e-2 * az + 1.75566716318264;
      d = d * az + 16.064177579207;
      d = d * az + 86.7807322029461;
      d = d * az + 296.564248779674;
      d = d * az + 637.333633378831;
      d = d * az + 793.826512519948;
      d = d * az + 440.413735824752;
      c = (e * b) / d;
    } else {
      let f = az + 0.65;
      f = az + 4 / f;
      f = az + 3 / f;
      f = az + 2 / f;
      f = az + 1 / f;
      c = e / (f * SQRT2PI);
    }
  }
  return z > 0 ? 1 - c : c;
}

/** Inverse standard normal CDF (Acklam) refined with one Halley step. */
export function qnorm(p: number, mean = 0, sd = 1): number {
  if (p <= 0) return -Infinity;
  if (p >= 1) return Infinity;
  const a = [
    -3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
    1.38357751867269e2, -3.066479806614716e1, 2.506628277459239,
  ];
  const b = [
    -5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
    6.680131188771972e1, -1.328068155288572e1,
  ];
  const c = [
    -7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838,
    -2.549732539343734, 4.374664141464968, 2.938163982698783,
  ];
  const d = [
    7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996,
    3.754408661907416,
  ];
  const pl = 0.02425;
  let x: number;
  if (p < pl) {
    const q = Math.sqrt(-2 * Math.log(p));
    x =
      (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  } else if (p <= 1 - pl) {
    const q = p - 0.5;
    const r = q * q;
    x =
      ((((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q) /
      (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
  } else {
    const q = Math.sqrt(-2 * Math.log(1 - p));
    x =
      -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
      ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  // One Halley refinement against the high-accuracy pnorm.
  const e = pnorm(x) - p;
  const u = e * SQRT2PI * Math.exp((x * x) / 2);
  x = x - u / (1 + (x * u) / 2);
  return mean + sd * x;
}

/** Log-gamma (Lanczos). */
export function lgamma(x: number): number {
  const g = [
    676.5203681218851, -1259.1392167224028, 771.32342877765313,
    -176.61502916214059, 12.507343278686905, -0.13857109526572012,
    9.9843695780195716e-6, 1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    return (
      Math.log(Math.PI / Math.sin(Math.PI * x)) - lgamma(1 - x)
    );
  }
  x -= 1;
  let a = 0.99999999999980993;
  const t = x + 7.5;
  for (let i = 0; i < g.length; i++) a += g[i] / (x + i + 1);
  return (
    0.5 * Math.log(2 * Math.PI) +
    (x + 0.5) * Math.log(t) -
    t +
    Math.log(a)
  );
}

/** Regularized incomplete beta I_x(a,b) via Lentz's continued fraction. */
function betacf(x: number, a: number, b: number): number {
  const EPS = 3e-14;
  const FPMIN = 1e-300;
  const qab = a + b;
  const qap = a + 1;
  const qam = a - 1;
  let c = 1;
  let d = 1 - (qab * x) / qap;
  if (Math.abs(d) < FPMIN) d = FPMIN;
  d = 1 / d;
  let h = d;
  for (let m = 1; m <= 300; m++) {
    const m2 = 2 * m;
    let aa = (m * (b - m) * x) / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    c = 1 + aa / c;
    if (Math.abs(c) < FPMIN) c = FPMIN;
    d = 1 / d;
    h *= d * c;
    aa = (-(a + m) * (qab + m) * x) / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    c = 1 + aa / c;
    if (Math.abs(c) < FPMIN) c = FPMIN;
    d = 1 / d;
    const del = d * c;
    h *= del;
    if (Math.abs(del - 1) < EPS) break;
  }
  return h;
}

export function ibeta(x: number, a: number, b: number): number {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  const lbeta = lgamma(a) + lgamma(b) - lgamma(a + b);
  const front = Math.exp(a * Math.log(x) + b * Math.log(1 - x) - lbeta);
  if (x < (a + 1) / (a + b + 2)) {
    return (front * betacf(x, a, b)) / a;
  }
  return 1 - (front * betacf(1 - x, b, a)) / b;
}

/** Student-t CDF. */
export function pt(t: number, df: number): number {
  const x = df / (df + t * t);
  const ib = 0.5 * ibeta(x, df / 2, 0.5);
  return t > 0 ? 1 - ib : ib;
}

/** Student-t quantile (bisection on pt). */
export function qt(p: number, df: number): number {
  if (p <= 0) return -Infinity;
  if (p >= 1) return Infinity;
  let lo = -1000;
  let hi = 1000;
  for (let i = 0; i < 200; i++) {
    const mid = (lo + hi) / 2;
    if (pt(mid, df) < p) lo = mid;
    else hi = mid;
  }
  return (lo + hi) / 2;
}

/** Lower regularized incomplete gamma P(a,x). */
function gammap(a: number, x: number): number {
  if (x <= 0) return 0;
  if (x < a + 1) {
    let ap = a;
    let sum = 1 / a;
    let del = sum;
    for (let n = 0; n < 300; n++) {
      ap += 1;
      del *= x / ap;
      sum += del;
      if (Math.abs(del) < Math.abs(sum) * 1e-15) break;
    }
    return sum * Math.exp(-x + a * Math.log(x) - lgamma(a));
  }
  // Continued fraction for the upper tail Q, then P = 1 - Q.
  const FPMIN = 1e-300;
  let b = x + 1 - a;
  let c = 1 / FPMIN;
  let d = 1 / b;
  let h = d;
  for (let i = 1; i <= 300; i++) {
    const an = -i * (i - a);
    b += 2;
    d = an * d + b;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    c = b + an / c;
    if (Math.abs(c) < FPMIN) c = FPMIN;
    d = 1 / d;
    const del = d * c;
    h *= del;
    if (Math.abs(del - 1) < 1e-15) break;
  }
  const q = Math.exp(-x + a * Math.log(x) - lgamma(a)) * h;
  return 1 - q;
}

/** Chi-square CDF (df degrees of freedom). */
export function pchisq(x: number, df: number): number {
  return gammap(df / 2, x / 2);
}
