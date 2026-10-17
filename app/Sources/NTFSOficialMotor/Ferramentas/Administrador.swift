import Foundation

public enum ErroAdministrador: Error, LocalizedError, Equatable {
    case cancelado
    case falha(String)

    public var errorDescription: String? {
        switch self {
        case .cancelado: return "Cancelado pelo usuário."
        case .falha(let texto): return texto
        }
    }
}

/// Roda um comando shell como administrador pela janela de senha padrão do macOS
/// (`do shell script … with administrator privileges`), sem serviço privilegiado fixo.
public enum Administrador {
    /// Cita um argumento com aspas simples para o shell: `a'b` vira `'a'\''b'`.
    public static func citar(_ argumento: String) -> String {
        "'" + argumento.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Monta uma linha de comando com todos os argumentos citados.
    public static func montarComando(_ argumentos: [String]) -> String {
        argumentos.map(citar).joined(separator: " ")
    }

    /// Escapa um texto para dentro de uma string de AppleScript entre aspas duplas.
    public static func escaparAppleScript(_ texto: String) -> String {
        texto.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// O AppleScript completo. O `exec 2>&1;` junta o erro na saída (o `do shell script` só devolve a saída).
    public static func scriptAppleScript(comando: String) -> String {
        "do shell script \"" + escaparAppleScript("exec 2>&1; " + comando) + "\" with administrator privileges"
    }

    /// Executa e devolve a saída. Deve rodar na thread principal (o NSAppleScript não é thread-safe);
    /// a janela de senha é de outro processo, mas a interface do app fica parada enquanto ela está aberta.
    @MainActor
    public static func executar(_ comando: String) throws -> String {
        guard let script = NSAppleScript(source: scriptAppleScript(comando: comando)) else {
            throw ErroAdministrador.falha("Não deu para montar o AppleScript.")
        }
        var erro: NSDictionary?
        let resultado = script.executeAndReturnError(&erro)
        if let erro {
            let numero = (erro[NSAppleScript.errorNumber] as? Int) ?? 0
            if numero == -128 { throw ErroAdministrador.cancelado }
            let mensagem = (erro[NSAppleScript.errorMessage] as? String) ?? "Erro \(numero)"
            throw ErroAdministrador.falha(mensagem)
        }
        return resultado.stringValue ?? ""
    }
}
