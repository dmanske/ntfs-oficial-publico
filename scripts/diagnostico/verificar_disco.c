/*
 * Verificador SÓ LEITURA das flags do volume e do journal de um disco NTFS. Ferramenta de apoio; o produto não usa.
 *
 * Abre o volume com NTFS_MNT_RDONLY (nada é gravado) e roda as mesmas checagens que o ntfs_mount faz numa montagem
 * com gravação (libntfs-3g/volume.c, "Check for dirty logfile and hibernated Windows"): hiberfil.sys
 * (ntfs_volume_check_hiberfile), journal sujo e journal 2.0 (ntfs_check_logfile + ntfs_is_logfile_clean). Com isso
 * prevê o que o ntfs-3g.probe --readwrite daria e se o NTFS Oficial montaria com gravação. Mostra também as flags de
 * $Volume (VOLUME_IS_DIRTY = 0x0001, a marca de "conferir com o chkdsk"), que a libntfs-3g ignora de propósito.
 *
 * Criado em 19/10/2026 para os discos reais do Hackintosh (docs/planos/KEXT_SO_CARREGA_NO_MACOS_27_2026-10-19.md).
 * Conferido numa imagem: o SHA-256 do dispositivo fica igual antes e depois.
 *
 * Compilar (depois de bash scripts/compilar.sh; troque x86_64 por arm64 no chip Apple):
 *   R=build/src-x86_64/ntfs-3g
 *   clang -std=gnu17 -O2 -Wall -arch x86_64 -DHAVE_CONFIG_H -I$R -I$R/include/ntfs-3g \
 *       scripts/diagnostico/verificar_disco.c $R/libntfs-3g/.libs/libntfs-3g.a -framework CoreFoundation \
 *       -o build/diagnostico/verificar_disco
 *
 * Usar (root): sudo build/diagnostico/verificar_disco /dev/rdisk0s2 [...]
 *   Pelo /dev/rdiskN: com o volume montado (pela Apple ou por nós) o dispositivo de bloco /dev/diskN dá
 *   "Resource busy"; o de caractere abre (a libntfs-3g com os nossos patches lê alinhado ao setor).
 */
#include "config.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "volume.h"
#include "inode.h"
#include "attrib.h"
#include "logfile.h"
#include "logging.h"

static void verificar(const char *dispositivo)
{
    printf("== %s\n", dispositivo);
    ntfs_volume *vol = ntfs_mount(dispositivo, NTFS_MNT_RDONLY);
    if (!vol) {
        printf("   não abriu (só leitura): %s\n", strerror(errno));
        return;
    }
    printf("   rótulo: \"%s\"  NTFS %d.%d  flags do volume: 0x%04x%s\n", vol->vol_name ? vol->vol_name : "",
           vol->major_ver, vol->minor_ver, le16_to_cpu(vol->flags),
           (vol->flags & VOLUME_IS_DIRTY) ? " (DIRTY)" : "");

    int hiber = ntfs_volume_check_hiberfile(vol, 0);
    int erro_hiber = errno;
    printf("   hibernação: %s\n", hiber < 0 ? (erro_hiber == EPERM ? "SIM (hiberfil.sys ativo)" : "erro ao ler") : "não");

    const char *journal = "erro ao ler";
    ntfs_inode *ni = ntfs_inode_open(vol, FILE_LogFile);
    if (ni) {
        ntfs_attr *na = ntfs_attr_open(ni, AT_DATA, AT_UNNAMED, 0);
        if (na) {
            RESTART_PAGE_HEADER *rp = NULL;
            BOOL ok = ntfs_check_logfile(na, &rp) && ntfs_is_logfile_clean(na, rp);
            if (rp && le16_to_cpu(rp->major_ver) == 2 && le16_to_cpu(rp->minor_ver) == 0)
                journal = "versão 2.0 (cache do Windows / inicialização rápida)";
            else
                journal = ok ? "limpo" : "sujo (Windows não desmontou direito)";
            free(rp);
            ntfs_attr_close(na);
        }
        ntfs_inode_close(ni);
    }
    printf("   journal: %s\n", journal);

    const char *previsao;
    if (hiber < 0 && erro_hiber == EPERM) previsao = "probe --readwrite = 14 (hibernado) -> NTFS Oficial monta SÓ LEITURA";
    else if (strncmp(journal, "versão 2.0", 10) == 0) previsao = "probe --readwrite = 14 (cache do Windows) -> SÓ LEITURA";
    else if (strncmp(journal, "sujo", 4) == 0) previsao = "probe --readwrite = 15 -> replay do journal (ou SÓ LEITURA com EnableAutomaticRecovery = 0)";
    else if (strcmp(journal, "limpo") == 0) previsao = "probe --readwrite = 0 -> NTFS Oficial monta COM GRAVAÇÃO";
    else previsao = "indefinido (erro ao ler)";
    printf("   previsão: %s\n", previsao);
    ntfs_umount(vol, FALSE);
}

int main(int argc, char *argv[])
{
    ntfs_log_set_handler(ntfs_log_handler_null);
    for (int i = 1; i < argc; i++) verificar(argv[i]);
    return 0;
}
