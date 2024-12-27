local parse = require "present"._parse_slides

describe("present.parse_slides", function()
    it("should parse an empty file", function()
        assert.are.same({
            slides = { {
                title = "",
                body = {},
                blocks = {},
            } }
        }, parse {})
    end)

    it("should parse a file with one slide", function()
        assert.are.same({
            slides = { {
                title = "# This is the title",
                body = { "This is the body" },
                blocks = {},
            } }
        }, parse {
            "# This is the title",
            "This is the body",
        })
    end)

    it("should parse a file with one slide and a block", function()
        local results = parse {
            "# This is the title",
            "This is the body",
            "```lua",
            "print('hi')",
            "```"
        }

        assert.are.same(1, #results.slides)

        local slide = results.slides[1]

        assert.are.same("# This is the title", slide.title)
        assert.are.same({
            "This is the body",
            "```lua",
            "print('hi')",
            "```"
        }, slide.body)

        assert.are.same({
            language = "lua",
            body = "print('hi')"
        }, slide.blocks[1])
    end)
end)
