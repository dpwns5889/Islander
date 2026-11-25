"""docs/GameDesign.md -> docs/GameDesign.html (pip install markdown)"""
from pathlib import Path
import markdown

d = Path(__file__).resolve().parent.parent
md = markdown.Markdown(extensions=["tables", "fenced_code", "toc"], extension_configs={"toc": {"toc_depth": "2-3"}})
body = md.convert((d / "GameDesign.md").read_text(encoding="utf-8"))
css = """body{margin:0;font:16px/1.7 'Malgun Gothic',sans-serif;color:#222}
nav{position:fixed;top:0;left:0;bottom:0;width:260px;overflow:auto;padding:1rem;box-sizing:border-box;background:#f6faf8;border-right:1px solid #ccc;font-size:14px;line-height:1.5}
nav ul{list-style:none;margin:0;padding-left:.9rem}nav>div>ul{padding-left:0}nav li{margin:.2rem 0}nav a{color:#245;text-decoration:none}nav a:hover{color:#2a7;text-decoration:underline}
main{max-width:860px;margin:2rem auto;padding:0 1rem 0 calc(260px + 1rem)}
@media(max-width:1200px){main{margin-left:280px;padding-left:1rem}}
html{scroll-behavior:smooth}
h1{border-bottom:3px solid #2a7;padding-bottom:.3rem}h2{margin-top:2.2rem;border-bottom:1px solid #ccc;padding-bottom:.2rem}
table{border-collapse:collapse;margin:1rem 0}th,td{border:1px solid #ccc;padding:.4rem .8rem;text-align:left}th{background:#eef6f2}
pre{background:#f4f4f4;padding:1rem;overflow:auto}code{background:#f4f4f4;padding:0 .25rem}"""
html = f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>BiomeDefender 기획서</title><style>{css}</style></head><body><nav>{md.toc}</nav><main>{body}</main></body></html>'
(d / "GameDesign.html").write_text(html, encoding="utf-8", newline="\n")
