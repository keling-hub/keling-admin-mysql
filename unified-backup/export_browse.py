#!/usr/bin/env python3
import os
import shutil
import pymysql
from datetime import datetime

DB_HOST = os.environ.get('DB_HOST') or 'keling-mysql'
DB_PORT = int(os.environ.get('DB_PORT') or '3306')
DB_USER = os.environ.get('DB_USER') or 'keling'
DB_PASSWORD = os.environ.get('DB_PASSWORD') or '131415'
DB_NAME = os.environ.get('DB_NAME') or 'kbk'

SOURCE_ROOT = os.environ.get('BROWSE_SOURCE_ROOT', '/backup')
OUTPUT_ROOT = os.environ.get('BROWSE_OUTPUT_ROOT', '/data/browse')

def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%F %T')}] {msg}")

def safe_name(name: str) -> str:
    invalid = '<>:"/\\|?*\n\r\t'
    cleaned = ''.join('_' if c in invalid else c for c in (name or '').strip())
    return cleaned[:120] or 'unnamed'

def get_db_conn():
    return pymysql.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD,
                           database=DB_NAME, charset='utf8mb4', cursorclass=pymysql.cursors.DictCursor)

def load_tree(conn):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT n.id AS node_id, n.s30102 AS node_type, n.s30104 AS node_name, n.s301_id_id AS parent_id,
                   fi.id AS file_info_id, fi.s30304 AS ext,
                   v.s30403 AS version_no, c.s30502 AS content_hash, c.s30504 AS storage_type, c.s30505 AS storage_key
            FROM s301 n
            LEFT JOIN s303 fi ON fi.s301_id_id = n.id
            LEFT JOIN s304 v ON fi.s30302_id = v.id
            LEFT JOIN s305 c ON v.s305_id_id = c.id
            ORDER BY n.create_time ASC
            """
        )
        rows = cur.fetchall()

    by_id = {}
    children = {}
    roots = []
    for r in rows:
        node_id = r['node_id']
        parent_id = r['parent_id']
        by_id[node_id] = r
        children.setdefault(parent_id, []).append(node_id)
    for node_id, r in by_id.items():
        if r['parent_id'] is None:
            roots.append(node_id)
    return by_id, children, roots

def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)

def copy_file(src: str, dst: str) -> None:
    ensure_dir(os.path.dirname(dst))
    shutil.copy2(src, dst)

def build_paths(today_root: str, by_id, children, node_id, prefix_parts):
    r = by_id[node_id]
    node_type = r['node_type']
    node_name = safe_name(r['node_name'])
    cur_parts = prefix_parts + [node_name]
    cur_dir = os.path.join(today_root, *cur_parts)

    if node_type == 'folder':
        ensure_dir(cur_dir)
        for cid in children.get(node_id, []):
            build_paths(today_root, by_id, children, cid, cur_parts)
    else:
        storage_type = r.get('storage_type')
        storage_key = r.get('storage_key')
        ext = r.get('ext') or ''
        filename = node_name + (('.' + ext.lstrip('.')) if ext else '')
        dst_path = os.path.join(today_root, *cur_parts[:-1], filename)

        if storage_type == 'local' and storage_key:
            key = storage_key.strip()
            if key.startswith('files/'):
                src = os.path.join(SOURCE_ROOT, key)
            else:
                prefix = key[:2]
                src = os.path.join(SOURCE_ROOT, 'files', prefix, key)
            if os.path.isfile(src):
                copy_file(src, dst_path)

def main():
    try:
        conn = get_db_conn()
    except Exception as e:
        log(f"数据库连接失败: {e}")
        return

    try:
        by_id, children, roots = load_tree(conn)
        today = datetime.now().strftime('%Y-%m-%d')
        today_root = os.path.join(OUTPUT_ROOT, today)
        if os.path.isdir(today_root):
            shutil.rmtree(today_root, ignore_errors=True)
        ensure_dir(today_root)
        for rid in roots:
            build_paths(today_root, by_id, children, rid, [])
        log(f"导出完成: {today_root}")
    except Exception as e:
        log(f"导出失败: {e}")
    finally:
        try:
            conn.close()
        except Exception:
            pass

if __name__ == '__main__':
    main()


