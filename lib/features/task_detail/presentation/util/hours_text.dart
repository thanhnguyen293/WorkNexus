import 'package:intl/intl.dart';

/// Hours as ZenTao shows them: up to two decimals, no trailing zeros (`2.5`,
/// `6`).
String hoursText(double hours) => NumberFormat('0.##').format(hours);
