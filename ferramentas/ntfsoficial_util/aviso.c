/*
 * Aviso para a pessoa (CFUserNotification, o mesmo recurso do tuxera_ntfs_confirm_mount).
 * Não espera resposta: a montagem segue (por exemplo, só para leitura) e o aviso explica por quê.
 */
#include "comum.h"

#include <CoreFoundation/CoreFoundation.h>

void aviso_mostrar(const char *titulo, const char *mensagem)
{
    CFStringRef t = CFStringCreateWithCString(NULL, titulo, kCFStringEncodingUTF8);
    CFStringRef m = CFStringCreateWithCString(NULL, mensagem, kCFStringEncodingUTF8);
    if (t && m) {
        CFUserNotificationDisplayNotice(0, kCFUserNotificationCautionAlertLevel, NULL, NULL, NULL,
                                        t, m, CFSTR("OK"));
    }
    if (t) CFRelease(t);
    if (m) CFRelease(m);
}
