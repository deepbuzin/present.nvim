local parse = require "present"._parse_slides

describe("present.parse_slides", function()
    it("should parse an empty file", function()
        assert.are.same({
            slides = { {
                title = "",
                body = {},
            } }
        }, parse {})
    end)

    it("should parse a file with one slide", function()
        assert.are.same({
            slides = { {
                title = "# This is the title",
                body = { "This is the body" },
            } }
        }, parse {
            "# This is the title",
            "This is the body",

        })
    end)
end)
