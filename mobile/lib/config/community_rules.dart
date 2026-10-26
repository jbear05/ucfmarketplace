// DRAFT rules text — written as a placeholder while the teammate's original
// copy is tracked down. Replace before release.

class RuleSection {
  final String title;
  final String body;
  const RuleSection({required this.title, required this.body});
}

const String kCommunityRulesIntro =
    'KnightMarket is for UCF students buying and selling with each other. '
    'By creating an account you agree to keep it safe, honest, and respectful.';

const List<RuleSection> kCommunityRules = [
  RuleSection(
    title: 'Be a real Knight',
    body: 'Use your own UCF email and your real name. One account per person.',
  ),
  RuleSection(
    title: 'List honestly',
    body: 'Use real photos of the item you are selling, describe its condition accurately, '
        'and tag AI-generated artwork or prints as AI-generated.',
  ),
  RuleSection(
    title: 'Meet in public, on campus',
    body: 'Arrange exchanges at one of the public campus meetup spots during daytime hours. '
        'Never share your home address.',
  ),
  RuleSection(
    title: 'No prohibited items',
    body: 'No weapons, drugs, alcohol, vapes, stolen property, counterfeit goods, '
        'or anything that breaks UCF policy or the law.',
  ),
  RuleSection(
    title: 'Respect each other',
    body: 'No harassment, hate speech, spam, or scams. Keep conversations about the exchange.',
  ),
  RuleSection(
    title: 'Follow through',
    body: 'Show up to meetups you confirm, pay in person at the exchange, and rate each other honestly afterward.',
  ),
  RuleSection(
    title: 'Enforcement',
    body: 'Listings or accounts that break these rules can be removed or blocked by an admin. '
        'Use Contact Admin to report a problem.',
  ),
];
