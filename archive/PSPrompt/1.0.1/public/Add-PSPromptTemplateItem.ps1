<#
    .SYNOPSIS
        A helper function for adding prompt templates. See the parameter comments for specific information.
#>
function Add-PSPromptTemplateItem {
    param(
        # The scriptblock (anonymous function) that calculates the prompt item's contents
        [Parameter(Mandatory)]
        [scriptblock]$ContentFunction,

        # Align left or right on your prompt line. Note that adding a right-aligned item will force a multi-line prompt.
        [PSPromptAlignment]$Alignment = 'Left',

        # The text color, see Get-FormattedColors for samples. Any color in the 'Color' column can be entered. Or arbitrary rgb values as: 'r;g;b'.
        [object]$ForegroundColor,

        # Background color, see Get-FormattedColors for samples. Any color in the 'Color' column can be entered. Or arbitrary rgb values as: 'r;g;b'.
        [object]$BackgroundColor,

        # The string used to divide items. Defaults to empty, i.e., no divider.
        [string]$ItemSeparator,

        # Ansi Effects. See [AnsiEffectsFlags].GetEnumNames() for a list. These can be entered as comma-delimited strings or numbers.
        [AnsiEffectsFlags]$AnsiEffects,

        # Calculates the value of ContentFunction once when added and recycles this value instead of recalculating at every prompt line.
        # Saves performance for static values like PSVersion (although PSVersion itself would be trivial to recalculate).
        [switch]$DoNotRecalculateContentValue,

        # Groups items together. If specified greater than 0, then applies default group wrappers  and . These can be adjusted.
        # Note: String values are accepted to make it easier to group common items together.
        [string]$Group = 0,

        # Forces an explicit position of the item. For example, 3 guarantees it will be the 3rd item in its alignment.
        # By default, each item is positioned according to the order it was added to PSPrompt.
        # Note: If groups are specified, then the group takes priority. ItemPosition=3 but Group=1 will not overwride the 3rd item in Group=0.
        [int]$ItemPosition,

        # The prompt is typically 1 line, and long prompts will automatically wrap to multiple lines.
        # However, one can explicitly designate the line via this parameter.
        # Empty lines are currently ignored, e.g., LineToPrintOn=5 won't print empty lines 2-4.
        [int]$LineToPrintOn = 1
        
    )
    [PSPromptConfig]::AddTemplate($PSBoundParameters)
}