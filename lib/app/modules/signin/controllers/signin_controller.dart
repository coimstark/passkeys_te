import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/webauthn_service.dart';

class SignInController extends GetxController {
  final WebAuthnService _webAuthnService = Get.find<WebAuthnService>();
  
  final usernameController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;
  
  // Expose logs from service
  RxList<String> get logs => _webAuthnService.logs;
  
  @override
  void onInit() {
    super.onInit();
    _webAuthnService.clearLogs();
    _webAuthnService.checkSupport();
  }
  
  void clearMessages() {
    errorMessage.value = '';
    successMessage.value = '';
  }
  
  Future<void> register() async {
    final username = usernameController.text.trim();
    
    if (username.isEmpty) {
      errorMessage.value = 'Please enter a username';
      return;
    }
    
    clearMessages();
    isLoading.value = true;
    
    try {
      await _webAuthnService.register(username);
      successMessage.value = '✅ Registration successful! You can now sign in.';
      usernameController.clear();
    } catch (e) {
      errorMessage.value = 'Registration failed: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> signIn() async {
    final username = usernameController.text.trim();
    
    if (username.isEmpty) {
      errorMessage.value = 'Please enter a username';
      return;
    }
    
    clearMessages();
    isLoading.value = true;
    
    try {
      await _webAuthnService.authenticate(username);
      successMessage.value = '✅ Sign in successful! Welcome back.';
      usernameController.clear();
    } catch (e) {
      errorMessage.value = 'Sign in failed: ${e.toString()}';
    } finally {
      isLoading.value = false;
    }
  }
  
  void clearLogs() {
    _webAuthnService.clearLogs();
    _webAuthnService.checkSupport();
  }
  
  @override
  void onClose() {
    usernameController.dispose();
    super.onClose();
  }
}
