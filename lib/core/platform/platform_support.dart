import 'platform_support_stub.dart'
    if (dart.library.io) 'platform_support_io.dart'
    if (dart.library.html) 'platform_support_web.dart'
    as platform_support;

bool get supportsSqlCipher => platform_support.supportsSqlCipher;
