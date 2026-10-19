# Metadados do Finder e nomes com caracteres proibidos no Windows

Dois patches do driver (18/10/2026), a partir da conferência com o Ghidra no driver do Tuxera
(`docs/design/REFERENCIA_TUXERA.md` seção 14). Código próprio sobre o NTFS-3G aberto.

## Metadados do Finder — `driver/patches/0007-metadados-do-finder.patch`

| NTFS | macOS | Observação |
|---|---|---|
| Oculto | `hidden` (`UF_HIDDEN`): o Finder esconde | `$RECYCLE.BIN`, `System Volume Information`, `desktop.ini` somem do Finder |
| Somente leitura, em arquivo | `uchg` (`UF_IMMUTABLE`): cadeado; gravar e apagar dão erro de permissão, como no Windows | |
| Somente leitura, em pasta | nada | **Diferente do Tuxera**, que põe o cadeado também. O Windows usa esse atributo em pastas personalizadas (com `desktop.ini`) e não impede gravar; com o cadeado o macOS recusaria criar arquivos na pasta |
| Sem o atributo Arquivo | `arch` (`SF_ARCHIVED`) | só fora de diretório, como o Tuxera |
| Data de criação | `st_birthtime` (`stat -f %B`), e gravada de volta (`setattrlist`, cópia pelo Finder) | |
| Data de backup | sempre 0 | o NTFS não tem; o Tuxera guarda no stream `AFP_AfpInfo` (pendente) |
| Rótulo do volume | `setvolname` no driver (até 128 caracteres; volume só leitura recusa) + `kext/patches/0005-renomear-volume.patch` | Sem o 0005, `setattrlist(ATTR_VOL_NAME)` dá *Invalid argument* (testado em 18/10/2026): o kext não anunciava `VOL_CAP_INT_VOL_RENAME` (estava comentado, "Not yet"). O `fuse_vfsop_setattr` do kext já tratava o nome e mandava `FUSE_SETVOLNAME`; o 0005 só liga o anúncio quando o driver implementa. Kext 0.1.1: exige aprovar e reiniciar |

- `chflags hidden|nohidden|uchg|nouchg` grava de volta nos atributos NTFS. Bits sem equivalente (`nodump`, `opaque`)
  são ignorados; o Tuxera recusa o pedido inteiro nesse caso.
- Registros de sistema do NTFS (MFT < 16) não ganham nem perdem flags.
- Implementação: `getstat` chama `ntfs_fuse_getstat_finder`; o macOS usa `setattr_x` (a libfuse prefere ao
  `setattr`), que reaproveita o corpo do `setattr` (modo, dono, tamanho, datas) e trata flags e datas extras;
  `getxtimes` e `setvolname` (o kext só os usa se o INIT anunciar `FUSE_XTIMES`/`FUSE_VOL_RENAME`,
  `fuse_internal.c:1939-1946`).

## Nomes estilo SFM — `driver/patches/0008-nomes-sfm.patch`

O Windows proíbe `" * : < > ? \ |` e os caracteres de controle em nomes; o macOS aceita (e o `/` do Finder é `:`
por baixo). Com a opção `sfmconv`, esses caracteres são gravados na área privada do Unicode, no formato do Services
for Macintosh — o mesmo do Tuxera e do compartilhamento SMB do macOS. No Windows aparecem como símbolos diferentes,
mas o arquivo abre normalmente.

| No Mac | No disco |
|---|---|
| 0x01–0x1F | U+F001–U+F01F |
| `"` `*` `:` `<` `>` `?` `\` `\|` | U+F020 a U+F027, nessa ordem |
| U+F8FF (símbolo da Apple) | U+F02A |
| `.` ou espaço no **fim** do nome | U+F029 / U+F028 |

- A troca é simétrica (a tabela do Tuxera, extraída do binário dele: FUN_100046e80/46f50, tabelas em 0x10006b450
  e 0x10004d548); um nome vai e volta igual.
- Vale para nomes de arquivo e pasta (lookup, criar, renomear, apagar, listar). Não vale para destino de link
  simbólico, nomes de xattr nem o rótulo.
- `.` e `..` nunca são trocados. Aplicada antes da checagem de `windows_names`.
- Preferência `EnableSFMConversions` (padrão 1, como o Tuxera): o util passa `sfmconv` e não passa
  `windows_names`. Desligada: `nosfmconv,windows_names` (nomes com esses caracteres são recusados, como antes).
  No driver a opção vem desligada.

## Teste

`bash scripts/testar-finder-sfm.sh` (sem sudo, com imagem de disco): flags, data de criação, rótulo, nomes SFM no
disco (`ntfsls`) e `ntfsck` do Tuxera. Regressão à parte: `python3 -I scripts/estresse.py <pasta_vazia> <volume> 1500`,
com e sem `sfmconv`.

Resultado em 18/10/2026 (driver de `build/out`, imagem de disco): `hidden` aparece, persiste e vira HIDDEN no NTFS;
pasta não fica imutável; arquivo somente leitura vira `uchg` e `rm` dá *Operation not permitted*; data de criação lida,
gravada e mantida; nomes SFM vão e voltam e aparecem na área privada pelo `ntfsls`; sem `sfmconv`, `windows_names`
recusa `a:b`; `ntfsck` do Tuxera 101 (sem erro). Estresse de 1500 operações sem divergência no dispositivo de bloco
com e sem `sfmconv` e no raw com `sfmconv`. Renomear o volume falhou (ver tabela).
