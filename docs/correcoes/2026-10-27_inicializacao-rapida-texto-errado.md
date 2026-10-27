# Correção: disco com a Inicialização Rápida do Windows aparecia como "desconectado sem ejetar" (27/10/2026)

Versão 0.2.3. O kext continua 0.1.2: não precisa aprovar nem reiniciar. Conferência completa do Tuxera:
[../planos/CONFERENCIA_TUXERA_INICIALIZACAO_RAPIDA_2026-10-27.md](../planos/CONFERENCIA_TUXERA_INICIALIZACAO_RAPIDA_2026-10-27.md).

## Sintoma

No Hackintosh (26 e 27/10/2026, app 0.2.2, kext 0.1.2), depois de usar **Desligar** no Windows com a Inicialização
Rápida ligada, os 3 discos NTFS montaram só leitura (certo), mas o app mostrou "Só leitura — desconectado sem ejetar"
(errado). Log do `ntfsoficial.util`:

```
montar /dev/disk2s2: probe = 14 (cache do Windows)
recuperar /dev/disk2s2: ntfsrecover = 1
  ** Fast restart mode detected, data could be lost … --kill-fast-restart to bypass
montar /dev/disk2s2 em /Volumes/DADOS 1 1TB: montado só para leitura (disco sujo)
```

Achado à parte: o rodapé e os Ajustes mostravam "0.1.1" com o app na 0.2.2.

## Causa

1. O util classificou certo (journal `$LogFile` versão 2.0 = "cache do Windows"), mas o arquivo de motivo
   `/private/var/tmp/ntfsoficial/<disco>.motivo` só aceitava "hibernado" ou "sujo" (`gravar_motivo` em
   `ferramentas/ntfsoficial_util/montar.c`), e gravou "sujo". O app só conhecia esses dois
   (`MotivoSoLeitura` em `app/Sources/NTFSOficialMotor/Discos/Disco.swift`) e mostrou o texto de "sujo".
2. Nesse caso o util rodava o `ntfsrecover` toda vez, sabendo que ele recusa o 2.0 sem `-k`, e registrava erro
   ("ntfsrecover = 1").
3. O texto certo (`verCacheWindows`) só aparecia no resultado do **Verificar**, não no selo do disco.
4. `Config.versao` (`app/Sources/NTFSOficial/Shared/Config.swift`) era fixa; o `Info.plist` do app instalado dizia 0.2.2.

## O que o Tuxera faz

Reaplica o journal 2.0 (replay próprio, `ntfs_jnl_play`) e monta com gravação, sem avisar. Resumo, endereços e a conta
estão na [conferência](../planos/CONFERENCIA_TUXERA_INICIALIZACAO_RAPIDA_2026-10-27.md).

**Decisão (27/10/2026, recomendação da conferência, seguida na correção que o Daniel pediu): aqui continua só leitura.** Em dual boot, o Windows retoma com os metadados antigos e
pode ignorar ou sobrescrever o que o Mac gravou. O custo de ficar só leitura é usar Reiniciar no Windows.

## Correção

- `montar.c`: motivo novo `MOTIVO_CACHE_WINDOWS`. No journal 2.0 (`SUJEIRA_CACHE_WINDOWS`) monta direto só leitura,
  **sem rodar o `ntfsrecover`**, e grava `cache-windows`. Contrato do arquivo: `hibernado`, `cache-windows` ou `sujo`
  (sem arquivo = montou com gravação). Quando o driver cai para só leitura sozinho, ou sai com 14, a saída "Metadata
  kept in Windows cache" também vira `cache-windows` (`motivo_pela_saida`, `nome_do_motivo`).
- Aviso do util: "O Windows foi desligado com a Inicialização rápida…", com o que fazer: no Windows, usar Reiniciar (não
  Desligar) para vir ao Mac, ou desligar a Inicialização rápida (`powercfg /h off`, Prompt de Comando como
  administrador) e usar Desligar. O aviso de "recuperação falhou" não fala mais do cache.
- App: `MotivoSoLeitura.cacheWindows` (`cache-windows`); selo "Só leitura — Inicialização rápida do Windows" (inglês:
  "Windows Fast Startup"); linha de explicação embaixo do selo no detalhe do disco (`DetalheDoDiscoView.swift`,
  `.callout`, cor secundária) com o texto do Verificar para hibernado, Inicialização rápida e sujo
  (`Formatacao.explicacao`); `verCacheWindows` revisado para mandar usar Reiniciar ou `powercfg /h off`.
- `Config.versao` lê o `CFBundleShortVersionString` do Info.plist (gravado pelo `scripts/montar-app.sh` com a `VERSAO`
  de `scripts/config.sh`); "dev" no `swift run`.
- `scripts/testar-casos-especiais.sh` confere também o arquivo de motivo: hibernado → `hibernado`, sujo → `sujo`,
  cache → `cache-windows`.

## Como foi conferido

Em 27/10/2026, no Mac principal (chip Apple, macOS 27, kext 0.1.2 carregado), sem instalar (sem `sudo` na sessão):

- `swift test` do app: 19 testes, 0 falhas (1 pulado, já era); `testLerMotivo` lê `cache-windows` → `.cacheWindows`.
  `swift build -c release` sem avisos.
- Util novo (`build/out/bin/ntfsoficial.util` chamado como `mount_ntfsoficial`, com o driver, o probe e o `ntfsrecover`
  instalados, que não mudaram) em imagens de 100 MB anexadas sem montar, criadas como no `testar-casos-especiais.sh`:

  | Imagem | Log do util | Grava? | Arquivo de motivo |
  |---|---|---|---|
  | journal 2.0 (`criar-journal-sujo.py … 2.0`) | `probe = 14 (cache do Windows)`, **sem** linha do `ntfsrecover`, `montado só para leitura (cache-windows)` | não (Read-only file system) | `cache-windows` |
  | `hiberfil.sys` com "hibr" | `probe = 14 (hibernado)`, `montado só para leitura (hibernado)` | não | `hibernado` |
  | journal 1.1 sujo recuperável | `probe = 15`, `ntfsrecover = 0`, `journal do Windows reaplicado` | sim | sem arquivo |

- Pacote `NTFS-Oficial-0.2.3.pkg` aberto com `pkgutil --expand-full`: mesmos 37 arquivos da 0.2.2; o util tem
  "cache-windows", o app diz 0.2.3 no `Info.plist` e não tem mais "0.1.1" no binário; kext 0.1.2.

Não conferido aqui: o `testar-casos-especiais.sh` completo (precisa do pacote instalado), a tela do app com o selo e a
explicação novos, e o caso real do Hackintosh (Desligar no Windows com a Inicialização Rápida → selo certo; Reiniciar →
discos com gravação).

## Como reverter

Voltar `montar.c`, `Disco.swift`, `DetalheDoDiscoView.swift`, `Formatacao.swift`, `Texto.swift`, `Config.swift` e o
`testar-casos-especiais.sh` ao commit anterior à 0.2.3 (`git revert`). Volta o texto errado "desconectado sem ejetar"
e o `ntfsrecover` rodando à toa. Para gravar nesses discos sem mudar o código, não há atalho seguro: use Reiniciar no
Windows.
