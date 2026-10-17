# WorkNexus

**Một nơi để đọc và xử lý mọi ticket.** WorkNexus là workspace desktop local-first,
dành cho developer phải theo dõi công việc ở nhiều
nguồn như **ZenTao, GitLab và GitHub**. App đồng bộ dữ liệu về SQLite cục bộ,
chuẩn hóa thành `Ticket`, rồi hiển thị theo đúng luồng làm việc của từng nguồn:
bug/task ZenTao, issue/MR GitLab, issue/PR GitHub.

<sub><a href="README.md">🇬🇧 English</a> · 🇻🇳 Tiếng Việt</sub>

> **Trạng thái:** đang phát triển giai đoạn đầu · desktop Windows/macOS · dự án nội bộ.
> Viết bằng Flutter/Dart theo Clean Architecture feature-first.

---

## Bảng phong thần

Vinh danh những người có code đã được merge vào `main`. 🏆

| | Contributor | Đóng góp nổi bật |
|:-:|---|---|
| <a href="https://github.com/thanhnguyen293"><img src="https://github.com/thanhnguyen293.png" width="64" alt="thanhnguyen293"/></a> | **[Thanh Nguyen](https://github.com/thanhnguyen293)** | 🥇 Người khởi tạo & maintainer — kiến trúc, providers, board, task detail |
| <a href="https://github.com/phungbuuquang"><img src="https://github.com/phungbuuquang.png" width="64" alt="phungbuuquang"/></a> | **[Michael (phungbuuquang)](https://github.com/phungbuuquang)** | 🥈 Menu tray desktop, hoàn thiện cửa sổ & profile (Windows/macOS) |
| <a href="https://github.com/dyno-nexsoft"><img src="https://github.com/dyno-nexsoft.png" width="64" alt="dyno-nexsoft"/></a> | **[Dyno (dyno-nexsoft)](https://github.com/dyno-nexsoft)** | 🥉 Updater trong app, dịch bằng API key, cấu hình build theo env, CI release & bộ cài đặt |

<a href="https://github.com/thanhnguyen293/WorkNexus/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=thanhnguyen293/WorkNexus" alt="Contributors"/>
</a>

---

## Vì sao có WorkNexus?

Công việc thường nằm rải rác ở nhiều hệ thống quản lý khác nhau. WorkNexus gom
việc đọc ticket, lọc, triage, bình luận, thao tác với provider, xem tệp đính kèm
và dịch máy vào một giao diện desktop duy nhất, để bạn không phải liên tục đổi
qua lại giữa nhiều tab trình duyệt.

- **Local-first.** drift/SQLite là nguồn dữ liệu chính. Sync ghi dữ liệu mạng
  vào CSDL; UI Flutter đọc stream reactive từ CSDL, nên ticket đã được cache vẫn
  xem được khi offline.
- **Thống nhất nhưng không đánh đồng.** Mọi nguồn đều được chuẩn hóa thành
  `Ticket`, nhưng từng bảng vẫn giữ vòng đời và action riêng của provider thay
  vì ép tất cả vào một bộ trạng thái chung.
- **An toàn mặc định.** Thông tin đăng nhập được lưu bằng
  `flutter_secure_storage` (macOS Keychain). Khi tải ảnh/tệp đính kèm cần xác
  thực, token chỉ được gắn với host của provider, không gửi sang host asset/CDN
  bên thứ ba.

---

## Trải nghiệm giao diện & Kiến trúc điều hướng

Hệ thống shell không gian làm việc tổ chức quy trình làm việc đa công cụ theo cấu trúc phân cấp 5 cấp độ rõ ràng:  
`Workspace (L1) → Tài khoản/Công cụ (L2) → Tính năng (L3) → Phạm vi (L4) → Mục chi tiết (L5)`.

<div align="center">
  <img src="assets/screenshots/unified-workspace-shell-slideshow.vi.gif" alt="WorkNexus Unified Workspace Shell Slideshow" width="100%" />
  <p><em>Slide trình chiếu động: tự động chuyển đổi lần lượt qua 7 màn hình cốt lõi của không gian làm việc.</em></p>
</div>

### Giải phẫu kiến trúc giao diện & 5 phân vùng Desktop

WorkNexus phân chia cửa sổ desktop thành 5 phân vùng công thái học, giúp tối ưu hóa năng suất khi làm việc đồng thời với nhiều hệ thống quản lý công việc:

```text
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [MW] MyWorkspace ▾ / Overview                  🔍 Tìm kiếm ticket, bug, PR, MR... (Ctrl+K)      ⚙️  — □ ✕│ (Title Bar 56px)
├──────┬─────────────────────────────┬───────────────────────────────────────────────────────────────────┤
│ (76) │ (Cột Tool Nav Pane 300px)   │ (Vùng Canvas chính - Chuyển tab 0ms nhờ bộ nhớ đệm LRU)           │
│ Rail │                             │                                                                   │
│ [W]  │ Chat   |  Tasks  |  Bugs    │ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐       │
│      │                             │ │ ZenTao (46 bugs)│ │ GitHub (12 PRs) │ │ GitLab (5 MRs)  │       │
│ [Z]  │ ▾ Dự án (Phạm vi):          │ └─────────────────┘ └─────────────────┘ └─────────────────┘       │
│ [GH] │   ⭐ Nền tảng cốt lõi        │ ───────────────────────────────────────────────────────────────── │
│ [GL] │   • Ứng dụng Mobile         │ 📋 Danh sách việc được giao trên tất cả công cụ:                  │
│ [Fg] │   • Cổng thanh toán         │   • [BUG-2041] Hết hạn phiên đăng nhập (ZenTao · Đã xác nhận)     │
│  +   │                             │   • [!312] Thêm luồng xác thực sinh trắc (GitLab MR · Cần review) │
│      │ ⚙️ Trạng thái sync: OK       │   • [#128] Nâng cấp lên Riverpod 3 (GitHub PR · Yêu cầu chỉnh sửa)│
└──────┴─────────────────────────────┴───────────────────────────────────────────────────────────────────┘
                                     │ ◄── [Slide-over Detail 460px: Xem chi tiết (Bản gốc / Dịch / Trao đổi)]
```

| Phân vùng | Kích thước | Mục đích & Trải nghiệm người dùng |
|---|---|---|
| **Thanh tiêu đề (Title Bar - L1)** | Cao `56px` | Chứa menu chuyển đổi **Workspace**, ô **Tìm kiếm theo ngữ cảnh** (`Ctrl/Cmd+K`), cài đặt nhanh và cụm nút điều khiển cửa sổ. |
| **Thanh Rail tài khoản (L2)** | Rộng cố định `76px` | Hiển thị biểu tượng nhận diện từng tài khoản kết nối (ZenTao, GitHub, GitLab), số tin nhắn chưa đọc và phím tắt `Ctrl/Cmd+1…9`; bên dưới là các **mini app** (website ghim vào rail, ví dụ `[Fg]` Figma) và nút `+` để thêm. |
| **Cột Pane công cụ (L3 & L4)** | Rộng cố định `300px` | Gom các tab tính năng (*Chat*, *Tasks*, *Bugs*, *MRs*, *PRs*), trạng thái kết nối sync và danh sách phạm vi (*Dự án*, *Product*, *Repository*). |
| **Vùng Viewport chính (L5)** | Độ rộng linh hoạt | Hiển thị bảng danh sách, kanban 6 cột hoặc luồng chat. Duy trì 3 view gần nhất trong bộ nhớ ẩn để chuyển đổi tức thì không cần tải lại mạng. |
| **Panel trượt chi tiết (Detail)** | Rộng trượt `460px` | Mở êm ái từ mép phải khi click vào bất kỳ ticket nào; hỗ trợ các tab xem mô tả gốc, dịch máy OpenCode và lịch sử bình luận. |

<details>
<summary><b>Nhấn để xem chi tiết từng slide thuyết trình (7 slide)</b></summary>
<br/>

#### 1. Workspace › Overview (Cấp L1)
> **Số liệu đa công cụ & hàng đợi Việc được giao thống nhất**  
> Hiển thị các thẻ tổng quan trực quan cho từng tài khoản kết nối (nhiệm vụ, bug, PR, MR mở) cùng danh sách "Assigned to you" tổng hợp các đầu việc cần xử lý từ ZenTao, GitLab và GitHub.
<p align="center"><img src="assets/screenshots/slides/01-workspace-overview.png" alt="Workspace Overview" width="96%"/></p>

#### 2. ZenTao › Chat (Cấp L3)
> **Kênh chat nội bộ thời gian thực tích hợp trực tiếp trong ZenTao**  
> Trò chuyện tức thì ngay trong ngữ cảnh công cụ ZenTao, hỗ trợ danh sách hội thoại, xem ảnh đính kèm và trạng thái thành viên mà không cần mở ứng dụng rời.
<p align="center"><img src="assets/screenshots/slides/04-zentao-chat.png" alt="ZenTao Chat" width="96%"/></p>

#### 3. ZenTao › Tasks (Cấp L3)
> **Quản lý task dự án với chuyển đổi Sprint & bộ lọc theo thời gian thực**  
> Theo dõi toàn diện vòng đời task dưới dạng bảng danh sách hoặc kanban, chọn sprint execution linh hoạt và lọc nhanh (*Tất cả*, *Giao cho tôi*, *Đến hạn tuần này*, *Trạng thái*).
<p align="center"><img src="assets/screenshots/slides/02-zentao-tasks.png" alt="ZenTao Tasks" width="96%"/></p>

#### 4. ZenTao › Bugs (Cấp L3)
> **Bảng kanban 6 cột trạng thái workflow & slide-over chi tiết bug**  
> Quy trình chuẩn ZenTao (Chưa xác nhận → Đã xác nhận → Đã giải quyết → Đã đóng) với các nút thao tác nhanh và panel chi tiết 460px đa tab.
<p align="center"><img src="assets/screenshots/slides/03-zentao-bugs.png" alt="ZenTao Bugs" width="96%"/></p>

#### 5. GitHub › Pull Requests (Cấp L3)
> **Phạm vi repo, tab trạng thái (Open/Merged/Closed) & chế độ bảng**  
> Lọc PR giữa các repository theo trạng thái (*Open*, *Merged*, *Closed*, *Board*) với nhãn reviewer và danh sách người thực hiện.
<p align="center"><img src="assets/screenshots/slides/05-github-pull-requests.png" alt="GitHub Pull Requests" width="96%"/></p>

#### 6. GitLab › Merge Requests (Cấp L3)
> **Bảng review MR, nhóm phạm vi (Đã ghim/Gần đây) & chip lọc linh hoạt**  
> Bảng tra cứu MR nhanh kèm trạng thái pipeline, bản nháp, duyệt phê duyệt và phân loại project thuận tiện.
<p align="center"><img src="assets/screenshots/slides/06-gitlab-merge-requests.png" alt="GitLab Merge Requests" width="96%"/></p>

#### 7. Workspace › Integrations (Cấp L1)
> **Quản lý kết nối nhiều tài khoản, thẻ sức khỏe & trạng thái sync**  
> Kết nối và quản trị nhiều tài khoản trên từng provider, theo dõi trạng thái đồng bộ tức thì và bảo mật token xác thực trong Keychain.
<p align="center"><img src="assets/screenshots/slides/07-workspace-integrations.png" alt="Workspace Integrations" width="96%"/></p>

</details>

Chưa có trong slide:

- **Mini app** — website bất kỳ ghim vào rail và hiển thị ngay trong app; link
  từ chat, ticket và các trang khác được chuyển tới đúng mini app (xem
  [Mini app](#mini-app)).
- **Tên và biểu tượng riêng** — tiêu đề cửa sổ, taskbar/Alt-Tab và khay hệ
  thống dùng tên và (trên Windows) ảnh bạn chọn trong Cài đặt nhanh › Giao diện.

---

## Tính năng

### Unified workspace shell (Shell không gian làm việc thống nhất)

- **Điều hướng 5 cấp:** Title bar → Rail tài khoản → Nav pane của công cụ → Viewport section → Detail slide-over.
- **Rail theo từng tài khoản** với màu nhận diện của provider; phím tắt `Ctrl/Cmd+1…9` để chuyển đổi nhanh.
- **Các section cấp workspace:** Overview (lưới thẻ + công việc được giao), Integrations (trạng thái sync + Quản lý), Members (sắp ra mắt), Settings.
- **Thẻ tổng quan (Overview cards)** hiển thị số liệu theo từng tài khoản (đang mở, được giao, lần sync cuối) kèm hiệu ứng skeleton loading.
- **Danh sách "Assigned to you"** tổng hợp công việc từ tất cả tài khoản trong workspace với chip lý do thông minh (reviewer, assignee).
- **Trình chuyển workspace** dạng popover với tìm kiếm, điều hướng bàn phím và thao tác "Tạo workspace".
- **Tìm kiếm theo ngữ cảnh** (`Ctrl/Cmd+K`): tìm kiếm ticket cục bộ có xếp hạng trọng số (tiêu đề/mã số/mô tả) cùng overlay kết quả điều hướng bàn phím.
- **Lưu trạng thái liên tục:** vị trí điều hướng của từng workspace (section, scope, view mode) được tự động lưu lại và phục hồi khi mở lại app hoặc chuyển workspace.
- **Bộ nhớ đệm section (Section caching):** viewport giữ 3 section gần nhất ở trạng thái ẩn (tạm dừng ticker/focus) để chuyển đổi tức thì.
- **Bảo vệ lỗi (Error boundary):** mỗi section được bọc bởi `SectionErrorBoundary` giúp bắt lỗi render và hiển thị nút thử lại thay vì làm sập ứng dụng.

### Bảng công việc và section riêng theo từng công cụ

- **ZenTao** — Chat, Tasks (List / Kanban / Calendar† / Gantt†), Bugs (Board / List), Docs†, Sprints†.
- **GitLab** — Merge Requests (Open / Merged / Closed / Board), Issues (List / Board), Pipelines†.
- **GitHub** — Pull Requests (Open / Merged / Closed / Board), Issues (List / Board), Actions†.
- † = các section dự kiến, render dưới dạng `ComingSoonView` kèm nút "Chuyển sang…".
- Phạm vi (Scope): project, product hoặc repository với thứ tự ưu tiên ghim đầu và lịch sử gần đây.
- Cột theo vòng đời thật của từng provider:
  - ZenTao bug: new/unconfirmed, confirmed/to-fix, resolved/verify,
    postponed, non-fix, closed.
  - ZenTao task: not started, in progress, paused, done/verify, closed,
    canceled.
  - GitLab/GitHub issue: open, in progress, closed.
  - GitLab/GitHub MR/PR: draft, review, merged, closed.
- Bộ lọc theo ngữ cảnh, với các nhóm lọc được suy ra từ dữ liệu: workspace,
  provider, account, người phụ trách, trạng thái, độ ưu tiên, label và tìm kiếm.
- Mỗi tab/project/repo dùng dữ liệu từ server nhưng có fallback offline: nếu
  không refresh được, app vẫn render ticket đã cache từ CSDL cục bộ.
- Cột phân trang dọn ticket cache mà server không còn liệt kê khi các trang
  tải về, nhưng giữ lại ticket của cột mà các trang đã tải chưa chạm tới
  (Postponed và Non-Fix dùng chung view `toclosed` của ZenTao với Resolved),
  nên thẻ của chúng không biến mất sau khi refresh.

### Kết nối nhiều provider

| Nguồn | Xác thực | Dữ liệu / phạm vi | Thao tác trong app |
|---|---|---|---|
| **ZenTao** | Tài khoản/mật khẩu trong Keychain; app lấy v1 session token | Bug theo product, task theo execution | Bình luận, note nội bộ, gán người, confirm/resolve/activate bug, ghim product/execution |
| **GitLab** | Personal Access Token | Issue, merge request, thành viên project, label, milestone, commit/changed file của MR | Bình luận, note nội bộ, gán người, đóng/mở lại, request reviewer, approve/rebase/merge MR, sửa label/milestone/time tracking |
| **GitHub** | Personal Access Token | Issue, pull request, assignee/reviewer của repo, commit/file của PR | Bình luận, note nội bộ, gán người, đóng/mở lại, request reviewer, update branch, merge PR |

GitLab hỗ trợ cả `gitlab.com` và instance self-hosted. GitHub hỗ trợ
`github.com` và GitHub Enterprise Server. Jira hiện mới là placeholder trong UI
và asset; chưa có adapter Jira.

### Mini app

- Ghim website bất kỳ vào rail thành **mini app** — Figma, Trello, giao diện web
  ZenTao, công cụ nội bộ — với icon của trang hoặc ảnh tự chọn, và tên tùy ý.
- Mỗi mini app là một web view nhúng (WebView2 trên Windows, WKWebView trên
  macOS) có back/forward, reload, stop, mở bằng trình duyệt và các phím tắt
  quen thuộc; cửa sổ pop-up của trang (cửa sổ đăng nhập) mở đè lên ngay trong
  app.
- Hỏi quyền theo từng trang — thông báo, camera, micro, vị trí, clipboard,
  autoplay, tải nhiều file, font cục bộ — được nhớ theo từng mini app và chỉnh
  lại được trong cài đặt. Thông báo của trang thành thông báo hệ điều hành, bấm
  vào sẽ quay lại đúng trang đó.
- **Link đi theo một thứ tự chung:** link bấm trong chat, trong ticket, hay do
  trang mở (`target=_blank`, `window.open`) được app nhận trước (ticket ZenTao
  mở trong panel chi tiết), sau đó tới mini app của trang đó (link Figma từ
  Trello đưa mini app Figma lên), cuối cùng mới tới trình duyệt hoặc pop-up của
  trang. Link tới chính trang của mini app vẫn ở trong cửa sổ của nó.
- **Đăng nhập ZenTao:** mini app trỏ tới server ZenTao đã kết nối sẽ tự đăng
  nhập bằng tài khoản đã lưu. Mật khẩu chỉ được đưa cho trang đăng nhập của
  chính server đó (cùng scheme, host và port) và chỉ điền vào form
  account/password; form chỉ được gửi một lần mỗi lần mở trang — sai mật khẩu
  thì không thử lại, và vẫn đăng xuất được.

### Chi tiết ticket và màn hình review

- Panel chi tiết dạng slide-over với các tab **Original**, ngôn ngữ dịch đang
  chọn, và **Comments & Activity**.
- Hai kiểu layout chi tiết: two-pane có sidebar metadata, hoặc document layout
  một cột để đọc nội dung dài.
- Comment từ provider và note nội bộ được hiển thị chung trong một timeline.
- Tải ảnh inline an toàn và preview attachment cho screenshot/video tái hiện lỗi.
- GitLab MR và GitHub PR có view riêng: overview, khung bình luận trong
  timeline, commit, changed files, trạng thái merge và trình sửa metadata.

### Dịch máy bằng OpenCode

- Dùng **OpenCode CLI** cục bộ qua `opencode run`; cần đăng nhập OpenCode bằng
  `opencode auth login`.
- Ngôn ngữ đích mặc định là tiếng Việt; có thể chọn thêm English, Japanese,
  Chinese (Simplified) và Korean.
- Bản dịch được cache theo ticket, ngôn ngữ đích, source hash và phiên bản
  prompt template.
- Trạng thái rõ ràng: `none`, `loading`, `done`, `outdated`, `error`.
- Prompt yêu cầu giữ nguyên code, định danh, đường dẫn file, URL và Markdown.

### Giao diện và workflow

- UI hỗ trợ đầy đủ tiếng Anh và tiếng Việt.
- Quick settings cho ngôn ngữ UI, ngôn ngữ dịch, theme, kiểu surface, mật độ
  hiển thị, layout chi tiết, định dạng ngày, font, màu accent và bo góc
  component.
- Theme: light, dark và midnight.
- Surface: flat hoặc outline; density: comfortable hoặc compact.
- Font mặc định: **Be Vietnam Pro** qua `google_fonts`.
- Font đi kèm: **Space Grotesk** và **Space Mono**; có thêm font hệ thống và
  **Geist Mono** để chọn.
- Độ rộng sidebar kéo chỉnh được và được lưu lại trong drift.
- **Tên và biểu tượng app:** đặt tên riêng cho app (tiêu đề cửa sổ, khi rê
  chuột trên taskbar, Alt-Tab, tooltip ở khay hệ thống) và, trên Windows, chọn
  ảnh bất kỳ — hoặc khung lớn nhất của file `.ico` nhiều kích thước — làm
  biểu tượng cửa sổ, taskbar và khay. Cả hai được giữ qua các lần mở app và có
  thể đặt lại mặc định. Biểu tượng và tên của chính file `.exe` (Explorer,
  Start menu, Task Manager, shortcut đã ghim) và tên trên thông báo hệ thống
  được cố định lúc build.

### Gửi ticket cho coding-agent (thử nghiệm)

Repo đã có phần thử nghiệm cho tab Development để gửi ticket sang **Claude
Code**, **Codex** hoặc **OpenCode**. Mặc định app chạy dry-run bằng mock session;
khi bật live CLI, app dùng binary cài trên máy và stream event đã chuẩn hóa vào
session store in-memory. Luồng này vẫn đang thử nghiệm và chưa nằm trong tab
strip mặc định của panel chi tiết.

---

## Công nghệ

| Mảng | Lựa chọn |
|---|---|
| Ngôn ngữ / UI | Flutter 3.44.8 · Dart 3.12.2 (qua **fvm**) |
| State management | **Riverpod 3** với state bất biến bằng **freezed** |
| Dependency injection | **get_it** + **injectable** trong một composition root |
| CSDL cục bộ | **drift** / SQLite với stream `.watch()` reactive |
| Kết nối mạng | **dio** + **retrofit** cho REST client có type rõ ràng |
| Xử lý lỗi | **fpdart** `Result` / `Failure`; không ném exception qua ranh giới layer |
| Secrets | **flutter_secure_storage** dùng macOS Keychain |
| Desktop shell | **window_manager** với custom title bar |
| UI / media | **gpt_markdown**, **flutter_svg**, **cached_network_image**, **video_player**, **image_picker**, **google_fonts** |
| Log / diagnostics | **talker_flutter**, **talker_dio_logger**, **logger** |
| Codegen | **build_runner**, **freezed**, **json_serializable**, **drift_dev**, **retrofit_generator**, **injectable_generator**, **flutter_gen** |

---

## Kiến trúc

WorkNexus đi theo **Clean Architecture feature-first**: mỗi feature là một lát
cắt dọc gồm `domain -> data -> presentation`, dependency chỉ hướng vào trong, và
domain là Dart thuần. Composition root duy nhất nằm ở `lib/app/di/`.
Bộ quy tắc đầy đủ nằm trong [`AGENTS.md`](AGENTS.md) / [`CLAUDE.md`](CLAUDE.md).

### Cấu trúc phân cấp của Shell

```
┌─────────────────────────────────────────────────────┐
│  Title Bar (breadcrumb · tìm kiếm · settings)       │
├────┬────────────┬───────────────────────┬────────────┤
│Rail│  Nav Pane   │       Viewport        │  Detail    │
│    │ (workspace  │  (nội dung section    │  slide-    │
│    │  hoặc tool) │   cùng các view mode) │  over      │
└────┴────────────┴───────────────────────┴────────────┘
```

**Rail** hiển thị một icon cho mỗi tài khoản được kết nối trong workspace đang chọn.
Nhấp vào tài khoản sẽ chuyển **nav pane** từ các mục workspace sang pane riêng của
module công cụ đó (danh sách scope, các tab section). Mỗi **tool module**
triển khai `ToolModule` và đăng ký trong `app/tool_registry.dart`.

```mermaid
flowchart LR
    subgraph Providers
        Z[ZenTao] & GL[GitLab] & GH[GitHub]
    end
    Providers -->|dio + credential của provider| SYNC[SyncService / Coordinator]
    SYNC -->|chuẩn hóa Ticket / comment / activity| DB[(drift · SQLite<br/>nguồn dữ liệu chính)]
    DB -->|watch streams| UI[Riverpod + Flutter UI]
    UI -->|provider actions| SYNC
    UI -->|opencode run| TR[Dịch bằng OpenCode]
```

```
lib/
├── app/                 # Composition root (di/), shell (rail, viewport, title bar),
│                        #   navigation và tool registry
├── core/                # Shared kernel: theme, widgets, error, database, cache, platform
├── shared/              # Shared slices: board, detail, shell_pane, sync
├── tools/               # Provider tool modules: zentao, gitlab, github (implement ToolModule)
├── features/            # Feature slices: chat, translation, app_update,
│                        #   connections, notifications, workspace_overview
├── gen/                 # Asset accessor sinh tự động
└── l10n/                # ARB tiếng Anh/Việt và l10n sinh tự động
```

---

## Bắt đầu

### Yêu cầu

- **[fvm](https://fvm.app/)** với Flutter **3.44.8** / Dart **3.12.2**.
- **macOS** kèm Xcode command-line tools (desktop target chính).
- Thông tin đăng nhập cho provider:
  - ZenTao: server URL, account và mật khẩu.
  - GitLab: Personal Access Token, thường cần scope `api`.
  - GitHub: Personal Access Token có quyền đọc/thao tác với repo/org cần dùng.
- Tùy chọn:
  - `opencode` đã đăng nhập bằng `opencode auth login` để dùng dịch máy.
  - `claude`, `codex` hoặc `opencode` trong `PATH` nếu muốn thử live agent
    dispatch.

### Cài đặt

```bash
# 1. Cài dependency
make get

# 2. Sinh output cho freezed/json/drift/retrofit/injectable/flutter_gen
make codegen

# 3. Chạy app trên macOS
make run
```

Sau đó mở **Settings -> Integrations** trong app, kết nối tài khoản provider và
chọn một nguồn ở sidebar.

### Lưu ý trên macOS

- Sandbox của app macOS được tắt có chủ đích để WorkNexus có thể chạy CLI cục bộ
  và truy cập các process OpenCode/agent chạy local.
- Thông tin đăng nhập được lưu trong login Keychain, không lưu trong CSDL cục bộ.
- Để Keychain ổn định qua các lần rebuild, tạo file local
  `macos/Runner/Configs/Signing.xcconfig` dựa trên
  `macos/Runner/Configs/Signing.xcconfig.example`. Nếu thiếu file này, build sẽ
  quay về ad-hoc signing.

---

## Lệnh Make

| Lệnh | Chức năng |
|---|---|
| `make doctor` | Xem diagnostics của Flutter |
| `make get` | Cài dependency Dart/Flutter |
| `make outdated` | Xem thông tin package có thể nâng cấp |
| `make codegen` | Chạy toàn bộ code generator một lần |
| `make watch` | Theo dõi và sinh lại generated source Dart |
| `make run` | Chạy app (`DEVICE=macos` mặc định) |
| `make format` | Format `lib` và `test` |
| `make analyze` | Chạy static analysis |
| `make test` | Chạy test (`TEST=đường/dẫn/hoặc/tên` để chạy một phần) |
| `make verify` | Chạy `format`, `analyze` và `test` |
| `make build-macos` | Build app macOS |
| `make build-macos-release` | Build bản release cho macOS |
| `make build-windows-release` | Build target release cho Windows |
| `make build-linux-release` | Build target release cho Linux |
| `make clean` | Dọn output build của Flutter |
| `make reset` | Clean, cài lại dependency và sinh lại code |

Chạy `make help` để xem danh sách target hiện tại.

---

## Kiểm thử

Test suite bao quát máy trạng thái điều hướng, bộ nhớ đệm section, error boundary,
tích hợp shell (khởi chạy → tổng quan → tài khoản → khôi phục trạng thái), logic board ở domain,
chuẩn hoá/adapter của provider, repository và migration drift, cache, theme extension,
quick settings, provider badge, dialog kết nối, detail view cho MR/PR, xếp hạng tìm kiếm và state bản dịch.

```bash
make test
make test TEST=test/core/app_nav_controller_test.dart
make test TEST=test/widget/shell_integration_test.dart
make test TEST=test/architecture/import_rules_test.dart
```

---

## Lộ trình

- [x] Provider ZenTao: bug theo product, task theo execution.
- [x] Provider GitLab: issue/MR, project board và My MRs.
- [x] Provider GitHub: issue/PR, repo board và My PRs.
- [x] Comment lên provider và note nội bộ chỉ lưu local.
- [x] Dịch máy bằng OpenCode với nhiều ngôn ngữ đích.
- [x] Detail view cho GitLab/GitHub MR/PR với commit, changed files và merge
  action.
- [x] **Unified workspace shell** với rail theo tài khoản, lưu vị trí điều hướng,
  cache section, tìm kiếm theo ngữ cảnh và error boundary.
- [x] Tổng quan workspace (Overview) với bảng tổng hợp công việc được giao và thẻ trạng thái sync.
- [ ] Đưa luồng Development/coding-agent ra UI chính và polish thêm.
- [ ] Lưu bền vững dev link và agent session thay vì chỉ giữ in-memory.
- [ ] Adapter Jira.
- [ ] Trạng thái kiểm tra CI của GitHub và cột approval/pipeline của GitLab.
- [ ] Các section Sprint, Docs, Calendar và Gantt cho ZenTao.
- [ ] Layout màn hình nhỏ (pass responsive <1024px).
- [ ] Kiểm chứng desktop target Windows/Linux.
- [ ] Tách sync client/server và client mobile.

---

## Giấy phép

Dự án nội bộ — © 2026 com.worknexus. Bảo lưu mọi quyền.
