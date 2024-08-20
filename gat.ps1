Add-Type -AssemblyName System.Web

Write-Host "GATスクリプト" -ForegroundColor Green

$logLocation = "%userprofile%\AppData\LocalLow\miHoYo\Genshin Impact\output_log.txt";
$logLocationChina = "%userprofile%\AppData\LocalLow\miHoYo\$([char]0x539f)$([char]0x795e)\output_log.txt";

$reg = $args[0]
$apiHost = "public-operation-hk4e-sg.hoyoverse.com" 
if ($reg -eq "china") {
  Write-Host "中国キャッシュロケーションの使用"
  $logLocation = $logLocationChina
  $apiHost = "public-operation-hk4e.mihoyo.com"
}

$tmps = $env:TEMP + '\pm.ps1';
if ([System.IO.File]::Exists($tmps)) {
  ri $tmps
}

$path = [System.Environment]::ExpandEnvironmentVariables($logLocation);
if (-Not [System.IO.File]::Exists($path)) {
    Write-Host "ログファイルが見つかりません！最初に祈願履歴を開いてください！" -ForegroundColor Red

    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
        Write-Host "スクリプトを管理者として実行しますか？続行するには[ENTER]を、キャンセルするにはどれかのキーを押してください。"
        $keyInput = [Console]::ReadKey($true).Key
        if ($keyInput -ne "13") {
            return
        }

        $myinvocation.mycommand.definition > $tmps

        Start-Process powershell -Verb runAs -ArgumentList "-noexit", $tmps, $reg
        break
    }

    return
}

$logs = Get-Content -Path $path
$m = $logs -match "(?m).:/.+(GenshinImpact_Data|YuanShen_Data)"
$m[0] -match "(.:/.+(GenshinImpact_Data|YuanShen_Data))" >$null

if ($matches.Length -eq 0) {
    Write-Host "祈願履歴のURLが見つかりません！最初に祈願履歴を開いてください！" -ForegroundColor Red
    return
}

$gamedir = $matches[1]
# Thanks to @jogerj for getting the latest webchache dir
$webcachePath = Resolve-Path "$gamedir/webCaches"
$cacheVerPath = Get-Item (Get-ChildItem -Path $webcachePath | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$cachefile = Resolve-Path "$cacheVerPath/Cache/Cache_Data/data_2"
$tmpfile = "$env:TEMP/ch_data_2"

Copy-Item $cachefile -Destination $tmpfile

function testUrl($url) {
  $ProgressPreference = 'SilentlyContinue'
  $uri = [System.UriBuilder]::New($url)
  $uri.Path = "gacha_info/api/getGachaLog"
  $uri.Host = $apiHost
  $uri.Fragment = ""
  $params = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
  $params.Set("lang", "en");
  $params.Set("gacha_type", 301);
  $params.Set("size", "5");
  $params.Add("lang", "en-us");
  $uri.Query = $params.ToString()
  $apiUrl = $uri.Uri.AbsoluteUri

  $response = Invoke-WebRequest -Uri $apiUrl -ContentType "application/json" -UseBasicParsing -TimeoutSec 10 | ConvertFrom-Json
  $testResult = $response.retcode -eq 0
  return $testResult
}

$content = Get-Content -Encoding UTF8 -Raw $tmpfile
$splitted = $content -split "1/0/"
$found = $splitted -match "webview_gacha"
$link = $false
$linkFound = $false
for ($i = $found.Length - 1; $i -ge 0; $i -= 1) {
  $t = $found[$i] -match "(https.+?game_biz=)"
  $link = $matches[0]
  Write-Host "`rChecking Link $i" -NoNewline
  $testResult = testUrl $link
  if ($testResult -eq $true) {
    $linkFound = $true
    break
  }
  Sleep 1
}

Remove-Item $tmpfile

Write-Host ""

if (-Not $linkFound) {
  Write-Host "祈願履歴のURLが見つかりません！最初に祈願履歴を開いてください！" -ForegroundColor Red
  return
}

$wishHistoryUrl = $link

Write-Host $wishHistoryUrl -ForegroundColor Cyan
Set-Clipboard -Value $wishHistoryUrl
Write-Host ""
Write-Host "チェック完了。クリップボードにURLをコピーしました。paimon.moe に貼り付けてインポートしてください。" -ForegroundColor Green
Read-Host "Enterキーを押すと paimon.moe に移動します。"
Start-Process "https://paimon.moe/wish/import"
