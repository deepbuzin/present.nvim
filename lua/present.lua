local M = {}

M.setup = function()
    -- nothing for now
end

---@class present.Slide
---@field title string: The title of the slide
---@field body string: The body of the slide

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


local function create_floating_win(config)
    local buf = vim.api.nvim_create_buf(false, true) -- no file scratch buffer
    local win = vim.api.nvim_open_win(buf, true, config)
    return { buf = buf, win = win }
end

M.start_presentation = function(opts)
    opts = opts or {}
    opts.bufnr = opts.bufnr or 0

    local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
    local parsed = parse_slides(lines)

    local width = vim.o.columns
    local height = vim.o.lines

    ---@type vim.api.keyset.win_config[]
    local windows = {
        header = {
            relative = "editor",
            width = width,
            height = 1,
            col = 1,
            row = 0,
            style = "minimal",
            border = "solid",
            zindex = 2,
        },
        body = {
            relative = "editor",
            width = width - 8,
            height = height - 5,
            col = 8,
            row = 4,
            style = "minimal",
            border = "solid",
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
        }
    }

    local background_float = create_floating_win(windows.background)
    local header_float = create_floating_win(windows.header)
    local body_float = create_floating_win(windows.body)

    vim.bo[header_float.buf].filetype = "markdown"
    vim.bo[body_float.buf].filetype = "markdown"

    local set_slide_content = function(idx)
        local slide = parsed.slides[idx]

        local padding = string.rep(" ", (width - #slide.title) / 2)
        local title = padding .. slide.title

        vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { title })
        vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
    end

    local current_slide = 1

    -- Create keybindings for navigation
    vim.keymap.set("n", "n", function()
        current_slide = math.min(current_slide + 1, #parsed.slides)
        set_slide_content(current_slide)
    end, { buffer = body_float.buf })

    vim.keymap.set("n", "p", function()
        current_slide = math.max(current_slide - 1, 1)
        set_slide_content(current_slide)
    end, { buffer = body_float.buf })

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(body_float.win, true)
    end, { buffer = body_float.buf })

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
        buffer = body_float.buf,
        callback = function()
            for option, config in pairs(restore) do
                vim.opt[option] = config.original
            end

            -- When leaving body also close header
            pcall(vim.api.nvim_win_close, header_float.win, true)
            pcall(vim.api.nvim_win_close, background_float.win, true)
        end
    })

    set_slide_content(current_slide)
end

M.start_presentation({ bufnr = 22 })

return M
