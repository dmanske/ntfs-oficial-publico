# Teste de estresse: mesmas operações aleatórias (criar, gravar no meio, anexar, truncar, renomear, apagar) numa
# pasta de referência e no volume NTFS, conferindo o arquivo tocado depois de CADA operação. Para na 1ª diferença.
#   python3 -I scripts/estresse.py <pasta_referencia_vazia> <volume_ntfs> <numero_de_operacoes>
# Achou a corrupção de 17/10/2026 (docs/correcoes/2026-10-17_dados-errados-ao-reaproveitar-registro.md).
import os, random, sys
ref, alvo, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
random.seed(17102026); nomes = []; hist = {}
def confere(i, desc, nome):
    hist.setdefault(nome.split("_")[1], []).append(f"op {i}: {desc} -> ref={os.path.getsize(os.path.join(ref,nome)) if os.path.exists(os.path.join(ref,nome)) else None}")
    a = os.path.join(ref, nome); b = os.path.join(alvo, nome)
    if os.path.exists(a) != os.path.exists(b) or (os.path.exists(a) and open(a,"rb").read() != open(b,"rb").read()):
        ta = os.path.getsize(a) if os.path.exists(a) else None; tb = os.path.getsize(b) if os.path.exists(b) else None
        print(f"DIVERGIU na operação {i}: {desc} em {nome!r} | ref={ta} vol={tb}")
        for linha in hist.get(nome.split("_")[1], [])[-8:]: print("   histórico:", linha)
        sys.exit(1)
for i in range(n):
    op = random.random()
    if op < 0.45 or not nomes:
        nome = f"arq_{i}_çã é.bin"; dados = os.urandom(random.choice([1, 7, 511, 513, 1023, 4097, 65537, random.randint(1, 3_000_000)]))
        for b in (ref, alvo): open(os.path.join(b, nome), "wb").write(dados)
        nomes.append(nome); confere(i, f"criar {len(dados)} B", nome)
    elif op < 0.70:
        nome = random.choice(nomes); tam = os.path.getsize(os.path.join(ref, nome)); pos = random.randint(0, tam); dados = os.urandom(random.randint(1, 70000))
        for b in (ref, alvo):
            with open(os.path.join(b, nome), "r+b") as f: f.seek(pos); f.write(dados)
        confere(i, f"gravar {len(dados)} B na posição {pos} (tam {tam})", nome)
    elif op < 0.80:
        nome = random.choice(nomes); dados = os.urandom(random.randint(1, 9000))
        for b in (ref, alvo): open(os.path.join(b, nome), "ab").write(dados)
        confere(i, f"anexar {len(dados)} B", nome)
    elif op < 0.88:
        nome = random.choice(nomes); tam = os.path.getsize(os.path.join(ref, nome)); novo = random.randint(0, tam)
        for b in (ref, alvo): os.truncate(os.path.join(b, nome), novo)
        confere(i, f"truncar de {tam} para {novo}", nome)
    elif op < 0.94:
        nome = random.choice(nomes); novo = nome.replace("arq_", "ren_", 1) + f"_{i}"
        for b in (ref, alvo): os.rename(os.path.join(b, nome), os.path.join(b, novo))
        nomes[nomes.index(nome)] = novo; confere(i, "renomear", novo)
    else:
        nome = random.choice(nomes)
        for b in (ref, alvo): os.remove(os.path.join(b, nome))
        nomes.remove(nome); confere(i, "apagar", nome)
print("sem divergência em", n, "operações")
