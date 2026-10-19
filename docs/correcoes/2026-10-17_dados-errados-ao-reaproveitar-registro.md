# Correção: dados errados ao apagar e criar arquivos (17/10/2026)

## Sintoma

Teste de estresse (operações aleatórias numa imagem NTFS, conferidas contra uma cópia de referência): 17 de 245
arquivos com conteúdo errado. Caso mínimo encontrado pelo teste passo a passo: criar um arquivo de 1 byte logo
depois de apagar outro fazia o novo aparecer com 65.537 bytes — tamanho e dados do arquivo apagado.

Acontecia também com o driver que estava instalado (modo bloco, síncrono), ou seja, desde a fase 0.

## Causa

- O NTFS reaproveita o registro MFT do arquivo apagado para o próximo criado.
- O NTFS-3G (`lowntfs-3g`) entregava ao kext o número do registro e **geração sempre 1**.
- O kext (osxfuse) não descarta o vnode ao apagar (`fuse_vnop_remove`, o `vnode_recycle` está comentado) e acha
  vnodes pelo número; com o mesmo número e a mesma geração, entregava o vnode velho, com tamanho e cache antigos.
- O kext do Tuxera tem o mesmo comportamento (REA: na mudança de geração descarta e devolve `ESTALE` = 0x46 em
  `sub_9988`; `vnode_recycle` só na rotina de "desaparecer", `sub_5430`). O driver do Tuxera não deixa nomes de
  função nessa parte; deduzimos que ele entrega números/gerações distintos. *Conferido com o Ghidra em 18/10/2026
  (lookup FUN_10000b240): o número entregue é só o do registro MFT, sem a sequência; só a geração muda (= número de
  sequência). A solução dele depende do ESTALE do kext; a nossa (0003 + 0004) muda também o número, e o teste de
  estresse mostra que funciona. Diferença visível: o nosso `st_ino` fica acima de 2^48.*

## Correção (patches do driver)

| Patch | O que faz |
|---|---|
| `driver/patches/0003-geracao-pelo-numero-de-sequencia.patch` | geração = número de sequência do registro + 1 |
| `driver/patches/0004-numero-com-sequencia.patch` | número entregue ao kext = registro + sequência (`MK_MREF`), **sempre calculado do registro aberto** |

Só o 0003 trocava dados errados por erro `ESTALE` (70, "Stale NFS file handle") na primeira criação. O 0004 faz o
arquivo novo chegar com outro número, e o kext cria um vnode novo. A primeira versão do 0004 calculava o número da
referência que vinha da consulta por nome — que às vezes vem sem a sequência — e o mesmo arquivo ganhava dois
números: anexar e depois renomear perdia o trecho anexado. Corrigido calculando sempre do registro aberto.
O `ntfs_inode_open()` confere a sequência ("wrong SeqNo"), então um vnode velho nunca alcança o arquivo novo.

Sem mudança no kext (não precisou aprovar nem reiniciar).

## Verificação

- Reprodução mínima (criar → anexar → renomear): ok.
- 1.500 operações aleatórias conferidas byte a byte depois de cada uma, modo bloco e modo raw: sem divergência.
- `ntfsck` do Tuxera (cópia em `build/rea/bin/`): sem erros.

## Como reverter

Apagar os dois patches e rodar `bash scripts/compilar.sh && bash scripts/instalar.sh` (volta o problema).
