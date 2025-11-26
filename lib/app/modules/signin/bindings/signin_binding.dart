import 'package:get/get.dart';
import '../../../data/services/webauthn_service.dart';
import '../controllers/signin_controller.dart';

class SignInBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize WebAuthn service as singleton
    Get.put<WebAuthnService>(WebAuthnService(), permanent: true);
    
    // Initialize SignIn controller
    Get.lazyPut<SignInController>(
      () => SignInController(),
    );
  }
}
