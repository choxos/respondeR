import Papa from "papaparse";
import { validateData } from "./sample";
import type { StudyRow } from "./engine";

// Files are parsed entirely in the browser; cap the size as a guard against a
// malicious or accidental large upload.
const MAX_FILE_BYTES = 5 * 1024 * 1024;

/**
 * Parse an uploaded CSV file into validated study rows. The app is CSV-only by
 * design: a responder dataset is one row per study, so no spreadsheet parser is
 * needed, and this avoids shipping a spreadsheet dependency with open security
 * advisories. Save Excel files as CSV before uploading.
 */
export async function parseFile(file: File): Promise<StudyRow[]> {
  if (file.size > MAX_FILE_BYTES) {
    throw new Error(
      `File is too large (${(file.size / 1e6).toFixed(1)} MB; limit 5 MB). ` +
        "A responder dataset is one row per study; please upload a small summary file.",
    );
  }
  const ext = file.name.split(".").pop()?.toLowerCase();
  if (ext === "xlsx" || ext === "xls") {
    throw new Error("This app reads CSV files. Save your spreadsheet as CSV and upload that.");
  }
  const text = await file.text();
  const parsed = Papa.parse<Record<string, unknown>>(text, {
    header: true,
    dynamicTyping: true,
    skipEmptyLines: true,
  });
  if (parsed.errors.length) {
    throw new Error(parsed.errors[0].message);
  }
  return validateData(parsed.data);
}

/** A CSV template with the required header. */
export function templateCsv(): string {
  return "study,change_e,sd_e,n_e,change_c,sd_c,n_c\n";
}

/** Serialise analysis results to CSV for download. */
export function toCsv(rows: Record<string, unknown>[]): string {
  return Papa.unparse(rows);
}
