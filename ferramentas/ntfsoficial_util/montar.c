/*
 * Montagem: mount_ntfsoficial [-o opções]... <dispositivo> <ponto de montagem>
 * (chamado pelo macOS com o FSMountExecutable do pacote, ou à mão)
 *
 * Opções passadas ao driver, como o _op_mount do Tuxera (REA):
 *   local, iosize (1 MiB), uid/gid da pessoa, nfconv conforme preferência e arquivo de controle,
 *   modo de xattr (XattrMode), recover/norecover (EnableAutomaticRecovery), volname.
 * Diferença do Tuxera: hibernado (14) ou desmontado sujo (15) não abre janela de "forçar" (que apaga a
 * hibernação); monta só para leitura e avisa. Nada de remove_hiberfile automático.
 */
#include "comum.h"

#include <libgen.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <unistd.h>

#define MAX_OPCOES 4096

static void juntar(char *destino, const char *item)
{
    if (destino[0]) strlcat(destino, ",", MAX_OPCOES);
    strlcat(destino, item, MAX_OPCOES);
}

/* Separa as opções que o macOS manda (-o a,b -o c) em: só leitura? + o resto, repassado ao FUSE. */
static void opcoes_do_sistema(const char *lista, char *repassar, bool *so_leitura)
{
    char copia[MAX_OPCOES];
    strlcpy(copia, lista, sizeof(copia));
    for (char *o = strtok(copia, ","); o; o = strtok(NULL, ",")) {
        if (strcmp(o, "rdonly") == 0 || strcmp(o, "ro") == 0) *so_leitura = true;
        else if (strcmp(o, "rw") == 0) *so_leitura = false;
        else juntar(repassar, o);
    }
}

/* Dono dos arquivos: quem chamou; se for root (montagem pelo sistema), quem está logado na tela. */
static void dono(uid_t *uid, gid_t *gid)
{
    *uid = getuid();
    *gid = getgid();
    struct stat st;
    if (*uid == 0 && stat("/dev/console", &st) == 0 && st.st_uid != 0) {
        *uid = st.st_uid;
        *gid = st.st_gid;
    }
}

static void montar_opcoes(char *o, const preferencias_t *p, const controle_t *c, const char *ponto,
                          const char *sistema, bool so_leitura)
{
    char item[512];
    uid_t uid; gid_t gid;
    dono(&uid, &gid);

    o[0] = '\0';
    juntar(o, "local");
    snprintf(item, sizeof(item), "iosize=%ld", p->iosize); juntar(o, item);
    snprintf(item, sizeof(item), "uid=%u,gid=%u", uid, gid); juntar(o, item);
    if (geteuid() == 0) juntar(o, "allow_other");   /* montado pelo sistema: a pessoa precisa acessar */
    juntar(o, "windows_names");                     /* não deixa criar nomes que o Windows recusa */
    juntar(o, (p->normalizacao && !c->sem_normalizacao) ? "nfconv" : "nonfconv");
    switch (p->modo_xattr) {
        case 0:  juntar(o, "streams_interface=none,noapplexattr,noappledouble"); break;
        case 1:  juntar(o, "streams_interface=none,auto_xattr"); break;
        default: juntar(o, "streams_interface=openxattr,native_xattr"); break;
    }
    juntar(o, p->recuperacao ? "recover" : "norecover");
    /* Sem isto o kext do osxfuse monta síncrono (fuse_vfsops.c: sem FUSE_MOPT_NO_SYNCWRITES liga
     * MNT_SYNCHRONOUS): cada gravação espera o disco, 21 MB/s no SSD USB (17/10/2026). O kext do Tuxera
     * monta assíncrono sem precisar de opção (REA: vfs_clearflags 0x2 + vfs_setflags 0x40 em 0xad2c). */
    if (p->cache && !c->sem_cache) juntar(o, "nosyncwrites");

    char copia[1024];
    strlcpy(copia, ponto, sizeof(copia));
    snprintf(item, sizeof(item), "volname=%s", basename(copia)); juntar(o, item);
    if (so_leitura) juntar(o, "ro");
    if (sistema[0]) juntar(o, sistema);
}

/* Espera o volume aparecer de verdade no ponto de montagem (o driver retorna antes de o FUSE terminar de
 * montar). O tuxera_ntfs_wait faz o mesmo esperando a notificação "...unotifications.mounted"; aqui a
 * confirmação é direta pelo statfs: tipo ntfsoficial no próprio ponto. */
static bool esperar_montado(const char *ponto, int segundos)
{
    char real[PATH_MAX];
    if (!realpath(ponto, real)) strlcpy(real, ponto, sizeof(real));
    for (int i = 0; i < segundos * 10; i++) {
        struct statfs s;
        if (statfs(real, &s) == 0 && strcmp(s.f_fstypename, NOME) == 0 && strcmp(s.f_mntonname, real) == 0) {
            return true;
        }
        usleep(100000);
    }
    return false;
}

/* Avisa por que o disco ficou só para leitura. hibernado = true: Windows hibernado/inicialização rápida;
 * false: desmontado sujo (journal pendente). */
/* Guarda o motivo do "só leitura" para o app NTFS Oficial mostrar (contrato:
 * ESTADO_DIR/<disco>.motivo com "hibernado" ou "sujo"; sem arquivo = montado normalmente). */
#define ESTADO_DIR "/private/var/tmp/" NOME
static void gravar_motivo(const char *dispositivo, const char *motivo)
{
    char caminho[256];
    const char *bsd = strrchr(dispositivo, '/');
    bsd = bsd ? bsd + 1 : dispositivo;
    if (strncmp(bsd, "rdisk", 5) == 0) bsd++;            /* sempre pelo nome do dispositivo de bloco */
    mkdir(ESTADO_DIR, 01777);
    chmod(ESTADO_DIR, 01777);
    snprintf(caminho, sizeof(caminho), ESTADO_DIR "/%s.motivo", bsd);
    if (!motivo) { unlink(caminho); return; }
    FILE *f = fopen(caminho, "w");
    if (f) { fputs(motivo, f); fclose(f); chmod(caminho, 0644); }
}

static void avisar_so_leitura(const char *ponto, bool hibernado)
{
    char copia[1024], msg[1024];
    strlcpy(copia, ponto, sizeof(copia));
    snprintf(msg, sizeof(msg),
        hibernado
        ? "O disco \"%s\" está com o Windows hibernado (ou com a \"Inicialização rápida\" ligada).\n\n"
          "Ele foi montado só para leitura, para não perder dados. Para gravar: no Windows, desligue "
          "a Inicialização rápida e use Desligar (não Hibernar)."
        : "O disco \"%s\" não foi desconectado direito da última vez.\n\n"
          "Ele foi montado só para leitura, para não piorar. Para gravar: conecte num Windows e rode "
          "\"chkdsk /f\", ou ejete com segurança antes de tirar o cabo.",
        basename(copia));
    aviso_mostrar("NTFS Oficial: montado só para leitura", msg);
}

/* O NTFS-3G cai para só leitura sozinho (e devolve 0) quando o disco está hibernado ou sujo, escrevendo
 * "Falling back to read-only" (visto em 17/10/2026). Detecta isso pelo volume montado + texto do driver. */
static bool caiu_para_so_leitura(const char *ponto)
{
    struct statfs s;
    return statfs(ponto, &s) == 0 && (s.f_flags & MNT_RDONLY);
}

static int rodar_driver(const char *dispositivo, const char *ponto, const char *opcoes, char *saida, size_t t)
{
    /* EnableRawDevices: /dev/diskN -> /dev/rdiskN (sem o cache de blocos do macOS, que picota as gravações:
     * 21 MB/s num SSD USB). O Tuxera faz o mesmo com aligned_io (REA); o nosso alinhamento é o patch 0002 do
     * driver, e o patch 0005 mantém /dev/diskN como origem do volume para o Finder. */
    char raw[128];
    preferencias_t p;
    preferencias_ler(&p);
    if (p.raw && strncmp(dispositivo, "/dev/disk", 9) == 0) {
        snprintf(raw, sizeof(raw), "/dev/r%s", dispositivo + 5);
        dispositivo = raw;
    }
    char *argv[] = { DRIVER, (char *)dispositivo, (char *)ponto, "-o", (char *)opcoes, NULL };
    registro("montar: %s %s %s -o %s", DRIVER, dispositivo, ponto, opcoes);
    return executar(argv, saida, t);
}

int montar(int argc, char *argv[])
{
    preferencias_t p;
    preferencias_ler(&p);

    char sistema[MAX_OPCOES] = "";
    bool so_leitura = false;
    const char *pos[2] = { NULL, NULL };
    int n = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            opcoes_do_sistema(argv[++i], sistema, &so_leitura);
        } else if (strncmp(argv[i], "-o", 2) == 0 && argv[i][2]) {
            opcoes_do_sistema(argv[i] + 2, sistema, &so_leitura);
        } else if (argv[i][0] != '-' && n < 2) {
            pos[n++] = argv[i];
        }
    }
    if (n != 2) {
        fprintf(stderr, "uso: mount_" NOME " [-o opções] <dispositivo> <ponto de montagem>\n");
        return 1;
    }
    const char *dispositivo = pos[0], *ponto = pos[1];

    controle_t c;
    controle_ler(dispositivo, &c);

    char opcoes[MAX_OPCOES], saida[4096];
    montar_opcoes(opcoes, &p, &c, ponto, sistema, so_leitura);
    int r = rodar_driver(dispositivo, ponto, opcoes, saida, sizeof(saida));

    if ((r == NTFS_HIBERNADO || r == NTFS_DESMONTAGEM_SUJA) && !so_leitura) {
        registro("montar %s: código %d, montando só para leitura", dispositivo, r);
        montar_opcoes(opcoes, &p, &c, ponto, sistema, true);
        int r2 = rodar_driver(dispositivo, ponto, opcoes, saida, sizeof(saida));
        if (r2 == 0 && esperar_montado(ponto, 10)) {
            gravar_motivo(dispositivo, r == NTFS_HIBERNADO ? "hibernado" : "sujo");
            avisar_so_leitura(ponto, r == NTFS_HIBERNADO);
            return 0;
        }
        r = r2;
    }
    if (r != 0) {
        registro_erro("montar %s em %s falhou (código %d): %s", dispositivo, ponto, r, saida);
        fprintf(stderr, "%s", saida);
        return r > 0 ? r : 1;
    }
    if (!esperar_montado(ponto, 10)) {
        registro_erro("montar %s em %s: o driver retornou 0 mas o volume não apareceu em 10 s. Saída: %s",
                      dispositivo, ponto, saida);
        fprintf(stderr, "%s", saida);
        return 1;
    }
    if (!so_leitura && caiu_para_so_leitura(ponto)) {
        bool hibernado = strcasestr(saida, "hibernat") != NULL;
        registro("montar %s em %s: o driver caiu para só leitura (%s)", dispositivo, ponto,
                 hibernado ? "hibernado" : "desmontado sujo");
        gravar_motivo(dispositivo, hibernado ? "hibernado" : "sujo");
        avisar_so_leitura(ponto, hibernado);
        return 0;
    }
    gravar_motivo(dispositivo, NULL);
    registro("montar %s em %s: ok (volume confirmado no statfs)", dispositivo, ponto);
    return 0;
}
