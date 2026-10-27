/*
 * Montagem: mount_ntfsoficial [-o opções]... <dispositivo> <ponto de montagem>
 * (chamado pelo macOS com o FSMountExecutable do pacote, ou à mão)
 *
 * Opções passadas ao driver, como o _op_mount do Tuxera (REA):
 *   local, iosize (1 MiB), uid/gid 99 (cada pessoa vê os arquivos como seus), nfconv conforme preferência e
 *   arquivo de controle, modo de xattr (XattrMode), sfmconv/nosfmconv (EnableSFMConversions), volname.
 *
 * Disco sujo (probe 14/15): com EnableAutomaticRecovery (padrão 1, como o Tuxera) roda o ntfsrecover, que
 * reaplica o journal do Windows, e monta com gravação. O driver sempre recebe `norecover`: a opção `recover`
 * do NTFS-3G só zera o journal (descarta as transações), então nunca é usada; depois do replay o journal já
 * está limpo (recuperar.c). Se o replay falhar, for cache do Windows (journal 2.0) ou hibernação de verdade:
 * monta só para leitura e avisa. Diferença do Tuxera: nada de janela de "forçar" (que apaga a hibernação) nem
 * de remove_hiberfile automático.
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

/* A opção (ex.: "uid=") veio nas opções do macOS? */
static bool tem_opcao(const char *lista, const char *prefixo)
{
    char copia[MAX_OPCOES];
    strlcpy(copia, lista, sizeof(copia));
    for (char *o = strtok(copia, ","); o; o = strtok(NULL, ",")) {
        if (strncmp(o, prefixo, strlen(prefixo)) == 0) return true;
    }
    return false;
}

static void montar_opcoes(char *o, const preferencias_t *p, const controle_t *c, const char *ponto,
                          const char *sistema, bool so_leitura)
{
    char item[512];

    o[0] = '\0';
    juntar(o, "local");
    snprintf(item, sizeof(item), "iosize=%ld", p->iosize); juntar(o, item);
    /* Dono: 99 (DONO_DESCONHECIDO), a não ser que o macOS mande o seu. Como o _op_mount do Tuxera, que só passa
     * adaptiveuid/adaptivegid sem uid=/gid= do sistema (REA). Antes era o dono de /dev/console, que no boot
     * (antes do login) é root ou _windowserver, e o git recusava repositório nesses discos (19/10/2026). */
    if (!tem_opcao(sistema, "uid=")) {
        snprintf(item, sizeof(item), "uid=%d", DONO_DESCONHECIDO); juntar(o, item);
    }
    if (!tem_opcao(sistema, "gid=")) {
        snprintf(item, sizeof(item), "gid=%d", DONO_DESCONHECIDO); juntar(o, item);
    }
    if (geteuid() == 0) juntar(o, "allow_other");   /* montado pelo sistema: a pessoa precisa acessar */
    /* Nomes com : * ? " < > | e afins. O Tuxera usa o estilo SFM (Services for Macintosh: grava U+F021... no
     * lugar) e NÃO passa windows_names (REA); sem SFM, windows_names recusa criar esses nomes. */
    if (p->sfm) {
        juntar(o, "sfmconv");
    } else {
        juntar(o, "nosfmconv");
        juntar(o, "windows_names");
    }
    juntar(o, (p->normalizacao && !c->sem_normalizacao) ? "nfconv" : "nonfconv");
    switch (p->modo_xattr) {
        case 0:  juntar(o, "streams_interface=none,noapplexattr,noappledouble"); break;
        case 1:  juntar(o, "streams_interface=none,auto_xattr"); break;
        default: juntar(o, "streams_interface=openxattr,native_xattr"); break;
    }
    juntar(o, "norecover");                         /* o replay é feito antes, pelo ntfsrecover (ver acima) */
    /* Sem isto o kext do osxfuse monta síncrono (fuse_vfsops.c: sem FUSE_MOPT_NO_SYNCWRITES liga
     * MNT_SYNCHRONOUS): cada gravação espera o disco, 21 MB/s no SSD USB (17/10/2026). O kext do Tuxera
     * também monta SÍNCRONO: o ramo assíncrono dele exige nosyncwrites, que nenhum programa do Tuxera passa
     * (REA). O nosso monta assíncrono por escolha, pelo desempenho (docs/modulos/desempenho.md). */
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

/* Guarda o motivo do "só leitura" para o app NTFS Oficial mostrar (contrato:
 * ESTADO_DIR/<disco>.motivo com "hibernado", "cache-windows" ou "sujo"; sem arquivo = montado normalmente). */
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

/* Por que o disco ficou só para leitura (muda o texto do aviso e o que o app lê no arquivo .motivo). */
typedef enum {
    MOTIVO_HIBERNADO,          /* Windows hibernado (hiberfil.sys; com a Inicialização rápida, é o disco do Windows) */
    MOTIVO_CACHE_WINDOWS,      /* journal 2.0: Inicialização rápida nos outros discos (ou disco arrancado do Windows 8+) */
    MOTIVO_SUJO,               /* journal pendente e a recuperação automática está desligada */
    MOTIVO_RECUPERACAO_FALHOU  /* tentamos reaplicar o journal e não deu */
} motivo_t;

static const char *nome_do_motivo(motivo_t motivo)
{
    switch (motivo) {
        case MOTIVO_HIBERNADO: return "hibernado";
        case MOTIVO_CACHE_WINDOWS: return "cache-windows";
        default: return "sujo";
    }
}

/* Pela saída do driver que caiu para só leitura: "Windows is hibernated"/"Hibernated non-system partition"
 * (hiberfil.sys) ou "Metadata kept in Windows cache" (journal 2.0, volume.c). O aviso de queda diz
 * "hibernation", que não conta. */
static motivo_t motivo_pela_saida(const char *saida, motivo_t sem_mensagem)
{
    if (strcasestr(saida, "hibernated")) return MOTIVO_HIBERNADO;
    if (strcasestr(saida, "Windows cache")) return MOTIVO_CACHE_WINDOWS;
    return sem_mensagem;
}

static void avisar_so_leitura(const char *ponto, motivo_t motivo)
{
    char copia[1024], msg[1024];
    strlcpy(copia, ponto, sizeof(copia));
    const char *formato;
    switch (motivo) {
        case MOTIVO_HIBERNADO:
            formato = "O disco \"%s\" está com o Windows hibernado (ou com a \"Inicialização rápida\" ligada).\n\n"
                      "Ele foi montado só para leitura, para não perder dados. Para gravar: no Windows, desligue "
                      "a Inicialização rápida e use Desligar (não Hibernar).";
            break;
        case MOTIVO_CACHE_WINDOWS:
            formato = "O Windows foi desligado com a \"Inicialização rápida\" e deixou alterações do disco \"%s\" "
                      "guardadas no cache dele.\n\n"
                      "Ele foi montado só para leitura, para não perder dados. Para gravar: no Windows, use Reiniciar "
                      "(não Desligar) para vir ao Mac, ou desligue a Inicialização rápida (Prompt de Comando como "
                      "administrador: powercfg /h off) e use Desligar.";
            break;
        case MOTIVO_RECUPERACAO_FALHOU:
            formato = "O disco \"%s\" não foi desconectado direito da última vez e não consegui recuperar as "
                      "alterações pendentes do Windows.\n\n"
                      "Ele foi montado só para leitura, para não piorar. Para gravar: conecte num Windows e rode "
                      "\"chkdsk /f\", ou ejete com segurança antes de tirar o cabo.";
            break;
        default:
            formato = "O disco \"%s\" não foi desconectado direito da última vez.\n\n"
                      "Ele foi montado só para leitura, para não piorar. Para gravar: ligue a recuperação "
                      "automática nas preferências do NTFS Oficial, ou conecte num Windows e rode \"chkdsk /f\".";
            break;
    }
    snprintf(msg, sizeof(msg), formato, basename(copia));
    aviso_mostrar("NTFS Oficial: montado só para leitura", msg);
}

/* Antes de montar com gravação: o disco está sujo? Se estiver e a recuperação automática estiver ligada,
 * reaplica o journal. Devolve true se pode montar com gravação; false (e o motivo) se tem que ser só leitura.
 * O Tuxera faz o replay dentro do próprio driver; aqui o NTFS-3G recusa disco sujo, então o ntfsrecover roda
 * antes (recuperar.c explica os códigos). Nunca se passa `recover` ao driver sem o replay ter dado certo. */
static bool preparar_gravacao(const char *dispositivo, const preferencias_t *p, motivo_t *motivo)
{
    char saida[1024];
    int codigo = 0;
    sujeira_t s = recuperar_classificar(dispositivo, &codigo, saida, sizeof(saida));
    if (s == SUJEIRA_NENHUMA) return true;       /* 0, ou erro que o próprio driver vai explicar */

    registro("montar %s: probe = %d (%s)", dispositivo, codigo,
             s == SUJEIRA_HIBERNADO ? "hibernado" : s == SUJEIRA_JOURNAL ? "journal sujo" : "cache do Windows");
    if (s == SUJEIRA_HIBERNADO) {
        *motivo = MOTIVO_HIBERNADO;              /* nunca mexe no journal de um Windows hibernado */
        return false;
    }
    if (s == SUJEIRA_CACHE_WINDOWS) {
        /* O ntfsrecover recusa o 2.0 sem -k ("Fast restart mode detected"), e o -k jogaria fora o cache do
         * Windows: nem tenta. O Tuxera reaplica e grava; aqui fica só leitura (decisão de 27/10/2026,
         * docs/planos/CONFERENCIA_TUXERA_INICIALIZACAO_RAPIDA_2026-10-27.md). */
        *motivo = MOTIVO_CACHE_WINDOWS;
        return false;
    }
    if (!p->recuperacao) {
        registro("montar %s: EnableAutomaticRecovery desligado, só leitura", dispositivo);
        *motivo = MOTIVO_SUJO;
        return false;
    }
    char rec[1024];
    int r = recuperar_journal(dispositivo, false, rec, sizeof(rec));
    if (r != 0) {
        registro_erro("montar %s: o replay do journal falhou (ntfsrecover = %d): %s", dispositivo, r, rec);
        *motivo = MOTIVO_RECUPERACAO_FALHOU;
        return false;
    }
    /* Confere: o journal tem que ter ficado limpo, senão o driver cairia para só leitura de novo */
    if (recuperar_classificar(dispositivo, &codigo, saida, sizeof(saida)) != SUJEIRA_NENHUMA || codigo != 0) {
        registro_erro("montar %s: depois do replay o probe ainda diz %d: %s", dispositivo, codigo, saida);
        *motivo = MOTIVO_RECUPERACAO_FALHOU;
        return false;
    }
    registro("montar %s: journal do Windows reaplicado, montando com gravação", dispositivo);
    return true;
}

/* O NTFS-3G cai para só leitura sozinho (e devolve 0) quando o disco está hibernado ou sujo, escrevendo
 * "Falling back to read-only" (visto em 17/10/2026). Detecta isso pelo volume montado. Agora é rede de
 * segurança: preparar_gravacao() já separa esses casos antes de chamar o driver. */
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

    /* Disco sujo/hibernado: reaplica o journal se der; senão a montagem sai só para leitura */
    motivo_t motivo = MOTIVO_SUJO;
    bool forcado_so_leitura = false;
    if (!so_leitura && !preparar_gravacao(dispositivo, &p, &motivo)) {
        so_leitura = true;
        forcado_so_leitura = true;
    }

    char opcoes[MAX_OPCOES], saida[4096];
    montar_opcoes(opcoes, &p, &c, ponto, sistema, so_leitura);
    int r = rodar_driver(dispositivo, ponto, opcoes, saida, sizeof(saida));

    if ((r == NTFS_HIBERNADO || r == NTFS_DESMONTAGEM_SUJA) && !so_leitura) {
        registro("montar %s: código %d, montando só para leitura", dispositivo, r);
        motivo_t m = r == NTFS_HIBERNADO ? motivo_pela_saida(saida, MOTIVO_HIBERNADO) : MOTIVO_SUJO;
        montar_opcoes(opcoes, &p, &c, ponto, sistema, true);
        int r2 = rodar_driver(dispositivo, ponto, opcoes, saida, sizeof(saida));
        if (r2 == 0 && esperar_montado(ponto, ESPERA_MONTAGEM_SEGUNDOS)) {
            gravar_motivo(dispositivo, nome_do_motivo(m));
            avisar_so_leitura(ponto, m);
            return 0;
        }
        r = r2;
    }
    if (r != 0) {
        registro_erro("montar %s em %s falhou (código %d): %s", dispositivo, ponto, r, saida);
        fprintf(stderr, "%s", saida);
        return r > 0 ? r : 1;
    }
    if (!esperar_montado(ponto, ESPERA_MONTAGEM_SEGUNDOS)) {
        registro_erro("montar %s em %s: o driver retornou 0 mas o volume não apareceu em %d s. Saída: %s",
                      dispositivo, ponto, ESPERA_MONTAGEM_SEGUNDOS, saida);
        fprintf(stderr, "%s", saida);
        return 1;
    }
    if (forcado_so_leitura) {
        registro("montar %s em %s: montado só para leitura (%s)", dispositivo, ponto, nome_do_motivo(motivo));
        gravar_motivo(dispositivo, nome_do_motivo(motivo));
        avisar_so_leitura(ponto, motivo);
        return 0;
    }
    if (!so_leitura && caiu_para_so_leitura(ponto)) {
        motivo_t m = motivo_pela_saida(saida, MOTIVO_SUJO);
        registro("montar %s em %s: o driver caiu para só leitura (%s)", dispositivo, ponto, nome_do_motivo(m));
        gravar_motivo(dispositivo, nome_do_motivo(m));
        avisar_so_leitura(ponto, m);
        return 0;
    }
    gravar_motivo(dispositivo, NULL);
    registro("montar %s em %s: ok (volume confirmado no statfs)", dispositivo, ponto);
    return 0;
}
