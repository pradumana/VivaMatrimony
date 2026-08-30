import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingBioScreen extends ConsumerStatefulWidget {
  const OnboardingBioScreen({super.key});
  @override
  ConsumerState<OnboardingBioScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingBioScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final ok = await ref
        .read(onboardingProvider.notifier)
        .saveBio(_controller.text.trim());
    if (ok && mounted) context.push(AppRoutes.onboardingEducation);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 1,
      title: 'About You',
      subtitle: 'Write a few lines about yourself — your personality, values, and what you\'re looking for.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VivaTextField(
            label: 'About Me',
            hint: 'e.g. I am a warm, family-oriented person who values tradition and modern thinking equally...',
            controller: _controller,
            maxLines: 6,
            maxLength: 500,
          ),
          const SizedBox(height: 12),
          // Prompts
          const Text('Need inspiration? Try:', style: TextStyle(
            fontFamily: 'Poppins', fontSize: 12,
            color: Color(0xFF9E9E9E),
          )),
          const SizedBox(height: 8),
          for (final prompt in [
            'My family is the most important thing to me...',
            'I enjoy reading, cooking and spending time with loved ones...',
            'Looking for a life partner who shares my values...',
          ])
            GestureDetector(
              onTap: () => _controller.text = prompt,
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF8F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEDE0DB)),
                ),
                child: Text(
                  '"$prompt"',
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12,
                    color: Color(0xFF8B1A1A),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
