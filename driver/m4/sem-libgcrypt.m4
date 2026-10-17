# Substitui a macro AM_PATH_LIBGCRYPT do libgcrypt, que o configure.ac do NTFS-3G chama.
# O NTFS Oficial compila sem a parte de criptografia (--disable-crypto), então a macro
# só executa o terceiro argumento ("libgcrypt não encontrado") e não exige o libgcrypt instalado.
AC_DEFUN([AM_PATH_LIBGCRYPT], [
    LIBGCRYPT_CFLAGS=""
    LIBGCRYPT_LIBS=""
    AC_SUBST([LIBGCRYPT_CFLAGS])
    AC_SUBST([LIBGCRYPT_LIBS])
    $3
])
