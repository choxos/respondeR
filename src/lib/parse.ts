import Papa from "papaparse";
import { validateData } from "./sample";
import type { StudyRow } from "./engine";

/** Parse an uploaded CSV or Excel file into validated study rows. */
export async function parseFile(file: File): Promise<StudyRow[]> {
  const ext = file.name.split(".").pop()?.toLowerCase();
  let rows: Record<string, unknown>[];
  if (ext === "xlsx" || ext === "xls") {
    // Load the (large) spreadsheet parser only when an Excel file is uploaded.
    const XLSX = await import("xlsx");
    const buf = await file.arrayBuffer();
    const wb = XLSX.read(buf, { type: "array" });
    const sheet = wb.Sheets[wb.SheetNames[0]];
    rows = XLSX.utils.sheet_to_json(sheet, { defval: null }) as Record<string, unknown>[];
  } else {
    const text = await file.text();
    const parsed = Papa.parse<Record<string, unknown>>(text, {
      header: true,
      dynamicTyping: true,
      skipEmptyLines: true,
    });
    if (parsed.errors.length) {
      throw new Error(parsed.errors[0].message);
    }
    rows = parsed.data;
  }
  return validateData(rows);
}

/** A CSV template with the required header. */
export function templateCsv(): string {
  return "study,change_e,sd_e,n_e,change_c,sd_c,n_c\n";
}

/** Serialise analysis results to CSV for download. */
export function toCsv(rows: Record<string, unknown>[]): string {
  return Papa.unparse(rows);
}
