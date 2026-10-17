/*
 * Roda um programa auxiliar (driver, ntfs-3g.probe, ntfsls...) e devolve o código de saída.
 *
 * A saída vai para um arquivo temporário, não para um pipe: o driver deixa um processo em segundo plano
 * (o daemon do FUSE) que herda a saída. Com pipe, quem lê esperaria esse processo terminar, ou seja,
 * até desmontar. O tuxera_ntfs_wait também não captura a saída do driver: faz fork + execvp e herda os
 * descritores (REA, docs/design/REFERENCIA_TUXERA.md seção 12).
 */
#include "comum.h"

#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

int executar(char *const argv[], char *saida, size_t tamanho)
{
    char modelo[] = "/tmp/" NOME ".XXXXXX";
    int fd_saida = -1;
    posix_spawn_file_actions_t acoes;
    posix_spawn_file_actions_init(&acoes);
    posix_spawn_file_actions_addopen(&acoes, STDIN_FILENO, "/dev/null", O_RDONLY, 0);

    if (saida && tamanho > 0) {
        saida[0] = '\0';
        fd_saida = mkstemp(modelo);
        if (fd_saida < 0) return -1;
        unlink(modelo);                      /* some sozinho quando ninguém mais usar */
        posix_spawn_file_actions_adddup2(&acoes, fd_saida, STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&acoes, fd_saida, STDERR_FILENO);
    } else {
        posix_spawn_file_actions_addopen(&acoes, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
        posix_spawn_file_actions_addopen(&acoes, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    }

    pid_t pid;
    int r = posix_spawn(&pid, argv[0], &acoes, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&acoes);
    if (r != 0) {
        if (fd_saida >= 0) close(fd_saida);
        registro_erro("não consegui executar %s: %s", argv[0], strerror(r));
        return -1;
    }

    int estado;
    while (waitpid(pid, &estado, 0) < 0) {
        if (errno != EINTR) {
            if (fd_saida >= 0) close(fd_saida);
            return -1;
        }
    }

    if (fd_saida >= 0) {
        ssize_t n = pread(fd_saida, saida, tamanho - 1, 0);
        saida[n > 0 ? n : 0] = '\0';
        close(fd_saida);
    }
    return WIFEXITED(estado) ? WEXITSTATUS(estado) : -1;
}
