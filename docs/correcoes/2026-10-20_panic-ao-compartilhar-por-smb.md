# Correção: Hackintosh reiniciava (kernel panic) quando outro Mac abria um disco NTFS pela rede (20/10/2026)

Versão 0.2.2, kext 0.1.2 (`kext/patches/0007-sem-leitura-nem-escrita-e-so-leitura.patch`). O mesmo kext leva a
correção do disco travado ao encerrar um programa ([2026-10-20_disco-travado-ao-encerrar-programa.md](2026-10-20_disco-travado-ao-encerrar-programa.md)).

## Sintoma

Do Hackintosh para o MacBook Air, o compartilhamento de arquivos funcionava. Do MacBook Air para o Hackintosh, dava
"erro de rede": o Hackintosh caía e reiniciava. O relatório do panic (Hackintosh, macOS 26.6 `25G83`, `MacPro7,1`):

```
panic(cpu 4 caller 0xffffff7f96975a8d): ntfsoficial: What kind of a flag is this (208000)?
Panicked task 0xffffff9178af29a0: 5 threads: pid 35251: smbd
  … com.danielmanske.ntfsoficial.filesystems.ntfsoficial : _fuse_isnoreadahead
  … com.danielmanske.ntfsoficial.filesystems.ntfsoficial : _fuse_biglock_vnop_open + 0x5c
  … mach_kernel : _vn_open_auth + 0x9ce
  … mach_kernel : _open + 0x187
Kernel Extensions in backtrace: com.danielmanske.ntfsoficial.filesystems.ntfsoficial(0.1.1)
```

(`_fuse_isnoreadahead` é só o símbolo exportado mais próximo: a função de verdade é o `fuse_vnop_open`, com a tradução
dos flags embutida.)

## Causa

1. Quem atende a rede é o `smbd` do Mac que **compartilha**. Ao navegar nas pastas, ele abre os arquivos só para
   acompanhar mudanças: `O_EVTONLY | O_SYMLINK`. Por isso só falhava do MacBook Air para o Hackintosh: no outro
   sentido o servidor é o MacBook Air, e nada passa por disco NTFS.
2. O kernel tira a leitura e a escrita dessas aberturas quando o processo ligou a política
   `IOPOL_VFS_DISALLOW_RW_FOR_O_EVTONLY`, que o `smbd` liga (xnu, `bsd/vfs/vfs_syscalls.c`, `open1`):
   ```c
   if ((flags & O_EVTONLY) && proc_disallow_rw_for_o_evtonly(p)) {
       flags &= ~(FREAD | FWRITE);
   }
   ```
3. A conta: `0x208000 = 0x200000 (O_SYMLINK) + 0x8000 (O_EVTONLY)`, sem `FREAD (0x1)` e sem `FWRITE (0x2)`
   (valores de `sys/fcntl.h`).
4. O osxfuse 3 (`kext/osxfuse/fuse_file.h`, `fuse_filehandle_xlate_from_fflags`) só aceitava "sem leitura nem
   escrita" se o flag fosse exatamente 0; qualquer outro valor caía em `panic("… What kind of a flag is this (%x)?")`.
   A função é usada no open, no close e no ioctl.

**O mesmo caminho é alcançável sem privilégio nenhum, por qualquer programa:** `open(arquivo, O_EXEC)`. O `FFLAGS` do
kernel não põe `FREAD` quando há `O_EXEC` (`sys/fcntl.h`: "O_EXEC turns off FREAD/FWRITE"), e os arquivos do NTFS
aparecem como `rwxrwxrwx`. Ou seja, até a 0.2.1 qualquer abertura `O_EXEC` num disco NTFS derrubava o Mac, inclusive no
Mac principal. Não é coisa do Hackintosh.

## O que o Tuxera faz (REA, Tuxera NTFS 2027.0.1, kext arm64e)

- O texto existe, mas como **aviso**, não panic: `"Tuxera NTFS: What kind of a flag is this (%x)?\n"` em `0x27e1`,
  usado só por `FUN_0000bfc8` (close) e `FUN_0000ea2c` (open), chamando `_IOLog`.
- Open (`FUN_0000ea2c`, instruções conferidas pelo REA):
  ```
  0xeb14  tbz  w23, #0x1, …     ; FWRITE?
  0xeb18  tbz  w23, #0x0, …     ; FREAD?
  0xeb1c  mov  w26, #0x2        ; os dois: FUFH_RDWR
  0xeb24  ubfx w26, w23, #1, #1 ; só FWRITE: FUFH_WRONLY
  0xeb28  tbnz w23, #0x0, …     ; só FREAD: FUFH_RDONLY
  0xeb30  cbnz w23, 0xeb44      ; flag diferente de 0: pula o aviso
  0xeb34…0xeb40  _IOLog(0x27e1) ; aviso só com flag 0
  0xeb44  mov  w26, #0x0        ; FUFH_RDONLY
  ```
  Sem leitura nem escrita vira **só leitura**, sem panic. O aviso só sai com o flag 0 (o contrário do osxfuse, que era
  silencioso no 0).
- Close (`FUN_0000bfc8`, descompilado): a mesma regra (`if (!isdir && fflag == 0) _IOLog(…)`, índice 0 = só leitura),
  então o close cai no mesmo fufh do open.

## Correção

`kext/patches/0007-sem-leitura-nem-escrita-e-so-leitura.patch`: em `fuse_filehandle_xlate_from_fflags`, qualquer flag sem
`FREAD` e sem `FWRITE` devolve `FUFH_RDONLY` (antes: só o 0; o resto, panic). Uma mudança cobre as três chamadas
(open, close, ioctl). O open e o close usam a mesma função, então a contagem do fufh de leitura continua casando. Sem
aviso no log: o `smbd` abre assim o tempo todo e encheria o log.

- `scripts/config.sh`: `VERSAO_KEXT` 0.1.1 → **0.1.2**, `VERSAO` 0.2.1 → **0.2.2**.
- Kext novo: o macOS pede para aprovar em Ajustes → Privacidade e Segurança e reiniciar.
- **Neste Mac, instalar com `bash scripts/instalar.sh --kext-novo`.** Sem a opção, o `instalar.sh` mantém o kext 0.1.1
  aprovado e os auxiliares 0.1.2 recusam montar ("mismatched version", ver
  [2026-10-18_versao-do-kext-impedia-montar.md](2026-10-18_versao-do-kext-impedia-montar.md)).

## Verificação

Feito em 20/10/2026, no Mac principal, sem carregar o kext novo:

- Compilação: `bash scripts/compilar.sh` aplicou o 0007; kext `CFBundleVersion 0.1.2`, `x86_64 arm64e`.
- O texto do panic sumiu do binário: `strings -a … | grep -c 'What kind of a flag'` = **0** no kext novo, 1 no
  instalado (0.1.1).
- Instalador `build/out/NTFS-Oficial-0.2.2.pkg` (primeiro com só o 0007, SHA-256 `fb1f3c77…`; o atual, com o 0008
  também, `5f16ff9b9cfc8e8d733977fdbc7ac346fb437badd391c989b9065571deb02795`) expandido: kext 0.1.2, `x86_64 arm64e`, sem o texto do panic, `kpi.bsd = 23.0.0`; `load_`/`mount_ntfsoficial` 0.1.2;
  app 0.2.2.
- Programa de teste (`scripts/diagnostico/abrir_so_eventos.c`) num arquivo APFS: 100 aberturas `0x40208000` no arquivo e
  `0x40308000` na pasta, todas com `read()` = `EBADF`. Isso prova que a abertura chega ao sistema de arquivos sem
  `FREAD`, como a do `smbd`.
- Imagem NTFS montada (kext 0.1.1, só listagem): os arquivos aparecem `-rwxrwxrwx`, então o `O_EXEC` do teste é aceito
  e chega ao kext.

**Falta (precisa do kext novo carregado, ou seja, aprovar e reiniciar):**

1. `bash scripts/testar-abrir-so-eventos.sh` (Mac principal ou Hackintosh): abre arquivo, pasta e link numa imagem NTFS
   do jeito do `smbd`, 100 vezes cada, e procura `fufh invalid` no log. O script se recusa a rodar se o kext carregado
   não for o `VERSAO_KEXT`: **com o 0.1.1 esse teste derruba o Mac.**
2. Uso real: no Hackintosh com a 0.2.2, abrir pelo MacBook Air (Finder → Rede) uma pasta compartilhada que esteja num
   disco NTFS, navegar, abrir e copiar arquivos nos dois sentidos.

## Como reverter

Apagar `kext/patches/0007-sem-leitura-nem-escrita-e-so-leitura.patch` e voltar `VERSAO_KEXT` para 0.1.1 em
`scripts/config.sh`. O panic volta junto.
