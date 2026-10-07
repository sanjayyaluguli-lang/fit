# Single source for every copy-paste block in the guide.
T = '\t'
def tsv(rows): return '\n'.join(T.join(str(c) for c in r) for r in rows)

# ---------- sample sources ----------
coverage = [['Level','Total Reqs','Covered Reqs','Moved to R260'],
            ['SYS.4',241,241,0],
            ['SYS.5',442,427,13]]
tc = [['TC_ID','Level','Result','Type']]
s4 = [('Passed','Automated')]*4+[('Passed','Manual')]*2+[('Failed','Manual')]*3+[('Not Run','Manual')]
s5 = [('Passed','Automated')]*4+[('Passed','Manual')]+[('Failed','Automated')]*3+[('Failed','Manual')]+[('Not Run','Manual')]
for i,(r,t) in enumerate(s4,1): tc.append([f'TC-S4-{i:03d}','SYS.4',r,t])
for i,(r,t) in enumerate(s5,1): tc.append([f'TC-S5-{i:03d}','SYS.5',r,t])
bugs = [['Metric','Value'],['Total Bugs',157],['Escaped Bugs',22],
        ['Weekly Comments','1) Clean-up re-triggered 2) Attribute "Origin Sw Type" added 3) Attribute "Origin" implemented']]

# ---------- dashboard sheet ----------
raw = [['REQ_TRACKER_SHEET_URL','PASTE_REQUIREMENTS_TRACKER_URL_HERE'],
       ['BUGTRACKER_SHEET_URL','PASTE_BUG_TRACKER_URL_HERE'],
       [''],
       ['=IMPORTRANGE($B$1,"Coverage!A1:D3")','','','','','=IMPORTRANGE($B$2,"Summary!A1:B3")'],
       [''],[''],[''],[''],
       ['=IMPORTRANGE($B$1,"TestCases!A1:D5000")','','','','','=IMPORTRANGE($B$2,"Summary!B4")']]
# row 9 holds A9 and F... but F10 is required; fix: F10 sits one row lower
raw[8] = ['=IMPORTRANGE($B$1,"TestCases!A1:D5000")']
raw.append(['','','','','','=IMPORTRANGE($B$2,"Summary!B4")'])

def lvl(l, base):
    b=base
    return [
     [f'{l}_TOTAL',  f'=IFERROR(VLOOKUP("{l[:3]}.{l[3]}",Raw_Data!$A$5:$D$6,2,FALSE),0)','from Requirements tracker'],
     [f'{l}_COVERED',f'=IFERROR(VLOOKUP("{l[:3]}.{l[3]}",Raw_Data!$A$5:$D$6,3,FALSE),0)',''],
     [f'{l}_COVERAGE',f'=IF(B{b}=0,0,B{b+1}/B{b})','format 0.0%'],
     [f'{l}_UNCOVERED',f'=B{b}-B{b+1}',''],
     [f'{l}_MOVED',  f'=IFERROR(VLOOKUP("{l[:3]}.{l[3]}",Raw_Data!$A$5:$D$6,4,FALSE),0)','moved to next release']]
L='Raw_Data!$B$10:$B'; R='Raw_Data!$C$10:$C'; Y='Raw_Data!$D$10:$D'
def tcs(l, b):
    n=f'"{l[:3]}.{l[3]}"'
    return [[f'{l}_TC_PLANNED',f'=COUNTIFS({L},{n})',''],
            [f'{l}_TC_EXECUTED',f'=B{b+2}+B{b+3}','passed + failed'],
            [f'{l}_TC_PASSED',f'=COUNTIFS({L},{n},{R},"Passed")',''],
            [f'{l}_TC_FAILED',f'=COUNTIFS({L},{n},{R},"Failed")','']]
def auto(l, b, planned):
    n=f'"{l[:3]}.{l[3]}"'
    return [[f'{l}_AUTO_COUNT',f'=COUNTIFS({L},{n},{Y},"Automated")',''],
            [f'{l}_MANUAL_COUNT',f'=COUNTIFS({L},{n},{Y},"Manual")',''],
            [f'{l}_AUTO_RATE',f'=IF(B{planned}=0,0,B{b}/B{planned})','format 0.0%']]
engine = [['Key','Value','Notes']] + lvl('SYS4',2) + lvl('SYS5',7) + [
 ['COVERAGE_NOTE','=IF((B5+B10)=0,"100% coverage achieved","Note: "&(B5+B10)&"/"&(B2+B7)&" reqs uncovered, "&(B6+B11)&"/"&(B5+B10)&" uncovered reqs shall be moved to R260")',''],
 ['BUG_TOTAL','=IFERROR(VALUE(Raw_Data!G5),0)','from Bug tracker'],
 ['BUG_ESCAPED','=IFERROR(VALUE(Raw_Data!G6),0)',''],
 ['BUG_RATE','=IF(B13=0,0,B14/B13)','format 0.00%'],
 ['BUG_COMMENT','=IFERROR(Raw_Data!F10,"")','weekly comment, linked']] + tcs('SYS4',17) + tcs('SYS5',21) + auto('SYS4',25,17) + auto('SYS5',28,21)
assert len(engine)==30, len(engine)
keys={r[0]:i+1 for i,r in enumerate(engine)}
assert keys['SYS4_COVERAGE']==4 and keys['SYS5_COVERAGE']==9 and keys['BUG_RATE']==15 and keys['SYS4_AUTO_RATE']==27 and keys['SYS5_AUTO_RATE']==30 and keys['SYS4_TC_PLANNED']==17 and keys['SYS5_TC_FAILED']==24

dash = [['SYS VAL chart data – every cell points at Calculation_Engine']]
blocks=[('SYS.4 coverage',4),('SYS.5 coverage',9),('SYS.4 automation',27),('SYS.5 automation',30),('Bug escape rate',15)]
for i,(title,row) in enumerate(blocks):
    top=2+i*4
    dash += [[title],['Covered' if 'coverage' in title else ('Automated' if 'automation' in title else 'Escaped'),f'=Calculation_Engine!B{row}'],
             ['Remaining',f'=MAX(0,1-B{top+1})'],['']]
while len(dash)<22: dash.append([''])
dash += [['Level','Passed','Failed','Not executed'],
         ['SYS.4','=Calculation_Engine!B19','=Calculation_Engine!B20','=Calculation_Engine!B17-Calculation_Engine!B18'],
         ['SYS.5','=Calculation_Engine!B23','=Calculation_Engine!B24','=Calculation_Engine!B21-Calculation_Engine!B22']]
assert dash[2][1]=='=Calculation_Engine!B4' and dash[3][1]=='=MAX(0,1-B3)' and dash[22][0]=='Level'

projects=[['Project','Release','Engine Tab (optional)'],['Project A','R250','Calculation_Engine']]

# ---------- expected values for the sample ----------
def count(l,res=None,typ=None): return sum(1 for r in tc[1:] if r[1]==l and (res is None or r[2]==res) and (typ is None or r[3]==typ))
exp = {}
for l,key in (('SYS.4','SYS4'),('SYS.5','SYS5')):
    row=[r for r in coverage if r[0]==l][0]
    exp[key+'_COVERAGE']=f'{row[2]/row[1]*100:.1f}%'
    p,f=count(l,'Passed'),count(l,'Failed')
    exp[key+'_TC_PLANNED']=count(l); exp[key+'_TC_EXECUTED']=p+f; exp[key+'_TC_PASSED']=p; exp[key+'_TC_FAILED']=f
    exp[key+'_AUTO_RATE']=f'{count(l,typ="Automated")/count(l)*100:.1f}%'
exp['BUG_RATE']=f'{22/157*100:.2f}%'
unc=sum(r[1]-r[2] for r in coverage[1:]); tot=sum(r[1] for r in coverage[1:]); mv=sum(r[3] for r in coverage[1:])
exp['COVERAGE_NOTE']=f'Note: {unc}/{tot} reqs uncovered, {mv}/{unc} uncovered reqs shall be moved to R260'
