local M = {}

M.setup = function()
    -- nothing for now
end


---@class present.Slides
---@field slides string[]: Slides found in the file


--- Parses lines to produce some slides
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
    local parsed = { slides = {} }
    local current_slide = {}
    local separator = "^# "

    for _, line in ipairs(lines) do
        if line:find(separator) then
            if #current_slide > 0 then
                table.insert(parsed.slides, current_slide)
            end
            current_slide = {}
        end
        table.insert(current_slide, line)
    end

    table.insert(parsed.slides, current_slide)

    return parsed
end


local function create_floating_win(opts)
    opts = opts or {}

    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = opts.row or math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true) -- no file scratch buffer

    local config = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, config)
    return { buf = buf, win = win }
end

M.start_presentation = function(opts)
    opts = opts or {}
    opts.buf_num = opts.buf_num or 0

    local lines = vim.api.nvim_buf_get_lines(opts.buf_num, 0, -1, false)
    local parsed = parse_slides(lines)
    local float = create_floating_win()

    local current_slide = 1

    vim.keymap.set("n", "n", function()
        current_slide = math.min(current_slide + 1, #parsed.slides)
        vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
    end, { buffer = float.buf })

    vim.keymap.set("n", "p", function()
        current_slide = math.max(current_slide - 1, 1)
        vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
    end, { buffer = float.buf })

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(float.win, true)
    end, { buffer = float.buf })

    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
end

M.start_presentation({ buf_num = 76 })

return M
