# 文章列表

<div style="margin-bottom:16px">
  <button id="sort-date" onclick="sortPosts('date')" style="padding:4px 16px;border:1px solid #5c6bc0;background:#5c6bc0;color:#fff;border-radius:4px;cursor:pointer;margin-right:8px;font-size:0.9em">📅 按时间</button>
  <button id="sort-name" onclick="sortPosts('name')" style="padding:4px 16px;border:1px solid #999;background:transparent;color:#333;border-radius:4px;cursor:pointer;font-size:0.9em">🔤 按名称</button>
</div>

<div id="posts-container">加载中...</div>

<script>
let ALL_POSTS = [];
let currentSort = 'date';

async function loadPosts() {
  try {
    const res = await fetch('/notes-blog/posts.json?t=' + Date.now());
    ALL_POSTS = await res.json();
    sortPosts(currentSort);
  } catch(e) {
    document.getElementById('posts-container').innerHTML = 
      '⚠️ 加载失败 · <a href="https://github.com/Nervger-lang/notes-blog" target="_blank">GitHub 查看</a>';
  }
}

function sortPosts(type) {
  currentSort = type;
  document.getElementById('sort-date').style.background = type === 'date' ? '#5c6bc0' : 'transparent';
  document.getElementById('sort-date').style.color = type === 'date' ? '#fff' : '#333';
  document.getElementById('sort-name').style.background = type === 'name' ? '#5c6bc0' : 'transparent';
  document.getElementById('sort-name').style.color = type === 'name' ? '#fff' : '#333';

  const sorted = [...ALL_POSTS].sort((a, b) => {
    if (type === 'name') return a.title.localeCompare(b.title, 'zh');
    return (b.date || '').localeCompare(a.date || '');
  });

  document.getElementById('posts-container').innerHTML = sorted.map(p =>
    `<div style="margin-bottom:10px;border-left:2px solid #5c6bc0;padding-left:12px">
      <a href="${p.url}">${p.title}</a>
      <span style="color:#999;font-size:0.85em;margin-left:8px">${p.date}</span>
    </div>`
  ).join('') || '<p>暂无文章</p>';
}

document.addEventListener('DOMContentLoaded', loadPosts);
// MkDocs instant nav
if (typeof document$ !== 'undefined' && document$.subscribe) {
  document$.subscribe(() => setTimeout(loadPosts, 100));
}
</script>
