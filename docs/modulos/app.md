# App NTFS Oficial (fase 2)

App de barra de menus em SwiftUI (macOS 14+), sem ícone no Dock. Desenho aprovado em
[`design/DESIGN_FASE2_APP.md`](../design/DESIGN_FASE2_APP.md). O app **não mexe no driver**: lista discos, chama ações
e mostra estado. Versão 0.1.0 (`app/Sources/NTFSOficial/Shared/Config.swift`).

## Estrutura (`app/`, pacote Swift sem dependências externas)

| Alvo | O que tem |
|---|---|
| `NTFSOficialMotor` (sem SwiftUI, testável) | `Discos/` (DiskArbitration: `MonitorDeDiscos`, `Disco`, montar/desmontar/ejetar com "forçar"), `Ferramentas/` (`Administrador`, `CaminhosDriver`, `OperacoesDeDisco` = verificar/reparar/formatar, `ValidacaoNome`, `InterpretacaoProbe`), `Preferencias/` (plist do driver), `Conflitos/` (outros drivers NTFS) |
| `NTFSOficial` (app) | `App/` (entrada, `EstadoApp`, `--listar`), `Features/Menu`, `Discos`, `Formatar`, `Preferencias`, `Avisos` (alertas NSAlert), `Shared/Config.swift`, `Shared/Texto.swift` (pt-BR e inglês em código) |
| `NTFSOficialMotorTests` | 18 testes (identificador de disco válido incluído): nome de volume (3 formatos), escape do comando de administrador, preferências (plist de teste), conflitos (pasta temporária), códigos do probe, arquivo de motivo, classificação NTFS; um teste com imagem de disco (opcional) |

## Como funciona

- **Lista de discos:** `MonitorDeDiscos` registra os callbacks do DiskArbitration na run loop principal e publica `[Disco]`.
  Entra se o tipo for `ntfsoficial`/`ntfs`; não montado só se o conteúdo for `Windows_NTFS` (o GUID `EBD0A0A2…` é de
  exFAT/FAT também, então sozinho não basta). Espaço e só leitura vêm do `statfs`. O motivo do só leitura vem de
  `/private/var/tmp/ntfsoficial/<disco>.motivo` (escrito pelo despachante de montagem); só leitura com tipo `ntfs`
  (Apple) = "outro driver". A lista é relida a cada 15 s (`Config.intervaloAtualizacao`) para atualizar o espaço livre.
- **Montar/desmontar/ejetar:** DiskArbitration, sem senha. Se falhar, o alerta mostra o texto do dissenter e oferece
  "Forçar" (botão vermelho).
- **Verificar:** desmonta, roda como administrador `ntfs-3g.probe --readwrite` + `ntfsrecover -n` (só se o probe disser
  sujo) + `ntfsfix -n`, interpreta (0 limpo, 14 hibernado ou cache do Windows, 15 sujo, outro = erro), remonta. Não
  altera o disco.
- **Reparar:** pede confirmação, desmonta, `ntfsrecover` (reaplica o journal do Windows) e, se ele der certo ou o
  journal não estava sujo, `ntfsfix`; remonta. Hibernado: recusa sem alterar nada. Desde 18/10/2026 **sem** o
  `ntfsfix -d`: o `ntfsfix` marca o volume para o `chkdsk` do Windows, e limpar essa marca escondia o problema (o
  driver não precisa dela para montar). O `ntfsrecover` tem limite de 60 s (`alarm 60`), porque pode entrar em laço
  com um journal estranho. Não é um `chkdsk`; para dano sério, o alerta manda usar `chkdsk /f` no Windows.
- **Formatar:** NTFS com o nosso `mkntfs -Q -F -L` (administrador); exFAT e FAT32 com `diskutil eraseVolume` (sem
  administrador, e o próprio `diskutil` desmonta/remonta). A folha exige marcar a caixa e nome válido.
- **Administrador:** `NSAppleScript` com `do shell script … with administrator privileges` (senha padrão do macOS, sem
  serviço fixo). Roda na thread principal, então a janela do app fica parada enquanto a senha está aberta.
- **Preferências do driver:** lê `/Library/Preferences/com.danielmanske.ntfsoficial.plist` (sem o arquivo: padrões);
  "Aplicar" grava todas as chaves num `defaults write … && …` só (uma senha). Valem para o próximo disco montado.
  Desde 18/10/2026: recuperação automática com padrão ligado (reaplica o journal do Windows) e o ajuste de nomes
  estilo SFM (`EnableSFMConversions`, ver `docs/modulos/metadados-e-nomes.md`).
- **Avisos:** ao abrir e quando a lista muda, `Conflitos.detectar()` procura Tuxera, Paragon e macFUSE+ntfs-3g; o alerta
  sai uma vez por sessão.
- **Telas (redesenho de 17/10/2026, telas-alvo em `identidade/telas/`):** Gerenciador com lateral (símbolo + nome,
  "Dispositivos", atalho para Ajustes) e detalhe em cartões (`Features/Discos/components/`: armazenamento, detalhes
  técnicos recolhíveis, manutenção com "Outras ações" = desmontar/formatar). Ajustes com lateral que rola até o cartão
  (`Features/Preferencias/components/`) e rodapé Cancelar/Aplicar alterações. A janela de Ajustes fica viva entre
  aberturas (o `onAppear` não roda de novo); ao fechar, ela volta ao topo e descarta o que não foi aplicado.
- **Ícones:** `montar-app.sh` copia de `identidade/` para `Contents/Resources` o `AppIcon.icns` (`CFBundleIconFile`),
  `BarraTemplate.png`/`@2x` (barra de menus, imagem template; com disco só leitura, `IconeBarra` desenha um "!" no
  canto) e `simbolo-colorido.png`. Sem os arquivos (`swift run`), cai para os SF Symbols.
- **Idioma:** `Texto.t(.chave)`; cada idioma é um `switch` exaustivo (faltou tradução = erro de compilação). Escolha em
  `UserDefaults` ("idioma"). O título da janela do Gerenciador só muda de idioma ao reabrir o app (o do conteúdo muda na hora).

## Comandos

```bash
cd app && swift build            # compila
cd app && swift test             # testes (18; 1 pula sem imagem)
NTFS_OFICIAL_TESTE_IMAGEM=<imagem em build/teste/> swift test   # inclui o teste com disco anexado
bash scripts/montar-app.sh       # release + build/out/NTFS Oficial.app (Info.plist, assinatura ad-hoc)
build/out/NTFS\ Oficial.app/Contents/MacOS/NTFSOficial --listar  # diagnóstico: imprime os discos NTFS e sai
```

## Limites

- Fluxos que pedem senha (verificar, reparar, formatar NTFS, aplicar preferências) e a interface gráfica não foram
  exercitados em teste automático: só o código e os comandos montados (testes puros).
- Disco NTFS **não montado** em partição GPT só aparece se o macOS informar `Windows_NTFS`; partição GPT com o GUID
  genérico fica fora (pode ser exFAT).
- "Abrir ao iniciar a sessão" usa `SMAppService.mainApp`, que exige o app instalado em `/Applications` (o instalador copia).
- O ícone da barra com aviso ("!") e o modo escuro não foram conferidos na tela.
- Não há atualizador, licença nem "Relatar problema" (fora de escopo).
