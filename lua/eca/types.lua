---@meta

---@class eca.ChatContext
---@field type string
---@field path? string
---@field linesRange? {start: integer, end: integer}
---@field url? string
---@field uri? string
---@field name? string
---@field description? string
---@field mimeType? string
---@field server string

---@class eca.ChatCommand
---@field name string
---@field description string
---@field help string
---@field type "mcp-prompt"|"native"
---@field arguments {name: string, description?: string, required: boolean}[]

---@alias eca.ToolCallOrigin "mcp"|"native"

---@alias eca.ToolCallDetails eca.FileChangedDetails

---TODO: flesh these out
---@alias eca.MessageParams table
---@alias eca.Message table

---@class eca.FileChangedDetails
---@field type 'fileChange'
---@field path string the file path of this file change
---@field diff string the content diff of this file change
---@field linesAdded integer the count of lines added in this change
---@field linesRemoved integer the count of lines removed in this change

---@class eca.ToolCallRun
---@field type 'toolCallRun'
---@field origin eca.ToolCallOrigin
---@field id string the id of the tool call
---@field name string name of the tool
---@field arguments {[string]: string} arguments of the tool call
---@field manualApproval boolean whether the call requires manual approval from the user
---@field summary string  summary text to present about this tool call
---@field details eca.ToolCallDetails extra details for the call. clients may use this to present a different UX for this tool call.

---@class eca.ToolCalled
---@field type 'toolCalled'
---@field id string the id of the tool call
---@field name string name of the tool
---@field arguments {[string]: string} arguments of the tool call
---@field errors boolean was there an error calling the tool
---@field outputs {type: 'text', text: string}[] the result of the tool call
---@field summary? string summary text to present about the tool call
---@field details? eca.ToolCallDetails extra details about the call
