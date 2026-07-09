// Vercel Serverless Function (Node.js runtime)
// Keeps the Anthropic API key on the server. Set ANTHROPIC_API_KEY in
// Vercel Project Settings -> Environment Variables (never commit it).

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'ANTHROPIC_API_KEY가 서버에 설정되어 있지 않아요.' });
  }

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (e) { body = {}; }
  }
  const name = (body && body.name || '').trim();
  if (!name) {
    return res.status(400).json({ error: '재료 이름(name)이 필요해요.' });
  }

  const prompt = `식재료 "${name}"에 대해 다음 JSON만 답해. 마크다운, 설명, 백틱 없이 JSON 객체 하나만:
{"emoji":"이 재료를 가장 잘 나타내는 이모지 1개","color":"이 재료의 실제 색을 나타내는 hex 색상코드","kcal":100g당 칼로리 숫자,"protein":100g당 단백질 g 숫자,"carb":100g당 탄수화물 g 숫자,"fat":100g당 지방 g 숫자,"fiber":100g당 식이섬유 g 숫자}
일반적인 영양성분 데이터베이스 기준 대표값을 사용해.`;

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 300,
        messages: [{ role: 'user', content: prompt }]
      })
    });

    const data = await response.json();
    if (!response.ok) {
      const msg = (data && data.error && data.error.message) || 'Anthropic API 호출 실패';
      return res.status(response.status).json({ error: msg });
    }

    const text = (data.content || [])
      .filter(b => b.type === 'text')
      .map(b => b.text)
      .join('');
    const clean = text.replace(/```json|```/g, '').trim();

    let parsed;
    try { parsed = JSON.parse(clean); }
    catch (e) { return res.status(502).json({ error: 'AI 응답을 해석하지 못했어요.', raw: text }); }

    return res.status(200).json(parsed);
  } catch (err) {
    return res.status(500).json({ error: err.message || '알 수 없는 오류' });
  }
};
