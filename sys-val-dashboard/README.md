# SYS VAL Project Dashboard – Sheets pipeline + Slides generator

```
DOORS sheet ─┐                                   ┌─> Dashboard (charts, strictly from Calculation_Engine)
Bug tracker ─┴─> Raw_Data ─> Calculation_Engine ─┤
TPM_Input (manual) ──────────────────────────────┘─> Code.gs ─> Slides copy "SYS VAL DASHBOARD CWxx"
```

`Calculation_Engine` is a **Key | Value** list (columns A:B). The script reads it
generically: key `BUG_RATE` fills the slide placeholder `{{BUG_RATE}}`. Adding a KPI =
add a row + put the placeholder in the template. No script change.

## Assumed source layouts (adapt the ranges in Raw_Data if yours differ)

| Source | Tab | Layout |
|---|---|---|
| DOORS metrics sheet | `Coverage` | `A1:D3` – header `Level, Total Reqs, Covered Reqs, Moved to R260`; row 2 = `SYS.4`, row 3 = `SYS.5` |
| DOORS metrics sheet | `TestCases` | `A:D` – `TC_ID, Level (SYS.4/SYS.5), Result (Passed/Failed/Not Run), Type (Automated/Manual)` |
| Bug tracker sheet | `Summary` | `A1:B4` – `Metric, Value` / `Total Bugs, n` / `Escaped Bugs, n` / `Weekly Comments, text` |

Test-case results were not named as one of your two sources, so I assumed they live in the DOORS/ALM sheet. Point that import at wherever they really are.

---

## Tab 1 – `TPM_Input`

| Cell(s) | Content |
|---|---|
| `A2` / `F2` | Titles "Test Equipment Status" / "Support Required" |
| `A3:D3` | `Test Platform, Planned Date, Achieved Date, Status` |
| `A4:D15` | Table A data (12 rows) |
| `F3:J3` | `No., Action Item, Responsible, Due Date, Status` |
| `F4:F6` | `1, 2, 3` (locked) |
| `G4:J6` | Table B data (max 3 rows) |

**Data validation** `D4:D15`: list `Ready, Evaluation, Blocked`, reject other input.

**Conditional formatting**, range `D4:D15`, custom formulas:
- `=$D4="Ready"` → green fill `#92D050`
- `=$D4="Evaluation"` → yellow fill `#FFC000`
- `=$D4="Blocked"` → light-red fill `#F4CCCC` (optional)

**Achieved date later than planned → red text**, range `C4:C15`:
`=AND(ISNUMBER($B4),ISNUMBER($C4),$C4>$B4)` → font colour red.

**Locking**: Data → Protect sheets and ranges → sheet `TPM_Input`, *Except certain cells*: `A4:D15` and `G4:J6`.
Status text in Table B that starts with `BLOCKER:` turns red in the slide.

All of the above is applied automatically by the menu item **Dashboard Generator → 1. Setup TPM_Input**.

## Tab 2 – `Raw_Data`

| Cell | Content |
|---|---|
| `A1` / `B1` | `DOORS_SHEET_URL` / *paste URL* |
| `A2` / `B2` | `BUGTRACKER_SHEET_URL` / *paste URL* |
| `A4` | `=IMPORTRANGE($B$1,"Coverage!A1:D3")` → spills `A4:D6` (SYS.4 in row 5, SYS.5 in row 6) |
| `A9` | `=IMPORTRANGE($B$1,"TestCases!A1:D5000")` → header row 9, data from row 10 |
| `F4` | `=IMPORTRANGE($B$2,"Summary!A1:B3")` → spills `F4:G6` (Total Bugs `G5`, Escaped Bugs `G6`) |
| `F10` | `=IMPORTRANGE($B$2,"Summary!B4")` → weekly comment |

First use: click each `#REF!` cell → **Allow access**. Keep the spill areas empty.

## Tab 3 – `Calculation_Engine`

Row 1 headers: `Key | Value | Notes`. Format `*_COVERAGE`, `*_AUTO_RATE` as `0.0%`, `BUG_RATE` as `0.00%`.

| Row | A (Key) | B (Value formula) |
|---|---|---|
| 2 | `SYS4_TOTAL` | `=IFERROR(VLOOKUP("SYS.4",Raw_Data!$A$5:$D$6,2,FALSE),0)` |
| 3 | `SYS4_COVERED` | `=IFERROR(VLOOKUP("SYS.4",Raw_Data!$A$5:$D$6,3,FALSE),0)` |
| 4 | `SYS4_COVERAGE` | `=IF(B2=0,0,B3/B2)` |
| 5 | `SYS4_UNCOVERED` | `=B2-B3` |
| 6 | `SYS4_MOVED` | `=IFERROR(VLOOKUP("SYS.4",Raw_Data!$A$5:$D$6,4,FALSE),0)` |
| 7–11 | `SYS5_TOTAL … SYS5_MOVED` | same as rows 2–6 with `"SYS.5"` and refs `B7…B10` |
| 12 | `COVERAGE_NOTE` | `=IF((B5+B10)=0,"100% coverage achieved","Note: "&(B5+B10)&"/"&(B2+B7)&" reqs uncovered, "&(B6+B11)&"/"&(B5+B10)&" uncovered reqs shall be moved to R260")` |
| 13 | `BUG_TOTAL` | `=IFERROR(VALUE(Raw_Data!G5),0)` |
| 14 | `BUG_ESCAPED` | `=IFERROR(VALUE(Raw_Data!G6),0)` |
| 15 | `BUG_RATE` | `=IF(B13=0,0,B14/B13)` |
| 16 | `BUG_COMMENT` | `=IFERROR(Raw_Data!F10,"")` (direct link to the tracker's Weekly Comments) |
| 17 | `SYS4_TC_PLANNED` | `=COUNTIFS(Raw_Data!$B$10:$B,"SYS.4")` |
| 18 | `SYS4_TC_EXECUTED` | `=B19+B20` |
| 19 | `SYS4_TC_PASSED` | `=COUNTIFS(Raw_Data!$B$10:$B,"SYS.4",Raw_Data!$C$10:$C,"Passed")` |
| 20 | `SYS4_TC_FAILED` | `=COUNTIFS(Raw_Data!$B$10:$B,"SYS.4",Raw_Data!$C$10:$C,"Failed")` |
| 21–24 | `SYS5_TC_PLANNED/EXECUTED/PASSED/FAILED` | as rows 17–20 with `"SYS.5"` |
| 25 | `SYS4_AUTO_COUNT` | `=COUNTIFS(Raw_Data!$B$10:$B,"SYS.4",Raw_Data!$D$10:$D,"Automated")` |
| 26 | `SYS4_MANUAL_COUNT` | `=COUNTIFS(Raw_Data!$B$10:$B,"SYS.4",Raw_Data!$D$10:$D,"Manual")` |
| 27 | `SYS4_AUTO_RATE` | `=IF(B17=0,0,B25/B17)` |
| 28–30 | `SYS5_AUTO_COUNT/MANUAL_COUNT/AUTO_RATE` | as rows 25–27 with `"SYS.5"`, `B21` |
| 31–34 | `ACTION_1`, `RESP_1`, `DUE_1`, `STATUS_1` | `=IF(TPM_Input!G4="","",TPM_Input!G4)`, `…H4…`, `=IF(TPM_Input!I4="","",IF(ISNUMBER(TPM_Input!I4),TEXT(TPM_Input!I4,"dd.mm.yyyy"),TPM_Input!I4))`, `…J4…` |
| 35–38 | `ACTION_2` … `STATUS_2` | same, row 5 of `TPM_Input` |
| 39–42 | `ACTION_3` … `STATUS_3` | same, row 6 of `TPM_Input` |

The script reads display values, so `99.7%` reaches the slide exactly as formatted.
Blank Support rows give `""`, and the script then writes an empty string into the slide.

## Tab 4 – `Dashboard`

Every cell references `Calculation_Engine` only, never `Raw_Data` or `TPM_Input`.

**Doughnut data blocks** (2 cells each; `Remaining` is clamped so the ring never goes negative):

| Block | Title cell | Slice cells |
|---|---|---|
| SYS.4 coverage | `A2` | `A3 "Covered"`, `B3 =Calculation_Engine!B4`; `A4 "Remaining"`, `B4 =MAX(0,1-B3)` |
| SYS.5 coverage | `A6` | `B7 =Calculation_Engine!B9`; `B8 =MAX(0,1-B7)` |
| SYS.4 automation | `A10` | `B11 =Calculation_Engine!B27`; `B12 =MAX(0,1-B11)` |
| SYS.5 automation | `A14` | `B15 =Calculation_Engine!B30`; `B16 =MAX(0,1-B15)` |
| Bug escape rate | `A18` | `B19 =Calculation_Engine!B15`; `B20 =MAX(0,1-B19)` |

For each block: select `A3:B4` → Insert → Chart → **Doughnut chart**. Customize: slice 1 `#2E75B6`, slice 2 light grey, doughnut hole 75%, legend none, no slice labels. Put the big number in a cell next to the chart (`=B3`) formatted as `0.0%`.

**Stacked bar** (test execution), `A23:D25`:

| | A | B | C | D |
|---|---|---|---|---|
| 23 | `Level` | `Passed` | `Failed` | `Not executed` |
| 24 | `SYS.4` | `=Calculation_Engine!B19` | `=Calculation_Engine!B20` | `=Calculation_Engine!B17-Calculation_Engine!B18` |
| 25 | `SYS.5` | `=Calculation_Engine!B23` | `=Calculation_Engine!B24` | `=Calculation_Engine!B21-Calculation_Engine!B22` |

Select `A23:D25` → Insert → Chart → **Stacked bar chart**. Colours: Passed light green, Failed red, Not executed grey.

---

## Slide template placeholders

Every `Calculation_Engine` key works as `{{KEY}}`, e.g. `{{SYS4_COVERAGE}}`, `{{SYS5_COVERAGE}}`, `{{BUG_RATE}}`, `{{BUG_COMMENT}}`, `{{COVERAGE_NOTE}}`, `{{SYS4_TC_PASSED}}`. The script adds `{{CW}}` (e.g. `40`) and `{{REPORT_DATE}}`, so the "Updated cw40" badge becomes `Updated cw{{CW}}`.
Support table cells use `{{ACTION_n}}`, `{{RESP_n}}`, `{{DUE_n}}`, `{{STATUS_n}}` for n = 1..3 (one placeholder per cell, no other text in the cell).

## Install

1. In the Sheet: Extensions → Apps Script → paste `Code.gs`.
2. Set `TEMPLATE_ID` and `FOLDER_ID` at the top.
3. Reload the Sheet → menu **Dashboard Generator**: run *1. Setup TPM_Input*, then *2. Generate Dashboard Now*. Authorise Sheets, Slides and Drive when asked.
4. Optional: *3. Schedule Weekly (Mon 07:00)*.
