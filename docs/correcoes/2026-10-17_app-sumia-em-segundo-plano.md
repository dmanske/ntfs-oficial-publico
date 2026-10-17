# App sumia em segundo plano (janelas e alertas escondidos)

17/10/2026 — corrigido na versão 0.1.1.

## Sintoma

Depois da janela de senha do macOS (Verificar, Reparar, Aplicar alterações), o Gerenciador ou os Ajustes sumiam e
a mensagem final não aparecia. Depois do reinício, aconteceu também **sem senha**: bastava o app ir para segundo
plano.

## Evidência

- Janela do app fora da tela: `CGWindowListCopyWindowInfo` → `Ajustes de NTFS Oficial onscreen: nao`.
  (O `visible` do System Events não serve para medir: em app de barra de menus ele é sempre `false`.)
- Log do app no momento: `AppKit:AutomaticTermination … _NSEnableAutomaticTerminationAndLog` e
  `Setting _kLSApplicationWouldBeTerminatedByTALKey=1` — o macOS marcava o app como "pode ser encerrado
  automaticamente" e, nesse estado, escondia as janelas.
- Teste igual nas duas versões (abrir Ajustes, pôr o Finder na frente, medir a cada 10 s):

  | Versão | 10 s | 20 s | 30 s |
  |---|---|---|---|
  | 0.1.0 (antes) | na tela | **fora** | **fora** |
  | 0.1.1 (depois) | na tela | na tela | na tela |

## Causa

O SwiftUI liga o *encerramento automático* do macOS por padrão. Para app comum isso economiza memória; para app de
barra de menus é errado: o sistema esconde (e pode até fechar) o app quando ele não está na frente, levando o
ícone da barra junto.

## Correção

- `App/NTFSOficialApp.swift`: ao abrir, `ProcessInfo.processInfo.disableAutomaticTermination(...)` e
  `disableSuddenTermination()`.
- `scripts/montar-app.sh`: `Info.plist` com `NSSupportsAutomaticTermination` e `NSSupportsSuddenTermination` = `false`.
- Reforço que já tinha entrado antes (`Features/Avisos/Alertas.swift`): `NSApp.unhide(nil)` antes de cada alerta.

Reverter: tirar essas linhas; o sintoma volta em ~20 s de segundo plano.
