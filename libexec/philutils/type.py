import difflib
import subprocess
import sys

code = sys.stdin.read()
if code == "":
    sys.exit(1)

try:
    import pygments
    import pygments.formatters
    import pygments.lexers.shell
    import pygments.styles
    import pygments.token
except ImportError as e:
    print(f"INFO: pygment imports failed: {e}")
    print(code)
    sys.exit(0)

if 'pygments' in sys.modules:
    def get_formatter():
        styles = list(pygments.styles.get_all_styles())
        style = 'default'
        # Solarized light is for light background but I tried it on dark background
        # and it looks great
        potential_styles = ['solarized-light', 'vim', 'monokai', 'arduino',
                            'emacs', 'native', 'lovelace', 'paraiso-dark',
                            'rainbow_dash', 'rrt', 'perldoc', 'solarized-dark',
                            'sas', 'stata-dark', 'dracula', 'colorful']
        for s in potential_styles:
            if s in styles:
                style = s
                break
        return pygments.formatters.Terminal256Formatter(style=style)

    lexer = pygments.lexers.shell.BashLexer()
    fmt = get_formatter()
    def highlight(code):
        return pygments.highlight(code, lexer=lexer, formatter=fmt)

print(highlight(code))
