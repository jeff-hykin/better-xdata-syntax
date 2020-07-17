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
        tag_as: "punctuation.type storage.type"
    ).then(
        match: /[\w\/]+/,
        tag_as: "type-name storage.type"
    ).then(
        match: /\)/,
        tag_as: "punctuation.type storage.type"
    )
)

grammar[:atom] = Pattern.new(
    Pattern.new(
        match:/@/,
        tag_as: "punctuation.type.xdata constant.language.atom.xdata"
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
    triple_single_quote = Pattern.new(
        match: /'''/,
        tag_as: "punctuation.definition.string string.quoted.single"
    ).then(
        match: /(.+?'?'?)/,
        tag_as: "string.quoted.single"
    ).then(
        triple_single_quote
    )
)
grammar[:inlineStringEscapable] = Pattern.new(
    single_double_quote = Pattern.new(
        match: /"/,
        tag_as: "punctuation.definition.string string.quoted.double"
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

grammar[:key] = PatternRange.new(
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
        )
    ]).maybe(grammar[:type])
)

# this is actually a wrapper to the real pattern
grammar[:stringBlockLiteral] = PatternRange.new(
    start_pattern: Pattern.new(
        lookBehindFor(/:/).then(
            / *+/
        ).maybe(grammar[:type].then(/ *+/)).then(
            match: /'/,
            tag_as: "punctuation.definition.string string.quoted.single"
        )
    ),
    applyEndPatternLast: 1,
    # look ahead for literally anything (end immediately after internal range ends)
    end_pattern: lookAheadFor(/.|\n/),
    includes: [
        
        # this is the actual string block finder
        PatternRange.new(
            tag_as: "meta.block.string.inner",
            start_pattern: Pattern.new(
                # find the first indent
                match: /\G(\s*)/,
                # debugging tag, non-standard and shouldn't be colored
                tag_as: "indentation.start"
            ),
            # this might throw an error
            # while the indent exists
            while: "\\1",
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
        )
    ),
    applyEndPatternLast: 1,
    # look ahead for literally anything (end immediately after internal range ends)
    end_pattern: lookAheadFor(/.|\n/),
    includes: [
        
        # this is the actual string block finder
        PatternRange.new(
            tag_as: "meta.block.string.inner",
            start_pattern: Pattern.new(
                # find the first indent
                match: /\G(\s*)/,
                # debugging tag, non-standard and shouldn't be colored
                tag_as: "indentation.start"
            ),
            # this might throw an error
            # while the indent exists
            while: "\\1",
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


grammar[:$initial_context] = [
    :key,
    :stringBlock,
    :type,
    :atom,
    :number,
    :comment,
    :inlineString,
]


# 
# export
#
grammar.save_to(
    directory: "../generated/",
    syntax_name: "syntax.tmLanguage.json",
    tag_name: "scopes.txt",
)