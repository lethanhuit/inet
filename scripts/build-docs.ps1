#requires -version 5.1
<#
.SYNOPSIS
  Sync toàn bộ Markdown trong docs/ thành một site HTML tĩnh "sinh động".
.DESCRIPTION
  - Quét docs/**/*.md (bỏ qua thư mục output), render mỗi file thành 1 trang HTML
    tự chứa: mục lục tự động + scrollspy, thanh tiến độ đọc, reveal khi cuộn,
    dark/light theme, render Mermaid + highlight code.
  - Sinh index.html dạng card có tìm kiếm + thống kê, gom nhóm theo loại tài liệu.
  - Cũng liệt kê các trang HTML dựng tay sẵn có (vd docs/visualization/*.html).
  Markdown được render phía client (marked.js) nên script chỉ làm việc nhúng + template.
.EXAMPLE
  pwsh scripts/build-docs.ps1 -Open
.NOTES
  3 thư viện (marked, highlight.js, mermaid) lấy từ CDN. Để chạy offline,
  tải chúng về docs/site/assets/ và sửa $LibCss/$LibJs cho trỏ nội bộ.
#>
[CmdletBinding()]
param(
  [string]$DocsDir,
  [string]$OutDir,
  [switch]$Open,
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'

# ---- Đường dẫn ---------------------------------------------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
if (-not $DocsDir) { $DocsDir = Join-Path $repoRoot 'docs' }
if (-not (Test-Path $DocsDir)) { throw "Không tìm thấy thư mục docs: $DocsDir" }
$DocsDir = (Resolve-Path $DocsDir).Path
if (-not $OutDir) { $OutDir = Join-Path $DocsDir 'site' }

$now = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$utf8 = New-Object System.Text.UTF8Encoding($false)

function HtmlEnc([string]$s) { ($s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;') }
function ToB64([string]$s) { [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s)) }
function WriteFile([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($path, $content, $utf8)
}

if ($Clean -and (Test-Path $OutDir)) { Remove-Item -Recurse -Force $OutDir }

# ---- Thư viện CDN ------------------------------------------------------------
$LibCss = '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github-dark.min.css">'
$LibJs  = @'
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/highlight.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
'@

# ---- CSS dùng chung ----------------------------------------------------------
$Css = @'
*{box-sizing:border-box}
:root{
  --bg:#0b0f17;--bg2:#0e1320;--panel:#121a2b;--panel2:#16203400;
  --fg:#e7edf7;--muted:#8aa0bd;--line:#22304a;--code:#0a0e16;
  --accent:#5eead4;--accent2:#7c83ff;--accent3:#ff7ce0;
  --shadow:0 10px 40px rgba(0,0,0,.45);
}
html[data-theme="light"]{
  --bg:#f5f7fb;--bg2:#eef2f9;--panel:#ffffff;--fg:#16202e;--muted:#5a6b82;
  --line:#dde5f0;--code:#0f1626;--shadow:0 10px 30px rgba(20,40,80,.12);
}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--fg);
  font:16px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,"Noto Sans",sans-serif;
  -webkit-font-smoothing:antialiased}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
.progress{position:fixed;top:0;left:0;height:3px;width:0;z-index:60;
  background:linear-gradient(90deg,var(--accent),var(--accent2),var(--accent3));
  box-shadow:0 0 12px var(--accent2);transition:width .1s linear}
.tbtn{background:var(--panel);color:var(--fg);border:1px solid var(--line);
  border-radius:10px;width:38px;height:38px;cursor:pointer;font-size:16px;transition:.2s}
.tbtn:hover{transform:translateY(-1px);box-shadow:var(--shadow)}
.foot{padding:28px 24px;color:var(--muted);font-size:13px;border-top:1px solid var(--line);text-align:center}

/* ---------- DOC PAGE ---------- */
.topbar{position:sticky;top:0;z-index:40;display:flex;align-items:center;gap:16px;
  padding:12px 20px;background:rgba(11,15,23,.78);backdrop-filter:blur(10px);
  border-bottom:1px solid var(--line)}
html[data-theme="light"] .topbar{background:rgba(245,247,251,.82)}
.topbar .brand{font-weight:600;white-space:nowrap}
.topbar .ttl{font-weight:600;color:var(--muted);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1}
.layout{display:grid;grid-template-columns:280px minmax(0,1fr);gap:32px;
  max-width:1180px;margin:0 auto;padding:28px 24px 60px}
.sidebar{position:sticky;top:74px;align-self:start;max-height:calc(100vh - 96px);overflow:auto}
.toc-h{font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);margin:6px 0 10px}
.toc{display:flex;flex-direction:column;gap:2px;border-left:1px solid var(--line)}
.toc a{color:var(--muted);padding:5px 12px;border-left:2px solid transparent;margin-left:-1px;
  font-size:14px;line-height:1.4;transition:.18s}
.toc a.toc-h3{padding-left:24px;font-size:13px}
.toc a:hover{color:var(--fg);text-decoration:none}
.toc a.active{color:var(--accent);border-left-color:var(--accent);background:linear-gradient(90deg,rgba(94,234,212,.08),transparent)}
.content{min-width:0}
.content h1{font-size:2rem;line-height:1.25;margin:.2em 0 .6em;
  background:linear-gradient(90deg,var(--fg),var(--accent));-webkit-background-clip:text;background-clip:text;color:transparent}
.content h2{font-size:1.5rem;margin:1.8em 0 .6em;padding-bottom:.3em;border-bottom:1px solid var(--line)}
.content h3{font-size:1.2rem;margin:1.4em 0 .4em;color:var(--accent)}
.content h4{margin:1.2em 0 .3em}
.content p{margin:.7em 0}
.content ul,.content ol{padding-left:1.4em}
.content li{margin:.25em 0}
.content code{background:var(--code);padding:.15em .45em;border-radius:6px;font-size:.88em;
  font-family:"SFMono-Regular",Consolas,"Liberation Mono",monospace;border:1px solid var(--line)}
.content pre{background:var(--code);border:1px solid var(--line);border-radius:12px;
  padding:16px 18px;overflow:auto;box-shadow:var(--shadow)}
.content pre code{background:none;border:none;padding:0;font-size:.85em;line-height:1.55}
.content blockquote{margin:1em 0;padding:.6em 1.1em;border-left:3px solid var(--accent2);
  background:linear-gradient(90deg,rgba(124,131,255,.10),transparent);border-radius:0 10px 10px 0;color:var(--fg)}
.content table{border-collapse:collapse;width:100%;margin:1.1em 0;font-size:.92em;
  border:1px solid var(--line);border-radius:12px;overflow:hidden;display:block;overflow-x:auto}
.content th,.content td{border:1px solid var(--line);padding:9px 13px;text-align:left;vertical-align:top}
.content thead th{background:var(--panel);color:var(--fg);position:sticky;top:0}
.content tbody tr:nth-child(even){background:rgba(124,131,255,.05)}
.content tbody tr:hover{background:rgba(94,234,212,.07)}
.content hr{border:none;border-top:1px solid var(--line);margin:2em 0}
.content a{border-bottom:1px dashed transparent}
.content a:hover{border-bottom-color:var(--accent);text-decoration:none}
.content img{max-width:100%}
.mermaid{margin:1.2em 0;text-align:center}
.reveal{opacity:0;transform:translateY(16px);transition:opacity .55s ease,transform .55s ease}
.reveal.in{opacity:1;transform:none}

/* ---------- INDEX ---------- */
body.index{background:radial-gradient(1100px 600px at 80% -10%,rgba(124,131,255,.18),transparent 60%),
  radial-gradient(900px 500px at 0% 0%,rgba(94,234,212,.12),transparent 55%),var(--bg)}
.hero{position:relative;max-width:1180px;margin:0 auto;padding:60px 24px 26px;text-align:center}
.hero .tbtn{position:absolute;right:24px;top:24px}
.hero h1{font-size:clamp(2rem,5vw,3.2rem);margin:.1em 0;letter-spacing:-.02em;
  background:linear-gradient(100deg,var(--accent),var(--accent2) 55%,var(--accent3));
  -webkit-background-clip:text;background-clip:text;color:transparent;
  background-size:200% auto;animation:shine 9s linear infinite}
@keyframes shine{to{background-position:200% center}}
.hero .sub{color:var(--muted);font-size:1.05rem;margin:.4em 0 1.4em}
.stats{display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-bottom:20px}
.chip{background:var(--panel);border:1px solid var(--line);border-radius:999px;
  padding:6px 16px;font-size:13px;color:var(--muted);box-shadow:var(--shadow)}
.chip b{color:var(--accent);font-size:15px}
.search{width:min(560px,92%);padding:14px 18px;border-radius:14px;border:1px solid var(--line);
  background:var(--panel);color:var(--fg);font-size:15px;outline:none;box-shadow:var(--shadow);transition:.2s}
.search:focus{border-color:var(--accent2);box-shadow:0 0 0 3px rgba(124,131,255,.25)}
.grid-wrap{max-width:1180px;margin:0 auto;padding:18px 24px 40px}
.cat{margin:26px 0}
.cat>h2{font-size:1.15rem;margin:0 0 14px;display:flex;align-items:center;gap:10px}
.cat>h2 .cnt{font-size:12px;color:var(--muted);background:var(--panel);border:1px solid var(--line);
  border-radius:999px;padding:1px 9px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
@keyframes pop{from{opacity:0;transform:translateY(18px) scale(.98)}to{opacity:1;transform:none}}
.card{display:block;position:relative;background:var(--panel);border:1px solid var(--line);
  border-radius:16px;padding:18px 18px 16px;overflow:hidden;animation:pop .5s both;
  transition:transform .22s ease,box-shadow .22s ease,border-color .22s ease}
.card::before{content:"";position:absolute;inset:0 0 auto 0;height:3px;
  background:linear-gradient(90deg,var(--accent),var(--accent2),var(--accent3));opacity:.0;transition:.22s}
.card:hover{transform:translateY(-4px);box-shadow:var(--shadow);border-color:var(--accent2);text-decoration:none}
.card:hover::before{opacity:1}
.card .badge{display:inline-block;font-size:11px;letter-spacing:.06em;text-transform:uppercase;
  color:var(--accent);background:rgba(94,234,212,.10);border:1px solid var(--line);
  border-radius:999px;padding:2px 10px;margin-bottom:10px}
.card h3{margin:.1em 0 .35em;font-size:1.06rem;color:var(--fg);line-height:1.3}
.card p{margin:0 0 12px;color:var(--muted);font-size:.9rem;
  display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.card .path{font-size:11.5px;color:var(--muted);font-family:Consolas,monospace;opacity:.75}

@media(max-width:860px){.layout{grid-template-columns:1fr}.sidebar{display:none}}
::-webkit-scrollbar{width:11px;height:11px}
::-webkit-scrollbar-thumb{background:var(--line);border-radius:8px;border:3px solid var(--bg)}
::-webkit-scrollbar-thumb:hover{background:var(--accent2)}
@media print{.topbar,.sidebar,.progress,.tbtn{display:none}.layout{display:block}}
'@

# ---- JS cho trang tài liệu ---------------------------------------------------
$DocJs = @'
(function(){
  function b64u(s){return decodeURIComponent(Array.prototype.map.call(atob(s.trim()),function(c){return '%'+('00'+c.charCodeAt(0).toString(16)).slice(-2)}).join(''))}
  function tt(){var h=document.documentElement,l=h.getAttribute('data-theme')==='light';if(l)h.removeAttribute('data-theme');else h.setAttribute('data-theme','light');localStorage.setItem('inet-docs-theme',l?'':'light')}
  window.toggleTheme=tt;
  var md=b64u(document.getElementById('md-src').textContent).replace(/^---\n[\s\S]*?\n---\n/,'');
  marked.setOptions({gfm:true});
  var c=document.getElementById('content');
  c.innerHTML=marked.parse(md);
  c.querySelectorAll('code.language-mermaid').forEach(function(code){var d=document.createElement('div');d.className='mermaid';d.textContent=code.textContent;code.parentElement.replaceWith(d)});
  c.querySelectorAll('pre code').forEach(function(b){try{hljs.highlightElement(b)}catch(e){}});
  if(window.mermaid){try{mermaid.initialize({startOnLoad:false,theme:'dark',securityLevel:'loose'});mermaid.run({querySelector:'.mermaid'})}catch(e){}}
  var toc=document.getElementById('toc-list'),items=[],i=0;
  c.querySelectorAll('h1,h2,h3').forEach(function(h){
    if(h.tagName==='H1'){h.id='top';return}
    var id='s'+(i++);h.id=id;
    var a=document.createElement('a');a.href='#'+id;a.textContent=h.textContent;a.className='toc-'+h.tagName.toLowerCase();
    a.addEventListener('click',function(e){e.preventDefault();h.scrollIntoView({behavior:'smooth',block:'start'});history.replaceState(null,'','#'+id)});
    toc.appendChild(a);items.push({a:a,h:h});
  });
  if(items.length){var spy=new IntersectionObserver(function(es){es.forEach(function(en){var it=items.filter(function(x){return x.h===en.target})[0];if(it&&en.isIntersecting){items.forEach(function(x){x.a.classList.remove('active')});it.a.classList.add('active')}})},{rootMargin:'0px 0px -78% 0px'});items.forEach(function(x){spy.observe(x.h)})}
  var rev=new IntersectionObserver(function(es){es.forEach(function(en){if(en.isIntersecting){en.target.classList.add('in');rev.unobserve(en.target)}})},{threshold:.05});
  Array.prototype.slice.call(c.children).forEach(function(el,idx){el.classList.add('reveal');el.style.transitionDelay=Math.min(idx*16,160)+'ms';rev.observe(el)});
  var bar=document.getElementById('bar');
  function sc(){var st=document.documentElement.scrollTop||document.body.scrollTop;var h=document.documentElement.scrollHeight-document.documentElement.clientHeight;bar.style.width=(h>0?st/h*100:0)+'%'}
  window.addEventListener('scroll',sc,{passive:true});sc();
})();
'@

# ---- JS cho trang index ------------------------------------------------------
$IndexJs = @'
(function(){
  function b64u(s){return decodeURIComponent(Array.prototype.map.call(atob(s.trim()),function(c){return '%'+('00'+c.charCodeAt(0).toString(16)).slice(-2)}).join(''))}
  window.toggleTheme=function(){var h=document.documentElement,l=h.getAttribute('data-theme')==='light';if(l)h.removeAttribute('data-theme');else h.setAttribute('data-theme','light');localStorage.setItem('inet-docs-theme',l?'':'light')};
  var docs=JSON.parse(b64u(document.getElementById('docs-data').textContent));
  if(!Array.isArray(docs))docs=[docs];
  var grid=document.getElementById('grid'),order=[],groups={},gi=0;
  docs.forEach(function(d){if(!groups[d.cat]){groups[d.cat]=[];order.push(d.cat)}groups[d.cat].push(d)});
  document.getElementById('stats').innerHTML='<span class="chip"><b>'+docs.length+'</b> tài liệu</span><span class="chip"><b>'+order.length+'</b> nhóm</span>';
  order.forEach(function(cat){
    var sec=document.createElement('section');sec.className='cat';
    var h=document.createElement('h2');h.textContent=cat;var cnt=document.createElement('span');cnt.className='cnt';cnt.textContent=groups[cat].length;h.appendChild(cnt);sec.appendChild(h);
    var w=document.createElement('div');w.className='cards';
    groups[cat].forEach(function(d){
      var a=document.createElement('a');a.className='card';a.href=d.href;
      a.setAttribute('data-text',(d.title+' '+d.desc+' '+d.href).toLowerCase());
      a.style.animationDelay=Math.min(gi*35,700)+'ms';gi++;
      var b=document.createElement('div');b.className='badge';b.textContent=d.type;a.appendChild(b);
      var t=document.createElement('h3');t.textContent=d.title;a.appendChild(t);
      var p=document.createElement('p');p.textContent=d.desc;a.appendChild(p);
      var f=document.createElement('div');f.className='path';f.textContent=d.href;a.appendChild(f);
      w.appendChild(a);
    });
    sec.appendChild(w);grid.appendChild(sec);
  });
  var q=document.getElementById('q');
  q.addEventListener('input',function(){
    var v=q.value.trim().toLowerCase();
    document.querySelectorAll('.cat').forEach(function(sec){
      var any=false;
      sec.querySelectorAll('.card').forEach(function(c){var m=!v||c.getAttribute('data-text').indexOf(v)>-1;c.style.display=m?'':'none';if(m)any=true});
      sec.style.display=any?'':'none';
    });
  });
  var bar=document.getElementById('bar');
  function sc(){var st=document.documentElement.scrollTop||document.body.scrollTop;var h=document.documentElement.scrollHeight-document.documentElement.clientHeight;bar.style.width=(h>0?st/h*100:0)+'%'}
  window.addEventListener('scroll',sc,{passive:true});sc();
})();
'@

# ---- Template trang tài liệu -------------------------------------------------
$PageTpl = @'
<!doctype html><html lang="vi"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>__TITLE__ · Định danh</title>
<script>(function(){var s=localStorage.getItem('inet-docs-theme');if(s)document.documentElement.setAttribute('data-theme',s)})();</script>
__LIBCSS__
<style>__CSS__</style>
</head><body class="doc">
<div id="bar" class="progress"></div>
<header class="topbar">
  <a class="brand" href="__BACKHREF__">← Tài liệu</a>
  <div class="ttl">__TITLE__</div>
  <button class="tbtn" onclick="toggleTheme()" title="Đổi giao diện">◑</button>
</header>
<div class="layout">
  <aside class="sidebar"><div class="toc-h">Mục lục</div><nav id="toc-list" class="toc"></nav></aside>
  <main id="content" class="content"></main>
</div>
<noscript><p style="padding:2rem;text-align:center">Cần bật JavaScript để hiển thị tài liệu này.</p></noscript>
<footer class="foot">Sinh tự động từ <code>__RELPATH__</code> · __GENERATED__</footer>
<script id="md-src" type="text/plain">__MDB64__</script>
__LIBJS__
<script>__APPJS__</script>
</body></html>
'@

# ---- Template trang index ----------------------------------------------------
$IndexTpl = @'
<!doctype html><html lang="vi"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tài liệu · Định danh trên Không gian mạng</title>
<script>(function(){var s=localStorage.getItem('inet-docs-theme');if(s)document.documentElement.setAttribute('data-theme',s)})();</script>
<style>__CSS__</style>
</head><body class="index">
<div id="bar" class="progress"></div>
<header class="hero">
  <button class="tbtn" onclick="toggleTheme()" title="Đổi giao diện">◑</button>
  <h1>Định danh trên Không gian mạng</h1>
  <p class="sub">Bộ tài liệu kiến trúc · eKYC + IdP/SSO · cập nhật __GENERATED__</p>
  <div id="stats" class="stats"></div>
  <input id="q" class="search" placeholder="🔎 Tìm tài liệu, ADR, thuật ngữ…" autocomplete="off">
</header>
<main id="grid" class="grid-wrap"></main>
<footer class="foot">Sinh tự động bằng <code>scripts/build-docs.ps1</code> · __GENERATED__</footer>
<script id="docs-data" type="text/plain">__DOCSJSON__</script>
<script>__APPJS__</script>
</body></html>
'@

# ---- Quét & sinh trang -------------------------------------------------------
$outFull = [System.IO.Path]::GetFullPath($OutDir)
$mdFiles = Get-ChildItem -Path $DocsDir -Recurse -Filter *.md -File |
  Where-Object { -not $_.FullName.StartsWith($outFull, [StringComparison]::OrdinalIgnoreCase) }

$docsList = @()
$count = 0

foreach ($f in $mdFiles) {
  $md  = Get-Content -Path $f.FullName -Raw -Encoding UTF8
  $rel = $f.FullName.Substring($DocsDir.Length).TrimStart('\','/')
  $relFwd = $rel -replace '\\','/'

  $lines = ($md -replace "`r",'') -split "`n"
  $title = ($lines | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1)
  if ($title) { $title = ($title -replace '^#\s+','').Trim() } else { $title = $f.BaseName }

  $desc = ''
  foreach ($ln in $lines) {
    $t = $ln.Trim()
    if ($t -eq '') { continue }
    if ($t -match '^#') { continue }
    if ($t -match '^(>|\||`|-|\*|!|\[|---|=)') { continue }
    $desc = $t; break
  }
  $desc = $desc -replace '\*\*','' -replace '`','' -replace '\[([^\]]+)\]\([^\)]+\)','$1'
  if ($desc.Length -gt 160) { $desc = $desc.Substring(0,160) + '…' }

  # phân loại theo thư mục gốc
  $dir = Split-Path $relFwd -Parent
  $segs = if ($dir) { ($dir -replace '\\','/').Split('/') } else { @() }
  $top  = if ($segs.Count -gt 0) { $segs[0] } else { '' }
  switch ($top) {
    'adr'           { $cat='ADR — Quyết định kiến trúc'; $type='ADR' }
    'research'      { $cat='Nghiên cứu';                 $type='Research' }
    'visualization' { $cat='Trực quan';                  $type='Viz' }
    'superpowers'   {
      $sub = if ($segs.Count -gt 1) { $segs[1] } else { '' }
      if ($sub -eq 'plans') { $cat='Kế hoạch triển khai'; $type='Plan' }
      else                  { $cat='Spec / Kiến trúc';    $type='Spec' }
    }
    ''              { $cat='Tổng quan'; $type='Doc' }
    default         { $cat=$top;       $type='Doc' }
  }

  $depth = $segs.Count
  $backHref = ('../' * $depth) + 'index.html'
  $href = ($relFwd -replace '\.md$','.html')

  $html = $PageTpl.Replace('__CSS__',$Css).Replace('__LIBCSS__',$LibCss).Replace('__LIBJS__',$LibJs).Replace('__APPJS__',$DocJs)
  $html = $html.Replace('__TITLE__',(HtmlEnc $title)).Replace('__BACKHREF__',$backHref)
  $html = $html.Replace('__RELPATH__',(HtmlEnc $relFwd)).Replace('__GENERATED__',$now)
  $html = $html.Replace('__MDB64__',(ToB64 $md))

  WriteFile (Join-Path $OutDir ($href -replace '/','\')) $html
  $count++

  $rank = switch ($cat) {
    'Tổng quan' {0} 'Spec / Kiến trúc' {1} 'ADR — Quyết định kiến trúc' {2}
    'Kế hoạch triển khai' {3} 'Nghiên cứu' {4} 'Trực quan' {5} default {8}
  }
  $docsList += [pscustomobject]@{ title=$title; desc=$desc; cat=$cat; type=$type; href=$href; rank=$rank }
}

# ---- Trang HTML dựng tay sẵn có ---------------------------------------------
$manual = Get-ChildItem -Path $DocsDir -Recurse -Filter *.html -File |
  Where-Object { -not $_.FullName.StartsWith($outFull, [StringComparison]::OrdinalIgnoreCase) }
foreach ($h in $manual) {
  $rel = ($h.FullName.Substring($DocsDir.Length).TrimStart('\','/')) -replace '\\','/'
  $docsList += [pscustomobject]@{
    title = $h.BaseName; desc = 'Trang HTML trực quan dựng tay.'
    cat = 'Trực quan (dựng tay)'; type = 'HTML'; href = '../' + $rel; rank = 6
  }
}

# ---- Sinh index --------------------------------------------------------------
$ordered = $docsList | Sort-Object rank, title | Select-Object title,desc,cat,type,href
$json = @($ordered) | ConvertTo-Json -Depth 4 -Compress
$indexHtml = $IndexTpl.Replace('__CSS__',$Css).Replace('__APPJS__',$IndexJs).Replace('__GENERATED__',$now).Replace('__DOCSJSON__',(ToB64 $json))
WriteFile (Join-Path $OutDir 'index.html') $indexHtml

Write-Host ""
Write-Host ("  ✓ Đã sync {0} tài liệu Markdown + {1} trang HTML dựng tay" -f $count, $manual.Count) -ForegroundColor Green
Write-Host ("  → Output: {0}" -f (Join-Path $OutDir 'index.html'))
Write-Host ""

if ($Open) { Start-Process (Join-Path $OutDir 'index.html') }
