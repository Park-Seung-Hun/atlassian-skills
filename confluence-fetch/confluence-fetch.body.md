Confluence Cloud 페이지를 내려받아 현재 작업 디렉토리에 Markdown 파일로 저장한다. `confluence-write`의 역방향이지만 **완전한 역함수가 아니다** — Kroki로 렌더된 다이어그램의 원본 DSL, 다단 레이아웃, jira/children-display/status 같은 위젯형 매크로는 Confluence에 보존되지 않거나 Markdown에 대응 문법이 없다. 이 스킬은 **손실 변환**이며, 변환되지 않은 요소는 문서 말미와 frontmatter에 집계형으로 보고한다.

호출 즉시 아래 기본값으로 진행한다:

- 저장 경로: 현재 작업 디렉토리
- 원본 페이지 정보 헤더(YAML frontmatter): 포함
- 첨부 다운로드: 본문에서 참조된 항목만 (이미지 + 링크된 비이미지)
- 첨부 임계치: 합계 **10MB** 또는 **20개** 초과 시 로컬 미러링 생략, 원격 URL 유지

"변경하실 항목이 있으면 지금 알려주세요"라고 한 번만 안내하고, 사용자가 별도 언급이 없으면 그대로 Step 1로 진행한다. **Step 0에서 이외의 질문은 하지 않는다.**

---

## Step 0 — 입력 수집 및 분기

사용자의 첫 입력 `x`를 다음 순서로 판정한다.

1. **순수 숫자** → `page_id` 경로. 그대로 Step 1로.
2. **`http(s)://`로 시작** → URL 경로. 아래 4종 패턴을 순차로 매칭해 `page_id`를 추출:
   - `/wiki/spaces/<KEY>/pages/<ID>/...`
   - `/spaces/<KEY>/pages/<ID>/...`
   - `/pages/viewpage.action?...pageId=<ID>`
   - 쿼리스트링 `pageId=<ID>` (경로 형태 무관)
   - 네 패턴 모두 실패 시 폴백: "URL에서 페이지 ID를 추출하지 못했습니다. 숫자 page_id로 알려주세요." 로 재질의.
3. **그 외(자연어)** → Step 0b로.

추가 옵션 질문은 없다. 기본값 안내 1회 후 그대로 진행한다.

### Step 0b — 자연어 후보 제시 (자연어 경로일 때만)

1. 스페이스 키를 먼저 받는다 — "어느 스페이스에서 검색할까요? space key를 알려주세요 (예: `DEV`)." (필수)
2. **1차 exact**: `mcp__mcp-atlassian__confluence_search` 호출, CQL:
   ```
   space = "<KEY>" AND title = "<질의>" AND type = "page"
   ```
3. **2차 부분일치 + 최신순**: 1차 결과가 0개면 아래 CQL로 재검색:
   ```
   space = "<KEY>" AND title ~ "<질의>" AND type = "page" ORDER BY lastModified DESC
   ```
4. 결과 처리:
   - 0개: "일치하는 페이지를 찾지 못했습니다. 질의어를 다시 알려주세요."
   - 1개: 확인 메시지 출력 후 Step 1로.
   - 2~10개: 번호를 매겨 `제목 | 상위 경로 | 최종 수정일` 형식으로 표시하고 사용자가 선택하도록 한다.
   - 10개 초과: "후보가 10개를 넘습니다. 더 구체적인 제목으로 다시 알려주세요."

---

## Step 1 — 페이지 원문과 첨부 메타 수집

1. `mcp__mcp-atlassian__confluence_get_page(page_id, convert_to_markdown=false, include_metadata=true)` 호출.
   - **반환 본문은 raw storage XML이 아니라 BeautifulSoup으로 전처리된 HTML(`processed_html`)**이다. 일부 `<ac:*>` / `<ri:*>` 매크로 잔재가 HTML 속성이나 class로 남아 있을 수 있으나, 기본은 HTML 기준으로 해석한다.
   - 메타에서 `title`, `space.key`, `version.number`, `version.when`, `_links.base`, `_links.webui` 등을 추출해 frontmatter용으로 보관한다.
2. `mcp__mcp-atlassian__confluence_get_attachments(content_id=page_id)` 호출 → 첨부 메타 리스트(attachment_id, filename, mediaType, size).
3. `processed_html`을 스캔해 **실제 본문에서 참조된 attachment ID 집합**을 수집한다. 참조 판정 소스:
   - `<img src="...">`에 포함된 attachment URL
   - `<a href="...">`에 포함된 attachment URL
   - 잔재로 남을 수 있는 `<ac:image>` / `<ac:link>` 하위의 `<ri:attachment ri:filename="..."/>`
4. 참조된 첨부들의 합계 크기와 개수를 계산한다. 이 값이 Step 3의 임계치 판정 기준이다.
5. 권한 오류(403) / 페이지 없음(404)이면 즉시 중단하고 사용자에게 원인을 명확히 보고한다. 부분 산출물은 남기지 않는다.

---

## Step 2 — HTML → Markdown 역변환 (보수적 v1 규칙표)

`processed_html`을 순회하며 아래 규칙으로 Markdown을 조립한다. 처리 순서는 **내부(가장 깊은 자식) → 외부** 순. HTML 엔티티(`&amp;`, `&lt;` 등)는 표준 디코딩하고, CDATA가 남아 있으면 내용만 추출한다.

> processed_html은 mcp-atlassian preprocessing의 결과물이다. 정확한 잔재 태그 형태는 대표 페이지(매크로·테이블·이미지·다단 포함)를 한 번 실제 호출해 확인하면서 조정한다. 아래는 v1 지원 집합이며, 표에 없는 요소는 아래 "v1 미지원" 처리를 적용한다.

| 원천 요소 | Markdown 복원 |
|---|---|
| `<h1>`~`<h6>` | `#`~`######` |
| `<p>`, `<strong>`, `<em>`, `<code>`, `<a href>` | 표준 GFM |
| `<ul>` / `<ol>` / `<li>` | `- ` / `1. ` (중첩은 2칸 들여쓰기) |
| `<blockquote>`, `<hr/>`, `<br/>` | 표준 GFM |
| `<pre><code class="language-X">...</code></pre>` | fenced code block. `language` / `title` / `linenumbers` 같은 추가 파라미터가 있으면 fence 바로 뒤에 HTML 주석(`<!-- title=... -->`)으로 보존 |
| panel (info/note/warning/tip — `class` 또는 `data-macro-name`으로 식별) | GFM alert (`> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, `> [!CAUTION]`) |
| `<details><summary>...</summary>...</details>` 또는 expand 매크로 잔재 | `<details><summary>title</summary>...</details>` (HTML 그대로 유지) |
| task-list (HTML 체크박스 또는 매크로 잔재) | `- [ ]` / `- [x]` |
| `<img src="...attachment...">` (참조 대상 첨부) | 다운로드 성공 시 `![alt](./<slug>.assets/att<id>-<name>)`, 실패·임계치 초과 시 `![alt](<원격 URL>)` |
| `<img src="http외부...">` | `![alt](<URL>)` — 다운로드하지 않음 |
| `<a href="...attachment...">` | 다운로드 성공 시 `[text](./<slug>.assets/att<id>-<name>)`, 실패 시 원격 URL 유지 |
| `<a href="...Confluence 내부 페이지...">` | Confluence URL 그대로 유지 (이 스킬은 단일 페이지 스코프) |
| 단순 `<table>` (colspan/rowspan 없음) | GFM 테이블 |
| **병합셀 있는 `<table>` (colspan 또는 rowspan 존재)** | **raw HTML 유지** + 손실 집계의 `merged_tables` 증가 |
| **다단 레이아웃 (`<div class="columnLayout-*">` 또는 해당 ac 잔재)** | **raw HTML 유지** + 손실 집계의 `multi_column_layouts` 증가 |
| 잔재 `<ac:structured-macro ac:name="X">` (v1 미지원) | `[Confluence macro: X]` placeholder + 손실 집계 `unsupported_macros[X]` 증가 |
| `<ac:emoticon ac:name="...">` 잔재 | 쇼트코드 `:<name>:` |

**v1 미지원(placeholder 처리)**: info/note/warning/tip 외의 panel 변형, `status`, `jira`, `children-display`, `user profile`, `excerpt`, `excerpt-include`, LaTeX/수식, 페이지 포함 매크로 등.

**병합셀 / 다단 레이아웃은 flatten하지 않는다.** GFM이 표현할 수 없는 구조를 억지로 펼치면 의미가 손상된다 — raw HTML 블록을 그대로 두고 집계에 기록한다.

---

## Step 3 — 첨부 다운로드 및 저장 (임계치 적용)

### 3-A. 파일명 슬러그화

페이지 제목에서 `<slug>`를 만든다 — 규칙은 다음과 같다.

1. NFC 정규화
2. 선행/후행 공백 제거
3. 경로 구분자(`/`, `\`), OS 예약 문자(`:`, `*`, `?`, `"`, `<`, `>`, `|`), 제어 문자 → `-`
4. 연속 공백 → `-` 하나
5. 선행 `.` 제거 (숨김 파일 방지)
6. 결과가 빈 문자열이거나 하이픈/점뿐이면 `page-<page_id>` 폴백
7. 최대 120자로 자름
8. 한글/영문/숫자/공백/하이픈/언더스코어/점은 보존

같은 디렉토리에 이미 `<slug>.md`가 있으면 Step 4에서 덮어쓰기/이름 변경 프롬프트를 띄운다. 사용자가 `rename`을 선택하면 **`<slug>--<page_id>.md`**를 우선 후보로 제안한다. 이것도 존재하면 `<slug>--<page_id>-2.md`로 숫자를 올린다. 사이드카 폴더명도 같은 suffix를 공유한다.

첨부 파일명은 원본 `filename`에서 경로 구분자와 제어 문자만 제거하고 나머지는 보존해 `<sanitized>`로 쓰고, 최종 저장 이름은 **`att<attachment_id>-<sanitized>`** 고정이다.

### 3-B. 사이드카 디렉토리 준비

```bash
mkdir -p "<cwd>/<slug>.assets"
```

(슬러그 충돌 폴백을 쓸 때는 `<slug>--<page_id>.assets`.)

### 3-C. 임계치 검사

Step 1에서 계산한 "본문 참조 첨부"의 합계를 기준으로 판정한다.

- **합계 크기 > 10MB 또는 개수 > 20개** → 로컬 미러링 중단.
  - 본문의 `<img src>` / `<a href>`는 모두 Confluence 원격 URL 그대로 유지.
  - 사이드카 디렉토리는 그대로 두어도 되지만 비어 있다면 `rmdir`해도 무방.
  - 손실 집계에 "첨부 임계치 초과로 로컬 미러링 생략 (합계 <X>MB, <N>개)" 기록.
  - frontmatter의 `attachment_manifest`는 리스트 대신 `{ skipped_reason: "threshold_exceeded" }`로 축약.
  - 곧바로 Step 4로 넘어간다.

### 3-D. 임계치 이내일 때 다운로드

- 본문에서 참조된 각 `attachment_id`에 대해 **`mcp__mcp-atlassian__confluence_download_attachment`를 개별 호출**한다. base64로 반환된다.
  - `mcp__mcp-atlassian__confluence_get_page_images` 같은 일괄 도구는 **사용하지 않는다** — 참조 여부와 무관하게 전체 첨부를 긁어오므로 스킬 정책과 충돌한다.
- 반환된 base64를 Bash로 디코드해 사이드카에 저장한다. 예:
  ```bash
  python3 -c 'import base64,sys; open(sys.argv[1],"wb").write(base64.b64decode(sys.stdin.read()))' \
    "<cwd>/<slug>.assets/att<id>-<sanitized>" <<'EOF'
  <base64 payload>
  EOF
  ```
  또는 `base64 -d` (GNU/BSD 차이 주의).
- 50MB 초과 단일 첨부는 MCP가 거절할 수 있다 → 그 항목만 건너뛰고 손실 집계의 `download_failures` 리스트에 `filename` 추가. 나머지 첨부는 계속 진행한다.
- 다운로드 성공한 첨부에 대해서만 본문의 `<img src>` / `<a href>`를 상대 경로(`./<slug>.assets/att<id>-<name>`)로 치환한다. 실패 항목은 원격 URL을 유지한다.

---

## Step 4 — Markdown 파일 저장

1. 선두에 **YAML frontmatter**를 붙인다(기본 포함). 스펙:

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

   규칙:
   - `page_id`는 **반드시 큰따옴표로 감싼 문자열**로 쓴다. YAML이 정수로 파싱하면 선행 0이 사라지거나 과학 표기법 이슈가 생길 수 있다.
   - `title`·`labels`에 콜론(`:`) / 큰따옴표(`"`) / 백슬래시(`\`)가 포함되면 double-quote로 감싸고 `\` / `"`를 이스케이프한다.
   - 임계치 초과 시 `attachment_manifest`는 `attachment_manifest: { skipped_reason: "threshold_exceeded" }`로 바꿔 쓴다.
   - `losses:`의 하위 필드는 해당 값이 0이거나 비어 있으면 생략해도 무방하지만, 최소한 하나라도 손실이 있으면 `losses:` 블록 자체는 포함한다.

2. frontmatter 뒤에 Step 2에서 조립한 Markdown 본문을 붙인다.

3. 손실이 하나라도 있으면 문서 끝에 **`## Confluence Conversion Notes`** 섹션을 붙인다. 예:

   ```markdown
   ## Confluence Conversion Notes

   - 변환되지 않은 매크로: jira x3, children-display x1, excerpt x1
   - 병합셀 테이블 x1 (raw HTML 유지)
   - 다단 레이아웃 x1 (raw HTML 유지)
   - 스페이스 내 페이지 링크 x5 (Confluence URL 유지)
   - 첨부 임계치 초과로 로컬 미러링 생략 (합계 13.2MB, 24개)
   - 다운로드 실패 첨부: huge.pdf (size_over_50mb)
   - 참고: 본문의 일부 이미지는 Mermaid/PlantUML/D2로 렌더된 다이어그램일 수 있으며, 원본 DSL은 Confluence에 보존되어 있지 않아 복원할 수 없습니다.
   ```

   손실이 전혀 없으면 이 섹션은 붙이지 않는다.

4. `Write`로 `<cwd>/<slug>.md`에 저장한다 (충돌 폴백 시 `<cwd>/<slug>--<page_id>.md`).

5. 같은 경로에 기존 파일이 있으면 저장 전에 확인한다:

   ```
   `<slug>.md`가 이미 존재합니다. 덮어쓸까요? (y / n / rename)
   ```

   - `y` → 덮어쓰기
   - `n` → 저장 취소, 사용자에게 상태를 보고하고 종료
   - `rename` → **`<slug>--<page_id>.md`**를 우선 제안. 그것도 이미 있으면 `<slug>--<page_id>-2.md`, `-3.md`… 순으로 증가. 사용자가 확정하면 사이드카 폴더명도 같은 suffix로 바꿔 저장한다.

---

## Step 5 — 결과 및 집계형 손실 보고

한 번의 마지막 메시지로 아래를 보고한다.

- 저장된 MD 파일의 **절대 경로**
- 사이드카 폴더 경로 + 실제 저장된 첨부 개수와 총 용량 (임계치 초과로 생략했다면 "로컬 미러링 생략" 명시)
- 원본 Confluence 페이지 URL (헤더 포함 여부와 무관하게 항상 표시)
- 손실 요약 (해당되는 항목만):
  - 변환되지 않은 매크로 종류별 카운트
  - 병합셀 테이블 수 (raw HTML로 유지됨)
  - 다단 레이아웃 수 (raw HTML로 유지됨)
  - 스페이스 내 페이지 링크 수 (Confluence URL로 유지됨)
  - 첨부 임계치 초과 여부 (합계/개수)
  - 다운로드 실패 첨부 파일명 리스트
  - mermaid/plantuml/d2 원본 DSL은 Confluence에 보존되지 않아 복원 불가 — 본문에 이런 이미지가 있을 수 있다는 일반 경고

frontmatter의 `losses:` 필드와 문서 끝 `## Confluence Conversion Notes` 섹션이 이 집계의 영구 기록 역할을 한다. 사용자 메시지는 그 요약본이다.

---

## 실패 / 엣지 케이스

- **권한 오류 (403)** / **존재하지 않는 page_id (404)**: 즉시 중단. 어떤 API 호출에서 어떤 상태로 실패했는지 명시하고, 파일/디렉토리는 생성하지 않는다.
- **빈 본문 페이지 (제목만 존재)**: frontmatter + 빈 본문 + `## Confluence Conversion Notes`에 "empty body" 한 줄을 남긴 MD 파일만 저장.
- **극단적으로 긴 페이지 (processed_html이 모델 컨텍스트를 초과할 정도)**: 부분 변환 결과물을 남기지 말고, 사용자에게 "페이지 크기가 한 번에 처리 가능한 한도를 초과합니다" 취지로 명확히 보고한 뒤 중단한다.
- **자연어 검색 결과 10개 초과**: 폴백 없이 "더 구체적인 제목으로 다시 알려주세요"로 재질의. 10개 이하일 때만 후보 표시로 진행.
- **동일 slug 재다운로드**: Step 4의 덮어쓰기 프롬프트 + `--<page_id>` 폴백으로 처리. 자동 덮어쓰기 금지.

어떤 단계에서 오류가 나든 **부분 산출물을 남기지 않는다**. 사이드카에 첨부만 저장되고 MD는 저장 안 된 상태로 끝나는 것을 피한다 — MD 저장 직전 단계까지 성공해야 파일을 쓴다.
