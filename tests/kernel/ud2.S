.text
.global exception_test_ud
.type exception_test_ud, @function
exception_test_ud:
    ud2
    # If a future handler incorrectly skips the fault, C will detect return.
    ret
.size exception_test_ud, .-exception_test_ud

.section .note.GNU-stack,"",@progbits
