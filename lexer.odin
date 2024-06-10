package pratt_parser

import "core:fmt"
import "core:strconv"
import "core:unicode"
import str "core:strings"
import utf "core:unicode/utf8"

Number :: distinct int

Identifier :: distinct string

Token :: struct {
	kind: TokenKind,
	payload: Primary,
}

Lexer :: struct {
	current: int,
	previous: int,
	source: []byte,
}

TokenKind :: enum {
	Number = 1,
	Identifier,
	Plus, Minus, Star, Slash, Bang, Caret,
	ParenOpen, ParenClose,
	SquareOpen, SquareClose,

	End_Of_File = -1,
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
		case '(': append(&tokens, Token{ kind = .ParenOpen })
		case ')': append(&tokens, Token{ kind = .ParenClose })
		case '[': append(&tokens, Token{ kind = .SquareOpen })
		case ']': append(&tokens, Token{ kind = .SquareClose })
		case ' ', '\t', '\r', '\n': continue
		case:
			if unicode.is_number(r){
				lexer.current -= n
				append(&tokens, tokenize_number(&lexer))
			}
			else if is_identifier(r, true){
				lexer.current -= n
				append(&tokens, tokenize_identifier(&lexer))
			}
			else {
				panic("Unknown token")
			}
		}
	}

	shrink(&tokens)
	return tokens[:]
}

tokenize_identifier :: proc(lexer: ^Lexer) -> Token {
	lexer.previous = lexer.current

	for {
		r, n := lexer_consume(lexer)
		if !is_identifier(r){
			lexer.current -= n
			break
		}
	}

	lexeme := string(lexer.source[lexer.previous:lexer.current])

	return Token {
		kind = .Identifier,
		payload = Identifier(lexeme),
	}
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
		kind = .Number,
		payload = Number(val),
	}
}

@private
append_encoded :: proc(buf: ^[dynamic]byte, r: rune){
	bytes, n := utf.encode_rune(r)
	append(buf, ..bytes[:n])
}

@private
is_identifier :: proc(c: rune, start := false) -> bool {
	is_digit := !start && unicode.is_number(c)
	is_alpha := unicode.is_alpha(c)
	return is_digit || is_alpha || c == '_'
}
