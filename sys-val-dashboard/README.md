# SYS VAL Project Dashboard – Sheets pipeline + Slides generator

```
Req. tracker─┐                                   ┌─> Dashboard (charts, strictly from Calculation_Engine)
Bug tracker ─┴─> Raw_Data ─> Calculation_Engine ─┤
InputForm.html ─> TPM_Equipment + TPM_Support ──┘─> Code.gs ─> Slides copy "SYS VAL DASHBOARD <Project> CWxx"
```

`Calculation_Engine` is a **Key | Value** list (columns A:B). The script reads it
generically: key `BUG_RATE` fills the slide placeholder `{{BUG_RATE}}`. Adding a KPI =
add a row + put the placeholder in the template. No script change.

## Assumed source layouts (adapt the ranges in Raw_Data if yours differ)

| Source | Tab | Layout |
|---|---|---|
| Requirements tracker sheet | `Coverage` | `A1:D3` – header `Level, Total Reqs, Covered Reqs, Moved to R260`; row 2 = `SYS.4`, row 3 = `SYS.5` |
| Requirements tracker sheet | `TestCases` | `A:D` – `TC_ID, Level (SYS.4/SYS.5), Result (Passed/Failed/Not Run), Type (Automated/Manual)` |
| Bug tracker sheet | `Summary` | `A1:B4` – `Metric, Value` / `Total Bugs, n` / `Escaped Bugs, n` / `Weekly Comments, text` |

Test-case results were not named as one of your two sources, so I assumed they live in the Requirements tracker sheet. Point that import at wherever they really are.

---

## Manual input – TPM Input form (replaces the old `TPM_Input` tab)

TPMs no longer type into the Sheet. They open **`InputForm.html`**, pick their project, and edit:
- **Test Equipment Status**: up to 8 rows of Test Platform, Planned Week, Achieved Week, Status (Ready / Evaluation / Blocked).
- **Support Required**: 3 fixed rows of Action Item, Responsible, Due Date, Status.

The form checks the input before saving. It highlights the status colours, shows a late achieved week in red, and shows `BLOCKER:` statuses in red. A **Generate deck** button builds that project's slides right away.
The form runs as the Sheet owner, so TPMs need **no edit access** to the Sheet. Every save records the TPM's email and the time.

| Tab | Columns | Notes |
|---|---|---|
| `Projects` | `Project, Release, Engine Tab (optional)` | One row per project. The owner maintains it. `Release` fills `{{RELEASE}}`. `Engine Tab` defaults to `Calculation_Engine` (see below). |
| `TPM_Equipment` | `Project, Test Platform, Planned Week, Achieved Week, Status, Updated By, Updated At` | Written by the form. Weeks are stored as ISO text `2026-W43` and shown as `cw43` (or `cw06/27` for another year) on the slide. |
| `TPM_Support` | `Project, No., Action Item, Responsible, Due Date, Status, Updated By, Updated At` | Written by the form. `No.` = slide row 1–3. |

**Dashboard Generator → Setup Input Tabs** creates all three tabs and applies the formatting and protection:
- Status validation and fills: `=$E2="Ready"` → green `#92D050`, `="Evaluation"` → yellow `#FFC000`, `="Blocked"` → light red.
- Late week → red text on `D2:D`: `=AND($C2<>"",$D2<>"",$D2>$C2)`. ISO week text sorts chronologically.
- `BLOCKER:` → red text on `TPM_Support!F2:F`.
- All three tabs are locked to the owner.

**Several projects with different data sources:** duplicate `Raw_Data` and `Calculation_Engine` per project (for example `Raw_Data_B`, `Calculation_Engine_B` pointing at project B's Requirements tracker and Bug tracker), then put the engine tab name in `Projects!C`.

### Publish the form

1. Apps Script editor → **+ → HTML**, name it `InputForm`, paste `InputForm.html`.
2. **Deploy → New deployment → Web app**. Set *Execute as*: **Me**. Set *Who has access*: **Anyone within your organisation**.
3. Share the web-app URL with the TPMs. Owners can also use **Dashboard Generator → Open TPM Input Form** inside the Sheet.
4. After any code change: **Deploy → Manage deployments → Edit → New version**, or the URL keeps serving the old code.

## Tab 2 – `Raw_Data`

| Cell | Content |
|---|---|
| `A1` / `B1` | `REQ_TRACKER_SHEET_URL` / *paste URL* |
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

Support Required and Test Equipment values come from the form tabs, not from `Calculation_Engine`. Rows 31–42 from the earlier version can be deleted.

The script reads display values, so `99.7%` reaches the slide exactly as formatted.

## Tab 4 – `Dashboard`

Every cell references `Calculation_Engine` only, never `Raw_Data` or the input tabs.

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

`SYS_VAL_Dashboard_Template.pptx` already contains all of these. Upload it to Drive, open it with Google Slides, and save it as Google Slides.

| Source | Placeholders |
|---|---|
| Engine tab | Every key, e.g. `{{SYS4_COVERAGE}}`, `{{SYS5_COVERAGE}}`, `{{BUG_RATE}}`, `{{BUG_COMMENT}}`, `{{COVERAGE_NOTE}}`, `{{SYS4_TC_PASSED}}` |
| Projects tab | `{{PROJECT}}`, `{{RELEASE}}` |
| Script | `{{CW}}` (e.g. `41`), `{{REPORT_DATE}}` |
| Support Required (n = 1..3) | `{{ACTION_n}}`, `{{RESP_n}}`, `{{DUE_n}}`, `{{STATUS_n}}`. Blank rows become empty, and a status containing `BLOCKER:` turns red. |
| Test Equipment (n = 1..8) | `{{EQ_PLATFORM_n}}`, `{{EQ_PLANNED_n}}`, `{{EQ_ACHIEVED_n}}`, `{{EQ_STATUS_n}}`. Each row is a table row, and rows beyond the project's count are removed. The status cell gets the status fill, and a late achieved week turns red. |

Keep each table placeholder alone in its cell.

## Install

1. In the Sheet: Extensions → Apps Script → paste `Code.gs`, and add `InputForm.html` as an HTML file named `InputForm`.
2. Set `TEMPLATE_ID` and `FOLDER_ID` at the top of `Code.gs`.
3. Reload the Sheet → **Dashboard Generator → Setup Input Tabs (one-off)**. Authorise when asked. Add your projects to `Projects`.
4. Deploy the web app (see *Publish the form*) and send the URL to the TPMs.
5. Generate a deck from the form, from **Generate Dashboard for a Project…**, or for every project with **Generate All Projects**.
6. Optional: **Schedule Weekly (Mon 07:00, all projects)**.
