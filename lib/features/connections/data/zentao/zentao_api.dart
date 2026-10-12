import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'zentao_models.dart';

part 'zentao_api.g.dart';

/// Type-safe client for the ZenTao REST v1 endpoints (base `{server}/api.php/v1`).
///
/// `Token` header injection and one-shot 401 re-auth are handled by
/// `ZenTaoAuthInterceptor` on the underlying [Dio]; the classic (non-REST)
/// channels — comment posting, `*-view-*.json` detail fallback, authenticated
/// image bytes — stay hand-written in `ZenTaoClient`.
@RestApi()
abstract class ZenTaoApi {
  factory ZenTaoApi(Dio dio, {String baseUrl}) = _ZenTaoApi;

  /// Obtain a session token. Skipped by the auth interceptor (no token yet).
  @POST('/tokens')
  Future<ZenTaoTokenResponse> login(@Body() Map<String, dynamic> credentials);

  /// "Assigned to me" for one kind (`fields` = bug|task|story), one page.
  @GET('/user')
  Future<ZenTaoAssignedResponse> assigned(
    @Query('type') String type,
    @Query('fields') String fields,
    @Query('page') int page,
    @Query('limit') int limit,
  );

  /// Users the current account may assign to.
  @GET('/users')
  Future<ZenTaoUsersResponse> users(@Query('limit') int limit);
}
