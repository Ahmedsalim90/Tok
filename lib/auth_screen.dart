import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kNavy = Color(0xFF1B2432);
const kCoral = Color(0xFFE4633F);
const kBackground = Color(0xFFF7F5F2);
const kFieldLine = Color(0xFFC9C2B8);
const kSubtitleGray = Color(0xFF8A8478);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  String? errorMessage;

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> _submit() async {
    setState(() {
      errorMessage = null;
    });

    if (!isLogin && _passwordController.text != _confirmPasswordController.text) {
      setState(() {
        errorMessage = "Passwords don't match";
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'email': credential.user!.email,
          'uid': credential.user!.uid,
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = _friendlyError(e.code);
      });
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      errorMessage = null;
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: kBackground,
        centerTitle: true,
        title: Text(
          isLogin ? 'Login' : 'Sign Up',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                const _TokLogo(),
                const SizedBox(height: 8),
                Text(
                  isLogin ? 'Welcome back' : 'Create your account',
                  style: const TextStyle(fontSize: 13, color: kSubtitleGray),
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'Enter your email address',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  obscure: true,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: !isLogin
                      ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _buildField(
                      controller: _confirmPasswordController,
                      label: 'Confirm password',
                      hintText: 'Confirm your password',
                      obscure: true,
                    ),
                  )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 20),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                isLoading
                    ? const CircularProgressIndicator(color: kCoral)
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCoral,
                      foregroundColor: kBackground,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      isLogin ? 'LOGIN' : 'SIGN UP',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _toggleMode,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: kNavy, fontSize: 13),
                      children: [
                        TextSpan(
                          text: isLogin
                              ? "Don't have an account? "
                              : "Already have an account? ",
                        ),
                        TextSpan(
                          text: isLogin ? 'Sign Up' : 'Login',
                          style: const TextStyle(
                            color: kCoral,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: kCoral,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: kCoral, fontSize: 13),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: kFieldLine),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: kCoral, width: 1.5),
        ),
      ),
    );
  }
}

class _TokLogo extends StatelessWidget {
  const _TokLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: kCoral,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(22),
      child: CustomPaint(
        painter: _ChatBubblePainter(),
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 48;
    final scaleY = size.height / 48;

    final bubblePaint = Paint()..color = kBackground;
    final dotPaint = Paint()..color = kCoral;

    final path = Path();
    path.moveTo(6 * scaleX, 12 * scaleY);
    path.cubicTo(
      6 * scaleX, 8.7 * scaleY,
      8.7 * scaleX, 6 * scaleY,
      12 * scaleX, 6 * scaleY,
    );
    path.lineTo(36 * scaleX, 6 * scaleY);
    path.cubicTo(
      39.3 * scaleX, 6 * scaleY,
      42 * scaleX, 8.7 * scaleY,
      42 * scaleX, 12 * scaleY,
    );
    path.lineTo(42 * scaleX, 28 * scaleY);
    path.cubicTo(
      42 * scaleX, 31.3 * scaleY,
      39.3 * scaleX, 34 * scaleY,
      36 * scaleX, 34 * scaleY,
    );
    path.lineTo(16 * scaleX, 34 * scaleY);
    path.lineTo(8 * scaleX, 42 * scaleY);
    path.lineTo(8 * scaleX, 34 * scaleY);
    path.cubicTo(
      6.9 * scaleX, 34 * scaleY,
      6 * scaleX, 33.1 * scaleY,
      6 * scaleX, 32 * scaleY,
    );
    path.close();

    canvas.drawPath(path, bubblePaint);

    canvas.drawCircle(Offset(17 * scaleX, 20 * scaleY), 3 * scaleX, dotPaint);
    canvas.drawCircle(Offset(24 * scaleX, 20 * scaleY), 3 * scaleX, dotPaint);
    canvas.drawCircle(Offset(31 * scaleX, 20 * scaleY), 3 * scaleX, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ChatBubblePainter oldDelegate) => false;
}