package pratt_parser

Error :: union {
	LexerError,
	ParserError,
}

LexerError :: enum byte {
	Unknown_Token,
}

ParserError :: enum byte {
	Missing_Expected,
	Unexpected,
	Operator_Unsupported,
}

