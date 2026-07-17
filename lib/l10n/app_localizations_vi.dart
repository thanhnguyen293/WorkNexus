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
}
