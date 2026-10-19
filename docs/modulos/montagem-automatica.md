# Montagem automática (fase 1)

Como o NTFS Oficial monta um disco NTFS sozinho, para leitura e gravação, quando ele é plugado.
Funcionando desde 17/10/2026 (teste com imagem de disco: `scripts/testar-automatico.sh`).

## O caminho, passo a passo

```
plugar o disco
  └─ DiskArbitration (diskarbitrationd, root)
       ├─ ntfsoficial.util -p disk4s1 removable readonly      (root)   detecção
       │    assinatura "NTFS    " → ntfs-3g.probe (0, 14 ou 15) → arquivo de controle → escreve o rótulo → 255
       ├─ ntfsoficial.util -k disk4s1                         (root)   UUID: não tem (254)
       ├─ ntfsoficial.util -q disk4s1                         (root)   verificação rápida: 0 sem checar, como o Tuxera
       │                                                                (o macOS chama porque o Info.plist declara verificar)
       └─ mount → mount_ntfsoficial -o nodev -o noowners -o nosuid /dev/disk4s1 "/Volumes/<rótulo>"
                  (uid do usuário, SÓ com o grupo principal 20)
            ├─ ntfs-3g.probe --readwrite: sujo (15) ou cache do Windows (14 sem hiberfil.sys)?
            │    → Support/ntfsrecover (replay do journal, até 60 s) → probe de novo tem que dar 0
            │    hibernado de verdade, replay que falha ou EnableAutomaticRecovery = 0 → só leitura + aviso
            └─ Support/ntfsoficial (driver lowntfs-3g) com as opções do Tuxera (sempre norecover)
                 └─ libfuse → Support/mount_ntfsoficial → mount("ntfsoficial") no kext
            └─ espera o statfs mostrar "ntfsoficial" no ponto (até 15 s) → responde ao macOS
```

| Peça | Arquivo | O que faz |
|---|---|---|
| Registro no macOS | `Contents/Info.plist` (gerado por `scripts/montar-pacote.sh`) | `FSMediaTypes` para `Windows_NTFS`, GPT `EBD0A0A2-…` e `Windows_LDM` (ordem 400), tipos FAT (1900: só o que o FAT da Apple, em 1000, recusou) e disco inteiro (3400); antes do Tuxera (440/1940) e da Apple (1000). Personalidade com verificar (`-v`), reparar (`-r`) e formatar (`newfs_ntfsoficial`), para o Utilitário de Disco |
| Detecção | `ferramentas/ntfsoficial_util/detectar.c` | 0, 14 ou 15 do `ntfs-3g.probe` reconhece, como o Tuxera; 13 (corrompido) e o resto ficam para o NTFS só leitura da Apple |
| Montagem | `ferramentas/ntfsoficial_util/montar.c` | opções: `local`, `iosize=1048576`, `uid=99,gid=99` (o kernel mostra 99 como quem está olhando, como o `adaptiveuid` do Tuxera; se o macOS mandar `uid=`/`gid=`, valem os dele), `sfmconv` (ou `nosfmconv,windows_names`), `nfconv`, xattr, sempre `norecover`, `volname`; disco sujo passa antes pelo replay; o que não puder gravar → só leitura + aviso |
| Replay do journal | `ferramentas/ntfsoficial_util/recuperar.c` | classifica pelo `ntfs-3g.probe --readwrite` e roda o `ntfsrecover` (seção abaixo) |
| Utilitário de Disco | `ferramentas/ntfsoficial_util/utilitario.c` | `-v`/`-q` verificar, `-r`/`-y` reparar, `newfs_ntfsoficial [-v rótulo] <disco>` formatar (argumentos e códigos do Tuxera) |
| Rodar o driver | `ferramentas/ntfsoficial_util/executar.c` | saída em arquivo temporário (não pipe), entrada `/dev/null`; `executar_limite` mata o processo no tempo limite |
| Preferências | `ferramentas/ntfsoficial_util/preferencias.c` | `/Library/Preferences/com.danielmanske.ntfsoficial.plist`, mesmas chaves do Tuxera (`EnableAutomaticRecovery` e `EnableSFMConversions` com padrão 1, como ele) |
| Controle por disco | `ferramentas/ntfsoficial_util/controle.c` | `/.NTFS-Oficial/` ou `/.Tuxera-NTFS/` `disable-driver`, `disable-normalization`, `disable-caching` |
| Log | `ferramentas/ntfsoficial_util/registro.c` | `/usr/bin/log show --predicate 'subsystem == "com.danielmanske.ntfsoficial"'` (no zsh, `log` sozinho é outro comando) |
| Desmontar ao desligar | `pacote/desmontar-ao-desligar.sh` + LaunchDaemon `com.danielmanske.ntfsoficial.desmontar` | no SIGTERM: `sync`, desmonta pelo dispositivo (normal, depois forçado) e repete até 25 s, como o `tuxera_ntfs_daemon`; `--agora` testa sem desligar |

## Disco que o Windows deixou sujo (18/10/2026)

Disco tirado do Windows sem "remover com segurança", ou com o Windows desligado no meio, fica com transações
confirmadas no `$LogFile` que não chegaram aos metadados. O Tuxera reaplica essas transações e monta com gravação
(REA, `docs/design/REFERENCIA_TUXERA.md` seção 14). Aqui:

| Probe `--readwrite` | O que é | O que o util faz |
|---|---|---|
| 0 | limpo | monta com gravação |
| 0, mas com a marca do chkdsk (`VOLUME_IS_DIRTY`) e journal limpo | o Windows marcou o disco para conferir | monta com gravação, como o Tuxera; a marca fica até um chkdsk no Windows |
| 15 | journal sujo | `ntfsrecover` (replay; termina gravando o journal como limpo, versão 1.1) → probe tem que dar 0 → monta com gravação |
| 14, mensagem "hibernated" | Windows hibernado (`hiberfil.sys`) | só leitura; nunca mexe no journal |
| 14, sem "hibernated" | journal 2.0, "Metadata kept in Windows cache" (inicialização rápida, ou disco arrancado do Windows 8+) | tenta o `ntfsrecover`, que recusa ("Fast restart mode detected") sem `-k`; fica só leitura. O `-k` jogaria fora o cache do Windows e não é usado |
| replay falha, ou `EnableAutomaticRecovery = 0` | — | só leitura + aviso (motivo gravado para o app) |

- A marca `VOLUME_IS_DIRTY` (19/10/2026, decisão do Daniel): a libntfs-3g ignora de propósito (`ntfsprogs/utils.c:271-278`),
  e o Tuxera também monta com gravação e não mexe na marca ao montar. O **Reparar não tira a marca** (decisão de 18/10/2026):
  o Tuxera só tira depois do `ntfsck` completo dele, que não temos; e o `ntfsfix -d` também apagaria as flags
  `0x0100`/`0x0200` (máscara `0xc03f` do NTFS-3G), que nem sabemos o que são. Evidência:
  `planos/KEXT_SO_CARREGA_NO_MACOS_27_2026-10-19.md`. Para ver as flags de um disco: `scripts/diagnostico/verificar_disco.c`.
- A opção `recover` do NTFS-3G só **zera** o journal (descarta as transações). Nunca é passada; o driver recebe
  sempre `norecover`.
- O `ntfsrecover` entrou em laço infinito com um journal de teste estranho; por isso o limite de 60 s.
- Teste: `scripts/testar-casos-especiais.sh` (hibernado, sujo com journal estragado, cache do Windows, sujo
  recuperável e arquivo de controle). O sujo recuperável é criado por `scripts/criar-journal-sujo.py` (páginas de
  reinício abertas e um `LOG_CHECKPOINT` válido); não há como gerar aqui as transações de um Windows de verdade.

## Problemas encontrados no caminho (e a evidência)

| Sintoma | Causa | Correção |
|---|---|---|
| O macOS montou com o NTFS da Apple (só leitura, `fskit`) e não chamou o nosso detector | O DiskArbitration guarda a lista de pacotes na memória; o nosso estava instalado desde a fase 0 sem `FSMediaTypes` | Reiniciar só o DiskArbitration (`sudo launchctl kickstart -k system/com.apple.diskarbitrationd`). Numa instalação nova, ou depois de reiniciar o Mac, não precisa |
| Driver recusou: "Unprivileged user can not mount NTFS block devices" (código 19) | A montagem pelo Finder roda como o usuário; essa recusa é do fuseblk do Linux | `driver/patches/0001` desliga no macOS. O driver do Tuxera também não tem (REA) |
| Driver "Mounted" e logo "Unmounting"; despachante travava quando chamado à mão | A saída do driver ia por pipe e o daemon do FUSE herdava o pipe; o despachante respondia antes da montagem terminar | Saída em arquivo temporário e espera pelo `statfs`, como o `tuxera_ntfs_wait` faz com a notificação "mounted" (REA) |
| `mount_ntfsoficial: failed to mount /Volumes/…: Operation not permitted` | Processo lançado pelo macOS tem só o grupo 20 (log: `grupos 20`), sem o admin (80); o kext nega `allow_other` (`fuse_vfsops.c:284`) | `tunables.allow_other=1`: no `load_ntfsoficial` (`kext/patches/0004`) e no `instalar.sh` |
| Mesmo erro antes disso | `tunables.admin_group` = 0 porque o kext foi carregado direto pelo `kmutil` | `instalar.sh` carrega pelo `load_ntfsoficial` e grava o grupo admin, como o `load_tuxera_ntfs` (REA) |

## Instalar, testar, desfazer

```bash
bash scripts/compilar.sh          # compila tudo em build/out
bash scripts/instalar.sh          # instala (sudo); mantém o kext já aprovado se o novo for diferente
bash scripts/testar-automatico.sh # imagem GPT + NTFS, anexa como HD plugado, grava, ejeta, confere
bash scripts/desinstalar.sh       # remove tudo e religa o Tuxera
```
