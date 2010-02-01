USING: help.markup help.syntax words math source-files
parser quotations definitions stack-checker.errors ;
IN: compiler.units

ARTICLE: "compilation-units-internals" "Compilation units internals"
"These words do not need to be called directly, and only serve to support the implementation."
$nl
"Compiling a set of words:"
{ $subsections compile }
"Words called to associate a definition with a compilation unit and a source file location:"
{ $subsections
    remember-definition
    remember-class
}
"Forward reference checking (see " { $link "definition-checking" } "):"
{ $subsections forward-reference? }
"A hook to be called at the end of the compilation unit. If the optimizing compiler is loaded, this compiles new words with the " { $link "compiler" } ":"
{ $subsections recompile }
"Low-level compiler interface exported by the Factor VM:"
{ $subsections modify-code-heap } ;

ARTICLE: "compilation-units" "Compilation units"
"A " { $emphasis "compilation unit" } " scopes a group of related definitions. They are compiled and entered into the system in one atomic operation."
$nl
"When a source file is being parsed, all definitions are part of a single compilation unit, unless the " { $link POSTPONE: << } " parsing word is used to create nested compilation units."
$nl
"Words defined in a compilation unit may not be called until the compilation unit is finished. The parser detects this case for parsing words and throws a " { $link staging-violation } ". Similarly, an attempt to use a macro from a word defined in the same compilation unit will throw a " { $link transform-expansion-error } ". Calling any other word from within its own compilation unit throws an " { $link undefined } " error."
$nl
"This means that parsing words and macros generally cannot be used in the same source file as they are defined. There are two means of getting around this:"
{ $list
    { "The simplest way is to split off the parsing words and macros into sub-vocabularies; perhaps suffixed by " { $snippet ".syntax" } " and " { $snippet ".macros" } "." }
    { "Alternatively, nested compilation units can be created using " { $link "syntax-immediate" } "." }
}
"Parsing words which create new definitions at parse time will implicitly add them to the compilation unit of the current source file. Code which creates new definitions at run time will need to explicitly create a compilation unit with a combinator:"
{ $subsections with-compilation-unit }
"Additional topics:"
{ $subsections "compilation-units-internals" } ;

ABOUT: "compilation-units"

HELP: redefine-error
{ $values { "definition" "a definition specifier" } }
{ $description "Throws a " { $link redefine-error } "." }
{ $error-description "Indicates that a single source file contains two definitions for the same artifact, one of which shadows the other. This is an error since it indicates a likely mistake, such as two words accidentally named the same by the developer; the error is restartable." } ;

HELP: remember-definition
{ $values { "definition" "a definition specifier" } { "loc" "a " { $snippet "{ path line# }" } " pair" } }
{ $description "Saves the location of a definition and associates this definition with the current source file." } ;

HELP: old-definitions
{ $var-description "Stores an assoc where the keys form the set of definitions which were defined by " { $link file } " the most recent time it was loaded." } ;

HELP: new-definitions
{ $var-description "Stores an assoc where the keys form the set of definitions which were defined so far by the current parsing of " { $link file } "." } ;

HELP: with-compilation-unit
{ $values { "quot" quotation } }
{ $description "Calls a quotation in a new compilation unit. The quotation can define new words and classes, as well as forget words. When the quotation returns, any changed words are recompiled, and changes are applied atomically." }
{ $notes "Compilation units may be nested."
$nl
"The parser wraps every source file in a compilation unit, so parsing words may define new words without having to perform extra work; to define new words at any other time, you must wrap your defining code with this combinator."
$nl
"Since compilation is relatively expensive, you should try to batch up as many definitions into one compilation unit as possible." } ;

HELP: recompile
{ $values { "words" "a sequence of words" } { "alist" "an association list mapping words to compiled definitions" } }
{ $contract "Internal word which compiles words. Called at the end of " { $link with-compilation-unit } "." } ;

HELP: no-compilation-unit
{ $values { "word" word } }
{ $description "Throws a " { $link no-compilation-unit } " error." }
{ $error-description "Thrown when an attempt is made to define a word outside of a " { $link with-compilation-unit } " combinator." } ;

HELP: modify-code-heap ( alist update-existing? reset-pics? -- )
{ $values { "alist" "an alist" } { "update-existing?" "a boolean" } { "reset-pics?" "a boolean" } }
{ $description "Stores compiled code definitions in the code heap. The alist maps words to the following:"
{ $list
    { "a quotation - in this case, the quotation is compiled with the non-optimizing compiler and the word will call the quotation when executed." }
    { { $snippet "{ code labels rel words literals }" } " - in this case, a code heap block is allocated with the given data and the word will call the code block when executed." }
} }
{ $notes "This word is called at the end of " { $link with-compilation-unit } "." } ;

HELP: compile
{ $values { "words" "a sequence of words" } }
{ $description "Compiles a set of words." } ;
