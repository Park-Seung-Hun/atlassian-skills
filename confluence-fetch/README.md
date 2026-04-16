# confluence-fetch

Confluence Cloud 페이지를 로컬 Markdown 파일로 내려받는 스킬.

`confluence-write`(Markdown → Confluence 업로드)의 역방향이지만, **완전한 역함수가 아니다.** Kroki로 렌더된 다이어그램의 원본 DSL, 다단 레이아웃, jira/children-display/status 같은 위젯형 매크로는 Confluence에 보존되지 않거나 Markdown에 대응 문법이 없다. 이 스킬은 **손실 변환**이며, 변환되지 않은 요소는 출력 파일 말미(`## Confluence Conversion Notes`)와 frontmatter `losses:` 필드에 집계형으로 보고한다.

---

## 설계 의도 / 스코프

### 단일 페이지 전용 (의도적 v1 스코프)

자식 페이지 재귀 다운로드, sync(재동기화), 순수 MD 출력(frontmatter 제거) 모드는 v2+ 스코프다. v1은 "한 페이지를 편집 가능한 Markdown으로 빠르게 꺼내기"에 집중한다.

### 왜 processed_html을 변환 원천으로 쓰는가

`confluence_get_page(convert_to_markdown=false)`를 호출하면 raw Confluence storage XML이 아니라 **BeautifulSoup으로 전처리된 HTML(`processed_html`)** 이 반환된다. 이 점이 설계의 핵심 전제다.

- `processed_html`은 대부분의 표준 HTML 요소(`<h1>~<h6>`, `<table>`, `<ul>` 등)로 이루어져 있으며, 일부 Confluence 매크로 잔재(`<ac:structured-macro>`, `<ri:attachment>` 등)가 남아 있다.
- 이 포맷을 변환 원천으로 쓰면 lxml/BeautifulSoup 같은 외부 라이브러리 설치 없이 LLM 인라인 치환만으로 Markdown을 조립할 수 있다.
- Bash는 디렉토리 생성(`mkdir`)과 base64 디코딩에만 쓴다.

### MCP-only 설계

외부 HTTP 호출(Confluence REST API 직접 호출 등)은 하지 않는다. 모든 Confluence 접근은 `mcp-atlassian` 서버를 통한다.

---

## 손실 변환 한계

아래 항목은 구조적 이유로 완전 복원이 불가능하다. 스킬은 이를 무시하지 않고 명시적으로 기록한다.

### mermaid / plantuml / d2 원본 DSL 복원 불가

`confluence-write`는 mermaid/plantuml/d2 코드블록을 Kroki로 PNG/SVG로 렌더링해 첨부 이미지로 업로드한다. 페이지에는 이미지 파일만 남고 원본 DSL은 어디에도 보존되지 않는다. `confluence-fetch`는 해당 이미지 파일만 내려받을 수 있다. `## Confluence Conversion Notes`에 "본문의 일부 이미지는 다이어그램에서 렌더된 것일 수 있으며 원본 DSL 복원 불가"라는 일반 경고를 추가한다.

### 병합셀 테이블 (colspan / rowspan)

GFM 테이블은 colspan/rowspan을 표현할 수 없다. 억지로 flatten하면 의미가 손상된다. v1에서는 raw HTML을 그대로 유지하고 `losses.merged_tables` 카운터를 증가시킨다.

### 다단 레이아웃

Confluence의 2단/다단 레이아웃(`<div class="columnLayout-*">` 또는 `ac:layout` 잔재)은 Markdown에 대응 문법이 없다. 마찬가지로 raw HTML 유지 + `losses.multi_column_layouts` 집계.

### 위젯형 매크로

아래 매크로는 Markdown으로 변환할 수 없다. 본문에 `[Confluence macro: <name>]` placeholder로 치환하고 `losses.unsupported_macros` 카운터에 기록한다.

- `jira` (Jira 이슈 임베드)
- `children-display` (자식 페이지 목록)
- `status` (상태 라벨 위젯)
- `user profile` (사용자 카드)
- `excerpt`, `excerpt-include`
- info/note/warning/tip 외의 panel 변형, LaTeX/수식, 페이지 포함 매크로 등

### 렌더 보장 없는 GFM 확장 문법

GFM alert(`> [!NOTE]` 등)와 `<details>` 블록은 문법 자체는 보존한다. 다만 이 문법이 **모든 Markdown 뷰어에서 동일하게 렌더된다는 보장은 아니다**. GitHub 웹 UI와 Obsidian은 대체로 정상 렌더되지만, VS Code 기본 Markdown 미리보기나 일부 터미널 뷰어는 다르게 표시될 수 있다.

---

## 핵심 동작 요약

상세 스펙은 `confluence-fetch.body.md`를 참조한다. 아래는 각 Step의 한 줄 요약.

| Step | 요약 |
|------|------|
| Step 0 | 입력을 page_id(숫자) / URL(4종 패턴) / 자연어 중 하나로 판정. 기본값 안내 1회 후 추가 질문 없이 진행. |
| Step 0b | 자연어 경로일 때만 실행. 스페이스 키 수집 후 CQL exact-title → 부분일치 순으로 검색해 후보를 제시. |
| Step 1 | `confluence_get_page`와 `confluence_get_attachments`로 페이지 본문(processed_html)과 첨부 메타를 수집하고, 본문에서 참조된 첨부 ID 집합과 합계 크기/개수를 계산. |
| Step 2 | processed_html을 v1 규칙표에 따라 Markdown으로 역변환. 미지원 요소는 placeholder 처리 + 손실 집계. |
| Step 3 | 임계치(10MB / 20개) 이내면 참조된 첨부만 개별 다운로드해 사이드카 폴더에 저장. 초과 시 원격 URL 유지. |
| Step 4 | frontmatter + 변환된 본문 + Conversion Notes 섹션을 조합해 MD 파일로 저장. 기존 파일 있으면 덮어쓰기/이름 변경 확인. |
| Step 5 | 저장 경로, 첨부 요약, 원본 Confluence URL, 손실 항목을 집계해 최종 보고. |

---

## 첨부 처리 정책

- **참조된 첨부만 다운로드**: 본문의 `<img src>`, `<a href>`, `<ri:attachment>` 잔재를 스캔해 실제 참조된 attachment ID 집합에 한해 처리한다. 페이지에 업로드된 전체 첨부를 긁는 방식은 쓰지 않는다.
- **파일명 규칙**: `att<attachment_id>-<sanitized_name>` 고정. 재다운로드(sync) 시 파일명이 흔들리지 않도록 attachment_id를 prefix로 쓴다.
- **임계치**: 참조된 첨부의 합계 크기 > 10MB 또는 개수 > 20개이면 로컬 미러링을 중단하고 원격 URL을 그대로 유지한다. 이 경우 `attachment_manifest`는 `{ skipped_reason: "threshold_exceeded" }`로 축약된다.
- **사이드카 폴더**: `<slug>.assets/`. 슬러그 충돌 폴백(`<slug>--<page_id>.md`) 사용 시 사이드카도 `<slug>--<page_id>.assets/`로 동일한 suffix를 공유한다.
- **50MB 초과 단일 첨부**: MCP가 거절하면 그 항목만 건너뛰고 `losses.download_failures`에 기록한다. 나머지 첨부는 계속 진행.

---

## Frontmatter (원본 페이지 정보 헤더)

저장되는 MD 파일의 선두에 아래 YAML frontmatter가 붙는다.

```yaml
---
source: confluence
source_format: processed_html
page_url: https://<tenant>.atlassian.net/wiki/spaces/<KEY>/pages/<ID>
page_id: "<ID>"
space_key: <KEY>
title: "<TITLE>"
version: <N>
updated: <ISO8601>
fetched_at: <ISO8601>
attachment_manifest:
  - id: "<attachment_id>"
    original: "<original_filename>"
    stored: "att<id>-<sanitized>"
    bytes: <size>
losses:
  unsupported_macros: { jira: 3, children-display: 1 }
  merged_tables: 1
  multi_column_layouts: 1
  internal_page_links: 5
  download_failures: [ "huge.pdf" ]
---
```

주요 규칙:

- `page_id`는 **반드시 큰따옴표로 감싼 문자열**로 쓴다. YAML이 정수로 파싱하면 선행 0 손실 또는 과학 표기법 변환 문제가 생길 수 있다.
- `source_format: processed_html`은 이 파일이 raw storage XML이 아니라 MCP가 전처리한 HTML 기반으로 변환되었음을 명시한다. 향후 sync 스킬이 변환 방식을 식별하는 데 쓸 수 있다.
- `attachment_manifest`는 실제 저장된 첨부의 목록이다. 임계치 초과 시 `{ skipped_reason: "threshold_exceeded" }`로 대체된다.
- `losses:`는 손실 항목의 집계다. sync 스킬이 "어떤 요소가 손실되었는지"를 파악하는 기준으로 쓰인다. 손실이 전혀 없으면 이 필드 자체를 생략해도 무방하다.

---

## 수동 배포 절차

현재 `scripts/build-skills.sh`가 없으므로 아래 방식으로 수동 배포한다. **CLAUDE.md의 project scope 선배포 원칙에 따라 전역 배포 전에 반드시 project scope에서 실전 검증 1회 이상을 수행한다.**

### Claude Code — project scope (권장 1차 테스트 경로)

대상 프로젝트의 `.claude/commands/confluence-fetch.md`를 직접 작성한다.

1. `confluence-fetch.claude.yml`의 frontmatter 내용을 복사한다.
2. 바로 아래에 `confluence-fetch.body.md`의 본문을 이어붙인다.

```bash
# 결합 후 파일 구조 (예시)
# ---
# allowed-tools: Read, Write, Bash, mcp__mcp-atlassian__confluence_search, ...
# description: Confluence Cloud 페이지를 Markdown 파일로 내려받아 현재 작업 디렉토리에 저장한다.
# disable-model-invocation: false
# ---
#
# <body.md 본문 전체>
```

배포 경로: `<project>/.claude/commands/confluence-fetch.md`

### Claude Code — global

동일한 방식으로 `~/.claude/commands/confluence-fetch.md`에 작성한다.

project scope에서 실전 검증을 마친 뒤에만 전역 배포를 진행한다.

### Codex CLI — global

```bash
mkdir -p ~/.agents/skills/confluence-fetch
```

`~/.agents/skills/confluence-fetch/SKILL.md`를 아래 방식으로 작성한다.

1. `confluence-fetch.codex.yml`의 frontmatter 내용을 복사한다.
2. 바로 아래에 `confluence-fetch.body.md`의 본문을 이어붙인다.

Codex Agent Skills는 표준상 `~/.agents/skills/` 아래에서만 자동 인식된다. project scope는 Claude만 해당된다.

---

## 향후 빌드 스크립트 통합

`scripts/build-skills.sh`가 추가되면 `SKILLS` 배열에 아래 엔트리를 등록한다.

```bash
SKILLS=(
  # ...
  "confluence-fetch:confluence-fetch:"   # shared_body 없음
)
```

빌드 스크립트가 생기면 위 수동 절차 대신 `bash scripts/build-skills.sh`로 자동 배포가 가능해진다.

---

## MCP 의존

`mcp-atlassian` 서버가 필요하다. Claude는 `~/.claude.json` 또는 `~/.claude/`에서, Codex는 `~/.codex/config.toml`에서 등록 여부를 확인한다.

### 사용하는 MCP 도구 (allowed-tools에 선언된 것과 동일)

| 도구 | 용도 |
|------|------|
| `confluence_search` | 자연어 입력 시 CQL로 페이지 검색 |
| `confluence_get_page` | 페이지 본문(processed_html) 및 메타 수집 |
| `confluence_get_attachments` | 페이지에 업로드된 첨부 메타 리스트 수집 |
| `confluence_download_attachment` | 참조된 첨부를 개별 base64로 다운로드 |

### 사용하지 않는 MCP 도구

- `confluence_get_page_images`: 참조 여부와 무관하게 페이지의 모든 이미지를 긁어온다. 이 스킬의 "본문에서 참조된 항목만 다운로드"라는 정책과 충돌하므로 사용하지 않는다.

---

## 알려진 미해결 / 향후 개선

- **processed_html의 정확한 잔재 형태 미확정**: mcp-atlassian의 preprocessing 결과물은 대표 페이지(매크로·테이블·이미지·다단 레이아웃 포함)를 한 번 실제 호출해서 확인해야 한다. 첫 구현 시 실측 결과를 바탕으로 `confluence-fetch.body.md`의 규칙표를 미세조정한다.
- **`confluence_get_page` 메타 필드 경로**: `include_metadata=true` 응답에서 `version.number`, `version.when`, `_links.base` 등이 어떤 키 이름으로 오는지 실제 응답 구조를 확인한 뒤 본문을 보완할 필요가 있다.
- **CQL exact title 동작**: `title = "..."` 쿼리가 완전 일치로 동작하는지, 내부적으로 부분 일치로 떨어지는지 Confluence CQL 문서상 명확하지 않다. 실측 후 2차 `~` 쿼리만 사용하는 방향으로 단순화할 수 있다.
- **v2+ 스코프**: 페이지 트리 재귀 다운로드, 재동기화(sync), frontmatter 없는 순수 MD 출력 모드는 v1 이후에 검토한다.
