import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final _phone = Uri.parse('tel:+918086358930');
  static final _site = Uri.parse('https://www.decare.team');

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Nothing to do: the device has no handler for this link.
    }
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      showFlash(context, context.l10n.commonCannotGoBack, type: FlashType.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final year = DateTime.now().year;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: l10n.aboutHeader, leftIcon: Icons.arrow_back, onLeftTap: () => _back(context)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Image.asset('assets/images/decare_logo.jpeg', height: 120)),
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.aboutCopyright(year), style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.aboutTerms, style: AppTextStyles.header),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.aboutLicense, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.aboutUs, style: AppTextStyles.header),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.aboutParaIntro, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.aboutParaTwo, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.aboutParaThree, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.aboutContact, style: AppTextStyles.header),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.aboutParaFinale, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LinkButton(label: l10n.aboutPhone, color: AppColors.primary, onPressed: () => _open(_phone)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        child: Text(l10n.aboutOr, style: AppTextStyles.fieldLabel),
                      ),
                      LinkButton(label: l10n.aboutWebsite, color: AppColors.primary, onPressed: () => _open(_site)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
