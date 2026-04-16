# confluence-write

Confluence Cloud에 **기술 문서**(SDD/Spec 중심)를 잘 쓰기 위한 스킬 도메인.

이 README는 "왜 이 스킬을 만들었는가 / 왜 이런 포맷을 선택했는가"에 대한 근거를 남긴다. 실제 스킬 본문(`*.body.md`)과 프론트매터(`*.claude.yml`, `*.codex.yml`)는 설계 완료 후 추가한다.

---

## 배경 — 문제 상황

Confluence에 기술 문서를 쓸 때 반복적으로 겪는 고통:

1. **Mermaid / D2 다이어그램이 렌더링되지 않는다** — 대부분의 워크스페이스에 관련 매크로/앱이 설치되어 있지 않아, 에디터 코드블록으로만 남고 시각화되지 않음.
2. **Markdown 문법이 일부만 먹힌다** — 체크박스, GFM Alert(`> [!NOTE]`), 중첩 리스트, 수식 등이 깨지거나 리터럴로 남는 경우가 자주 발생.
3. **결과**: LLM이 생성한 초안이 "보기엔 깔끔한 Markdown인데 업로드하면 스타일이 망가진" 상태로 나와 사람이 수동으로 고쳐야 함.

대상 사용자(SDD 작성자)에게 "**업로드 직후 바로 보기 좋고, 수동 수정이 최소화된**" 문서를 만들어 주는 것이 이 스킬의 목표.

---

## 조사 요약 — Confluence가 받는 페이지 포맷 4종

Confluence Cloud REST API는 페이지 본문을 4가지 포맷 중 하나로 받는다:

| 포맷 | 내부 구조 | mcp-atlassian 지원 |
|------|----------|-------------------|
| `markdown` | 서버/클라이언트가 HTML로 변환 후 storage에 저장 | ✅ |
| `wiki` | Confluence 서버가 wiki markup → storage 변환 | ✅ |
| `storage` | XHTML 기반, Confluence 내부 저장 형태 그대로 | ✅ |
| `atlas_doc_format` (ADF) | JSON, v2 API 전용 | ❌ (별도 REST 호출 필요) |

### 실증 테스트 결과 (2026-04, 개인 스페이스 대상)

각 포맷별로 SDD에 필요한 주요 요소를 찍어서 실제 렌더링을 확인했다.

| 기능 | `markdown` | `wiki` | **`storage`** |
|------|:---------:|:------:|:------------:|
| 헤딩 / 인라인 포맷 / 링크 / 표 | ✅ | ✅ | ✅ |
| 중첩 비순서 리스트 | ❌ flatten | ✅ | ✅ |
| 중첩 순서 리스트 | ❌ 전부 1단계 | ✅ | ✅ |
| **네이티브 코드 매크로** (언어·제목·줄번호·collapse) | ❌ `<pre><code>`만 | ✅ | ✅ (파라미터 전체 제어) |
| **콜아웃** (info / note / warning / tip) | ❌ blockquote 리터럴 | ✅ | ✅ |
| 커스텀 panel (색 / 테두리 / 타이틀 배경) | ❌ | ✅ | ✅ |
| expand (토글) / status 라벨 / TOC / children | ❌ | ✅ | ✅ |
| **태스크 리스트** (`ac:task-list`, 체크박스) | ❌ | ❌ | ✅ **유일 지원** |
| **사용자 멘션** (`ri:user`) | ❌ | ❌ | ✅ **유일 지원** |
| **2단 / 다단 레이아웃** (`ac:layout`) | ❌ | ❌ | ✅ **유일 지원** |
| 네이티브 이모티콘 (`ac:emoticon`) | shortcode → 유니코드만 | 별도 문법 | ✅ |
| GFM Alert (`> [!NOTE]`) | ❌ 리터럴 | N/A | N/A |
| LaTeX 수식 (`$...$`, `$$...$$`) | ❌ 리터럴 | ❌ | ❌ (외부 앱 필요) |
| Mermaid / PlantUML / D2 | 코드블록만 | 코드블록만 | 코드블록만 |
| Footnote / Definition List / `<details>` / `<kbd>` / `<mark>` | ❌ | ❌ | ❌ |

---

## 포맷 선택 — `storage`

SDD/Spec 문서의 **기본 작성 포맷은 `storage` (XHTML)** 로 확정한다.

### 근거

1. **기술 문서 필수 기능이 storage 전용** — 태스크 체크리스트(TODO·Action Item), 사용자 멘션(담당자 지정), 2단 레이아웃(요약 vs 상세 병치)은 다른 포맷으로 불가능.
2. **코드 블록 품질** — SDD는 코드 스니펫이 많은데, `storage`는 `ac:structured-macro[name=code]`에 `language`, `title`, `linenumbers`, `collapse`, `theme`을 전부 붙일 수 있음. `markdown`은 `<pre><code class="language-X">`만 나가 Confluence 네이티브 하이라이트가 붙지 않음.
3. **콜아웃(info/note/warning/tip)이 제대로 나감** — `markdown`에선 GFM alert가 전부 깨져 리터럴 `[!NOTE]`로 남음.
4. **wiki가 할 수 있는 것은 storage가 전부 커버** — wiki는 사실상 storage로 변환되는 중간 단계. storage를 직접 쓰면 매크로 파라미터를 더 세밀하게 제어할 수 있음.
5. **학습 곡선 문제는 스킬이 해결** — 사용자가 XHTML을 직접 쓰는 게 아니라, 스킬이 템플릿 기반으로 생성한다. 사용자는 자연어로 지시만 하면 됨.

### `atlas_doc_format` (ADF)를 쓰지 않는 이유

- `mcp-atlassian`이 ADF를 파라미터로 받지 않음. 사용하려면 별도 REST 호출로 우회해야 함.
- 이중 JSON 인코딩 등 API 사용 함정이 있음([ref](https://community.developer.atlassian.com/t/confluence-rest-api-v2-create-page-with-atlas-doc-format-representation/67565)).
- storage와 기능 동등 이상의 이점이 SDD 맥락에서 뚜렷하지 않음.

---

## 플러그인 없는 환경 — 다이어그램 전략 (Track B)

이 워크스페이스에는 Mermaid / draw.io / PlantUML / LaTeX 매크로가 설치되어 있지 않음. 2026-04 실증으로 확정된 대체 파이프라인:

### 기본 경로 — Kroki 렌더링 → 첨부 업로드 → `ac:image` 임베드

1. 사용자 Mermaid/PlantUML/D2 소스를 받거나 스킬이 생성한다.
2. [Kroki](https://kroki.io) 공개 서비스에 `curl --data-binary @src https://kroki.io/<type>/<format>`로 POST → PNG/SVG 파일을 받는다. 로컬 설치 불필요.
3. `confluence_upload_attachment`로 페이지에 첨부.
4. storage format에 `<ac:image ac:width="W"><ri:attachment ri:filename="..."/></ac:image>`로 임베드.

### 실증 결과 (Kroki → Confluence)

| 다이어그램 유형 | Kroki 엔진 | 포맷 | Confluence 렌더 | 메모 |
|----------------|----------|------|----------------|------|
| Flowchart / Decision | `mermaid` | PNG ✅ | ✅ | 21KB 수준 |
| Sequence | `mermaid` | PNG ✅ | ✅ | SDD 필수 요소 |
| ERD | `plantuml` | PNG ✅ | ✅ | 가장 작음 (~4KB) |
| Architecture (D2) | `d2` | **SVG 전용** ⚠️ | ✅ | PNG 요청 시 HTTP 400, SVG는 정상 렌더 |
| 상태전이 | — | 표 | ✅ | `From / Event / To / Guard` 구조 권장 |
| API 엔드포인트 맵 | — | 표 | ✅ | `Method / Path / Auth / Handler` |
| 단순 컴포넌트 박스 | — | ASCII 코드블록(`{code:text}`) | ✅ | 오프라인/네트워크 차단 환경 폴백 |

**주요 관찰**:
- `<ac:image>`는 view 렌더링 시 `<img src="download/attachments/...">` 태그로 변환되어 실제로 표시됨.
- 첨부 `media_type`이 `application/octet-stream`으로 저장되지만 Confluence가 파일명 기반으로 이미지로 인식.
- `ac:width` 속성으로 다이어그램별 너비 튜닝 가능 (플로우 700, ERD 500 등).
- 파일명이 alt 텍스트로 들어가므로 의미 있는 이름 부여 필요 (예: `login-flow.png`).

### 다이어그램 유형별 권장 (SDD 기준)

| 유형 | 1순위 | 2순위 (폴백) |
|------|------|------------|
| 플로우 / 의사결정 | Mermaid `flowchart` → PNG | ASCII 박스 |
| 시퀀스 | Mermaid `sequenceDiagram` → PNG | 표 (참여자 × 단계) |
| ERD | PlantUML entity → PNG | 표 (엔티티별 필드) |
| 컴포넌트 / 아키텍처 | D2 → SVG | Mermaid `graph LR` / ASCII 박스 |
| 상태 전이 | **표** (From/Event/To/Guard) | Mermaid `stateDiagram` |
| API 엔드포인트 목록 | **표** (Method/Path/Auth/Handler) | — (다이어그램 불필요) |
| 클래스 / 패키지 | PlantUML class → PNG | 표 |

### 네트워크 불가 환경 폴백

Kroki가 막힌 회사 네트워크라면:
- 옵션 A: 로컬 `mermaid-cli` (`mmdc`) 설치 후 같은 플로우 (렌더링만 로컬)
- 옵션 B: 다이어그램 생략 → ASCII 코드블록 + 표 조합으로 대체
- 스킬 설정(`{{CONFIG_PATH}}`)에서 `diagram_backend: kroki | mmdc | none` 플래그로 선택 가능하게 설계

---

## 외부 의존 — 추가 MCP 불필요

- **핵심**: `mcp-atlassian` (페이지 CRUD + 첨부 업로드)만으로 전체 파이프라인 커버.
- **다이어그램 렌더링**은 MCP가 아니라 로컬 Bash(`curl kroki.io` 또는 `mmdc`)로 처리.
- 별도 MCP 서버 추가 설치 필요 없음.

---

## 스킬 구성 계획

- **`confluence-write`** (메인 스킬): 자연어 지시를 받아 storage format 문서 초안을 생성하고 지정 스페이스에 업로드. 다이어그램 요청 시 Mermaid 소스를 받아 Kroki로 렌더링 후 첨부. 초기 타깃 문서 유형은 SDD/Spec.
- **`confluence-write-setup`** (예정): 최초 실행 시 스페이스 키, 상위 페이지 ID, Kroki 사용 여부 등을 수집해 `{{CONFIG_PATH}}`에 저장.

구조·프론트매터·`SKILLS` 배열 등록은 Track C(템플릿 설계) 완료 후 확정한다.

---

## 참고 문서

- [Confluence Cloud REST API — Content Body](https://developer.atlassian.com/cloud/confluence/rest/api-group-content-body/)
- [Confluence Storage Format 공식 문서](https://confluence.atlassian.com/doc/confluence-storage-format-790796544.html)
- [ADF vs Storage Format (Atlassian Developer Community)](https://community.developer.atlassian.com/t/can-i-create-content-in-confluence-cloud-using-atlassian-document-format-adf-rather-than-storage-format/30720)
- [Confluence REST API v2 — ADF 생성 가이드](https://community.developer.atlassian.com/t/confluence-rest-api-v2-create-page-with-atlas-doc-format-representation/67565)
- [Kroki — 다이어그램 렌더링 서비스](https://kroki.io)
