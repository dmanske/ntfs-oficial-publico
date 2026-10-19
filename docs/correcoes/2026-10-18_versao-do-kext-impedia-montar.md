# Correção: nenhum disco montava depois de instalar a 0.1.1 (18/10/2026)

## Sintoma

Toda montagem falhava, pelo Finder e rodando o driver à mão. No log (`subsystem == "com.danielmanske.ntfsoficial"`):

```
montar /dev/disk4s1 em /Volumes/TESTE MODOS falhou (código 21): mount_ntfsoficial: the loaded NTFSOficial
kernel extension has a mismatched version
```

Achado em 18/10/2026, ao montar uma imagem para medir velocidade. A 0.1.1 foi instalada em 17/10/2026 às 20:09
(data dos arquivos em `/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/`); desde então, nada montava.

## Causa

| Peça | Versão |
|---|---|
| Kext carregado (o aprovado em 17/10) | 0.1.0 (`sysctl vfs.generic.ntfsoficial.version.number`) |
| `Support/mount_ntfsoficial` e `load_ntfsoficial` instalados | 0.1.1 |

- O commit `db06593` subiu a `VERSAO` de `scripts/config.sh` para 0.1.1, e ela entrava em tudo, inclusive no kext
  (`OSXFUSE_VERSION_LITERAL`, via `scripts/preparar-fontes.sh` e `scripts/compilar-kext.sh`).
- O kext novo ficou diferente do aprovado, e o `instalar.sh` manteve o aprovado (certo: kext novo exige aprovar e
  reiniciar).
- O `mount_ntfsoficial` confere a versão do kext carregado com a dele e recusa se for diferente
  (`check_kext_status`, `mount_osxfuse.c:668-678`; o `load_ntfsoficial` faz o mesmo).

## O que o Tuxera faz (REA)

O `mount_tuxera_ntfs` do Tuxera 2027.0.1 tem a mesma conferência ("the loaded Tuxera NTFS kernel extension has a
mismatched version", `0x1000030fb`), mas contra a versão do **kext**, `2023.5.23` (`0x100003ee1`; também no
`load_tuxera_ntfs` e no `sysctl tuxera_ntfs.version.number`), e não contra a do pacote (2027.0.1). Ou seja, lá a versão
do kext já é separada da do produto.

## Correção

- `scripts/config.sh`: versão própria do kext, `VERSAO_KEXT="0.1.0"`, separada da `VERSAO` do pacote e do app. Só muda
  quando o código do kext mudar (no mesmo dia foi para 0.1.1, com o `kext/patches/0005-renomear-volume.patch`).
- `scripts/preparar-fontes.sh` (`OSXFUSE_VERSION_LITERAL`) e `scripts/compilar-kext.sh` (`OSXFUSE_VERSION`) usam a
  `VERSAO_KEXT`. O kext, a libfuse e o `load_`/`mount_ntfsoficial` passam a ter sempre a mesma versão.
- Para devolver a montagem sem reinstalar tudo: `build/corrigir-versao.command` troca só os dois auxiliares instalados
  pelos compilados com a 0.1.0 (sem mexer no kext).

## Verificação

- `strings` nos auxiliares compilados: 0.1.0 (arm64 e x86_64), igual ao `sysctl` do kext carregado.
- Montagem depois de trocar os auxiliares: ver `docs/planos/PENDENCIAS.md`.

## Como reverter

Voltar `${VERSAO_KEXT}` para `${VERSAO}` em `scripts/preparar-fontes.sh` e `scripts/compilar-kext.sh` (volta o
problema sempre que a `VERSAO` mudar sem trocar o kext aprovado).
