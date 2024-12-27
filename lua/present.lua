local M = {}

M.setup = function()
    -- nothing for now
end

---@class present.Slide
---@field title string: The title of the slide
---@field body string[]: The body of the slide

---@class present.Slides
---@field slides present.Slide[]: Slides found in the file


--- Parses lines to produce some slides
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parse_slides = function(lines)
    local parsed = { slides = {} }
    local current_slide = {
        title = "",
        body = {}
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
            }
        else
            table.insert(current_slide.body, line)
        end
    end

    table.insert(parsed.slides, current_slide)

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
