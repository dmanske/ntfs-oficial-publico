/*
 * Arquivos de controle na raiz do próprio disco NTFS, lidos sem montar (ntfsls -f <disco> --path <arquivo>).
 * Mesma ideia do Tuxera (/.Tuxera-NTFS/...); os do Tuxera também são respeitados, para quem já os criou.
 */
#include "comum.h"

#include <stdio.h>
#include <string.h>

static bool existe_no_disco(const char *dispositivo, const char *caminho)
{
    char saida[512];
    char *argv[] = { NTFSLS, "-f", (char *)dispositivo, "--path", (char *)caminho, NULL };
    int r = executar(argv, saida, sizeof(saida));
    return r == 0;
}

static bool qualquer(const char *dispositivo, const char *arquivo)
{
    char nosso[256], tuxera[256];
    snprintf(nosso, sizeof(nosso), "/.NTFS-Oficial/%s", arquivo);
    snprintf(tuxera, sizeof(tuxera), "/.Tuxera-NTFS/%s", arquivo);
    return existe_no_disco(dispositivo, nosso) || existe_no_disco(dispositivo, tuxera);
}

void controle_ler(const char *dispositivo, controle_t *c)
{
    c->desligar_driver  = qualquer(dispositivo, "disable-driver");
    c->sem_normalizacao = qualquer(dispositivo, "disable-normalization");
    c->sem_cache        = qualquer(dispositivo, "disable-caching");
    if (c->desligar_driver)  registro("controle: disable-driver encontrado em %s", dispositivo);
    if (c->sem_normalizacao) registro("controle: disable-normalization encontrado em %s", dispositivo);
    if (c->sem_cache)        registro("controle: disable-caching encontrado em %s", dispositivo);
}
