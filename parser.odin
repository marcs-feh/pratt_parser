package pratt_parser 

import "core:fmt"

Parser :: struct {
	current: int,
	tokens: []Token,
}

parse :: proc(tokens: []Token) -> (^Expression, Error) {
	parser := Parser {
		current = 0,
		tokens = tokens,
	}
	return parse_expr(&parser, 0)
}

parse_expr :: proc(parser: ^Parser, min_bp: int) -> (left: ^Expression, err: Error) {
	head := parser_consume(parser)

	// Unary or Primary expression
	#partial switch head.kind {
	case .Number, .Identifier:
		left = make_primary(head.payload)
	case .ParenOpen:
		left = parse_expr(parser, 0) or_return
		if tk, ok := parser_consume_expected(parser, .ParenClose); !ok {
			fmt.printf("Expected ')' but found %v", tk.kind)
			return nil, .Missing_Expected
		}
	case .Plus, .Minus:
		rbp, prefix_ok := prefix_binding_power(head)
		assert(prefix_ok)
		right := parse_expr(parser, rbp) or_return
		left = make_unary(head.kind, right)
	case:
		fmt.printf("Unexpected token: %v", head.kind)
		return nil, .Unexpected
	}

	// Binary "precedence climbing"
	for {
		lookahead := parser_peek(parser, 0)
		if lookahead.kind == .End_Of_File { break }

		// Handle postfix operator and "pseudo infix" ones like indexing
		if lbp, ok := postfix_binding_power(lookahead); ok {
			if lbp < min_bp { break }
			_ = parser_consume(parser)

			#partial switch lookahead.kind {
			case .SquareOpen:
				index := parse_expr(parser, 0) or_return
				if tk, ok := parser_consume_expected(parser, .SquareClose); !ok {
					fmt.printfln("Expression ']' but found %v", tk.kind)
					return nil, .Missing_Expected
				}
				left = make_index(left, index)
			case .ParenOpen:
				unimplemented()
			case:
				left = make_unary(lookahead.kind, left)
			}
			continue
		}
		
		if lbp, rbp, ok := infix_binding_power(lookahead); ok {
			if lbp < min_bp { break }

			_ = parser_consume(parser)
			right := parse_expr(parser, rbp) or_return

			left = make_binary(left, lookahead.kind, right)
		}

		// If nothing is hit, just break out
		break
	}

	return
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

@(require_results)
parser_consume_expected :: proc(parser: ^Parser, expect: TokenKind) -> (Token, bool){
	tk := parser_consume(parser)
	if tk.kind != expect {
		parser.current -= 1
		return tk, false
	}
	return tk, true
}

prefix_binding_power :: proc(tk: Token) -> (rbp: int, ok := false){
	#partial switch tk.kind {
	case .Plus, .Minus: return 90, true
	case: return
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
