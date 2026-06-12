import { describe, it, expect } from "vitest";
import cases from "../__fixtures__/reference.json";
import {
  responderAnalysis,
  responderRdIndividual,
  responderCles,
  type AnalysisOptions,
} from "../engine";
import { sampleData } from "../sample";

// Normalize: R's NA and any non-finite value compare as null.
const norm = (x: unknown): number | null =>
  x == null || (typeof x === "number" && !Number.isFinite(x)) ? null : (x as number);

const TOL = 1e-6;

function expectClose(actual: unknown, expected: unknown, path: string) {
  const a = norm(actual);
  const e = norm(expected);
  if (e === null || a === null) {
    expect(a, `${path}: expected ${e}, got ${a}`).toBe(e);
    return;
  }
  expect(Math.abs(a - e), `${path}: |${a} - ${e}|`).toBeLessThanOrEqual(TOL * (1 + Math.abs(e)));
}

function compareRows(actual: Record<string, unknown>[], expected: Record<string, unknown>[], id: string) {
  expect(actual.length, `${id}: row count`).toBe(expected.length);
  expected.forEach((row, i) => {
    for (const key of Object.keys(row)) {
      if (typeof row[key] === "number" || row[key] === null) {
        expectClose(actual[i][key as keyof (typeof actual)[number]], row[key], `${id}[${i}].${key}`);
      }
    }
  });
}

describe("TypeScript engine matches the R reference", () => {
  (cases as Array<{ fn: string; args: Record<string, unknown>; result: unknown }>).forEach((c, ci) => {
    it(`${c.fn} #${ci} (${JSON.stringify(c.args).slice(0, 60)})`, () => {
      if (c.fn === "responder_analysis") {
        const out = responderAnalysis(sampleData, c.args as unknown as AnalysisOptions);
        compareRows(out as unknown as Record<string, unknown>[], c.result as Record<string, unknown>[], c.fn);
      } else if (c.fn === "responder_rd_individual") {
        const out = responderRdIndividual(sampleData, c.args as unknown as AnalysisOptions);
        compareRows(out as unknown as Record<string, unknown>[], c.result as Record<string, unknown>[], c.fn);
      } else if (c.fn === "responder_cles") {
        const a = c.args as {
          direction?: "higher" | "lower"; pooling?: "fixed" | "random";
          ci_method?: "wald" | "hksj"; conf_level?: number;
        };
        const out = responderCles(sampleData, a);
        const exp = c.result as Record<string, unknown>;
        const outRec = out as unknown as Record<string, unknown>;
        for (const key of ["cles", "cles_lb", "cles_ub", "delta", "se_delta", "tau2", "i2", "q", "q_p", "pi_lb", "pi_ub"]) {
          expectClose(outRec[key], exp[key], `cles.${key}`);
        }
        compareRows(out.studies as unknown as Record<string, unknown>[], exp.studies as Record<string, unknown>[], "cles.studies");
      }
    });
  });
});
