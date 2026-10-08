import html, data as D
E = html.escape
GH = 'https://github.com/sanjayyaluguli-lang/fit/blob/claude/hopeful-mayer-6tuncf/sys-val-dashboard/'

def grid(rows, cols=None, start=1, hl=None, maxrows=None, first_col_label=True):
    rows = rows[:maxrows] if maxrows else rows
    n = max(len(r) for r in rows)
    letters = [chr(65+i) for i in range(n)]
    h = '<div class="scroll"><table class="g"><tr><th></th>' + ''.join(f'<th>{c}</th>' for c in letters) + '</tr>'
    for i, r in enumerate(rows):
        h += f'<tr><td class="rn">{start+i}</td>' + ''.join(
            f'<td class="mono{" f" if str(v).startswith("=") else ""}">{E(str(v))}</td>' for v in list(r)+['']*(n-len(r))) + '</tr>'
    return h + '</table></div>'

def copy(id_, label, text, where):
    return (f'<div class="copy"><div class="copy-h"><span><b>{E(label)}</b> · paste at <code>{where}</code></span>'
            f'<button type="button" class="cbtn" data-copy="{id_}">Copy</button></div>'
            f'<textarea id="{id_}" readonly rows="4" spellcheck="false">{E(text)}</textarea></div>')

def check(items):
    return '<div class="check"><b>You should see</b><ul>' + ''.join(f'<li>{i}</li>' for i in items) + '</ul></div>'

def step(n, part, title, why, body):
    return (f'<section class="step" id="s{n}" data-s="{n}"><div class="num">{n}</div><div class="body">'
            f'<div class="part">{part}</div><h2>{title}</h2><p class="why">{why}</p>{body}'
            f'<label class="done-row"><input type="checkbox" id="done{n}"> Step {n} done</label></div></section>')

def ol(items, start=1): return f'<ol class="do" start="{start}">' + ''.join(f'<li>{i}</li>' for i in items) + '</ol>'

def shot(inner, cap): return f'<div class="shot">{inner}<div class="cap">{cap}</div></div>'

X = D.exp
steps = []

steps.append(step(1, 'Before you start', 'Collect the three files and a Drive folder',
 'Everything you paste later comes from these files. The destination folder is where the weekly decks will appear.',
 ol([f'Open <a href="{GH}Code.gs" target="_blank" rel="noopener">Code.gs</a>, <a href="{GH}InputForm.html" target="_blank" rel="noopener">InputForm.html</a> and <a href="{GH}SYS_VAL_Dashboard_Template.pptx" target="_blank" rel="noopener">SYS_VAL_Dashboard_Template.pptx</a> on GitHub (sign in if asked; the repository is yours).',
     'For each of the two code files, click <b>Raw</b> (top right of the file), then <b>Ctrl+A</b>, <b>Ctrl+C</b> when you need it in step 7. For the .pptx click <b>Download raw file</b> (the download arrow).',
     'In Google Drive click <b>+ New → New folder</b>, name it <code>SYS VAL Decks</code>, and open it.',
     'Copy the folder ID from the address bar and keep it in a note: <code>drive.google.com/drive/folders/<span class="hl">0B9q…Lk7</span></code>.'])
 + '<p class="warn">You need a Google Workspace account. Personal Gmail works for testing, but the form cannot record who saved and TPMs outside your organisation cannot open it.</p>'))

steps.append(step(2, 'Test data', 'Create two sample tracker sheets (recommended)',
 'With known sample numbers you can confirm every formula before you point the dashboard at the real trackers. Skip this step if your Requirements tracker and Bug tracker sheets already have the tabs below.',
 '<h3>2a · Sample Requirements tracker</h3>' + ol([
   'Open <b>sheets.new</b> and name the file <code>SAMPLE Requirements tracker</code>.',
   'Double-click the tab <b>Sheet1</b> at the bottom and rename it to <code>Coverage</code>.',
   'Click cell <b>A1</b>, press <b>Copy</b> on the block below, then <b>Ctrl+V</b>.'])
 + copy('c_cov','Coverage tab',D.tsv(D.coverage),'Coverage!A1')
 + ol(['Click the <b>+</b> at the bottom left to add a tab, rename it <code>TestCases</code>, click <b>A1</b> and paste the next block.'], 4)
 + copy('c_tc','TestCases tab',D.tsv(D.tc),'TestCases!A1')
 + '<h3>2b · Sample Bug tracker</h3>' + ol([
   'Open <b>sheets.new</b>, name it <code>SAMPLE Bug tracker</code>, rename the tab to <code>Summary</code>, click <b>A1</b> and paste.'])
 + copy('c_bug','Summary tab',D.tsv(D.bugs),'Summary!A1')
 + check(['Coverage tab: 3 rows (header, SYS.4, SYS.5).','TestCases tab: 21 rows (header + 20 test cases).','Summary tab: 4 rows, with the weekly comment in B4.'])
 + '<p class="hint">Your real trackers must use the same tab names and column order, or you adjust the ranges in step 4.</p>'))

steps.append(step(3, 'Build the Sheet', 'Create the dashboard Sheet and its tabs',
 'The script finds tabs by name, so the spelling must match exactly.',
 ol(['Open <b>sheets.new</b> and name the file <code>SYS VAL Dashboard</code> (click "Untitled spreadsheet" top left).',
     'Double-click <b>Sheet1</b> and rename it <code>Raw_Data</code>.',
     'Click <b>+</b> (bottom left) twice more and rename the new tabs <code>Calculation_Engine</code> and <code>Dashboard</code>.'])
 + shot('<div class="tabs"><span class="plus">+</span><span class="on">Raw_Data</span><span>Calculation_Engine</span><span>Dashboard</span><span class="ghost">Projects</span><span class="ghost">TPM_Equipment</span><span class="ghost">TPM_Support</span></div>',
        'Bottom tab bar. The faded tabs are created by the script in step 8; do not create them yourself.')))

steps.append(step(4, 'Build the Sheet', 'Fill Raw_Data and connect the trackers',
 'Raw_Data pulls the tracker numbers in. Nothing in it is typed by hand except the two URLs.',
 ol(['Open the <b>Raw_Data</b> tab, click <b>A1</b>, press <b>Copy</b> below and <b>Ctrl+V</b>.'])
 + copy('c_raw','Raw_Data layout and formulas',D.tsv(D.raw),'Raw_Data!A1')
 + ol(['Replace <code>B1</code> with the full URL of your Requirements tracker (or the sample from step 2) and <code>B2</code> with the Bug tracker URL. Copy each URL from the browser address bar.',
       'Cells A4, A9, F4 and F10 now show <code>#REF!</code>. Hover over <b>A4</b> and click <b>Allow access</b> in the popup. Do the same for <b>F4</b>. One approval per tracker is enough.',
       'Wait a few seconds for the data to load.'], 2)
 + shot('<div class="pop"><b>#REF!</b><p>You need to connect these sheets.</p><span class="btn p">Allow access</span></div>', 'The popup when you hover over an IMPORTRANGE cell for the first time.')
 + check(['A4:D6 shows the Coverage table, with SYS.4 in row 5 and SYS.5 in row 6.','A9:D29 shows the test-case list (header in row 9).','F4:G6 shows Metric / Total Bugs / Escaped Bugs, and F10 the weekly comment.'])
 + grid(D.raw[:3]+[['Level','Total Reqs','Covered Reqs','Moved to R260','','Metric','Value'],['SYS.4',241,241,0,'','Total Bugs',157],['SYS.5',442,427,13,'','Escaped Bugs',22]], maxrows=6)
 + '<p class="warn">Keep the cells below and to the right of each formula empty. If anything is typed there, the import shows <code>#REF!</code> "Array result was not expanded".</p>'))

expected_rows = ''.join(f'<tr><td class="mono">{k}</td><td>{E(str(v))}</td></tr>' for k,v in X.items())
steps.append(step(5, 'Build the Sheet', 'Paste the Calculation_Engine',
 'This tab turns raw numbers into the KPIs the slide shows. Column A is the placeholder name: the key <code>BUG_RATE</code> fills <code>{{BUG_RATE}}</code> on the slide.',
 ol(['Open the <b>Calculation_Engine</b> tab, click <b>A1</b>, press <b>Copy</b> and <b>Ctrl+V</b>. All 30 rows land in A1:C30.'])
 + copy('c_eng','Calculation_Engine (30 rows)',D.tsv(D.engine),'Calculation_Engine!A1')
 + ol(['Format the percentages. Hold <b>Ctrl</b> and click <b>B4</b>, <b>B9</b>, <b>B27</b>, <b>B30</b>, then choose <b>Format → Number → Custom number format</b>, type <code>0.0%</code> and click <b>Apply</b>.',
       'Click <b>B15</b> and apply the custom format <code>0.00%</code> the same way.'], 2)
 + check(['No cell in column B shows an error.','With the sample data from step 2, column B shows these values:'])
 + f'<div class="scroll"><table class="g exp"><tr><th>Key</th><th>Expected with sample data</th></tr>{expected_rows}</table></div>'
 + '<p class="hint">The script copies each value exactly as displayed, so the number format you set here is what appears on the slide.</p>'))

steps.append(step(6, 'Build the Sheet', 'Build the Dashboard tab and its charts',
 'Dashboard is your in-Sheet overview. Its cells only reference Calculation_Engine, so the charts always match the slide.',
 ol(['Open the <b>Dashboard</b> tab, click <b>A1</b>, press <b>Copy</b> and <b>Ctrl+V</b>.'])
 + copy('c_dash','Dashboard chart data',D.tsv(D.dash),'Dashboard!A1')
 + ol(['Select <b>B3:B4</b> and B7:B8, B11:B12, B15:B16, B19:B20 (hold Ctrl) and apply the custom format <code>0.0%</code>.'], 2)
 + '<h3>6a · Doughnut chart (repeat for each of the 5 blocks)</h3>'
 + ol(['Select <b>A3:B4</b> (SYS.4 coverage).','Choose <b>Insert → Chart</b>. The Chart editor opens on the right.',
       '<b>Setup</b> tab → <b>Chart type</b> → choose <b>Doughnut chart</b>.',
       '<b>Customize</b> tab → <b>Pie chart</b>: set <b>Donut hole</b> to <b>75%</b> and <b>Slice label</b> to <b>None</b>.',
       '<b>Customize</b> → <b>Pie slice</b>: pick "Covered" and choose blue; pick "Remaining" and choose light grey 2.',
       '<b>Customize</b> → <b>Legend</b> → <b>Position: None</b>. <b>Chart &amp; axis titles</b> → type the block title, e.g. <code>SYS.4 coverage</code>.',
       'Repeat with A7:B8, A11:B12, A15:B16 and A19:B20.'])
 + shot('<div class="editor"><div class="et"><span class="on">Setup</span><span>Customize</span></div><div class="er"><span>Chart type</span><b>Doughnut chart ▾</b></div><div class="er"><span>Data range</span><b class="mono">A3:B4</b></div><div class="er"><span>Pie chart › Donut hole</span><b>75%</b></div><div class="er"><span>Legend › Position</span><b>None</b></div></div>','Chart editor settings for one doughnut.')
 + '<h3>6b · Show the percentage in the middle of each ring</h3>'
 + '<p class="hint">Google Sheets cannot write text inside a doughnut hole. The usual workaround is a transparent Scorecard chart placed on top of the ring.</p>'
 + ol(['Click an empty cell, then choose <b>Insert → Chart</b>.',
       '<b>Setup</b> → <b>Chart type</b> → <b>Scorecard chart</b> (under "Other"). Set <b>Key value</b> to <code>B3</code> (B7, B11, B15, B19 for the other rings).',
       '<b>Customize</b> → <b>Chart style</b>: <b>Background colour</b> → <b>None</b>, <b>Border colour</b> → <b>None</b>.',
       '<b>Customize</b> → <b>Key value</b>: <b>Number format</b> → <b>Percent</b> (or Custom <code>0.0%</code>), font size about 24, bold, dark grey.',
       '<b>Customize</b> → <b>Chart &amp; axis titles</b>: leave the title empty.',
       'Close the editor. Drag the scorecard into the hole of the ring and drag its corner until it fits. A chart created later sits on top, so the number stays visible.'])
 + shot('<div class="donut-row"><div class="donut"><svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" fill="none" stroke="var(--navy)" stroke-width="12"/></svg><b>100.0%</b></div><div class="editor" style="margin:0;flex:1 1 260px"><div class="et"><span class="on">Setup</span><span>Customize</span></div><div class="er"><span>Chart type</span><b>Scorecard chart</b></div><div class="er"><span>Key value</span><b class="mono">B3</b></div><div class="er"><span>Background colour</span><b>None</b></div><div class="er"><span>Number format</span><b>Percent</b></div></div></div>','The scorecard (right) dragged into the ring gives the result on the left.')
 + '<p class="hint">Quicker but less tidy: in the doughnut\'s <b>Customize → Pie chart</b>, set <b>Slice label</b> to <b>Percentage</b>. The value then appears on the ring itself instead of in the middle.</p>'
 + '<h3>6c · Stacked bar chart (test execution)</h3>'
 + ol(['Select <b>A23:D25</b> and choose <b>Insert → Chart</b>.','<b>Setup</b> → <b>Chart type</b> → <b>Stacked bar chart</b>. Tick <b>Use row 23 as headers</b> and <b>Use column A as labels</b>.',
       '<b>Customize</b> → <b>Series</b>: Passed light green, Failed red, Not executed light grey.'])
 + check(['Five doughnuts, each with its percentage in the middle, and one stacked bar. With the sample: SYS.4 coverage ring full (100%), bug ring at about one seventh (14%).','Stacked bars: SYS.4 = 6 passed, 3 failed, 1 not executed; SYS.5 = 5 / 4 / 1.'])))

steps.append(step(7, 'Script and form', 'Paste the script and the form into Apps Script',
 'The script reads the Sheet and builds the deck. The HTML file is the input form TPMs use.',
 ol(['In the dashboard Sheet choose <b>Extensions → Apps Script</b>. A new tab opens with a file <code>Code.gs</code> containing <code>function myFunction() {}</code>.',
     'Rename the project: click <b>Untitled project</b> (top left) and type <code>SYS VAL Dashboard</code>.',
     'Click into <code>Code.gs</code>, press <b>Ctrl+A</b>, then paste the full content of <b>Code.gs</b> from step 1.',
     'Click <b>+</b> next to <b>Files</b> → <b>HTML</b>. Type <code>InputForm</code> (without .html) and press Enter. Select all its content and paste <b>InputForm.html</b>.',
     'Back in <code>Code.gs</code>, replace the folder placeholder with your folder ID from step 1. Leave <code>TEMPLATE_ID</code> for step 11.',
     'Press <b>Ctrl+S</b>.'])
 + shot('<div class="ide"><div class="files"><div class="fh">Files <span>+</span></div><div class="on">Code.gs</div><div>InputForm.html</div></div><pre class="code"><span class="c">// Code.gs, lines 11-13</span>\nconst CONFIG = {\n  TEMPLATE_ID: <span class="hl">\'PASTE_TEMPLATE_SLIDES_ID\'</span>,   <span class="c">← step 11</span>\n  FOLDER_ID:   <span class="hl">\'0B9q…Lk7\'</span>,                  <span class="c">← your folder ID</span>\n  ...</pre></div>','The editor after step 7. Keep the quotes around each ID.')
 + check(['Two files in the sidebar: Code.gs and InputForm.html.','No red error bar after saving.'])))

steps.append(step(8, 'Script and form', 'Run the setup and grant permissions',
 'The first run asks for your permission to read and write your Sheet, Slides and Drive. It also creates the three input tabs.',
 ol(['Go back to the Sheet tab and reload the page (<b>F5</b>). After a few seconds a menu <b>Dashboard Generator</b> appears next to Help.',
     'Choose <b>Dashboard Generator → Setup Input Tabs (one-off)</b>.',
     'A dialog "Authorisation required" opens. Click <b>OK</b> or <b>Continue</b>, then pick your account.',
     'If you see "Google hasn\'t verified this app", click <b>Advanced</b>, then <b>Go to SYS VAL Dashboard (unsafe)</b>. This is your own script, so this is expected.',
     'Review the access list (Google Sheets, Slides, Drive, external requests for the form, and triggers) and click <b>Allow</b>.',
     'Run <b>Setup Input Tabs</b> once more if it stopped at the permission screen.'])
 + shot('<div class="menu"><div class="t">Dashboard Generator</div><div>Open TPM Input Form</div><div>Generate Dashboard for a Project…</div><div>Generate All Projects</div><div class="sep"></div><div class="go">Setup Input Tabs (one-off)</div><div>Schedule Weekly (Mon 07:00, all projects)</div></div>'
        '<div class="dlg n"><div class="dt">Google hasn\'t verified this app</div><div class="dr"><span>1.</span><b>Advanced</b></div><div class="dr"><span>2.</span><b class="hl">Go to SYS VAL Dashboard (unsafe)</b></div><div class="dr"><span>3.</span><b>Allow</b></div></div>',
        'The menu, and the three clicks on the warning screen.')
 + check(['Three new tabs: Projects, TPM_Equipment, TPM_Support, with dark blue header rows.','Projects already contains one row: Project A, R250, Calculation_Engine.','A toast at the bottom right: "Input tabs ready".'])))

steps.append(step(9, 'Script and form', 'List your projects',
 'The Projects tab fills the dropdown in the form and the {{PROJECT}} and {{RELEASE}} placeholders on the slide.',
 ol(['Open the <b>Projects</b> tab. Overwrite <b>Project A</b> with your real project name and <b>R250</b> with its release.',
     'Add one row per further project. Names must be unique; TPMs pick from exactly these names.',
     'Leave column C empty unless the project has its own trackers (see the note).'])
 + copy('c_proj','Projects tab (example)',D.tsv(D.projects+[['Project B','R260','']]),'Projects!A1')
 + '<p class="warn"><b>Different trackers per project:</b> right-click the <b>Raw_Data</b> tab → <b>Duplicate</b>, rename the copy <code>Raw_Data_B</code> and change its two URLs. Duplicate <b>Calculation_Engine</b> as <code>Calculation_Engine_B</code>, then use <b>Edit → Find and replace</b> on that tab only: find <code>Raw_Data!</code>, replace with <code>Raw_Data_B!</code>. Put <code>Calculation_Engine_B</code> in column C for that project.</p>'))

steps.append(step(10, 'Script and form', 'Publish the form as a web app',
 'Publishing gives you one link for all TPMs. The form runs as you, so TPMs need no access to the Sheet and cannot edit it directly.',
 ol(['In the Apps Script tab click <b>Deploy</b> (blue button, top right) → <b>New deployment</b>.',
     'Click the gear icon next to <b>Select type</b> → <b>Web app</b>.',
     'Description: <code>TPM Input v1</code>. <b>Execute as</b>: <b>Me</b>. <b>Who has access</b>: <b>Anyone within &lt;your organisation&gt;</b>.',
     'Click <b>Deploy</b>. Approve permissions again if asked.',
     'Copy the <b>Web app URL</b> (ends in <code>/exec</code>) and click <b>Done</b>.',
     'Open the URL in a new tab to test it, then send it to your TPMs.'])
 + shot('<div class="dlg"><div class="dt">New deployment · Web app</div><div class="dr"><span>Description</span><b>TPM Input v1</b></div><div class="dr"><span>Execute as</span><b class="hl">Me (you@company.com)</b></div><div class="dr"><span>Who has access</span><b class="hl">Anyone within your organisation</b></div><div class="dr"><span>Web app URL</span><b class="mono">https://script.google.com/a/macros/…/exec</b></div></div>','The deployment dialog with the two settings that matter.')
 + check(['The URL opens the form, the dropdown lists your projects, and the bottom bar shows Save and Generate deck.'])
 + '<p class="warn">After any change to the code: <b>Deploy → Manage deployments</b> → pencil icon → <b>Version: New version</b> → <b>Deploy</b>. The URL stays the same. Without this, TPMs keep getting the old form.</p>'))

steps.append(step(11, 'Slides', 'Turn the template into Google Slides',
 'The script copies this deck every week and fills its placeholders.',
 ol(['In Google Drive click <b>+ New → File upload</b> and choose <code>SYS_VAL_Dashboard_Template.pptx</code>.',
     'Right-click the uploaded file → <b>Open with → Google Slides</b>.',
     'In Slides choose <b>File → Save as Google Slides</b>. A second, native copy opens. You can delete the .pptx afterwards.',
     'Rename the new deck <code>SYS VAL Dashboard TEMPLATE</code>.',
     'Copy its ID from the address bar: <code>docs.google.com/presentation/d/<span class="hl">1AbC…xYz</span>/edit</code>.',
     'Paste it into <code>TEMPLATE_ID</code> in Code.gs, save, and deploy a new version (step 10 note).'])
 + shot('<div class="slide"><div class="head"><span><span class="ph">{{PROJECT}}</span> · REL <span class="ph">{{RELEASE}}</span></span><span class="badge">Updated cw<span class="ph">{{CW}}</span></span></div><div class="card"><h4>TEST EQUIPMENT STATUS</h4><span><span class="ph">{{EQ_PLATFORM_1}}</span> <span class="ph">{{EQ_STATUS_1}}</span></span><span>… rows 2 to 8</span></div><div class="card"><h4>COVERAGE · BUG ESCAPE</h4><span class="ph">{{SYS5_COVERAGE}}</span><span class="ph">{{BUG_RATE}}</span></div><div class="card" style="grid-column:1/-1"><h4>SUPPORT REQUIRED</h4><span><span class="ph">{{ACTION_1}}</span> <span class="ph">{{RESP_1}}</span> <span class="ph">{{DUE_1}}</span> <span class="ph">{{STATUS_1}}</span></span></div></div>','Simplified view of the template. Every yellow chip is a placeholder already in the file.')
 + check(['The deck shows text such as {{PROJECT}} and {{SYS5_COVERAGE}}. Do not edit or retype these; one wrong character and that value is not filled.','To move or restyle a box, drag it; the placeholder text stays intact.'])))

steps.append(step(12, 'Run it', 'Enter test data in the form',
 'This checks that the form can write to the Sheet.',
 ol(['Open the web app URL and pick your project.',
     'Test Equipment: type <code>Veh 1</code>, planned <code>Week 43</code>, achieved <code>Week 50</code>, status <b>Ready</b>. Add a second row <code>RadarView</code>, planned Week 45, status <b>Blocked</b>.',
     'Support Required row 1: Action <code>XCP Implementation for SYS.4 pending</code>, Responsible your name, Due <code>R3.1_last (28.4.26)</code>, Status <code>BLOCKER: specific binary needed</code>.',
     'Click <b>Save</b>.'])
 + shot('<div class="scroll"><table class="g"><tr><th>Test Platform</th><th>Planned Week</th><th>Achieved Week</th><th>Status</th></tr><tr><td>Veh 1</td><td>Week 43, 2026</td><td class="late">Week 50, 2026</td><td class="s-ready">Ready</td></tr><tr><td>RadarView</td><td>Week 45, 2026</td><td></td><td class="s-block">Blocked</td></tr></table></div><div class="scroll"><table class="g"><tr><th>N°</th><th>Action Item</th><th>Responsible</th><th>Due Date</th><th>Status</th></tr><tr><td>1</td><td>XCP Implementation for SYS.4 pending</td><td>J. Doe</td><td>R3.1_last (28.4.26)</td><td class="red">BLOCKER: specific binary needed</td></tr></table></div>','The form while you type: the late week and the BLOCKER status turn red straight away.')
 + check(['Green message "Saved for &lt;project&gt;." and "Last saved … by you@…" under the title.','In the Sheet, TPM_Equipment has 2 rows and TPM_Support 1 row for your project, with your email and time.'])))

steps.append(step(13, 'Run it', 'Generate the first deck',
 'This is the full pipeline: tracker numbers, form input and template come together in a new deck.',
 ol(['In the form click <b>Generate deck</b>. It takes about 20 seconds.',
     'Click <b>Open deck</b> in the green message. The deck is also in your <code>SYS VAL Decks</code> folder.',
     'From the Sheet you can also use <b>Dashboard Generator → Generate Dashboard for a Project…</b> (type the exact project name) or <b>Generate All Projects</b>.'])
 + check([f'The file is named <code>SYS VAL DASHBOARD &lt;project&gt; CW&lt;week&gt;</code>.',
          'Top: your project name, its release, and "Updated cw" plus the current week.',
          f'Coverage {X["SYS4_COVERAGE"]} and {X["SYS5_COVERAGE"]}, bug escape rate {X["BUG_RATE"]}, and the red note "{E(X["COVERAGE_NOTE"])}" (sample data).',
          'Test Equipment shows 2 rows (the other 6 are removed); Ready is green, Blocked light red, and cw50 is red because it is later than cw43.',
          'Support Required row 1 is filled and its status is red; rows 2 and 3 are empty.',
          'No text in double braces remains. If some does, see Troubleshooting.'])))

steps.append(step(14, 'Run it', 'Schedule the weekly run and go live',
 'From now on one deck per project is created every Monday morning.',
 ol(['In the Sheet choose <b>Dashboard Generator → Schedule Weekly (Mon 07:00, all projects)</b>.',
     'Check it in Apps Script: click the clock icon <b>Triggers</b> in the left bar. You should see one trigger: <code>generateAllDashboards</code>, Time-based, Week timer, Every Monday, 7am to 8am.',
     'Switch Raw_Data B1/B2 from the sample sheets to the real Requirements tracker and Bug tracker (allow access again).',
     'Delete the test rows: open the form, clear them, Save.',
     'Tell TPMs to save by Friday each week. The form shows when each project was last saved.'])
 + shot('<div class="scroll"><table class="g"><tr><th>Function</th><th>Event</th><th>Schedule</th></tr><tr><td class="mono">generateAllDashboards</td><td>Time-based</td><td>Every Monday, 7am to 8am</td></tr></table></div>','Apps Script → Triggers after scheduling. Running the menu item again replaces it rather than adding a second one.')))

trouble = [
 ('<code>Set TEMPLATE_ID and FOLDER_ID in CONFIG first</code>','An ID is still a placeholder, or the quotes were removed. Fix it, save, and deploy a new version.'),
 ('<code>Tab "Projects" not found</code>','Run Setup Input Tabs (step 8). Check the tab names have no trailing space.'),
 ('<code>Unknown project "…"</code>','The name typed or sent does not exactly match the Projects tab.'),
 ('Form says "No projects yet"','Add at least one row to the Projects tab.'),
 ('Form behaves like an older version','Deploy a new version (step 10 note).'),
 ('"Last saved … by unknown"','The TPM is outside your Google Workspace organisation, so Google hides their email.'),
 ('<code>#REF!</code> "You need to connect these sheets"','Hover the cell and click Allow access (step 4).'),
 ('<code>#REF!</code> "Array result was not expanded"','Something is typed in the cells an import needs. Clear the area below or right of the formula.'),
 ('Values on the slide show as 0.997 instead of 99.7%','Set the percent format on that Calculation_Engine cell (step 5).'),
 ('Text in double braces left in the deck','The key does not exist or is spelled differently. The toast and View → Executions in Apps Script list the unmatched placeholders.'),
 ('"Exception: You do not have permission"','Run any menu item once yourself and accept the permissions (step 8). For the trigger, you must be the one who created it.'),
 ('Deck generation stops after 6 minutes','Apps Script time limit. Generate projects one by one, or fewer projects per run.'),
]
trows = ''.join(f'<tr><td>{a}</td><td>{b}</td></tr>' for a,b in trouble)

nav = ''.join(f'<a href="#s{i}">{i}</a>' for i in range(1,15))
parts = [('Before you start',1),('Test data',2),('Build the Sheet',3),('Script and form',7),('Slides',11),('Run it',12)]

css_extra = open('extra.css').read()
base = open('base.css').read()
page = f'''<title>SYS VAL Dashboard Setup</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Semi+Condensed:wght@600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
{base}
{css_extra}
</style>

<div class="wrap">
  <h1>SYS VAL Dashboard Setup</h1>
  <p class="lede">A click-by-click manual for the owner of the dashboard. It goes from three files to a weekly Slides deck per project, with TPMs entering Test Equipment and Support Required through a web form. Every formula can be copied with one button, and sample data lets you check each step against known numbers.</p>
  <div class="meta"><span class="pill">About 60 minutes</span><span class="pill l">Copy and paste, no coding</span><span class="pill">14 steps</span></div>
  <div class="flow"><span>Requirements tracker</span><b>+</b><span>Bug tracker</span><b>→</b><span>Raw_Data</span><b>→</b><span>Calculation_Engine</span><b>→</b><span>Code.gs</span><b>→</b><span>Slides deck</span></div>
  <div class="flow"><span>TPM Input form</span><b>→</b><span>TPM_Equipment + TPM_Support</span><b>→</b><span>Code.gs</span></div>

  <div class="progress"><div class="bar"><i id="fill"></i></div><span id="count">0 / 14</span><nav class="jump" aria-label="Jump to step">{nav}</nav></div>

  <div class="howto"><b>How to use the copy blocks:</b> click <b>Copy</b>, click the target cell named in the block (usually A1), press <b>Ctrl+V</b> (<b>Cmd+V</b> on Mac). Google Sheets splits the text into cells and turns lines starting with = into formulas.</div>

{chr(10).join(steps)}

  <section class="ft">
    <h2>If something goes wrong</h2>
    <div class="scroll"><table><tr><th>You see</th><th>Fix</th></tr>{trows}</table></div>
  </section>
</div>

<script>
(function(){{
  var KEY="sysval-setup-ticks-v3", steps=[].slice.call(document.querySelectorAll(".step")), saved={{}};
  try{{saved=JSON.parse(localStorage.getItem(KEY)||"{{}}")}}catch(e){{}}
  var links=[].slice.call(document.querySelectorAll(".jump a"));
  function update(){{
    var n=0,o={{}};
    steps.forEach(function(s,i){{var c=s.querySelector(".done-row input").checked;s.classList.toggle("done",c);if(links[i])links[i].classList.toggle("ok",c);if(c){{n++;o[s.dataset.s]=1}}}});
    document.getElementById("count").textContent=n+" / "+steps.length;
    document.getElementById("fill").style.width=(n/steps.length*100)+"%";
    try{{localStorage.setItem(KEY,JSON.stringify(o))}}catch(e){{}}
  }}
  steps.forEach(function(s){{var i=s.querySelector(".done-row input");i.checked=!!saved[s.dataset.s];i.addEventListener("change",update)}});
  update();
  document.querySelectorAll(".cbtn").forEach(function(b){{
    b.addEventListener("click",function(){{
      var t=document.getElementById(b.dataset.copy);
      function ok(){{b.textContent="Copied";b.classList.add("ok");setTimeout(function(){{b.textContent="Copy";b.classList.remove("ok")}},1800)}}
      function manual(){{t.focus();t.select();b.textContent="Press Ctrl+C"}}
      try{{navigator.clipboard.writeText(t.value).then(ok,manual)}}catch(e){{manual()}}
    }});
  }});
}})();
</script>
'''
open('setup-guide.html','w').write(page)
print('steps', len(steps), 'bytes', len(page))
