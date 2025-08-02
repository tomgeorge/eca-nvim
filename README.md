# ECA Neovim Plugin

Um plugin para Neovim que integra o [ECA (Editor Code Assistant)](https://eca.dev/) diretamente no editor.

## Funcionalidades

- 🤖 Chat integrado com IA através do ECA
- 📁 Adição de contexto de arquivos e diretórios
- 🎯 Seleção de código como contexto
- 🚀 Download automático do servidor ECA
- ⌨️ Comandos e atalhos personalizáveis
- 🎨 Interface visual integrada ao Neovim
- ✨ Suporte a [markview.nvim](https://github.com/OXY2DEV/markview.nvim) para markdown bonito

## Instalação

### Com lazy.nvim

```lua
{
  "seu-usuario/eca-neovim",
  config = function()
    require("eca").setup({
      -- Configurações opcionais
      debug = false,
      server_path = "", -- Caminho personalizado para o binário ECA
      server_args = "", -- Argumentos extras para o servidor
      behaviour = {
        auto_set_keymaps = true,
        auto_focus_sidebar = true,
      },
      mappings = {
        chat = "<leader>ec",
        focus = "<leader>ef",
        toggle = "<leader>et",
      },
    })
  end
}
```

### Com packer.nvim

```lua
use {
  "seu-usuario/eca-neovim",
  config = function()
    require("eca").setup()
  end
}
```

## Comandos

| Comando | Descrição |
|---------|-----------|
| `:EcaChat` | Abre o chat do ECA |
| `:EcaToggle` | Alterna a visibilidade do sidebar |
| `:EcaFocus` | Foca no sidebar do ECA |
| `:EcaClose` | Fecha o sidebar do ECA |
| `:EcaAddFile [arquivo]` | Adiciona arquivo como contexto |
| `:EcaAddSelection` | Adiciona seleção atual como contexto |
| `:EcaServerStart` | Inicia o servidor ECA |
| `:EcaServerStop` | Para o servidor ECA |
| `:EcaServerRestart` | Reinicia o servidor ECA |
| `:EcaServerStatus` | Mostra status do servidor |
| `:EcaSend <mensagem>` | Envia mensagem para o ECA |

## Atalhos Padrão

| Atalho | Ação |
|--------|------|
| `<leader>ec` | Abrir chat |
| `<leader>ef` | Focar no sidebar |
| `<leader>et` | Alternar sidebar |

## Configuração

```lua
require("eca").setup({
  -- Ativar modo debug
  debug = false,
  
  -- Caminho para o binário ECA (vazio = download automático)
  server_path = "",
  
  -- Argumentos extras para o servidor ECA
  server_args = "--log-level debug",
  
  -- Formato da string de uso (tokens/custo)
  usage_string_format = "{messageCost} / {sessionCost}",
  
  -- Comportamento
  behaviour = {
    auto_set_keymaps = true,     -- Definir atalhos automaticamente
    auto_focus_sidebar = true,   -- Focar automaticamente no sidebar
  },
  
  -- Integração com markview.nvim para markdown bonito
  markview = {
    enable = true,               -- Habilitar markview.nvim
    filetypes = { "markdown", "Eca" }, -- Tipos de arquivo para habilitar
  },
  
  -- Mapeamentos de teclas
  mappings = {
    chat = "<leader>ec",
    focus = "<leader>ef", 
    toggle = "<leader>et",
  },
  
  -- Configurações das janelas
  windows = {
    wrap = true,                 -- Quebra de linha
    width = 40,                  -- Largura em porcentagem (40 = 40% da tela)
    sidebar_header = {
      enabled = true,
      align = "center",
      rounded = true,
    },
    input = {
      prefix = "> ",             -- Prefixo da linha de input
      height = 8,                -- Altura da janela de input
    },
  },
})
```

## Uso

1. **Iniciar o plugin**: Execute `:EcaChat` ou use `<leader>ec`
2. **Enviar mensagens**: Digite sua mensagem e pressione Enter
3. **Adicionar contexto**: Use `:EcaAddFile` para adicionar arquivos ou `:EcaAddSelection` para adicionar seleções
4. **Gerenciar servidor**: Use os comandos `EcaServer*` para controlar o servidor

## Exemplos de Uso

### Adicionar arquivo atual como contexto
```vim
:EcaAddFile
```

### Adicionar arquivo específico como contexto
```vim
:EcaAddFile src/main.lua
```

### Enviar mensagem diretamente
```vim
:EcaSend Explique esta função
```

### Adicionar seleção como contexto
1. Selecione o código em modo visual
2. Execute `:EcaAddSelection`

## Dependências

### Obrigatórias
- Neovim >= 0.8.0
- `curl` (para download automático do servidor)
- `unzip` (para extração do servidor)

### Opcionais
- [markview.nvim](https://github.com/OXY2DEV/markview.nvim) - Para renderização bonita de markdown no chat
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Necessário para markview
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) - Ícones para markview

### Instalando Markview (Recomendado)

```lua
-- Com lazy.nvim
{
  "OXY2DEV/markview.nvim",
  lazy = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  }
}
```

## Solução de Problemas

### Servidor não inicia
- Verifique se `curl` e `unzip` estão instalados
- Tente definir `server_path` manualmente
- Use `:EcaServerStatus` para verificar o status

### Problemas de conectividade
- Verifique sua conexão com a internet
- Verifique se as portas necessárias estão abertas
- Tente reiniciar o servidor com `:EcaServerRestart`

## Desenvolvimento

Para contribuir com o desenvolvimento:

1. Clone o repositório
2. Faça suas alterações
3. Teste com diferentes versões do Neovim
4. Envie um pull request

## Licença

MIT

## Créditos

Baseado no trabalho dos plugins:
- [avante.nvim](https://github.com/yetone/avante.nvim) 
- [eca-vscode](https://github.com/editor-code-assistant/eca-vscode)
