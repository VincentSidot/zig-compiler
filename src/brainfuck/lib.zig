const runner = @import("runner.zig");
const compiler = @import("compiler.zig");

/// Parsed Brainfuck program ready for interpretation.
pub const BrainfuckInterpreter = runner.BrainfuckInterpreter;
/// Raw Brainfuck token emitted by the tokenizer.
pub const Token = runner.Token;
/// Kinds of Brainfuck source tokens.
pub const TokenKind = runner.TokenKind;

/// Loads a Brainfuck source file and prepares it for interpretation.
pub const load_file = runner.load_file;
/// Interprets a prepared Brainfuck program against a memory tape.
pub const interpret = runner.interpret;
/// Compiles a prepared Brainfuck program to native code.
pub const compile = compiler.compile;
/// Compiles a prepared Brainfuck program to native code using the inner engine.
pub const compile_with_engine = compiler.compile_with_engine;
