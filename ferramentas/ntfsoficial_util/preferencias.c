/*
 * Preferências em PREFERENCIAS (/Library/Preferences/com.danielmanske.ntfsoficial.plist).
 * Mesmas chaves do Tuxera (/Library/Preferences/com.tuxera.NTFS.plist), para ficar familiar.
 * Sem o arquivo, valem os padrões abaixo. Mudar: sudo defaults write <arquivo> <Chave> -int <valor>
 */
#include "comum.h"

#include <CoreFoundation/CoreFoundation.h>

static long ler_numero(CFDictionaryRef d, CFStringRef chave, long padrao)
{
    if (!d) return padrao;
    CFTypeRef v = CFDictionaryGetValue(d, chave);
    long n = padrao;
    if (v && CFGetTypeID(v) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)v, kCFNumberLongType, &n);
    } else if (v && CFGetTypeID(v) == CFBooleanGetTypeID()) {
        n = CFBooleanGetValue((CFBooleanRef)v) ? 1 : 0;
    }
    return n;
}

static CFDictionaryRef abrir_plist(void)
{
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8 *)PREFERENCIAS,
                                                           (CFIndex)strlen(PREFERENCIAS), false);
    if (!url) return NULL;
    CFReadStreamRef s = CFReadStreamCreateWithFile(NULL, url);
    CFRelease(url);
    if (!s) return NULL;
    CFPropertyListRef pl = NULL;
    if (CFReadStreamOpen(s)) {
        pl = CFPropertyListCreateWithStream(NULL, s, 0, kCFPropertyListImmutable, NULL, NULL);
        CFReadStreamClose(s);
    }
    CFRelease(s);
    if (pl && CFGetTypeID(pl) != CFDictionaryGetTypeID()) {
        CFRelease(pl);
        pl = NULL;
    }
    return (CFDictionaryRef)pl;
}

void preferencias_ler(preferencias_t *p)
{
    CFDictionaryRef d = abrir_plist();
    p->desligado    = ler_numero(d, CFSTR("DisableDriver"), 0) != 0;
    p->normalizacao = ler_numero(d, CFSTR("EnableNormalization"), 1) != 0;
    p->recuperacao  = ler_numero(d, CFSTR("EnableAutomaticRecovery"), 0) != 0;
    p->cache        = ler_numero(d, CFSTR("EnableCaching"), 1) != 0;
    p->raw          = ler_numero(d, CFSTR("EnableRawDevices"), 1) != 0;
    p->modo_xattr   = (int)ler_numero(d, CFSTR("XattrMode"), 2);
    p->iosize       = ler_numero(d, CFSTR("IOSize"), 1048576);   /* 1 MiB, igual ao Tuxera (REA) */
    p->depurar      = ler_numero(d, CFSTR("LoggingLevel"), 1) >= 2;
    if (p->modo_xattr < 0 || p->modo_xattr > 2) p->modo_xattr = 2;
    if (d) CFRelease(d);
}
