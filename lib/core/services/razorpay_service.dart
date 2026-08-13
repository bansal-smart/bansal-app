import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/env.dart';

typedef PaymentSuccessCallback = void Function(PaymentSuccessResponse);
typedef PaymentFailureCallback = void Function(PaymentFailureResponse);
typedef PaymentExternalWalletCallback = void Function(ExternalWalletResponse);

class RazorpayService {
  static String get _keyId => Env.razorpayKeyId;

  final Razorpay _razorpay = Razorpay();

  void init({
    required PaymentSuccessCallback onSuccess,
    required PaymentFailureCallback onFailure,
    required PaymentExternalWalletCallback onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);
  }

  /// [amountInRupees] is the course price in ₹ (e.g. 499).
  /// Razorpay expects amount in paise (multiply by 100).
  void openCheckout({
    required double amountInRupees,
    required String courseId,
    required String courseName,
    String? userEmail,
    String? userName,
    String? userPhone,
  }) {
    final options = <String, dynamic>{
      'key': _keyId,
      'amount': (amountInRupees * 100).toInt(),
      'currency': 'INR',
      'name': 'Bansal',
      'description': courseName,
      'prefill': {
        'contact': userPhone ?? '',
        'email': userEmail ?? '',
        'name': userName ?? '',
      },
      'notes': {'course_id': courseId},
      'theme': {'color': '#F97315'},
    };
    _razorpay.open(options);
  }

  void dispose() => _razorpay.clear();
}
