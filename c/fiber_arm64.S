.text
.align 2
.globl _fiber_switch
_fiber_switch:
	mov	x2, sp
	stp	x19, x20, [x0, #8]
	stp	x21, x22, [x0, #24]
	stp	x23, x24, [x0, #40]
	stp	x25, x26, [x0, #56]
	stp	x27, x28, [x0, #72]
	stp	x29, x30, [x0, #88]
	str	x2, [x0]

	ldr	x2, [x1]
	ldp	x19, x20, [x1, #8]
	ldp	x21, x22, [x1, #24]
	ldp	x23, x24, [x1, #40]
	ldp	x25, x26, [x1, #56]
	ldp	x27, x28, [x1, #72]
	ldp	x29, x30, [x1, #88]
	mov	sp, x2
	ret
