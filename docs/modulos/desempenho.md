# Desempenho

Como o NTFS Oficial chega à velocidade atual e por quê. Medido em 17/10/2026 no SSD Kingston SA400 (USB,
"Filmes") com `bash scripts/medir-velocidade.sh /Volumes/Filmes 2048` (arquivo aleatório de 2 GB, `cp` + `sync`;
leitura depois de desmontar e montar; hash conferido).

| Etapa | Gravação | Leitura |
|---|---|---|
| Início (dispositivo de bloco, síncrono, `f_iosize` 16 KB) | 21,1 MB/s | 92,8 MB/s |
| + assíncrono (`nosyncwrites`) | 21,3 | 91,4 |
| + dispositivo raw com E/S alinhada | 9,7 | 256,1 |
| **+ `f_iosize` de 1 MiB (atual, raw)** | **202,4** | **267,4** |
| mesmo com dispositivo de bloco | 46,4 | 88,6 |
| limite do SSD (leitura direta do `/dev/rdisk`) | — | 326 |

## As três peças

1. **Dispositivo raw** (`EnableRawDevices = 1`, padrão; o Tuxera faz o mesmo). O despachante troca `/dev/diskN` por
   `/dev/rdiskN` (`ferramentas/ntfsoficial_util/montar.c`). O raw só aceita E/S em múltiplos do setor; o patch
   `driver/patches/0002` faz ler-modificar-gravar nos pedidos desalinhados, como o `aligned_io.c` do Tuxera
   ("High Performance NTFS Driver [built with USE_CBCIO USE_ALIGNED_IO USE_LOCK]", REA). O patch `0005` informa
   `/dev/diskN` como origem do volume, para o Finder associar ao disco.
2. **Tamanho ideal de transferência de 1 MiB** (`driver/patches/0006`). O `copyfile` do macOS (`cp`, Finder) usa
   o `f_iosize` do volume como buffer. O NTFS-3G informava o tamanho do cluster (4 KB → 16 KB no kext), e cada
   pedaço de 16 KB gerava ~4 gravações pequenas de controle: **327.749 gravações (1.792 MB) e 131.147 leituras
   para copiar 1 GB** (contagem com um build de diagnóstico). Com 1 MiB: ~11 mil.
3. **Gravação assíncrona** (`EnableCaching = 1` → `nosyncwrites`). Sozinha não mudou a velocidade, mas é como o
   kext do Tuxera monta (REA: `vfs_setflags 0x40` sem precisar de opção).

## O que ainda dá para melhorar

- Gravação em 202 MB/s; a leitura fica perto do limite do SSD. Falta medir a gravação direta do SSD (destrutiva
  no raw — só num disco de teste) para saber o teto.
- O Tuxera tem um cache de blocos próprio (`cbcio`) e o kext dele declara 8 MB em `io_maxreadcnt/maxwritecnt`
  (`vfs_setioattr`, REA); o nosso declara o `iosize` (1 MiB).
- O Paragon NTFS 18 (`build/rea/pacotes/paragon_18`, extraído sem instalar) usa driver NTFS dentro do kernel
  (`ufsd_NTFS.kext`), sem FUSE.

## Preferências

`/Library/Preferences/com.danielmanske.ntfsoficial.plist` (`sudo defaults write … <Chave> -int <valor>`):
`EnableRawDevices` (1), `EnableCaching` (1), `IOSize` (1048576). Por disco: `/.NTFS-Oficial/disable-caching`.
