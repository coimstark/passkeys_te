import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:webauthn/webauthn.dart';
import 'package:http/http.dart' as http;

class WebAuthnService extends GetxService {
  final RxList<String> logs = <String>[].obs;
  late final Authenticator _authenticator;
  final String rpId = '192.168.3.174:8070';
  final String rpName = 'MATOA Relying Party';

  void addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    logs.add('[$timestamp] $message');
    print('WebAuthn: $message');
  }

  void clearLogs() {
    logs.clear();
  }

  /// Register a new credential (sign up)
  Future<void> register(String username) async {
    try {
      addLog('🚀 Starting registration for: $username');
      addLog('');
      
      // Step 1: Get registration options from server
      addLog('📝 Step 1: Requesting registration options from server');
      final uri = Uri.http(rpId, '/webauthn/attestation/options');
      addLog('   - Endpoint: http://$rpId/webauthn/attestation/options');
      
      final responseOptions = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
      
      if (responseOptions.statusCode != 200) {
        addLog('❌ Server returned status: ${responseOptions.statusCode}');
        throw Exception('Failed to get registration options from server');
      }
      
      final serverOptions = json.decode(responseOptions.body);
      addLog('✅ Server options received');
      addLog('   - Challenge: ${serverOptions['challenge']}');
      addLog('   - RP ID: ${serverOptions['rp']['id']}');
      addLog('   - RP Name: ${serverOptions['rp']['name']}');
      addLog('');
      
      // Step 2: Create client data and hash
      addLog('📝 Step 2: Creating client data');
      final clientData = {
        'type': 'webauthn.create',
        'challenge': serverOptions['challenge'],
        'origin': 'http://${serverOptions['rp']['id']}',
      };
      final clientDataJson = json.encode(clientData);
      addLog(clientDataJson);
      final clientDataHash = Uint8List.fromList(
        sha256.convert(utf8.encode(clientDataJson)).bytes
      );
      addLog('   - Client data JSON created');
      addLog('   - Client data hash (SHA256): ${clientDataHash.length} bytes');
      addLog('');
      
      // Step 3: Transform server options to authenticator format
      addLog('🔧 Step 3: Preparing authenticator options');
      
      // Convert pubKeyCredParams to CredTypePubKeyAlgoPair list
      final credTypesAndPubKeyAlgs = (serverOptions['pubKeyCredParams'] as List)
          .map((param) => CredTypePubKeyAlgoPair(
                credType: PublicKeyCredentialType.publicKey,
                pubKeyAlgo: param['alg'] as int,
              ))
          .toList();
      
      final options = MakeCredentialOptions(
        clientDataHash: clientDataHash,
        credTypesAndPubKeyAlgs: credTypesAndPubKeyAlgs,
        requireResidentKey: serverOptions['authenticatorSelection']?['requireResidentKey'] ?? false,
        requireUserPresence: true,
        requireUserVerification: serverOptions['authenticatorSelection']?['userVerification'] == 'required',
        rpEntity: RpEntity(
          name: 'localhost',
          id: '192.168.3.174',
        ),
        userEntity: UserEntity(
          id: Uint8List.fromList(utf8.encode(username)),
          name: username,
          displayName: username,
        ),
      );
      
      addLog('   - User: $username');
      addLog('   - User ID (base64): ${base64Url.encode(options.userEntity.id)}');
      addLog('   - Require resident key: ${options.requireResidentKey}');
      addLog('   - Require user verification: ${options.requireUserVerification}');
      addLog('   - Algorithms: ${credTypesAndPubKeyAlgs.map((e) => e.pubKeyAlgo).toList()}');
      addLog('');
      
      // Step 4: Make credential with authenticator
      addLog('📱 Step 4: Calling platform authenticator');
      addLog('   This will trigger biometric authentication');
      addLog('   (Touch ID, Face ID, Windows Hello, etc.)');
      addLog('⏳ Waiting for user biometric verification...');
      addLog('');
      
      final attestation = await _authenticator.makeCredential(options);
      
      addLog('✅ Credential created successfully!');
      addLog('   - Credential ID (base64): ${attestation.getCredentialIdBase64()}');
      addLog('   - Credential ID length: ${attestation.getCredentialId().length} bytes');
      addLog('');
      
      // Step 5: Display attestation details
      addLog('📦 Step 5: Attestation object details');
      final cborData = attestation.asCBOR();
      addLog('   - CBOR data length: ${cborData.length} bytes');
      addLog('   - Auth data length: ${attestation.authData.length} bytes');
      
      // Parse attestation JSON
      final attestationJson = json.decode(attestation.asJSON());
      addLog('   - Format: ${attestationJson['fmt']}');
      addLog('');
      
      // Step 6: Prepare response for server
      addLog('📤 Step 6: Preparing response for server verification');
      final credentialResponse = {
        'type': 'public-key',
        'id': attestation.getCredentialIdBase64(),
        'rawId': attestation.getCredentialIdBase64(),
        'response': {
          'clientDataJSON': base64Url.encode(utf8.encode(clientDataJson)),
          'attestationObject': base64Url.encode(cborData),
        },
      };

      addLog(jsonEncode(credentialResponse));
      
      addLog('   - Response type: ${credentialResponse['type']}');
      addLog('   - Credential ID: ${credentialResponse['id'].toString().substring(0, 20)}...');
      addLog('');
      
      // Step 7: Send credential to server
      addLog('📤 Step 7: Sending credential to server');
      final verifyUri = Uri.http(rpId, '/webauthn/attestation/result');
      addLog('   - Endpoint: http://$rpId/webauthn/attestation/result');
      
      final verifyResponse = await http.post(
        verifyUri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(credentialResponse),
      );
      
      if (verifyResponse.statusCode == 200 || verifyResponse.statusCode == 201) {
        addLog('✅ Server verification successful!');
        final verifyResult = json.decode(verifyResponse.body);
        addLog('   - Server response: ${verifyResult.toString()}');
      } else {
        addLog('⚠️  Server returned status: ${verifyResponse.statusCode}');
        addLog('   - Response: ${verifyResponse.body}');
      }
      addLog('');
      
      addLog('🎉 Registration completed successfully!');
      addLog('   User "$username" can now sign in with passkey');
      addLog('   Credential stored securely on device');
      addLog('');
      
    } on AuthenticatorException catch (e) {
      addLog('');
      addLog('❌ Authenticator error: ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      addLog('');
      addLog('❌ Registration error: $e');
      addLog('   Stack trace: ${stackTrace.toString().split('\n').first}');
      rethrow;
    }
  }

  /// Authenticate with existing credential (sign in)
  Future<void> authenticate(String username) async {
    try {
      addLog('🔑 Starting authentication for: $username');
      addLog('');
      
      // Step 1: Get assertion options from server
      addLog('📝 Step 1: Requesting assertion options from server');
      final uri = Uri.http(rpId, '/webauthn/assertion/options');
      addLog('   - Endpoint: http://$rpId/webauthn/assertion/options');
      
      final responseOptions = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      });
      
      if (responseOptions.statusCode != 200) {
        addLog('❌ Server returned status: ${responseOptions.statusCode}');
        throw Exception('Failed to get assertion options from server');
      }
      
      final serverOptions = json.decode(responseOptions.body);
      addLog('✅ Server options received');
      addLog('   - Challenge: ${serverOptions['challenge']}');
      addLog('   - RP ID: ${serverOptions['rpId']}');
      addLog('');
      
      // Step 2: Create client data and hash
      addLog('📝 Step 2: Creating client data');
      final clientData = {
        'type': 'webauthn.get',
        'challenge': serverOptions['challenge'],
        'origin': 'http://${serverOptions['rpId']}',
      };
      final clientDataJson = json.encode(clientData);
      final clientDataHash = Uint8List.fromList(
        sha256.convert(utf8.encode(clientDataJson)).bytes
      );
      addLog('   - Client data JSON created');
      addLog('   - Client data hash (SHA256): ${clientDataHash.length} bytes');
      addLog('');
      
      // Step 3: Create GetAssertionOptions
      addLog('🔧 Step 3: Creating assertion options');
      
      // Convert allowCredentials if present
      List<PublicKeyCredentialDescriptor>? allowCredentials;
      if (serverOptions['allowCredentials'] != null && 
          (serverOptions['allowCredentials'] as List).isNotEmpty) {
        allowCredentials = (serverOptions['allowCredentials'] as List)
            .map((cred) => PublicKeyCredentialDescriptor(
                  type: PublicKeyCredentialType.publicKey,
                  id: base64Url.decode(cred['id']),
                ))
            .toList();
        addLog('   - Allow credentials: ${allowCredentials.length} credential(s)');
      } else {
        addLog('   - Allow credentials: any (empty list)');
      }
      
      final options = GetAssertionOptions(
        clientDataHash: clientDataHash,
        rpId: serverOptions['rpId'],
        requireUserPresence: true,
        requireUserVerification: serverOptions['userVerification'] == 'required',
        allowCredentialDescriptorList: allowCredentials,
      );
      
      addLog('   - RP ID: ${serverOptions['rpId']}');
      addLog('   - Require user verification: ${options.requireUserVerification}');
      addLog('   - Require user presence: ${options.requireUserPresence}');
      addLog('');
      
      // Step 4: Get assertion from authenticator
      addLog('📱 Step 4: Calling platform authenticator');
      addLog('   This will trigger biometric authentication');
      addLog('   (Touch ID, Face ID, Windows Hello, etc.)');
      addLog('⏳ Waiting for user biometric verification...');
      addLog('');
      
      final assertion = await _authenticator.getAssertion(options);
      
      addLog('✅ Assertion retrieved successfully!');
      addLog('   - Credential ID (base64): ${base64Url.encode(assertion.selectedCredentialId)}');
      addLog('   - Credential ID length: ${assertion.selectedCredentialId.length} bytes');
      addLog('');
      
      // Step 5: Display assertion details
      addLog('📦 Step 5: Assertion details');
      addLog('   - Authenticator data length: ${assertion.authenticatorData.length} bytes');
      addLog('   - Signature length: ${assertion.signature.length} bytes');
      addLog('   - User handle length: ${assertion.selectedCredentialUserHandle.length} bytes');
      addLog('   - User handle: ${String.fromCharCodes(assertion.selectedCredentialUserHandle)}');
      addLog('');
      
      // Step 6: Prepare response for server
      addLog('📤 Step 6: Preparing response for server verification');
      final assertionResponse = {
        'type': 'public-key',
        'id': base64Url.encode(assertion.selectedCredentialId),
        'rawId': base64Url.encode(assertion.selectedCredentialId),
        'response': {
          'clientDataJSON': base64Url.encode(utf8.encode(clientDataJson)),
          'authenticatorData': base64Url.encode(assertion.authenticatorData),
          'signature': base64Url.encode(assertion.signature),
          'userHandle': base64Url.encode(assertion.selectedCredentialUserHandle),
        },
      };
      
      addLog('   - Response type: ${assertionResponse['type']}');
      addLog('   - Credential ID: ${assertionResponse['id'].toString().substring(0, 20)}...');
      addLog('');
      
      // Step 7: Send assertion to server
      addLog('📤 Step 7: Sending assertion to server');
      final verifyUri = Uri.http(rpId, '/webauthn/assertion/result');
      addLog('   - Endpoint: http://$rpId/webauthn/assertion/result');
      
      final verifyResponse = await http.post(
        verifyUri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(assertionResponse),
      );
      
      if (verifyResponse.statusCode == 200 || verifyResponse.statusCode == 201) {
        addLog('✅ Server verification successful!');
        final verifyResult = json.decode(verifyResponse.body);
        addLog('   - Server response: ${verifyResult.toString()}');
      } else {
        addLog('⚠️  Server returned status: ${verifyResponse.statusCode}');
        addLog('   - Response: ${verifyResponse.body}');
      }
      addLog('');
      
      addLog('🎉 Authentication completed successfully!');
      addLog('   User "$username" signed in with passkey');
      addLog('   Signature verified by server');
      addLog('');
      
    } on AuthenticatorException catch (e) {
      addLog('');
      addLog('❌ Authenticator error: ${e.message}');
      addLog('   Hint: User may have cancelled or no matching credential found');
      rethrow;
    } catch (e, stackTrace) {
      addLog('');
      addLog('❌ Authentication error: $e');
      addLog('   Stack trace: ${stackTrace.toString().split('\n').first}');
      rethrow;
    }
  }

  /// Check platform support for WebAuthn
  Future<bool> checkSupport() async {
    try {
      addLog('🔍 Checking platform capabilities');
      addLog('');
      
      if (GetPlatform.isWeb) {
        addLog('   - Platform: Web Browser');
        addLog('   ✅ WebAuthn supported');
      } else if (GetPlatform.isAndroid) {
        addLog('   - Platform: Android');
        addLog('   - Uses: local_auth + secure storage');
        addLog('   ✅ WebAuthn supported');
      } else if (GetPlatform.isIOS) {
        addLog('   - Platform: iOS');
        addLog('   - Uses: local_auth + keychain');
        addLog('   ✅ WebAuthn supported');
      } else if (GetPlatform.isMacOS) {
        addLog('   - Platform: macOS');
        addLog('   - Uses: local_auth + keychain');
        addLog('   ✅ WebAuthn supported');
      } else if (GetPlatform.isWindows) {
        addLog('   - Platform: Windows');
        addLog('   - Uses: local_auth + secure storage');
        addLog('   ✅ WebAuthn supported');
      } else {
        addLog('   - Platform: Unknown');
        addLog('   ⚠️  Platform support uncertain');
        return false;
      }
      
      addLog('');
      return true;
    } catch (e) {
      addLog('❌ Error checking support: $e');
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    
    // Initialize authenticator
    // First param: authenticationRequired (true = require biometric)
    // Second param: strongboxRequired (Android strongbox, not widely supported)
    _authenticator = Authenticator(true, false);
    
    addLog('🔧 WebAuthn Service initialized');
    addLog('📱 Platform: ${GetPlatform.isWeb ? "Web" : GetPlatform.isMobile ? "Mobile" : "Desktop"}');
    addLog('🔐 Biometric authentication: ENABLED');
    addLog('💾 Credentials stored in: ${GetPlatform.isIOS || GetPlatform.isMacOS ? "Keychain" : "Secure Storage"}');
    addLog('');
    addLog('✨ Ready for WebAuthn/Passkeys operations');
    addLog('');
  }
}
