.text
.global timer_wait_probe
.type timer_wait_probe, @function
timer_wait_probe:
    # Preserve our own caller's callee-saved registers before planting sentinels.
    pushq %rbx
    pushq %rbp
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    movq $0x11, %rax
    movq $0x22, %rbx
    movq $0x33, %rcx
    movq $0x44, %rdx
    movq $0x55, %rbp
    movq $0x66, %rsi
    movq $0x77, %rdi
    movq $0x88, %r8
    movq $0x99, %r9
    movq $0xaa, %r10
    movq $0xbb, %r11
    movq $0xcc, %r12
    movq $0xdd, %r13
    movq $0xee, %r14
    movq $0xff, %r15
    # C must see DF clear, but IRETQ must restore our DF and CF after the IRQ.
    std
    stc
    sti
    hlt
    cli
    pushfq
    testq $0x400, (%rsp)
    jz .Lflags_failed
    testq $1, (%rsp)
    jz .Lflags_failed
    addq $8, %rsp
    cld
    cmpq $0x11, %rax
    jne .Lprobe_failed
    cmpq $0x22, %rbx
    jne .Lprobe_failed
    cmpq $0x33, %rcx
    jne .Lprobe_failed
    cmpq $0x44, %rdx
    jne .Lprobe_failed
    cmpq $0x55, %rbp
    jne .Lprobe_failed
    cmpq $0x66, %rsi
    jne .Lprobe_failed
    cmpq $0x77, %rdi
    jne .Lprobe_failed
    cmpq $0x88, %r8
    jne .Lprobe_failed
    cmpq $0x99, %r9
    jne .Lprobe_failed
    cmpq $0xaa, %r10
    jne .Lprobe_failed
    cmpq $0xbb, %r11
    jne .Lprobe_failed
    cmpq $0xcc, %r12
    jne .Lprobe_failed
    cmpq $0xdd, %r13
    jne .Lprobe_failed
    cmpq $0xee, %r14
    jne .Lprobe_failed
    cmpq $0xff, %r15
    jne .Lprobe_failed
    movl $1, %eax
    jmp .Lprobe_return
.Lflags_failed:
    addq $8, %rsp
    cld
.Lprobe_failed:
    xorl %eax, %eax
.Lprobe_return:
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbp
    popq %rbx
    ret
.size timer_wait_probe, .-timer_wait_probe
.section .note.GNU-stack,"",@progbits
