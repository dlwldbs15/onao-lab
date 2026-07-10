# 🥣 오나오 랩

스푼으로 재료를 더하고 밀크를 조로록 부어서 나만의 오버나이트 오트밀(오나오) 레시피를 만드는 인터랙티브 웹 앱. 재료를 넣을 때마다 유리병 속 층이 실시간으로 쌓이고, 칼로리·단백질·탄수화물·지방·식이섬유가 자동 계산돼요.

## 주요 기능

**레시피 빌더**
- 기본 레시피 5종 + 나만의 레시피 무제한 추가
- 스푼 단위 조절 (0.5 단위 반스푼까지 가능), 드래그 앤 드롭으로 재료 순서 변경 (재료 순서 = 병 속 층 쌓이는 순서)
- 오트밀크·아몬드밀크·코코넛밀크·두유·우유 중 선택해서 ml 단위로 붓기
- 재료를 클릭하면 스푼당/레시피 전체 영양 정보 상세 카드 확인 가능

**AI 재료 분석**
- 재료 이름만 입력하면 Claude가 이모지·색상·칼로리·영양성분을 자동으로 채워줌 (`api/analyze.js` 서버리스 함수 경유)
- **전역 공유 캐시**: 누군가 한 번 분석한 재료는 Supabase `ingredients` 테이블에 저장되고, 이후 다른 사용자가 비슷한 이름을 입력하면(오타·띄어쓰기 차이 포함, pg_trgm 유사도 검색) AI를 다시 부르지 않고 그 값을 재사용함
- 같은 브라우저 안에서도 이름별로 한 번만 분석하고 영구 캐싱

**즐겨찾기**
- 레시피 카드 우측 상단 ⭐ 버튼으로 즐겨찾기 토글, 즐겨찾기한 레시피는 목록 맨 앞으로 자동 정렬
- "⭐ 즐겨찾기만" 필터로 즐겨찾기한 것만 모아보기
- 로그인 상태면 계정(Supabase)에 저장돼서 기기 바꿔도 유지, 비로그인 상태면 브라우저에만 저장

**공유하기**
- 지금 만든 레시피(재료·순서·스푼·밀크·AI 분석 재료까지)를 링크 하나에 통째로 압축(base64url)해서 전달 — 받은 사람이 링크를 열면 그 레시피가 그대로 로드됨
- 카카오톡(Kakao JS SDK) / X / Threads 공유, 지원 안 되는 환경에서는 OS 공유 시트나 클립보드 복사로 자동 대체

**계정 & 클라우드 저장**
- Google / Kakao 로그인 (Supabase Auth)
- 로그인 상태에서 저장한 레시피는 계정(Supabase DB)에 저장돼서 기기를 바꿔도 로그인만 하면 불러와짐
- 비로그인 상태에서는 이 브라우저에만 저장됨 (localStorage)

## 파일 구조

```
onao-lab/
  index.html          앱 본체 (UI + 로직 전부 단일 파일)
  api/analyze.js       재료 영양성분 AI 분석용 Vercel 서버리스 함수 (Anthropic API 키는 여기서만 사용)
  package.json         Vercel이 프로젝트를 인식하기 위한 최소 설정
  supabase_schema.sql  레시피 저장 테이블 + RLS 보안 정책 SQL
  README.md            이 문서
```

## 배포 가이드

### 1. GitHub

이 폴더 전체를 GitHub 저장소에 올려주세요 (웹에서 Upload files로 드래그해도 되고, git으로 push해도 돼요).

### 2. Vercel

1. https://vercel.com → GitHub 계정으로 로그인 → **Add New → Project** → 방금 만든 저장소 Import
2. **Environment Variables**에 추가:
   - `ANTHROPIC_API_KEY` — console.anthropic.com에서 발급 (재료 AI 분석용, 서버에서만 사용되고 클라이언트엔 노출 안 됨)
   - `SUPABASE_URL` — `https://프로젝트ID.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` — Supabase Project Settings → API → **service_role** 키 (⚠️ publishable/anon 키와 다름! 이 키는 RLS를 우회하는 완전 관리자 권한 키라 절대 클라이언트 코드에 넣거나 채팅 등에 노출하면 안 돼요. Vercel 환경변수에만 저장)
3. Deploy → `https://프로젝트명.vercel.app` 주소 발급

Vercel과 GitHub을 연결해두면, 이후 GitHub에 파일을 새로 올릴 때마다 **자동으로 재배포**돼요.

### 3. Supabase (로그인 + 클라우드 저장)

1. https://supabase.com → 새 프로젝트 생성 (Region: Seoul 추천)
2. SQL Editor에서 `supabase_schema.sql` 실행 → `recipes` 테이블(RLS) + `ingredients` 공유 캐시 테이블(pg_trgm 유사도 검색 함수 포함) 생성
3. Project Settings → API에서 **Project URL**, **anon/publishable key** 확인 → `index.html`의 `SUPABASE_URL`, `SUPABASE_KEY` 값과 일치하는지 확인
4. Authentication → Sign In/Up에서 **Google**, **Kakao** Provider 각각 활성화
   - Google: Google Cloud Console에서 OAuth 클라이언트 ID 생성 → Client ID/Secret을 Supabase에 입력
   - Kakao: developers.kakao.com에서 앱 생성 → 카카오 로그인 활성화 → REST API 키 + Client Secret을 Supabase에 입력
   - 두 경우 모두 Supabase가 보여주는 **Callback URL**을 각 플랫폼의 Redirect URI에 등록해야 함

### 4. 카카오톡 공유하기 (선택)

로그인용 카카오 앱과는 별개로, "카카오톡 공유하기" 기능은 Kakao JavaScript 키가 필요해요.

1. developers.kakao.com → 앱 설정 → 플랫폼 → Web 플랫폼에 배포 도메인 등록
2. 제품 설정 → 카카오톡 공유 활성화
3. JavaScript 키를 `index.html`의 `Kakao.init('...')` 값과 일치시키기

## 참고

- API 키(Anthropic)와 OAuth Client Secret은 절대 `index.html`이나 다른 클라이언트 코드에 직접 넣지 마세요. `ANTHROPIC_API_KEY`는 Vercel 환경변수로, OAuth Secret은 Supabase 대시보드에만 입력합니다.
- Supabase publishable key와 Kakao JavaScript 키는 클라이언트에 노출되도록 설계된 공개 키라 코드에 그대로 있어도 안전해요. 대신 각 서비스의 콘솔에서 "허용 도메인"을 등록해두는 것으로 오남용을 막습니다.
- Claude 아티팩트 미리보기 안에서는 `window.storage`(자체 영구 저장소)를, 실제 배포된 사이트에서는 브라우저 `localStorage`를 자동으로 사용하도록 되어 있어요.
