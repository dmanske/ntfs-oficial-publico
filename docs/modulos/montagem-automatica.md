# Montagem automática (fase 1)

Como o NTFS Oficial monta um disco NTFS sozinho, para leitura e gravação, quando ele é plugado.
Funcionando desde 17/10/2026 (teste com imagem de disco: `scripts/testar-automatico.sh`).

## O caminho, passo a passo

```
plugar o disco
  └─ DiskArbitration (diskarbitrationd, root)
       ├─ ntfsoficial.util -p disk4s1 removable readonly      (root)   detecção
       │    assinatura "NTFS    " → ntfs-3g.probe → arquivo de controle → escreve o rótulo → 255
       ├─ ntfsoficial.util -k disk4s1                         (root)   UUID: não tem (254)
       └─ mount → mount_ntfsoficial -o nodev -o noowners -o nosuid /dev/disk4s1 "/Volumes/<rótulo>"
                  (uid do usuário, SÓ com o grupo principal 20)
            └─ Support/ntfsoficial (driver lowntfs-3g) com as opções do Tuxera
                 └─ libfuse → Support/mount_ntfsoficial → mount("ntfsoficial") no kext
            └─ espera o statfs mostrar "ntfsoficial" no ponto (até 10 s) → responde ao macOS
```

| Peça | Arquivo | O que faz |
|---|---|---|
| Registro no macOS | `Contents/Info.plist` (gerado por `scripts/montar-pacote.sh`) | `FSMediaTypes` para `Windows_NTFS`, GPT `EBD0A0A2-…` (ordem 400) e disco inteiro (3400): antes do Tuxera (440) e da Apple (1000) |
| Detecção | `ferramentas/ntfsoficial_util/detectar.c` | 0 ou 14 do `ntfs-3g.probe` reconhece; resto (inclusive 15) fica para o NTFS só leitura da Apple |
| Montagem | `ferramentas/ntfsoficial_util/montar.c` | opções: `local`, `iosize=1048576`, `uid/gid`, `windows_names`, `nfconv`, xattr, `recover`/`norecover`, `volname`; 14/15 → só leitura + aviso |
| Rodar o driver | `ferramentas/ntfsoficial_util/executar.c` | saída em arquivo temporário (não pipe), entrada `/dev/null` |
| Preferências | `ferramentas/ntfsoficial_util/preferencias.c` | `/Library/Preferences/com.danielmanske.ntfsoficial.plist`, mesmas chaves do Tuxera |
| Controle por disco | `ferramentas/ntfsoficial_util/controle.c` | `/.NTFS-Oficial/` ou `/.Tuxera-NTFS/` `disable-driver`, `disable-normalization` |
| Log | `ferramentas/ntfsoficial_util/registro.c` | `/usr/bin/log show --predicate 'subsystem == "com.danielmanske.ntfsoficial"'` (no zsh, `log` sozinho é outro comando) |
| Desmontar ao desligar | `pacote/desmontar-ao-desligar.sh` + LaunchDaemon `com.danielmanske.ntfsoficial.desmontar` | no SIGTERM do desligamento, desmonta os volumes `ntfsoficial` |

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
