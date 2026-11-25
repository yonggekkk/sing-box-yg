// 配合Serv00/VPS/软路由保活网页，支持 Cloudflare Workers Scheduled 与 HTTP Fetch 触发
// 每个网页地址之间用空格、英文逗号或中文逗号分隔，网页前带 http:// 或 https://
// 推荐通过 Worker 环境变量 URLS 配置地址列表，未配置时回退到下面的默认字符串
const URL_STRING = 'http://保活或重启网页1 http://保活或重启网页2 http://保活或重启网页3';
const TIMEOUT = 15000;

function parseUrls(raw) {
  return String(raw || '')
    .split(/[\s,，]+/)
    .map((url) => url.trim())
    .filter((url) => /^https?:\/\/\S+$/i.test(url));
}

async function fetchWithTimeout(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT);
  try {
    const resp = await fetch(url, { signal: controller.signal });
    if (!resp.ok) {
      console.warn(`❌ 访问失败: ${url}, HTTP 状态码: ${resp.status}`);
      return { url, ok: false, status: resp.status };
    }
    console.log(`✅ 成功: ${url} (HTTP ${resp.status})`);
    return { url, ok: true, status: resp.status };
  } catch (error) {
    console.warn(`❌ 访问失败: ${url}, 错误: ${error.message}`);
    return { url, ok: false, error: error.message };
  } finally {
    clearTimeout(timeout);
  }
}

export default {
  async scheduled(event, env, ctx) {
    const raw = (env && env.URLS) || URL_STRING;
    const urls = parseUrls(raw);
    console.log('⏳ 任务开始');
    await Promise.allSettled(urls.map(fetchWithTimeout));
    console.log('📊 任务结束');
  },

  async fetch(request, env, ctx) {
    const raw = (env && env.URLS) || URL_STRING;
    const urls = parseUrls(raw);
    const settled = await Promise.allSettled(urls.map(fetchWithTimeout));
    const results = settled.map((item) =>
      item.status === 'fulfilled' ? item.value : { ok: false, error: 'Unexpected rejection' }
    );
    return new Response(JSON.stringify(results), {
      headers: { 'content-type': 'application/json; charset=utf-8' },
    });
  },
};
