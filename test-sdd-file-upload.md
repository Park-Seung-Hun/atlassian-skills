# Tasks: 파일 업로드 기능 구현 (File Upload Capability)

**Input**: `/specs/003-file-upload/` 설계 문서
**Prerequisites**: plan.md ✅, spec.md ✅, api-contracts.md ✅

## 포맷: `[ID] [P?] [Story?] 설명`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: 해당 유저 스토리 (예: US1, US2)
- **[Tnnn]**: 해당 Task의 하위 작업
- 정확한 파일 경로 포함

## Phase 1: Setup (업로드 기본 설정)

**목적**: 파일 업로드 기능에 필요한 타입, 설정, 저장 경로 규칙을 정의한다

- [ ] T001 [P] 업로드 파일 메타데이터 타입 및 제한 정책 정의 → `src/types/upload.ts`

## Phase 2: Foundational (업로드 코어)

**목적**: 파일 전송, 검증, 업로드 상태 관리를 위한 공통 기반을 만든다

- [ ] T002 UploadService 클래스 생성 (파일 전송, 응답 파싱 공통 로직) → `src/services/UploadService.ts`
- [ ] T002-1 [T002] multipart/form-data 전송 로직 구현 → `src/services/UploadService.ts`
- [ ] T002-2 [T002] 파일 크기 및 확장자 검증 로직 구현 → `src/services/UploadService.ts`
- [ ] T003 [P] 업로드 상태 관리 훅 생성 → `src/hooks/useFileUpload.ts`

## Phase 3: User Story 1 — 사용자가 파일을 선택해 업로드할 수 있다 (Priority: P1)

**목표**: 사용자가 업로드 화면에서 파일을 선택하고 서버로 업로드할 수 있다
**독립 테스트**: 파일 선택 → 업로드 버튼 클릭 → 업로드 성공 응답 → 파일 목록 반영 확인

- [ ] T004 [US1] 파일 업로드 API 엔드포인트 구현 → `src/api/files/upload.ts`
- [ ] T005 [US1] FileUploadForm 컴포넌트 생성 → `src/components/FileUpload/FileUploadForm.tsx`
- [ ] T006 [US1] 업로드 페이지에 파일 선택 및 업로드 버튼 배치 → `src/pages/FileUploadPage.tsx`

## Phase 4: User Story 2 — 사용자가 업로드 진행 상태와 실패 원인을 확인할 수 있다 (Priority: P2)

**목표**: 사용자가 업로드 진행률과 오류 메시지를 확인해 업로드 결과를 이해할 수 있다
**독립 테스트**: 대용량 파일 업로드 시 진행률 표시, 허용되지 않은 파일 업로드 시 오류 메시지 노출 확인

- [ ] T007 [US2] 업로드 진행률 표시 UI 추가 → `src/components/FileUpload/UploadProgress.tsx`
- [ ] T008 [US2] 업로드 실패 시 오류 메시지 및 재시도 버튼 제공 → `src/components/FileUpload/FileUploadForm.tsx`
- [ ] T009 [US2] 업로드 결과를 파일 목록에 반영하고 상태 배지 표시 → `src/pages/FileUploadPage.tsx`
