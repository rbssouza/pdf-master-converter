
5. Role a página até o final e clique no botão verde **`Commit changes...`** e confirme.

### Passo 3: Subir o Código (O Instalador)
1. Na página principal do repositório, clique em **`Add file`** -> **`Create new file`**.
2. No nome do arquivo, digite: **`Instalador-PDF.ps1`**
3. No espaço grande, cole o código abaixo **inteiro**:

```powershell
# ============================================================
#  INSTALADOR SEGURO - CONVERSOR PDF PRO (HARDENED)
#  Correções aplicadas: verificação de hash do DLL, bloqueio
#  de macros, validação de links externos, mutex de impressora,
#  TLS forçado, abertura segura de arquivos, log mascarado.
# ============================================================

$Destino = Join-Path $env:LOCALAPPDATA 'EnterpriseTools'
$Ps1Gui  = Join-Path $Destino 'Conversor-GUI.ps1'
$Bat     = Join-Path $Destino 'converter.bat'
$LibDir  = Join-Path $Destino 'lib'
$DllPath = Join-Path $LibDir 'PdfSharp.dll'
$HashFile = Join-Path $LibDir 'PdfSharp.sha256'

Clear-Host
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host "  |      ***  CONVERSOR PDF PRO - INSTALADOR SEGURO  ***         |" -ForegroundColor Magenta
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path -LiteralPath $Destino)) { New-Item -ItemType Directory -Path $Destino -Force | Out-Null }
if (-not (Test-Path -LiteralPath $LibDir))  { New-Item -ItemType Directory -Path $LibDir  -Force | Out-Null }

# ============================================================
# 1) DOWNLOAD SEGURO do PdfSharp com verificação de hash (TOFU)
# ============================================================
function Get-SafePdfSharp {
    param([string]$DestinoDll, [string]$HashFile)

    if (Test-Path -LiteralPath $DestinoDll) {
        if (Test-Path -LiteralPath $HashFile) {
            $esperado = (Get-Content -LiteralPath $HashFile -Raw).Trim()
            $atual = (Get-FileHash -LiteralPath $DestinoDll -Algorithm SHA256).Hash
            if ($atual -eq $esperado) {
                Write-Host "  [ OK ] PdfSharp.dll verificado (hash confere)." -ForegroundColor Green
                return $true
            } else {
                Write-Host "  [!] Hash do PdfSharp.dll NAO confere - removendo." -ForegroundColor Red
                Remove-Item -LiteralPath $DestinoDll -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $HashFile -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "  [!] PdfSharp.dll sem hash salvo - removendo por seguranca." -ForegroundColor Yellow
            Remove-Item -LiteralPath $DestinoDll -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "  [INFO] Baixando PdfSharp.dll (TLS 1.2+ forçado)..." -ForegroundColor Cyan
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
            if (-not $novaUrl.StartsWith('https://')) { throw "Redirecionamento inseguro detectado!" }
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
        $dll = Get-ChildItem -Path $tmp -Recurse -Filter 'PdfSharp.dll' |
               Where-Object { $_.FullName -match '\\lib\\net20\\' } |
               Select-Object -First 1
        if (-not $dll) { $dll = Get-ChildItem -Path $tmp -Recurse -Filter 'PdfSharp.dll' | Select-Object -First 1 }
        if (-not $dll) { throw "PdfSharp.dll nao encontrado no pacote." }

        Copy-Item -LiteralPath $dll.FullName -Destination $DestinoDll -Force
        $hash = (Get-FileHash -LiteralPath $DestinoDll -Algorithm SHA256).Hash
        Set-Content -LiteralPath $HashFile -Value $hash -Encoding ASCII -NoNewline
        Write-Host "  [ OK ] PdfSharp.dll baixado. SHA256: $($hash.Substring(0,16))..." -ForegroundColor Green

        Remove-Item -LiteralPath $nupkg -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        Write-Host "  [INFO] Sem internet ou bloqueio. Merge usara modo rasterizado." -ForegroundColor Yellow
        return $false
    }
}

[void](Get-SafePdfSharp -DestinoDll $DllPath -HashFile $HashFile)

# ============================================================
# 2) SCRIPT PRINCIPAL (GUI HARDENED)
# ============================================================
$conteudoGui = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- PALETA ----------
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
$cDangerH   = [System.Drawing.Color]::FromArgb(220, 38, 38)
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

# ============================================================
# PROTEÇÕES BÁSICAS
# ============================================================
function Test-PdfSharpIntegrity {
    $dll = Join-Path $script:LibDir 'PdfSharp.dll'
    if (-not (Test-Path -LiteralPath $dll)) { return $false }
    if (-not (Test-Path -LiteralPath $script:HashFile)) {
        Write-UiLog "[SEGURANCA] Hash do PdfSharp ausente - desabilitando merge vetorial." -cor $cDanger
        return $false
    }
    $esperado = (Get-Content -LiteralPath $script:HashFile -Raw).Trim()
    $atual = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    if ($atual -ne $esperado) {
        Write-UiLog "[SEGURANCA] Hash do PdfSharp NAO CONFERE - possivel adulteracao!" -cor $cDanger
        return $false
    }
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

# ============================================================
# MOTOR DE CONVERSAO (com hardening)
# ============================================================
function Convert-WordViaCOM {
    param([object]$WordApp, [string]$Origem, [string]$DestinoPdf)
    if (Test-Path -LiteralPath $DestinoPdf) { Remove-Item -LiteralPath $DestinoPdf -Force }

    $doc = $WordApp.Documents.Open(
        $Origem,          # FileName
        $false,           # ConfirmConversions
        $true,            # ReadOnly
        $false,           # AddToRecentFiles
        [Type]::Missing,  # PasswordDocument
        [Type]::Missing,  # PasswordTemplate
        $false,           # Revert
        [Type]::Missing,  # WritePasswordDocument
        [Type]::Missing,  # WritePasswordTemplate
        [Type]::Missing,  # Format (auto-detecta)
        [Type]::Missing,  # Encoding
        $false,           # Visible
        $false,           # OpenAndRepair
        [Type]::Missing,  # DocumentDirection
        $false            # NoEncodingDialog
    )
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
        if (-not $adquiriu) { throw "Timeout aguardando outro processo liberar a impressora." }

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
    public const uint WM_COMMAND = 0x0111;
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

function Convert-XpsToPdf {
    param([string]$OrigemXps, [string]$DestinoPdf)
    Add-Type -AssemblyName ReachFramework, PresentationCore, WindowsBase, System.Drawing
    if (Test-Path -LiteralPath $DestinoPdf) { Remove-Item -LiteralPath $DestinoPdf -Force }
    $xpsDoc = $null; $paginas = @()
    try {
        $xpsDoc = New-Object System.Windows.Xps.Packaging.XpsDocument($OrigemXps, [System.IO.FileAccess]::Read)
        $seq = $xpsDoc.GetFixedDocumentSequence()
        foreach ($docRef in $seq.References) { $fd = $docRef.GetDocument($true); foreach ($pc in $fd.Pages) { $paginas += $pc.GetPageRoot($true) } }
    } catch { if ($xpsDoc) { try { $xpsDoc.Close() } catch {} }; throw "Falha XPS: $($_.Exception.Message)" }
    $dpi = 200; $bitmaps = @(); $tamPt = $null
    foreach ($pg in $paginas) {
        $w = $pg.Width; $h = $pg.Height
        $pg.Measure((New-Object System.Windows.Size($w, $h))); $pg.Arrange((New-Object System.Windows.Rect(0, 0, $w, $h))); $pg.UpdateLayout()
        $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int]($w * $dpi / 96), [int]($h * $dpi / 96), $dpi, $dpi, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($pg)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $ms = New-Object System.IO.MemoryStream; $enc.Save($ms); $ms.Position = 0
        $bitmaps += [System.Drawing.Image]::FromStream($ms)
        if (-not $tamPt) { $tamPt = @{ W = [int]($w / 96 * 100); H = [int]($h / 96 * 100) } }
    }
    try { $xpsDoc.Close() } catch {}
    $pd = New-Object System.Drawing.Printing.PrintDocument
    $pd.PrinterSettings.PrinterName = 'Microsoft Print to PDF'
    $pd.PrinterSettings.PrintToFile = $true; $pd.PrinterSettings.PrintFileName = $DestinoPdf
    $pd.DefaultPageSettings.PaperSize = New-Object System.Drawing.Printing.PaperSize('X', $tamPt.W, $tamPt.H)
    $pd.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0,0,0,0)
    $script:_idx = 0; $script:_bmp = $bitmaps
    $pd.add_PrintPage({ param($s, $e); $e.Graphics.DrawImage($script:_bmp[$script:_idx], 0, 0, $e.PageBounds.Width, $e.PageBounds.Height); $script:_idx++; $e.HasMorePages = ($script:_idx -lt $script:_bmp.Count) })
    try { $pd.Print() } finally { foreach ($b in $bitmaps) { try { $b.Dispose() } catch {} }; try { $pd.Dispose() } catch {} }
}

function Merge-Pdfs {
    param([string[]]$ListaPdfs, [string]$DestinoPdf)
    if (Test-Path -LiteralPath $DestinoPdf) { Remove-Item -LiteralPath $DestinoPdf -Force }

    $dll = Join-Path $script:LibDir 'PdfSharp.dll'
    if ((Test-Path -LiteralPath $dll) -and (Test-PdfSharpIntegrity)) {
        try { [Reflection.Assembly]::LoadFrom($dll) | Out-Null } catch {
            Write-UiLog "[SEGURANCA] Nao carregou PdfSharp (hash ok mas load falhou)." -cor $cDanger
        }
        try {
            $output = New-Object PdfSharp.Pdf.PdfDocument
            foreach ($f in $ListaPdfs) {
                $input = [PdfSharp.Pdf.IO.PdfReader]::Open((Resolve-Path -LiteralPath $f).Path, [PdfSharp.Pdf.IO.PdfDocumentOpenMode]::Import)
                for ($i = 0; $i -lt $input.PageCount; $i++) { $output.AddPage($input.Pages[$i]) | Out-Null }
            }
            $output.Save($DestinoPdf); $output.Dispose(); return "VETORIAL"
        } catch { Write-UiLog "[AVISO] PdfSharp falhou, caindo para rasterizado..." -cor $cTextSub }
    } else {
        Write-UiLog "[INFO] Merge rasterizado (PdfSharp indisponivel/invalido)." -cor $cTextSub
    }

    Add-Type -AssemblyName System.Drawing
    [void][Windows.Data.Pdf.PdfDocument,Windows.Data.Pdf,ContentType=WindowsRuntime]
    [void][Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
    [void][Windows.Storage.Streams.InMemoryRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
    [void][Windows.Storage.Streams.DataReader,Windows.Storage.Streams,ContentType=WindowsRuntime]
    $todas = New-Object System.Collections.ArrayList
    foreach ($pdfPath in $ListaPdfs) {
        $file = [Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path -LiteralPath $pdfPath).Path).GetAwaiter().GetResult()
        $doc  = [Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file).GetAwaiter().GetResult()
        for ($i = 0; $i -lt $doc.PageCount; $i++) {
            $page = $doc.GetPage($i); $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
            $opts = New-Object Windows.Data.Pdf.PdfPageRenderOptions
            $opts.DestinationWidth = [uint32]($page.Size.Width * 2); $opts.DestinationHeight = [uint32]($page.Size.Height * 2)
            $page.RenderToStreamAsync($stream, $opts).GetAwaiter().GetResult() | Out-Null
            $size = [int]$stream.Size; $reader = New-Object Windows.Storage.Streams.DataReader($stream.GetInputStreamAt(0))
            $reader.LoadAsync([uint32]$size).GetAwaiter().GetResult() | Out-Null
            $bytes = New-Object byte[] $size; $reader.ReadBytes($bytes)
            [void]$todas.Add([System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,$bytes))))
            $reader.Dispose(); $stream.Dispose(); $page.Dispose()
        }
    }
    $pd = New-Object System.Drawing.Printing.PrintDocument
    $pd.PrinterSettings.PrinterName = 'Microsoft Print to PDF'
    $pd.PrinterSettings.PrintToFile = $true; $pd.PrinterSettings.PrintFileName = $DestinoPdf
    $pd.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0,0,0,0)
    $script:_mi = 0; $script:_mp = $todas
    $pd.add_PrintPage({ param($s, $e); $e.Graphics.DrawImage($script:_mp[$script:_mi], 0, 0, $e.PageBounds.Width, $e.PageBounds.Height); $script:_mi++; $e.HasMorePages = ($script:_mi -lt $script:_mp.Count) })
    try { $pd.Print() } finally { foreach ($b in $todas) { try { $b.Dispose() } catch {} } }
    return "RASTERIZADO"
}

# ============================================================
# HELPERS UI
# ============================================================
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

# ============================================================
# FORM PRINCIPAL
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "PDF Master Pro"
$form.Size = New-Object System.Drawing.Size(1100, 750)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = $cBgMain
$form.Font = $fSubtitle

$form.Add_FormClosing({
    if ($script:word) { try { $script:word.Quit() } catch {} }
    if ($script:excel) { try { $script:excel.Quit() } catch {} }
    if ($script:ppt) { try { $script:ppt.Quit() } catch {} }
    [GC]::Collect()
})

# Header
$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size(1100, 45); $header.BackColor = $cBgDark; $header.Dock = "Top"
$form.Controls.Add($header)
$lblLogo = New-Object System.Windows.Forms.Label
$lblLogo.Text = "PDF MASTER PRO"; $lblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblLogo.ForeColor = $cPrimary; $lblLogo.Location = New-Object System.Drawing.Point(15, 12); $lblLogo.AutoSize = $true
$header.Controls.Add($lblLogo)

$header.Add_MouseDown({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $script:dragging = $true; $script:startPoint = $e.Location } })
$header.Add_MouseMove({ param($s, $e) if ($script:dragging) { $form.Location = New-Object System.Drawing.Point(($form.Location.X + $e.X - $script:startPoint.X),($form.Location.Y + $e.Y - $script:startPoint.Y)) } })
$header.Add_MouseUp({ $script:dragging = $false })

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "X"; $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnClose.FlatStyle = "Flat"; $btnClose.FlatAppearance.BorderSize = 0
$btnClose.Size = New-Object System.Drawing.Size(45, 45); $btnClose.Location = New-Object System.Drawing.Point(1055, 0)
$btnClose.ForeColor = $cTextSub; $btnClose.BackColor = $cBgDark; $btnClose.Add_Click({ $form.Close() })
Add-Hover -Controle $btnClose -NormalColor $cBgDark -HoverColor $cDanger
$header.Controls.Add($btnClose)

$btnMin = New-Object System.Windows.Forms.Button
$btnMin.Text = "_"; $btnMin.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnMin.FlatStyle = "Flat"; $btnMin.FlatAppearance.BorderSize = 0
$btnMin.Size = New-Object System.Drawing.Size(45, 45); $btnMin.Location = New-Object System.Drawing.Point(1010, 0)
$btnMin.ForeColor = $cTextSub; $btnMin.BackColor = $cBgDark; $btnMin.Add_Click({ $form.WindowState = 'Minimized' })
Add-Hover -Controle $btnMin -NormalColor $cBgDark -HoverColor $cNeutralH
$header.Controls.Add($btnMin)

# Sidebar
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

# Main
$mainArea = New-Object System.Windows.Forms.Panel
$mainArea.Size = New-Object System.Drawing.Size(880, 560); $mainArea.Location = New-Object System.Drawing.Point(220, 45); $mainArea.BackColor = $cBgMain
$form.Controls.Add($mainArea)

# Console
$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Size = New-Object System.Drawing.Size(880, 145); $logPanel.Location = New-Object System.Drawing.Point(220, 605); $logPanel.BackColor = $cBgDark
$logPanel.Padding = New-Object System.Windows.Forms.Padding(10); $form.Controls.Add($logPanel)
$lblLogTitle = New-Object System.Windows.Forms.Label
$lblLogTitle.Text = "TERMINAL DE STATUS"; $lblLogTitle.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
$lblLogTitle.ForeColor = $cAccent; $lblLogTitle.Dock = "Top"; $lblLogTitle.Height = 20
$logPanel.Controls.Add($lblLogTitle)
$script:txtLog = New-Object System.Windows.Forms.RichTextBox
$script:txtLog.Dock = "Fill"; $script:txtLog.BackColor = $cBgDark; $script:txtLog.ForeColor = $cSuccess
$script:txtLog.Font = $fLog; $script:txtLog.BorderStyle = "None"; $script:txtLog.ReadOnly = $true
$logPanel.Controls.Add($script:txtLog); $script:txtLog.BringToFront()

# ============================================================
# TELA CONVERTER
# ============================================================
$panelConvert = New-Object System.Windows.Forms.Panel
$panelConvert.Dock = "Fill"; $panelConvert.BackColor = $cBgMain; $panelConvert.Visible = $true
$mainArea.Controls.Add($panelConvert)

$lblTitleConv = New-Object System.Windows.Forms.Label
$lblTitleConv.Text = "Conversao Inteligente"; $lblTitleConv.Font = $fTitle; $lblTitleConv.ForeColor = $cTextMain
$lblTitleConv.Location = New-Object System.Drawing.Point(30, 20); $lblTitleConv.AutoSize = $true; $panelConvert.Controls.Add($lblTitleConv)

$lblSubConv = New-Object System.Windows.Forms.Label
$lblSubConv.Text = "Arraste e solte arquivos ou adicione-os abaixo."; $lblSubConv.Font = $fSubtitle; $lblSubConv.ForeColor = $cTextSub
$lblSubConv.Location = New-Object System.Drawing.Point(33, 60); $lblSubConv.AutoSize = $true; $panelConvert.Controls.Add($lblSubConv)

$btnAddFile = New-Object System.Windows.Forms.Button
$btnAddFile.Text = "+ Adicionar Arquivos"; $btnAddFile.Font = $fBtnNormal
$btnAddFile.FlatStyle = "Flat"; $btnAddFile.FlatAppearance.BorderSize = 0
$btnAddFile.Size = New-Object System.Drawing.Size(200, 40); $btnAddFile.Location = New-Object System.Drawing.Point(30, 100)
$btnAddFile.ForeColor = [System.Drawing.Color]::White; $btnAddFile.Cursor = "Hand"
Add-Hover -Controle $btnAddFile -NormalColor $cPrimary -HoverColor $cPrimaryH
$panelConvert.Controls.Add($btnAddFile)

$btnClearFiles = New-Object System.Windows.Forms.Button
$btnClearFiles.Text = "Limpar Lista"; $btnClearFiles.Font = $fBtnNormal
$btnClearFiles.FlatStyle = "Flat"; $btnClearFiles.FlatAppearance.BorderSize = 0
$btnClearFiles.Size = New-Object System.Drawing.Size(140, 40); $btnClearFiles.Location = New-Object System.Drawing.Point(240, 100)
$btnClearFiles.ForeColor = $cTextMain; $btnClearFiles.Cursor = "Hand"
Add-Hover -Controle $btnClearFiles -NormalColor $cNeutral -HoverColor $cNeutralH
$panelConvert.Controls.Add($btnClearFiles)

$script:listViewConvert = New-Object System.Windows.Forms.ListView
$script:listViewConvert.View = "Details"; $script:listViewConvert.FullRowSelect = $true; $script:listViewConvert.BorderStyle = "None"
$script:listViewConvert.BackColor = $cBgDark; $script:listViewConvert.ForeColor = $cTextMain; $script:listViewConvert.Font = $fSubtitle
$script:listViewConvert.Location = New-Object System.Drawing.Point(30, 155); $script:listViewConvert.Size = New-Object System.Drawing.Size(820, 250)
[void]$script:listViewConvert.Columns.Add("Arquivo", 500)
[void]$script:listViewConvert.Columns.Add("Tipo", 100)
[void]$script:listViewConvert.Columns.Add("Status", 200)
$script:listViewConvert.AllowDrop = $true; $panelConvert.Controls.Add($script:listViewConvert)

$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text = "Destino:"; $lblOut.Font = $fBtnNormal; $lblOut.ForeColor = $cTextSub
$lblOut.Location = New-Object System.Drawing.Point(30, 420); $lblOut.AutoSize = $true; $panelConvert.Controls.Add($lblOut)

$script:txtOut = New-Object System.Windows.Forms.TextBox
$script:txtOut.Font = $fSubtitle; $script:txtOut.Location = New-Object System.Drawing.Point(100, 418)
$script:txtOut.Size = New-Object System.Drawing.Size(650, 27); $script:txtOut.ReadOnly = $true
$script:txtOut.BackColor = $cBgPanel; $script:txtOut.ForeColor = $cTextMain; $script:txtOut.BorderStyle = "FixedSingle"
$script:txtOut.Text = [Environment]::GetFolderPath('Desktop'); $panelConvert.Controls.Add($script:txtOut)

$btnOut = New-Object System.Windows.Forms.Button
$btnOut.Text = "..."; $btnOut.Font = $fBtnNormal; $btnOut.FlatStyle = "Flat"; $btnOut.FlatAppearance.BorderSize = 0
$btnOut.Size = New-Object System.Drawing.Size(70, 27); $btnOut.Location = New-Object System.Drawing.Point(760, 418)
$btnOut.ForeColor = $cTextMain; $btnOut.Cursor = "Hand"
Add-Hover -Controle $btnOut -NormalColor $cNeutral -HoverColor $cNeutralH
$panelConvert.Controls.Add($btnOut)

$btnDoConvert = New-Object System.Windows.Forms.Button
$btnDoConvert.Text = "CONVERTER AGORA"; $btnDoConvert.Font = $fBtnLarge
$btnDoConvert.FlatStyle = "Flat"; $btnDoConvert.FlatAppearance.BorderSize = 0
$btnDoConvert.Size = New-Object System.Drawing.Size(820, 60); $btnDoConvert.Location = New-Object System.Drawing.Point(30, 470)
$btnDoConvert.ForeColor = [System.Drawing.Color]::White; $btnDoConvert.Cursor = "Hand"
Add-Hover -Controle $btnDoConvert -NormalColor $cSuccess -HoverColor $cSuccessH
$panelConvert.Controls.Add($btnDoConvert)

# ============================================================
# TELA MERGE
# ============================================================
$panelMerge = New-Object System.Windows.Forms.Panel
$panelMerge.Dock = "Fill"; $panelMerge.BackColor = $cBgMain; $panelMerge.Visible = $false
$mainArea.Controls.Add($panelMerge)

$lblTitleMerge = New-Object System.Windows.Forms.Label
$lblTitleMerge.Text = "Mesclar Documentos"; $lblTitleMerge.Font = $fTitle; $lblTitleMerge.ForeColor = $cTextMain
$lblTitleMerge.Location = New-Object System.Drawing.Point(30, 20); $lblTitleMerge.AutoSize = $true; $panelMerge.Controls.Add($lblTitleMerge)

$lblSubMerge = New-Object System.Windows.Forms.Label
$lblSubMerge.Text = "Organize a ordem dos PDFs e crie um unico arquivo consolidado."; $lblSubMerge.Font = $fSubtitle; $lblSubMerge.ForeColor = $cTextSub
$lblSubMerge.Location = New-Object System.Drawing.Point(33, 60); $lblSubMerge.AutoSize = $true; $panelMerge.Controls.Add($lblSubMerge)

$btnAddPdf = New-Object System.Windows.Forms.Button
$btnAddPdf.Text = "+ Adicionar PDFs"; $btnAddPdf.Font = $fBtnNormal; $btnAddPdf.FlatStyle = "Flat"; $btnAddPdf.FlatAppearance.BorderSize = 0
$btnAddPdf.Size = New-Object System.Drawing.Size(180, 40); $btnAddPdf.Location = New-Object System.Drawing.Point(30, 100)
$btnAddPdf.ForeColor = [System.Drawing.Color]::White; $btnAddPdf.Cursor = "Hand"
Add-Hover -Controle $btnAddPdf -NormalColor $cPrimary -HoverColor $cPrimaryH
$panelMerge.Controls.Add($btnAddPdf)

$btnClearPdf = New-Object System.Windows.Forms.Button
$btnClearPdf.Text = "Limpar"; $btnClearPdf.Font = $fBtnNormal; $btnClearPdf.FlatStyle = "Flat"; $btnClearPdf.FlatAppearance.BorderSize = 0
$btnClearPdf.Size = New-Object System.Drawing.Size(100, 40); $btnClearPdf.Location = New-Object System.Drawing.Point(220, 100)
$btnClearPdf.ForeColor = $cTextMain; $btnClearPdf.Cursor = "Hand"
Add-Hover -Controle $btnClearPdf -NormalColor $cNeutral -HoverColor $cNeutralH
$panelMerge.Controls.Add($btnClearPdf)

$btnUp = New-Object System.Windows.Forms.Button
$btnUp.Text = "Subir"; $btnUp.Font = $fBtnNormal; $btnUp.FlatStyle = "Flat"; $btnUp.FlatAppearance.BorderSize = 0
$btnUp.Size = New-Object System.Drawing.Size(90, 40); $btnUp.Location = New-Object System.Drawing.Point(340, 100)
$btnUp.ForeColor = $cTextMain; $btnUp.Cursor = "Hand"
Add-Hover -Controle $btnUp -NormalColor $cNeutral -HoverColor $cNeutralH
$panelMerge.Controls.Add($btnUp)

$btnDown = New-Object System.Windows.Forms.Button
$btnDown.Text = "Descer"; $btnDown.Font = $fBtnNormal; $btnDown.FlatStyle = "Flat"; $btnDown.FlatAppearance.BorderSize = 0
$btnDown.Size = New-Object System.Drawing.Size(100, 40); $btnDown.Location = New-Object System.Drawing.Point(440, 100)
$btnDown.ForeColor = $cTextMain; $btnDown.Cursor = "Hand"
Add-Hover -Controle $btnDown -NormalColor $cNeutral -HoverColor $cNeutralH
$panelMerge.Controls.Add($btnDown)

$script:listViewMerge = New-Object System.Windows.Forms.ListView
$script:listViewMerge.View = "List"; $script:listViewMerge.FullRowSelect = $true; $script:listViewMerge.BorderStyle = "None"
$script:listViewMerge.BackColor = $cBgDark; $script:listViewMerge.ForeColor = $cTextMain; $script:listViewMerge.Font = $fSubtitle
$script:listViewMerge.Location = New-Object System.Drawing.Point(30, 155); $script:listViewMerge.Size = New-Object System.Drawing.Size(820, 230)
$panelMerge.Controls.Add($script:listViewMerge)

$lblName = New-Object System.Windows.Forms.Label
$lblName.Text = "Nome do PDF Final:"; $lblName.Font = $fBtnNormal; $lblName.ForeColor = $cTextSub
$lblName.Location = New-Object System.Drawing.Point(30, 400); $lblName.AutoSize = $true; $panelMerge.Controls.Add($lblName)

$script:txtName = New-Object System.Windows.Forms.TextBox
$script:txtName.Font = $fSubtitle; $script:txtName.Location = New-Object System.Drawing.Point(160, 398)
$script:txtName.Size = New-Object System.Drawing.Size(350, 27); $script:txtName.BackColor = $cBgPanel
$script:txtName.ForeColor = $cTextMain; $script:txtName.BorderStyle = "FixedSingle"; $script:txtName.Text = "PDF_UNICO"
$panelMerge.Controls.Add($script:txtName)

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

# ============================================================
# EVENTOS
# ============================================================
function Test-ExtensaoPermitida { param([string]$ext) return ($ext -match '^\.(docx|doc|rtf|xlsx|xls|csv|pptx|ppt|xps|oxps)$') }

function Add-FileToConvertList {
    param([string]$file)
    $ext = [IO.Path]::GetExtension($file).ToLower()
    if (-not (Test-ExtensaoPermitida -ext $ext)) { return }
    foreach ($item in $script:listViewConvert.Items) { if ($item.Text -eq $file) { return } }
    $typeStr = switch -Regex ($ext) {
        '\.(docx|doc|rtf)' { "Word" }; '\.(xlsx|xls|csv)' { "Excel" }
        '\.(pptx|ppt)' { "PowerPoint" }; '\.(xps|oxps)' { "XPS" }
    }
    $item = New-Object System.Windows.Forms.ListViewItem($file)
    [void]$item.SubItems.Add($typeStr); [void]$item.SubItems.Add("Pendente")
    [void]$script:listViewConvert.Items.Add($item)
}

$btnAddFile.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'Documentos|*.docx;*.doc;*.rtf;*.xlsx;*.xls;*.csv;*.pptx;*.ppt;*.xps;*.oxps'
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq 'OK') { foreach ($f in $dlg.FileNames) { Add-FileToConvertList -file $f } }
})
$btnClearFiles.Add_Click({ $script:listViewConvert.Items.Clear(); Write-UiLog "[SISTEMA] Lista de conversao limpa." -cor $cTextSub })
$btnOut.Add_Click({ $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; if ($dlg.ShowDialog() -eq 'OK') { $script:txtOut.Text = $dlg.SelectedPath } })

$script:listViewConvert.Add_DragEnter({ param($s, $e) if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy } })
$script:listViewConvert.Add_DragDrop({ param($s, $e) $files = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop); foreach ($f in $files) { Add-FileToConvertList -file $f } })

$btnDoConvert.Add_Click({
    if ($script:listViewConvert.Items.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Adicione arquivos primeiro!"); return }
    $btnDoConvert.Enabled = $false; $btnDoConvert.Text = "PROCESSANDO..."; $btnDoConvert.BackColor = $cNeutral

    $script:word = $null; $script:excel = $null; $script:ppt = $null
    $stats = @{ Ok = 0; Falha = 0 }

    foreach ($item in $script:listViewConvert.Items) {
        $f = $item.Text
        $item.SubItems[2].Text = "Processando..."
        [System.Windows.Forms.Application]::DoEvents()

        $ext = [IO.Path]::GetExtension($f).ToLower()
        $outPdf = Join-Path $script:txtOut.Text ([IO.Path]::GetFileNameWithoutExtension($f) + ".pdf")
        $nomeMascarado = [IO.Path]::GetFileName($f)
        Write-UiLog "> Convertendo: $nomeMascarado" -cor $cPrimary
        Write-SafeLog 'CONV' ("Iniciando: {0}" -f $nomeMascarado)

        try {
            if ($ext -match '\.(docx|doc|rtf)') {
                if (-not $script:word) {
                    $script:word = New-Object -ComObject Word.Application
                    $script:word.Visible = $false
                    $script:word.DisplayAlerts = 0
                    try { $script:word.AutomationSecurity = 3 } catch {}
                    try { $script:word.Options.ConfirmConversions = $false } catch {}
                }
                $ok = Convert-WordViaCOM -WordApp $script:word -Origem $f -DestinoPdf $outPdf
                if (-not $ok) { Convert-WordViaShellPrint -Origem $f -DestinoPdf $outPdf }
            } elseif ($ext -match '\.(xlsx|xls|csv)') {
                if (-not $script:excel) {
                    $script:excel = New-Object -ComObject Excel.Application
                    $script:excel.Visible = $false
                    $script:excel.DisplayAlerts = $false
                    try { $script:excel.AutomationSecurity = 3 } catch {}
                }
                $wb = $script:excel.Workbooks.Open($f, 0, $true, [Type]::Missing, [Type]::Missing, [Type]::Missing, $true, [Type]::Missing, [Type]::Missing, $false)
                try { $wb.ExportAsFixedFormat(0, $outPdf) } finally { $wb.Close($false) }
            } elseif ($ext -match '\.(pptx|ppt)') {
                if (-not $script:ppt) {
                    $script:ppt = New-Object -ComObject PowerPoint.Application
                    try { $script:ppt.AutomationSecurity = 3 } catch {}
                }
                $pres = $script:ppt.Presentations.Open($f, $true, $false, $false)
                try { $pres.SaveAs($outPdf, 32) } finally { $pres.Close() }
            } elseif ($ext -match '\.(xps|oxps)') {
                Convert-XpsToPdf -OrigemXps $f -DestinoPdf $outPdf
            }
            Write-UiLog "  [OK] Concluido" -cor $cSuccess
            $item.SubItems[2].Text = "Concluido"; $item.ForeColor = $cSuccess; $stats.Ok++
            Write-SafeLog 'OK' ("Concluido: {0}" -f $nomeMascarado)
        } catch {
            Write-UiLog "  [ERRO] $($_.Exception.Message)" -cor $cDanger
            $item.SubItems[2].Text = "Falhou"; $item.ForeColor = $cDanger; $stats.Falha++
            Write-SafeLog 'ERRO' ("{0} :: {1}" -f $nomeMascarado, $_.Exception.Message)
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    if ($script:word) { try { $script:word.Quit() } catch {}; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:word); $script:word = $null }
    if ($script:excel) { try { $script:excel.Quit() } catch {}; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:excel); $script:excel = $null }
    if ($script:ppt) { try { $script:ppt.Quit() } catch {}; [void][Runtime.InteropServices.Marshal]::ReleaseComObject($script:ppt); $script:ppt = $null }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()

    $btnDoConvert.Enabled = $true; $btnDoConvert.Text = "CONVERTER AGORA"; $btnDoConvert.BackColor = $cSuccess
    Write-UiLog "[SISTEMA] Lote finalizado. OK: $($stats.Ok) | Falhas: $($stats.Falha)" -cor $cAccent
    [System.Windows.Forms.MessageBox]::Show("Concluido!`nOK: $($stats.Ok)`nFalhas: $($stats.Falha)")
    Start-Process explorer.exe $script:txtOut.Text
})

$btnAddPdf.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'Arquivos PDF|*.pdf'; $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq 'OK') {
        foreach ($f in $dlg.FileNames) { [void]$script:listViewMerge.Items.Add((New-Object System.Windows.Forms.ListViewItem($f))) }
    }
})
$btnClearPdf.Add_Click({ $script:listViewMerge.Items.Clear() })
$btnUp.Add_Click({ if ($script:listViewMerge.SelectedIndices.Count -gt 0) { $idx = $script:listViewMerge.SelectedIndices[0]; if ($idx -gt 0) { $item = $script:listViewMerge.Items[$idx]; $script:listViewMerge.Items.RemoveAt($idx); $script:listViewMerge.Items.Insert($idx - 1, $item); $script:listViewMerge.Items[$idx - 1].Selected = $true } } })
$btnDown.Add_Click({ if ($script:listViewMerge.SelectedIndices.Count -gt 0) { $idx = $script:listViewMerge.SelectedIndices[0]; if ($idx -lt $script:listViewMerge.Items.Count - 1) { $item = $script:listViewMerge.Items[$idx]; $script:listViewMerge.Items.RemoveAt($idx); $script:listViewMerge.Items.Insert($idx + 1, $item); $script:listViewMerge.Items[$idx + 1].Selected = $true } } })

$btnDoMerge.Add_Click({
    if ($script:listViewMerge.Items.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Adicione PDFs primeiro!"); return }
    $btnDoMerge.Enabled = $false; $btnDoMerge.Text = "MESCLANDO..."; $btnDoMerge.BackColor = $cNeutral
    $outName = $script:txtName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($outName)) { $outName = "PDF_UNICO" }
    $outName = $outName -replace '[\\/:*?"<>|]', '_'
    if ($outName -notmatch '\.pdf$') { $outName += '.pdf' }
    $outPdf = Join-Path $script:txtOut.Text $outName
    $listaPaths = @(); foreach ($item in $script:listViewMerge.Items) { $listaPaths += $item.Text }
    Write-UiLog "[SISTEMA] Mesclando $($listaPaths.Count) arquivos..." -cor $cAccent
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $modo = Merge-Pdfs -ListaPdfs $listaPaths -DestinoPdf $outPdf
        Write-UiLog "  [OK] PDF gerado ($modo)" -cor $cSuccess
        Write-SafeLog 'MERGE' ("OK modo={0} destino={1}" -f $modo, $outName)
        Start-Process explorer.exe "/select,`"$outPdf`""
        [System.Windows.Forms.MessageBox]::Show("Arquivo criado!`n`n$outPdf")
    } catch {
        Write-UiLog "  [ERRO] $($_.Exception.Message)" -cor $cDanger
        Write-SafeLog 'ERRO' ("MERGE :: {0}" -f $_.Exception.Message)
        [System.Windows.Forms.MessageBox]::Show("Falha: $($_.Exception.Message)")
    }
    $btnDoMerge.Enabled = $true; $btnDoMerge.Text = "MESCLAR AGORA"; $btnDoMerge.BackColor = $cAccent
})

Write-UiLog "=========================================" -cor $cAccent
Write-UiLog "  PDF MASTER PRO - Iniciado (hardened)" -cor $cPrimary
if (Test-PdfSharpIntegrity) { Write-UiLog "  PdfSharp: integro" -cor $cSuccess } else { Write-UiLog "  PdfSharp: ausente/invalido -> rasterizado" -cor $cTextSub }
Write-UiLog "=========================================" -cor $cAccent

[void]$form.ShowDialog()
'@

Set-Content -LiteralPath $Ps1Gui -Value $conteudoGui -Encoding UTF8

$erros = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($Ps1Gui, [ref]$null, [ref]$erros)
if ($erros -and $erros.Count -gt 0) {
    Write-Host "  [ERRO] Sintaxe invalida:" -ForegroundColor Red
    $erros | ForEach-Object { Write-Host "    $($_.Message)" -ForegroundColor Red }
    return
}
Write-Host "  [ OK ] Sintaxe validada." -ForegroundColor Green

# ============================================================
# 3) LAUNCHER
# ============================================================
$batConteudo = @"
@echo off
title PDF Master Pro - Enterprise
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Conversor-GUI.ps1" %*
exit
"@
Set-Content -LiteralPath $Bat -Value $batConteudo -Encoding OEM

# ============================================================
# 4) ATALHOS
# ============================================================
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

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  |      ***  INSTALACAO SEGURA CONCLUIDA!  ***                  |" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  Correcoes de seguranca aplicadas:" -ForegroundColor Cyan
Write-Host "    - Verificacao SHA256 do PdfSharp.dll (TOFU)" -ForegroundColor DarkGray
Write-Host "    - Forcado TLS 1.2+ e validacao de redirect" -ForegroundColor DarkGray
Write-Host "    - Bloqueio de macros (Word/Excel/PPT)" -ForegroundColor DarkGray
Write-Host "    - Excel UpdateLinks=0 (sem DDE)" -ForegroundColor DarkGray
Write-Host "    - Word com abertura segura (sem PV dialog)" -ForegroundColor DarkGray
Write-Host "    - Mutex na troca de impressora padrao" -ForegroundColor DarkGray
Write-Host "    - Log mascarado (LGPD)" -ForegroundColor DarkGray
Write-Host ""
$r = Read-Host "  Abrir o programa agora? (S/N)"
if ($r -match '^[SsYy]') { Start-Process $Bat }
