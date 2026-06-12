import { describe, it, expect } from "vitest";
import { sampleData, vasPainData, validateData } from "../sample";
import { responderAnalysis } from "../engine";

describe("bundled datasets", () => {
  it("sampleData and vasPainData pass validation", () => {
    expect(() => validateData(sampleData as unknown as Record<string, unknown>[])).not.toThrow();
    expect(() => validateData(vasPainData as unknown as Record<string, unknown>[])).not.toThrow();
  });

  it("vasPainData matches the published totals", () => {
    expect(vasPainData).toHaveLength(20);
    expect(vasPainData.reduce((a, r) => a + r.n_e, 0)).toBe(671);
    expect(vasPainData.reduce((a, r) => a + r.n_c, 0)).toBe(654);
  });

  it("vasPainData runs with a lower-is-better MID", () => {
    const res = responderAnalysis(vasPainData, { mid: -1.5, direction: "lower", method: ["individual"] });
    expect(res[0].rd).toBeGreaterThan(0);
  });
});
