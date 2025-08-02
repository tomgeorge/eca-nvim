# Changelog - ECA Neovim Plugin

## [1.1.0] - 2025-08-01

### ✨ Added
- **Integração com markview.nvim**: Suporte completo para renderização bonita de markdown
- **Interface melhorada**: Headers com emojis (👤 User, 🤖 ECA)
- **Detecção automática de código**: Código é automaticamente envolvido em blocos ````
- **Separadores visuais**: Separadores entre mensagens para melhor legibilidade
- **Configuração flexível**: Opção para habilitar/desabilitar markview
- **Fallback gracioso**: Funciona mesmo sem markview instalado

### 🔧 Changed
- **Buffer filetype**: Mudado de "Eca" para "markdown" para melhor compatibilidade
- **Configuração de largura**: Corrigido cálculo de porcentagem da tela
- **API do markview**: Atualizado para usar a nova API (preview.filetypes, markdown.*)

### 🐛 Fixed
- **Warnings do markview**: Removidos avisos de API depreciada
- **Erro de attach**: Corrigido erro "attempt to call field 'attach'"
- **Refresh de renderização**: Melhorado método de re-renderização do markview

### 📚 Documentation
- **MARKVIEW.md**: Guia completo de integração com markview.nvim
- **README.md**: Atualizado com informações sobre markview
- **example-config.lua**: Exemplo de configuração com markview
- **test-markview.lua**: Script de teste para verificar instalação

### 🛠 Technical
- **Compatibilidade**: Suporte a diferentes versões da API do markview
- **Configuração modular**: Sistema de configuração mais flexível
- **Detecção automática**: Detecção inteligente de código vs texto

## [1.0.0] - 2025-08-01

### 🎉 Initial Release
- **Chat integrado**: Interface de chat com ECA no sidebar
- **Download automático**: Download e configuração automática do servidor ECA
- **Comandos Vim**: Comandos como `:EcaChat`, `:EcaToggle`, etc.
- **Atalhos personalizáveis**: Mapeamentos de teclas configuráveis
- **Contexto de arquivos**: Adição de arquivos e seleções como contexto
- **Interface responsiva**: Sidebar redimensionável e configurável
- **Sistema de cores**: Highlights personalizadas para o chat

### 🏗 Architecture
- **Estrutura modular**: Código organizado em módulos (config, sidebar, server, etc.)
- **Configuração flexível**: Sistema de configuração inspirado no avante.nvim
- **Protocolo JSON-RPC**: Base para comunicação com servidor ECA
- **Plugin system**: Integração nativa com sistema de plugins do Neovim
