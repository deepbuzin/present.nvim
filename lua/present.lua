local M = {}

M.create_system_executor = function(program)
    return function(block)
        local tempfile = vim.fn.tempname()
        vim.fn.writefile(vim.split(block.body, "\n"), tempfile)

        local result = vim.system({ program, tempfile }, { text = true }):wait()
        return vim.split(result.stdout, "\n")
    end
end

--- Default executor for Lua
---@param block present.Block
local execute_lua_code = function(block)
    -- Override the print function to capture output
    local original_print = print

    local output = {}

    -- Redefine print
    print = function(...)
        local args = { ... }
        local message = table.concat(vim.tbl_map(tostring, args), "\t")
        table.insert(output, message)
    end

    local chunk = loadstring(block.body)

    pcall(function()
        if not chunk then
            table.insert(output, "BROKEN CODE")
        else
            chunk()
        end
        return output
    end)

    -- Restore original print
    print = original_print
    return output
end

local execute_js_code = M.create_system_executor("node")
local execute_python_code = M.create_system_executor("python3")

local options = {
    executors = {
        lua = execute_lua_code,
        javascript = execute_js_code,
        python = execute_python_code,
    }
}

M.setup = function(opts)
    opts = opts or {}
    opts.executors = opts.executors or {}

    opts.executors.lua = opts.executors.lua or execute_lua_code
    opts.executors.javascript = opts.executors.javascript or M.create_system_executor "node"
    opts.executors.python = opts.executors.python or M.create_system_executor "python3"

    options = opts
end


---@class present.Slides
---@field slides present.Slide[]: Slides found in the file
---
---@class present.Slide
---@field title string: The title of the slide
---@field body string[]: The body of the slide
---@field blocks present.Block[]: A codeblock inside of a slide

---@class present.Block
---@field language string: Language of the block
---@field body string: The body of the code block

--- Parses lines to produce some slides
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
    local parsed = { slides = {} }
    local current_slide = {
        title = "",
        body = {},
        blocks = {},
    }

    local separator = "^# "

    for _, line in ipairs(lines) do
        if line:find(separator) then
            if #current_slide.title > 0 then
                table.insert(parsed.slides, current_slide)
            end
            current_slide = {
                title = line,
                body = {},
                blocks = {},
            }
        else
            table.insert(current_slide.body, line)
        end
    end

    table.insert(parsed.slides, current_slide)

    for _, slide in ipairs(parsed.slides) do
        local block = {
            language = nil,
            body = "",
        }
        local inside_block = false

        for _, line in ipairs(slide.body) do
            --- Check for start and end of the block
            if vim.startswith(line, "```") then
                if not inside_block then
                    inside_block = true
                    block.language = string.sub(line, 4)
                else
                    --- Append and reset the block
                    inside_block = false
                    block.body = vim.trim(block.body)
                    table.insert(slide.blocks, block)
                end
            else
                --- Insede of a block but not one of the ticks
                if inside_block then
                    block.body = block.body .. line .. "\n"
                end
            end
        end
    end

    return parsed
end


local function create_floating_win(config, enter)
    if enter == nil then
        enter = false
    end

    local buf = vim.api.nvim_create_buf(false, enter) -- no file scratch buffer
    local win = vim.api.nvim_open_win(buf, true, config)
    return { buf = buf, win = win }
end

local create_window_configs = function()
    local width = vim.o.columns
    local height = vim.o.lines

    local header_height = 1 + 2                                    -- 1 line + 2 borders
    local footer_height = 1                                        -- 1 line
    local body_height = height - header_height - footer_height - 3 -- 1 offset + 2 borders

    return {
        header = {
            relative = "editor",
            width = width,
            height = 1,
            col = 0,
            row = 0,
            style = "minimal",
            border = "solid",
            zindex = 2,
        },
        body = {
            relative = "editor",
            width = width - 8,
            height = body_height,
            col = 8,
            row = 4,
            style = "minimal",
            border = "solid",
            zindex = 2,
        },
        footer = {
            relative = "editor",
            width = width,
            height = 1,
            col = 0,
            row = height - 1,
            style = "minimal",
            border = "none",
            zindex = 2,
        },
        background = {
            relative = "editor",
            width = width,
            height = height,
            col = 0,
            row = 0,
            style = "minimal",
            border = "none",
            zindex = 1,
        },
    }
end


local state = {
    parsed = {},
    current_slide = 1,
    filename = "",
    floats = {},
}

local foreach_float = function(callback)
    for name, float in pairs(state.floats) do
        callback(name, float)
    end
end

local assign_keymap = function(mode, key, callback)
    vim.keymap.set(mode, key, callback, { buffer = state.floats.body.buf })
end

M.start_presentation = function(opts)
    opts = opts or {}
    opts.bufnr = opts.bufnr or 0

    local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
    state.parsed = parse_slides(lines)
    state.current_slide = 1
    state.filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

    local windows = create_window_configs()
    state.floats.background = create_floating_win(windows.background)
    state.floats.header = create_floating_win(windows.header)
    state.floats.footer = create_floating_win(windows.footer)
    state.floats.body = create_floating_win(windows.body, true)

    foreach_float(function(_, float)
        vim.bo[float.buf].filetype = "markdown"
    end)

    local set_slide_content = function(idx)
        local slide = state.parsed.slides[idx]
        local width = vim.o.columns

        local padding = string.rep(" ", (width - #slide.title) / 2)
        local title = padding .. slide.title

        local footer = string.format(
            " %d / %d | %s",
            state.current_slide,
            #state.parsed.slides,
            state.filename
        )

        vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { title })
        vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
        vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer })
    end


    -- Create keybindings for navigation
    assign_keymap("n", "n", function()
        state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
        set_slide_content(state.current_slide)
    end)

    assign_keymap("n", "p", function()
        state.current_slide = math.max(state.current_slide - 1, 1)
        set_slide_content(state.current_slide)
    end)

    assign_keymap("n", "q", function()
        vim.api.nvim_win_close(state.floats.body.win, true)
    end)

    assign_keymap("n", "X", function()
        local slide = state.parsed.slides[state.current_slide]
        local block = slide.blocks[1]

        if not block then
            print("No blocks found on this page")
            return
        end

        local executor = options.executors[block.language]
        if not executor then
            print("No valid executor for this language")
        end

        -- This is where print messages will go
        local output = { "# Code", "", "```" .. block.language }
        vim.list_extend(output, vim.split(block.body, "\n"))
        table.insert(output, "```")

        table.insert(output, "")
        table.insert(output, "# Output ")
        table.insert(output, "")
        vim.list_extend(output, executor(block))

        local buf = vim.api.nvim_create_buf(false, true) -- no file scratch buffer
        local temp_width = math.floor(vim.o.columns * 0.8)
        local temp_height = math.floor(vim.o.lines * 0.8)

        vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            style = "minimal",
            width = temp_width,
            height = temp_height,
            row = math.floor((vim.o.lines - temp_height) / 2),
            col = math.floor((vim.o.columns - temp_width) / 2),
            noautocmd = true,
            border = "rounded",
        })

        vim.bo[buf].filetype = "markdown"
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
    end)

    -- Save and override options in present mode
    local restore = {
        cmdheight = {
            original = vim.o.cmdheight,
            present = 0,
        }
    }

    for option, config in pairs(restore) do
        vim.opt[option] = config.present
    end

    -- Restore options after leaving the buffer
    vim.api.nvim_create_autocmd("BufLeave", {
        buffer = state.floats.body.buf,
        callback = function()
            for option, config in pairs(restore) do
                vim.opt[option] = config.original
            end

            -- When leaving body also close header
            foreach_float(function(_, float)
                pcall(vim.api.nvim_win_close, float.win, true)
                pcall(vim.api.nvim_buf_delete, float.buf, { force = true })
            end)
        end
    })

    vim.api.nvim_create_autocmd("VimResized", {
        group = vim.api.nvim_create_augroup("present-resized", {}),
        callback = function()
            if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
                return
            end

            local updated = create_window_configs()

            foreach_float(function(name, _)
                vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
            end)
            set_slide_content(state.current_slide)
        end
    })

    set_slide_content(state.current_slide)
end

-- M.start_presentation({ bufnr = 3 })

M._parse_slides = parse_slides

return M
