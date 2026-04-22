# Tasks: 소셜 로그인 통합 (Social Login Integration)

**Input**: `/specs/002-social-login/` 설계 문서
**Prerequisites**: plan.md ✅, spec.md ✅, api-contracts.md ✅

## 포맷: `[ID] [P?] [Story?] 설명`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: 해당 유저 스토리 (예: US1, US2)
- **[Tnnn]**: 해당 Task의 하위 작업
- 정확한 파일 경로 포함

## Phase 1: Setup (인증 인프라 초기화)

**목적**: OAuth2 관련 타입, 설정 정의

- [ ] T001 [P] OAuth2 프로바이더 타입 및 인터페이스 정의 → `src/types/auth.ts`

## Phase 2: Foundational (인증 코어)

**목적**: 소셜 로그인 플로우에 필요한 핵심 서비스 및 유틸리티

- [ ] T002 OAuthService 클래스 생성 (토큰 교환, 프로필 조회 공통 로직) → `src/services/OAuthService.ts`
- [ ] T002-1 [T002] 토큰 교환 로직 구현 → `src/services/OAuthService.ts`
- [ ] T002-2 [T002] 프로필 조회 로직 구현 → `src/services/OAuthService.ts`
- [ ] T003 [P] 인증 상태 관리 훅 생성 → `src/hooks/useAuth.ts`

## Phase 3: User Story 1 — Google 로그인 (Priority: P1)

**목표**: 사용자가 로그인 페이지에서 Google 계정으로 로그인할 수 있다
**독립 테스트**: Google 로그인 버튼 클릭 → OAuth 동의 화면 → 콜백 → 대시보드 진입 확인

- [ ] T004 [US1] Google OAuth 콜백 API 엔드포인트 구현 → `src/api/auth/google/callback.ts`
- [ ] T005 [US1] GoogleLoginButton 컴포넌트 생성 → `src/components/Auth/GoogleLoginButton.tsx`
- [ ] T006 [US1] 로그인 페이지에 Google 버튼 배치 및 연동 → `src/pages/LoginPage.tsx`

## Phase 4: User Story 2 — GitHub 로그인 (Priority: P2)

**목표**: 사용자가 로그인 페이지에서 GitHub 계정으로 로그인할 수 있다
**독립 테스트**: GitHub 로그인 버튼 클릭 → OAuth 인가 → 콜백 → 대시보드 진입 확인

- [ ] T007 [US2] GitHub OAuth 콜백 API 엔드포인트 구현 → `src/api/auth/github/callback.ts`
- [ ] T008 [US2] GitHubLoginButton 컴포넌트 생성 → `src/components/Auth/GitHubLoginButton.tsx`
- [ ] T009 [US2] 로그인 페이지에 GitHub 버튼 배치 및 연동 → `src/pages/LoginPage.tsx`
