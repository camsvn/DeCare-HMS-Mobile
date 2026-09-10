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
              // Zero padding so the link rows run edge to edge like every other
              // row in a card; the prose keeps the usual card inset.
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        DsSpace.cardPadding, DsSpace.cardPadding, DsSpace.cardPadding, DsSpace.x2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.aboutContact, style: type.heading),
                        const SizedBox(height: DsSpace.x2),
                        Text(l10n.aboutParaFinale, style: type.body),
                      ],
                    ),
                  ),
                  Semantics(
                    label: l10n.aboutCallSemantics(l10n.aboutPhone),
                    excludeSemantics: true,
                    button: true,
                    child: DsListRow(
                      leadingIcon: Icons.phone_outlined,
                      title: l10n.aboutPhone,
                      trailing: _OpenIndicator(),
                      onTap: () => _open(_phone),
                    ),
                  ),
                  Semantics(
                    label: l10n.aboutOpenWebsite,
                    excludeSemantics: true,
                    button: true,
                    child: DsListRow(
                      leadingIcon: Icons.language_outlined,
                      title: l10n.aboutWebsite,
                      trailing: _OpenIndicator(),
                      onTap: () => _open(_site),
                    ),
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

/// Marks a row as leaving the app; the row itself carries the tap.
class _OpenIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Icon(Icons.open_in_new, size: 18, color: context.ds.textSecondary);
}
