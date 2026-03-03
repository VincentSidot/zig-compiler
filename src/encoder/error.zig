pub const EncodingError = error{
    /// The provided operand combination is not valid for encoding.
    InvalidOperand,
    /// The provided index register is invalid (e.g., RSP or R12 cannot be used as index registers).
    InvalidIndexRegister,
    /// The patch address does not reference a complete instruction/immediate window.
    InvalidPatchAddress,
    /// The computed relative displacement cannot be represented in the target immediate width.
    InvalidDisplacement,
    /// An error occurred while writing bytes to the writer.
    WriterError,
};
