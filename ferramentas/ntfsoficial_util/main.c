/*
 * Ponto de entrada: escolhe a operação pelo nome com que foi chamado (como o tuxera_ntfs.util).
 */
#include "comum.h"

#include <libgen.h>
#include <libproc.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

/* Registra cada chamada (quem chamou, usuário, argumentos): mostra se o macOS está usando o detector. */
static void registrar_chamada(int argc, char *argv[])
{
    char pai[64] = "?", args[512] = "";
    proc_name(getppid(), pai, sizeof(pai));
    for (int i = 1; i < argc; i++) {
        strlcat(args, " ", sizeof(args));
        strlcat(args, argv[i], sizeof(args));
    }
    gid_t grupos[64];
    int n = getgroups(64, grupos);
    char lista[256] = "";
    for (int i = 0; i < n; i++) {
        char g[16];
        snprintf(g, sizeof(g), "%s%u", i ? "," : "", grupos[i]);
        strlcat(lista, g, sizeof(lista));
    }
    registro("chamado:%s (uid %d, grupos %s, pai %s)", args, getuid(), lista, pai);
}

static int uso(const char *nome)
{
    fprintf(stderr,
        "uso: %s -p <disco> <removable|fixed> <readonly|writable>   (detecção)\n"
        "     mount_" NOME " [-o opções] <dispositivo> <ponto>          (montagem)\n"
        "     %s -v|-r <disco>                                     (verificar | reparar)\n"
        "     newfs_" NOME " [-v rótulo] <disco>                       (formatar)\n", nome, nome);
    return RESPOSTA_INVALIDO;
}

int main(int argc, char *argv[])
{
    char copia[1024];
    strlcpy(copia, argv[0], sizeof(copia));
    const char *nome = basename(copia);

    preferencias_t p;
    preferencias_ler(&p);
    registro_iniciar(p.depurar);
    registrar_chamada(argc, argv);

    if (strcmp(nome, "mount_" NOME) == 0) {
        return montar(argc, argv);
    }
    if (strcmp(nome, "newfs_" NOME) == 0) {
        return utilitario_formatar(argc, argv);
    }
    if (argc >= 3 && strcmp(argv[1], "-p") == 0) {
        return detectar(argc, argv);
    }
    if (argc >= 2 && strcmp(argv[1], "-k") == 0) {
        /* -k: pedido de UUID do volume. Sem UUID (o NTFS não tem um no formato que o macOS espera). */
        return RESPOSTA_NAO_RECONHECIDO;
    }
    /* Utilitário de Disco (FSVerificationArguments -v, FSRepairArguments -r): as opções do tuxera_ntfs.util.
     * "-r -q" / "-y -q" é verificação rápida (tux_util.c). */
    if (argc >= 2 && strcmp(argv[1], "-v") == 0) {
        return utilitario_verificar_reparar('v', argc - 2, argv + 2);
    }
    if (argc >= 2 && strcmp(argv[1], "-q") == 0) {
        return utilitario_verificar_reparar('q', argc - 2, argv + 2);
    }
    if (argc >= 2 && (strcmp(argv[1], "-r") == 0 || strcmp(argv[1], "-y") == 0)) {
        bool rapido = argc >= 3 && strcmp(argv[2], "-q") == 0;
        return utilitario_verificar_reparar(rapido ? 'q' : 'r', argc - 2, argv + 2);
    }
    return uso(nome);
}
