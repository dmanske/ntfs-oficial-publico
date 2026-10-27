import XCTest
import DiskArbitration
@testable import NTFSOficialMotor

final class ValidacaoNomeTests: XCTestCase {
    func testNTFS() {
        XCTAssertNil(ValidacaoNome.validar("Filmes", formato: .ntfs))
        XCTAssertNil(ValidacaoNome.validar(String(repeating: "a", count: 128), formato: .ntfs))
        XCTAssertEqual(ValidacaoNome.validar(String(repeating: "a", count: 129), formato: .ntfs), .muitoLongo(maximo: 128))
        XCTAssertEqual(ValidacaoNome.validar("", formato: .ntfs), .vazio)
    }
    func testExFAT() {
        XCTAssertNil(ValidacaoNome.validar("Meu disco", formato: .exfat))
        XCTAssertNil(ValidacaoNome.validar("12345678901", formato: .exfat))
        XCTAssertEqual(ValidacaoNome.validar("123456789012", formato: .exfat), .muitoLongo(maximo: 11))
        for c in "\"*/:<>?\\|" {
            XCTAssertEqual(ValidacaoNome.validar("a\(c)b", formato: .exfat), .caractereInvalido(c))
        }
    }
    func testFAT32() {
        XCTAssertNil(ValidacaoNome.validar("MEU DISCO", formato: .fat32))
        XCTAssertEqual(ValidacaoNome.validar("Meu", formato: .fat32), .precisaMaiusculaASCII)
        XCTAssertEqual(ValidacaoNome.validar("AÇÃO", formato: .fat32), .precisaMaiusculaASCII)
        XCTAssertEqual(ValidacaoNome.validar("A/B", formato: .fat32), .caractereInvalido("/"))
        XCTAssertEqual(ValidacaoNome.validar("ABCDEFGHIJKL", formato: .fat32), .muitoLongo(maximo: 11))
    }
}

final class AdministradorTests: XCTestCase {
    func testCitar() {
        XCTAssertEqual(Administrador.citar("abc"), "'abc'")
        XCTAssertEqual(Administrador.citar("it's"), "'it'\\''s'")
        XCTAssertEqual(Administrador.montarComando(["/bin/echo", "a b", "c'd"]), "'/bin/echo' 'a b' 'c'\\''d'")
    }
    func testEscapeAppleScript() {
        XCTAssertEqual(Administrador.escaparAppleScript("a\"b\\c"), "a\\\"b\\\\c")
        let s = Administrador.scriptAppleScript(comando: "echo \"x\"")
        XCTAssertEqual(s, "do shell script \"exec 2>&1; echo \\\"x\\\"\" with administrator privileges")
    }
    func testComandosDasOperacoes() {
        let v = OperacoesDeDisco.comandoVerificar(bsd: "disk9s1")
        XCTAssertTrue(v.contains("'--readwrite' '/dev/disk9s1' 2>&1); p=$?; "))
        XCTAssertTrue(v.contains("echo \"probe=$p\""))
        // ntfsrecover -n só com probe 14/15 e fora da hibernação; ntfsfix -n sempre; nada grava
        XCTAssertTrue(v.contains("'/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/ntfsrecover' '-n' '/dev/disk9s1'; echo \"recover=$?\""))
        XCTAssertTrue(v.contains("grep -qi hibernated"))
        XCTAssertTrue(v.hasSuffix("'/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/ntfsfix' '-n' '/dev/disk9s1'; echo \"ntfsfix=$?\""))
        XCTAssertFalse(v.contains("'-d'"))
        XCTAssertFalse(v.contains("'-k'"))
        let r = OperacoesDeDisco.comandoReparar(bsd: "disk9s1")
        // ntfsrecover (replay, com limite de 60 s) antes do ntfsfix; ntfsfix só se o replay deu 0; nunca -d nem -k
        let iRecover = try! XCTUnwrap(r.range(of: "ntfsrecover' '/dev/disk9s1'")).lowerBound
        let iFix = try! XCTUnwrap(r.range(of: "ntfsfix' '/dev/disk9s1'")).lowerBound
        XCTAssertLessThan(iRecover, iFix)
        XCTAssertTrue(r.contains("'alarm 60; exec @ARGV'"))
        // ntfsfix só se o ntfsfix -n achar erro (num disco em ordem ele só deixaria a marca de "sujo")
        XCTAssertTrue(r.contains("if [ \"$r\" = 0 ]; then '/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/ntfsfix' '-n' '/dev/disk9s1'"))
        XCTAssertTrue(r.contains("if [ \"$n\" != 0 ]; then '/Library/Filesystems/ntfsoficial.fs/Contents/Resources/Support/ntfsfix' '/dev/disk9s1'"))
        XCTAssertTrue(OperacoesDeDisco.reparoDeuCerto(saida: "probe=0\nntfsfix_n=0\n"))
        XCTAssertTrue(OperacoesDeDisco.reparoDeuCerto(saida: "probe=0\nntfsfix_n=1\nntfsfix=0\n"))
        XCTAssertFalse(OperacoesDeDisco.reparoDeuCerto(saida: "probe=0\nntfsfix_n=1\nntfsfix=1\n"))
        XCTAssertFalse(OperacoesDeDisco.reparoDeuCerto(saida: "probe=15\nrecover=1\n"))
        XCTAssertFalse(OperacoesDeDisco.reparoDeuCerto(saida: "probe=14\nhibernado=1\n"))
        XCTAssertTrue(r.contains("hibernado=1"))
        XCTAssertFalse(r.contains("'-d'"))
        XCTAssertFalse(r.contains("'-k'"))
        XCTAssertTrue(OperacoesDeDisco.comandoFormatarNTFS(bsd: "disk9s1", nome: "O'Brien").contains("'-L' 'O'\\''Brien' '/dev/disk9s1'"))
        XCTAssertEqual(OperacoesDeDisco.argumentosDiskutil(formato: .fat32, nome: "A", bsd: "disk9s1")!,
                       ["eraseVolume", "MS-DOS FAT32", "A", "disk9s1"])
        XCTAssertNil(OperacoesDeDisco.argumentosDiskutil(formato: .ntfs, nome: "A", bsd: "x"))
    }
}

final class PreferenciasTests: XCTestCase {
    func testPadroesSemArquivo() {
        let p = PreferenciasDriver.ler(caminho: "/nao/existe.plist")
        XCTAssertEqual(p, PreferenciasDriver())
        XCTAssertEqual(p.enableRawDevices, 1)
        XCTAssertEqual(p.xattrMode, 2)
        // como o Tuxera (REA): recuperação automática e conversão SFM ligadas por padrão
        XCTAssertEqual(p.enableAutomaticRecovery, 1)
        XCTAssertEqual(p.enableSFMConversions, 1)
    }
    func testLerSFMeRecuperacaoDesligadas() throws {
        let caminho = NSTemporaryDirectory() + "prefs-\(UUID().uuidString).plist"
        defer { try? FileManager.default.removeItem(atPath: caminho) }
        let dic: NSDictionary = ["EnableAutomaticRecovery": 0, "EnableSFMConversions": false]
        XCTAssertTrue(dic.write(toFile: caminho, atomically: true))
        let p = PreferenciasDriver.ler(caminho: caminho)
        XCTAssertEqual(p.enableAutomaticRecovery, 0)
        XCTAssertEqual(p.enableSFMConversions, 0)
    }
    func testLerPlist() throws {
        let caminho = NSTemporaryDirectory() + "prefs-\(UUID().uuidString).plist"
        defer { try? FileManager.default.removeItem(atPath: caminho) }
        let dic: NSDictionary = ["DisableDriver": 1, "EnableRawDevices": false, "XattrMode": 1]
        XCTAssertTrue(dic.write(toFile: caminho, atomically: true))
        let p = PreferenciasDriver.ler(caminho: caminho)
        XCTAssertEqual(p.disableDriver, 1)
        XCTAssertEqual(p.enableRawDevices, 0)
        XCTAssertEqual(p.enableCaching, 1)   // ausente = padrão
        XCTAssertEqual(p.xattrMode, 1)
    }
    func testComandoGravar() {
        var p = PreferenciasDriver()
        p.enableCaching = 0
        let c = p.comandoGravar(caminho: "/tmp/x.plist")
        XCTAssertTrue(c.hasPrefix("'/usr/bin/defaults' 'write' '/tmp/x.plist' 'DisableDriver' '-int' '0' && "))
        XCTAssertTrue(c.contains("'EnableCaching' '-int' '0'"))
        XCTAssertTrue(c.contains("'EnableSFMConversions' '-int' '1'"))
        XCTAssertTrue(c.contains("'EnableAutomaticRecovery' '-int' '1'"))
        XCTAssertEqual(c.components(separatedBy: " && ").count, 7)
    }
}

final class ConflitosTests: XCTestCase {
    private func pastaTemporaria() throws -> String {
        let p = NSTemporaryDirectory() + "conf-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: p, withIntermediateDirectories: true)
        return p
    }
    private func criar(_ raiz: String, _ relativo: String) throws {
        let c = raiz + "/" + relativo
        try FileManager.default.createDirectory(atPath: (c as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: c, contents: Data())
    }
    func testNenhum() throws {
        let r = try pastaTemporaria(); defer { try? FileManager.default.removeItem(atPath: r) }
        XCTAssertEqual(Conflitos.detectar(raiz: r), [])
    }
    func testTuxeraEParagon() throws {
        let r = try pastaTemporaria(); defer { try? FileManager.default.removeItem(atPath: r) }
        try criar(r, "Library/Filesystems/tuxera_ntfs.fs/x")
        try criar(r, "Library/Extensions/ufsd_NTFS.kext/x")
        XCTAssertEqual(Conflitos.detectar(raiz: r), [.tuxera, .paragon])
    }
    func testMacFUSEPrecisaDoNtfs3g() throws {
        let r = try pastaTemporaria(); defer { try? FileManager.default.removeItem(atPath: r) }
        try criar(r, "Library/Filesystems/macfuse.fs/x")
        XCTAssertEqual(Conflitos.detectar(raiz: r), [])
        try criar(r, "opt/homebrew/bin/ntfs-3g")
        XCTAssertEqual(Conflitos.detectar(raiz: r), [.ntfs3gMacFUSE])
    }
}

final class ProbeETMotivoTests: XCTestCase {
    func testCodigosDoProbe() {
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 0), .limpo)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 14), .hibernado)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 15), .sujo)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 3), .erro(codigo: 3))
        // o 14 vale para hiberfil.sys e para o journal 2.0; a mensagem do probe separa
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 14, saida: "Windows is hibernated, refused to mount.\n"), .hibernado)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 14, saida: "Hibernated non-system partition, refused to mount."), .hibernado)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 14, saida: "Metadata kept in Windows cache, refused to mount.\n"), .cacheWindows)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 15, saida: "The disk contains an unclean file system (0, 0).\n"), .sujo)
        XCTAssertEqual(InterpretacaoProbe.estado(codigo: 0, saida: ""), .limpo)
        XCTAssertEqual(InterpretacaoProbe.codigo(na: "lixo\nprobe=15\nntfsfix=0\n", marcador: "probe"), 15)
        XCTAssertEqual(InterpretacaoProbe.codigo(na: "lixo\nprobe=15\nntfsfix=0\n", marcador: "ntfsfix"), 0)
        XCTAssertNil(InterpretacaoProbe.codigo(na: "nada", marcador: "probe"))
    }
    func testLerMotivo() throws {
        let pasta = NSTemporaryDirectory() + "motivo-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: pasta, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: pasta) }
        XCTAssertNil(Disco.lerMotivo(bsdName: "disk9s1", pasta: pasta))
        try "hibernado".write(toFile: pasta + "/disk9s1.motivo", atomically: true, encoding: .utf8)
        try "sujo\n".write(toFile: pasta + "/disk9s2.motivo", atomically: true, encoding: .utf8)
        try "bobagem".write(toFile: pasta + "/disk9s3.motivo", atomically: true, encoding: .utf8)
        try "cache-windows\n".write(toFile: pasta + "/disk9s4.motivo", atomically: true, encoding: .utf8)
        XCTAssertEqual(Disco.lerMotivo(bsdName: "disk9s1", pasta: pasta), .hibernado)
        XCTAssertEqual(Disco.lerMotivo(bsdName: "disk9s2", pasta: pasta), .sujo)
        XCTAssertNil(Disco.lerMotivo(bsdName: "disk9s3", pasta: pasta))
        XCTAssertEqual(Disco.lerMotivo(bsdName: "disk9s4", pasta: pasta), .cacheWindows)
        XCTAssertEqual(MotivoSoLeitura.cacheWindows.rawValue, "cache-windows")
    }
}

final class ClassificacaoTests: XCTestCase {
    func testEhNTFS() {
        XCTAssertTrue(Disco.ehNTFS(tipoDeSistema: "ntfsoficial", conteudo: nil, montado: true))
        XCTAssertTrue(Disco.ehNTFS(tipoDeSistema: "ntfs", conteudo: "x", montado: true))
        XCTAssertTrue(Disco.ehNTFS(tipoDeSistema: nil, conteudo: "Windows_NTFS", montado: false))
        XCTAssertFalse(Disco.ehNTFS(tipoDeSistema: nil, conteudo: "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7", montado: false))
        XCTAssertFalse(Disco.ehNTFS(tipoDeSistema: "exfat", conteudo: "Windows_NTFS", montado: true))
        XCTAssertFalse(Disco.ehNTFS(tipoDeSistema: "apfs", conteudo: nil, montado: true))
    }
    func testMontaDiscoDaDescricao() {
        let d: [String: Any] = [
            kDADiskDescriptionMediaBSDNameKey as String: "disk9s1",
            kDADiskDescriptionVolumeKindKey as String: "ntfs",
            kDADiskDescriptionVolumeNameKey as String: "TESTE",
            kDADiskDescriptionMediaSizeKey as String: NSNumber(value: 1000),
        ]
        let w: [String: Any] = [kDADiskDescriptionMediaBSDNameKey as String: "disk9",
                                kDADiskDescriptionMediaSizeKey as String: NSNumber(value: 2000)]
        let disco = Disco(descricao: d, inteiro: w)
        XCTAssertEqual(disco?.nome, "TESTE")
        XCTAssertEqual(disco?.discoInteiro, "disk9")
        XCTAssertEqual(disco?.tamanhoDiscoInteiro, 2000)
        XCTAssertEqual(disco?.montado, false)
    }
}

/// Teste com disco de verdade: só roda com NTFS_OFICIAL_TESTE_IMAGEM=<caminho de uma imagem de teste já criada
/// em build/teste/>. Anexa (o driver monta), confere que o MonitorDeDiscos lista e desanexa no fim.
@MainActor
final class MonitorComImagemTests: XCTestCase {
    func testListaImagemAnexada() async throws {
        guard let imagem = ProcessInfo.processInfo.environment["NTFS_OFICIAL_TESTE_IMAGEM"] else {
            throw XCTSkip("defina NTFS_OFICIAL_TESTE_IMAGEM para rodar")
        }
        let saida = try await OperacoesDeDisco.rodar("/usr/bin/hdiutil", ["attach", imagem])
        // O hdiutil escreve avisos no stderr (que o rodar() junta): pega a 1ª linha que começa com /dev/.
        let linha = saida.split(separator: "\n").first { $0.hasPrefix("/dev/") }.map(String.init) ?? ""
        let inteiro = linha.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
        XCTAssertFalse(inteiro.isEmpty, "attach falhou: \(saida)")
        defer {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            p.arguments = ["detach", inteiro]
            try? p.run()
            p.waitUntilExit()
        }
        let monitor = MonitorDeDiscos()
        monitor.iniciar()
        try await Task.sleep(nanoseconds: 2_000_000_000)
        print("discos:", monitor.discos.map(\.bsdName))
        XCTAssertTrue(monitor.discos.contains { $0.bsdName.hasPrefix(inteiro.replacingOccurrences(of: "/dev/", with: "")) },
                      "a imagem NTFS deveria aparecer; achei \(monitor.discos.map(\.bsdName))")
    }
}

final class IdentificadorTests: XCTestCase {
    func testIdentificadorDeDisco() {
        XCTAssertTrue(OperacoesDeDisco.identificadorValido("disk6s2"))
        XCTAssertTrue(OperacoesDeDisco.identificadorValido("disk4"))
        XCTAssertFalse(OperacoesDeDisco.identificadorValido(""))
        XCTAssertFalse(OperacoesDeDisco.identificadorValido("disk6s2; rm -rf /"))
        XCTAssertFalse(OperacoesDeDisco.identificadorValido("../disk1"))
        XCTAssertFalse(OperacoesDeDisco.identificadorValido("rdisk6s2"))
    }
}
