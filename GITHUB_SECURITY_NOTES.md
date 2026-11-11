# TrashGo – GitHub upload notes

This archive excludes generated/cache folders such as `.dart_tool`, `build`, `node_modules`, and `.git`.

## Security before publishing
- Brevo SMTP credentials and the Brevo API key found in the supplied source have been removed/replaced.
- Treat the original exposed keys as compromised. The owner of the Brevo account must revoke them and create replacements.
- Do not put a Brevo API key or SMTP password in Flutter/Dart client code. Move email sending to a trusted backend (for example, a secured Firebase Cloud Function) and store credentials in server-side environment secrets.
- Email OTP sending will not work until that backend is configured.
- Review Firebase rules and ensure no private service-account JSON files or other credentials are committed. Firebase client configuration files are not substitutes for security rules.

Inspect the project and test it locally before publishing.
