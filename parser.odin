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

	// Unary or Primary expression
	#partial switch tk.kind {
	case .Number, .Identifier:
		left = make_primary(tk.payload)
	case .ParenOpen:
		left = parse_expr(parser, 0)
		assert(parser_consume(parser).kind == .ParenClose, "Expected ')'")
	case .Plus, .Minus:
		rbp := prefix_binding_power(tk)
		right := parse_expr(parser, rbp)
		left = make_unary(tk.kind, right)
	case:
		fmt.panicf("Unexpected token: %v", tk.kind)
	}

	// Binary "precedence climbing"
	for {
		lookahead := parser_peek(parser, 0)
		if lookahead.kind == .End_Of_File { break }

		// Handle postfix operator and "pseudo infix" ones like indexing
		if lbp, ok := postfix_binding_power(lookahead); ok {
			if lbp < min_bp { break }
			_ = parser_consume(parser)

			if lookahead.kind == .SquareOpen {
				index := parse_expr(parser, 0)
				assert(parser_consume(parser).kind == .SquareClose, "Expected ']'")
				left = make_index(left, index)
			}
			else {
				left = make_unary(lookahead.kind, left)
			}
			continue
		}
		
		if lbp, rbp, ok := infix_binding_power(lookahead); ok {
			if lbp < min_bp { break }

			_ = parser_consume(parser)
			right := parse_expr(parser, rbp)

			left = make_binary(left, lookahead.kind, right)
		}

		// If nothing is hit, just break out
		break
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

make_index :: proc(object: ^Expression, index: ^Expression) -> ^Expression {
	e := new(Expression)
	e^ = IndexExpr {
		object = object,
		index = index,
	}
	return e
}

make_primary :: proc(a: $T) -> ^Expression {
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

infix_binding_power :: proc(tk: Token) -> (lbp: int, rbp: int, ok := false){
	#partial switch tk.kind {
	case .Plus, .Minus: lbp, rbp = 10, 11
	case .Slash, .Star: lbp, rbp = 30, 31
	case .Caret: 		lbp, rbp = 61, 60
	}

	if lbp != 0 && rbp != 0 { ok = true }
	return
}

postfix_binding_power :: proc(tk: Token) -> (lbp: int, ok := false){
	// NOTE: *ONLY* for postfix operators, it's OK to have the same binding power.
	#partial switch tk.kind {
	case .Bang, .SquareOpen: return 100, true
	}
	return
}


Expression :: union {
	Primary, UnaryExpr, BinaryExpr, IndexExpr,
}

Primary :: union #no_nil {
	Number,
	Identifier,
}

UnaryExpr :: struct {
	operator: TokenKind,
	operand: ^Expression,
}

BinaryExpr :: struct {
	operator: TokenKind,
	left: ^Expression,
	right: ^Expression,
}

// NOTE: Idexing is technically just a BinaryExpr, however, because it is
//       semantically very distinct during type checking, it is kept as a 
//       separate type for organizational purposes
IndexExpr :: struct {
	object: ^Expression,
	index: ^Expression,
}
