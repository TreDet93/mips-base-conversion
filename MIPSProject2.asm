.data
    # Menu and prompts
    menu:           .asciiz "\n=== Base Conversion Program ===\n1. Convert base-10 to base 2-10\n2. Convert base-16 to base-10\n3. Exit\nEnter choice (1-3): "
    base_prompt:    .asciiz "Enter base (2-10): "
    number_prompt:  .asciiz "Enter base-10 integer: "
    hex_prompt:     .asciiz "Enter hexadecimal string (without 0x): "
    result_msg:     .asciiz "Result: "
    invalid_msg:    .asciiz "Invalid input! Please try again.\n"
    goodbye_msg:    .asciiz "Goodbye!\n"
    newline:        .asciiz "\n"
    
    # Buffers
    hex_buffer:     .space 32       # Buffer for hex string input
    result_buffer:  .space 32       # Buffer for result string
    
.text
.globl main

main:
    # Display menu and get user choice
menu_loop:
    li $v0, 4                       # Print string
    la $a0, menu
    syscall
    
    li $v0, 5                       # Read integer
    syscall
    move $t0, $v0                   # Store choice in $t0
    
    # Check choice
    beq $t0, 1, base10_to_base      # Choice 1: base-10 to base 2-10
    beq $t0, 2, hex_to_base10       # Choice 2: hex to base-10
    beq $t0, 3, exit_program        # Choice 3: exit
    
    # Invalid choice
    li $v0, 4
    la $a0, invalid_msg
    syscall
    j menu_loop

base10_to_base:
    # Get base (2-10)
    li $v0, 4
    la $a0, base_prompt
    syscall
    
    li $v0, 5
    syscall
    move $t1, $v0                   # Store base in $t1
    
    # Validate base (2-10)
    blt $t1, 2, invalid_base
    bgt $t1, 10, invalid_base
    
    # Get number to convert
    li $v0, 4
    la $a0, number_prompt
    syscall
    
    li $v0, 5
    syscall
    move $t2, $v0                   # Store number in $t2
    
    # Convert number to specified base
    move $a0, $t2                   # Number to convert
    move $a1, $t1                   # Target base
    jal convert_to_base
    
    # Print result
    li $v0, 4
    la $a0, result_msg
    syscall
    
    li $v0, 4
    la $a0, result_buffer
    syscall
    
    li $v0, 4
    la $a0, newline
    syscall
    
    j menu_loop

invalid_base:
    li $v0, 4
    la $a0, invalid_msg
    syscall
    j menu_loop

hex_to_base10:
    # Get hex string
    li $v0, 4
    la $a0, hex_prompt
    syscall
    
    li $v0, 8                       # Read string
    la $a0, hex_buffer
    li $a1, 32
    syscall
    
    # Remove newline from input
    la $t0, hex_buffer
remove_newline:
    lb $t1, 0($t0)
    beq $t1, 10, found_newline      # ASCII 10 is newline
    beq $t1, 0, convert_hex         # End of string
    addi $t0, $t0, 1
    j remove_newline
found_newline:
    sb $zero, 0($t0)                # Replace newline with null terminator

convert_hex:
    # Convert hex string to base-10
    la $a0, hex_buffer
    jal hex_string_to_int
    move $t2, $v0                   # Store result in $t2
    
    # Check if conversion was successful (result >= 0)
    bltz $t2, invalid_hex
    
    # Print result
    li $v0, 4
    la $a0, result_msg
    syscall
    
    li $v0, 1                       # Print integer
    move $a0, $t2
    syscall
    
    li $v0, 4
    la $a0, newline
    syscall
    
    j menu_loop

invalid_hex:
    li $v0, 4
    la $a0, invalid_msg
    syscall
    j menu_loop

exit_program:
    li $v0, 4
    la $a0, goodbye_msg
    syscall
    
    li $v0, 10                      # Exit
    syscall

# Function: convert_to_base
# Converts a decimal number to specified base (2-10)
# Arguments: $a0 = number, $a1 = base
# Uses result_buffer to store the result string
convert_to_base:
    # Save registers
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)
    
    move $s0, $a0                   # Number to convert
    move $s1, $a1                   # Base
    la $s2, result_buffer           # Result buffer
    
    # Handle special case: number is 0
    bnez $s0, not_zero
    li $t0, 48                      # ASCII '0'
    sb $t0, 0($s2)
    sb $zero, 1($s2)                # Null terminator
    j convert_done
    
not_zero:
    # Handle negative numbers
    move $t3, $s0                   # Copy number
    li $t4, 0                       # Negative flag
    bgez $t3, positive
    neg $t3, $t3                    # Make positive
    li $t4, 1                       # Set negative flag
    
positive:
    # Convert digits (stored in reverse order initially)
    addi $t0, $s2, 31               # Start at end of buffer
    sb $zero, 0($t0)                # Null terminator
    addi $t0, $t0, -1
    
convert_loop:
    div $t3, $s1                    # Divide by base
    mfhi $t1                        # Get remainder (digit)
    mflo $t3                        # Get quotient
    
    # Convert digit to ASCII
    addi $t1, $t1, 48               # Add ASCII '0'
    sb $t1, 0($t0)                  # Store digit
    addi $t0, $t0, -1               # Move to previous position
    
    bnez $t3, convert_loop          # Continue if quotient != 0
    
    # Add negative sign if needed
    beqz $t4, no_negative
    li $t1, 45                      # ASCII '-'
    sb $t1, 0($t0)
    addi $t0, $t0, -1
    
no_negative:
    # Copy reversed string to beginning of buffer
    addi $t0, $t0, 1                # Point to first character
    move $t1, $s2                   # Destination
    
copy_loop:
    lb $t2, 0($t0)                  # Load character
    sb $t2, 0($t1)                  # Store character
    beqz $t2, convert_done          # Stop at null terminator
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j copy_loop
    
convert_done:
    # Restore registers
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# Function: hex_string_to_int
# Converts a hexadecimal string to integer
# Arguments: $a0 = address of hex string
# Returns: $v0 = integer value (-1 if invalid)
hex_string_to_int:
    # Save registers
    addi $sp, $sp, -12
    sw $ra, 8($sp)
    sw $s0, 4($sp)
    sw $s1, 0($sp)
    
    move $s0, $a0                   # String address
    li $s1, 0                       # Result accumulator
    
hex_loop:
    lb $t0, 0($s0)                  # Load character
    beqz $t0, hex_success           # End of string
    
    # Check if character is valid hex digit
    li $t1, -1                      # Invalid digit value
    
    # Check 0-9
    blt $t0, 48, hex_invalid        # Less than '0'
    ble $t0, 57, hex_digit          # Between '0' and '9'
    
    # Check A-F
    blt $t0, 65, hex_invalid        # Less than 'A'
    ble $t0, 70, hex_upper          # Between 'A' and 'F'
    
    # Check a-f
    blt $t0, 97, hex_invalid        # Less than 'a'
    bgt $t0, 102, hex_invalid       # Greater than 'f'
    
    # Convert a-f to digit value
    subi $t1, $t0, 87               # 'a' = 97, so 97-87 = 10
    j hex_add_digit
    
hex_upper:
    # Convert A-F to digit value
    subi $t1, $t0, 55               # 'A' = 65, so 65-55 = 10
    j hex_add_digit
    
hex_digit:
    # Convert 0-9 to digit value
    subi $t1, $t0, 48               # '0' = 48
    
hex_add_digit:
    # Multiply current result by 16 and add new digit
    sll $s1, $s1, 4                # Multiply by 16 (shift left 4)
    add $s1, $s1, $t1               # Add new digit
    
    addi $s0, $s0, 1                # Next character
    j hex_loop
    
hex_invalid:
    li $s1, -1                      # Return -1 for invalid
    
hex_success:
    move $v0, $s1                   # Return result
    
    # Restore registers
    lw $s1, 0($sp)
    lw $s0, 4($sp)
    lw $ra, 8($sp)
    addi $sp, $sp, 12
    jr $ra