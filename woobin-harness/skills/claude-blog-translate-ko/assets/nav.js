/* Shared sidebar nav, injected at runtime into every post page.
   Add a post = add one entry to POSTS below (newest first). The active
   link is detected by matching the current filename, so the same file
   works unchanged on every post. */
(function () {
  var POSTS = [
    // { file: "example-post.html", title: "글 제목", date: "2026-06-18" },
  ];

  var current = location.pathname.split("/").pop();

  var items = POSTS.map(function (p) {
    var active = p.file === current ? " active" : "";
    return (
      '<li><a class="nav-link' + active + '" href="' + p.file + '">' +
        p.title +
        '<span class="nav-date">' + p.date + "</span>" +
      "</a></li>"
    );
  }).join("");

  var nav = document.createElement("nav");
  nav.id = "site-nav";
  nav.innerHTML =
    '<a class="nav-brand" href="../index.html">Claude 블로그 한글 번역</a>' +
    '<a class="nav-home" href="../index.html">← 메인으로</a>' +
    '<div class="nav-heading">다른 글</div>' +
    "<ul>" + items + "</ul>";

  document.body.insertBefore(nav, document.body.firstChild);
})();
