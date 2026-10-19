# Correção: o kext da 0.2.0 só carregava no macOS 27 (19/10/2026)

Versão 0.2.1. Plano, evidências e revisão: `docs/planos/KEXT_SO_CARREGA_NO_MACOS_27_2026-10-19.md` (repositório
privado).

## Sintoma

O `NTFS-Oficial-0.2.0.pkg` instalado num PC Hackintosh (Intel `x86_64`, macOS 26.6.2, kernel 25.6.0, OpenCore):

- os discos NTFS **sumiram do Finder** (antes apareciam, só leitura, pelo NTFS da Apple);
- **nada apareceu** em Ajustes → Privacidade e Segurança para aprovar;
- os 4 discos internos do Windows apareciam com o nome `WARNING: Dirty volume mount was forced by the 'force' mount
  option.` (`diskutil info`).

`/private/var/log/ntfsoficial-instalacao.log`:

```
Unable to resolve dependencies: 'Kext com.danielmanske.ntfsoficial.filesystems.ntfsoficial v0.1.1 ...'
names a dependency on 'com.apple.kpi.mach', but could not find version compatible with '27.0.0'.
AVISO: kext não carregou (falta aprovar em Ajustes e reiniciar)
```

## Causas

1. **KPI do SDK.** O `Info.plist` do kext do osxfuse define a versão das KPIs (`OSBundleLibraries`) como
   `VERSION_MAJOR.0.0`, e `VERSION_MAJOR` vem do `libkern/version.h` do **SDK de quem compila**. Compilado com o
   Xcode 27, o kext pedia `com.apple.kpi.* 27.0.0`; o macOS 26 oferece `25.6.0`, e o `kmutil` recusa o kext antes da
   etapa de aprovação. O osxfuse original não tinha o problema porque gerava um kext por versão do macOS; o nosso usa
   um kext só, em pasta fixa (`kext/patches/0003`). Valia para todo macOS anterior ao 27, Mac ou Hackintosh.
2. **Sem kext, o pacote ficava com o disco.** A detecção (`ntfsoficial.util -p`) reconhecia o volume, o macOS
   escolhia o nosso pacote no lugar do NTFS da Apple, e a montagem falhava sem o kext: o disco ficava sem montar.
3. **Rótulo com o aviso.** A detecção lia o rótulo com o `ntfslabel -f` juntando stdout e stderr; com o disco sujo, o
   `ntfslabel` escreve no stderr o aviso `Dirty volume mount was forced…` antes do rótulo.
4. **Mensagem errada no instalador.** Qualquer falha do load virava "falta aprovar".

## Correção

- `scripts/config.sh`: `KPI_MINIMO="23.0.0"` e `MACOS_PKG_MINIMO="14.0"` lado a lado (os dois são macOS 14 =
  Darwin 23). O `montar-instalador.sh` passa a usar o valor do `config.sh`.
- `kext/patches/0006-kpi-minima-fixa.patch`: o `Info.plist` do kext usa `NTFSOFICIAL_KPI_MINIMO` (e para com `#error`
  se não vier); `scripts/compilar-kext.sh` passa `INFOPLIST_PREPROCESSOR_DEFINITIONS="KERNEL NTFSOFICIAL_KPI_MINIMO=…"`
  e, no fim, confere com o `PlistBuddy` que as 5 `OSBundleLibraries` saíram com `KPI_MINIMO`.
- `ferramentas/ntfsoficial_util/executar.c`: `executar_so_stdout` (stderr para `/dev/null`); o `ler_rotulo` usa essa
  forma, com buffer de 512 bytes. Os outros usos continuam juntando o stderr (a montagem procura "hibernated" nele).
- `ferramentas/ntfsoficial_util/detectar.c`: depois do `ntfs-3g.probe` aceitar, roda o `load_ntfsoficial`; se ele
  falhar (1 = falta aprovar, 2 = kext não encontrado, 255 = outra falha), responde "não reconhecido" e o disco fica
  com o NTFS da Apple (só leitura).
- `pacote/instalador/postinstall`: compara a KPI do kext com o kernel (`uname -r`) e, pelo código do
  `load_ntfsoficial`, separa "macOS incompatível", "falta aprovar" e "não carregou (código N)", com o
  `kmutil print-diagnostics` no log.
- `VERSAO_KEXT` continua `0.1.1`: o código do kext não mudou, só o `Info.plist`.
- `ferramentas/ntfsoficial_util/montar.c` (achado no teste do Hackintosh, corrigido antes de publicar): o dono dos
  arquivos era o de `/dev/console`, que no boot (antes do login) é `root` ou `_windowserver`; o `git` recusava
  repositórios nesses discos ("dubious ownership"). Agora a montagem passa `uid=99,gid=99` (`DONO_DESCONHECIDO` em
  `comum.h`) quando o macOS não manda `uid=`/`gid=`. O 99 é o "desconhecido" do macOS: o kernel o mostra como quem está
  olhando (`bsd/vfs/kpi_vfs.c`, `vnode_attr_handle_uid_and_gid`, no código aberto do xnu), então cada pessoa vê os
  arquivos como seus. O `chown` para outro dono não dá erro (o NTFS-3G vem com `silent`). Para desfazer: voltar a função
  `dono()` anterior em `montar.c`.

Os 232 símbolos do kernel que o kext usa existem nas listas de exportação das KPIs do macOS 12 ao 26, em `x86_64` e
`arm64e` (conferido com as listas `config/*.exports` do código aberto do xnu da Apple).

## Verificação

Compilado no PC Hackintosh (Intel, macOS 26.6.2, Xcode 26.5, SDK `macosx26.5`) em 19/10/2026:

- `bash scripts/compilar.sh` sem erro; o `compilar-kext.sh` conferiu as 5 `OSBundleLibraries` = `23.0.0`.
- Kext `x86_64 arm64e`, `CFBundleVersion 0.1.1`; o mesmo `23.0.0` no kext dentro do `NTFS-Oficial-0.2.1.pkg`
  (`pkgutil --expand-full`), com `os-version min="14.0"`.
- `kmutil print-diagnostics -p` no kext compilado: `Dependencies: OK` (com a 0.2.0: "could not find version
  compatible with '27.0.0'"). Os outros avisos são de dono (pasta de build, o instalador põe `root:wheel`) e da
  assinatura ad-hoc, iguais aos da 0.2.0.
- Os 232 símbolos do kernel existem do macOS 12 ao 26, nas duas arquiteturas (saída 0).
- Nenhum binário com `libintl` (ver abaixo).

Instalado no Hackintosh (detalhes no plano):

- Log do instalador: `load_ntfsoficial = 1`, `kmutil load = 27` ("not approved to load"), `AVISO: falta aprovar…`; o
  pedido apareceu em Privacidade e Segurança.
- Antes de aprovar: os 4 discos voltaram ao Finder só leitura pelo NTFS da Apple, com os nomes certos; log
  `kext não carregou (load_ntfsoficial = 1), fica para o NTFS da Apple`.
- Depois de aprovar e reiniciar: kext `0.1.1` carregado (x86_64), `allow_other: 1`; uma imagem de teste montou sozinha
  pelo NTFS Oficial e gravou 30 MB idênticos como usuário comum.
- Achado no teste: os 4 discos reais desse PC tinham a marca `VOLUME_IS_DIRTY` (o Windows pede um chkdsk) com o journal
  limpo e sem hibernação. Nesse caso o NTFS-3G monta com gravação, porque ignora a marca de propósito, e o driver
  comercial com que o projeto é comparado faz o mesmo. **Decisão (19/10/2026): seguir igual** — monta com gravação e não
  tira a marca pelo Mac (nem no Reparar). Sem mudança de código.
- Discos reais liberados: antes, `ntfsfix -n` (só leitura) sem erro nos 4. Depois do reinício, os 4 montaram sozinhos pelo
  NTFS Oficial, com gravação e os nomes certos; gravar, ler e apagar um arquivo pequeno funcionou; a marca continuou igual
  depois de desmontar (conferido em 3 dos 4: um não desmontou porque o macOS estava usando o disco).
- Pacote final da 0.2.1 (com a correção do dono, SHA-256 `a08bc259…`) no Hackintosh: o macOS pediu aprovação de novo e,
  até aprovar, os discos ficaram com o NTFS da Apple; depois, os 4 discos internos montaram no boot pelo NTFS Oficial com
  `uid=99`, aparecem como do usuário (`ls -ln` = 501) e o `git` funciona num repositório dentro deles.

### Achado ao compilar no Mac Intel

O link do NTFS-3G arm64 falhava com `Undefined symbols: _libintl_setlocale`. O Homebrew do Intel fica em `/usr/local`,
o configure achava o `libintl.h` do gettext (`HAVE_LIBINTL_H 1`), que troca `setlocale` por `libintl_setlocale`, mas o
NTFS-3G não linka a `libintl` (e a do Homebrew só existe em `x86_64`). No Mac com chip Apple o cabeçalho não é achado:
os binários da 0.2.0 usam o `setlocale` do sistema. O `compilar-usuario.sh` passa `ac_cv_header_libintl_h=no` ao
configure do NTFS-3G, e os dois Macs geram o mesmo binário. Para desfazer: tirar essa variável da linha do configure.

## Como reverter

Voltar `kext/patches/0006-kpi-minima-fixa.patch` e a linha `INFOPLIST_PREPROCESSOR_DEFINITIONS` do
`compilar-kext.sh` (o kext volta a pedir a KPI do SDK: só carrega no macOS da versão do Xcode). O load na detecção sai
tirando a chamada a `carregar_kext` em `detectar.c`.
