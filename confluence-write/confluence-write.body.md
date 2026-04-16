사용자가 쓴 Markdown 초안을 Confluence Cloud에 **storage format**으로 업로드한다. 깨지기 쉬운 MD 요소는 Confluence 네이티브 매크로로 자동 치환하고, `mermaid` / `plantuml` / `d2` 코드블록은 [Kroki](https://kroki.io)로 렌더링해 첨부 + 이미지 임베드로 바꾼다.

**새 페이지 생성 전용** 스킬이다. 기존 페이지 업데이트는 이 스킬의 스코프가 아니다.

---

## Step 0 — 입력 수집

사용자가 인자 없이 호출했거나 일부만 제공했다고 가정한다. 아래 5가지를 **순서대로** 수집한다. 이미 대화 맥락에서 확실한 값이 있으면 재질문하지 않고 바로 다음으로 넘어간다.

1. **초안 소스**
   - 파일이면: "업로드할 Markdown 파일 경로를 알려주세요." → `Read` 도구로 읽는다.
   - 인라인이면: "여기에 Markdown을 붙여넣어 주세요." → 사용자 입력을 본문으로 쓴다.
2. **제목**
   - 초안 첫 비공백 라인이 `# ` 또는 `## ` 수준 H1이면 그것을 제목으로 쓰고 **본문에서 그 줄만 제거**한다.
   - H1이 없으면: "페이지 제목은 무엇으로 할까요?" → 사용자 답을 제목으로 쓴다.
3. **스페이스 키**
   - "어느 스페이스에 올릴까요? space key를 알려주세요 (예: `DEV`, `~accountId`)."
4. **상위 페이지 ID**
   - "상위 페이지 ID는? (없으면 스페이스 루트로 만듭니다. 숫자 ID만 허용.)"
5. **확인**
   - "제목: `…`, 스페이스: `…`, 상위: `…` — 이대로 진행할까요?"

---

## Step 1 — Markdown → Storage 변환

아래 치환을 **순서대로** 적용한다. 규칙 외의 MD(헤딩, 인라인 포맷, 일반 표, 단순 코드블록, 링크, 이미지 URL, blockquote, 구분선, 중첩 리스트)는 정상적인 XHTML로 변환한다.

### 1-A. 중첩 리스트 복구

MD 소스에서 2칸 들여쓰기로 중첩된 리스트는 Confluence로 보낼 때 `<ul><li>…<ul><li>…</li></ul></li></ul>` 구조로 **명시적으로 중첩** 시킨다. 2칸을 그대로 두면 flatten된다는 점을 Track A에서 확인했다. 순서 리스트(`1. …`)도 동일.

### 1-B. GFM Alert → 콜아웃 매크로

| 입력 | 출력 |
|------|------|
| `> [!NOTE]` 블록 | `<ac:structured-macro ac:name="info">` |
| `> [!TIP]` 블록 | `<ac:structured-macro ac:name="tip">` |
| `> [!IMPORTANT]` 블록 | `<ac:structured-macro ac:name="info">` (Confluence는 info/note/warning/tip만 있음) |
| `> [!WARNING]` 블록 | `<ac:structured-macro ac:name="warning">` |
| `> [!CAUTION]` 블록 | `<ac:structured-macro ac:name="warning">` |

형태:
```xml
<ac:structured-macro ac:name="warning">
  <ac:rich-text-body><p>본문</p></ac:rich-text-body>
</ac:structured-macro>
```

### 1-C. 체크박스 → 태스크 리스트

연속된 `- [ ]` / `- [x]` 라인들은 **하나의 `<ac:task-list>`** 안에 묶는다.

```xml
<ac:task-list>
  <ac:task>
    <ac:task-status>incomplete</ac:task-status>
    <ac:task-body>할 일</ac:task-body>
  </ac:task>
  <ac:task>
    <ac:task-status>complete</ac:task-status>
    <ac:task-body>완료한 일</ac:task-body>
  </ac:task>
</ac:task-list>
```

### 1-D. `<details>` → expand 매크로

```html
<details>
<summary>클릭하여 펼치기</summary>
안쪽 내용
</details>
```
↓
```xml
<ac:structured-macro ac:name="expand">
  <ac:parameter ac:name="title">클릭하여 펼치기</ac:parameter>
  <ac:rich-text-body><p>안쪽 내용</p></ac:rich-text-body>
</ac:structured-macro>
```

### 1-E. `<!-- toc -->` → TOC 매크로

문서 아무 위치에 `<!-- toc -->` 주석이 있으면 그 자리를 `<ac:structured-macro ac:name="toc"/>`로 치환. 주석이 없으면 TOC는 넣지 않는다(자동 삽입 금지).

### 1-F. 코드블록 언어 파라미터

```` ```java ```` 형태의 일반 코드블록은 네이티브 코드 매크로로 변환:

```xml
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">java</ac:parameter>
  <ac:plain-text-body><![CDATA[…코드…]]></ac:plain-text-body>
</ac:structured-macro>
```

언어가 없으면 `<ac:parameter ac:name="language">text</ac:parameter>`로 둔다. 단, 다이어그램 언어(`mermaid`/`plantuml`/`d2`/`graphviz`)는 다음 단계에서 따로 처리하므로 여기선 건드리지 않는다.

---

## Step 2 — 다이어그램 추출 및 렌더링

` ```mermaid ` / ` ```plantuml ` / ` ```d2 ` / ` ```graphviz ` 코드블록을 순회하며 각각 Kroki로 렌더한다.

### 2-A. 파일명과 포맷 결정

- `mermaid`, `plantuml`, `graphviz` → PNG
- `d2` → **SVG 전용** (PNG 요청 시 Kroki가 400 반환)

파일명: `diagram-<n>.<ext>` (n은 1부터 순번). 사용자가 ` ```mermaid title="login-flow" ` 같은 extension attribute를 쓰면 `<title>.<ext>`로 명명.

### 2-B. Kroki 호출 (Bash)

각 다이어그램 소스를 `/tmp/confluence-write/<session>/<name>.src`에 쓰고 curl로 POST:

```bash
curl -sS --data-binary @/tmp/confluence-write/<session>/<name>.src \
  -H "Content-Type: text/plain" \
  https://kroki.io/<type>/<fmt> \
  -o /tmp/confluence-write/<session>/<name>.<fmt>
```

응답이 비-이미지(에러 메시지)거나 HTTP 200이 아니면 **해당 코드블록을 렌더 실패로 처리**한다:
- 원본 코드블록은 `<ac:structured-macro ac:name="code" language="<type>">` 그대로 두고
- 바로 위에 경고 매크로를 삽입: `<ac:structured-macro ac:name="warning"><ac:rich-text-body><p>다이어그램 "<name>" 렌더 실패. 수동 검토 필요.</p></ac:rich-text-body></ac:structured-macro>`
- 나머지 다이어그램 처리는 계속한다.

### 2-C. 치환

성공한 다이어그램 코드블록은 다음으로 치환:

```xml
<ac:image ac:width="700">
  <ri:attachment ri:filename="<name>.<ext>"/>
</ac:image>
```

너비는 기본 `700`. 시퀀스/플로우는 700, ERD·아키텍처는 500~600이 대체로 적합하지만 여기서는 단순화.

---

## Step 3 — 페이지 생성 + 첨부 업로드

### 3-A. 페이지 생성

변환 완료된 storage XHTML로 `confluence_create_page` 호출:
- `space_key`: Step 0에서 수집
- `title`: Step 0에서 수집 또는 자동 추출
- `content_format`: `"storage"`
- `content`: 변환된 XHTML
- `parent_id`: Step 0에서 수집 (없으면 생략)
- `include_content`: `false`

응답에서 `page.id`를 보관한다.

### 3-B. 다이어그램 첨부

Step 2에서 생성된 각 이미지 파일에 대해 `confluence_upload_attachment` 호출:
- `content_id`: 방금 받은 `page.id`
- `file_path`: `/tmp/confluence-write/<session>/<name>.<fmt>`
- `comment`: `"Rendered via Kroki (<type>)"`
- `minor_edit`: `true`

업로드 실패 시 사용자에게 어떤 파일이 실패했는지만 알리고 진행한다. 페이지는 이미 생성되었으므로 유지.

### 3-C. 임시 파일 정리

`rm -rf /tmp/confluence-write/<session>/` 로 렌더 산출물을 삭제한다.

---

## Step 4 — 결과 보고

사용자에게 다음을 알려준다:
- 생성된 페이지 URL
- 업로드된 다이어그램 개수
- 렌더/업로드 실패한 항목이 있으면 그 목록과 파일명

---

## 변환하지 않는 요소 (참고)

Track A 실증상 다음은 Confluence 어느 포맷에서도 네이티브 지원이 없다. 사용자가 이런 요소를 썼을 때는 **있는 그대로 XHTML로 내보내거나(안전한 변환), 렌더가 깨진다는 점을 안내**한다:

- LaTeX 수식(`$…$`, `$$…$$`) — 리터럴로 남음
- Footnote (`[^1]`) — 리터럴로 남음
- Definition list — 리터럴로 남음
- `<kbd>`, `<mark>` 태그 — stripped
- 비표준 HTML 확장(`<sub>`, `<sup>`은 예외로 OK)

다이어그램 렌더가 불가능한 언어(예: `bpmn`, `excalidraw`)는 Track B 범위 밖이므로 Kroki 호출하지 않고 코드블록 그대로 둔다.

---

## 제약

- **새 페이지 생성 전용**. 기존 페이지 업데이트/덮어쓰기는 이 스킬의 스코프가 아니다.
- **다이어그램 백엔드는 Kroki 고정**. 네트워크 차단 환경에서는 다이어그램 코드블록이 전부 "렌더 실패"가 되고, 원본 코드블록이 페이지에 그대로 남는다.
- **@멘션 자동 변환 미지원**. Markdown의 `@홍길동`은 그대로 텍스트로 들어간다. 필요하면 후속 스킬로 분리.
- **TOC 자동 삽입 없음**. 문서에 `<!-- toc -->` 주석이 있을 때만 추가된다.
