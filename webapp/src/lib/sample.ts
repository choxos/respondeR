import type { StudyRow } from "./engine";

/** The package's bundled example dataset (sample_responder_data). */
export const sampleData: StudyRow[] = [
  { study: "Study 1", change_e: 0.9581395, sd_e: 1.257593, n_e: 43, change_c: 0.217777778, sd_c: 1.195501, n_c: 45 },
  { study: "Study 2", change_e: 0.7920863, sd_e: 1.281364, n_e: 139, change_c: 0.003448276, sd_c: 1.324629, n_c: 145 },
  { study: "Study 3", change_e: 1.0230769, sd_e: 1.341201, n_e: 156, change_c: -0.041975309, sd_c: 1.263178, n_c: 162 },
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
    if (row.sd_e <= 0 || row.sd_c <= 0) throw new Error(`Row ${i + 1}: standard deviations must be greater than 0.`);
    if (row.n_e < 2 || row.n_c < 2) throw new Error(`Row ${i + 1}: sample sizes must be at least 2.`);
    return row;
  });
}
