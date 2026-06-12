import { describe, it, expect } from "vitest";
import { pnorm, qnorm, pt } from "../special";
import { responderP, responderAnalysis, responderCles, responderRdIndividual } from "../engine";
import { sampleData } from "../sample";

describe("special functions", () => {
  it("pnorm matches known values", () => {
    expect(pnorm(0)).toBeCloseTo(0.5, 12);
    expect(pnorm(1.959963984540054)).toBeCloseTo(0.975, 9);
    expect(pnorm(-3)).toBeCloseTo(0.0013498980316301, 12);
  });
  it("qnorm inverts pnorm", () => {
    expect(qnorm(0.975)).toBeCloseTo(1.959963984540054, 7);
    expect(pnorm(qnorm(0.3))).toBeCloseTo(0.3, 10);
  });
  it("pt approaches the normal for large df", () => {
    expect(pt(1, 1e6)).toBeCloseTo(pnorm(1), 4);
  });
});

describe("responderP", () => {
  it("equals 0.5 at the mean and respects direction", () => {
    expect(responderP(1, 2, 1, "higher")).toBeCloseTo(0.5, 12);
    expect(responderP(3, 2, 1, "higher")).toBeCloseTo(pnorm(1), 12);
    expect(responderP(3, 2, 1, "lower")).toBeCloseTo(1 - pnorm(1), 12);
  });
});

describe("responder_analysis on the example data", () => {
  const res = responderAnalysis(sampleData, { mid: 1 });
  it("returns the four default methods", () => {
    expect(res.map((r) => r.method)).toEqual(["individual", "weighted", "unweighted", "median"]);
  });
  it("reproduces the individual risk difference", () => {
    const ind = res.find((r) => r.method === "individual")!;
    expect(ind.rd).toBeCloseTo(0.2554474533, 8);
    expect(ind.rr).toBeCloseTo(2.1488085019, 7);
    expect(ind.or).toBeCloseTo(3.1980979564, 7);
  });
  it("keeps proportions in [0, 1] and brackets the estimate", () => {
    const w = res.find((r) => r.method === "weighted")!;
    expect(w.p_e!).toBeGreaterThan(0);
    expect(w.p_e!).toBeLessThan(1);
    expect(w.rd_lb!).toBeLessThanOrEqual(w.rd);
    expect(w.rd).toBeLessThanOrEqual(w.rd_ub!);
  });
  it("negates the risk difference when direction flips", () => {
    const hi = responderAnalysis(sampleData, { mid: 1, method: ["individual"], direction: "higher" })[0];
    const lo = responderAnalysis(sampleData, { mid: 1, method: ["individual"], direction: "lower" })[0];
    expect(hi.rd).toBeCloseTo(-lo.rd, 10);
  });
});

describe("responder_cles", () => {
  it("reproduces the example CLES", () => {
    expect(responderCles(sampleData).cles).toBeCloseTo(0.6899040750, 8);
  });
});

describe("responder_rd_individual", () => {
  it("returns one row per study", () => {
    expect(responderRdIndividual(sampleData, { mid: 1 })).toHaveLength(3);
  });
});
