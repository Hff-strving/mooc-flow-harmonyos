param(
  [Parameter(Mandatory=$false)][string]$RepoName = "mooc-flow-harmonyos",
  [Parameter(Mandatory=$false)][switch]$Private
)

if (-not $env:GITHUB_TOKEN) {
  Write-Error "Missing GITHUB_TOKEN. Create a GitHub Personal Access Token (classic) with 'repo' scope, then: setx GITHUB_TOKEN <token> (or $env:GITHUB_TOKEN='<token>' for current session)."
  exit 1
}

$headers = @{
  Authorization = "token $env:GITHUB_TOKEN"
  "User-Agent"  = "mooc-flow-uploader"
  Accept        = "application/vnd.github+json"
}

$body = @{ name = $RepoName; private = [bool]$Private }

try {
  $resp = Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/repos" -Headers $headers -Body ($body | ConvertTo-Json) -ContentType "application/json"
  Write-Host "Created repo: $($resp.full_name)"
} catch {
  Write-Warning "Repo create may have failed (it may already exist). Error: $($_.Exception.Message)"
}

git remote remove origin 2>$null | Out-Null
git remote add origin "git@github.com:Hff-strving/$RepoName.git"
git push -u origin main
