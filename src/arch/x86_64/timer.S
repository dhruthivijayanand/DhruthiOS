.text
.global timer_irq_entry
.type timer_irq_entry, @function
timer_irq_entry:
    # IRQ0 has no CPU error code. Preserve all 15 non-RSP integer registers.
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rbp
    pushq %rsi
    pushq %rdi
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    cld
    movq %rsp, %rbx
    andq $-16, %rsp
    call timer_on_irq
    # RBX is callee-saved by the C ABI; recover our exact saved-register stack.
    movq %rbx, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rdi
    popq %rsi
    popq %rbp
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax
    iretq
.size timer_irq_entry, .-timer_irq_entry

.section .note.GNU-stack,"",@progbits
