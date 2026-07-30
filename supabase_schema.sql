-- 오나오 랩: 레시피 저장 테이블 + 보안 정책(RLS) + 전역 재료 캐시
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요.
-- 이 스크립트는 몇 번을 다시 실행해도 안전합니다 (이미 있는 건 건너뜁니다).

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null default auth.uid(),
  name text not null,
  emoji text default '🥣',
  ingredients jsonb not null,      -- [{key, spoons}, ...]
  liquid text not null,
  ml integer not null default 150,
  custom_defs jsonb default '[]',  -- AI로 분석한 재료 정의 (이 레시피가 쓰는 것만)
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 사용자별 데이터 격리: 로그인한 본인 레시피만 보이고, 본인만 수정 가능
alter table public.recipes enable row level security;

drop policy if exists "본인 레시피 조회" on public.recipes;
create policy "본인 레시피 조회" on public.recipes
  for select using (auth.uid() = user_id);

drop policy if exists "본인 레시피 생성" on public.recipes;
create policy "본인 레시피 생성" on public.recipes
  for insert with check (auth.uid() = user_id);

drop policy if exists "본인 레시피 수정" on public.recipes;
create policy "본인 레시피 수정" on public.recipes
  for update using (auth.uid() = user_id);

drop policy if exists "본인 레시피 삭제" on public.recipes;
create policy "본인 레시피 삭제" on public.recipes
  for delete using (auth.uid() = user_id);

-- 수정 시각 자동 갱신
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists recipes_set_updated_at on public.recipes;
create trigger recipes_set_updated_at
  before update on public.recipes
  for each row execute function public.set_updated_at();

-- ============================================================
-- 전역 재료 캐시: 한 번 AI로 분석된 재료는 모든 사용자가 공유해서 재사용
-- ============================================================

create extension if not exists pg_trgm;

create table if not exists public.ingredients (
  id uuid primary key default gen_random_uuid(),
  name text not null,              -- 사람이 입력한 원본 이름 (예: "흑임자맛 프로틴")
  normalized_name text not null,   -- 공백 제거 + 소문자 (매칭용)
  emoji text,
  color text,
  kcal numeric not null,
  protein numeric not null,
  carb numeric not null,
  fat numeric not null,
  fiber numeric not null,
  created_at timestamptz default now()
);

-- 유사도 검색 속도를 위한 trigram 인덱스
create index if not exists ingredients_normalized_trgm_idx
  on public.ingredients using gin (normalized_name gin_trgm_ops);

alter table public.ingredients enable row level security;

-- 조회는 누구나 가능 (읽기 전용 공개 캐시)
drop policy if exists "누구나 재료 조회 가능" on public.ingredients;
create policy "누구나 재료 조회 가능" on public.ingredients
  for select using (true);

-- insert/update/delete 정책은 의도적으로 만들지 않음 -> RLS가 기본 차단.
-- 새 재료 등록은 서버(api/analyze.js, service_role 키)를 통해서만 가능.

-- 입력한 이름과 가장 비슷한 기존 재료 1개를 찾는 함수 (유사도 임계값 기본 0.35)
create or replace function public.match_ingredient(search_name text, min_similarity real default 0.35)
returns setof public.ingredients
language sql stable
as $$
  select *
  from public.ingredients
  where similarity(normalized_name, search_name) > min_similarity
  order by similarity(normalized_name, search_name) desc
  limit 1;
$$;

-- ============================================================
-- 즐겨찾기: 기본/커스텀/클라우드 레시피 공통으로 recipe_ref(레시피 id 문자열)만 저장
-- ============================================================

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null default auth.uid(),
  recipe_ref text not null,   -- 앱에서 쓰는 레시피 id (예: "r1", "cloud-uuid", "custom-169...")
  created_at timestamptz default now(),
  unique (user_id, recipe_ref)
);

alter table public.favorites enable row level security;

drop policy if exists "본인 즐겨찾기 조회" on public.favorites;
create policy "본인 즐겨찾기 조회" on public.favorites
  for select using (auth.uid() = user_id);

drop policy if exists "본인 즐겨찾기 추가" on public.favorites;
create policy "본인 즐겨찾기 추가" on public.favorites
  for insert with check (auth.uid() = user_id);

drop policy if exists "본인 즐겨찾기 삭제" on public.favorites;
create policy "본인 즐겨찾기 삭제" on public.favorites
  for delete using (auth.uid() = user_id);

-- ============================================================
-- 공유 링크: 레시피를 저장하고 짧은 코드(share_code)로 공유
-- ============================================================

create table if not exists public.shared_recipes (
  id uuid primary key default gen_random_uuid(),
  share_code text not null unique,   -- URL에 들어가는 짧은 코드 (예: "Ax7k2p")
  payload jsonb not null,            -- 레시피 전체 데이터 (이름/재료/밀크/커스텀재료 등)
  created_at timestamptz default now()
);

create index if not exists shared_recipes_code_idx on public.shared_recipes (share_code);

alter table public.shared_recipes enable row level security;

-- 공유 링크는 누구나 조회 가능 (로그인 없이 링크만 있으면 열람)
drop policy if exists "누구나 공유레시피 조회" on public.shared_recipes;
create policy "누구나 공유레시피 조회" on public.shared_recipes
  for select using (true);

-- 누구나 공유 링크 생성 가능 (로그인 없이도 공유하기 사용 가능)
drop policy if exists "누구나 공유레시피 생성" on public.shared_recipes;
create policy "누구나 공유레시피 생성" on public.shared_recipes
  for insert with check (true);

-- ============================================================
-- 식단 트래커: 날짜별 목표/끼니 기록 (사용자별)
-- ============================================================

create table if not exists public.diet_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null default auth.uid(),
  log_date date not null,
  weight numeric,              -- 목표 몸무게
  workout boolean default false, -- 운동일 여부 (탄수 사이클링)
  meals jsonb not null default '{"breakfast":[],"lunch":[],"dinner":[],"snack":[]}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, log_date)
);

alter table public.diet_logs enable row level security;

drop policy if exists "본인 식단 조회" on public.diet_logs;
create policy "본인 식단 조회" on public.diet_logs
  for select using (auth.uid() = user_id);

drop policy if exists "본인 식단 생성" on public.diet_logs;
create policy "본인 식단 생성" on public.diet_logs
  for insert with check (auth.uid() = user_id);

drop policy if exists "본인 식단 수정" on public.diet_logs;
create policy "본인 식단 수정" on public.diet_logs
  for update using (auth.uid() = user_id);

drop policy if exists "본인 식단 삭제" on public.diet_logs;
create policy "본인 식단 삭제" on public.diet_logs
  for delete using (auth.uid() = user_id);

drop trigger if exists diet_logs_set_updated_at on public.diet_logs;
create trigger diet_logs_set_updated_at
  before update on public.diet_logs
  for each row execute function public.set_updated_at();

-- 식단 스타일 (균형/저탄고지/카니보어) 컬럼 — 재실행 안전
alter table public.diet_logs add column if not exists diet text default 'balanced';
