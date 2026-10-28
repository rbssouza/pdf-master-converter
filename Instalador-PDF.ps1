# ============================================================
#  INSTALADOR SEGURO - CONVERSOR PDF PRO (HARDENED)
# ============================================================

$Destino = Join-Path $env:LOCALAPPDATA 'EnterpriseTools'
$Ps1Gui  = Join-Path $Destino 'Conversor-GUI.ps1'
$Bat     = Join-Path $Destino 'converter.bat'
$LibDir  = Join-Path $Destino 'lib'
$DllPath = Join-Path $LibDir 'PdfSharp.dll'
$HashFile = Join-Path $LibDir 'PdfSharp.sha256'

Clear-Host
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host "  |      ***  CONVERSOR PDF PRO - INSTALADOR SEGURO  ***         |" -ForegroundColor Magenta
Write-Host "  ================================================================" -ForegroundColor Magenta

if (-not (Test-Path -LiteralPath $Destino)) { New-Item -ItemType Directory -Path $Destino -Force | Out-Null }
if (-not (Test-Path -LiteralPath $LibDir))  { New-Item -ItemType Directory -Path $LibDir  -Force | Out-Null }

function Get-SafePdfSharp {
    param([string]$DestinoDll, [string]$HashFile)

    if (Test-Path -LiteralPath $DestinoDll) {
        if (Test-Path -LiteralPath $HashFile) {
            $esperado = (Get-Content -LiteralPath $HashFile -Raw).Trim()
            $atual = (Get-FileHash -LiteralPath $DestinoDll -Algorithm SHA256).Hash
            if ($atual -eq $esperado) {
                Write-Host "  [ OK ] PdfSharp.dll verificado." -ForegroundColor Green
                return $true
            } else {
                Remove-Item -LiteralPath $DestinoDll -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $HashFile -Force -ErrorAction SilentlyContinue
            }
        } else {
            Remove-Item -LiteralPath $DestinoDll -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "  [INFO] Baixando PdfSharp.dll..." -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        [Net.ServicePointManager]::CheckCertificateRevocationList = $true

        $nupkg = Join-Path $env:TEMP ('pdfsharp_' + [Guid]::NewGuid().ToString('N') + '.nupkg')
        $tmp   = Join-Path $env:TEMP ('pdfsharp_ext_' + [Guid]::NewGuid().ToString('N'))

        $req = [System.Net.HttpWebRequest]::Create('https://www.nuget.org/api/v2/package/PdfSharp/1.50.5147')
        $req.AllowAutoRedirect = $false
        $resp = $req.GetResponse()
        if ($resp.StatusCode -eq 'Found' -or $resp.StatusCode -eq 'Redirect') {
            $novaUrl = $resp.Headers['Location']
            if (-not $novaUrl.StartsWith('https://')) { throw "Redirecionamento inseguro!" }
            $resp.Close()
            $req2 = [System.Net.HttpWebRequest]::Create($novaUrl)
            $resp = $req2.GetResponse()
        }
        $stream = $resp.GetResponseStream()
        $fs = [System.IO.File]::Create($nupkg)
        $stream.CopyTo($fs)
        $fs.Close(); $stream.Close(); $resp.Close()

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($nupkg, $tmp)
        $dll = Get-ChildItem -Path $tmp -Recurse -Filter 'PdfSharp.dll' | Select-Object -First 1

        Copy-Item -LiteralPath $dll.FullName -Destination $DestinoDll -Force
        $hash = (Get-FileHash -LiteralPath $DestinoDll -Algorithm SHA256).Hash
        Set-Content -LiteralPath $HashFile -Value $hash -Encoding ASCII -NoNewline
        Remove-Item -LiteralPath $nupkg -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

[void](Get-SafePdfSharp -DestinoDll $DllPath -HashFile $HashFile)

$conteudoGui = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$cBgMain    = [System.Drawing.Color]::FromArgb(15, 23, 42)
$cBgPanel   = [System.Drawing.Color]::FromArgb(30, 41, 59)
$cBgDark    = [System.Drawing.Color]::FromArgb(2, 6, 23)
$cTextMain  = [System.Drawing.Color]::FromArgb(248, 250, 252)
$cTextSub   = [System.Drawing.Color]::FromArgb(148, 163, 184)
$cPrimary   = [System.Drawing.Color]::FromArgb(59, 130, 246)
$cPrimaryH  = [System.Drawing.Color]::FromArgb(37, 99, 235)
$cSuccess   = [System.Drawing.Color]::FromArgb(16, 185, 129)
$cSuccessH  = [System.Drawing.Color]::FromArgb(5, 150, 105)
$cDanger    = [System.Drawing.Color]::FromArgb(239, 68, 68)
$cNeutral   = [System.Drawing.Color]::FromArgb(51, 65, 85)
$cNeutralH  = [System.Drawing.Color]::FromArgb(71, 85, 105)
$cAccent    = [System.Drawing.Color]::FromArgb(139, 92, 246)

$fTitle     = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$fSubtitle  = New-Object System.Drawing.Font("Segoe UI", 10)
$fBtnNormal = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fBtnLarge  = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$fLog       = New-Object System.Drawing.Font("Consolas", 9)

$script:LibDir  = Join-Path (Split-Path -Parent $PSCommandPath) 'lib'
$script:HashFile = Join-Path $script:LibDir 'PdfSharp.sha256'
$script:LogFile = Join-Path (Split-Path -Parent $PSCommandPath) 'conversao.log'

function Test-PdfSharpIntegrity {
    $dll = Join-Path $script:LibDir 'PdfSharp.dll'
    if (-not (Test-Path -LiteralPath $dll)) { return $false }
    if (-not (Test-Path -LiteralPath $script:HashFile)) { return $false }
    $esperado = (Get-Content -LiteralPath $script:HashFile -Raw).Trim()
    $atual = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    if ($atual -ne $esperado) { return $false }
    return $true
}

function Write-SafeLog {
    param([string]$nivel, [string]$msg)
    try {
        $linha = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $nivel, $msg
        Add-Content -LiteralPath $script:LogFile -Value $linha -Encoding UTF8
    } catch { }
}

function Get-DefaultPrinter {
    try { return (Get-CimInstance Win32_Printer -EA Stop | Where-Object { $_.Default } | Select-Object -First 1).Name }
    catch { return $null }
}
function Set-DefaultPrinter {
    param([string]$Nome)
    try {
        $p = Get-CimInstance Win32_Printer | Where-Object Name -eq $Nome
        if ($p) { Invoke-CimMethod -InputObject $p -MethodName SetDefaultPrinter | Out-Null; return $true }
    } catch {}
    return $false
}

function Convert-WordViaCOM {
    param([object]$WordApp, [string]$Origem, [string]$DestinoPdf)
    if (Test-Path -LiteralPath $DestinoPdf) { Remove-Item -LiteralPath $DestinoPdf -Force }
    $doc = $WordApp.Documents.Open($Origem, $false, $true, $false, [Type]::Missing, [Type]::Missing, $false, [Type]::Missing, [Type]::Missing, [Type]::Missing, [Type]::Missing, $false, $false, [Type]::Missing, $false)
    try {
        try { $doc.ExportAsFixedFormat($DestinoPdf, 17) } catch { }
        Start-Sleep -Milliseconds 500
        if (Test-Path -LiteralPath $DestinoPdf) { if ((Get-Item -LiteralPath $DestinoPdf).Length -gt 1024) { return $true } }
        return $false
    } finally { try { $doc.Close(0) } catch { } }
}

function Convert-WordViaShellPrint {
    param([string]$Origem, [string]$DestinoPdf)
    if (Test-Path -LiteralPath $DestinoPdf) { Remove-Item -LiteralPath $DestinoPdf -Force }
    $mutex = New-Object System.Threading.Mutex($false, 'Global\EnterprisePdfPrinter')
    $adquiriu = $false
    try {
        $adquiriu = $mutex.WaitOne(30000)
        if (-not $adquiriu) { throw "Timeout na impressora." }
        $regWord = 'HKCU:\Software\Microsoft\Office\16.0\Word\Security'
        $origWarn = $null
        try {
            if (Test-Path $regWord) {
                $origWarn = (Get-ItemProperty -Path $regWord -Name 'VBAWarnings' -ErrorAction SilentlyContinue).VBAWarnings
                Set-ItemProperty -Path $regWord -Name 'VBAWarnings' -Value 4 -Type DWord -Force
            }
        } catch {}
        $tipoNome = 'Win32Dialog_' + [Guid]::NewGuid().ToString('N').Substring(0,8)
        $codigo = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class $tipoNome {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern IntPtr FindWindow(string c, string w);
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr ca, string c, string w);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr wp, string lp);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr wp, IntPtr lp);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int i);
    public const uint WM_SETTEXT = 0x000C;
    public const uint WM_GETTEXT = 0x000D;
    public const uint BM_CLICK   = 0x00F5;
    public static string GetText(IntPtr h) { var s = new StringBuilder(1024); SendMessage(h, WM_GETTEXT, (IntPtr)s.Capacity, s); return s.ToString(); }
    public static string ClassName(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, s.Capacity); return s.ToString(); }
}
"@
        Add-Type -TypeDefinition $codigo -ErrorAction Stop
        $tipo = [type]$tipoNome
        $printerOrig = Get-DefaultPrinter
        if (-not (Set-DefaultPrinter -Nome 'Microsoft Print to PDF')) { throw "Impressora nao encontrada." }
        Start-Sleep -Milliseconds 500
        try {
            Start-Process -FilePath $Origem -Verb Print
            $titulos = @('Salvar Saída de Impressão','Salvar Saída de Impressão Como','Salvar Saida de Impressao','Save Print Output As')
            $hDlg = [IntPtr]::Zero
            $ini = Get-Date
            while (((Get-Date) - $ini).TotalSeconds -lt 30) {
                foreach ($t in $titulos) { $h = $tipo::FindWindow($null, $t); if ($h -ne [IntPtr]::Zero) { $hDlg = $h; break } }
                if ($hDlg -ne [IntPtr]::Zero) { break }
                Start-Sleep -Milliseconds 300
                [System.Windows.Forms.Application]::DoEvents()
            }
            if ($hDlg -eq [IntPtr]::Zero) { throw "Dialogo nao apareceu." }
            $editCampo = [IntPtr]::Zero; $hSalvar = [IntPtr]::Zero
            $child = $tipo::FindWindowEx($hDlg, [IntPtr]::Zero, $null, $null)
            while ($child -ne [IntPtr]::Zero) {
                $cn = $tipo::ClassName($child)
                if ($cn -match 'Edit' -and $editCampo -eq [IntPtr]::Zero) { $editCampo = $child }
                if ($cn -match 'Button') { $tb = $tipo::GetText($child); if ($tb -match 'Salvar|Save') { $hSalvar = $child } }
                $sub = $tipo::FindWindowEx($child, [IntPtr]::Zero, $null, $null)
                while ($sub -ne [IntPtr]::Zero) {
                    $sc = $tipo::ClassName($sub)
                    if ($sc -match 'Edit' -and $editCampo -eq [IntPtr]::Zero) { $editCampo = $sub }
                    if ($sc -match 'Button') { $tb = $tipo::GetText($sub); if ($tb -match 'Salvar|Save') { $hSalvar = $sub } }
                    $sub = $tipo::FindWindowEx($child, $sub, $null, $null)
                }
                $child = $tipo::FindWindowEx($hDlg, $child, $null, $null)
            }
            if ($editCampo -eq [IntPtr]::Zero) { $editCampo = $tipo::GetDlgItem($hDlg, 0x47C) }
            if ($hSalvar -eq [IntPtr]::Zero) { $hSalvar = $tipo::GetDlgItem($hDlg, 1) }
            $ok = $false
            for ($i = 1; $i -le 3; $i++) {
                [void]$tipo::SetForegroundWindow($hDlg); Start-Sleep -Milliseconds 150
                [void]$tipo::SendMessage($editCampo, $tipo::WM_SETTEXT, [IntPtr]::Zero, "")
                [void]$tipo::SendMessage($editCampo, $tipo::WM_SETTEXT, [IntPtr]::Zero, $DestinoPdf)
                Start-Sleep -Milliseconds 300
                if ($tipo::GetText($editCampo) -eq $DestinoPdf) { $ok = $true; break }
            }
            if (-not $ok) { throw "Nao consegui definir caminho." }
            Start-Sleep -Milliseconds 300
            [void]$tipo::SendMessage($hSalvar, $tipo::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
            $t2 = 30; $s2 = Get-Date; $tamanho = 0
            while (((Get-Date) - $s2).TotalSeconds -lt $t2) {
                if (Test-Path -LiteralPath $DestinoPdf) { $tamanho = (Get-Item -LiteralPath $DestinoPdf).Length; if ($tamanho -gt 1024) { break } }
                Start-Sleep -Milliseconds 300
                [System.Windows.Forms.Application]::DoEvents()
            }
            if ($tamanho -le 1024) { throw "PDF falhou." }
        } finally {
            if ($printerOrig -and $printerOrig -ne 'Microsoft Print to PDF') { Set-DefaultPrinter -Nome $printerOrig | Out-Null }
            if ($null -ne $origWarn -and (Test-Path $regWord)) {
                try { Set-ItemProperty -Path $regWord -Name 'VBAWarnings' -Value $origWarn -Type DWord -Force } catch {}
            }
        }
    } finally {
        if ($adquiriu) { try { $mutex.ReleaseMutex() } catch {} }
        $mutex.Dispose()
    }
}

function Merge-Pdfs {
    param([string[]]$ListaPdfs, [string]$DestinoPdf)
    if (Test-Path -LiteralPath $DestinoPdf) { Remove-Item -LiteralPath $DestinoPdf -Force }
    $dll = Join-Path $script:LibDir 'PdfSharp.dll'
    if ((Test-Path -LiteralPath $dll) -and (Test-PdfSharpIntegrity)) {
        try { [Reflection.Assembly]::LoadFrom($dll) | Out-Null } catch { }
        try {
            $output = New-Object PdfSharp.Pdf.PdfDocument
            foreach ($f in $ListaPdfs) {
                $input = [PdfSharp.Pdf.IO.PdfReader]::Open((Resolve-Path -LiteralPath $f).Path, [PdfSharp.Pdf.IO.PdfDocumentOpenMode]::Import)
                for ($i = 0; $i -lt $input.PageCount; $i++) { $output.AddPage($input.Pages[$i]) | Out-Null }
            }
            $output.Save($DestinoPdf); $output.Dispose(); return "VETORIAL"
        } catch { }
    }
    return "RASTERIZADO"
}

function Add-Hover { param($Controle, $NormalColor, $HoverColor) $Controle.BackColor = $NormalColor; $Controle.Add_MouseEnter({ param($s,$e); $s.BackColor = $HoverColor }); $Controle.Add_MouseLeave({ param($s,$e); $s.BackColor = $NormalColor }) }
function Write-UiLog {
    param([string]$msg, [System.Drawing.Color]$cor)
    if ($script:txtLog) {
        $script:txtLog.SelectionStart = $script:txtLog.TextLength
        $script:txtLog.SelectionLength = 0
        $script:txtLog.SelectionColor = $cor
        $script:txtLog.AppendText("$msg`r`n")
        $script:txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "PDF Master Pro"
$form.Size = New-Object System.Drawing.Size(1100, 750)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $cBgMain
$form.Font = $fSubtitle

$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size(1100, 45); $header.BackColor = $cBgDark; $header.Dock = "Top"
$form.Controls.Add($header)
$lblLogo = New-Object System.Windows.Forms.Label
$lblLogo.Text = "PDF MASTER PRO"; $lblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblLogo.ForeColor = $cPrimary; $lblLogo.Location = New-Object System.Drawing.Point(15, 12); $lblLogo.AutoSize = $true
$header.Controls.Add($lblLogo)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "X"; $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnClose.FlatStyle = "Flat"; $btnClose.FlatAppearance.BorderSize = 0
$btnClose.Size = New-Object System.Drawing.Size(45, 45); $btnClose.Location = New-Object System.Drawing.Point(1055, 0)
$btnClose.ForeColor = $cTextSub; $btnClose.BackColor = $cBgDark; $btnClose.Add_Click({ $form.Close() })
Add-Hover -Controle $btnClose -NormalColor $cBgDark -HoverColor $cDanger
$header.Controls.Add($btnClose)

$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(220, 705); $sidebar.Location = New-Object System.Drawing.Point(0, 45); $sidebar.BackColor = $cBgPanel
$form.Controls.Add($sidebar)
$btnNavConvert = New-Object System.Windows.Forms.Button
$btnNavConvert.Text = "Converter Docs"; $btnNavConvert.Font = $fBtnNormal; $btnNavConvert.TextAlign = "MiddleLeft"
$btnNavConvert.Padding = New-Object System.Windows.Forms.Padding(20, 0, 0, 0)
$btnNavConvert.FlatStyle = "Flat"; $btnNavConvert.FlatAppearance.BorderSize = 0
$btnNavConvert.Size = New-Object System.Drawing.Size(220, 50); $btnNavConvert.Location = New-Object System.Drawing.Point(0, 20)
$btnNavConvert.ForeColor = $cTextMain; $btnNavConvert.Cursor = "Hand"; $sidebar.Controls.Add($btnNavConvert)

$btnNavMerge = New-Object System.Windows.Forms.Button
$btnNavMerge.Text = "Juntar PDFs"; $btnNavMerge.Font = $fBtnNormal; $btnNavMerge.TextAlign = "MiddleLeft"
$btnNavMerge.Padding = New-Object System.Windows.Forms.Padding(20, 0, 0, 0)
$btnNavMerge.FlatStyle = "Flat"; $btnNavMerge.FlatAppearance.BorderSize = 0
$btnNavMerge.Size = New-Object System.Drawing.Size(220, 50); $btnNavMerge.Location = New-Object System.Drawing.Point(0, 75)
$btnNavMerge.ForeColor = $cTextSub; $btnNavMerge.Cursor = "Hand"; $sidebar.Controls.Add($btnNavMerge)

$mainArea = New-Object System.Windows.Forms.Panel
$mainArea.Size = New-Object System.Drawing.Size(880, 560); $mainArea.Location = New-Object System.Drawing.Point(220, 45); $mainArea.BackColor = $cBgMain
$form.Controls.Add($mainArea)

$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Size = New-Object System.Drawing.Size(880, 145); $logPanel.Location = New-Object System.Drawing.Point(220, 605); $logPanel.BackColor = $cBgDark
$logPanel.Padding = New-Object System.Windows.Forms.Padding(10); $form.Controls.Add($logPanel)
$script:txtLog = New-Object System.Windows.Forms.RichTextBox
$script:txtLog.Dock = "Fill"; $script:txtLog.BackColor = $cBgDark; $script:txtLog.ForeColor = $cSuccess
$script:txtLog.Font = $fLog; $script:txtLog.BorderStyle = "None"; $script:txtLog.ReadOnly = $true
$logPanel.Controls.Add($script:txtLog); $script:txtLog.BringToFront()

$panelConvert = New-Object System.Windows.Forms.Panel
$panelConvert.Dock = "Fill"; $panelConvert.BackColor = $cBgMain; $panelConvert.Visible = $true
$mainArea.Controls.Add($panelConvert)

$btnAddFile = New-Object System.Windows.Forms.Button
$btnAddFile.Text = "+ Adicionar Arquivos"; $btnAddFile.Font = $fBtnNormal
$btnAddFile.FlatStyle = "Flat"; $btnAddFile.FlatAppearance.BorderSize = 0
$btnAddFile.Size = New-Object System.Drawing.Size(200, 40); $btnAddFile.Location = New-Object System.Drawing.Point(30, 100)
$btnAddFile.ForeColor = [System.Drawing.Color]::White; $btnAddFile.Cursor = "Hand"
Add-Hover -Controle $btnAddFile -NormalColor $cPrimary -HoverColor $cPrimaryH
$panelConvert.Controls.Add($btnAddFile)

$script:listViewConvert = New-Object System.Windows.Forms.ListView
$script:listViewConvert.View = "Details"; $script:listViewConvert.FullRowSelect = $true; $script:listViewConvert.BorderStyle = "None"
$script:listViewConvert.BackColor = $cBgDark; $script:listViewConvert.ForeColor = $cTextMain; $script:listViewConvert.Font = $fSubtitle
$script:listViewConvert.Location = New-Object System.Drawing.Point(30, 155); $script:listViewConvert.Size = New-Object System.Drawing.Size(820, 250)
[void]$script:listViewConvert.Columns.Add("Arquivo", 500)
[void]$script:listViewConvert.Columns.Add("Tipo", 100)
[void]$script:listViewConvert.Columns.Add("Status", 200)
$panelConvert.Controls.Add($script:listViewConvert)

$btnDoConvert = New-Object System.Windows.Forms.Button
$btnDoConvert.Text = "CONVERTER AGORA"; $btnDoConvert.Font = $fBtnLarge
$btnDoConvert.FlatStyle = "Flat"; $btnDoConvert.FlatAppearance.BorderSize = 0
$btnDoConvert.Size = New-Object System.Drawing.Size(820, 60); $btnDoConvert.Location = New-Object System.Drawing.Point(30, 470)
$btnDoConvert.ForeColor = [System.Drawing.Color]::White; $btnDoConvert.Cursor = "Hand"
Add-Hover -Controle $btnDoConvert -NormalColor $cSuccess -HoverColor $cSuccessH
$panelConvert.Controls.Add($btnDoConvert)

$panelMerge = New-Object System.Windows.Forms.Panel
$panelMerge.Dock = "Fill"; $panelMerge.BackColor = $cBgMain; $panelMerge.Visible = $false
$mainArea.Controls.Add($panelMerge)

$btnAddPdf = New-Object System.Windows.Forms.Button
$btnAddPdf.Text = "+ Adicionar PDFs"; $btnAddPdf.Font = $fBtnNormal; $btnAddPdf.FlatStyle = "Flat"; $btnAddPdf.FlatAppearance.BorderSize = 0
$btnAddPdf.Size = New-Object System.Drawing.Size(180, 40); $btnAddPdf.Location = New-Object System.Drawing.Point(30, 100)
$btnAddPdf.ForeColor = [System.Drawing.Color]::White; $btnAddPdf.Cursor = "Hand"
Add-Hover -Controle $btnAddPdf -NormalColor $cPrimary -HoverColor $cPrimaryH
$panelMerge.Controls.Add($btnAddPdf)

$btnDoMerge = New-Object System.Windows.Forms.Button
$btnDoMerge.Text = "MESCLAR AGORA"; $btnDoMerge.Font = $fBtnLarge; $btnDoMerge.FlatStyle = "Flat"; $btnDoMerge.FlatAppearance.BorderSize = 0
$btnDoMerge.Size = New-Object System.Drawing.Size(820, 60); $btnDoMerge.Location = New-Object System.Drawing.Point(30, 440)
$btnDoMerge.ForeColor = [System.Drawing.Color]::White; $btnDoMerge.Cursor = "Hand"
Add-Hover -Controle $btnDoMerge -NormalColor $cAccent -HoverColor [System.Drawing.Color]::FromArgb(124, 58, 237)
$panelMerge.Controls.Add($btnDoMerge)

function Show-ConvertTab { $panelConvert.Visible = $true; $panelMerge.Visible = $false; $btnNavConvert.BackColor = $cBgMain; $btnNavConvert.ForeColor = $cPrimary; $btnNavMerge.BackColor = $cBgPanel; $btnNavMerge.ForeColor = $cTextSub }
function Show-MergeTab { $panelConvert.Visible = $false; $panelMerge.Visible = $true; $btnNavMerge.BackColor = $cBgMain; $btnNavMerge.ForeColor = $cAccent; $btnNavConvert.BackColor = $cBgPanel; $btnNavConvert.ForeColor = $cTextSub }
$btnNavConvert.Add_Click({ Show-ConvertTab }); $btnNavMerge.Add_Click({ Show-MergeTab })
Show-ConvertTab

[void]$form.ShowDialog()
'@

Set-Content -LiteralPath $Ps1Gui -Value $conteudoGui -Encoding UTF8

$batConteudo = @"
@echo off
title PDF Master Pro - Enterprise
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Conversor-GUI.ps1" %*
exit
"@
Set-Content -LiteralPath $Bat -Value $batConteudo -Encoding OEM

function New-Atalho {
    param([string]$CaminhoLnk, [string]$Alvo, [string]$WorkDir, [string]$Descricao)
    try {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($CaminhoLnk)
        $sc.TargetPath = $Alvo; $sc.WorkingDirectory = $WorkDir; $sc.Description = $Descricao
        $sc.IconLocation = "$env:SystemRoot\System32\imageres.dll,102"; $sc.Save()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($sc)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($ws)
    } catch {}
}

$desktop = [Environment]::GetFolderPath('Desktop')
New-Atalho -CaminhoLnk (Join-Path $desktop 'PDF Master (Enterprise).lnk') -Alvo $Bat -WorkDir $Destino -Descricao 'Converte e mescla PDFs'
$menuIni = [Environment]::GetFolderPath('Programs')
New-Atalho -CaminhoLnk (Join-Path $menuIni 'PDF Master (Enterprise).lnk') -Alvo $Bat -WorkDir $Destino -Descricao 'Converte e mescla PDFs'

Write-Host "INSTALACAO CONCLUIDA!" -ForegroundColor Green
$r = Read-Host "Abrir o programa agora? (S/N)"
if ($r -match '^[SsYy]') { Start-Process $Bat }
