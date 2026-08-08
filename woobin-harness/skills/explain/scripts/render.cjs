// HTML → PNG 렌더 (시스템 Chrome 채널, 2x). explain skill용.
// usage: node render.cjs <htmlPath> <pngPath> [width=1200] [height=700]
const path = require('path');

// playwright는 이 스크립트 위치(~/.claude/skills)가 아니라 대상 프로젝트에
// 설치돼 있으므로 cwd 기준으로 resolve한다. 없으면 글로벌/NODE_PATH로 fallback.
function loadChromium() {
  const paths = [process.cwd(), path.join(process.cwd(), 'frontend'), path.join(process.cwd(), 'backend')];
  try {
    return require(require.resolve('playwright', { paths })).chromium;
  } catch {
    return require('playwright').chromium; // global / NODE_PATH fallback
  }
}
const chromium = loadChromium();

const [htmlPath, pngPath, w = '1200', h = '700'] = process.argv.slice(2);
if (!htmlPath || !pngPath) {
  console.error('usage: node render.cjs <htmlPath> <pngPath> [width] [height]');
  process.exit(2);
}

(async () => {
  const browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage({ deviceScaleFactor: 2 });
  await page.setViewportSize({ width: parseInt(w, 10), height: parseInt(h, 10) });
  await page.goto('file://' + path.resolve(htmlPath));
  await page.screenshot({ path: path.resolve(pngPath), fullPage: true });
  await browser.close();
  console.log('rendered ok →', pngPath);
})().catch((e) => { console.error('ERR', e.message); process.exit(1); });
