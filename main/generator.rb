require 'textmate_grammar'

# 
# create the grammar
# 
grammar = Grammar.new(
    name: "XData",
    scope_name: "source.xdata",
    fileTypes: [
		"xdata",
    ],
    version: "",
)

# 
# patterns
#
grammar[:type] = Pattern.new(
    Pattern.new(
        match: /\(/,
        tag_as: "punctuation.section storage.type"
    ).then(
        match: /[\w\/]+/,
        tag_as: "storage.type.name"
    ).then(
        match: /\)/,
        tag_as: "punctuation.section storage.type"
    )
)

grammar[:atom] = Pattern.new(
    Pattern.new(
        match:/@/,
        tag_as: "punctuation.section.xdata constant.language.atom.xdata"
    ).then(
        match: /[\w]+/,
        tag_as: "constant.language.atom.xdata"
    )
)

grammar[:number] = Pattern.new(
    tag_as: "constant.numeric",
    match: Pattern.new(
        maybe(/-/).then(/\d+/).maybe(
            Pattern.new(
                tag_as: "constant.numeric.decimal",
                match: /\./,
            ).then(
                match: /\d+/
            )
        )
    )
)

grammar[:comment] = Pattern.new(
    tag_as: "comment.line.number-sign",
    match: Pattern.new(
        Pattern.new(
            match:/#/,
            tag_as: "punctuation.definition.comment"
        ).then(/ .+/)
    )
)

grammar[:inlineString] = [
    :inlineStringLiteral,
    :inlineStringLiteralTriple,
    :inlineStringEscapable
]
grammar[:escapeCharacter] = Pattern.new(
    match:  /\./,
    tag_as: "constant.character.escape"
)
grammar[:inlineStringLiteral] = Pattern.new(
    tag_as: "",
    match: Pattern.new(
        Pattern.new(
            tag_as: "punctuation.definition.string string.quoted.single",
            match: /'/,
        ).then(
            match: /[^']+/,
            tag_as: "string.quoted.single",
        ).then(
            match: /'/,
            tag_as: "punctuation.definition.string string.quoted.single"
        )
    )
)
grammar[:inlineStringLiteralTriple] = Pattern.new(
    Pattern.new(
        triple_single_quote = Pattern.new(
            match: /'''/,
            tag_as: "punctuation.definition.string string.quoted.single"
        )
    ).then(
        match: /.+?'?'?/,
        tag_as: "string.quoted.single"
    ).then(
        triple_single_quote
    )
)
grammar[:inlineStringEscapable] = Pattern.new(
    Pattern.new(
        single_double_quote = Pattern.new(
            match: /"/,
            tag_as: "punctuation.definition.string string.quoted.double"
        )
    ).then(
        match: zeroOrMoreOf(/[^\"\\]|\\./),
        tag_as: "string.quoted.double",
        # TODO: include interpolation inside this pattern
    ).then(
        single_double_quote
    )
)
grammar[:stringBlock] = [
    :stringBlockLiteral,
    :stringBlockEscapable
]

grammar[:key] = Pattern.new(
    tag_as: "meta.key",
    match: oneOf([
        grammar[:atom],
        grammar[:number],
        grammar[:inlineStringLiteral],
        grammar[:inlineStringEscapable],
        # word-key
        Pattern.new(
            match: /\w+/,
            tag_as: "string.unquoted"
        ),
    ]).maybe(
        Pattern.new(/ *+/).then(grammar[:type])
    ).then(/ *+/).then(
        match: /:/,
        tag_as: "punctuation.separator.key-value",
    )
)

# this is actually a wrapper to the real pattern
grammar[:stringBlockLiteral] = PatternRange.new(
    start_pattern: Pattern.new(
        lookBehindFor(/:/).then(
            / *+/
        ).maybe(grammar[:type].then(/ *+/)).then(
            match: /'/,
            tag_as: "punctuation.definition.string string.quoted.single"
        ).then(match: / *\n/)
    ),
    apply_end_pattern_last: 1,
    # look ahead for literally anything (end immediately after internal range ends)
    end_pattern: lookAheadFor(/.|\n/),
    includes: [
        
        # this is the actual string block finder
        PatternRange.new(
            tag_as: "meta.block.string.inner",
            start_pattern: Pattern.new(/\G/).then(
                # find the first indent
                match: /\s+/,
                # debugging tag, non-standard and shouldn't be colored
                tag_as: "indentation.start",
                reference: "indent",
            ),
            # this might throw an error
            # while the indent exists
            while_pattern: matchResultOf("indent"),
            includes: [
                # match the whole line
                Pattern.new(
                    match:  /.*\n/,
                    tag_as: "string.quoted.single.block"
                )
            ]
        )
        
    ]
)

# this is actually a wrapper to the real pattern
grammar[:stringBlockEscapable] = PatternRange.new(
    start_pattern: Pattern.new(
        lookBehindFor(/:/).then(
            / *+/
        ).maybe(grammar[:type].then(/ *+/)).then(
            match: /"/,
            tag_as: "punctuation.definition.string string.quoted.double"
        ).then(match: / *\n/)
    ),
    apply_end_pattern_last: 1,
    # look ahead for literally anything (end immediately after internal range ends)
    end_pattern: lookAheadFor(/.|\n/),
    includes: [
        
        # this is the actual string block finder
        PatternRange.new(
            tag_as: "meta.block.string.inner",
            start_pattern: Pattern.new(/\G/).then(
                # find the first indent
                match: /\s+/,
                # debugging tag, non-standard and shouldn't be colored
                tag_as: "indentation.start",
                reference: "indent",
            ),
            # this might throw an error
            # while the indent exists
            while_pattern: matchResultOf("indent"),
            includes: [
                # TODO: also add the references here!
                
                # match the whole line
                Pattern.new(
                    match:  /.*\n/,
                    tag_as: "string.quoted.double.block"
                )
            ]
        )
    ]
)

grammar[:carat_separator] = Pattern.new(/^ */).then(match:/>/, tag_as: "punctuation.separator.key-value").then(oneOf([/ /, lookAheadFor(/\n/)]))


grammar[:$initial_context] = [
    :key,
    :carat_separator,
    :stringBlock,
    :type,
    :atom,
    :number,
    :comment,
    :inlineString,
    Pattern.new(
        lookBehindFor(/:\s/).or(lookBehindFor(/>\s/)).then(
            match: Pattern.new(/./).then(/.*/), # why is this then here when you could just use .+
                                                # because there's a bug in vs code's textmate parser (AFAIK)
                                                # just try simplifying it and it wont match
            tag_as: "string.unquoted"
        )
    )
]


# 
# export
#
grammar.save_to(
    directory: "../generated/",
    syntax_name: "syntax.tmLanguage",
    tag_name: "scopes.txt",
)