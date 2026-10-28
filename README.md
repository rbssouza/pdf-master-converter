# PDF Master Pro - Conversor e Mesclador de Documentos Seguro

Aplicação completa em PowerShell para conversão em lote (Office, XPS para PDF) e mesclagem de PDFs, com interface gráfica customizada (WinForms Dark Mode) e instalador automático.

## Problema
No dia a dia de suporte e infraestrutura, usuários frequentemente precisam converter dezenas de documentos do Office (Word, Excel, PowerPoint) para PDF e uni-los em um único arquivo. Fazer isso manualmente é lento e softwares de terceiros são caros, além de representarem um risco de segurança (execução de macros, links DDE externos).

## Solução
Um instalador em PowerShell que monta um ambiente completo no computador do usuário, criando um atalho na área de trabalho para uma ferramenta visual (GUI) de conversão e mesclagem, com foco em Hardening (Segurança).

### Destaques Técnicos e Segurança

1. **Interface Customizada (WinForms):** UI moderna em "Dark Mode", com design responsivo e arrastar-e-soltar (drag and drop).
2. **Instalador Automático com Verificação de Integridade (TOFU):** O script faz o download de dependências (PdfSharp) diretamente do NuGet, salvando o hash SHA256. Nas próximas execuções, ele verifica se o DLL foi adulterado.
3. **Proteção Anti-Downgrade (TLS):** Força o uso de TLS 1.2+ e valida redirecionamentos HTTP para evitar interceptação de tráfego (MITM) durante o download.
4. **Automação COM do Office Segura:** Bloqueio de execução de macros (AutomationSecurity = 3), prevenção de DDE no Excel (UpdateLinks=0) e abertura segura do Word.
5. **Fallback via Win32 API:** Uso de user32.dll com um Mutex Global para interagir programaticamente com a janela "Microsoft Print to PDF".
6. **Log Mascarado:** O sistema de logs oculta os caminhos completos dos arquivos, em conformidade com a LGPD.

## Funcionalidades
- Conversão de Word, Excel, PowerPoint, RTF, CSV e XPS para PDF.
- Mesclagem de múltiplos PDFs em um único arquivo, com opção de reordenar as páginas.
- Criação automática de atalhos no Desktop e Menu Iniciar.
- Interface visual amigável para usuários finais.

## Como usar
O script requer privilégios de Administrador para rodar o instalador inicial.

```powershell
# Executar o instalador
.\Instalador-PDF.ps1
