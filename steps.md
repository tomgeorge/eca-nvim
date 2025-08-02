# Plano para o Plugin eca-neovim

Este documento serve como guia para implementar um plugin do Neovim em Lua que integra o utilitário "eca", inspirado nos plugins `avante.nvim` (para Neovim) e `eca-vscode` (para VSCode).

## Objetivo
Criar um plugin que permita ao usuário do Neovim acessar funcionalidades do utilitário "eca" diretamente do editor, de maneira semelhante ao que já existe no Avante (Neovim) e ECA (VSCode).

---

## 1. Análise dos Plugins de Referência
- **Avante.nvim**: Analisar a estrutura, como conecta ao backend, comandos Neovim, autocommands, patterns de integração, comunicação e interface com o usuário.
- **eca-vscode**: Examinar funcionalidades oferecidas, arquitetura de comunicação com utilitário "eca", UX e principais fluxos usados.

## 2. Definição de Funcionalidades
- Listar e priorizar as funcionalidades essenciais para o plugin Neovim, inspirado nos plugins de referência.
  - Exemplos:
    - Comunicação cliente-servidor com o "eca"
    - Comandos interativos (diagnóstico de código, sugestões, etc.)
    - Interface de usuário integrada ao Neovim (comandos, menus, atalhos)

## 3. Estrutura Inicial do Projeto (Lua)
- Criar estrutura de arquivos padrão para plugins Lua de Neovim.
  - `lua/eca/init.lua` (entrypoint)
  - README
  - steps.md (este guia)
- Definir escopo mínimo e modularidade do código.

## 4. Conector: Comunicação com ECA
- Implementar client em Lua para conectar ao utilitário ECA (ex: via socket, HTTP, stdin/stdout — depende do utilitário).
- Considerar mecanismos de request/response, callbacks, parsing de dados, etc.

## 5. Integração e Comandos Neovim
- Criar comandos Neovim que utilizam o backend ECA:
  - Ex: `:EcaDiagnose`, `:EcaSuggest`, etc.
- Traduzir respostas do ECA para formato amigável no editor (mensagens, splits, popups).

## 6. Testes e Documentação
- Testar funcionalidade na prática, em vários cenários.
- Escrever documentação de instalação, uso e troubleshooting.

---

## Observações da Sessão
- Para referência, os repositórios de inspiração:
  - avante.nvim: `~/repos/avante.nvim`
  - eca-vscode: `~/repos/eca-vscode`
- O objetivo é sempre focar UX integrada, rapidez e feedback visual claro ao usuário.
- Iterar a implementação a partir dos testes e feedbacks.

