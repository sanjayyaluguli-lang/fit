/**
 * SYS VAL Project Dashboard – weekly Google Slides generator.
 * Container-bound script of the dashboard Google Sheet.
 * Reads Calculation_Engine (Key | Value) and fills {{KEY}} placeholders in a copy of the template deck.
 */

const CONFIG = {
  TEMPLATE_ID: 'PASTE_TEMPLATE_SLIDES_ID',
  FOLDER_ID: 'PASTE_DESTINATION_FOLDER_ID',
  NAME_PREFIX: 'SYS VAL DASHBOARD',
  ENGINE_SHEET: 'Calculation_Engine',
  INPUT_SHEET: 'TPM_Input',
  SUPPORT_ROWS: 3,
  BLOCKER_TOKEN: 'BLOCKER:',
  BLOCKER_COLOR: '#FF0000',
  TIMEZONE: Session.getScriptTimeZone(),
};

// ───────────────────────────── UI ─────────────────────────────

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Dashboard Generator')
    .addItem('1. Setup TPM_Input (validation, colours, lock)', 'setupTpmInput')
    .addItem('2. Generate Dashboard Now', 'generateDashboard')
    .addItem('3. Schedule Weekly (Mon 07:00)', 'installWeeklyTrigger')
    .addToUi();
}

function notify_(msg) {
  Logger.log(msg);
  try { SpreadsheetApp.getActive().toast(msg, 'Dashboard Generator', 10); } catch (e) { /* trigger run */ }
}

// ───────────────────────── Main pipeline ─────────────────────────

function generateDashboard() {
  if (CONFIG.TEMPLATE_ID.indexOf('PASTE') === 0 || CONFIG.FOLDER_ID.indexOf('PASTE') === 0) {
    throw new Error('Set TEMPLATE_ID and FOLDER_ID in CONFIG first.');
  }
  SpreadsheetApp.flush(); // let IMPORTRANGE / formulas settle

  const now = new Date();
  const cw = isoWeek_(now);
  const values = readEngineValues_();
  values.CW = String(cw);
  values.REPORT_DATE = Utilities.formatDate(now, CONFIG.TIMEZONE, 'dd.MM.yyyy');

  // 1. Duplicate the template
  const name = CONFIG.NAME_PREFIX + ' CW' + cw;
  const copy = DriveApp.getFileById(CONFIG.TEMPLATE_ID)
    .makeCopy(name, DriveApp.getFolderById(CONFIG.FOLDER_ID));
  const pres = SlidesApp.openById(copy.getId());

  // 2. Support Required cells first: replace + red text for BLOCKER
  applyStatusPlaceholders_(pres, values);

  // 3. Every remaining placeholder (blank values become empty strings)
  Object.keys(values).forEach(function (key) {
    pres.replaceAllText('{{' + key + '}}', values[key]);
  });

  warnLeftoverPlaceholders_(pres);
  pres.saveAndClose();

  notify_('Created "' + name + '": ' + copy.getUrl());
  return copy.getUrl();
}

/** Reads Calculation_Engine A:B as {KEY: displayValue}. Errors become 'n/a' (or '' for support rows). */
function readEngineValues_() {
  const sheet = SpreadsheetApp.getActive().getSheetByName(CONFIG.ENGINE_SHEET);
  if (!sheet) throw new Error('Sheet not found: ' + CONFIG.ENGINE_SHEET);
  const lastRow = sheet.getLastRow();
  const rows = lastRow > 1 ? sheet.getRange(2, 1, lastRow - 1, 2).getDisplayValues() : [];
  const out = {};
  rows.forEach(function (r) {
    const key = String(r[0]).trim();
    if (!key) return;
    let val = String(r[1]);
    if (/^#(N\/A|REF!|VALUE!|DIV\/0!|NAME\?|ERROR!|NUM!)/.test(val)) {
      Logger.log('Formula error in ' + key + ': ' + val);
      val = /^(ACTION|RESP|DUE|STATUS)_\d+$/.test(key) ? '' : 'n/a';
    }
    out[key] = val;
  });
  // Guarantee all support placeholders exist -> blank row = empty string
  for (let n = 1; n <= CONFIG.SUPPORT_ROWS; n++) {
    ['ACTION_', 'RESP_', 'DUE_', 'STATUS_'].forEach(function (p) {
      if (!(p + n in out)) out[p + n] = '';
    });
  }
  return out;
}

/** Replaces {{STATUS_n}} and colours the whole cell/shape text red when it contains "BLOCKER:". */
function applyStatusPlaceholders_(pres, values) {
  pres.getSlides().forEach(function (slide) {
    collectTextGetters_(slide.getPageElements()).forEach(function (getText) {
      for (let n = 1; n <= CONFIG.SUPPORT_ROWS; n++) {
        const token = '{{STATUS_' + n + '}}';
        if (getText().asString().indexOf(token) === -1) continue;
        const val = values['STATUS_' + n] || '';
        getText().replaceAllText(token, val);
        if (val.indexOf(CONFIG.BLOCKER_TOKEN) !== -1) {
          // re-fetch the range: the old one is stale after the replacement
          getText().getTextStyle().setForegroundColor(CONFIG.BLOCKER_COLOR);
        }
      }
    });
  });
}

/** Returns functions that fetch a fresh TextRange for every shape / table cell (groups included). */
function collectTextGetters_(elements) {
  const getters = [];
  elements.forEach(function (el) {
    switch (el.getPageElementType()) {
      case SlidesApp.PageElementType.SHAPE: {
        const shape = el.asShape();
        getters.push(function () { return shape.getText(); });
        break;
      }
      case SlidesApp.PageElementType.TABLE: {
        const table = el.asTable();
        for (let r = 0; r < table.getNumRows(); r++) {
          for (let c = 0; c < table.getNumColumns(); c++) {
            (function (cell) { getters.push(function () { return cell.getText(); }); })(table.getCell(r, c));
          }
        }
        break;
      }
      case SlidesApp.PageElementType.GROUP:
        getters.push.apply(getters, collectTextGetters_(el.asGroup().getChildren()));
        break;
    }
  });
  return getters;
}

function warnLeftoverPlaceholders_(pres) {
  const left = {};
  pres.getSlides().forEach(function (slide) {
    collectTextGetters_(slide.getPageElements()).forEach(function (getText) {
      (getText().asString().match(/\{\{[A-Z0-9_]+\}\}/g) || []).forEach(function (m) { left[m] = true; });
    });
  });
  const keys = Object.keys(left);
  if (keys.length) notify_('Unreplaced placeholders (no matching key): ' + keys.join(', '));
}

// ───────────────────────── Helpers ─────────────────────────

/** ISO-8601 calendar week number. */
function isoWeek_(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
}

function installWeeklyTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'generateDashboard') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('generateDashboard').timeBased()
    .onWeekDay(ScriptApp.WeekDay.MONDAY).atHour(7).create();
  notify_('Weekly trigger installed (Mondays ~07:00).');
}

// ───────────────────── TPM_Input setup (one-off) ─────────────────────

function setupTpmInput() {
  const ss = SpreadsheetApp.getActive();
  const sh = ss.getSheetByName(CONFIG.INPUT_SHEET) || ss.insertSheet(CONFIG.INPUT_SHEET);

  sh.getRange('A2').setValue('Test Equipment Status').setFontWeight('bold');
  sh.getRange('F2').setValue('Support Required').setFontWeight('bold');
  sh.getRange('A3:D3').setValues([['Test Platform', 'Planned Date', 'Achieved Date', 'Status']]);
  sh.getRange('F3:J3').setValues([['No.', 'Action Item', 'Responsible', 'Due Date', 'Status']]);
  sh.getRangeList(['A3:D3', 'F3:J3']).setFontWeight('bold').setBackground('#1F4E79').setFontColor('#FFFFFF');
  sh.getRange('F4:F6').setValues([[1], [2], [3]]);
  sh.getRange('B4:C15').setNumberFormat('dd.mm.yyyy');
  sh.getRange('I4:I6').setNumberFormat('dd.mm.yyyy');

  // Data validation
  sh.getRange('D4:D15').setDataValidation(SpreadsheetApp.newDataValidation()
    .requireValueInList(['Ready', 'Evaluation', 'Blocked'], true)
    .setAllowInvalid(false).setHelpText('Ready, Evaluation or Blocked').build());
  sh.getRange('B4:C15').setDataValidation(SpreadsheetApp.newDataValidation()
    .requireDate().setAllowInvalid(false).setHelpText('Enter a valid date').build());
  sh.getRange('J4:J6').setNote('Prefix with "BLOCKER:" to show this status in red on the slide.');

  // Conditional formatting
  const status = sh.getRange('D4:D15');
  const rule = function (formula, bg) {
    return SpreadsheetApp.newConditionalFormatRule()
      .whenFormulaSatisfied(formula).setBackground(bg).setRanges([status]).build();
  };
  const lateRule = SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=AND(ISNUMBER($B4),ISNUMBER($C4),$C4>$B4)')
    .setFontColor('#FF0000').setRanges([sh.getRange('C4:C15')]).build();
  sh.setConditionalFormatRules([
    rule('=$D4="Ready"', '#92D050'),
    rule('=$D4="Evaluation"', '#FFC000'),
    rule('=$D4="Blocked"', '#F4CCCC'),
    lateRule,
  ]);

  // Protection: everything locked except the input ranges
  sh.getProtections(SpreadsheetApp.ProtectionType.SHEET).forEach(function (p) { p.remove(); });
  const p = sh.protect().setDescription('TPM input – only input ranges editable');
  p.setUnprotectedRanges([sh.getRange('A4:D15'), sh.getRange('G4:J6')]);
  const me = Session.getEffectiveUser();
  p.addEditor(me);
  p.removeEditors(p.getEditors().filter(function (u) { return u.getEmail() !== me.getEmail(); }));
  if (p.canDomainEdit()) p.setDomainEdit(false);

  notify_('TPM_Input configured.');
}
