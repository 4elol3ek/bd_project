#!/usr/bin/env python3
"""Run original listings in rollback-only schemas and save factual evidence."""
import json
import subprocess
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'local/evidence'
OUT.mkdir(exist_ok=True)
USER = os.environ.get('POSTGRES_USER','news_app')
DB = os.environ.get('POSTGRES_DB','news_aggregator')
COMPOSE = ['docker','compose']


def save(name,command,sql=None):
    result=subprocess.run(command,cwd=ROOT,input=sql,text=True,capture_output=True)
    (OUT/f'{name}.log').write_text(result.stdout+('\nSTDERR\n'+result.stderr if result.stderr else ''))
    return {'command':command,'exit_code':result.returncode,
            'log':f'local/evidence/{name}.log','sql_error_count':result.stderr.count('ERROR:')}


def psql():
    return COMPOSE+['exec','-T','postgres','psql','-X','-U',USER,'-d',DB]


results={}
results['environment']=save('environment',psql()+['-Atc',
    "SELECT version(); SHOW server_encoding; SHOW TimeZone; SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"])
results['audit']=save('audit',COMPOSE+['--profile','audit','run','--rm','checks'])
if results['audit']['exit_code']:
    raise SystemExit('Audit expectations failed; inspect local/evidence/audit.log')
snapshot="""
SELECT 'seed_counts' AS snapshot,
 (SELECT count(*) FROM app_user) users,(SELECT count(*) FROM news_source) sources,
 (SELECT count(*) FROM scrape_run) runs,(SELECT count(*) FROM news) news,
 (SELECT count(*) FROM import_result) imports,(SELECT count(*) FROM scrape_error_log) errors;
SELECT ir.id, ir.news_id, sr.source_id AS run_source, n.source_id AS news_source
FROM import_result ir JOIN scrape_run sr ON sr.id=ir.scrape_run_id
JOIN news n ON n.id=ir.news_id WHERE sr.source_id<>n.source_id;
"""
for name,version,strict in [('raw_seed_strict_v002',2,True),('raw_v002',2,False),('raw_v001',1,False)]:
    sql="\\set VERBOSITY verbose\n\\set ON_ERROR_STOP "+('on' if strict else 'off')+"\nBEGIN;\n"
    sql+=f"CREATE SCHEMA {name};\nSET LOCAL search_path={name},pg_catalog;\n"
    sql+="\\i /workspace/migrations/001_init.up.sql\n"
    if version==2:
        sql+="\\i /workspace/migrations/002_add_scrape_run_status_check.up.sql\n"
    sql+="\\i /workspace/sql/seed/report_test.sql\n"
    if not strict:
        # A normal transaction stays aborted after its first error. Show that behavior
        # first; permissive replay is a separate autocommit-like savepoint mode below.
        sql+=snapshot
    sql+="ROLLBACK;\n"
    results[name]=save(name,psql()+['-f','-'],sql)

for version in (1,2):
    name=f'raw_savepoints_v00{version}'
    sql="\\set VERBOSITY verbose\n\\set ON_ERROR_STOP off\n\\set ON_ERROR_ROLLBACK on\nBEGIN;\n"
    sql+=f"CREATE SCHEMA {name};\nSET LOCAL search_path={name},pg_catalog;\n"
    sql+="\\i /workspace/migrations/001_init.up.sql\n"
    if version==2:
        sql+="\\i /workspace/migrations/002_add_scrape_run_status_check.up.sql\n"
    sql+="\\i /workspace/sql/seed/report_test.sql\n"+snapshot
    for file in sorted((ROOT/'sql/scenarios').glob('*.sql')):
        sql+=f"\\i /workspace/{file.relative_to(ROOT)}\n"
    sql+="""
SELECT 'after_scenarios' AS snapshot;
SELECT id,email FROM app_user ORDER BY id;
SELECT id,name FROM news_source ORDER BY id;
SELECT id,source_id,status FROM scrape_run ORDER BY id;
SELECT id,scrape_run_id,news_id,status FROM import_result ORDER BY id;
SELECT id,scrape_run_id,error_message FROM scrape_error_log ORDER BY id;
SELECT n.id,n.canonical_url FROM news n WHERE NOT EXISTS(SELECT FROM news_category nc WHERE nc.news_id=n.id);
"""
    for file in sorted((ROOT/'sql/negative').glob('*.sql')):
        sql+=f"\\i /workspace/{file.relative_to(ROOT)}\n"
    sql+="ROLLBACK;\n"
    results[name]=save(name,psql()+['-f','-'],sql)
results['post_audit']=save('post_audit',psql()+['-Atc',"""
SELECT 'public_tables', count(*) FROM information_schema.tables WHERE table_schema='public';
SELECT 'public_news', count(*) FROM public.news;
SELECT 'public_users', count(*) FROM public.app_user;
SELECT 'audit_schemas', count(*) FROM information_schema.schemata
WHERE schema_name='bd_labs_audit' OR schema_name LIKE 'raw_%';
"""])
(OUT/'execution.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
for name,result in results.items():
    print(f'{name}: exit={result["exit_code"]}, SQL errors={result["sql_error_count"]}, {result["log"]}')
if results['post_audit']['exit_code']:
    raise SystemExit('Post-audit verification failed')
