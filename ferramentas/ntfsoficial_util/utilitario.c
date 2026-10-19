/*
 * Utilitário de Disco (Primeiros Socorros e Apagar): verificar, reparar e formatar.
 * Mesmas opções e códigos de saída do tuxera_ntfs.util / newfs_tuxera_ntfs (REA, tux_util.c):
 *   ntfsoficial.util -v <disco>        verificar   (FSVerificationArguments)   0 = ok, 8 = falhou
 *   ntfsoficial.util -q                verificar rápido: o Tuxera responde 0 sem checar nada (_op_quick_verify)
 *   ntfsoficial.util -r|-y <disco>     reparar     (FSRepairArguments)         0 = ok, 8 = falhou
 *   newfs_ntfsoficial [-v rótulo] <disco>   formatar (FSFormatExecutable)      código do mkntfs
 *   sem dispositivo = uso errado = 250 (0xfa, o mesmo que o Tuxera)
 * O dispositivo vem como "disk4s1" ou "/dev/rdisk4s1"; vira sempre /dev/diskNsM (o _get_device do Tuxera).
 */
#include "comum.h"

#include <stdio.h>
#include <string.h>

/* "disk4s1", "/dev/disk4s1" ou "/dev/rdisk4s1" -> "/dev/disk4s1" */
static void dispositivo_de(const char *arg, char *destino, size_t tamanho)
{
    if (strncmp(arg, "/dev/", 5) == 0) strlcpy(destino, arg, tamanho);
    else snprintf(destino, tamanho, "/dev/%s", arg);
    char *barra = strrchr(destino, '/');
    if (barra && strncmp(barra, "/rdisk", 6) == 0) {
        char resto[128];
        strlcpy(resto, barra + 2, sizeof(resto));      /* "disk4s1" */
        snprintf(barra + 1, tamanho - (size_t)(barra + 1 - destino), "%s", resto);
    }
}

/* Último argumento que não começa com "-" (o Tuxera usa o 1º depois da opção; assim aceita -r -y disco). */
static const char *achar_disco(int argc, char *argv[])
{
    for (int i = argc - 1; i >= 0; i--) {
        if (argv[i][0] != '-') return argv[i];
    }
    return NULL;
}

static void mostrar(const char *titulo, const char *saida)
{
    /* O Utilitário de Disco mostra o que o programa imprime; só as linhas que ajudam */
    if (saida[0]) printf("%s:\n%s%s", titulo, saida, saida[strlen(saida) - 1] == '\n' ? "" : "\n");
}

static int verificar(const char *dispositivo)
{
    char saida[4096];
    int codigo = 0, falhas = 0;

    /* 1) o NTFS-3G aceitaria montar com gravação? (journal limpo, sem hibernação) */
    sujeira_t s = recuperar_classificar(dispositivo, &codigo, saida, sizeof(saida));
    registro("verificar %s: probe = %d", dispositivo, codigo);
    if (codigo != 0) {
        falhas++;
        printf("O volume não pode ser montado com gravação (ntfs-3g.probe = %d).\n", codigo);
        mostrar("ntfs-3g.probe", saida);
    }
    /* 2) se o motivo é o journal, o reparo conseguiria reaplicá-lo? (-n não grava nada). Só faz sentido
     * quando o probe disse 14/15: com o journal apagado ("wiped out", normal depois de formatar) o
     * ntfsrecover -n sai com 1 mesmo estando tudo certo. */
    if (s == SUJEIRA_JOURNAL || s == SUJEIRA_CACHE_WINDOWS) {
        int r = recuperar_journal(dispositivo, true, saida, sizeof(saida));
        printf("Journal do Windows: %s\n", r == 0 ? "pode ser reaplicado (Reparar)"
                                                  : "não pode ser reaplicado sem perder dados");
        mostrar("ntfsrecover -n", saida);
    } else if (s == SUJEIRA_HIBERNADO) {
        printf("O Windows está hibernado neste disco (hiberfil.sys).\n");
    }
    /* 3) estrutura: boot, $MFT, $MFTMirr, $UpCase (-n: não grava) */
    char *fix[] = { NTFSFIX, "-n", (char *)dispositivo, NULL };
    int r = executar(fix, saida, sizeof(saida));
    registro("verificar %s: ntfsfix -n = %d", dispositivo, r);
    if (r != 0) {
        falhas++;
        printf("ntfsfix -n encontrou problemas (código %d).\n", r);
        mostrar("ntfsfix -n", saida);
    }
    if (falhas == 0) printf("O volume NTFS parece estar em ordem.\n");
    return falhas == 0 ? 0 : SAIDA_VERIFICACAO_FALHOU;
}

static int reparar(const char *dispositivo)
{
    char saida[4096];
    int codigo = 0;

    sujeira_t s = recuperar_classificar(dispositivo, &codigo, saida, sizeof(saida));
    registro("reparar %s: probe = %d", dispositivo, codigo);
    if (s == SUJEIRA_HIBERNADO) {
        /* o ntfsfix zeraria o journal de um Windows hibernado e o volume seria corrompido ao acordar */
        printf("O Windows está hibernado neste disco. Nada foi alterado: ligue o Windows e desligue-o por inteiro.\n");
        return SAIDA_VERIFICACAO_FALHOU;
    }
    if (s == SUJEIRA_JOURNAL || s == SUJEIRA_CACHE_WINDOWS) {
        /* 1) reaplica o que o Windows confirmou e não gravou. Se falhar, para: o ntfsfix zera o journal
         * ($LogFile) e jogaria essas transações fora. */
        int r = recuperar_journal(dispositivo, false, saida, sizeof(saida));
        mostrar("ntfsrecover", saida);
        if (r != 0) {
            printf("Não foi possível reaplicar o journal do Windows. Nada foi alterado. Conecte o disco num Windows "
                   "e rode \"chkdsk /f\".\n");
            return SAIDA_VERIFICACAO_FALHOU;
        }
        printf("Journal do Windows reaplicado.\n");
    }
    /* 2) estrutura, só se precisar: o ntfsfix -n sai com 1 quando acha erro ("error present and not fixed",
     * ntfsfix.c). Como o -a ("Repair volume only if needed") do ntfsck do Tuxera (REA, tux_ntfsck): num volume
     * em ordem, o ntfsfix só deixaria a marca de "sujo" e o Windows rodaria o chkdsk à toa (visto em 18/10/2026,
     * Volume Flags 0x0001 DIRTY depois de reparar um disco limpo). */
    char *teste[] = { NTFSFIX, "-n", (char *)dispositivo, NULL };
    int r = executar(teste, saida, sizeof(saida));
    registro("reparar %s: ntfsfix -n = %d", dispositivo, r);
    if (r == 0) {
        printf("Nenhum problema de estrutura encontrado; nada a reparar.\n");
        return 0;
    }
    /* Sem -d: o ntfsfix deixa o volume marcado para o chkdsk do Windows conferir no próximo uso; limpar esse
     * indicador esconderia o problema. */
    char *fix[] = { NTFSFIX, (char *)dispositivo, NULL };
    r = executar(fix, saida, sizeof(saida));
    registro("reparar %s: ntfsfix = %d", dispositivo, r);
    mostrar("ntfsfix", saida);
    return r == 0 ? 0 : SAIDA_VERIFICACAO_FALHOU;
}

int utilitario_verificar_reparar(char operacao, int argc, char *argv[])
{
    if (operacao == 'q') {
        /* O Tuxera devolve 0 sem checar nada (_op_quick_verify). Aqui, no máximo, vê se não é hibernação. */
        registro("verificar rápido: ok (nenhuma checagem, como o Tuxera)");
        return 0;
    }
    const char *arg = achar_disco(argc, argv);
    if (!arg) {
        fprintf(stderr, "uso: %s%s <disco>\n", NOME ".util ", operacao == 'v' ? "-v" : "-r");
        return RESPOSTA_INVALIDO;
    }
    char dispositivo[128];
    dispositivo_de(arg, dispositivo, sizeof(dispositivo));
    return operacao == 'v' ? verificar(dispositivo) : reparar(dispositivo);
}

/* newfs_ntfsoficial [-v rótulo] <disco>  ->  mkntfs -f [-L rótulo] <disco>  (sem -F, como o Tuxera) */
int utilitario_formatar(int argc, char *argv[])
{
    const char *rotulo = NULL, *arg = NULL;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0 && i + 1 < argc) rotulo = argv[++i];
        else if (i == argc - 1) arg = argv[i];                  /* o último argumento é o disco */
        else registro("formatar: opção ignorada \"%s\"", argv[i]);
    }
    if (!arg || arg[0] == '-') {
        fprintf(stderr, "uso: newfs_" NOME " [-v <rótulo>] <disco>\n");
        return RESPOSTA_INVALIDO;
    }
    char dispositivo[128];
    dispositivo_de(arg, dispositivo, sizeof(dispositivo));

    printf("Creating NTFS file system on %s...\n", dispositivo);
    char saida[4096];
    char *com_rotulo[] = { MKNTFS, "-f", "-L", (char *)rotulo, dispositivo, NULL };
    char *sem_rotulo[] = { MKNTFS, "-f", dispositivo, NULL };
    int r = executar(rotulo ? com_rotulo : sem_rotulo, saida, sizeof(saida));
    registro("formatar %s%s%s: mkntfs = %d", dispositivo, rotulo ? " rótulo " : "", rotulo ? rotulo : "", r);
    if (r == 0) {
        printf("File system created.\n");
    } else {
        printf("Could not create NTFS file system!\n");
        fprintf(stderr, "%s", saida);
    }
    return r < 0 ? 1 : r;
}
