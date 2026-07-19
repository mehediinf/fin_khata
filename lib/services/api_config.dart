/// Base URL for the FinKhata cloud sync backend. Override at build time with
/// `--dart-define=API_BASE_URL=https://your-host` for a different deployment
/// (e.g. a staging server); defaults to the production Railway deployment.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://finkhata-api-production.up.railway.app',
);
