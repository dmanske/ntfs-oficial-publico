# Correção: disco NTFS travava de vez quando um programa era encerrado esperando por ele (20/10/2026)

Versão 0.2.2, kext 0.1.2 (`kext/patches/0008-interrompido-antes-de-enviar-desiste.patch`). Vai no mesmo kext da
[correção do compartilhamento](2026-10-20_panic-ao-compartilhar-por-smb.md): o 0.1.2 ainda não tinha sido instalado em
lugar nenhum, então continua sendo uma aprovação e um reinício só.

## Sintoma

Hackintosh (macOS 26.6.2 `25G83`, kext 0.1.1), 20:09: o FinderX parou de responder. O relatório (`spindump`, evento
`hang`, 78 s) mostra que **tudo o que usava um dos discos NTFS parou**, não só o FinderX:

| Processo | Onde parou |
|---|---|
| FinderX (`faccessat`) | `fuse_biglock_vnop_getattr` → `fusefs_lock`: `blocked by krwlock for writing owned by MirrorDisplays [2056] thread 0x15616` |
| CleanMyMac Health Monitor | a mesma trava; e um `close` e um `statfs` esperando o driver |
| `mds` (Spotlight) | `fuse_biglock_vnop_close` → `fusefs_lock`, a mesma trava |
| NTFS Oficial (o app) | `statfs` (`fuse_vfsop_biglock_getattr` → `fdisp_wait_answ`) esperando o driver |
| `ntfsoficial [2029]` (driver do disco) | `fuse_device_read`: `blocked by turnstile waiting for MirrorDisplays [2056] thread 0x15616` |
| `MirrorDisplays [2056]` | `(suspended) (zombie)`, 1 thread: `fuse_biglock_vnop_getattr` → `fuse_vnop_getattr` → `fdisp_wait_answ` → `fuse_internal_msleep`, **4,9 s de CPU em 5 s** de amostra |

Nomes tirados do kext 0.1.1 x86_64 deste projeto: o UUID `71E49789-B87F-3D56-9859-D91654BEAFC2` é o mesmo do relatório;
os deslocamentos são os endereços do arquivo (conferido com o panic do mesmo dia: `_fuse_biglock_vnop_open` = `0x67c8`,
`+ 0x5c` = `0x6824`); `atos -arch x86_64 -o <fatia> -l 0 <endereço>`. Exemplo: `+11449` = `0x2cb9` =
`fdisp_wait_answ` (`fuse_ipc.c:1080`), `+52656` = `0xcdb0` = `fuse_internal_msleep`, `+21168` = `0x52b0` =
`fuse_device_read`.

## Causa

1. O `MirrorDisplays` (ajudante de "espelhar telas" dos Ajustes de Tela) pediu os atributos de um arquivo do disco
   (`getattr`). Para isso pegou a trava do arquivo (`nodelocked_vnop` → `fusefs_lock` exclusivo) e entrou em
   `fticket_wait_answer` (`fuse_ipc.c`), esperando a resposta do driver.
2. O processo foi encerrado. Quando um processo é encerrado, o kernel liga `TH_SFLAG_ABORT` (0x10) em cada thread
   (xnu, `osfmk/kern/thread_act.c`, `act_abort`), e todo `msleep` com `PCATCH` volta na hora com `EINTR`.
3. Com o pedido ainda **não enviado** ao driver, o osxfuse 3 só desistia se
   `fuse_kludge_thread_should_abort(current_thread())` visse essa marca. Essa função lê `sched_flags` **num deslocamento
   fixo** dentro da estrutura da thread: a tabela dela (`fuse_kludges.c`) para no macOS 10.14 (168 bytes) e esse valor
   vale para qualquer kernel mais novo. No macOS 26 a estrutura é outra, então a função lê outro campo e diz "não
   aborta". Prova: a thread de um processo já encerrado ficou 74 s sem desistir.
4. Sem desistir, o código voltava ao `msleep` ainda com `PCATCH` (só tira o `PCATCH` depois de enviado), que voltava na
   hora: **laço girando**, com o `tk_mtx` do pedido preso quase o tempo todo (o `msleep` só o solta por um instante).
5. O driver já tinha tirado o pedido da fila e estava parado em `fuse_lck_mtx_lock(ftick->tk_mtx)`
   (`fuse_device.c:352`). Nunca ganhava a trava, então nunca chegava ao `fticket_set_sent` (linha 398). O laço não
   terminava nunca, e o driver daquele disco parou de atender todo mundo.

Não sai sozinho: só reiniciando. Acontece quando qualquer programa é encerrado enquanto espera o disco e o driver ainda
não recebeu o pedido, uma corrida rara. O código é o mesmo no Mac com chip Apple.

O mesmo teste quebrado era usado em `fusefs_lock` (`fuse_locking.c:85`), na espera por um getattr de outra thread. Com
"não aborta", o laço repetia o `msleep` com o `getattr_lock` já solto pelo `PDROP`.

## O que o Tuxera faz (REA, Tuxera NTFS 2027.0.1, kext arm64e; base osxfuse 2.x)

- Espera pela resposta, `FUN_000089e0` (texto `"fu_ans"` em `0x15cd`): `msleep(tick, tk_mtx, 0x100 (PCATCH), "fu_ans",
  tempo_limite)` num laço que só se repete com `0x23` (`EWOULDBLOCK`, tempo limite: aviso "force ejecting"). Com `4`
  (`EINTR`) chama `FUN_00007334` e sai; com qualquer outro erro também sai, marca o pedido como respondido e devolve o
  erro.
- `FUN_00007334` monta um pedido `0x24` = 36 = `FUSE_INTERRUPT` com o `unique` do original e o põe na fila
  (`FUN_0000851c`, a mesma usada para os pedidos normais).
- Não lê a estrutura da thread em lugar nenhum e não tem a espera de getattr do `fusefs_lock` (não há o texto
  `"fuse_getattr"`, que no nosso é de `_fusefs_lock`).

Ou seja: o Tuxera desiste em qualquer interrupção, enviado ou não.

## Correção

`kext/patches/0008-interrompido-antes-de-enviar-desiste.patch`:

- `fuse_ipc.c`, `fticket_wait_answer`: interrompido por sinal (`EINTR`/`ERESTART` do `msleep`) com o pedido **ainda
  não enviado** → marca como respondido, tira o retorno e sai com o erro. Não usa mais a função quebrada. O driver já
  pula pedido marcado como respondido (`fuse_device.c:358`), e a fila tem a própria referência do pedido
  (`fuse_insert_message` → `fuse_ticket_retain`), então não há pedido liberado ainda na fila. Fica **antes** do
  tratamento do tempo limite, porque lá o osxfuse cria um `EINTR` artificial para mandar o aviso, e o tempo limite tem
  que continuar marcando o disco como morto.
- Pedido **já enviado**: fica como no osxfuse 3 (manda `FUSE_INTERRUPT` e espera a resposta dormindo, sem `PCATCH`; não
  gira e solta o `tk_mtx`). Aqui é diferente do Tuxera de propósito: desistir de um pedido que o driver já está
  fazendo pode deixar, por exemplo, uma gravação terminar no disco depois de o programa ter ouvido "interrompido".
- `fuse_locking.c`, `fusefs_lock`: qualquer interrupção sai da espera. O nó já está destravado, e a macro
  `fuse_nodelock_lock` devolve o erro antes de chegar ao `fuse_nodelock_unlock`.
- Nenhuma chamada à `fuse_kludge_thread_should_abort` sobra no kext (abaixo).

Ficou de fora, de propósito: `fuse_kludge_exchange` **grava** `v_name`/`v_parent` do vnode em deslocamentos do macOS
10.12 (`fuse_kludges.c`). Só roda no `exchangedata` quando o driver o implementa, e o `lowntfs-3g` não implementa (sem
`exchange` no código; o kext desliga a função no primeiro `ENOSYS`, `fuse_vnops.c:690`). Anotado nas pendências.

## Verificação

Feito em 20/10/2026, no Mac principal, sem carregar o kext novo:

- `bash scripts/compilar.sh` aplicou o 0007 e o 0008; instalador `build/out/NTFS-Oficial-0.2.2.pkg` (SHA-256
  `5f16ff9b9cfc8e8d733977fdbc7ac346fb437badd391c989b9065571deb02795`), cujo kext é idêntico ao compilado (`cmp`), 0.1.2,
  `x86_64 arm64e`.
- Chamadas a `_fuse_kludge_thread_should_abort` (`otool -V`; no arm64e, seção `__TEXT_EXEC,__text`):

  | | x86_64 | arm64e |
  |---|---|---|
  | kext 0.1.1 instalado | 2 | 2 |
  | kext 0.1.2 do `.pkg` | 0 | 0 |

- `bash scripts/testar-interrupcao.sh --ensaio` com o kext 0.1.1 e o driver instalado (`DRV=…/Support/ntfsoficial`):
  driver pausado, o `stat` B ficou esperando (o pedido estava na fila), os dois terminaram ao soltar o driver, o disco
  respondeu e foi desmontado. Isso confere o roteiro; o ensaio não mata o processo.
- Os dois testes se recusam a rodar com o kext 0.1.1 (conferido).

**Falta (kext novo carregado):** `bash scripts/testar-interrupcao.sh` (sem `--ensaio`): o `stat` B morto tem que sair em
até 2 s com o pedido na fila, e o disco tem que responder depois. **Com o kext 0.1.1 esse teste trava o disco de teste
e um núcleo até reiniciar**; o script confere a versão.

## Como reverter

Apagar `kext/patches/0008-interrompido-antes-de-enviar-desiste.patch` e tirar a linha `+ 0008` do comentário do
`VERSAO_KEXT` em `scripts/config.sh`. O travamento volta junto.
