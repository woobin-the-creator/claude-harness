/* Shared sidebar nav + breadcrumb + per-post bookmark/notes UI.
 * Post catalog lives in posts.js (window.CBK_POSTS) — load it before this file.
 * Requires store.js (window.CBK) for bookmarks; degrades gracefully if absent. */
(function () {
  var POSTS = window.CBK_POSTS || [];

  var CBK = window.CBK || null;
  var current = location.pathname.split("/").pop();
  var slug = CBK ? CBK.slugOf(current) : current.replace(/\.html$/, "");

  /* ---------- sidebar ---------- */
  var items = POSTS.map(function (p) {
    var active = p.file === current ? " active" : "";
    var star = (CBK && CBK.isBookmarked(CBK.slugOf(p.file))) ? "★ " : "";
    return (
      '<li><a class="nav-link' + active + '" href="' + p.file + '">' +
        star + (p.nav || p.title) +
        '<span class="nav-date">' + p.date + "</span>" +
      "</a></li>"
    );
  }).join("");

  var favCount = CBK ? CBK.bookmarkedSlugs().length : 0;
  var tools = CBK
    ? '<div class="nav-tools">' +
        '<a class="nav-library" href="../library.html">📑 보관함' +
          (favCount ? ' <span class="nav-count">' + favCount + "</span>" : "") +
        "</a>" +
      "</div>"
    : "";

  var nav = document.createElement("nav");
  nav.id = "site-nav";
  nav.innerHTML =
    '<a class="nav-brand" href="../index.html">Claude 블로그 한글 번역</a>' +
    '<a class="nav-home" href="../index.html">← 메인으로</a>' +
    '<div class="nav-heading">다른 글</div>' +
    "<ul>" + items + "</ul>" +
    tools;

  document.body.insertBefore(nav, document.body.firstChild);

  /* ---------- breadcrumb (메인 › 서브 › 제목) ---------- */
  var meta = window.CBK_postBySlug ? window.CBK_postBySlug(current) : null;
  var header = document.querySelector("header");
  if (meta && header) {
    function enc(s) { return encodeURIComponent(s); }
    function esc(s) {
      return String(s).replace(/[&<>"]/g, function (c) {
        return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
      });
    }
    var crumb = document.createElement("nav");
    crumb.className = "post-crumb";
    crumb.setAttribute("aria-label", "breadcrumb");
    crumb.innerHTML =
      '<a href="../index.html#m=' + enc(meta.main) + '">' + esc(meta.main) + "</a>" +
      '<span class="post-crumb-sep">›</span>' +
      '<a href="../index.html#m=' + enc(meta.main) + "&c=" + enc(meta.cat) + '">' + esc(meta.cat) + "</a>" +
      '<span class="post-crumb-sep">›</span>' +
      '<span class="post-crumb-cur">' + esc(meta.title) + "</span>";
    header.parentNode.insertBefore(crumb, header);
  }

  /* ---------- per-post bookmark + note bar ---------- */
  if (!CBK) return;

  var link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = "assets/cbk.css";
  document.head.appendChild(link);

  var faved = CBK.isBookmarked(slug);
  var note = CBK.getNote(slug);

  var bar = document.createElement("div");
  bar.className = "cbk-bar";
  bar.innerHTML =
    '<button type="button" id="cbk-fav" class="cbk-fav' + (faved ? " on" : "") + '">' +
      '<span class="cbk-star">' + (faved ? "★" : "☆") + "</span>" +
      '<span class="cbk-fav-label">' + (faved ? "즐겨찾기됨" : "즐겨찾기") + "</span>" +
    "</button>" +
    '<button type="button" id="cbk-note-toggle" class="cbk-note-toggle' +
      (note ? " has-note" : "") + (note ? " open" : "") + '">' +
      "메모<span class=\"cbk-dot\"></span>" + "</button>" +
    '<span id="cbk-note-status" class="cbk-status"></span>' +
    '<a class="cbk-library" href="../library.html">📑 보관함</a>' +
    '<div id="cbk-note-wrap" class="cbk-note-wrap"' + (note ? "" : " hidden") + ">" +
      '<textarea id="cbk-note" class="cbk-note" ' +
        'placeholder="이 글에 대한 메모 — 이 브라우저에 저장됩니다."></textarea>' +
      '<div class="cbk-note-hint">자동 저장됨 · <kbd>Esc</kbd> 로 닫기</div>' +
    "</div>";

  var header = document.querySelector("header");
  if (header && header.parentNode) header.parentNode.insertBefore(bar, header.nextSibling);
  else document.body.insertBefore(bar, nav.nextSibling);

  var favBtn = document.getElementById("cbk-fav");
  favBtn.addEventListener("click", function () {
    var on = CBK.toggleBookmark(slug);
    favBtn.classList.toggle("on", on);
    favBtn.querySelector(".cbk-star").textContent = on ? "★" : "☆";
    favBtn.querySelector(".cbk-fav-label").textContent = on ? "즐겨찾기됨" : "즐겨찾기";
  });

  var noteToggle = document.getElementById("cbk-note-toggle");
  var noteWrap = document.getElementById("cbk-note-wrap");
  var ta = document.getElementById("cbk-note");
  var status = document.getElementById("cbk-note-status");

  function autosize() {
    ta.style.height = "auto";
    ta.style.height = Math.max(ta.scrollHeight, 96) + "px";
  }
  function openNote(focus) {
    noteWrap.hidden = false;
    noteToggle.classList.add("open");
    autosize();
    if (focus) ta.focus();
  }
  function closeNote() {
    noteWrap.hidden = true;
    noteToggle.classList.remove("open");
  }
  noteToggle.addEventListener("click", function () {
    if (noteWrap.hidden) openNote(true);
    else closeNote();
  });

  ta.value = note;
  if (!noteWrap.hidden) autosize();

  var t = null;
  function showStatus(text, saved) {
    status.textContent = text;
    status.classList.add("show");
    status.classList.toggle("saved", !!saved);
  }
  ta.addEventListener("input", function () {
    autosize();
    showStatus("저장 중…", false);
    if (t) clearTimeout(t);
    t = setTimeout(function () {
      CBK.setNote(slug, ta.value);
      var has = !!ta.value.trim();
      noteToggle.classList.toggle("has-note", has);
      showStatus("저장됨 ✓", true);
      setTimeout(function () { status.classList.remove("show"); }, 1600);
    }, 500);
  });
  ta.addEventListener("keydown", function (e) {
    if (e.key === "Escape") { closeNote(); noteToggle.focus(); }
  });
})();
