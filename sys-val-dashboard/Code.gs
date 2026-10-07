/**
 * SYS VAL Project Dashboard – TPM input form + weekly Google Slides generator.
 * Container-bound script of the dashboard Google Sheet.
 *
 * Data flow
 *   InputForm.html (web app / dialog) ──save──> TPM_Equipment + TPM_Support (one row set per project)
 *   Raw_Data ──> Calculation_Engine (Key | Value KPIs; one engine tab per project, see Projects!C)
 *   generateDashboard(project) merges both and fills {{KEY}} placeholders in a copy of the template deck.
 */

const CONFIG = {
  TEMPLATE_ID: 'PASTE_TEMPLATE_SLIDES_ID',
  FOLDER_ID: 'PASTE_DESTINATION_FOLDER_ID',
  NAME_PREFIX: 'SYS VAL DASHBOARD',
  PROJECTS_SHEET: 'Projects',
  EQUIPMENT_SHEET: 'TPM_Equipment',
  SUPPORT_SHEET: 'TPM_Support',
  DEFAULT_ENGINE_SHEET: 'Calculation_Engine',
  MAX_EQUIPMENT: 8,
  SUPPORT_ROWS: 3,
  MAX_TEXT: 300,
  STATUSES: ['Ready', 'Evaluation', 'Blocked'],
  STATUS_FILLS: { Ready: '#92D050', Evaluation: '#FFC000', Blocked: '#F4CCCC' },
  BLOCKER_TOKEN: 'BLOCKER:',
  RED: '#FF0000',
  TIMEZONE: Session.getScriptTimeZone(),
};

const WEEK_RE = /^(\d{4})-W(\d{2})$/;

// ───────────────────────────── UI ─────────────────────────────

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Dashboard Generator')
    .addItem('Open TPM Input Form', 'openInputForm')
    .addItem('Generate Dashboard for a Project…', 'generateDashboardPrompt')
    .addItem('Generate All Projects', 'generateAllDashboards')
    .addSeparator()
    .addItem('Setup Input Tabs (one-off)', 'setupInputSheets')
    .addItem('Schedule Weekly (Mon 07:00, all projects)', 'installWeeklyTrigger')
    .addToUi();
}

/** Web app entry point (Deploy → New deployment → Web app). */
function doGet() {
  return HtmlService.createHtmlOutputFromFile('InputForm')
    .setTitle('SYS VAL TPM Input')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

/** Same form as a dialog inside the Sheet. */
function openInputForm() {
  const html = HtmlService.createHtmlOutputFromFile('InputForm').setWidth(1100).setHeight(780);
  SpreadsheetApp.getUi().showModalDialog(html, 'SYS VAL TPM Input');
}

function notify_(msg) {
  Logger.log(msg);
  try { SpreadsheetApp.getActive().toast(msg, 'Dashboard Generator', 10); } catch (e) { /* web app or trigger */ }
}

// ───────────────────── Form endpoints (google.script.run) ─────────────────────

function getProjects() {
  return dataRows_(sheet_(CONFIG.PROJECTS_SHEET), 3)
    .filter(r => r[0].trim())
    .map(r => ({
      name: r[0].trim(),
      release: r[1].trim(),
      engine: r[2].trim() || CONFIG.DEFAULT_ENGINE_SHEET,
    }));
}

function getProjectData(projectName) {
  findProject_(projectName);
  const eq = dataRows_(sheet_(CONFIG.EQUIPMENT_SHEET), 7).filter(r => r[0] === projectName);
  const sup = dataRows_(sheet_(CONFIG.SUPPORT_SHEET), 8).filter(r => r[0] === projectName);
  const stamp = eq[0] || sup[0];
  return {
    equipment: eq.map(r => ({ platform: r[1], planned: r[2], achieved: r[3], status: r[4] })),
    support: sup.map(r => ({ no: Number(r[1]), action: r[2], responsible: r[3], due: r[4], status: r[5] })),
    updatedBy: stamp ? stamp[stamp.length - 2] : '',
    updatedAt: stamp ? stamp[stamp.length - 1] : '',
  };
}

function saveProjectData(projectName, data) {
  findProject_(projectName);
  const equipment = cleanEquipment_(data && data.equipment);
  const support = cleanSupport_(data && data.support);
  const user = Session.getActiveUser().getEmail() || 'unknown';
  const now = new Date();

  const eqRows = equipment.map(e => [projectName, e.platform, e.planned, e.achieved, e.status, user, now]);
  const supRows = support.map(s => [projectName, s.no, s.action, s.responsible, s.due, s.status, user, now]);

  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    replaceProjectRows_(sheet_(CONFIG.EQUIPMENT_SHEET), 7, projectName, eqRows);
    replaceProjectRows_(sheet_(CONFIG.SUPPORT_SHEET), 8, projectName, supRows);
    SpreadsheetApp.flush();
  } finally {
    lock.releaseLock();
  }
  return getProjectData(projectName);
}

function generateFromForm(projectName) {
  return generateDashboard(projectName);
}

// ───────────────────────── Validation / storage ─────────────────────────

function cleanText_(v) {
  return String(v == null ? '' : v).trim().slice(0, CONFIG.MAX_TEXT);
}

/** Stops user text such as "=IMPORTXML(...)" from being stored as a formula. */
function escapeFormula_(v) {
  return typeof v === 'string' && /^[=+\-@]/.test(v) ? "'" + v : v;
}

function cleanEquipment_(list) {
  if (!Array.isArray(list)) return [];
  const rows = list
    .map(e => ({
      platform: cleanText_(e.platform),
      planned: cleanText_(e.planned),
      achieved: cleanText_(e.achieved),
      status: cleanText_(e.status),
    }))
    .filter(e => e.platform || e.planned || e.achieved || e.status);
  if (rows.length > CONFIG.MAX_EQUIPMENT) {
    throw new Error('At most ' + CONFIG.MAX_EQUIPMENT + ' test platforms fit on the slide.');
  }
  rows.forEach((e, i) => {
    const where = 'Test equipment row ' + (i + 1) + ': ';
    if (!e.platform) throw new Error(where + 'enter the test platform name.');
    if (CONFIG.STATUSES.indexOf(e.status) === -1) throw new Error(where + 'choose a status.');
    [['planned', e.planned], ['achieved', e.achieved]].forEach(([label, w]) => {
      if (w && !WEEK_RE.test(w)) throw new Error(where + label + ' week must look like 2026-W43.');
    });
  });
  return rows;
}

function cleanSupport_(list) {
  if (!Array.isArray(list)) return [];
  return list.slice(0, CONFIG.SUPPORT_ROWS)
    .map((s, i) => ({
      no: i + 1,
      action: cleanText_(s && s.action),
      responsible: cleanText_(s && s.responsible),
      due: cleanText_(s && s.due),
      status: cleanText_(s && s.status),
    }))
    .filter(s => s.action || s.responsible || s.due || s.status);
}

/** Replaces every row of one project, leaving other projects untouched. Caller holds the lock. */
function replaceProjectRows_(sh, cols, projectName, newRows) {
  const last = sh.getLastRow();
  const old = last > 1 ? sh.getRange(2, 1, last - 1, cols).getValues() : [];
  const kept = old
    .filter(r => String(r[0]) !== projectName)
    .map(r => r.map(escapeFormula_));
  const all = kept.concat(newRows.map(r => r.map(escapeFormula_)));
  if (last > 1) sh.getRange(2, 1, last - 1, cols).clearContent();
  if (all.length) sh.getRange(2, 1, all.length, cols).setValues(all);
}

function sheet_(name) {
  const sh = SpreadsheetApp.getActive().getSheetByName(name);
  if (!sh) throw new Error('Tab "' + name + '" not found. Run Dashboard Generator → Setup Input Tabs first.');
  return sh;
}

function dataRows_(sh, cols) {
  const n = sh.getLastRow() - 1;
  return n > 0 ? sh.getRange(2, 1, n, cols).getDisplayValues() : [];
}

function findProject_(name) {
  const p = getProjects().find(x => x.name === name);
  if (!p) throw new Error('Unknown project "' + name + '". Add it to the Projects tab.');
  return p;
}

// ───────────────────────── Deck generation ─────────────────────────

function generateDashboardPrompt() {
  const ui = SpreadsheetApp.getUi();
  const names = getProjects().map(p => p.name);
  if (!names.length) return ui.alert('Add at least one project to the Projects tab.');
  let name = names[0];
  if (names.length > 1) {
    const res = ui.prompt('Generate dashboard', 'Project name (' + names.join(', ') + '):', ui.ButtonSet.OK_CANCEL);
    if (res.getSelectedButton() !== ui.Button.OK) return;
    name = res.getResponseText().trim();
  }
  const out = generateDashboard(name);
  ui.alert('Created "' + out.name + '"\n' + out.url);
}

function generateAllDashboards() {
  getProjects().forEach(p => {
    try { generateDashboard(p.name); } catch (e) { notify_('Failed for ' + p.name + ': ' + e.message); }
  });
}

function generateDashboard(projectName) {
  if (CONFIG.TEMPLATE_ID.indexOf('PASTE') === 0 || CONFIG.FOLDER_ID.indexOf('PASTE') === 0) {
    throw new Error('Set TEMPLATE_ID and FOLDER_ID in CONFIG first.');
  }
  const project = findProject_(projectName);
  SpreadsheetApp.flush(); // let IMPORTRANGE / formulas settle

  const now = new Date();
  const week = isoWeek_(now);
  const input = getProjectData(project.name);
  const values = Object.assign(readEngineValues_(project.engine), {
    PROJECT: project.name,
    RELEASE: project.release,
    CW: String(week.week),
    REPORT_DATE: Utilities.formatDate(now, CONFIG.TIMEZONE, 'dd.MM.yyyy'),
  });
  const rules = [];

  // Support Required: placeholders by position; blank rows become empty strings
  for (let n = 1; n <= CONFIG.SUPPORT_ROWS; n++) {
    const s = input.support.find(x => x.no === n) || {};
    values['ACTION_' + n] = s.action || '';
    values['RESP_' + n] = s.responsible || '';
    values['DUE_' + n] = s.due || '';
    values['STATUS_' + n] = s.status || '';
    if ((s.status || '').indexOf(CONFIG.BLOCKER_TOKEN) !== -1) {
      rules.push({ token: '{{STATUS_' + n + '}}', apply: c => c.text().getTextStyle().setForegroundColor(CONFIG.RED) });
    }
  }

  // Test Equipment: status fill + red achieved week when later than planned
  for (let n = 1; n <= CONFIG.MAX_EQUIPMENT; n++) {
    const e = input.equipment[n - 1] || {};
    values['EQ_PLATFORM_' + n] = e.platform || '';
    values['EQ_PLANNED_' + n] = formatWeek_(e.planned, week.year);
    values['EQ_ACHIEVED_' + n] = formatWeek_(e.achieved, week.year);
    values['EQ_STATUS_' + n] = e.status || '';
    if (CONFIG.STATUS_FILLS[e.status]) {
      const fill = CONFIG.STATUS_FILLS[e.status];
      rules.push({ token: '{{EQ_STATUS_' + n + '}}', apply: c => c.fill().setSolidFill(fill) });
    }
    if (e.planned && e.achieved && e.achieved > e.planned) { // ISO week strings sort chronologically
      rules.push({ token: '{{EQ_ACHIEVED_' + n + '}}', apply: c => c.text().getTextStyle().setForegroundColor(CONFIG.RED) });
    }
  }

  // 1. Duplicate the template
  const name = CONFIG.NAME_PREFIX + ' ' + project.name + ' CW' + week.week;
  const copy = DriveApp.getFileById(CONFIG.TEMPLATE_ID)
    .makeCopy(name, DriveApp.getFolderById(CONFIG.FOLDER_ID));
  const pres = SlidesApp.openById(copy.getId());

  // 2. Drop equipment rows the project does not use
  removeUnusedEquipmentRows_(pres, input.equipment.length);

  // 3. Formatting rules need the placeholder still in place to find their cell
  applyRules_(pres, rules, values);

  // 4. Every remaining placeholder
  Object.keys(values).forEach(key => pres.replaceAllText('{{' + key + '}}', values[key]));

  warnLeftoverPlaceholders_(pres);
  pres.saveAndClose();

  notify_('Created "' + name + '": ' + copy.getUrl());
  return { name: name, url: copy.getUrl() };
}

/** Reads a Key | Value engine tab as {KEY: displayValue}. Formula errors become 'n/a'. */
function readEngineValues_(sheetName) {
  const sh = sheet_(sheetName);
  const out = {};
  dataRows_(sh, 2).forEach(r => {
    const key = String(r[0]).trim();
    if (!key) return;
    let val = String(r[1]);
    if (/^#(N\/A|REF!|VALUE!|DIV\/0!|NAME\?|ERROR!|NUM!)/.test(val)) {
      Logger.log('Formula error in ' + sheetName + '!' + key + ': ' + val);
      val = 'n/a';
    }
    out[key] = val;
  });
  return out;
}

/** For each rule: replace its token in the shape/cell that holds it, then apply the formatting. */
function applyRules_(pres, rules, values) {
  if (!rules.length) return;
  pres.getSlides().forEach(slide => {
    collectContainers_(slide.getPageElements()).forEach(c => {
      rules.forEach(rule => {
        if (c.text().asString().indexOf(rule.token) === -1) return;
        const key = rule.token.slice(2, -2);
        c.text().replaceAllText(rule.token, values[key]);
        rule.apply(c); // re-fetches the range: the old one is stale after replacement
      });
    });
  });
}

function removeUnusedEquipmentRows_(pres, used) {
  pres.getSlides().forEach(slide => {
    forEachTable_(slide.getPageElements(), table => {
      for (let r = table.getNumRows() - 1; r >= 0; r--) {
        const m = table.getCell(r, 0).getText().asString().match(/\{\{EQ_PLATFORM_(\d+)\}\}/);
        if (m && Number(m[1]) > used && table.getNumRows() > 1) table.getRow(r).remove();
      }
    });
  });
}

/** Every shape and table cell (groups included) as {text(), fill()} getters that always return fresh objects. */
function collectContainers_(elements) {
  const out = [];
  elements.forEach(el => {
    switch (el.getPageElementType()) {
      case SlidesApp.PageElementType.SHAPE: {
        const shape = el.asShape();
        out.push({ text: () => shape.getText(), fill: () => shape.getFill() });
        break;
      }
      case SlidesApp.PageElementType.TABLE: {
        const table = el.asTable();
        for (let r = 0; r < table.getNumRows(); r++) {
          for (let c = 0; c < table.getNumColumns(); c++) {
            const cell = table.getCell(r, c);
            out.push({ text: () => cell.getText(), fill: () => cell.getFill() });
          }
        }
        break;
      }
      case SlidesApp.PageElementType.GROUP:
        out.push.apply(out, collectContainers_(el.asGroup().getChildren()));
        break;
    }
  });
  return out;
}

function forEachTable_(elements, fn) {
  elements.forEach(el => {
    const type = el.getPageElementType();
    if (type === SlidesApp.PageElementType.TABLE) fn(el.asTable());
    else if (type === SlidesApp.PageElementType.GROUP) forEachTable_(el.asGroup().getChildren(), fn);
  });
}

function warnLeftoverPlaceholders_(pres) {
  const left = {};
  pres.getSlides().forEach(slide => {
    collectContainers_(slide.getPageElements()).forEach(c => {
      (c.text().asString().match(/\{\{[A-Z0-9_]+\}\}/g) || []).forEach(m => { left[m] = true; });
    });
  });
  const keys = Object.keys(left);
  if (keys.length) notify_('Unreplaced placeholders (no matching key): ' + keys.join(', '));
}

// ───────────────────────── Helpers ─────────────────────────

/** ISO-8601 calendar week and its week-year. */
function isoWeek_(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return { week: Math.ceil(((d - yearStart) / 86400000 + 1) / 7), year: d.getUTCFullYear() };
}

/** "2026-W43" → "cw43" in the current year, "cw43/27" otherwise (the slide's convention). */
function formatWeek_(iso, currentYear) {
  const m = WEEK_RE.exec(iso || '');
  if (!m) return iso || '';
  return 'cw' + m[2] + (Number(m[1]) === currentYear ? '' : '/' + m[1].slice(2));
}

function installWeeklyTrigger() {
  ScriptApp.getProjectTriggers().forEach(t => {
    if (t.getHandlerFunction() === 'generateAllDashboards') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('generateAllDashboards').timeBased()
    .onWeekDay(ScriptApp.WeekDay.MONDAY).atHour(7).create();
  notify_('Weekly trigger installed (Mondays ~07:00, all projects).');
}

// ───────────────────── Input tabs setup (one-off) ─────────────────────

function setupInputSheets() {
  const ss = SpreadsheetApp.getActive();
  const ensure = (name, headers) => {
    const sh = ss.getSheetByName(name) || ss.insertSheet(name);
    sh.getRange(1, 1, 1, headers.length).setValues([headers])
      .setFontWeight('bold').setBackground('#1F4E79').setFontColor('#FFFFFF');
    sh.setFrozenRows(1);
    return sh;
  };

  const projects = ensure(CONFIG.PROJECTS_SHEET, ['Project', 'Release', 'Engine Tab (optional)']);
  if (projects.getLastRow() < 2) projects.getRange('A2:C2').setValues([['Project A', 'R250', CONFIG.DEFAULT_ENGINE_SHEET]]);

  const eq = ensure(CONFIG.EQUIPMENT_SHEET,
    ['Project', 'Test Platform', 'Planned Week', 'Achieved Week', 'Status', 'Updated By', 'Updated At']);
  eq.getRange('A:E').setNumberFormat('@'); // keep "2026-W43" as text
  eq.getRange('G:G').setNumberFormat('dd.mm.yyyy hh:mm');
  eq.getRange('E2:E').setDataValidation(SpreadsheetApp.newDataValidation()
    .requireValueInList(CONFIG.STATUSES, true).setAllowInvalid(false).build());
  const status = eq.getRange('E2:E');
  const fillRule = (value, color) => SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=$E2="' + value + '"').setBackground(color).setRanges([status]).build();
  eq.setConditionalFormatRules([
    fillRule('Ready', CONFIG.STATUS_FILLS.Ready),
    fillRule('Evaluation', CONFIG.STATUS_FILLS.Evaluation),
    fillRule('Blocked', CONFIG.STATUS_FILLS.Blocked),
    SpreadsheetApp.newConditionalFormatRule()
      .whenFormulaSatisfied('=AND($C2<>"",$D2<>"",$D2>$C2)')
      .setFontColor(CONFIG.RED).setRanges([eq.getRange('D2:D')]).build(),
  ]);

  const sup = ensure(CONFIG.SUPPORT_SHEET,
    ['Project', 'No.', 'Action Item', 'Responsible', 'Due Date', 'Status', 'Updated By', 'Updated At']);
  sup.getRange('A:F').setNumberFormat('@');
  sup.getRange('H:H').setNumberFormat('dd.mm.yyyy hh:mm');
  sup.setConditionalFormatRules([SpreadsheetApp.newConditionalFormatRule()
    .whenTextContains(CONFIG.BLOCKER_TOKEN).setFontColor(CONFIG.RED).setRanges([sup.getRange('F2:F')]).build()]);

  // Only the owner edits these tabs directly; TPMs write through the form, which runs as the owner.
  [projects, eq, sup].forEach(sh => {
    sh.getProtections(SpreadsheetApp.ProtectionType.SHEET).forEach(p => p.remove());
    const p = sh.protect().setDescription('Written by the TPM Input form');
    const me = Session.getEffectiveUser();
    p.addEditor(me);
    p.removeEditors(p.getEditors().filter(u => u.getEmail() !== me.getEmail()));
    if (p.canDomainEdit()) p.setDomainEdit(false);
  });

  notify_('Input tabs ready. Add your projects to the Projects tab.');
}
