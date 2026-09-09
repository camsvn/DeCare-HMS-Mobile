import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.dsType;
    final ds = context.ds;
    final year = DateTime.now().year;
    return Scaffold(
      appBar: DsAppBar(title: l10n.aboutHeader),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpace.gutter),
        child: Column(
          children: [
            DsCard(
              child: Column(
                children: [
                  Center(
                    child: Image.asset('assets/images/decare_logo.jpeg',
                        height: 96),
                  ),
                  const SizedBox(height: DsSpace.x3),
                  Text(
                    l10n.aboutCopyright(year),
                    style: type.label.withColor(ds.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DsSpace.x3),
            DsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.aboutTerms, style: type.heading),
                  const SizedBox(height: DsSpace.x2),
                  Text(l10n.aboutLicense, style: type.body),
                ],
              ),
            ),
            const SizedBox(height: DsSpace.x3),
            DsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.aboutUs, style: type.heading),
                  const SizedBox(height: DsSpace.x2),
                  Text(l10n.aboutParaIntro, style: type.body),
                  const SizedBox(height: DsSpace.x3),
                  Text(l10n.aboutParaTwo, style: type.body),
                  const SizedBox(height: DsSpace.x3),
                  Text(l10n.aboutParaThree, style: type.body),
                ],
              ),
            ),
            const SizedBox(height: DsSpace.x3),
            DsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.aboutContact, style: type.heading),
                  const SizedBox(height: DsSpace.x2),
                  Text(l10n.aboutParaFinale, style: type.body),
                  const SizedBox(height: DsSpace.x3),
                  Row(
                    children: [
                      Expanded(
                        child: DsButton.ghost(
                          label: l10n.aboutPhone,
                          onPressed: () => _open(_phone),
                          expand: true,
                        ),
                      ),
                      const SizedBox(width: DsSpace.x2),
                      Expanded(
                        child: DsButton.ghost(
                          label: l10n.aboutWebsite,
                          onPressed: () => _open(_site),
                          expand: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
