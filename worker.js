// No License Ranks backend - Cloudflare Worker + KV (binding name: RANKS)
// Routes:  GET /get?id=STEAMID   POST /set {json}   GET /top   GET /ping
export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const cors = { 'Access-Control-Allow-Origin': '*', 'Content-Type': 'application/json' };
    if (url.pathname === '/ping') return new Response('{"ok":true}', { headers: cors });
    if (url.pathname === '/get') {
      const id = url.searchParams.get('id') || '';
      if (!/^\d{5,20}$/.test(id)) return new Response('{"error":"bad id"}', { status: 400, headers: cors });
      const v = await env.RANKS.get('p:' + id);
      return new Response(v || '{"xp":0}', { headers: cors });
    }
    if (url.pathname === '/set' && req.method === 'POST') {
      let d; try { d = await req.json(); } catch { return new Response('{"error":"bad json"}', { status: 400, headers: cors }); }
      const id = String(d.id || '');
      if (!/^\d{5,20}$/.test(id)) return new Response('{"error":"bad id"}', { status: 400, headers: cors });
      const old = JSON.parse((await env.RANKS.get('p:' + id)) || '{}');
      // never let a client lower its own numbers
      const keep = {};
      for (const k of ['xp','km','nearMisses','overtakes','crashes','topSpeed','bestStreak','bestRun','escapes','busts','races','raceWins']) {
        const n = Number(d[k] || 0), o = Number(old[k] || 0);
        keep[k] = Math.max(isFinite(n) ? n : 0, o);
      }
      keep.name = String(d.name || old.name || '').slice(0, 40);
      keep.updated = Date.now();
      await env.RANKS.put('p:' + id, JSON.stringify(keep));
      return new Response('{"ok":true}', { headers: cors });
    }
    if (url.pathname === '/top') {
      const list = await env.RANKS.list({ prefix: 'p:' });
      const rows = [];
      for (const k of list.keys) { const v = await env.RANKS.get(k.name); if (v) { const o = JSON.parse(v); rows.push({ id: k.name.slice(2), name: o.name, xp: o.xp }); } }
      rows.sort((a, b) => b.xp - a.xp);
      return new Response(JSON.stringify(rows.slice(0, 50)), { headers: cors });
    }
    return new Response('{"error":"not found"}', { status: 404, headers: cors });
  }
};
