import type { StudyRow } from "./engine";

/** The package's bundled example dataset (sample_responder_data). */
export const sampleData: StudyRow[] = [
  { study: "Study 1", change_e: 0.9581395, sd_e: 1.257593, n_e: 43, change_c: 0.217777778, sd_c: 1.195501, n_c: 45 },
  { study: "Study 2", change_e: 0.7920863, sd_e: 1.281364, n_e: 139, change_c: 0.003448276, sd_c: 1.324629, n_c: 145 },
  { study: "Study 3", change_e: 1.0230769, sd_e: 1.341201, n_e: 156, change_c: -0.041975309, sd_c: 1.263178, n_c: 162 },
];

/**
 * Real VAS pain change scores from 20 spinal-health exercise trials, pooled by
 * Li, Bao, Wang & Zhao (2025), Front. Sports Act. Living, doi:10.3389/fspor.2025.1614906,
 * Figure 3. Reproduced under CC BY 4.0. Change is post minus baseline VAS, so a
 * more negative value is a larger pain reduction (analyze with direction "lower").
 */
export const vasPainData: StudyRow[] = [
  { study: "Aboufazeli 2021", change_e: -5.06, sd_e: 1.15, n_e: 12, change_c: -3.08, sd_c: 1.28, n_c: 12 },
  { study: "Erika 2014", change_e: -0.3, sd_e: 2.03, n_e: 21, change_c: -0.66, sd_c: 2.49, n_c: 20 },
  { study: "Falla 2013", change_e: -1.7, sd_e: 2.62, n_e: 23, change_c: -0.2, sd_c: 2.17, n_c: 23 },
  { study: "Farzaneh a 2022", change_e: -3, sd_e: 2.15, n_e: 14, change_c: 0.36, sd_c: 2.32, n_c: 14 },
  { study: "Farzaneh b 2022", change_e: -2.83, sd_e: 2.1, n_e: 14, change_c: 0.36, sd_c: 2.32, n_c: 14 },
  { study: "Hua Song 2008", change_e: -1.81, sd_e: 1.23, n_e: 37, change_c: -0.6, sd_c: 1.28, n_c: 31 },
  { study: "Lin Li 2021", change_e: -4.1, sd_e: 1.1, n_e: 60, change_c: -2.84, sd_c: 1.02, n_c: 60 },
  { study: "Lin Li 2023", change_e: -3.95, sd_e: 1.29, n_e: 30, change_c: -3.43, sd_c: 1.34, n_c: 30 },
  { study: "Peng Qiu a 2014", change_e: -1.31, sd_e: 1.4, n_e: 10, change_c: -0.51, sd_c: 1.49, n_c: 10 },
  { study: "Peng Qiu b 2014", change_e: -2.75, sd_e: 1.26, n_e: 10, change_c: -0.51, sd_c: 1.49, n_c: 10 },
  { study: "Shanju Bao 2023", change_e: -1.34, sd_e: 2.47, n_e: 31, change_c: -0.55, sd_c: 2.29, n_c: 29 },
  { study: "Weimin Zou 2023", change_e: -2.86, sd_e: 0.6, n_e: 60, change_c: -1.93, sd_c: 0.37, n_c: 60 },
  { study: "Xiaojian Ke 2018", change_e: -1.4, sd_e: 1.08, n_e: 20, change_c: -0.2, sd_c: 1.28, n_c: 17 },
  { study: "Xingping Hu 2018", change_e: -3.83, sd_e: 0.83, n_e: 30, change_c: -2.57, sd_c: 0.98, n_c: 30 },
  { study: "Xiuyuan Li 2024", change_e: -2.78, sd_e: 0.98, n_e: 50, change_c: -1.92, sd_c: 1.02, n_c: 50 },
  { study: "Yong Ding 2014", change_e: -2.66, sd_e: 0.98, n_e: 22, change_c: -1.42, sd_c: 1.01, n_c: 18 },
  { study: "Yue Guo 2025", change_e: -1.16, sd_e: 1.36, n_e: 37, change_c: 0.08, sd_c: 1.91, n_c: 37 },
  { study: "Yuping Chong 2011", change_e: -3.57, sd_e: 1.33, n_e: 30, change_c: -3.04, sd_c: 1.62, n_c: 30 },
  { study: "Yuping Chong 2014", change_e: -3.77, sd_e: 1.77, n_e: 30, change_c: -2.81, sd_c: 1.61, n_c: 30 },
  { study: "Zhou 2022", change_e: -2.71, sd_e: 1.07, n_e: 130, change_c: -2.31, sd_c: 1.12, n_c: 129 },
];

export const REQUIRED_COLUMNS = ["study", "change_e", "sd_e", "n_e", "change_c", "sd_c", "n_c"] as const;

/** Validate and coerce parsed rows, mirroring validate_responder_data() in R. */
export function validateData(rows: Record<string, unknown>[]): StudyRow[] {
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error("No rows found in the uploaded data.");
  }
  const cols = Object.keys(rows[0] ?? {});
  const missing = REQUIRED_COLUMNS.filter((c) => !cols.includes(c));
  if (missing.length) {
    throw new Error(`Missing required column(s): ${missing.join(", ")}.`);
  }
  return rows.map((r, i) => {
    const num = (key: string): number => {
      const v = typeof r[key] === "string" ? Number((r[key] as string).trim()) : (r[key] as number);
      if (v == null || Number.isNaN(v)) {
        throw new Error(`Row ${i + 1}: column "${key}" is missing or non-numeric.`);
      }
      return v;
    };
    const row: StudyRow = {
      study: String(r.study ?? `Study ${i + 1}`),
      change_e: num("change_e"), sd_e: num("sd_e"), n_e: num("n_e"),
      change_c: num("change_c"), sd_c: num("sd_c"), n_c: num("n_c"),
    };
    if (!Number.isFinite(row.change_e) || !Number.isFinite(row.change_c)) {
      throw new Error(`Row ${i + 1}: mean change must be finite.`);
    }
    if (!(row.sd_e > 0) || !(row.sd_c > 0) || !Number.isFinite(row.sd_e) || !Number.isFinite(row.sd_c)) {
      throw new Error(`Row ${i + 1}: standard deviations must be finite and greater than 0.`);
    }
    if (row.n_e < 2 || row.n_c < 2) throw new Error(`Row ${i + 1}: sample sizes must be at least 2.`);
    if (Math.abs(row.n_e - Math.round(row.n_e)) > 1e-8 || Math.abs(row.n_c - Math.round(row.n_c)) > 1e-8) {
      throw new Error(`Row ${i + 1}: sample sizes must be whole numbers.`);
    }
    return row;
  });
}
