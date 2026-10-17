/*
 * Log no sistema unificado do macOS. Para ver:
 *   log show --last 10m --predicate 'subsystem == "com.danielmanske.ntfsoficial"' --info --debug
 */
#include "comum.h"

#include <os/log.h>
#include <stdarg.h>
#include <stdio.h>

static os_log_t canal;
static bool modo_depurar;

void registro_iniciar(bool depurar)
{
    canal = os_log_create(IDENTIFICADOR, "util");
    modo_depurar = depurar;
}

static void escrever(os_log_type_t tipo, const char *formato, va_list args)
{
    char texto[2048];
    vsnprintf(texto, sizeof(texto), formato, args);
    os_log_with_type(canal ? canal : OS_LOG_DEFAULT, tipo, "%{public}s", texto);
    if (modo_depurar) fprintf(stderr, "%s\n", texto);
}

void registro(const char *formato, ...)
{
    va_list a;
    va_start(a, formato);
    escrever(OS_LOG_TYPE_DEFAULT, formato, a);
    va_end(a);
}

void registro_erro(const char *formato, ...)
{
    va_list a;
    va_start(a, formato);
    escrever(OS_LOG_TYPE_ERROR, formato, a);
    va_end(a);
}
