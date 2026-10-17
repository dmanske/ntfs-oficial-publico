/*
 * NTFS Oficial — ntfsoficial.util / mount_ntfsoficial
 *
 * O macOS (DiskArbitration) chama este programa com dois nomes:
 *   ntfsoficial.util -p <disco> <removable|fixed> <readonly|writable>   detecção (probe)
 *   mount_ntfsoficial [-o opções]... <dispositivo> <ponto de montagem>   montagem
 * Mesmo desenho do tuxera_ntfs.util (analisado com o REA, docs/design/REFERENCIA_TUXERA.md).
 *
 * Os nomes e caminhos chegam por -D na compilação (scripts/config.sh):
 *   NOME, IDENTIFICADOR, PACOTE_FS, PREFERENCIAS
 */
#ifndef NTFSOFICIAL_COMUM_H
#define NTFSOFICIAL_COMUM_H

#include <stdbool.h>
#include <stddef.h>

#ifndef NOME
#error "compilar com -DNOME=... (ver scripts/compilar-usuario.sh)"
#endif

#define SUPORTE              PACOTE_FS "/Contents/Resources/Support"
#define DRIVER               SUPORTE "/" NOME
#define PROBE_NTFS3G         SUPORTE "/ntfs-3g.probe"
#define NTFSLS               SUPORTE "/ntfsls"
#define NTFSLABEL            SUPORTE "/ntfslabel"

/* Respostas ao macOS (sys/loadable_fs.h); como código de saída viram 255, 254... */
#define RESPOSTA_RECONHECIDO      (-1)  /* FSUR_RECOGNIZED */
#define RESPOSTA_NAO_RECONHECIDO  (-2)  /* FSUR_UNRECOGNIZED */
#define RESPOSTA_IO_FALHOU        (-4)  /* FSUR_IO_FAIL */
#define RESPOSTA_INVALIDO         (-6)  /* FSUR_INVAL */

/* Códigos do NTFS-3G (include/ntfs-3g/volume.h), os mesmos que o driver do Tuxera devolve */
#define NTFS_OK                 0
#define NTFS_CORROMPIDO         13
#define NTFS_HIBERNADO          14
#define NTFS_DESMONTAGEM_SUJA   15

/* --- preferencias.c --- */
typedef struct {
    bool desligado;            /* DisableDriver: não reconhece nenhum disco */
    bool normalizacao;         /* EnableNormalization: nomes Unicode NFD <-> NFC (nfconv) */
    bool recuperacao;          /* EnableAutomaticRecovery: opção recover do NTFS-3G */
    bool cache;                /* EnableCaching: gravação assíncrona com o cache do macOS (nosyncwrites) */
    bool raw;                  /* EnableRawDevices: montar por /dev/rdiskN (mais rápido; padrão do Tuxera) */
    int  modo_xattr;           /* XattrMode: 0 nenhum, 1 auto_xattr, 2 atributos nativos (padrão) */
    long iosize;               /* IOSize: bytes por operação (o Tuxera usa 1 MiB) */
    bool depurar;              /* LoggingLevel >= 2 */
} preferencias_t;

void preferencias_ler(preferencias_t *p);

/* --- controle.c: arquivos de controle na raiz do próprio disco --- */
typedef struct {
    bool desligar_driver;      /* /.NTFS-Oficial/disable-driver (ou o /.Tuxera-NTFS/ equivalente) */
    bool sem_normalizacao;     /* /.NTFS-Oficial/disable-normalization */
    bool sem_cache;            /* /.NTFS-Oficial/disable-caching */
} controle_t;

void controle_ler(const char *dispositivo, controle_t *c);

/* --- executar.c --- */
/* Roda um programa (argv[0] = caminho), espera e devolve o código de saída (ou -1).
 * Se saida != NULL, guarda até tamanho-1 bytes de stdout+stderr. */
int executar(char *const argv[], char *saida, size_t tamanho);

/* --- registro.c: log unificado do macOS (subsistema IDENTIFICADOR) --- */
void registro_iniciar(bool depurar);
void registro(const char *formato, ...) __attribute__((format(printf, 1, 2)));
void registro_erro(const char *formato, ...) __attribute__((format(printf, 1, 2)));

/* --- aviso.c: janela de aviso para a pessoa (não bloqueia a montagem) --- */
void aviso_mostrar(const char *titulo, const char *mensagem);

/* --- detectar.c / montar.c --- */
int detectar(int argc, char *argv[]);
int montar(int argc, char *argv[]);

#endif
