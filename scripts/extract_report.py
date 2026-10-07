#!/usr/bin/env python3
"""Extract the supplied report without correcting its SQL or prose (stdlib only)."""
import argparse
import hashlib
import json
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / 'local'
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
BLOCKS = {
    'migrations/001_init.up.sql': [(491, 622)],
    'migrations/001_init.down.sql': [(626, 637)],
    'migrations/002_add_scrape_run_status_check.up.sql': [(640, 641)],
    'migrations/002_add_scrape_run_status_check.down.sql': [(644, 645)],
    'sql/seed/report_test.sql': [(702, 789)],
    'sql/scenarios/01_user.sql': [(794, 801), (803, 806)],
    'sql/scenarios/02_source.sql': [(811, 818), (821, 828), (831, 834), (837, 849)],
    'sql/scenarios/03_news.sql': [(857, 860), (862, 877), (879, 889)],
    'sql/negative/01_email_unique.sql': [(897, 902)],
    'sql/negative/02_user_role_fk.sql': [(906, 911)],
    'sql/negative/03_source_status_check.sql': [(916, 921)],
    'sql/negative/04_news_title_not_null.sql': [(925, 938)],
    'sql/negative/05_news_source_fk.sql': [(942, 955)],
    'sql/negative/06_news_url_unique.sql': [(959, 972)],
}


def text_of(el):
    parts = []
    for child in el.iter():
        if child.tag == W + 't':
            parts.append(child.text or '')
        elif child.tag == W + 'br':
            parts.append('\n')
        elif child.tag == W + 'tab':
            parts.append('\t')
    return ''.join(parts)


def extract(source, check=False):
    with ZipFile(source) as archive:
        root = ET.fromstring(archive.read('word/document.xml'))
        body = root.find(W + 'body')
        elements = list(body)
    manifest = {'source': 'local/source/report.docx',
                'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'indexing': '0-based direct children of w:body, including empty paragraphs and tables',
                'normalization': 'UTF-8, LF, one newline between Word paragraphs; SQL unchanged',
                'sql': []}
    for name, ranges in BLOCKS.items():
        pieces = []
        for start, end in ranges:
            pieces.append('\n'.join(text_of(elements[i]) for i in range(start, end + 1)))
        data = ('\n\n'.join(pieces) + '\n').encode()
        dest = ROOT / name
        if check:
            if not dest.exists() or dest.read_bytes() != data:
                raise SystemExit(f'FAIL: source mismatch: {name}')
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        manifest['sql'].append({'path': name, 'body_ranges_inclusive': [list(r) for r in ranges],
                                'sha256': hashlib.sha256(data).hexdigest()})
    if check:
        recorded = json.loads((LOCAL / 'source/extraction_manifest.json').read_text())
        if recorded != manifest:
            raise SystemExit('FAIL: extraction manifest mismatch')
        print(f'PASS: {len(BLOCKS)} SQL files match report; SHA-256 verified')
        return
    (LOCAL / 'source').mkdir(parents=True, exist_ok=True)
    (LOCAL / 'source/extraction_manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    sections = [('lab01.md', 'Первая лабораторная из исходного отчёта', 0, 341),
                ('teacher_feedback_lab01.md', 'Замечания преподавателя из исходного отчёта', 342, 410),
                ('lab02.md', 'Вторая лабораторная из исходного отчёта', 411, len(elements)-1)]
    for filename, title, start, end in sections:
        lines = [f'# {title}', '',
                 'Текст извлечён без исправлений. Номер `pNNNN` — индекс элемента в `word/document.xml`.',
                 'Разбиение соответствует трём разделам выгруженного DOCX. Это копия исходных материалов, а не проверенный итоговый отчёт.', '',
                 'Графические фигуры Word сохранены в [оригинале](../../source/report.docx); их текст ниже не заменяет диаграмму.', '']
        code_end = -1
        for i in range(start, end+1):
            el = elements[i]
            s = text_of(el)
            if i <= code_end:
                continue
            code = next(((name, a, b) for name, ranges in BLOCKS.items() for a,b in ranges if i == a), None)
            if code:
                name, a, b = code
                lines += [f'<a id="p{i:04d}"></a>', '', f'Исходный SQL: [{name}](../../../{name}), элементы {a}–{b}.', '', '```sql',
                          '\n'.join(text_of(elements[n]) for n in range(a,b+1)), '```', '']
                code_end = b
                continue
            if not s:
                continue
            lines += [f'<a id="p{i:04d}"></a>', '']
            if el.tag == W + 'tbl':
                rows = []
                for row in el.findall(W + 'tr'):
                    rows.append([text_of(cell).replace('|','\\|').replace('\n','<br>')
                                 for cell in row.findall(W + 'tc')])
                if rows:
                    lines += ['| ' + ' | '.join(rows[0]) + ' |',
                              '| ' + ' | '.join('---' for _ in rows[0]) + ' |']
                    lines += ['| ' + ' | '.join(row) + ' |' for row in rows[1:]]
            else:
                style = el.find(f'{W}pPr/{W}pStyle')
                val = style.get(W + 'val','') if style is not None else ''
                prefix = '#' * min(int(val[-1])+1, 6) + ' ' if val.startswith('Heading') and val[-1].isdigit() else ''
                lines.append(prefix + s)
            lines.append('')
        dest = LOCAL / 'docs/source' / filename
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text('\n'.join(lines))
    print(f'Extracted {len(BLOCKS)} SQL files and 3 Markdown sections')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', nargs='?', type=Path, default=LOCAL/'source/report.docx')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    extract(args.source, args.check)
