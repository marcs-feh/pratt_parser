package pratt_parser 

import "core:fmt"

Parser :: struct {
	current: int,
	tokens: []Token,
}

parse :: proc(tokens: []Token) -> ^Expression {
	parser := Parser {
		tokens = tokens,
	}

	return parse_expr(&parser, 0)
}

parse_expr :: proc(parser: ^Parser, min_bp: int) -> ^Expression {
	left : ^Expression
	tk := parser_consume(parser)

	#partial switch tk.kind {
	case .Atom:
		left = make_atom(tk.payload)

	case .Plus, .Minus:
		rbp := prefix_binding_power(tk)
		right := parse_expr(parser, rbp)
		left = make_unary(tk.kind, right)

	case:
		fmt.panicf("Unexpected token: %v", tk.kind)
	}

	for {
		lookahead := parser_peek(parser, 0)
		if lookahead.kind == .End_Of_File { break }
		
		lbp, rbp := infix_binding_power(lookahead)
		if lbp < min_bp { break }

		_ = parser_consume(parser)
		right := parse_expr(parser, rbp)

		left = make_binary(left, lookahead.kind, right)
	}

	return left
}

make_unary :: proc(op: TokenKind, operand: ^Expression) -> ^Expression {
	e := new(Expression)
	e^ = UnaryExpr {
		operator = op,
		operand = operand,
	}
	return e
}

make_binary :: proc(lhs: ^Expression, op: TokenKind, rhs: ^Expression) -> ^Expression {
	e := new(Expression)
	e^ = BinaryExpr {
		operator = op,
		left = lhs,
		right = rhs,
	}
	return e
}

make_atom :: proc(a: Atom) -> ^Expression {
	e := new(Expression)
	e^ = a
	return e
}

parser_peek :: proc(parser: ^Parser, delta: int) -> Token {
	if parser.current + delta >= len(parser.tokens){
		return Token { kind = .End_Of_File }
	}
	return parser.tokens[parser.current + delta]
}

@(require_results)
parser_consume :: proc(parser: ^Parser) -> Token {
	if parser.current >= len(parser.tokens){
		return Token { kind = .End_Of_File }
	}
	parser.current += 1
	return parser.tokens[parser.current - 1]
}


prefix_binding_power :: proc(tk: Token) -> (rbp: int){
	#partial switch tk.kind {
	case .Plus, .Minus: return 90
	case: fmt.panicf("Not a unary operator: %v", tk.kind)
	}
}

infix_binding_power :: proc(tk: Token) -> (int, int){
	#partial switch tk.kind {
	case .Plus, .Minus: return 10, 11
	case .Slash, .Star: return 30, 31
	case .Caret: return 61, 60
	case: fmt.panicf("Not a binary operator: %v", tk.kind)
	}
}
