// Vercel Serverless Function — Supabase keep-alive
// Vercel Cron이 하루 한 번 이 함수를 호출해, Supabase에 가벼운 쿼리를 날려서
// 무료 플랜 7일 비활성 자동 정지를 방지합니다.
// 필요한 환경변수: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (analyze.js와 동일하게 이미 설정돼 있음)

module.exports = async (req, res) => {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceKey) {
    return res.status(500).json({ ok: false, error: 'Supabase 환경변수가 설정되어 있지 않아요.' });
  }

  try {
    // ingredients 테이블에서 1행만 가볍게 조회 -> DB 활동으로 기록되어 정지 타이머 리셋
    const r = await fetch(`${supabaseUrl}/rest/v1/ingredients?select=id&limit=1`, {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`
      }
    });
    if (!r.ok) {
      const body = await r.text();
      return res.status(502).json({ ok: false, status: r.status, body });
    }
    return res.status(200).json({ ok: true, pingedAt: new Date().toISOString() });
  } catch (err) {
    return res.status(500).json({ ok: false, error: err.message || '알 수 없는 오류' });
  }
};
