# Correção: disco com espaço no nome não era desmontado ao desligar (18/10/2026)

## Sintoma

Achado na conferência com o Ghidra (comparando com o `tuxera_ntfs_daemon`). O serviço que desmonta os volumes no
desligamento lia a linha do `mount` separando por espaços:

```
mount -t ntfsoficial | while read -r dispositivo _ ponto _
```

Com o volume `/Volumes/Meu Disco`, `ponto` virava `/Volumes/Meu` (testado com `printf | read`), e as três
tentativas (`diskutil unmount`, `diskutil unmount force`, `umount -f`) falhavam. O disco desligava sem ser
desmontado e voltava "sujo". Os HDs que já vêm em NTFS têm espaço no nome ("My Passport", "Seagate Expansion
Drive"). O mesmo padrão estava em `scripts/desinstalar.sh` e `pacote/desinstalar-ntfs-oficial.command`.

## Correção

- `pacote/desmontar-ao-desligar.sh`: usa o dispositivo (1º campo da linha, sem espaço; o `diskutil` e o `umount`
  aceitam dispositivo no lugar do ponto).
- Como o `tuxera_ntfs_daemon` (`_sigterm_execute`, REA): `sync`, desmontar normal e depois forçado, repetindo de 1 em
  1 s até não sobrar volume. O do Tuxera repete sem limite; aqui para em 25 s, porque o launchd encerra o serviço em
  30 s (`ExitTimeOut` do plist).
- `--agora` roda a desmontagem uma vez e sai (para testar sem desligar o Mac).
- `scripts/desinstalar.sh` e `pacote/desinstalar-ntfs-oficial.command`: também pelo dispositivo.

## Verificação

- Com `mount`, `diskutil` e `umount` falsos: volume com espaço desmontado pelo dispositivo; dois volumes; volume
  que só sai forçado; volume que não sai (para no limite e devolve 1); SIGTERM no modo serviço.
- Com volume de verdade: ver `docs/planos/PENDENCIAS.md`.

## Como reverter

`git checkout` dos três arquivos (volta o problema com nome que tem espaço).
