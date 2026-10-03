// Constants for LINUX ARM64 Syscalls and Flags
.equ SYS_OPENAT, 56         // Syscall number for openat
.equ SYS_READ, 63           // Syscall number for read
.equ SYS_CLOSE, 57          // Syscall number for close
.equ AT_FDCWD, -100         // File Descriptor for Current Working Directory
.equ O_RDONLY, 0            // Flag for Open Read-Only
.equ BUF_SIZE, 1024         // Buffer size for reading chunks from file

.section .rodata            // Read-only data section
gamelist_path:              // Label for the file path
    .asciz "/data/ProjectRaco/gamelist.txt" // Null-terminated string for target file path

.text                       // Code section
.global check_game_in_memory// Export function name globally
.type check_game_in_memory, %function // Define as a function

check_game_in_memory:       // Function Entry Point (Input: x0 = pkg pointer)
    // Prologue: Save state to stack
    stp x29, x30, [sp, -80]! // Store Frame Pointer (x29) and Link Register (x30), allocate 80 bytes
    mov x29, sp              // Update Frame Pointer to current Stack Pointer
    stp x19, x20, [sp, 16]   // Save callee-saved registers x19, x20
    stp x21, x22, [sp, 32]   // Save callee-saved registers x21, x22
    stp x23, x24, [sp, 48]   // Save callee-saved registers x23, x24
    stp x25, x26, [sp, 64]   // Save callee-saved registers x25, x26

    // Save pkg pointer
    mov x19, x0              // Backup target package pointer from x0 to x19

    // Get pkg_len (String length of package)
    mov x25, 0               // Initialize pkg_len (x25) to 0
    cbz x19, .L_ret_not_found// If pkg pointer is NULL, branch to not found
1:                           // Loop start for strlen
    ldrb w8, [x19, x25]      // Load byte from pkg pointer + offset (x25) into w8
    cbz w8, 2f               // If byte is 0 (null terminator), break loop (jump to label 2 forward)
    add x25, x25, 1          // Increment pkg_len (x25) by 1
    b 1b                     // Branch backward to label 1 (continue loop)
2:                           // End of strlen loop
    // If pkg_len == 0, return false
    cbz x25, .L_ret_not_found// If pkg_len (x25) is 0, branch to not found

    // Allocate buffer on stack for reading
    sub sp, sp, BUF_SIZE     // Subtract BUF_SIZE (1024) from Stack Pointer to allocate buffer

    // System call: openat(AT_FDCWD, path, O_RDONLY)
    mov x0, AT_FDCWD         // Arg 1: Use Current Working Directory
    adrp x1, gamelist_path   // Arg 2: Get page address of file path string
    add x1, x1, :lo12:gamelist_path // Add page offset to complete the address pointer
    mov x2, O_RDONLY         // Arg 3: Open in Read-Only mode
    mov x3, 0                // Arg 4: No mode flags required
    mov x8, SYS_OPENAT       // Load Syscall number for OPENAT
    svc 0                    // Trigger kernel system call

    cmp x0, 0                // Compare returned File Descriptor (x0) with 0
    blt .L_cleanup_stack_not_found // If less than 0 (error), jump to cleanup and return not found
    mov x20, x0              // Backup File Descriptor to x20

    // Initialize State Machine
    mov x23, 0               // Initialize pkg_idx (x23) to 0 (Matched character count)
    mov w24, 1               // Initialize is_matching (w24) to 1 (True: Currently matching line)

.L_loop_read:                // Start of file reading loop
    mov x0, x20              // Arg 1: File Descriptor
    mov x1, sp               // Arg 2: Pointer to stack buffer
    mov x2, BUF_SIZE         // Arg 3: Bytes to read (1024)
    mov x8, SYS_READ         // Load Syscall number for READ
    svc 0                    // Trigger kernel system call

    cmp x0, 0                // Compare bytes read (x0) with 0
    ble .L_eof               // If less than or equal to 0 (EOF or error), jump to EOF handler

    mov x21, x0              // Backup bytes_read to x21
    mov x22, 0               // Initialize buffer index (x22) to 0

.L_buffer_loop:              // Start of buffer processing loop
    cmp x22, x21             // Compare buffer index (x22) with bytes_read (x21)
    b.ge .L_loop_read        // If index >= bytes_read, buffer is exhausted, read next chunk

    ldrb w8, [sp, x22]       // Load character from buffer[index] into w8
    add x22, x22, 1          // Increment buffer index by 1

    cmp w8, 10               // Compare character with 10 ('\n' newline)
    b.eq .L_newline          // If equal, branch to newline handler
    cmp w8, 13               // Compare character with 13 ('\r' carriage return)
    b.eq .L_newline          // If equal, branch to newline handler

    // Normal character processing
    cbz w24, .L_buffer_loop  // If is_matching (w24) is 0, skip checking and loop to next char

    // Check if we matched more characters than pkg length
    cmp x23, x25             // Compare pkg_idx (x23) with pkg_len (x25)
    b.ge .L_mismatch         // If pkg_idx >= pkg_len, this line is too long, branch to mismatch

    // Compare buffer character with package character
    ldrb w9, [x19, x23]      // Load character from pkg[pkg_idx] into w9
    cmp w8, w9               // Compare buffer char (w8) with pkg char (w9)
    b.ne .L_mismatch         // If not equal, branch to mismatch

    // Characters match
    add x23, x23, 1          // Increment pkg_idx by 1
    b .L_buffer_loop         // Branch back to process next character

.L_mismatch:                 // Mismatch handler
    mov w24, 0               // Set is_matching (w24) to 0 (False)
    b .L_buffer_loop         // Branch back to process remaining characters in the line

.L_newline:                  // Newline handler (End of current line)
    cbz w24, .L_reset_line   // If is_matching is 0, line failed already, jump to reset state
    cmp x23, x25             // Compare pkg_idx with pkg_len
    b.eq .L_found_close      // If they are exactly equal, WE FOUND IT! Jump to success exit

.L_reset_line:               // Reset state for the next line
    mov x23, 0               // Reset pkg_idx to 0
    mov w24, 1               // Reset is_matching to 1 (True)
    b .L_buffer_loop         // Branch back to process next character in buffer

.L_eof:                      // End Of File handler
    cbz w24, .L_not_found_close // If last line was not matching, jump to fail close
    cmp x23, x25             // Check if pkg_idx equals pkg_len (for files without trailing newline)
    b.eq .L_found_close      // If they are equal, WE FOUND IT! Jump to success exit

.L_not_found_close:          // Cleanup when package is not found
    mov x0, x20              // Arg 1: File Descriptor
    mov x8, SYS_CLOSE        // Load Syscall number for CLOSE
    svc 0                    // Trigger kernel system call
    b .L_cleanup_stack_not_found // Branch to stack cleanup for failure

.L_found_close:              // Cleanup when package IS found
    mov x0, x20              // Arg 1: File Descriptor
    mov x8, SYS_CLOSE        // Load Syscall number for CLOSE
    svc 0                    // Trigger kernel system call
    b .L_cleanup_stack_found // Branch to stack cleanup for success

.L_cleanup_stack_not_found:  // Stack cleanup for failure
    add sp, sp, BUF_SIZE     // Deallocate buffer from stack
.L_ret_not_found:            // Return point for failure
    mov x0, 0                // Set return value (x0) to 0 (False)
    b .L_epilogue            // Branch to function epilogue

.L_cleanup_stack_found:      // Stack cleanup for success
    add sp, sp, BUF_SIZE     // Deallocate buffer from stack
    mov x0, 1                // Set return value (x0) to 1 (True)

.L_epilogue:                 // Function Epilogue: Restore state and return
    ldp x19, x20, [sp, 16]   // Restore callee-saved registers x19, x20
    ldp x21, x22, [sp, 32]   // Restore callee-saved registers x21, x22
    ldp x23, x24, [sp, 48]   // Restore callee-saved registers x23, x24
    ldp x25, x26, [sp, 64]   // Restore callee-saved registers x25, x26
    ldp x29, x30, [sp], 80   // Restore Frame Pointer and Link Register, deallocate 80 bytes
    ret                      // Return to caller
