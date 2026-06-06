param(
  [Parameter(Mandatory = $true)]
  [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"

if ($ApiBaseUrl -notmatch "^https://") {
  throw "ApiBaseUrl must be a public HTTPS URL, for example https://moodwave-api.up.railway.app"
}

flutter clean
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl

Write-Host "Built Flutter web app for API: $ApiBaseUrl"
Write-Host "Output directory: build/web"
