# 오나오 랩 배포 가이드 (GitHub + Vercel)

이 폴더에는 세 가지가 들어있어요:

- `index.html` — 앱 본체
- `api/analyze.js` — 재료 이름을 받아 Anthropic API로 영양성분을 분석하는 서버리스 함수 (API 키는 여기서만, 서버 쪽에서만 사용돼요)
- `package.json` — Vercel이 프로젝트를 인식하기 위한 최소 설정 파일

## 1. GitHub에 올리기

1. github.com에서 새 저장소 생성 (예: `onao-lab`), Public이든 Private이든 상관없어요
2. 이 폴더(`index.html`, `api/analyze.js`, `package.json`)를 그대로 저장소에 업로드
   - 웹에서 "uploading an existing file"로 드래그 앤 드롭해도 되고
   - 로컬에 git이 있다면:
     ```
     git init
     git add .
     git commit -m "오나오 랩 초기 배포"
     git branch -M main
     git remote add origin https://github.com/내아이디/onao-lab.git
     git push -u origin main
     ```

## 2. Vercel로 배포하기

GitHub Pages는 정적 파일만 서빙하고 서버리스 함수(`api/analyze.js`)를 실행할 수 없어서, **Vercel**을 사용해요. Vercel은 같은 GitHub 저장소를 그대로 가져와서 정적 페이지 + API 함수를 함께 배포해줘요.

1. https://vercel.com 접속 → GitHub 계정으로 로그인
2. "Add New..." → "Project" → 방금 만든 `onao-lab` 저장소 선택 → Import
3. 프레임워크는 자동 감지 안 돼도 상관없어요 (Other로 둬도 정적 파일 + `/api`는 그대로 인식됩니다)
4. **배포 전에 환경변수 설정이 꼭 필요해요:**
   - Project Settings → Environment Variables
   - Key: `ANTHROPIC_API_KEY`
   - Value: console.anthropic.com에서 발급받은 API 키 (sk-ant-... 로 시작)
   - 적용 범위는 Production/Preview/Development 전부 체크
5. Deploy 클릭 → 1~2분 뒤 `https://onao-lab.vercel.app` 같은 주소가 생겨요

## 3. 확인

배포된 주소로 접속해서 재료 추가 → "🔍 분석하고 추가하기"를 눌러보세요. "흑임자맛 프로틴"처럼 특이한 재료도 실제 AI가 분석한 값이 나오면 정상 작동하는 거예요.

## 4. AI 호출을 아끼는 방법 (이미 적용됨)

앱은 재료를 추가할 때마다 무조건 AI를 부르지 않아요:

1. 먼저 기본 재료 DB(17종)와 **이전에 한 번이라도 분석한 재료 이름**을 확인해요
2. 이미 아는 이름이면 저장된 값을 바로 재사용하고 AI는 호출하지 않아요
3. 완전히 새로운 이름일 때만 AI를 호출하고, 그 결과를 영구 저장해서 다음부터는 다시 안 물어봐요

저장은 Claude 아티팩트 안에서는 `window.storage`를, Vercel 등에 배포된 뒤에는 브라우저 `localStorage`를 자동으로 사용해요 (기기별로 저장되는 점 참고하세요).

## 참고


- API 키는 절대 `index.html`이나 클라이언트 코드에 직접 넣지 마세요. 반드시 Vercel 환경변수로만 관리하세요.
- Anthropic API는 호출량만큼 과금돼요 (console.anthropic.com에서 사용량/한도 확인 가능).
- 저장 레시피(레시피 저장하기)는 Claude 아티팩트 안에서는 `window.storage`로 저장되지만, Vercel에 배포된 버전에서는 이 스토리지 API가 없어서 저장이 동작하지 않아요. 필요하시면 브라우저 localStorage나 별도 DB 연동으로 바꿔드릴 수 있어요.
