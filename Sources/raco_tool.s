/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
 */

// Define for global for later use
.global raco_write
.global raco_kakikomi
.global raco_read

// Constants for LINUX ARM64
.equ SYS_FACCESSAT, 48 // Function of check file accessibility
.equ SYS_FCHMODAT,  53 // Function of Change file permission
.equ SYS_OPENAT,    56 // Function of open file
.equ SYS_CLOSE,     57 // Function of close file
.equ SYS_READ,      63 // Function of read file 
.equ SYS_WRITE,     64 // Function of write file 

.equ AT_FDCWD,      -100 // FD is Current Working Dir
.equ F_OK,          0    // Flag check exist
.equ O_RDONLY,      0    // Open Read-Only
.equ O_WRONLY,      1    // Open Write-Only

.equ PERM_644,      420  // Permission of 644 for chmod
.equ PERM_444,      292  // Permission of 444 for chmod

/*
Function of raco_write. 
This will do:
1. Check exists -> 2. chmod 644 -> 3. Write -> 4. chmod 444
*/
raco_write:
    stp x29, x30, [sp, #-48]! // Store pointer of 48 byte, Store pointer x29 and Link Register x30
    stp x19, x20, [sp, #16]   // Store the registered x19 and x20 with offset of 16
    stp x21, x22, [sp, #32]   // Store the registered x21 and x22 with offset of 32
    mov x29, sp               // Update Frame Pointer to current Stack 

    // Save for arguments so it's survive the syscall 
    mov x19, x0 // Backup path from x0 to x19
    mov x20, x1 // Backup val from x1 to x20
    mov x21, x2 // Backup integer from x2 to x21

    // Check if file exist 
    mov x0, #AT_FDCWD         // Use work directory
    mov x1, x19               // Point pointer to file path
    mov x2, #F_OK             // Check if File is exist
    mov x3, #0                // No Flag 
    mov x8, #SYS_FACCESSAT    // Load Syscall for Faccessat
    svc #0                    // Trigger kernel system call
    cbnz x0, .L_write_fail    // Compare and branch non zero. IF x0 != 0, jump to fail 

    // Chmod 644 via fchmodat
    mov x0, #AT_FDCWD         // Directory of FD
    mov x1, x19               // Pointer to file path
    mov x2, #PERM_644         // Change to perm 644
    mov x3, #0                // No flags
    mov x8, #SYS_FCHMODAT     // Load Syscall for FCHMODAT
    svc #0                    // Trigger Kernel System Call

    // Open file
    mov x0, #AT_FDCWD         // Directory of FD
    mov x1, x19               // Pointer of File Path
    mov x2, #O_WRONLY         // Open in Write Only
    mov x3, #0                // File create. Ignored
    mov x8, #SYS_OPENAT       // Load SYSCALL for OPENAT
    svc #0                    // Trigger kernel syscall 
    cmp x0, #0                // Compare FD with 0
    blt .L_write_fail         // Compare and branch less than. IF x0 < 0, jump to fail
    mov x22, x0               // Backup FD Open to x22

    // Write file
    // Since x0 already contain valid FD
    mov x1, x20               // Pointer to string Val
    mov x2, x21               // Length of String
    mov x8, #SYS_WRITE        // Load SYSCALL for write
    svc #0                    // Trigger syscall

    // Close File
    mov x0, x22               // File descriptor x22 into x0
    mov x8, #SYS_CLOSE        // Load syscall for close into x8
    svc #0                    // Trigger Syscall

    // Chmod 444 via fchmodat
    mov x0, #AT_FDCWD         // Directory of FD
    mov x1, x19               // Pointer to file path
    mov x2, #PERM_444         // Change to perm 444
    mov x3, #0                // No flags
    mov x8, #SYS_FCHMODAT     // Load Syscall for FCHMODAT
    svc #0                    // Trigger Kernel System Call

    // Exit OK
    mov x0, #0                // Set return as 0
    b .L_write_exit           // Unconditional branch to exit block

.L_write_fail:
    mov x0, #-1               // Exit as -1

.L_write_exit:
    // Restore stack
    ldp x21, x22, [sp, #32]   // Load Pair: Restore x21 and x22
    ldp x19, x20, [sp, #16]   // Load Pair: Restore x19 and x20
    ldp x29, x30, [sp], #48   // Load Pair: Restore Frame Pointer and Link Register with byte of 48
    ret                       // Return

/*
Function of raco_kakikomi. 
This will do:
1. Check exists -> 2. chmod 644 -> 3. Write
*/
raco_kakikomi:
    stp x29, x30, [sp, #-48]! // Store pointer of 48 byte, Store pointer x29 and Link Register x30
    stp x19, x20, [sp, #16]   // Store the registered x19 and x20 with offset of 16
    stp x21, x22, [sp, #32]   // Store the registered x21 and x22 with offset of 32
    mov x29, sp               // Update Frame Pointer to current Stack 

    // Save for arguments so it's survive the syscall 
    mov x19, x0 // Backup path from x0 to x19
    mov x20, x1 // Backup val from x1 to x20
    mov x21, x2 // Backup integer from x2 to x21

    // Check if file exist 
    mov x0, #AT_FDCWD         // Use work directory
    mov x1, x19               // Point pointer to file path
    mov x2, #F_OK             // Check if File is exist
    mov x3, #0                // No Flag 
    mov x8, #SYS_FACCESSAT    // Load Syscall for Faccessat
    svc #0                    // Trigger kernel system call
    cbnz x0, .L_kaki_fail     // Compare and branch non zero. IF x0 != 0, jump to fail 

    // Chmod 644 via fchmodat
    mov x0, #AT_FDCWD         // Directory of FD
    mov x1, x19               // Pointer to file path
    mov x2, #PERM_644         // Change to perm 644
    mov x3, #0                // No flags
    mov x8, #SYS_FCHMODAT     // Load Syscall for FCHMODAT
    svc #0                    // Trigger Kernel System Call

    // Open file
    mov x0, #AT_FDCWD         // Directory of FD
    mov x1, x19               // Pointer of File Path
    mov x2, #O_WRONLY         // Open in Write Only
    mov x3, #0                // File create. Ignored
    mov x8, #SYS_OPENAT       // Load SYSCALL for OPENAT
    svc #0                    // Trigger kernel syscall 
    cmp x0, #0                // Compare FD with 0
    blt .L_kaki_fail          // Compare and branch less than. IF x0 < 0, jump to fail
    mov x22, x0               // Backup FD Open to x22

    // Write file
    // Since x0 already contain valid FD
    mov x1, x20               // Pointer to string Val
    mov x2, x21               // Length of String
    mov x8, #SYS_WRITE        // Load SYSCALL for write
    svc #0                    // Trigger syscall

    // Close File
    mov x0, x22               // File descriptor x22 into x0
    mov x8, #SYS_CLOSE        // Load syscall for close into x8
    svc #0                    // Trigger Syscall

    // Exit OK
    mov x0, #0                // Set return as 0
    b .L_kaki_exit            // Unconditional branch to exit block

.L_kaki_fail:
    mov x0, #-1               // Exit as -1

.L_kaki_exit:
    // Restore stack
    ldp x21, x22, [sp, #32]   // Load Pair: Restore x21 and x22
    ldp x19, x20, [sp, #16]   // Load Pair: Restore x19 and x20
    ldp x29, x30, [sp], #48   // Load Pair: Restore Frame Pointer and Link Register with byte of 48
    ret                       // Return

/*
Function of raco_read. 
This will do:
1. Check exists -> 2. Open Read-Only -> 3. Read into C Buffer -> 4. Close
*/
raco_read:
    stp x29, x30, [sp, #-48]! // Store pointer of 48
    stp x19, x20, [sp, #16]   // Store the registered x19 and x20 with offset of 16
    stp x21, x22 [sp, #32]    // Original value that registers x21 and x22
    mov x29, sp               // Update Frame Pointer to current Stack 

    // Backup for C integration
    mov x19, x0 // Path used
    mov x20, x1 // Pointer of C
    mov x21, x2 // Maximum size. Reference before is 32 byte

    // Check if file exist 
    mov x0, #AT_FDCWD         // Use work directory
    mov x1, x19               // Point pointer to file path
    mov x2, #F_OK             // Check if File is exist
    mov x3, #0                // No Flag 
    mov x8, #SYS_FACCESSAT    // Load Syscall for Faccessat
    svc #0                    // Trigger kernel system call
    cbnz x0, .L_read_fail     // Compare and branch non zero. IF x0 != 0, jump to fail 

    // Open file
    mov x0, #AT_FDCWD         // Directory of FD
    mov x1, x19               // Pointer of File Path
    mov x2, #O_RDONLY         // FIX: Must open in Read-Only to read!
    mov x3, #0                // File create. Ignored
    mov x8, #SYS_OPENAT       // Load SYSCALL for OPENAT
    svc #0                    // Trigger kernel syscall 
    cmp x0, #0                // Compare FD with 0
    blt .L_read_fail          // Compare and branch less than. IF x0 < 0, jump to fail
    mov x22, x0               // Backup FD Open to x22

    // File Reading
    mov x0, x22 // x22 which is FD
    mov x1, x20 // C Buffer
    mov x2, x21 // Max byte to read
    mov x8, #SYS_READ // Syscall for Read
    svc #0 // Trigger syscall

    mov x21, x0 // Backup so no lose during close file

    // File closing
    mov x0, x22 // FD Close
    mov x8, #SYS_CLOSE // syscall for close
    svc #0 // Trigger syscall

    // Return point of bytes
    mov x0, x21 // This is for return of file content
    b .L_read_exit

.L_read_fail:
    mov x0, #-1               // Return -1. Error

.L_read_exit:
    // Restore stack
    ldp x21, x22, [sp, #32] // For file content
    ldp x19, x20, [sp, #16]  // For file pointer
    ldp x29, x30, [sp], #48  // Load Pair: Restore Frame Pointer and Link Register, deallocate 48 bytes
    ret                       // Return