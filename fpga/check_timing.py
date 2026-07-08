import re, sys
t = open('impl/pnr/project_tr_content.html', encoding='utf-8', errors='ignore').read()
bad = 0
rows = re.findall(r'<tr[^>]*>(.*?)</tr>', t, re.S)
for r in rows:
    cells = [re.sub(r'<[^>]+>', '', c).strip() for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', r, re.S)]
    if len(cells) == 4 and cells[1] in ('Setup','Hold') and (cells[2] != '0.000' or cells[3] != '0'):
        bad += 1; print('RESUMEN VIOLADO:', cells)
    elif len(cells) == 9 and cells[0] != 'Path Number' and cells[1].startswith('-'):
        bad += 1; print('CAMINO VIOLADO:', cells[1], cells[2], '->', cells[3], f'({cells[4]}->{cells[5]})')
print('TIMING LIMPIO (resumen + path slacks + recovery)' if bad == 0 else f'*** {bad} VIOLACIONES ***')
sys.exit(0 if bad == 0 else 1)
