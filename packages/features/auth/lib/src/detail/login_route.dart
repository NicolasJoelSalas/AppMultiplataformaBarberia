import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'login_view_model.dart';

class LoginRoute extends StatelessWidget {
  const LoginRoute({
    super.key,
    required this.viewModel,
    required this.getGoogleToken,
  });
  final LoginViewModel viewModel;
  final Future<String?> Function() getGoogleToken;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => LoginScreen(
      state: viewModel.state,
      onLogin: viewModel.onLogin,
      onRegister: viewModel.onRegister,
      onGoogleLogin: () => viewModel.onGoogleLogin(getGoogleToken),
      onToggleRegistration: viewModel.onToggleRegistration,
      onRetryProfile: viewModel.onRetryProfile,
    ),
  );
}
