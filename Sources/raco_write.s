/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
This program is free software: you can redistribute it and/or modify it under the terms of 
the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. 

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
See the GNU General Public License for more details. 
You should have received a copy of the GNU General Public License along with this program. 

If not, see https://www.gnu.org/licenses/.
 */

.arch armv8-a
.text
.align 2
.global tweak
.global kakangku
.global moco
.extern chmod
.extern open
.extern write
.extern read
.extern close
.extern strlen

// void tweak(const char *value, const char *path)
// x0 = value, x1 = path
tweak:
    // Prologue: save frame pointer, link register, and arguments
    stp x29, x30, [sp, -48]!
    mov x29, sp
    str x0, [sp, 16] // save value
    str x1, [sp, 24] // save path

    // chmod 644 (0644 octal is 420 decimal)
    mov x0, x1
    mov x1, 420
    bl chmod

    // open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644)
    // O_WRONLY=1, O_CREAT=64, O_TRUNC=512 -> 577
    ldr x0, [sp, 24]
    mov x1, 577
    mov x2, 420
    bl open
    cmp w0, 0
    blt .Ltweak_end      // Exit if open fails
    str w0, [sp, 36]     // save file descriptor

    // strlen(value)
    ldr x0, [sp, 16]
    bl strlen
    mov x2, x0           // length for write

    // write(fd, value, len)
    ldr w0, [sp, 36]
    ldr x1, [sp, 16]
    bl write

    // close(fd)
    ldr w0, [sp, 36]
    bl close

    // chmod 444 (0444 octal is 292 decimal)
    ldr x0, [sp, 24]
    mov x1, 292
    bl chmod

.Ltweak_end:
    // Epilogue
    ldp x29, x30, [sp], 48
    ret

// void kakangku(const char *value, const char *path)
// x0 = value, x1 = path
kakangku:
    // Prologue
    stp x29, x30, [sp, -48]!
    mov x29, sp
    str x0, [sp, 16]
    str x1, [sp, 24]

    // chmod 644 (0644 octal is 420 decimal)
    mov x0, x1
    mov x1, 420
    bl chmod

    // open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644)
    ldr x0, [sp, 24]
    mov x1, 577
    mov x2, 420
    bl open
    cmp w0, 0
    blt .Lkakangku_end
    str w0, [sp, 36]

    // strlen(value)
    ldr x0, [sp, 16]
    bl strlen
    mov x2, x0

    // write(fd, value, len)
    ldr w0, [sp, 36]
    ldr x1, [sp, 16]
    bl write

    // close(fd)
    ldr w0, [sp, 36]
    bl close

.Lkakangku_end:
    // Epilogue
    ldp x29, x30, [sp], 48
    ret

// int moco(const char *path, char *buffer, int size)
// x0 = path, x1 = buffer, x2 = size
moco:
    // Prologue
    stp x29, x30, [sp, -48]!
    mov x29, sp
    str x0, [sp, 16] // save path
    str x1, [sp, 24] // save buffer
    str x2, [sp, 32] // save size

    // open(path, O_RDONLY)
    // O_RDONLY is 0
    ldr x0, [sp, 16]
    mov x1, 0
    bl open
    cmp w0, 0
    blt .Lmoco_fail      // Exit if open fails
    str w0, [sp, 36]     // save file descriptor

    // read(fd, buffer, size - 1)
    ldr w0, [sp, 36]
    ldr x1, [sp, 24]
    ldr x2, [sp, 32]
    sub x2, x2, 1        // Reserve 1 byte for null terminator
    bl read
    cmp x0, 0
    blt .Lmoco_close

    // Null-terminate the buffer: buffer[bytes_read] = '\0'
    ldr x1, [sp, 24]
    strb wzr, [x1, x0]

.Lmoco_close:
    // save bytes read count across close
    str x0, [sp, 40]

    // close(fd)
    ldr w0, [sp, 36]
    bl close

    // return bytes read
    ldr x0, [sp, 40]
    b .Lmoco_end

.Lmoco_fail:
    mov x0, -1

.Lmoco_end:
    // Epilogue
    ldp x29, x30, [sp], 48
    ret