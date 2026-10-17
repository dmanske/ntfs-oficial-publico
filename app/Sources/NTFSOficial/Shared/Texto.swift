import Foundation

/// Todas as chaves de texto da interface. Cada idioma é um `switch` exaustivo: faltou tradução = erro de compilação.
enum Chave {
    // Menu
    case menuTitulo, menuNenhum, menuLivres, menuAbrirFinder, menuEjetar, menuSoLeitura, menuNaoMontado
    case menuMontar, menuGerenciador, menuPreferencias, menuSair
    // Motivos
    case motivoHibernado, motivoSujo, motivoOutroDriver
    // Janela
    case janelaTitulo, listaGravacao, listaSoLeitura, listaNaoMontado, semDiscos
    case detNaoMontado, seloGravacao, seloSoLeitura, seloSoLeituraMotivo, usados, livres
    case campoSistema, campoIdentificador, campoModoAcesso, campoTipoParticao, campoEjetavel, campoDiscoInteiro
    case modoRapido, modoPadrao, sim, nao, sistemaOficial, sistemaApple
    case botMontar, botDesmontar, botEjetar, botVerificar, botReparar, botFormatar
    case opMontando, opDesmontando, opEjetando, opVerificando, opReparando, opFormatando
    // Alertas
    case ok, cancelar, falhouGenerico
    case ejetarFalhouTitulo, ejetarFalhouTexto, forcarEjecao
    case desmontarFalhouTitulo, desmontarFalhouTexto, forcarDesmontagem
    case montarFalhouTitulo
    case verificarTitulo, verLimpo, verHibernado, verSujo, verErro, verNaoRemontou
    case repararConfirmaTitulo, repararConfirmaTexto, repararBotao, repararOk, repararFalha
    case senhaCancelada
    // Formatar
    case formatarTitulo, formatarTexto, formatarNome, formatarFormato, fmtNTFS, fmtExFAT, fmtFAT32
    case dicaNTFS, dicaExFAT, dicaFAT32, formatarEntendo, formatarApagar, formatarOk
    case problemaVazio, problemaLongo, problemaCaractere, problemaMaiuscula
    // Conflitos
    case avisoDriverTitulo, avisoDriverTexto, drvTuxera, drvParagon, drvMacFuse
    // Preferências
    case prefMontarGravacao, prefModoRapido, prefModoRapidoDesc, prefCache, prefCacheDesc
    case prefReparo, prefReparoDesc, prefXattr, xattrTudo, xattrEssencial, xattrNenhum
    case prefIdioma, prefLogin, prefAplicar, prefRodape, prefVersao, prefAplicadoOk, prefLoginErro
    // Gerenciador (visual novo)
    case lateralDispositivos, lateralAjustes, lateralVersao
    case armazenamento, pctUsado, colCapacidade, colConexao, colAcesso
    case detTecnicosTitulo, detTecnicosSub, campoPontoMontagem, campoModelo
    case manTitulo, manSub, manOutras
    // Ajustes (visual novo)
    case ajTitulo, ajSubtitulo, ajGeral, ajGeralSub, ajMontagem, ajMontagemSub, ajDesempenho, ajDesempenhoSub
    case ajAvancado, ajAvancadoSub, ajSobre, ajSobreDescricao
    case ajIdiomaDesc, ajLoginDesc, ajMontarDesc, ajXattrDesc, ajAvisoProximo
}

/// Idioma da interface: padrão pt-BR, opção inglês, guardado em UserDefaults. Trocar atualiza a tela na hora.
final class Idioma: ObservableObject {
    static let shared = Idioma()
    static let ptBR = "pt-BR"
    static let en = "en"

    @Published var codigo: String {
        didSet { UserDefaults.standard.set(codigo, forKey: Config.chaveIdioma) }
    }

    private init() {
        let salvo = UserDefaults.standard.string(forKey: Config.chaveIdioma)
        codigo = (salvo == Idioma.en) ? Idioma.en : Idioma.ptBR
    }
}

enum Texto {
    /// `Texto.t(.menuLivres, "744 GB", "894 GB")`
    static func t(_ chave: Chave, _ args: CVarArg...) -> String {
        let modelo = Idioma.shared.codigo == Idioma.en ? ingles(chave) : portugues(chave)
        return args.isEmpty ? modelo : String(format: modelo, arguments: args)
    }

    // swiftlint:disable function_body_length
    private static func portugues(_ c: Chave) -> String {
        switch c {
        case .menuTitulo: return "Discos NTFS"
        case .menuNenhum: return "Nenhum disco NTFS conectado"
        case .menuLivres: return "%@ livres de %@"
        case .menuAbrirFinder: return "Abrir no Finder"
        case .menuEjetar: return "Ejetar"
        case .menuSoLeitura: return "só leitura — %@"
        case .menuNaoMontado: return "(não montado)"
        case .menuMontar: return "Montar"
        case .menuGerenciador: return "Gerenciador de discos…"
        case .menuPreferencias: return "Preferências…"
        case .menuSair: return "Sair do NTFS Oficial"
        case .motivoHibernado: return "Windows hibernado"
        case .motivoSujo: return "desconectado sem ejetar"
        case .motivoOutroDriver: return "outro driver / NTFS Oficial desligado"
        case .janelaTitulo: return "Gerenciador de discos"
        case .listaGravacao: return "gravação"
        case .listaSoLeitura: return "só leitura"
        case .listaNaoMontado: return "não montado"
        case .semDiscos: return "Nenhum disco NTFS conectado"
        case .detNaoMontado: return "Não montado"
        case .seloGravacao: return "Leitura e gravação"
        case .seloSoLeitura: return "Só leitura"
        case .seloSoLeituraMotivo: return "Só leitura — %@"
        case .usados: return "%@ usados"
        case .livres: return "%@ livres"
        case .campoSistema: return "Sistema de arquivos"
        case .campoIdentificador: return "Identificador"
        case .campoModoAcesso: return "Modo de acesso"
        case .campoTipoParticao: return "Tipo de partição"
        case .campoEjetavel: return "Ejetável"
        case .campoDiscoInteiro: return "Disco inteiro"
        case .modoRapido: return "rápido (raw)"
        case .modoPadrao: return "padrão (bloco)"
        case .sim: return "Sim"
        case .nao: return "Não"
        case .sistemaOficial: return "NTFS (NTFS Oficial)"
        case .sistemaApple: return "NTFS (Apple, só leitura)"
        case .botMontar: return "Montar"
        case .botDesmontar: return "Desmontar"
        case .botEjetar: return "Ejetar"
        case .botVerificar: return "Verificar disco"
        case .botReparar: return "Reparar…"
        case .botFormatar: return "Formatar…"
        case .opMontando: return "Montando…"
        case .opDesmontando: return "Desmontando…"
        case .opEjetando: return "Ejetando…"
        case .opVerificando: return "Verificando… (aguarde, pode pedir a senha)"
        case .opReparando: return "Reparando…"
        case .opFormatando: return "Formatando…"
        case .ok: return "OK"
        case .cancelar: return "Cancelar"
        case .falhouGenerico: return "Falhou: %@"
        case .ejetarFalhouTitulo: return "Não deu para ejetar “%@”"
        case .ejetarFalhouTexto: return "%@\n\nProvavelmente há arquivos abertos no disco. Feche os programas que o usam, ou force a ejeção (dados ainda não gravados podem ser perdidos)."
        case .forcarEjecao: return "Forçar ejeção"
        case .desmontarFalhouTitulo: return "Não deu para desmontar “%@”"
        case .desmontarFalhouTexto: return "%@\n\nProvavelmente há arquivos abertos no disco. Feche os programas que o usam, ou force a desmontagem (dados ainda não gravados podem ser perdidos)."
        case .forcarDesmontagem: return "Forçar desmontagem"
        case .montarFalhouTitulo: return "Não deu para montar “%@”"
        case .verificarTitulo: return "Verificação de “%@”"
        case .verLimpo: return "O disco está limpo e pode ser montado com gravação."
        case .verHibernado: return "O disco está hibernado pelo Windows (ou com a Inicialização rápida ligada). Ele só monta para leitura. Para gravar: no Windows, desligue a Inicialização rápida e use Desligar (não Hibernar)."
        case .verSujo: return "O disco não foi desconectado direito (indicador de sujo). Use Reparar, ou rode “chkdsk /f” no Windows."
        case .verErro: return "A verificação terminou com o código %d. Veja os detalhes abaixo."
        case .verNaoRemontou: return "O disco não voltou a montar sozinho: use Montar."
        case .repararConfirmaTitulo: return "Reparar “%@”?"
        case .repararConfirmaTexto: return "O disco será desmontado, o ntfsfix zera o journal e limpa o indicador de sujo, e depois o disco é montado de novo. Pede a senha do Mac.\n\nNão é um chkdsk completo: para dano sério, use “chkdsk /f” no Windows."
        case .repararBotao: return "Reparar"
        case .repararOk: return "Reparo concluído."
        case .repararFalha: return "O reparo terminou com erro. Para dano sério, use “chkdsk /f” no Windows."
        case .senhaCancelada: return "Operação cancelada (senha não informada)."
        case .formatarTitulo: return "Formatar “%@”?"
        case .formatarTexto: return "Tudo o que está no disco será apagado. Isso não pode ser desfeito."
        case .formatarNome: return "Nome"
        case .formatarFormato: return "Formato"
        case .fmtNTFS: return "NTFS (Windows e Mac)"
        case .fmtExFAT: return "exFAT"
        case .fmtFAT32: return "FAT32 (MS-DOS)"
        case .dicaNTFS: return "Até 128 caracteres."
        case .dicaExFAT: return "Até 11 caracteres, sem \" * / : < > ? \\ |"
        case .dicaFAT32: return "Até 11 caracteres, só maiúsculas sem acento, sem \" * / : < > ? \\ |"
        case .formatarEntendo: return "Entendo que todos os arquivos de “%@” serão apagados"
        case .formatarApagar: return "Apagar e formatar"
        case .formatarOk: return "“%@” foi formatado."
        case .problemaVazio: return "Digite um nome."
        case .problemaLongo: return "Nome longo demais (máximo %d)."
        case .problemaCaractere: return "Caractere não permitido: %@"
        case .problemaMaiuscula: return "FAT32 aceita só letras maiúsculas sem acento."
        case .avisoDriverTitulo: return "Outro driver NTFS instalado"
        case .avisoDriverTexto: return "Foram encontrados: %@.\n\nDois drivers NTFS ao mesmo tempo disputam o disco e podem causar erros ou perda de dados. Desinstale o outro driver."
        case .drvTuxera: return "Tuxera NTFS"
        case .drvParagon: return "Paragon NTFS"
        case .drvMacFuse: return "ntfs-3g com macFUSE"
        case .prefMontarGravacao: return "Montar discos NTFS com gravação"
        case .prefModoRapido: return "Modo rápido"
        case .prefModoRapidoDesc: return "Acesso direto ao disco para maior desempenho."
        case .prefCache: return "Gravar com cache"
        case .prefCacheDesc: return "Grava em segundo plano: mais rápido, mas ejete sempre antes de tirar o cabo."
        case .prefReparo: return "Reparar sozinho disco desconectado sem ejetar"
        case .prefReparoDesc: return "Risco: o reparo automático pode mexer num disco que deveria só ser lido. Desativada por padrão."
        case .prefXattr: return "Etiquetas e metadados do Mac"
        case .xattrTudo: return "Tudo (recomendado)"
        case .xattrEssencial: return "Só o essencial"
        case .xattrNenhum: return "Desligado"
        case .prefIdioma: return "Idioma"
        case .prefLogin: return "Abrir o NTFS Oficial ao iniciar a sessão"
        case .prefAplicar: return "Aplicar alterações"
        case .prefRodape: return "Mudar estas opções pede a senha do Mac. Valem para o próximo disco montado."
        case .prefVersao: return "Versão %@"
        case .prefAplicadoOk: return "Preferências gravadas."
        case .prefLoginErro: return "Não deu para mudar a abertura no login: %@"
        case .lateralDispositivos: return "DISPOSITIVOS"
        case .lateralAjustes: return "Ajustes"
        case .lateralVersao: return "NTFS Oficial %@"
        case .armazenamento: return "Armazenamento"
        case .pctUsado: return "%d%% usado"
        case .colCapacidade: return "Capacidade"
        case .colConexao: return "Conexão"
        case .colAcesso: return "Acesso"
        case .detTecnicosTitulo: return "Detalhes técnicos"
        case .detTecnicosSub: return "Identificador, ponto de montagem e partição."
        case .campoPontoMontagem: return "Ponto de montagem"
        case .campoModelo: return "Modelo"
        case .manTitulo: return "Manutenção"
        case .manSub: return "Verifique e repare possíveis problemas no disco."
        case .manOutras: return "Outras ações"
        case .ajTitulo: return "Ajustes"
        case .ajSubtitulo: return "Configure como seus discos são montados."
        case .ajGeral: return "Geral"
        case .ajGeralSub: return "Idioma e comportamento do aplicativo."
        case .ajMontagem: return "Montagem"
        case .ajMontagemSub: return "Como seus discos NTFS são montados."
        case .ajDesempenho: return "Desempenho"
        case .ajDesempenhoSub: return "Ajustes para melhor desempenho."
        case .ajAvancado: return "Avançado"
        case .ajAvancadoSub: return "Recursos adicionais e manutenção."
        case .ajSobre: return "Sobre"
        case .ajSobreDescricao: return "Driver NTFS para macOS, sem macFUSE."
        case .ajIdiomaDesc: return "Define o idioma da interface do aplicativo."
        case .ajLoginDesc: return "Inicia o aplicativo automaticamente quando você entra no Mac."
        case .ajMontarDesc: return "Permite ler e gravar em discos NTFS no macOS."
        case .ajXattrDesc: return "Define quais metadados do macOS são salvos nos discos NTFS."
        case .ajAvisoProximo: return "Alterações valem para o próximo disco montado."
        }
    }

    private static func ingles(_ c: Chave) -> String {
        switch c {
        case .menuTitulo: return "NTFS disks"
        case .menuNenhum: return "No NTFS disk connected"
        case .menuLivres: return "%@ free of %@"
        case .menuAbrirFinder: return "Show in Finder"
        case .menuEjetar: return "Eject"
        case .menuSoLeitura: return "read-only — %@"
        case .menuNaoMontado: return "(not mounted)"
        case .menuMontar: return "Mount"
        case .menuGerenciador: return "Disk Manager…"
        case .menuPreferencias: return "Preferences…"
        case .menuSair: return "Quit NTFS Oficial"
        case .motivoHibernado: return "Windows hibernated"
        case .motivoSujo: return "unplugged without ejecting"
        case .motivoOutroDriver: return "other driver / NTFS Oficial turned off"
        case .janelaTitulo: return "Disk Manager"
        case .listaGravacao: return "read/write"
        case .listaSoLeitura: return "read-only"
        case .listaNaoMontado: return "not mounted"
        case .semDiscos: return "No NTFS disk connected"
        case .detNaoMontado: return "Not mounted"
        case .seloGravacao: return "Read and write"
        case .seloSoLeitura: return "Read-only"
        case .seloSoLeituraMotivo: return "Read-only — %@"
        case .usados: return "%@ used"
        case .livres: return "%@ free"
        case .campoSistema: return "File system"
        case .campoIdentificador: return "Identifier"
        case .campoModoAcesso: return "Access mode"
        case .campoTipoParticao: return "Partition type"
        case .campoEjetavel: return "Ejectable"
        case .campoDiscoInteiro: return "Whole disk"
        case .modoRapido: return "fast (raw)"
        case .modoPadrao: return "standard (block)"
        case .sim: return "Yes"
        case .nao: return "No"
        case .sistemaOficial: return "NTFS (NTFS Oficial)"
        case .sistemaApple: return "NTFS (Apple, read-only)"
        case .botMontar: return "Mount"
        case .botDesmontar: return "Unmount"
        case .botEjetar: return "Eject"
        case .botVerificar: return "Verify disk"
        case .botReparar: return "Repair…"
        case .botFormatar: return "Format…"
        case .opMontando: return "Mounting…"
        case .opDesmontando: return "Unmounting…"
        case .opEjetando: return "Ejecting…"
        case .opVerificando: return "Verifying… (wait, it may ask for the password)"
        case .opReparando: return "Repairing…"
        case .opFormatando: return "Formatting…"
        case .ok: return "OK"
        case .cancelar: return "Cancel"
        case .falhouGenerico: return "Failed: %@"
        case .ejetarFalhouTitulo: return "Could not eject “%@”"
        case .ejetarFalhouTexto: return "%@\n\nThere are probably open files on the disk. Close the programs using it, or force the eject (data not yet written may be lost)."
        case .forcarEjecao: return "Force eject"
        case .desmontarFalhouTitulo: return "Could not unmount “%@”"
        case .desmontarFalhouTexto: return "%@\n\nThere are probably open files on the disk. Close the programs using it, or force the unmount (data not yet written may be lost)."
        case .forcarDesmontagem: return "Force unmount"
        case .montarFalhouTitulo: return "Could not mount “%@”"
        case .verificarTitulo: return "Verification of “%@”"
        case .verLimpo: return "The disk is clean and can be mounted read/write."
        case .verHibernado: return "The disk is hibernated by Windows (or Fast Startup is on). It only mounts read-only. To write: in Windows, turn off Fast Startup and use Shut down (not Hibernate)."
        case .verSujo: return "The disk was not unplugged properly (dirty flag). Use Repair, or run “chkdsk /f” in Windows."
        case .verErro: return "The verification ended with code %d. See the details below."
        case .verNaoRemontou: return "The disk did not mount again by itself: use Mount."
        case .repararConfirmaTitulo: return "Repair “%@”?"
        case .repararConfirmaTexto: return "The disk will be unmounted, ntfsfix resets the journal and clears the dirty flag, and then the disk is mounted again. Asks for the Mac password.\n\nThis is not a full chkdsk: for serious damage, use “chkdsk /f” in Windows."
        case .repararBotao: return "Repair"
        case .repararOk: return "Repair finished."
        case .repararFalha: return "The repair ended with an error. For serious damage, use “chkdsk /f” in Windows."
        case .senhaCancelada: return "Operation cancelled (no password given)."
        case .formatarTitulo: return "Format “%@”?"
        case .formatarTexto: return "Everything on the disk will be erased. This cannot be undone."
        case .formatarNome: return "Name"
        case .formatarFormato: return "Format"
        case .fmtNTFS: return "NTFS (Windows and Mac)"
        case .fmtExFAT: return "exFAT"
        case .fmtFAT32: return "FAT32 (MS-DOS)"
        case .dicaNTFS: return "Up to 128 characters."
        case .dicaExFAT: return "Up to 11 characters, none of \" * / : < > ? \\ |"
        case .dicaFAT32: return "Up to 11 characters, unaccented capitals only, none of \" * / : < > ? \\ |"
        case .formatarEntendo: return "I understand all files on “%@” will be erased"
        case .formatarApagar: return "Erase and format"
        case .formatarOk: return "“%@” was formatted."
        case .problemaVazio: return "Type a name."
        case .problemaLongo: return "Name too long (maximum %d)."
        case .problemaCaractere: return "Character not allowed: %@"
        case .problemaMaiuscula: return "FAT32 accepts only unaccented capital letters."
        case .avisoDriverTitulo: return "Another NTFS driver is installed"
        case .avisoDriverTexto: return "Found: %@.\n\nTwo NTFS drivers at the same time fight over the disk and can cause errors or data loss. Uninstall the other driver."
        case .drvTuxera: return "Tuxera NTFS"
        case .drvParagon: return "Paragon NTFS"
        case .drvMacFuse: return "ntfs-3g with macFUSE"
        case .prefMontarGravacao: return "Mount NTFS disks read/write"
        case .prefModoRapido: return "Fast mode"
        case .prefModoRapidoDesc: return "Direct disk access for better performance."
        case .prefCache: return "Write with cache"
        case .prefCacheDesc: return "Writes in the background: faster, but always eject before unplugging."
        case .prefReparo: return "Auto-repair a disk unplugged without ejecting"
        case .prefReparoDesc: return "Risk: automatic repair may touch a disk that should only be read. Off by default."
        case .prefXattr: return "Mac tags and metadata"
        case .xattrTudo: return "Everything (recommended)"
        case .xattrEssencial: return "Essentials only"
        case .xattrNenhum: return "Off"
        case .prefIdioma: return "Language"
        case .prefLogin: return "Open NTFS Oficial at login"
        case .prefAplicar: return "Apply changes"
        case .prefRodape: return "Changing these options asks for the Mac password. They apply to the next disk mounted."
        case .prefVersao: return "Version %@"
        case .prefAplicadoOk: return "Preferences saved."
        case .prefLoginErro: return "Could not change open at login: %@"
        case .lateralDispositivos: return "DEVICES"
        case .lateralAjustes: return "Settings"
        case .lateralVersao: return "NTFS Oficial %@"
        case .armazenamento: return "Storage"
        case .pctUsado: return "%d%% used"
        case .colCapacidade: return "Capacity"
        case .colConexao: return "Connection"
        case .colAcesso: return "Access"
        case .detTecnicosTitulo: return "Technical details"
        case .detTecnicosSub: return "Identifier, mount point and partition."
        case .campoPontoMontagem: return "Mount point"
        case .campoModelo: return "Model"
        case .manTitulo: return "Maintenance"
        case .manSub: return "Check and repair possible problems on the disk."
        case .manOutras: return "More actions"
        case .ajTitulo: return "Settings"
        case .ajSubtitulo: return "Configure how your disks are mounted."
        case .ajGeral: return "General"
        case .ajGeralSub: return "App language and behavior."
        case .ajMontagem: return "Mounting"
        case .ajMontagemSub: return "How your NTFS disks are mounted."
        case .ajDesempenho: return "Performance"
        case .ajDesempenhoSub: return "Settings for better performance."
        case .ajAvancado: return "Advanced"
        case .ajAvancadoSub: return "Additional features and maintenance."
        case .ajSobre: return "About"
        case .ajSobreDescricao: return "NTFS driver for macOS, without macFUSE."
        case .ajIdiomaDesc: return "Sets the app interface language."
        case .ajLoginDesc: return "Starts the app automatically when you log in to the Mac."
        case .ajMontarDesc: return "Allows reading and writing on NTFS disks in macOS."
        case .ajXattrDesc: return "Sets which macOS metadata is saved on NTFS disks."
        case .ajAvisoProximo: return "Changes apply to the next disk mounted."
        }
    }
}
