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
3. **Gravação assíncrona** (`EnableCaching = 1` → `nosyncwrites`). Sozinha não mudou a velocidade. *Corrigido em
   18/10/2026 (Ghidra): o kext do Tuxera **não** monta assíncrono sem opção — o `vfs_setflags 0x40` só roda com
   `nosyncwrites`, que nenhum programa do Tuxera passa (a ajuda do `mount_tuxera_ntfs` chama a opção de
   "dangerous"). O Tuxera monta síncrono e tem o cache `cbcio` no driver. Assíncrono é escolha nossa: os dados
   ficam na memória até irem para o disco, e tirar o cabo sem ejetar perde mais. Comparação dos dois modos com raw +
   1 MiB: `bash scripts/medir-modos.sh /Volumes/Filmes` (resultado abaixo, quando medido).*

## O que ainda dá para melhorar

- Gravação em 202 MB/s; a leitura fica perto do limite do SSD. Falta medir a gravação direta do SSD (destrutiva
  no raw — só num disco de teste) para saber o teto.
- O Tuxera tem um cache de blocos próprio (`cbcio`) e o kext dele declara 8 MB em `io_maxreadcnt/maxwritecnt`
  (`vfs_setioattr`, REA); o nosso declara o `iosize` (1 MiB).
- Muitos arquivos pequenos (copiar, procurar, listar, ler, apagar) nunca tinham sido medidos; no raw o nosso não tem
  cache nenhum para MFT e índices. Script: `bash scripts/medir-arquivos-pequenos.sh <volume> [quantidade]`.

## Medição de 18/10/2026: síncrono × assíncrono e arquivos pequenos

`bash scripts/medir-modos.sh /Volumes/Filmes 2048 3000` (SSD Kingston SA400 USB, raw, `iosize` 1 MiB; arquivos pequenos =
3.000 de 1 a 64 KB, 102 MB, em 30 pastas; cada leitura depois de desmontar e montar):

| Etapa | Assíncrono (`nosyncwrites`, padrão) | Síncrono (como o Tuxera monta) |
|---|---|---|
| Gravar 2 GB | **201,3 MB/s** | 44,2 MB/s |
| Ler 2 GB | 277,1 MB/s | 267,9 MB/s |
| Copiar 3.000 arquivos | 56,0 s | 55,7 s |
| Procurar / listar / ler tudo / apagar | 2,7 / 4,0 / 6,1 / 13,6 s | 1,7 / 2,1 / 6,2 / 11,3 s |

- **Decisão: continua assíncrono.** Síncrono grava 4,5× mais devagar no raw. O Tuxera é síncrono, mas tem o cache `cbcio`
  no driver; nós não temos.
- **Arquivos pequenos são o ponto fraco**: ~53 arquivos/s (1,8 MB/s) ao copiar, nos dois modos. Numa imagem de disco, a
  mesma cópia levou 6,4–7,6 s no raw e 1,9 s no dispositivo de bloco (apagar: 2,8–3,5 s × 0,4 s): o que falta é cache.
- **O que o Tuxera faz (REA, `ntfs_device_unix_io_open`, FUN_10004c28c do driver 2027.0.1):** com `cbcio` e só em
  dispositivo de caractere (raw), abre um cache de blocos (`CSBlockCachingStream`): blocos de 16 MiB (`0x1000000`),
  32 blocos, gravação a cada 1000 ms, 2 blocos fixos, limitado a 1/4 da RAM (`hw.memsize`; reduz o bloco pela metade até
  1 MiB). Também trava o dispositivo com `flock`.
- O "ERRO: conteúdo diferente" da primeira versão do script era só o `diff -r` comparando nomes acentuados byte a byte
  (o volume devolve NFD, como o macOS espera); conteúdo conferido idêntico. O script agora compara normalizando.
- O Paragon NTFS 18 (`build/rea/pacotes/paragon_18`, extraído sem instalar) usa driver NTFS dentro do kernel
  (`ufsd_NTFS.kext`), sem FUSE.

## Preferências

`/Library/Preferences/com.danielmanske.ntfsoficial.plist` (`sudo defaults write … <Chave> -int <valor>`):
`EnableRawDevices` (1), `EnableCaching` (1), `IOSize` (1048576). Por disco: `/.NTFS-Oficial/disable-caching`.
