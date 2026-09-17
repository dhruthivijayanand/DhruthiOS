.text
.global exception_ud_entry
.type exception_ud_entry, @function
exception_ud_entry:
    cld
    # #UD pushes no error code: saved RIP is at the current stack top.
    movq (%rsp), %rdi
    # System V: RSP must be 16-byte aligned immediately before CALL.
    andq $-16, %rsp
    call exception_panic_ud
    jmp .Lfatal_stop
.size exception_ud_entry, .-exception_ud_entry

.global exception_unhandled_entry
.type exception_unhandled_entry, @function
exception_unhandled_entry:
    cld
    # Generic fatal path ignores the frame, with or without a CPU error code.
    andq $-16, %rsp
    call exception_panic_unhandled
.Lfatal_stop:
    cli
    hlt
    jmp .Lfatal_stop
.size exception_unhandled_entry, .-exception_unhandled_entry

.global exception_test_ud
.type exception_test_ud, @function
exception_test_ud:
    ud2
    # If a future handler incorrectly skips the fault, C will detect return.
    ret
.size exception_test_ud, .-exception_test_ud

.section .note.GNU-stack,"",@progbits
