/*
 * Detecção: ntfsoficial.util -p <disco> <removable|fixed> <readonly|writable>
 *
 * Fluxo do _op_probe do Tuxera (REA, docs/design/REFERENCIA_TUXERA.md), com duas diferenças (2 e 5):
 *   1. preferência DisableDriver -> não reconhece;
 *   2. (nosso) assinatura "NTFS    " no setor de boot: responde rápido "não é meu" para FAT/exFAT,
 *      que usam o mesmo tipo de partição GPT (EBD0A0A2-...);
 *   3. ntfs-3g.probe -> 0, 14 (hibernado ou journal 2.0) e 15 (desmontado sujo) seguem, como o Tuxera (REA:
 *      _op_probe aceita `código - 14 < 2`, ou seja, 14 e 15). O 13 (corrompido) é recusado, igual ao Tuxera, e
 *      fica para o NTFS só leitura da Apple. Em 14/15 a montagem decide o que fazer (montar.c: replay do
 *      journal com o ntfsrecover ou só leitura);
 *   4. arquivo de controle disable-driver no disco -> não reconhece;
 *   5. load_ntfsoficial (carrega o kext; com o kext certo já carregado volta 0 na hora): qualquer falha ->
 *      não reconhece, e o disco fica para o NTFS da Apple (só leitura). Sem isso, um kext que não carrega
 *      (falta aprovar, macOS incompatível) deixava o disco sem montar nenhum (0.2.0 no Hackintosh, 19/10/2026).
 *      O Tuxera faz parecido no driver em -oprobe, mas só responde "não reconhecido" quando falta aprovar
 *      (código 27); em qualquer outra falha do load ele reconhece;
 *   6. escreve o rótulo do volume (só o stdout do ntfslabel; o stderr traz avisos como "Dirty volume mount
 *      was forced", que viravam o nome do volume) e responde RECONHECIDO.
 */
#include "comum.h"

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static bool tem_assinatura_ntfs(const char *dispositivo)
{
    unsigned char setor[512];
    int fd = open(dispositivo, O_RDONLY);
    if (fd < 0) {
        registro_erro("detectar: não abri %s", dispositivo);
        return false;
    }
    ssize_t n = pread(fd, setor, sizeof(setor), 0);
    close(fd);
    return n == (ssize_t)sizeof(setor) && memcmp(setor + 3, "NTFS    ", 8) == 0;
}

static void ler_rotulo(const char *dispositivo, char *rotulo, size_t tamanho)
{
    char *argv[] = { NTFSLABEL, "-f", (char *)dispositivo, NULL };
    if (executar_so_stdout(argv, rotulo, tamanho) != 0) rotulo[0] = '\0';
    rotulo[strcspn(rotulo, "\r\n")] = '\0';
}

/* Códigos do load_ntfsoficial (support/load_osxfuse): 1 = falta aprovar (kOSKextReturnSystemPolicy -> EPERM,
 * fuse_kext.c:322); 2 = kext não encontrado (ENOENT); 255 = outra falha, por exemplo dependência; -1 = não rodou
 * ou passou do limite. Com o kext da versão errada carregado, ele tenta descarregar e carregar o certo. */
static bool carregar_kext(const char *dispositivo)
{
    char *argv[] = { LOAD_KEXT, NULL };
    int r = executar_limite(argv, NULL, 0, LIMITE_LOAD_SEGUNDOS);
    if (r != 0) {
        registro("detectar %s: kext não carregou (load_%s = %d), fica para o NTFS da Apple", dispositivo, NOME, r);
        return false;
    }
    return true;
}

int detectar(int argc, char *argv[])
{
    preferencias_t p;
    preferencias_ler(&p);

    char dispositivo[128];
    snprintf(dispositivo, sizeof(dispositivo), "/dev/%s", argv[2]);
    bool so_leitura = argc >= 5 && strcmp(argv[4], "readonly") == 0;

    if (p.desligado) {
        registro("detectar %s: desligado nas preferências (DisableDriver)", dispositivo);
        return RESPOSTA_NAO_RECONHECIDO;
    }
    if (!tem_assinatura_ntfs(dispositivo)) {
        return RESPOSTA_NAO_RECONHECIDO;
    }

    char saida[1024];
    char *probe[] = { PROBE_NTFS3G, so_leitura ? "--readonly" : "--readwrite", dispositivo, NULL };
    int r = executar(probe, saida, sizeof(saida));
    registro("detectar %s: ntfs-3g.probe = %d", dispositivo, r);
    if (r != NTFS_OK && r != NTFS_HIBERNADO && r != NTFS_DESMONTAGEM_SUJA) {
        registro("detectar %s: não reconhecido (código %d): %s", dispositivo, r, saida);
        return RESPOSTA_NAO_RECONHECIDO;
    }

    controle_t c;
    controle_ler(dispositivo, &c);
    if (c.desligar_driver) {
        return RESPOSTA_NAO_RECONHECIDO;
    }
    if (!carregar_kext(dispositivo)) {
        return RESPOSTA_NAO_RECONHECIDO;
    }

    /* rótulo NTFS: até 128 unidades UTF-16 = até 384 bytes em UTF-8 */
    char rotulo[512];
    ler_rotulo(dispositivo, rotulo, sizeof(rotulo));
    registro("detectar %s: reconhecido, rótulo \"%s\"", dispositivo, rotulo);
    printf("%s", rotulo);
    fflush(stdout);
    return RESPOSTA_RECONHECIDO;
}
