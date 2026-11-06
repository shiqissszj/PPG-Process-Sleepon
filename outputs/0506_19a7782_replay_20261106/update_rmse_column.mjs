import fs from 'node:fs/promises';
import { FileBlob, SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const sourcePath = '/Users/shiqissszj/Desktop/Sleepon/Codes/sleepon_original_0421/RMSE_summary.xlsx';
const resultsPath = '/Users/shiqissszj/Desktop/Sleepon/Codes/sleepon_original_0421/outputs/0506_19a7782_replay_20261106/0506_19a7782_results.csv';
const outputPath = '/tmp/RMSE_summary_updated_19a7782.xlsx';
const targetHeader = 'PR RMSE 0506 重跑（旧版快照）';

const workbook = await SpreadsheetFile.importXlsx(await FileBlob.load(sourcePath));
const sheet = workbook.worksheets.getItemAt(0);
const beforeValues = sheet.getRange('A1:L165').values;
const beforeFormulas = sheet.getRange('A1:L165').formulas;
const headers = beforeValues[0].map(value => String(value ?? '').trim());
const targetColumnIndex = headers.indexOf(targetHeader);
if (targetColumnIndex < 0) throw new Error(`Could not find target column: ${targetHeader}`);
const targetColumnLetter = String.fromCharCode('A'.charCodeAt(0) + targetColumnIndex);

const rowIds = sheet.getRange('A2:A157').values.flat().map(value => String(value ?? '').trim());
const recordIds = rowIds.filter(Boolean);
if (recordIds.length !== 154 || new Set(recordIds).size !== recordIds.length) {
  throw new Error(`Expected 154 unique workbook records, got ${recordIds.length}.`);
}

const csvBook = await Workbook.fromCSV(await fs.readFile(resultsPath, 'utf8'), { sheetName: 'Results' });
const csvValues = csvBook.worksheets.getItem('Results').getUsedRange().values;
const csvHeaders = csvValues[0].map(value => String(value ?? '').trim());
const recordIdIndex = csvHeaders.indexOf('RecordID');
const rmseIndex = csvHeaders.indexOf('PRRMSE');
const statusIndex = csvHeaders.indexOf('Status');
if ([recordIdIndex, rmseIndex, statusIndex].some(index => index < 0)) throw new Error('Results CSV is missing required columns.');

const resultById = new Map();
for (const row of csvValues.slice(1)) {
  const id = String(row[recordIdIndex] ?? '').trim();
  if (!id) continue;
  if (resultById.has(id)) throw new Error(`Duplicate result for ${id}.`);
  const rmse = Number(row[rmseIndex]);
  if (String(row[statusIndex]) !== 'ok' || !Number.isFinite(rmse)) {
    throw new Error(`Invalid result for ${id}: status=${row[statusIndex]}, PRRMSE=${row[rmseIndex]}.`);
  }
  resultById.set(id, rmse);
}
const missing = recordIds.filter(id => !resultById.has(id));
const extras = [...resultById.keys()].filter(id => !recordIds.includes(id));
if (missing.length || extras.length || resultById.size !== 154) {
  throw new Error(JSON.stringify({ resultCount: resultById.size, missing, extras }));
}

const valuesToWrite = rowIds.map(id => [id ? resultById.get(id) : null]);
sheet.getRange(`${targetColumnLetter}2:${targetColumnLetter}157`).values = valuesToWrite;
workbook.recalculate();

const formulasAfter = sheet.getRange('A1:L165').formulas;
if (JSON.stringify(beforeFormulas) !== JSON.stringify(formulasAfter)) throw new Error('Formulas changed unexpectedly.');
const afterValues = sheet.getRange('A1:L165').values;
for (let row = 0; row < beforeValues.length; row++) {
  for (let column = 0; column < beforeValues[row].length; column++) {
    if (column === targetColumnIndex) continue;
    if (JSON.stringify(beforeValues[row][column]) !== JSON.stringify(afterValues[row][column])) {
      throw new Error(`Unexpected change outside target column at row ${row + 1}, column ${column + 1}.`);
    }
  }
}

const expectedAverage = (startRow, endRow) => {
  const sample = rowIds.slice(startRow - 2, endRow - 1).filter(Boolean).map(id => resultById.get(id));
  return sample.reduce((sum, value) => sum + value, 0) / sample.length;
};
const summaryChecks = [
  ['159', expectedAverage(75, 115)],
  ['161', expectedAverage(117, 157)],
  ['163', expectedAverage(2, 73)],
  ['165', expectedAverage(2, 157)],
];
for (const [row, expected] of summaryChecks) {
  const actual = sheet.getRange(`${targetColumnLetter}${row}`).values[0][0];
  if (!Number.isFinite(actual) || Math.abs(actual - expected) > 1e-9) {
    throw new Error(`Summary ${targetColumnLetter}${row}=${actual}; expected ${expected}.`);
  }
}
sheet.getRange(`${targetColumnLetter}159:${targetColumnLetter}165`).format.numberFormat = '0.00';

const errors = await workbook.inspect({
  kind: 'match',
  searchTerm: '#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!',
  options: { useRegex: true, maxResults: 100 },
  summary: 'formula error scan',
});
console.log('FORMULA_ERRORS', errors.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
const verified = await SpreadsheetFile.importXlsx(await FileBlob.load(outputPath));
const verifiedSheet = verified.worksheets.getItemAt(0);
const verifiedValues = verifiedSheet.getRange(`${targetColumnLetter}2:${targetColumnLetter}157`).values.flat();
const savedCount = verifiedValues.filter(Number.isFinite).length;
if (savedCount !== 154) throw new Error(`Saved ${savedCount} numeric RMSE values.`);
for (let index = 0; index < rowIds.length; index++) {
  const id = rowIds[index];
  if (id && Math.abs(verifiedValues[index] - resultById.get(id)) > 1e-12) {
    throw new Error(`Saved value mismatch for ${id}.`);
  }
}

await fs.copyFile(outputPath, sourcePath);
console.log('UPDATED', JSON.stringify({
  sourcePath,
  header: targetHeader,
  records: savedCount,
  legacy1013: resultById.get('legacy_1013'),
  legacy1015: resultById.get('legacy_1015'),
  psg55: resultById.get('psg_55'),
  midpoint50_55: resultById.get('psg_midpoint50_55'),
  averages: Object.fromEntries(summaryChecks.map(([row]) => [row, verifiedSheet.getRange(`${targetColumnLetter}${row}`).values[0][0]])),
}));
