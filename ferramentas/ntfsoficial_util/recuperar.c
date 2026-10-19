/*
 * Journal sujo: o disco foi tirado do Windows sem ejetar, ou o Windows deixou transações confirmadas
 * (committed) que não chegou a gravar. O Tuxera (EnableAutomaticRecovery = 1, padrão) reaplica essas
 * transações antes de montar com gravação. Aqui quem reaplica é o ntfsrecover do NTFS-3G.
 *
 * O que o código do NTFS-3G faz (lido em 18/10/2026, build/src/ntfs-3g):
 *   - ntfs-3g.probe --readwrite devolve 14 para hiberfil.sys (volume.c: "Windows is hibernated"/"Hibernated
 *     non-system partition") E para $LogFile versão 2.0 ("Metadata kept in Windows cache", EPERM), e 15 para
 *     journal sujo comum (EOPNOTSUPP, sem mensagem). Só a mensagem distingue os dois 14;
 *   - ntfsrecover sem opções = --sync: monta o volume em modo forense, reaplica as transações confirmadas e
 *     termina com reset_logfile(): grava as duas páginas de reinício com RESTART_VOLUME_IS_CLEAN, sem
 *     cliente em uso e versão 1.1. Depois disso o driver monta sem a opção `recover` (o journal já está
 *     limpo), então `recover` (que só ZERA o journal, descartando transações) nunca é passado;
 *   - com journal versão 2.0 (cache do Windows) ele recusa ("Fast restart mode detected") e sai com 1, sem
 *     gravar nada, a não ser com -k, que joga fora os dados do cache do Windows. Nunca usamos -k;
 *   - código de saída: 0 = sincronizou (ou nada a fazer), 1 = qualquer falha; journal apagado ("wiped out")
 *     também sai 1, por isso o -n só faz sentido quando o probe já disse 14/15.
 */
#include "comum.h"

#include <string.h>
#include <strings.h>

sujeira_t recuperar_classificar(const char *dispositivo, int *codigo, char *saida, size_t tamanho)
{
    char local[1024];
    if (!saida) { saida = local; tamanho = sizeof(local); }
    char *probe[] = { PROBE_NTFS3G, "--readwrite", (char *)dispositivo, NULL };
    int r = executar(probe, saida, tamanho);
    if (codigo) *codigo = r;
    if (r == NTFS_DESMONTAGEM_SUJA) return SUJEIRA_JOURNAL;
    if (r == NTFS_HIBERNADO) {
        /* "hibernated" cobre as duas mensagens de hiberfil.sys; sem elas o 14 veio do journal 2.0 */
        return strcasestr(saida, "hibernated") ? SUJEIRA_HIBERNADO : SUJEIRA_CACHE_WINDOWS;
    }
    return SUJEIRA_NENHUMA;
}

int recuperar_journal(const char *dispositivo, bool simular, char *saida, size_t tamanho)
{
    char *normal[] = { NTFSRECOVER, (char *)dispositivo, NULL };
    char *so_ver[] = { NTFSRECOVER, "-n", (char *)dispositivo, NULL };
    int r = executar_limite(simular ? so_ver : normal, saida, tamanho, LIMITE_RECUPERACAO_SEGUNDOS);
    registro("recuperar %s%s: ntfsrecover = %d", dispositivo, simular ? " (simulação)" : "", r);
    return r;
}
