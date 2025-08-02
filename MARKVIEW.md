# Integração com Markview.nvim

O plugin ECA para Neovim inclui integração nativa com o [markview.nvim](https://github.com/OXY2DEV/markview.nvim) para renderização bonita de markdown no chat.

## Instalação do Markview

### Com lazy.nvim

```lua
{
  "OXY2DEV/markview.nvim",
  lazy = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  },
  opts = {
    preview = {
      filetypes = { "markdown", "Eca" }, -- Inclui "Eca" para o chat
      ignore_buftypes = {},
    }
  }
}
```

### Com packer.nvim

```lua
use {
  "OXY2DEV/markview.nvim",
  requires = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons"
  },
  config = function()
    require("markview").setup({
      preview = {
        filetypes = { "markdown", "Eca" }
      }
    })
  end
}
```

## Configuração do ECA com Markview

```lua
require("eca").setup({
  markview = {
    enable = true, -- Habilita integração com markview
    filetypes = { "markdown", "Eca" }, -- Tipos de arquivo para habilitar
  },
  -- ... outras configurações
})
```

## Funcionalidades Suportadas

O ECA com markview.nvim oferece:

- ✅ **Cabeçalhos**: `#`, `##`, `###` renderizados com destaque
- ✅ **Texto em negrito**: `**texto**` e `__texto__`
- ✅ **Texto em itálico**: `*texto*` e `_texto_`
- ✅ **Código inline**: `` `código` ``
- ✅ **Blocos de código**: ````código```` com destaque de sintaxe
- ✅ **Listas**: `- item`, `* item`, `1. item`
- ✅ **Citações**: `> citação`
- ✅ **Links**: `[texto](url)`
- ✅ **Separadores**: `---`
- ✅ **Tabelas**: Markdown tables
- ✅ **Emojis**: 🤖, 👤, 💡, etc.

## Exemplos de Renderização

### Entrada do usuário:
```markdown
## 👤 You

Como posso melhorar este código?

```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```
```

### Resposta do ECA:
```markdown
## 🤖 ECA

Aqui estão algumas **melhorias** para o código:

### 1. 🚀 Memorização (Memoization)

```python
from functools import lru_cache

@lru_cache(maxsize=None)
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

### 2. 💡 Implementação Iterativa

```python
def fibonacci(n):
    if n <= 1:
        return n
    
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b
```

> **Dica**: A versão iterativa é mais eficiente para números grandes!
```

## Desabilitando o Markview

Se preferir usar markdown simples, desabilite o markview:

```lua
require("eca").setup({
  markview = {
    enable = false, -- Desabilita markview
  },
})
```

## Solução de Problemas

### Markview não funciona
1. Verifique se o plugin está instalado: `:Lazy check markview.nvim`
2. Verifique se treesitter está configurado: `:TSInstall markdown`
3. Reinicie o Neovim após instalar

### Performance lenta
Se o markview estiver lento com chats longos:

```lua
require("eca").setup({
  markview = {
    enable = true,
    filetypes = { "markdown" }, -- Remove "Eca" se necessário
  },
})
```

### Conflitos de highlight
Se houver conflitos visuais:

```lua
-- No seu init.lua, após configurar o markview
vim.api.nvim_set_hl(0, "MarkviewHeading1", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "MarkviewCode", { bg = "#1a1b26", fg = "#bb9af7" })
```
