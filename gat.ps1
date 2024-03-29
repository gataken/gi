Add-Type -AssemblyName System.Web

# ver
Write-Host "スクリプト Ver.4.5 JP(2024/03/13)" -ForegroundColor Green

$logLocation = "%userprofile%\AppData\LocalLow\miHoYo\Genshin Impact\output_log.txt";
$logLocationChina = "%userprofile%\AppData\LocalLow\miHoYo\$([char]0x539f)$([char]0x795e)\output_log.txt";

# 翻訳
$log = "祈願履歴が存在しません。最初にゲーム内でガチャの履歴を開いておいてください。"
$url = "祈願履歴が開かれていません。Enterキーを押すと終了します。"
$admin = "管理者権限でこのツールを実行していない可能性があります。Enterキーで続行、その他のボタンで終了します。"
$clipboard = "クリップボードにURLをコピーしました、paimon.moe に貼り付けてインポートしてください。"
$end = "Enterキーで終了します。"

$reg = $args[0]
$apiHost = "hk4e-api-os.hoyoverse.com" 
if ($reg -eq "china") {
  Write-Host "Using China cache location"
  $logLocation = $logLocationChina
  $apiHost = "hk4e-api.mihoyo.com"
}

$tmps = $env:TEMP + '\pm.ps1';
if ([System.IO.File]::Exists($tmps)) {
  ri $tmps
}

$path = [System.Environment]::ExpandEnvironmentVariables($logLocation);
if (-Not [System.IO.File]::Exists($path)) {
    Write-Host "Cannot find the log file! Make sure to open the wish history first!" -ForegroundColor Red

    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {  
        Write-Host "Do you want to try to run the script as Administrator? Press [ENTER] to continue, or any key to cancel."
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
    Write-Host "Cannot find the wish history url! Make sure to open the wish history first!" -ForegroundColor Red
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
  $uri.Path = "event/gacha_info/api/getGachaLog"
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
  Write-Host "`rリンクをチェック中... $i" -NoNewline -ForegroundColor Red
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
  Write-Host $log -ForegroundColor Red
  Read-Host $end
  return
}

$wishHistoryUrl = $link

Write-Host $wishHistoryUrl -ForegroundColor Cyan
Set-Clipboard -Value $wishHistoryUrl
Write-Host ""
Write-Host "チェック完了。クリップボードにURLをコピーしました。paimon.moe に貼り付けてインポートしてください。" -ForegroundColor Green
Read-Host "Enterキーを押すと paimon.moe に移動します。"
Start-Process "https://paimon.moe/wish/import"
