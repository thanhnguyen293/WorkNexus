// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppL10nVi extends AppL10n {
  AppL10nVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Bảng công việc hợp nhất';

  @override
  String get board => 'Bảng';

  @override
  String get list => 'Danh sách';

  @override
  String get integrations => 'Kết nối';

  @override
  String get views => 'Chế độ xem';

  @override
  String get workspace => 'Không gian';

  @override
  String get sources => 'Nguồn';

  @override
  String get activity => 'Hoạt động';

  @override
  String get allWorkspaces => 'Tất cả không gian';

  @override
  String get personal => 'Cá nhân';

  @override
  String get search => 'Tìm công việc, mã, dự án…';

  @override
  String get provider => 'Nguồn';

  @override
  String get account => 'Tài khoản';

  @override
  String get project => 'Dự án';

  @override
  String get status => 'Trạng thái';

  @override
  String get priority => 'Ưu tiên';

  @override
  String get assignee => 'Người phụ trách';

  @override
  String get severity => 'Mức độ';

  @override
  String get bugType => 'Loại';

  @override
  String get resolution => 'Cách xử lý';

  @override
  String get unassigned => 'Chưa gán';

  @override
  String get noBoardFilters => 'Bảng này chưa có bộ lọc';

  @override
  String get assignedToMe => 'Giao cho tôi';

  @override
  String get resolvedByMe => 'Tôi đã xử lý';

  @override
  String get bugTabAll => 'Tất cả';

  @override
  String get bugTabUnclosed => 'Chưa đóng';

  @override
  String get bugTabReportedByMe => 'Tôi báo';

  @override
  String get bugTabAssignedByMe => 'Tôi giao';

  @override
  String get bugTabLoadFailed => 'Không tải được bug';

  @override
  String get filters => 'Bộ lọc';

  @override
  String get hide => 'Ẩn';

  @override
  String get clear => 'Xóa';

  @override
  String get results => 'kết quả';

  @override
  String get result => 'kết quả';

  @override
  String get colInbox => 'Hộp đến';

  @override
  String get colTodo => 'Cần làm';

  @override
  String get colInprogress => 'Đang làm';

  @override
  String get colReview => 'Chờ duyệt';

  @override
  String get colBlocked => 'Bị chặn';

  @override
  String get colDone => 'Hoàn tất';

  @override
  String get viewAll => 'Tất cả';

  @override
  String get viewToday => 'Hôm nay';

  @override
  String get viewMine => 'Việc của tôi';

  @override
  String get viewReview => 'Đang duyệt';

  @override
  String get viewBlocked => 'Bị chặn';

  @override
  String get allSynced => 'Đã đồng bộ';

  @override
  String assignedToYou(int count) {
    return '$count công việc được giao cho bạn';
  }

  @override
  String get syncedAgo => 'Đồng bộ 2 phút trước';

  @override
  String get justNow => 'vừa xong';

  @override
  String minutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String get task => 'Công việc';

  @override
  String get summary => 'Nội dung';

  @override
  String get updated => 'Cập nhật';

  @override
  String get priorityUrgent => 'Khẩn';

  @override
  String get priorityHigh => 'Cao';

  @override
  String get priorityMedium => 'Vừa';

  @override
  String get priorityLow => 'Thấp';

  @override
  String get original => 'Bản gốc';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get description => 'Mô tả';

  @override
  String get comments => 'Bình luận';

  @override
  String get development => 'Phát triển';

  @override
  String get translate => 'Dịch bằng OpenCode';

  @override
  String get retranslate => 'Dịch lại bằng OpenCode';

  @override
  String get translating => 'Đang dịch bằng OpenCode…';

  @override
  String get notTranslated => 'Chưa dịch';

  @override
  String get translated => 'Đã dịch';

  @override
  String get translationOutdated => 'Bản dịch cũ';

  @override
  String get translationFailed => 'Dịch thất bại';

  @override
  String get connectedAccounts => 'Tài khoản đã kết nối';

  @override
  String get connect => 'Kết nối tài khoản';

  @override
  String get connected => 'Đã kết nối';

  @override
  String get chooseProvider => 'Chọn một nguồn';

  @override
  String get connectGitLab => 'Kết nối GitLab';

  @override
  String get gitlabConnectionSubtitle =>
      'Nhập địa chỉ máy chủ GitLab và Personal Access Token (scope: api). Token được lưu trong macOS Keychain — không lưu trong cơ sở dữ liệu cục bộ.';

  @override
  String get serverUrl => 'Địa chỉ máy chủ';

  @override
  String get gitlabServerHint => 'https://gitlab.com hoặc URL tự host';

  @override
  String get personalAccessToken => 'Personal Access Token';

  @override
  String get gitlabTokenHint => 'glpat-… (scope: api)';

  @override
  String get newWorkspaceOption => '➕ Workspace mới…';

  @override
  String get newWorkspaceName => 'Tên workspace mới';

  @override
  String get newWorkspaceHint => 'vd Công ty C';

  @override
  String get cancel => 'Hủy';

  @override
  String get connectAndSync => 'Kết nối & đồng bộ';

  @override
  String get gitlabIssues => 'Issues';

  @override
  String get gitlabMergeRequests => 'Merge Requests';

  @override
  String get gitlabColOpen => 'Mở';

  @override
  String get gitlabColDraft => 'Nháp';

  @override
  String get gitlabColMerged => 'Đã merge';

  @override
  String get gitlabColClosed => 'Đã đóng';

  @override
  String get gitlabItemsLoadFailed => 'Không tải được danh sách';

  @override
  String get assign => 'Giao';

  @override
  String get gitlabMerge => 'Merge';

  @override
  String get gitlabReopen => 'Mở lại';

  @override
  String get emptyTitle => 'Không có công việc khớp bộ lọc';

  @override
  String get emptyDesc => 'Thử bỏ bớt bộ lọc hoặc đổi không gian.';

  @override
  String get clearAllFilters => 'Xóa tất cả bộ lọc';

  @override
  String get quickSettings => 'Cài đặt nhanh';

  @override
  String get appearance => 'Giao diện';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get theme => 'Chủ đề';

  @override
  String get themeLight => 'Sáng';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeMidnight => 'Nửa đêm';

  @override
  String get surface => 'Bề mặt';

  @override
  String get surfaceFlat => 'Phẳng';

  @override
  String get surfaceOutline => 'Viền';

  @override
  String get density => 'Mật độ';

  @override
  String get densityComfortable => 'Thoải mái';

  @override
  String get densityCompact => 'Gọn';

  @override
  String get detailLayout => 'Bố cục chi tiết';

  @override
  String get layoutTwoPane => 'Hai cột';

  @override
  String get layoutDocument => 'Tài liệu';

  @override
  String get dateFormat => 'Định dạng ngày';

  @override
  String get dateFormatIso => 'ISO';

  @override
  String get dateFormatDmy => 'DD/MM';

  @override
  String get dateFormatLong => 'Dài';

  @override
  String get companyTint => 'Màu công ty';

  @override
  String get settingOff => 'Tắt';

  @override
  String get settingOn => 'Bật';

  @override
  String get font => 'Phông chữ';

  @override
  String get systemFont => 'Hệ thống';

  @override
  String get chooseUiFont => 'Chọn phông chữ giao diện';

  @override
  String get cornerRadius => 'Bo góc';

  @override
  String get primaryColor => 'Màu chủ đạo';

  @override
  String get colorDefault => 'Mặc định';

  @override
  String get projects => 'Dự án';

  @override
  String get pinProject => 'Ghim dự án';

  @override
  String get unpinProject => 'Bỏ ghim dự án';

  @override
  String get loadingProjects => 'Đang tải dự án…';

  @override
  String get projectsUnavailable => 'Không tải được dự án';

  @override
  String get projectOpenFailed => 'Không mở được dự án';

  @override
  String get executions => 'Bản thực thi';

  @override
  String get loadingExecutions => 'Đang tải bản thực thi…';

  @override
  String get executionsUnavailable => 'Không tải được bản thực thi';

  @override
  String get noExecutions => 'Không có bản thực thi';

  @override
  String get executionOpenFailed => 'Không mở được bản thực thi';

  @override
  String get close => 'Đóng';

  @override
  String get download => 'Tải xuống';

  @override
  String get attachments => 'Tệp đính kèm';

  @override
  String get savedToDownloads => 'Đã lưu vào thư mục Downloads';

  @override
  String get saveFailed => 'Không lưu được tệp';

  @override
  String get attachmentLoadFailed => 'Không tải được tệp đính kèm';

  @override
  String get previewUnavailable => 'Không xem trước được loại tệp này';

  @override
  String get confirmed => 'Đã xác nhận';

  @override
  String reopenedTimes(int count) {
    return 'Mở lại ×$count';
  }

  @override
  String get openedBy => 'Người mở';

  @override
  String get assignedTo => 'Được giao cho';

  @override
  String get lastEdited => 'Sửa lần cuối';

  @override
  String get classification => 'Phân loại';

  @override
  String get lifecycle => 'Vòng đời';

  @override
  String showEmptyFields(int count) {
    return 'Hiện $count trường trống';
  }

  @override
  String get hideEmptyFields => 'Ẩn trường trống';

  @override
  String get stepsToReproduce => 'Các bước tái hiện';

  @override
  String get actualResult => 'Kết quả thực tế';

  @override
  String get expectedResult => 'Kết quả mong đợi';

  @override
  String get fieldProduct => 'Sản phẩm';

  @override
  String get fieldExecution => 'Bản thực thi';

  @override
  String get fieldModule => 'Mô-đun';

  @override
  String get fieldBranch => 'Nhánh';

  @override
  String get fieldType => 'Loại lỗi';

  @override
  String get fieldSeverity => 'Mức độ';

  @override
  String get fieldPlan => 'Kế hoạch';

  @override
  String get fieldStory => 'Story';

  @override
  String get fieldOs => 'Hệ điều hành';

  @override
  String get fieldBrowser => 'Trình duyệt';

  @override
  String get fieldOpenedBuild => 'Bản phát hiện';

  @override
  String get fieldOpened => 'Ngày mở';

  @override
  String get fieldAssigned => 'Ngày giao';

  @override
  String get fieldDeadline => 'Hạn chót';

  @override
  String get fieldResolvedBy => 'Người xử lý';

  @override
  String get fieldResolved => 'Ngày xử lý';

  @override
  String get fieldResolvedBuild => 'Bản sửa';

  @override
  String get fieldClosedBy => 'Người đóng';

  @override
  String get fieldClosed => 'Ngày đóng';
}
