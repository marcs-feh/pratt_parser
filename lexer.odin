package pratt_parser

import "core:fmt"
import "core:strconv"
import "core:unicode"
import str "core:strings"
import utf "core:unicode/utf8"

Lexer :: struct {
	current: int,
	previous: int,
	source: []byte,
}

TokenKind :: enum {
	Atom = 1,
	Plus, Minus, Star, Slash, Bang, Caret,

	End_Of_File = -1,
}

// Atom could be any primary expression
Atom :: distinct int

Token :: struct {
	kind: TokenKind,
	payload: Atom,
}

Expression :: union {
	Atom, UnaryExpr, BinaryExpr,
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


lexer_consume :: proc(lexer: ^Lexer) -> (rune, int) {
	if lexer.current >= len(lexer.source){
		return 0, 0
	}
	r, n := utf.decode_rune(lexer.source[lexer.current:])
	lexer.current += n
	return r, n
}

lexer_peek :: proc(lexer: ^Lexer) -> (rune, int) {
	r, n := lexer_consume(lexer)
	lexer.current -= n
	return r, n
}

tokenize :: proc(source: string) -> []Token {
	tokens := make([dynamic]Token)

	lexer := Lexer {
		source = transmute([]byte)source,
	}

	r, n := lexer_consume(&lexer)
	for n != 0 {
		defer r, n = lexer_consume(&lexer)
		switch r {
		case '+': append(&tokens, Token{ kind = .Plus })
		case '-': append(&tokens, Token{ kind = .Minus })
		case '*': append(&tokens, Token{ kind = .Star })
		case '/': append(&tokens, Token{ kind = .Slash })
		case '!': append(&tokens, Token{ kind = .Bang })
		case '^': append(&tokens, Token{ kind = .Caret })
		case ' ', '\t', '\r', '\n': continue
		case:
			if unicode.is_number(r){
				lexer.current -= n
				append(&tokens, tokenize_number(&lexer))
			}
			else {
				panic("Unknown token")
			}
		}
	}

	shrink(&tokens)
	return tokens[:]
}

tokenize_number :: proc(lexer: ^Lexer) -> Token {
	lexer.previous = lexer.current

	digits := make([dynamic]u8, context.temp_allocator)

	for {
		r, n := lexer_consume(lexer)
		if unicode.is_number(r) {
			append_encoded(&digits, r)
		}
		else if r == '_' {
			continue
		}
		else {
			lexer.current -= n
			break
		}
	}

	lexeme := string(digits[:])
	val, ok := strconv.parse_int(lexeme)
	assert(ok, "Faild to parse integer")

	return Token {
		kind = .Atom,
		payload = Atom(val),
	}
}

append_encoded :: proc(buf: ^[dynamic]byte, r: rune){
	bytes, n := utf.encode_rune(r)
	append(buf, ..bytes[:n])
}
