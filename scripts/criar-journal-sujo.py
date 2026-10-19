#!/usr/bin/env python3
"""Deixa o $LogFile de um volume NTFS recém-formatado "sujo, mas recuperável", como o Windows deixa quando o
disco é arrancado: as duas páginas de reinício (RSTR) abertas (client_in_use_list = 0 e sem o bit
RESTART_VOLUME_IS_CLEAN) e um registro de checkpoint (LOG_CHECKPOINT) que o ntfsrecover consegue percorrer.
Sem transações pendentes de verdade (não há como gerar as do Windows aqui), o "replay" aplica 1 ação
(o checkpoint) e deixa o journal limpo: serve para provar o caminho sujo -> ntfsrecover -> monta com gravação.

Uso: criar-journal-sujo.py <dispositivo> <offset do $LogFile em bytes> <tamanho do $LogFile em bytes> [2.0]
  2.0 = versão 2.0 do journal (metadados no cache da Inicialização rápida): o ntfsrecover recusa sem -k.
Layout (include/ntfs-3g/logfile.h): páginas de 4096 bytes; blocos 0 e 1 = RSTR; 2 e 3 = cópias temporárias da página
mais recente; 4 em diante = registros (RCRD); o último bloco é a "página anterior" da volta do círculo.
Só mexe nos campos do 1º setor de cada página, longe da correção de setor, e escreve a proteção de setor (USA).
"""
import os
import struct
import sys

PAG = 4096
dispositivo, inicio, tamanho = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
major, minor = (2, 0) if "2.0" in sys.argv[4:] else (1, 1)

# LSN do checkpoint: número de sequência 1 acima dos bits de posição; posição = (offset no log) / 8
bits_seq = 67 - tamanho.bit_length()                    # seq_number_bits que o NTFS-3G confere
LSN = (1 << (64 - bits_seq)) | ((4 * PAG + 0x40) >> 3)  # registro em 0x40 do bloco 4
TAM_REGISTRO = 0x30 + 0x68                              # cabeçalho + dados de um checkpoint
LSN_FIM = LSN + (TAM_REGISTRO >> 3)


def proteger(p, usa_ofs):
    """Proteção de setor (MST): usn no fim de cada setor; os bytes originais vão para o USA."""
    struct.pack_into("<H", p, usa_ofs, 1)
    for i in range(PAG // 512):
        fim = (i + 1) * 512 - 2
        struct.pack_into("<2s", p, usa_ofs + 2 + 2 * i, bytes(p[fim:fim + 2]))
        struct.pack_into("<H", p, fim, 1)


def pagina_reinicio():
    p = bytearray(PAG)
    usa_ofs, ra_ofs = 0x30, 0x48
    p[0:4] = b"RSTR"
    struct.pack_into("<HHQIIHhh", p, 4, usa_ofs, 1 + PAG // 512, 0, PAG, PAG, ra_ofs, minor, major)
    # RESTART_AREA: current_lsn, clients, free_list, in_use_list = 0 (aberto), flags = 0 (sem CLEAN), bits, ...
    struct.pack_into("<QHHHHIHHQIHHII", p, ra_ofs, LSN, 1, 0xffff, 0, 0, bits_seq, 0xd0, 0x30, tamanho,
                     0x68, 0x30, 0x40, 1, 0)
    c = ra_ofs + 0x30                                   # LOG_CLIENT_RECORD
    struct.pack_into("<QQHHH6xI", p, c, LSN, LSN, 0xffff, 0xffff, 0, 8)
    p[c + 0x28:c + 0x30] = "NTFS".encode("utf-16-le")
    proteger(p, usa_ofs)
    return bytes(p)


def pagina_registros(copia, cheia=False):
    """RCRD com um checkpoint em 0x40. copia = file_offset (blocos 2/3) ou last_lsn (bloco real)."""
    p = bytearray(PAG)
    p[0:4] = b"RCRD"
    proximo = 0xff8 if cheia else 0x40 + TAM_REGISTRO
    struct.pack_into("<HHQIHHH6xQ", p, 4, 0x28, 1 + PAG // 512, copia, 1, 1, 1, proximo, LSN_FIM)
    if not cheia:
        # LOG_RECORD: this_lsn, previous, undo_next, data_len, client_id, tipo 2 (LOG_CHECKPOINT), transação 0
        struct.pack_into("<QQQIHHIIH", p, 0x40, LSN, 0, 0, 0x68, 2, 2, 2, 0, 0)
    proteger(p, 0x28)
    return bytes(p)


fd = os.open(dispositivo, os.O_RDWR)
for n in (2, 3):
    os.pwrite(fd, pagina_registros(4 * PAG), inicio + n * PAG)
os.pwrite(fd, pagina_registros(LSN), inicio + 4 * PAG)
os.pwrite(fd, pagina_registros(0, cheia=True), inicio + (tamanho // PAG - 1) * PAG)   # página anterior (volta do log)
for n in (0, 1):
    os.pwrite(fd, pagina_reinicio(), inicio + n * PAG)
os.close(fd)
