"""docs/GameDesign.md -> docs/GameDesign.html (pip install markdown)"""
from pathlib import Path
import markdown

d = Path(__file__).resolve().parent.parent
body = markdown.markdown((d / "GameDesign.md").read_text(encoding="utf-8"), extensions=["tables", "fenced_code", "toc"])
css = """body{max-width:860px;margin:2rem auto;padding:0 1rem;font:16px/1.7 'Malgun Gothic',sans-serif;color:#222}
h1{border-bottom:3px solid #2a7;padding-bottom:.3rem}h2{margin-top:2.2rem;border-bottom:1px solid #ccc;padding-bottom:.2rem}
table{border-collapse:collapse;margin:1rem 0}th,td{border:1px solid #ccc;padding:.4rem .8rem;text-align:left}th{background:#eef6f2}
pre{background:#f4f4f4;padding:1rem;overflow:auto}code{background:#f4f4f4;padding:0 .25rem}"""
html = f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>BiomeDefender 기획서</title><style>{css}</style></head><body>{body}</body></html>'
(d / "GameDesign.html").write_text(html, encoding="utf-8", newline="\n")
