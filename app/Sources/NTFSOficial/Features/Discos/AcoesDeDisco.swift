import SwiftUI
import NTFSOficialMotor

/// Ações dos botões (janela) e dos itens (menu). Mostram progresso e o resultado num alerta.
extension EstadoApp {
    private func executando(_ texto: Chave, _ corpo: @escaping () async -> Void) {
        guard operacaoEmAndamento == nil else { return }
        Task {
            operacaoEmAndamento = Texto.t(texto)
            await corpo()
            operacaoEmAndamento = nil
            monitor.recarregar()
        }
    }

    private func mostrarErro(_ erro: Error, titulo: String) {
        if let e = erro as? ErroAdministrador, e == .cancelado {
            Alertas.informar(titulo: titulo, texto: Texto.t(.senhaCancelada))
        } else {
            Alertas.informar(titulo: titulo, texto: Texto.t(.falhouGenerico, erro.localizedDescription), aviso: true)
        }
    }

    func montar(_ d: Disco) {
        executando(.opMontando) {
            do { try await self.monitor.montar(d.bsdName) }
            catch { self.mostrarErro(error, titulo: Texto.t(.montarFalhouTitulo, d.nome)) }
        }
    }

    func desmontar(_ d: Disco) {
        executando(.opDesmontando) { await self.desmontarOuForcar(d) }
    }

    private func desmontarOuForcar(_ d: Disco, forcar: Bool = false) async {
        do { try await monitor.desmontar(d.bsdName, forcar: forcar) }
        catch let e as ErroDeDisco where !forcar {
            if Alertas.confirmar(titulo: Texto.t(.desmontarFalhouTitulo, d.nome),
                                 texto: Texto.t(.desmontarFalhouTexto, e.texto),
                                 botao: Texto.t(.forcarDesmontagem), destrutivo: true) {
                await desmontarOuForcar(d, forcar: true)
            }
        } catch {
            mostrarErro(error, titulo: Texto.t(.desmontarFalhouTitulo, d.nome))
        }
    }

    func ejetar(_ d: Disco) {
        executando(.opEjetando) { await self.ejetarOuForcar(d) }
    }

    private func ejetarOuForcar(_ d: Disco, forcar: Bool = false) async {
        do { try await monitor.ejetar(d.bsdName, forcar: forcar) }
        catch let e as ErroDeDisco where !forcar {
            if Alertas.confirmar(titulo: Texto.t(.ejetarFalhouTitulo, d.nome),
                                 texto: Texto.t(.ejetarFalhouTexto, e.texto),
                                 botao: Texto.t(.forcarEjecao), destrutivo: true) {
                await ejetarOuForcar(d, forcar: true)
            }
        } catch {
            mostrarErro(error, titulo: Texto.t(.ejetarFalhouTitulo, d.nome))
        }
    }

    func verificar(_ d: Disco) {
        executando(.opVerificando) {
            let titulo = Texto.t(.verificarTitulo, d.nome)
            do {
                let r = try await self.operacoes.verificar(d)
                var texto: String
                switch r.estado {
                case .limpo: texto = Texto.t(.verLimpo)
                case .hibernado: texto = Texto.t(.verHibernado)
                case .sujo: texto = Texto.t(.verSujo)
                case .erro(let codigo): texto = Texto.t(.verErro, codigo)
                }
                if d.montado && !r.remontou { texto += "\n\n" + Texto.t(.verNaoRemontou) }
                Alertas.informar(titulo: titulo, texto: texto, detalhes: r.saida, aviso: r.estado != .limpo)
            } catch {
                self.mostrarErro(error, titulo: titulo)
            }
        }
    }

    func reparar(_ d: Disco) {
        guard Alertas.confirmar(titulo: Texto.t(.repararConfirmaTitulo, d.nome), texto: Texto.t(.repararConfirmaTexto),
                                botao: Texto.t(.repararBotao), destrutivo: false) else { return }
        executando(.opReparando) {
            do {
                let r = try await self.operacoes.reparar(d)
                var texto = r.sucesso ? Texto.t(.repararOk) : Texto.t(.repararFalha)
                if d.montado && !r.remontou { texto += "\n\n" + Texto.t(.verNaoRemontou) }
                Alertas.informar(titulo: d.nome, texto: texto, detalhes: r.saida, aviso: !r.sucesso)
            } catch {
                self.mostrarErro(error, titulo: d.nome)
            }
        }
    }

    func formatar(_ d: Disco, nome: String, formato: FormatoVolume) {
        executando(.opFormatando) {
            do {
                let r = try await self.operacoes.formatar(d, nome: nome, formato: formato)
                Alertas.informar(titulo: nome, texto: Texto.t(.formatarOk, nome), detalhes: r.saida)
            } catch {
                self.mostrarErro(error, titulo: d.nome)
            }
        }
    }

    func abrirNoFinder(_ d: Disco) {
        guard let ponto = d.pontoDeMontagem else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: ponto))
    }
}
