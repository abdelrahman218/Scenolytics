// Chrome detection conditional export — web uses real UA check; elsewhere false.
export 'is_flutter_web_chrome_stub.dart'
    if (dart.library.html) 'is_flutter_web_chrome_web.dart';
