/* Single source of truth for the post catalog.
 * Loaded by index.html, library.html, and every post page (before nav.js).
 *
 * Add a post = add ONE entry below (newest first). Fields:
 *   file  : 파일명 (posts/ 기준 상대)
 *   date  : YYYY-MM-DD
 *   main  : 메인 카테고리 = 출처 (예: "Claude blog", "Cursor Youtube")
 *   cat   : 서브 카테고리 = 주제 (예: "Agents", "Claude Code · 해커톤", "세미나")
 *   title : 전체 제목 (index/library/breadcrumb 용)
 *   nav   : 사이드바용 짧은 제목
 */
(function () {
  window.CBK_POSTS = [
    { file: "building-effective-human-agent-teams.html", date: "2026-06-24", main: "Claude blog", cat: "Enterprise AI",
      title: "효과적인 인간-에이전트 팀 만들기: Anthropic의 교훈", nav: "효과적인 인간-에이전트 팀" },
    { file: "agent-identity-access-model.html", date: "2026-06-24", main: "Claude blog", cat: "Claude Code",
      title: "Claude Tag의 에이전트 아이덴티티: 자율적이고 팀 전체가 함께 쓰는 AI를 위한 새로운 접근 모델", nav: "에이전트 아이덴티티 접근 모델" },
    { file: "the-full-claude-desktop-experience-on-aws-google-cloud-and-microsoft-foundry.html", date: "2026-06-22", main: "Claude blog", cat: "Enterprise AI",
      title: "AWS, Google Cloud, Microsoft Foundry에서 누리는 완전한 Claude Desktop 경험", nav: "완전한 Claude Desktop 경험" },
    { file: "artifacts-in-claude-code.html", date: "2026-06-18", main: "Claude blog", cat: "Product announcements",
      title: "Claude Code가 이제 아티팩트(artifacts)를 지원합니다", nav: "Claude Code 아티팩트" },
    { file: "enterprise-managed-auth.html", date: "2026-06-18", main: "Claude blog", cat: "Enterprise AI",
      title: "MCP 커넥터 권한을 중앙에서 관리하기", nav: "MCP 커넥터 중앙 권한 관리" },
    { file: "steering-claude-code.html", date: "2026-06-18", main: "Claude blog", cat: "Claude Code",
      title: "Claude Code 길들이기: CLAUDE.md, 스킬, 훅, 룰, 서브에이전트 그 외", nav: "Claude Code 길들이기" },
    { file: "claude-design-stays-on-brand-for-daily-work.html", date: "2026-06-17", main: "Claude blog", cat: "Product announcements",
      title: "이제 Claude Design은 일상 업무에서도 브랜드를 일관되게 유지합니다", nav: "Claude Design 브랜드 유지" },
    { file: "workload-identity-federation.html", date: "2026-06-17", main: "Claude blog", cat: "Product announcements",
      title: "워크로드 아이덴티티 페더레이션(WIF)으로 Claude 플랫폼에 안전하게 접근하기", nav: "워크로드 아이덴티티 페더레이션" },
    { file: "build-day-hackathon-winners.html", date: "2026-06-17", main: "Claude blog", cat: "Claude Code · 해커톤",
      title: "Claude Opus 4.8 빌드 데이 해커톤 우승팀을 소개합니다", nav: "Opus 4.8 빌드 데이 해커톤" },
    { file: "opus-4-7-hackathon-winners.html", date: "2026-06-15", main: "Claude blog", cat: "Claude Code · 해커톤",
      title: "Built with Opus 4.7 Claude Code 해커톤 우승팀을 소개합니다", nav: "Built with Opus 4.7 해커톤" },
    { file: "building-with-claude-managed-agents.html", date: "2026-06-10", main: "Claude blog", cat: "Agents",
      title: "에이전트 표면의 진화: Claude Managed Agents로 만들기", nav: "Managed Agents로 만들기" },
    { file: "whats-new-in-claude-managed-agents.html", date: "2026-06-09", main: "Claude blog", cat: "Product announcements",
      title: "Claude Managed Agents 새 기능: 일정 실행과 환경 변수 볼트", nav: "관리형 에이전트 새 기능" },
    { file: "opus-4-6-hackathon-winners.html", date: "2026-04-20", main: "Claude blog", cat: "Claude Code · 해커톤",
      title: "Built with Opus 4.6 Claude Code 해커톤 우승팀을 소개합니다", nav: "Built with Opus 4.6 해커톤" }
  ];

  /* file 또는 slug(확장자 없는 파일명)로 포스트 1건 조회. 없으면 null. */
  window.CBK_postBySlug = function (key) {
    if (!key) return null;
    var want = String(key).replace(/\.html$/, "");
    var list = window.CBK_POSTS;
    for (var i = 0; i < list.length; i++) {
      if (list[i].file.replace(/\.html$/, "") === want) return list[i];
    }
    return null;
  };
})();
