import { describe, it, expect } from "vitest";
import { responderAnalysis, traceCalculations } from "../engine";
import { sampleData } from "../sample";

describe("Calculations trace matches the result path", () => {
  it("weighted SE^2 equals the weighted var_rd (mid_sd = 0)", () => {
    const res = responderAnalysis(sampleData, { mid: 1, method: ["weighted"] });
    const trace = traceCalculations(sampleData, { mid: 1 });
    expect(trace.weighted.se ** 2).toBeCloseTo(res[0].var_rd!, 12);
  });

  it("weighted SE^2 equals the weighted var_rd (mid_sd > 0)", () => {
    const res = responderAnalysis(sampleData, { mid: 1, method: ["weighted"], mid_sd: 0.3 });
    const trace = traceCalculations(sampleData, { mid: 1, mid_sd: 0.3 });
    expect(trace.weighted.se ** 2).toBeCloseTo(res[0].var_rd!, 12);
  });

  it("random trace SE reflects the active interval (HKSJ vs Wald differ)", () => {
    const wald = traceCalculations(sampleData, { mid: 1, ci_method: "wald" });
    const hksj = traceCalculations(sampleData, { mid: 1, ci_method: "hksj" });
    expect(hksj.random.se).not.toBeCloseTo(wald.random.se, 6);
  });
});
