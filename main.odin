package pratt_parser

import "core:fmt"
import "core:strings"
import "core:mem"

SOURCE :: "arr[1]! + 4 / 4!"

COMPILER_MEMORY_POOL : [16 * mem.Megabyte]byte

main :: proc(){
	arena : mem.Arena
	mem.arena_init(&arena, COMPILER_MEMORY_POOL[:])
	context.allocator = mem.arena_allocator(&arena)
	defer free_all(context.allocator)

	tokens := tokenize(SOURCE)
	ast := parse(tokens)
	fmt.println(tokens)
	fmt.println(to_sexpression(ast))
}

to_sexpression :: proc(expr: ^Expression, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	sexpr_rec(&sb, expr)
	shrink(&sb.buf)
	return string(sb.buf[:])
}

@private
sexpr_rec :: proc(sb: ^strings.Builder, expr: ^Expression){
	op_map := OPERATOR_MAP
	if expr == nil {
		return
	}
	switch expr in expr {
	case BinaryExpr:
		fmt.sbprintf(sb, "(%v ", op_map[expr.operator])
		sexpr_rec(sb, expr.left)
		fmt.sbprint(sb, " ")
		sexpr_rec(sb, expr.right)
		fmt.sbprint(sb, ")")
	case IndexExpr:
		fmt.sbprint(sb, "([] ")
		sexpr_rec(sb, expr.object)
		fmt.sbprint(sb, " ")
		sexpr_rec(sb, expr.index)
		fmt.sbprint(sb, ")")
	case UnaryExpr:
		fmt.sbprintf(sb, "(%v ", op_map[expr.operator])
		sexpr_rec(sb, expr.operand)
		fmt.sbprint(sb, ")")
	case Primary:
		fmt.sbprint(sb, expr)
	}
}

@private
OPERATOR_MAP :: #partial #sparse [TokenKind]string{
	.Plus = "+",
	.Minus = "-",
	.Star = "*",
	.Slash = "/",
	.Caret = "^",
	.Bang = "!",
}
