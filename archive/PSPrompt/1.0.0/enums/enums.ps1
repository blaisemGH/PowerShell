Enum PSPromptAlignment {
    Left = 0
    Right = 1
}

[Flags()] Enum AnsiEffectsFlags {
    bold = 1
    dim = 2
    italicize = 4
    underline = 8
    reverse = 16
    hide = 32
    strikethrough = 64
}
Enum AnsiEffects {
    reset = 0
    bold = 1
    dim = 2
    italicize = 3
    underline = 4
    reverse = 7
    hide = 8
    strikethrough = 9
}