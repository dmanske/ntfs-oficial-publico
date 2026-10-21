/*
 * Abre arquivos sem leitura e sem escrita, como o smbd (compartilhamento de arquivos do macOS) abre os discos NTFS
 * quando outro Mac os acessa pela rede. O smbd abre com O_EVTONLY | O_SYMLINK e tem o entitlement da política
 * IOPOL_VFS_DISALLOW_RW_FOR_O_EVTONLY, que faz o kernel tirar FREAD e FWRITE (open1, vfs_syscalls.c): o VNOP_OPEN
 * chega ao kext com 0x208000. Um programa nosso não pode ligar essa política (setiopolicy_np dá EPERM sem o
 * entitlement, kern_resource.c), então somamos O_EXEC: o FFLAGS do kernel não põe FREAD quando há O_EXEC, e o
 * VNOP_OPEN chega com 0x40208000, que cai no mesmo ramo do kext (fuse_filehandle_xlate_from_fflags).
 *
 * Com o kext 0.1.1 isso é panic ("What kind of a flag is this"): só rodar com o kext 0.1.2 ou mais novo carregado.
 * Quem chama é o scripts/testar-abrir-so-eventos.sh, que confere a versão antes.
 *
 * Para cada caminho, REPETICOES vezes: abre, confere que read() dá EBADF (prova de que chegou sem FREAD, ou seja, que o
 * teste passou pelo caminho do panic), fstat e fecha. Depois, se for arquivo, abre normal e lê, para ver que o fufh de
 * leitura continua bom (open e close caem no mesmo fufh). Pasta usa O_SEARCH (o O_EXEC das pastas).
 * Com -i na frente, só mostra o resultado e sai com 0 (usado no link simbólico, em que o driver pode recusar o open).
 *
 * Criado em 20/10/2026 (docs/correcoes/2026-10-20_panic-ao-compartilhar-por-smb.md).
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define REPETICOES 100

static int conferir(const char *caminho)
{
    struct stat st;

    if (lstat(caminho, &st) != 0) {
        printf("FALHA %s: lstat: %s\n", caminho, strerror(errno));
        return 1;
    }
    int modo = O_EVTONLY | O_SYMLINK | (S_ISDIR(st.st_mode) ? O_SEARCH : O_EXEC);

    for (int i = 0; i < REPETICOES; i++) {
        int fd = open(caminho, modo);
        if (fd < 0) {
            printf("FALHA %s: open(0x%x) na vez %d: %s\n", caminho, modo, i + 1, strerror(errno));
            return 1;
        }
        char b[16];
        ssize_t n = read(fd, b, sizeof b);
        int erro_leitura = errno;
        int st_ok = fstat(fd, &st) == 0;
        close(fd);
        if (n >= 0 || erro_leitura != EBADF) {
            printf("FALHA %s: read() devia dar EBADF (aberto sem FREAD) e deu %zd/%s: o teste não passou pelo caminho "
                   "do smbd\n", caminho, n, n >= 0 ? "ok" : strerror(erro_leitura));
            return 1;
        }
        if (!st_ok) {
            printf("FALHA %s: fstat: %s\n", caminho, strerror(errno));
            return 1;
        }
    }

    if (S_ISREG(st.st_mode)) {
        char b[64] = {0};
        int fd = open(caminho, O_RDONLY);
        ssize_t n = fd < 0 ? -1 : read(fd, b, sizeof b - 1);
        if (fd >= 0) {
            close(fd);
        }
        if (n <= 0) {
            printf("FALHA %s: leitura normal depois: %s\n", caminho, n < 0 ? strerror(errno) : "vazio");
            return 1;
        }
    }
    printf("ok    %s: %d aberturas 0x%x sem leitura nem escrita\n", caminho, REPETICOES, modo);
    return 0;
}

int main(int argc, char **argv)
{
    int informativo = argc > 1 && strcmp(argv[1], "-i") == 0;
    int primeiro = informativo ? 2 : 1;

    if (argc <= primeiro) {
        fprintf(stderr, "uso: %s [-i] <caminho>...\n", argv[0]);
        return 2;
    }
    int falhas = 0;
    for (int i = primeiro; i < argc; i++) {
        falhas += conferir(argv[i]);
    }
    return informativo ? 0 : (falhas != 0);
}
