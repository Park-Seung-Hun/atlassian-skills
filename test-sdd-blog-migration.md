# Tasks: 노션 개발 공부 내용을 GitHub Blog로 이전

**Input**: `/notes/dev-study-notion/` 원문 정리 문서
**Prerequisites**: 이전할 주제 선정 ✅, 원문 검토 ✅

## 포맷: `[ID] [P?] [Story?] 설명`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: 해당 유저 스토리 (예: US1, US2)
- **[Tnnn]**: 해당 Task의 하위 작업
- 정확한 파일 경로 포함

## Phase 1: Setup (이전 대상 정리)

**목적**: 노션 원문에서 게시 대상으로 삼을 범위와 게시글 메타데이터를 정리한다

- [ ] T001 게시글 제목, slug, 발행 카테고리 초안 정의 → `_posts/2026-04-21-notion-dev-study-migration.md`
- [ ] T002 [P] 노션 원문에서 게시 대상 섹션과 제외 섹션 분류 → `docs/notion-dev-study-outline.md`

## Phase 2: Foundational (게시글 뼈대 작성)

**목적**: GitHub Blog 게시글 형식에 맞는 본문 구조와 자산 배치 기준을 만든다

- [ ] T003 블로그 front matter 및 섹션 골격 작성 → `_posts/2026-04-21-notion-dev-study-migration.md`
- [ ] T004 코드 예시와 참고 링크를 블로그 문체로 정리 → `_posts/2026-04-21-notion-dev-study-migration.md`
- [ ] T004-1 [T004] 코드 블록 언어 태그 및 형식 통일 → `_posts/2026-04-21-notion-dev-study-migration.md`
- [ ] T005 [P] 이미지/첨부 파일 저장 경로 규칙 정리 → `assets/images/posts/notion-dev-study/README.md`

## Phase 3: User Story 1 — 학습 내용을 블로그 글로 읽을 수 있다 (Priority: P1)

**목표**: 사용자가 노션에 있던 개발 공부 내용을 GitHub Blog 게시글 형태로 읽을 수 있다
**독립 테스트**: 생성된 Markdown 파일을 열어 제목, 도입, 본문, 정리 섹션이 자연스럽게 이어지는지 확인

- [ ] T006 [US1] 노션 핵심 내용을 블로그 본문 초안으로 옮기기 → `_posts/2026-04-21-notion-dev-study-migration.md`
- [ ] T007 [US1] 문단 흐름과 소제목을 블로그 독자 관점으로 다듬기 → `_posts/2026-04-21-notion-dev-study-migration.md`
- [ ] T008 [US1] 게시글 마지막에 요약과 참고 링크 섹션 추가 → `_posts/2026-04-21-notion-dev-study-migration.md`

## Phase 4: User Story 2 — 게시에 필요한 증거와 자산이 함께 정리된다 (Priority: P2)

**목표**: 사용자가 게시글 파일 경로와 관련 자산 위치를 함께 확인할 수 있다
**독립 테스트**: 게시글 파일 경로와 이미지 자산 경로가 문서와 디렉터리에 일관되게 남아 있는지 확인

- [ ] T009 [US2] 게시글에서 사용하는 이미지 자산 이동 및 경로 반영 → `assets/images/posts/notion-dev-study/diagram-01.png`
- [ ] T010 [US2] 게시글 파일 경로와 관련 자산 경로를 작업 메모에 기록 → `docs/notion-dev-study-outline.md`
- [ ] T011 [US2] 최종 게시 전 링크/코드 블록/이미지 참조 점검 → `_posts/2026-04-21-notion-dev-study-migration.md`
