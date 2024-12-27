# present.nvim

Tutorial plugin from TJ's Advent of Neovim YouTube series. It presents Markdown files.

# Features

Can execute code inside code blocks present on the slide.

```lua
print("Hello World!")
```

# Also JS

```javascript
console.log("Hello from JavaScript")
```

# And Python

```python
print("This is Python")
```

# Usage

```lua
require("present").start_presentation {}
```

Use `n` to go forward, `p` to go backwards and `q` to quit.
