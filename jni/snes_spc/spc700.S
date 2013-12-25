/* Copyright (C) 2013 Nathan Cassano. This module is free software; you
can redistribute it and/or modify it under the terms of the GNU Lesser
General Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version. This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
details. You should have received a copy of the GNU Lesser General Public
License along with this module; if not, write to the Free Software Foundation,
Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA */

.align 4

SPCAddr         .req r12

SPC_RAM         .req r3
SPC_YAPX        .req r4
SPC_S           .req r5
SPC_PC          .req r6
SPC_Cycles      .req r7

.equ Carry,       1
.equ Zero,        2
.equ Interrupt,   4
.equ HalfCarry,   8
.equ Break,      16
.equ DirectPage, 32
.equ Overflow,   64
.equ Negative,  128

.equ SPC_Register_YAPX, 0
.equ SPC_Register_YA, 2
.equ SPC_Register_X, 0
.equ SPC_Register_P, 1
.equ SPC_Register_A, 2
.equ SPC_Register_Y, 3
.equ SPC_Register_S, 4
.equ SPC_Register_PC, 6
.equ SPC_Ram, 320
.equ SPC_spc_time, 116
.equ SPC_dsp_time, 112
.equ SPC_timer0_next_time, 8
.equ SPC_timer1_next_time, 32
.equ SPC_timer2_next_time, 56
.equ SPC_smp_regs, 80
.equ SPC_smp_regs_count, 16
.equ SPC_hi_ram, 192
.equ SPC_rom, 256
.equ SPC_rom_enabled, 188
.equ SPC_timers, 8
.equ Timer_size, 24
.equ Timer_next_time, 0
.equ Timer_counter, 20
.equ Timer_enabled, 16
.equ Timer_divider, 12
.equ Timer_period, 8

.balign 4
.section .rodata

.text
.code 32

##  SNES_SPC::run_until_(int)
.global _ZN8SNES_SPC10run_until_Ei
_ZN8SNES_SPC10run_until_Ei:

    stmfd   sp!, {r4, r5, r6, r7}

    mov    SPCAddr, r0

    ## rel_time_t rel_time = m.spc_time - end_time;
    ldr    r0, [SPCAddr, #SPC_spc_time]
    sub    SPC_Cycles, r0, r1

    ## m.spc_time = end_time;
    str    r1, [SPCAddr, #SPC_spc_time]

    ## m.dsp_time += rel_time;
    ldr    r0, [SPCAddr, #SPC_dsp_time]
    add    r0, r0, SPC_Cycles
    str    r0, [SPCAddr, #SPC_dsp_time]

    ## m.timers[0].next_time += rel_time;
    ldr    r0, [SPCAddr, #SPC_timer0_next_time]
    add    r0, r0, SPC_Cycles
    str    r0, [SPCAddr, #SPC_timer0_next_time]

    ## m.timers[1].next_time += rel_time;
    ldr    r0, [SPCAddr, #SPC_timer1_next_time]
    add    r0, r0, SPC_Cycles
    str    r0, [SPCAddr, #SPC_timer1_next_time]

    ## m.timers[2].next_time += rel_time;
    ldr    r0, [SPCAddr, #SPC_timer2_next_time]
    add    r0, r0, SPC_Cycles
    str    r0, [SPCAddr, #SPC_timer2_next_time]

    ## Load spc registers
    ldm    SPCAddr, {r4, r5}

    add    SPC_RAM, SPCAddr, #SPC_Ram
    add    SPC_PC, SPC_RAM, r5, lsr #16
    and    SPC_S, r5, #0xFF

    spc_loop:

    ldrb   r1, [SPC_PC]    @ Get opcode

    adr    r2, SpcOpCodeJumpTable

    ldr    pc, [r2, r1, lsl #2]

    out_of_time:

    ## m.spc_time += rel_time;
    ldr    r0, [SPCAddr, #SPC_spc_time]
    add    r0, r0, SPC_Cycles 
    str    r0, [SPCAddr, #SPC_spc_time]

    ## m.dsp_time -= rel_time;
    ldr    r0, [SPCAddr, #SPC_dsp_time]
    sub    r0, r0, SPC_Cycles 
    str    r0, [SPCAddr, #SPC_dsp_time]

    ## m.timers [0].next_time -= rel_time;
    ldr    r0, [SPCAddr, #SPC_timer0_next_time]
    sub    r0, r0, SPC_Cycles 
    str    r0, [SPCAddr, #SPC_timer0_next_time]

    ## m.timers [1].next_time -= rel_time;
    ldr    r0, [SPCAddr, #SPC_timer1_next_time]
    sub    r0, r0, SPC_Cycles 
    str    r0, [SPCAddr, #SPC_timer1_next_time]

    ## m.timers [2].next_time -= rel_time;
    ldr    r0, [SPCAddr, #SPC_timer2_next_time]
    sub    r0, r0, SPC_Cycles 
    str    r0, [SPCAddr, #SPC_timer2_next_time]

    ## Save spc registers
    sub    SPC_PC, SPC_PC, SPC_RAM
    orr    r5, SPC_S, SPC_PC, lsl #16
    stm    SPCAddr, {r4, r5}

    ## return &(m.smp_regs [0]) [r_cpuio0];
    ldmfd   sp!, {r4, r5, r6, r7}
    add    r0, SPCAddr, #SPC_smp_regs + 4
    bx     lr

.ltorg

.macro IncrementPC count
    add    SPC_PC, SPC_PC, #\count
.endm

.macro AddCyclesCheckTime Cycles
    adds   r0, SPC_Cycles, #\Cycles - 1
    bpl    out_of_time
    add    SPC_Cycles, SPC_Cycles, #\Cycles
.endm

.macro SubCycles Cycles
    sub    SPC_Cycles, SPC_Cycles, #\Cycles
.endm

.macro CPU_WRITE
    stmfd   sp!, {pc}    @ Push the PC to the stack
    b cpu_write
.endm

.macro CPU_WRITE_DP
    stmfd   sp!, {pc}    @ Push the PC to the stack
    b cpu_write_dp
.endm

# IN : r0 - address
# DESTROYED - r0, r1
# OUT: r0 - value
.macro CPU_READ

    LOCAL CPU_READ_Return

    ## if (addr <= 0xff && addr >= 0xf0)
    mov    r1, #0xF
    cmp    r1, r0, lsr #4
        ## return (read_smp_reg(addr));
        adreq     r1, CPU_READ_Return @ Push the PC to the stack
        stmeqfd   sp!, {r1}
        beq read_smp_reg
    
        ## return (ram[addr]);
        ldrb   r0, [SPC_RAM, r0]

    CPU_READ_Return:

.endm

# IN : r0 - address
# DESTROYED - r0, r1
.macro CPU_READ_DP 

    local CPU_READ_DPDirectPage
    LOCAL CPU_READ_DPEnd

    and    r0, r0, #0xFF

    @ Test direct flag is not set
    tst    SPC_YAPX, #(DirectPage << 8)
    addne  r0, r0, #0x100
    bne    CPU_READ_DPDirectPage

    ## if (addr >= 0xf0 && (P & DirectPage ) == 0 )
    cmp    r0, #0xf0
        ## return read_smp_reg(addr)
        adrhs     r1, CPU_READ_DPEnd
        stmhsfd   sp!, {r1}
        bhs       read_smp_reg
    ## else

        ## return Iram[addr]

    CPU_READ_DPDirectPage:

        ldrb   r0, [SPC_RAM, r0]

    CPU_READ_DPEnd:

.endm

.macro IndexedXIndirect

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    mov    r2, SPC_RAM
    tst    SPC_YAPX, #(DirectPage << 8)
    addne  r2, r2, #0x100
    ldrb   r1, [r2, r0]

    add    r0, r0, #1
    and    r0, r0, #0xFF

    ldrb   r0, [r2, r0]

    orr    r0, r1, r0, lsl #8

.endm

.macro IndirectIndexedY

    ldrb   r0, [SPC_PC, #1]

    mov    r1, SPC_RAM
    tst    SPC_YAPX, #(DirectPage << 8)
    addne  r1, r1, #0x100
 
    add    r0, r0, r1
    ldrb   r1, [r0]

    ldrb   r0, [r0, #1]
    orr    r0, r1, r0, lsl #8

    mov    r1, SPC_YAPX, lsr #24
    add    r0, r0, r1
    bic    r0, r0, #0xFF0000

.endm

.macro Absolute

    ldrb   r0, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r0, r0, r1, lsl #8

.endm

# OUT r0 - addr
.macro AbsoluteX

    ldrb   r0, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r0, r0, r1, lsl #8
    and    r1, SPC_YAPX, #0xFF
    add    r0, r0, r1
    bic    r0, r0, #0xFF0000

.endm

.macro AbsoluteY

    ldrb   r0, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r0, r0, r1, lsl #8
    mov    r1, SPC_YAPX, lsr #24
    add    r0, r0, r1
    bic    r0, #0xFF0000

.endm

.macro TCALL Count

    sub     r0, SPC_PC, SPC_RAM      @ Ipc - Iram + 1
    add     r0, r0, #1

    add     r1, SPC_RAM, SPC_S
    strb    r0, [r1, #0xFF]     @ *(ram + 0x100 + S--) = (w);
    mov     r0, r0, lsr #8      @ *(ram + 0x100 + S--) = ((w) >> 8);
    strb    r0, [r1, #0x100]

    sub     SPC_S, SPC_S, #2
    and     SPC_S, SPC_S, #0xFF

    mov     r0, #(((15 - \Count) << 1) + 0xc0)
    orr     r0, r0, #0xFF00
    ldrb    r2, [SPC_RAM, r0]
    add     r0, r0, #1
    ldrb    r0, [SPC_RAM, r0]
    add     r2, r2, r0, lsl #8
    add     SPC_PC, SPC_RAM, r2

.endm

.macro SET bit

    ldrb   r2, [SPC_PC, #1]    @ *(pc + 1)

    mov   r0, r2
    CPU_READ_DP
    orr    r1, r0, #(1 << (\bit))

    mov    r0, r2

    CPU_WRITE_DP

    # pc += 2
    add    SPC_PC, SPC_PC, #2

    b    spc_loop

.endm

.macro CLR bit


    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2
    CPU_READ_DP
    bic    r1, r0, #(1 << \bit)

    mov    r0, r2

    CPU_WRITE_DP

    add    SPC_PC, SPC_PC, #2

.endm

.macro BBS bit

    LOCAL BitNotSet

    AddCyclesCheckTime 7

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP
    tst    r0, #(1 << (\bit))
    beq    BitNotSet

        ldrsb  r0, [SPC_PC, #2]
        add    SPC_PC, SPC_PC, r0
        add    SPC_PC, SPC_PC, #3

        b    spc_loop

    BitNotSet:
        add    SPC_PC, SPC_PC, #3

        SubCycles 2

        b    spc_loop

.endm

.macro BBC bit

    LOCAL BitNoSet

    AddCyclesCheckTime 7

    ldrb   r0, [SPC_PC, #1]

    CPU_READ_DP
    tst    r0, #(1 << (\bit))
    beq    BitNoSet

        add  SPC_PC, SPC_PC, #3

        SubCycles 2

        b    spc_loop

    BitNoSet:

        ldrsb   r0, [SPC_PC, #2]
        add     SPC_PC, SPC_PC, #3
        add     SPC_PC, SPC_PC, r0

        b    spc_loop

.endm

# OUT r0 - address, r1 - bit
.macro MemBit

    ldrb   r0, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r0, r0, r1, lsl #8
    ## uint8 Bit = (int8) (addr >> 13);
    mov    r1, r0, lsr #13
    ## addr &= 0x1fff;
    bic    r0, r0, #0xE000

.endm

# IN - r0, r1
.macro SBC

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too

    mov    r1, SPC_YAPX, lsl #8
    and    r1, r1, #0xFF000000

    sbcs   r1, r1, r0, lsl #24

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    eor    r0, r0, SPC_YAPX, lsr #16
    eor    r0, r0, r1, lsr #24
    tst    r0, #0x10
    orreq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    ands   r1, r1, #0xFF000000    @ Clear lower 24 bits away

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000    @ Put Register A back into YAPX
    orr    SPC_YAPX, SPC_YAPX, r1, lsr #8

.endm


# IN r0, r1
.macro ADC

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too
    subcs  r0, r0, #0x100   @ If carry set then fill upper bits

    mov    r1, SPC_YAPX, lsl #8
    and    r1, r1, #0xFF000000

    adcs   r1, r1, r0, ror #8

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    eor    r0, r0, SPC_YAPX, lsr #16
    eor    r0, r0, r1, lsr #24
    tst    r0, #0x10
    orrne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    biceq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    ands   r1, r1, #0xFF000000    @ Clear lower 24 bits away

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000    @ Put Register A back into YAPX
    orr    SPC_YAPX, SPC_YAPX, r1, lsr #8

.endm


.macro RCMP reg1 reg2

    mov    \reg1, \reg1, lsl #24
    cmp    \reg1, \reg2, lsl #24

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

.endm


.macro ACMP

    mov    r1, SPC_YAPX, lsl #8
    and    r1, r1, #0xFF000000

    cmp    r1, r0, lsl #24

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

.endm

.macro ASL

    movs   r0, r0, lsl #25

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r0, lsr #24

.endm

.macro LSR

    movs   r0, r0, lsr #1

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    ## SET_PSW (b);
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #(Negative << 8)

.endm

.macro ROL

    mov    r0, r0, lsl #1

    tst    SPC_YAPX, #(Carry << 8)
    orrne  r0, r0, #1

    tst    r0, #0x100

    biceq  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    ands   r0, r0, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r0, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

.endm

# IN - r0
.macro ROR dest=r0

    tst    SPC_YAPX, #(Carry << 8)
    orrne  r0, r0, #0x100

    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    movs   \dest, r0, lsr #1

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    ## SET_PSW (b);
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

.endm


# IN r0
.macro Push

    ## *(ram + 0x100 + S) = b;
    add     r1, SPC_RAM, SPC_S
    strb    r0, [r1, #0x100]

    ## S--;
    sub     SPC_S, SPC_S, #1
    and     SPC_S, SPC_S, #0xFF

.endm

# OUT r0
.macro Pop

    ## S++;
    add     SPC_S, SPC_S, #1
    and     SPC_S, SPC_S, #0xFF

    ## (b) = *(ram + 0x100 + S)
    add     r1, SPC_RAM, SPC_S
    ldrb    r0, [r1, #0x100]

.endm

SpcOpCodeJumpTable:
    .int Spc00
    .int Spc01
    .int Spc02
    .int Spc03
    .int Spc04
    .int Spc05
    .int Spc06
    .int Spc07
    .int Spc08
    .int Spc09
    .int Spc0A
    .int Spc0B
    .int Spc0C
    .int Spc0D
    .int Spc0E
    .int Spc0F
    .int Spc10
    .int Spc11
    .int Spc12
    .int Spc13
    .int Spc14
    .int Spc15
    .int Spc16
    .int Spc17
    .int Spc18
    .int Spc19
    .int Spc1A
    .int Spc1B
    .int Spc1C
    .int Spc1D
    .int Spc1E
    .int Spc1F
    .int Spc20
    .int Spc21
    .int Spc22
    .int Spc23
    .int Spc24
    .int Spc25
    .int Spc26
    .int Spc27
    .int Spc28
    .int Spc29
    .int Spc2A
    .int Spc2B
    .int Spc2C
    .int Spc2D
    .int Spc2E
    .int Spc2F
    .int Spc30
    .int Spc31
    .int Spc32
    .int Spc33
    .int Spc34
    .int Spc35
    .int Spc36
    .int Spc37
    .int Spc38
    .int Spc39
    .int Spc3A
    .int Spc3B
    .int Spc3C
    .int Spc3D
    .int Spc3E
    .int Spc3F
    .int Spc40
    .int Spc41
    .int Spc42
    .int Spc43
    .int Spc44
    .int Spc45
    .int Spc46
    .int Spc47
    .int Spc48
    .int Spc49
    .int Spc4A
    .int Spc4B
    .int Spc4C
    .int Spc4D
    .int Spc4E
    .int Spc4F
    .int Spc50
    .int Spc51
    .int Spc52
    .int Spc53
    .int Spc54
    .int Spc55
    .int Spc56
    .int Spc57
    .int Spc58
    .int Spc59
    .int Spc5A
    .int Spc5B
    .int Spc5C
    .int Spc5D
    .int Spc5E
    .int Spc5F
    .int Spc60
    .int Spc61
    .int Spc62
    .int Spc63
    .int Spc64
    .int Spc65
    .int Spc66
    .int Spc67
    .int Spc68
    .int Spc69
    .int Spc6A
    .int Spc6B
    .int Spc6C
    .int Spc6D
    .int Spc6E
    .int Spc6F
    .int Spc70
    .int Spc71
    .int Spc72
    .int Spc73
    .int Spc74
    .int Spc75
    .int Spc76
    .int Spc77
    .int Spc78
    .int Spc79
    .int Spc7A
    .int Spc7B
    .int Spc7C
    .int Spc7D
    .int Spc7E
    .int Spc7F
    .int Spc80
    .int Spc81
    .int Spc82
    .int Spc83
    .int Spc84
    .int Spc85
    .int Spc86
    .int Spc87
    .int Spc88
    .int Spc89
    .int Spc8A
    .int Spc8B
    .int Spc8C
    .int Spc8D
    .int Spc8E
    .int Spc8F
    .int Spc90
    .int Spc91
    .int Spc92
    .int Spc93
    .int Spc94
    .int Spc95
    .int Spc96
    .int Spc97
    .int Spc98
    .int Spc99
    .int Spc9A
    .int Spc9B
    .int Spc9C
    .int Spc9D
    .int Spc9E
    .int Spc9F
    .int SpcA0
    .int SpcA1
    .int SpcA2
    .int SpcA3
    .int SpcA4
    .int SpcA5
    .int SpcA6
    .int SpcA7
    .int SpcA8
    .int SpcA9
    .int SpcAA
    .int SpcAB
    .int SpcAC
    .int SpcAD
    .int SpcAE
    .int SpcAF
    .int SpcB0
    .int SpcB1
    .int SpcB2
    .int SpcB3
    .int SpcB4
    .int SpcB5
    .int SpcB6
    .int SpcB7
    .int SpcB8
    .int SpcB9
    .int SpcBA
    .int SpcBB
    .int SpcBC
    .int SpcBD
    .int SpcBE
    .int SpcBF
    .int SpcC0
    .int SpcC1
    .int SpcC2
    .int SpcC3
    .int SpcC4
    .int SpcC5
    .int SpcC6
    .int SpcC7
    .int SpcC8
    .int SpcC9
    .int SpcCA
    .int SpcCB
    .int SpcCC
    .int SpcCD
    .int SpcCE
    .int SpcCF
    .int SpcD0
    .int SpcD1
    .int SpcD2
    .int SpcD3
    .int SpcD4
    .int SpcD5
    .int SpcD6
    .int SpcD7
    .int SpcD8
    .int SpcD9
    .int SpcDA
    .int SpcDB
    .int SpcDC
    .int SpcDD
    .int SpcDE
    .int SpcDF
    .int SpcE0
    .int SpcE1
    .int SpcE2
    .int SpcE3
    .int SpcE4
    .int SpcE5
    .int SpcE6
    .int SpcE7
    .int SpcE8
    .int SpcE9
    .int SpcEA
    .int SpcEB
    .int SpcEC
    .int SpcED
    .int SpcEE
    .int SpcEF
    .int SpcF0
    .int SpcF1
    .int SpcF2
    .int SpcF3
    .int SpcF4
    .int SpcF5
    .int SpcF6
    .int SpcF7
    .int SpcF8
    .int SpcF9
    .int SpcFA
    .int SpcFB
    .int SpcFC
    .int SpcFD
    .int SpcFE
    .int SpcFF

Spc00:
    AddCyclesCheckTime 2
    add   SPC_PC, SPC_PC, #1
    b    spc_loop

Spc01:
    AddCyclesCheckTime 8
    TCALL 0
    b    spc_loop

Spc02:
    AddCyclesCheckTime 4
    SET 0

Spc03:
    BBS 0

Spc04:
    # OR A,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc05:
    # OR A,abs

    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc06:
    # OR A,(X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

Spc07:
    AddCyclesCheckTime 6

    IndexedXIndirect

    CPU_READ

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc08:
    # OR A,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc09:
    # OR dp(dest),dp(src)
    AddCyclesCheckTime 6

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP
    mov    r2, r0

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)
    CPU_READ_DP

    orrs    r1, r0, r2

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc0A:
    # OR1 C,membit
    AddCyclesCheckTime 5

    tst    SPC_YAPX, #(Carry << 8)
    bne    Spc0ACarrySet

        MemBit

        IncrementPC 3

        ## if (CPU_READ (addr) & (1 << Bit))
        add    r2, r1, #1     @ Save
        CPU_READ
        movs   r0, r0, lsr r2
            orrcs    SPC_YAPX, SPC_YAPX, #(Carry << 8)
        b    spc_loop

    Spc0ACarrySet:

        IncrementPC 3

        b    spc_loop

Spc0B:
    # ASL dp
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    mov    r2, r0
    CPU_READ_DP

    ASL

    mov    r1, r0
    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc0C:
    # ASL abs
    AddCyclesCheckTime 5

    Absolute
    mov    r2, r0

    CPU_READ

    ASL

    mov    r1, r0
    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc0D:
    # PUSH PSW
    AddCyclesCheckTime 4

    mov    r0, SPC_YAPX, lsr #8
    and    r0, r0, #0xFF
    Push

    ## pc += 1
    IncrementPC 1
    b    spc_loop

Spc0E:
    AddCyclesCheckTime 6

    # TSET1 abs
    Absolute

    mov   r2, r0

    CPU_READ

    and    r1, SPC_YAPX, #0x00FF0000
    mov    r1, r1, lsl #8
    cmp    r1, r0, lsl #24
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    orr    r1, r0, r1, lsr #24
    mov    r0, r2
    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc0F:
    AddCyclesCheckTime 8

    ## PushW (pc + 1 - ram);
    add    r0, SPC_PC, #1    @ Ipc + 1 - Iram
    sub    r0, r0, SPC_RAM

    ## *(ram + 0x100 + S - 1) = (w);
    add    r1, SPC_RAM, SPC_S
    strb   r0, [r1, #0x0FF]

    ## *(ram + 0x100 + S) = ((w) >> 8);
    mov    r0, r0, lsr #8
    strb   r0, [r1, #0x100]

    ## Push (P);
    mov    r0, SPC_YAPX, lsr #8
    and    r0, r0, #0xFF
    strb   r0, [r1, #0x0FE]

    ## S -= 3;
    sub    SPC_S, SPC_S, #3
    and    SPC_S, SPC_S, #0xFF

    orr    SPC_YAPX, SPC_YAPX, #(Break << 8)
    bic    SPC_YAPX, SPC_YAPX, #(Interrupt << 8)

    ## pc = ram + CPU_READ(0xffde) + (CPU_READ(0xffdf)<<8);

    mov    r2, #0xFF00
    orr    r0, r2, #0xde

    ldrb   r1, [SPC_RAM, r0]    @ CPU_READ(0xffde)

    add    r0, r0, #1

    ldrb   r0, [SPC_RAM, r0]    @ (CPU_READ(0xffdf)

    orr    r0, r1, r0, lsl #8

    add    SPC_PC, SPC_RAM, r0      @ + ram

    b    spc_loop

Spc10:
    # BPL

    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Negative << 8)
    bne    Spc10NotNegative

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    Spc10NotNegative:

        SubCycles 2

        IncrementPC 2

        b    spc_loop

Spc11:
    AddCyclesCheckTime 8
    TCALL 1
    b    spc_loop

Spc12:
    AddCyclesCheckTime 4
    CLR 0
    b    spc_loop

Spc13:
    BBC 0
    b    spc_loop

Spc14:
    # OR A,dp+X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc15:
    # OR A,abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

Spc16:
    AddCyclesCheckTime 5

    AbsoluteY

    CPU_READ

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc17:
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc18:
    # OR dp,#00
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #2]
    mov    r0, r2

    CPU_READ_DP

    ldrb   r1, [SPC_PC, #1]

    orrs   r1, r0, r1

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2
    CPU_WRITE_DP

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc19:
    # OR (X),(Y)
    AddCyclesCheckTime 5


    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    mov    r2, r0

    mov    r0, SPC_YAPX, lsr #24
    CPU_READ_DP

    orrs   r1, r0, r2
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    and    r0, SPC_YAPX, #0xFF
    CPU_WRITE_DP

    IncrementPC 1

    b    spc_loop

Spc1A:
    # DECW dp
    AddCyclesCheckTime 6

    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2

    CPU_READ_DP

    mov    r1, r0
    add    r0, r2, #1
    mov    r2, r1

    CPU_READ_DP

    orr    r0, r2, r0, lsl #8

    subs   r2, r0, #1

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r2, #0x8000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    and    r1, r2, #0xFF
    ldrb   r0, [SPC_PC, #1]

    CPU_WRITE_DP

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, #1
    and    r0, r0, #0xFF
    mov    r1, r2, lsr #8
    and    r1, r1, #0xFF

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc1B:
    # ASL dp+X
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    and    r1, SPC_YAPX, #0xFF
    add    r0, r0, r1
    and    r2, r0, #0xFF

    CPU_READ_DP

    ASL

    mov    r1, r0
    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc1C:
    # ASL A
    AddCyclesCheckTime 2

    and    r0, SPC_YAPX, #0xFF0000
    mov    r0, r0, lsr #16
    ASL
    bic    SPC_YAPX, SPC_YAPX, #0xFF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc1D:
    # DEC X
    AddCyclesCheckTime 2

    ## X--;
    mov    SPC_YAPX, SPC_YAPX, ror #8
    subs   SPC_YAPX, SPC_YAPX, #0x01000000

    ## SET_PSW (X);
    bicpl  SPC_YAPX, SPC_YAPX, #Negative @ This is adjusted for rotation
    orrmi  SPC_YAPX, SPC_YAPX, #Negative

    mov    SPC_YAPX, SPC_YAPX, ror #24

    ands   r0, SPC_YAPX, #0xFF
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc1E:
    # CMP X,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    and    r1, SPC_YAPX, #0xFF     @ Register_X
    RCMP   r1, r0

    IncrementPC 3

    b    spc_loop

Spc1F:
    AddCyclesCheckTime 6

    Absolute

    ## pc = ram + CPU_READ (addr + X) + (CPU_READ (addr + X + 1) << 8);

    and    r2, SPC_YAPX, #0xFF     @ Register_X
    add    r2, r2, r0
    mov    r0, r2

    CPU_READ

    add   SPC_PC, SPC_RAM, r0

    add   r0, r2, #1

    CPU_READ

    add    SPC_PC, SPC_PC, r0, lsl #8

    b    spc_loop

Spc20:
    AddCyclesCheckTime 2

    # CLRP
    bic    SPC_YAPX, SPC_YAPX, #(DirectPage << 8)

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc21:
    AddCyclesCheckTime 8
    TCALL 2
    b    spc_loop

Spc22:
    AddCyclesCheckTime 4
    SET 1

Spc23:
    BBS 1

Spc24:
    # AND A,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP


    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc25:
    # AND A,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc26:
    # AND A,(X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

Spc27:
    # AND A,(dp+X)
    AddCyclesCheckTime 6

    IndexedXIndirect

    CPU_READ

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc28:
    # AND A,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc29:
    # AND dp(dest),dp(src)
    AddCyclesCheckTime 6

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP
    mov    r2, r0

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)
    CPU_READ_DP

    ands   r1, r0, r2

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc2A:
    # OR1 C, not membit
    AddCyclesCheckTime 5

    MemBit

    IncrementPC 3

    tst    SPC_YAPX, #(Carry << 8)
    bne    spc_loop    @ Return

        ## if (!(CPU_READ (addr) & (1 << Bit)))
        add    r2, r1, #1     @ Save
        CPU_READ
        movs   r0, r0, lsr r2
            orrcs    SPC_YAPX, SPC_YAPX, #(Carry << 8)

    b    spc_loop

Spc2B:
    #  ROL dp
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    mov    r2, r0
    CPU_READ_DP

    ROL

    mov    r1, r0
    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc2C:
    # ROL abs
    AddCyclesCheckTime 5

    Absolute
    mov    r2, r0

    CPU_READ

    ROL

    mov    r1, r0
    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc2D:
    #  PUSH A
    AddCyclesCheckTime 4

    mov    r0, SPC_YAPX, lsr #16
    and    r0, r0, #0xFF

    Push

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc2E:
    # CBNE dp,rel
    AddCyclesCheckTime 7

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF

    cmp   r0, r1
    beq   Spc2Eequal

        ldrsb  r0, [SPC_PC, #2]
        add    SPC_PC, SPC_PC, #3
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    Spc2Eequal:
         IncrementPC 3
         SubCycles 2

    b    spc_loop

Spc2F:
    # BRA
    AddCyclesCheckTime 4

    ldrsb  r0, [SPC_PC, #1]
    add    SPC_PC, SPC_PC, #2
    add    SPC_PC, SPC_PC, r0
    b    spc_loop

Spc30:
    # BMI
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Negative << 8)
    beq    Spc30Negative

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    Spc30Negative:
        IncrementPC 2
        SubCycles 2

    b   spc_loop

Spc31:
    AddCyclesCheckTime 8
    TCALL 3
    b    spc_loop

Spc32:
    AddCyclesCheckTime 4
    CLR 1
    b    spc_loop

Spc33:
    BBC 1
    b    spc_loop

Spc34:
    # AND A,dp+X
    AddCyclesCheckTime 4


    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc35:

    # AND A,abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc36:

    #  AND A,abs+Y
    AddCyclesCheckTime 5

    AbsoluteY

    CPU_READ

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc37:
    # AND A,(dp)+Y
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    ands   r0, SPC_YAPX, r0, lsl #16
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc38:
    # AND dp,#00
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #2]
    mov    r0, r2

    CPU_READ_DP

    ldrb   r1, [SPC_PC, #1]
    ands   r1, r1, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2
    CPU_WRITE_DP

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc39:
    # AND (X),(Y)
    AddCyclesCheckTime 5


    and    r0, SPC_YAPX, #0xFF    @ Register X
    CPU_READ_DP
    mov    r2, r0

    mov    r0, SPC_YAPX, lsr #24  @ Register Y
    CPU_READ_DP

    ands   r1, r0, r2
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    and    r0, SPC_YAPX, #0xFF
    CPU_WRITE_DP

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc3A:
    # INCW dp
    AddCyclesCheckTime 6

    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2
    CPU_READ_DP

    mov    r1, r0
    add    r0, r2, #1
    mov    r2, r1

    CPU_READ_DP

    orr    r0, r2, r0, lsl #8

    add    r1, r0, #1
    movs   r2, r1, lsl #16   @ Set zero flag
    mov    r2, r2, lsr #16
    and    r1, r1, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ldrb   r0, [SPC_PC, #1]
    CPU_WRITE_DP


    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, #1
    and    r0, r0, #0xFF

    mov    r1, r2, lsr #8

    CPU_WRITE_DP

    IncrementPC 2
 
    b    spc_loop

Spc3B:
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    and    r1, SPC_YAPX, #0xFF
    add    r0, r0, r1
    and    r2, r0, #0xFF

    CPU_READ_DP

    ROL

    mov    r1, r0
    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc3C:
    # ROL A
    AddCyclesCheckTime 2

    and    r0, SPC_YAPX, #0xFF0000
    mov    r0, r0, lsr #16

    ROL

    bic    SPC_YAPX, SPC_YAPX, #0xFF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc3D:
    # INC X
    AddCyclesCheckTime 2

    ## X++;
    add    r0, SPC_YAPX, #1
    ands   r0, r0, #0xFF
    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0

    ## SET_PSW (X);
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc3E:
    # CMP X,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    and    r1, SPC_YAPX, #0xFF    @ Register_X

    RCMP r1, r0

    IncrementPC 2

    b    spc_loop

Spc3F:
    AddCyclesCheckTime 8

    Absolute

    ## PushW (pc + 3 - ram);
    add    r1, SPC_PC, #3
    sub    r1, r1, SPC_RAM

    add    r2, SPC_RAM, SPC_S
    strb   r1, [r2, #0xFF]     @ *(ram + 0x100 + S--) = (w);
    mov    r1, r1, lsr #8
    strb   r1, [r2, #0x100]    @ *(ram + 0x100 + S--) = ((w) >> 8);
    sub    SPC_S, SPC_S, #2
    and    SPC_S, SPC_S, #0xFF

    ## pc = ram + addr;
    add    SPC_PC, SPC_RAM, r0

    b    spc_loop

Spc40:
    # SETP
    AddCyclesCheckTime 2

    orr    SPC_YAPX, SPC_YAPX, #(DirectPage << 8)

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc41:
    AddCyclesCheckTime 8
    TCALL 4
    b    spc_loop

Spc42:
    AddCyclesCheckTime 4
    SET 2

Spc43:
    BBS 2

Spc44:
    # EOR A,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP
    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc45:
    # EOR A,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc46:
    # EOR A,(X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

Spc47:
    # EOR A,(dp+X)
    AddCyclesCheckTime 6

    IndexedXIndirect

    CPU_READ

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc48:
    # EOR A,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc49:
    #  EOR dp(dest),dp(src)
    AddCyclesCheckTime 6

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP
    mov    r2, r0

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)
    CPU_READ_DP

    eors   r1, r0, r2

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc4A:
    # AND1 C,membit
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Carry << 8)
    beq    spc_loop    @ Return

        MemBit

        ## if ( (CPU_READ (addr) & (1 << Bit)) )
        add    r2, r1, #1     @ Save
        CPU_READ
        movs   r0, r0, lsr r2
            orrcs    SPC_YAPX, SPC_YAPX, #(Carry << 8)

    IncrementPC 3

    b    spc_loop

Spc4B:
    # LSR dp
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    mov    r2, r0
    CPU_READ_DP

    LSR

    mov    r1, r0
    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2
    b    spc_loop

Spc4C:
    # LSR abs
    AddCyclesCheckTime 5

    Absolute
    mov    r2, r0

    CPU_READ

    LSR

    mov    r1, r0
    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc4D:
    # PUSH X
    AddCyclesCheckTime 4

    and    r0, SPC_YAPX, #0xFF
    Push

    ## pc += 1
    IncrementPC 1

    b    spc_loop

Spc4E:
    # TCLR1 abs
    AddCyclesCheckTime 6

    Absolute
    mov   r2, r0

    CPU_READ

    and    r1, SPC_YAPX, #0x00FF0000
    mov    r1, r1, lsl #8
    cmp    r1, r0, lsl #24
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    bic    r1, r0, SPC_YAPX, lsr #16
    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc4F:
    AddCyclesCheckTime 6

    ## PushW (pc + 2 - ram);
    add    r0, SPC_PC, #2
    sub    r0, r0, SPC_RAM

    add    r1, SPC_RAM, SPC_S
    strb   r0, [r1, #0xFF]     @ *(ram + 0x100 + S--) = (w);
    mov    r0, r0, lsr #8
    strb   r0, [r1, #0x100]    @ *(ram + 0x100 + S--) = ((w) >> 8);
    sub    SPC_S, SPC_S, #2
    and    SPC_S, SPC_S, #0xFF

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_RAM
    add    SPC_PC, r0, #0xFF00

    b    spc_loop

Spc50:
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Overflow << 8)
    bne    Spc50NotOverflow

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    Spc50NotOverflow:
        IncrementPC 2
        SubCycles 2

    b    spc_loop

Spc51:
    AddCyclesCheckTime 8
    TCALL 5
    b    spc_loop

Spc52:
    AddCyclesCheckTime 4
    CLR 2
    b    spc_loop

Spc53:
    BBC 2
    b    spc_loop

Spc54:
    # EOR A,dp+X
    AddCyclesCheckTime 4


    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc55:
    # EOR A,abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc56:
    # EOR A,abs+Y
    AddCyclesCheckTime 5

    AbsoluteY

    CPU_READ

    eor    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc57:
    # EOR A,(dp)+Y
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    eor    r2, r2, r0, lsl #16

    tst    SPC_YAPX, #0x00FF0000
    bicne  SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc58:
    # EOR dp,#00
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #2]
    mov    r0, r2

    CPU_READ_DP

    ldrb   r1, [SPC_PC, #1]

    eors   r1, r0, r1

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc59:
    # EOR (X),(Y)
    AddCyclesCheckTime 5


    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    mov    r2, r0

    mov    r0, SPC_YAPX, lsr# 24
    CPU_READ_DP

    eors   r1, r0, r2

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    and    r0, SPC_YAPX, #0xFF
    CPU_WRITE_DP
    
    IncrementPC 1

    b    spc_loop

Spc5A:
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    mov    r2, r0
    CPU_READ_DP

    mov    r1, r0
    add    r0, r2, #1
    mov    r2, r1

    CPU_READ_DP

    orr    r0, r2, r0, lsl #8

    mov    r2, SPC_YAPX, lsr #16
    mov    r2, r2, lsl #16
 
    cmp    r2, r0, lsl #16
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

Spc5B:
    # LSR dp+X
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    and    r1, SPC_YAPX, #0xFF
    add    r2, r0, r1
    and    r0, r2, #0xFF

    CPU_READ_DP

    LSR

    mov    r1, r0
    and    r0, r2, #0xFF
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc5C:
    # LSR A
    AddCyclesCheckTime 2

    and    r0, SPC_YAPX, #0xFF0000
    mov    r0, r0, lsr #16
    LSR
    bic    SPC_YAPX, SPC_YAPX, #0xFF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    IncrementPC 1

    b    spc_loop

Spc5D:
    # MOV X,A
    AddCyclesCheckTime 2

    ands   r0, SPC_YAPX, #0x00FF0000
    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0, lsr #16

    # SET_PSW (X);
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    tst    SPC_YAPX, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

Spc5E:
    # CMP Y,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    mov    r1, SPC_YAPX, lsr #24    @ Register_Y

    RCMP   r1, r0

    IncrementPC 3

    b    spc_loop

Spc5F:
    AddCyclesCheckTime 3

    Absolute

    ## pc = ram + addr;
    add   SPC_PC, SPC_RAM, r0

    b    spc_loop

Spc60:
    AddCyclesCheckTime 2

    bic    SPC_YAPX, SPC_YAPX, #(Carry << 8)

    IncrementPC 1

    b    spc_loop

Spc61:
    AddCyclesCheckTime 8
    TCALL 6
    b    spc_loop

Spc62:
    AddCyclesCheckTime 4
    SET 3

Spc63:
    BBS 3

Spc64:
    # CMP A,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP

    ACMP

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc65:
    # CMP A,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    ACMP

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc66:
    # CMP A,(X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    ACMP

    IncrementPC 1

    b    spc_loop

Spc67:
    # CMP A,(dp+X)
    AddCyclesCheckTime 6

    IndexedXIndirect

    CPU_READ

    ACMP

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc68:
    # CMP A,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]

    ACMP

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc69:
    # CMP dp(dest), dp(src)
    AddCyclesCheckTime 6

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)
    CPU_READ_DP
    mov    r2, r0, lsl #24

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP

    cmp    r2, r0, lsl #24

    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

Spc6A:
    # AND1 C, not membit
    AddCyclesCheckTime 4

    MemBit

    IncrementPC 3

    tst    SPC_YAPX, #(Carry << 8)
    beq    spc_loop    @ Return

        ## if (CPU_READ (addr) & (1 << Bit))
        add    r2, r1, #1     @ Save
        CPU_READ
        movs   r0, r0, lsr r2
            biccs    SPC_YAPX, SPC_YAPX, #(Carry << 8)

    b    spc_loop

Spc6B:
    # ROR dp
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    mov    r2, r0

    CPU_READ_DP

    ROR r1

    mov    r0, r2

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc6C:
    # ROR abs
    AddCyclesCheckTime 5

    Absolute
    mov    r2, r0

    CPU_READ

    ROR r1

    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc6D:
    # PUSH Y
    AddCyclesCheckTime 4

    mov    r0, SPC_YAPX, lsr #24
    Push

    IncrementPC 1

    b    spc_loop

Spc6E:
    # DBNZ dp,rel
    AddCyclesCheckTime 7

    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2

    CPU_READ_DP
    sub    r0, r0, #1
    ands   r1, r0, #0xFF

    beq    Spc6E_EqualsZero

        mov    r0, r2
        CPU_WRITE_DP

        ldrsb   r0, [SPC_PC, #2]
        add     SPC_PC, SPC_PC, #3
        add     SPC_PC, SPC_PC, r0

        b    spc_loop

    Spc6E_EqualsZero:

        mov    r0, r2
        CPU_WRITE_DP

        SubCycles 2

        IncrementPC 3

    b    spc_loop

Spc6F:
    AddCyclesCheckTime 5

    ## S += 2;
    add   SPC_S, SPC_S, #2
    ands  SPC_S, SPC_S, #0xFF

    ## if( S == 0 )
    beq    Spc6F_StackZero

        ## PC = *(ram + 0xff + S) + (*(ram + 0x100 + S) << 8)
        add    r2, SPC_RAM, SPC_S
        ldrb   r0, [r2, #0xff]
        ldrb   r1, [r2, #0x100]
        orr    r0, r0, r1, lsl #8

        ## pc = ram + PC;
        add    SPC_PC, SPC_RAM, r0

        b    spc_loop
    ## else
    Spc6F_StackZero:

        ## PC = *(ram + 0x1ff) | (*(ram + 0x100)<<8);
        add    r2, SPC_RAM, #0x100
        ldrb   r0, [r2, #0xff]
        ldrb   r1, [r2]
        orr    r0, r0, r1, lsl #8

        ## pc = ram + PC;
        add    SPC_PC, SPC_RAM, r0

        b    spc_loop


Spc70:
    # BVS
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Overflow << 8)
    beq    Spc70NoOverFlow

        ldrb   r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, r0
        add    SPC_PC, SPC_PC, #2
        b    spc_loop

    Spc70NoOverFlow:

        SubCycles 2

        ## pc += 2;
        IncrementPC 2

    b    spc_loop

Spc71:
    AddCyclesCheckTime 8
    TCALL 7
    b    spc_loop

Spc72:
    AddCyclesCheckTime 4
    CLR 3
    b    spc_loop

Spc73:
    BBC 3
    b    spc_loop

Spc74:
    #  CMP A, dp+X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX    @ Register_X
    and    r0, r0, #0xFF

    CPU_READ_DP

    ACMP

    IncrementPC 2

    b    spc_loop

Spc75:
    # CMP A,abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    ACMP

    IncrementPC 3

    b    spc_loop

Spc76:
    # CMP A,abs+Y
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r0, r0, r1, lsl #8
    add    r0, r0, SPC_YAPX, lsr #24

    CPU_READ

    ACMP

    IncrementPC 3

    b    spc_loop

Spc77:
    # CMP A,(dp)+Y
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    ACMP

    IncrementPC 2

    b    spc_loop
Spc78:
    # CMP dp,#00
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #2]
    CPU_READ_DP

    ldrb   r1, [SPC_PC, #1]

    RCMP   r0, r1

    IncrementPC 3

    b    spc_loop

.ltorg
Spc79:
    # CMP (X),(Y)
    AddCyclesCheckTime 5

    IncrementPC 1

    and    r0, SPC_YAPX, #0xFF   @ Register_X
    CPU_READ_DP
    mov    r2, r0

    mov    r0, SPC_YAPX, lsl #24 @ Register_Y
    CPU_READ_DP

    RCMP r2, r0

    b    spc_loop

Spc7A:
    # ADDW YA,dp
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2
    CPU_READ_DP

    mov    r1, r0
    add    r0, r2, #1
    mov    r2, r1

    CPU_READ_DP

    orr    r0, r2, r0, lsl #8

    mov    r2, SPC_YAPX   @ Save original
    adds   SPC_YAPX, SPC_YAPX, r0, lsl #16

    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    movs   r1, SPC_YAPX, lsr #16

    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    eor    r2, r2, r0, lsl #16
    eor    r2, r2, SPC_YAPX
    tst    r2, #0x10000000

    orrne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    biceq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    IncrementPC 2

    b    spc_loop

Spc7B:
    # ROR dp+X
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r2, r0, #0xFF

    CPU_READ_DP

    ROR r1

    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc7C:
    #  ROR A
    AddCyclesCheckTime 2

    and    r0, SPC_YAPX, #0x00FF0000
    mov    r0, r0, lsr #16

    ROR

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    IncrementPC 1
    b    spc_loop

Spc7D:
    # MOV A,X
    AddCyclesCheckTime 2

    ands   r0, SPC_YAPX, #0xFF
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

Spc7E:
    # CMP Y,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    mov    r1, SPC_YAPX, lsr #24    @ Register Y

    RCMP   r1, r0

    IncrementPC 2

    b    spc_loop

Spc7F:
    # RETI

    AddCyclesCheckTime 6

    ## Pop (P);

    ## S++;
    add    SPC_S, SPC_S, #1
    and    SPC_S, SPC_S, #0xFF

    ## (b) = *(ram + 0x100 + S)
    add    r1, SPC_S, SPC_RAM
    ldrb   r0, [r1, #0x100]

    bic    SPC_YAPX, #0xFF00
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #8

    ## PopW (PC );

    ## S += 2;
    adds   SPC_S, SPC_S, #2
    and    SPC_S, SPC_S, #0xFF

    ## if( S == 0 )
    beq    Spc7F_StackZero

        ## PC = *(ram + 0xff + S) + (*(ram + 0x100 + S) << 8)

        add    r2, SPC_S, SPC_RAM
        ldrb   r0, [r2, #0xff]
        ldrb   r1, [r2, #0x100]
        orr    r0, r0, r1, lsl #8

        ## pc = ram + PC;
        add    SPC_PC, SPC_RAM, r0

        b    spc_loop
    ## else
    Spc7F_StackZero:

        ## PC = *(ram + 0x1ff) | (*(ram + 0x100)<<8);
        add    r2, SPC_RAM, #0x100
        ldrb   r0, [r2, #0xff]
        ldrb   r1, [r2]
        orr    r0, r0, r1, lsl #8

        ## pc = ram + PC;
        add    SPC_PC, SPC_RAM, r0

        b    spc_loop

Spc80:
    # SETC
    AddCyclesCheckTime 2

    orr    SPC_YAPX, SPC_YAPX, #(Carry << 8)

    IncrementPC 1

    b    spc_loop

Spc81:
    AddCyclesCheckTime 8
    TCALL 8
    b    spc_loop

Spc82:
    AddCyclesCheckTime 4
    SET 4

Spc83:
    BBS 4

Spc84:
    # ADC A,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    ADC

    ## pc += 2;
    IncrementPC 2

    b    spc_loop

Spc85:
    # ADC A, abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    ADC

    ## pc += 3;
    IncrementPC 3

    b    spc_loop

Spc86:
    # ADC A,(X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    ADC

    IncrementPC 1

    b    spc_loop

Spc87:
    # ADC A,(dp+X)
    AddCyclesCheckTime 6

    IndexedXIndirect

    CPU_READ

    ADC

    IncrementPC 2

    b    spc_loop

Spc88:
    # ADC A,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)

    ADC

    IncrementPC 2

    b    spc_loop

Spc89:
    # ADC dp(dest),dp(src)
    AddCyclesCheckTime 6

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP

    mov    r2, r0
    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)

    CPU_READ_DP

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too
    subcs  r2, r2, #0x100   @ If carry set then fill upper bits

    mov    r0, r0, lsl #24

    adcs   r1, r0, r2, ror #8

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    eor    r0, r0, r2, ror #8
    eor    r0, r0, r1
    tst    r0, #0x10000000
    orrne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    biceq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    movs   r1, r1, lsr #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ldrb   r0, [SPC_PC, #2]

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc8A:
    # EOR1 C, membit
    AddCyclesCheckTime 5

    MemBit

    mov    r2, r1     @ Save bit

    CPU_READ

    @ This is genius code
    mov    r0, r0, lsl #8
    mov    r1, #0x100
    and    r0, r0, r1, lsl r2
    eors   SPC_YAPX, SPC_YAPX, r0, lsr r2

    IncrementPC 3

    b    spc_loop

Spc8B:
    # DEC dp
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    mov    r2, r0

    CPU_READ_DP
    sub    r0, r0, #1
    ands   r1, r0, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2
    CPU_WRITE_DP
    
    IncrementPC 2

    b    spc_loop

Spc8C:
    # DEC abs
    AddCyclesCheckTime 5

    Absolute

    mov   r2, r0

    CPU_READ

    sub    r0, r0, #1
    ands   r1, r0, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

Spc8D:
    # MOV Y,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    movs   r2, r0, lsl #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF000000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #24

    IncrementPC 2

    b    spc_loop

Spc8E:
    # POP PSW
    AddCyclesCheckTime 4

    Pop

    bic    SPC_YAPX, SPC_YAPX, #0xFF00
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #8

    IncrementPC 1

    b    spc_loop

Spc8F:
    # MOV dp,#00
    AddCyclesCheckTime 5


    ldrb   r1, [SPC_PC, #1]
    ldrb   r0, [SPC_PC, #2]

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc90:
    # BCC
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Carry << 8)
    bne    Spc90CarrySet

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    Spc90CarrySet:

        IncrementPC 2

        SubCycles 2

        b    spc_loop

Spc91:
    AddCyclesCheckTime 8
    TCALL 9
    b    spc_loop

Spc92:
    AddCyclesCheckTime 4
    CLR 4
    b    spc_loop

Spc93:
    BBC 4
    b    spc_loop

Spc94:
    # ADC A,dp+X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    ADC

    IncrementPC 2

    b    spc_loop

Spc95:
    # ADC A, abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    ADC

    IncrementPC 3

    b    spc_loop

Spc96:
    # ADC A, abs+Y
    AddCyclesCheckTime 5

    AbsoluteY

    CPU_READ

    ADC

    IncrementPC 3

    b    spc_loop

Spc97:
    # ADC A, (dp)+Y
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    ADC

    IncrementPC 2

    b    spc_loop

Spc98:
    # ADC dp,#00
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #2]
    CPU_READ_DP

    ldrb   r2, [SPC_PC, #1]

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too
    subcs  r2, r2, #0x100   @ If carry set then fill upper bits

    mov    r0, r0, lsl #24

    adcs   r1, r0, r2, ror #8

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    eor    r0, r0, r2, ror #8
    eor    r0, r0, r1
    tst    r0, #0x10000000
    orrne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    biceq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    movs   r1, r1, lsr #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

Spc99:
    # ADC (X),(Y)
    AddCyclesCheckTime 5

    mov    r0, SPC_YAPX, lsl #24
    CPU_READ_DP
    mov    r2, r0

    and    r0, SPC_YAPX, #0xFF    @ Register_X
    CPU_READ_DP

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too
    subcs  r2, r2, #0x100   @ If carry set then fill upper bits

    mov    r0, r0, lsl #24

    adcs   r1, r0, r2, ror #8

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    eor    r0, r0, r2, ror #8
    eor    r0, r0, r1
    tst    r0, #0x10000000
    orrne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    biceq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    movs   r1, r1, lsr #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    and    r0, SPC_YAPX, #0xFF    @ Register_X

    CPU_WRITE_DP

    IncrementPC 1

    b    spc_loop

Spc9A:
    # SUBW YA,dp
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2
    CPU_READ_DP
    mov    r1, r0

    add    r0, r2, #1
    mov    r2, r1

    CPU_READ_DP

    orr    r0, r2, r0, lsl #8


    subs   r2, SPC_YAPX, r0, lsl #16

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    movs   r2, r2, lsr #16

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    eor    r0, SPC_YAPX, r0, lsl #16
    eor    r0, r0, r2, lsl #16
    tst    r0, #0x10000000
    orreq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    mov    SPC_YAPX, SPC_YAPX, lsl #16
    mov    SPC_YAPX, SPC_YAPX, lsr #16
    orr    SPC_YAPX, SPC_YAPX, r2, lsl #16

    IncrementPC 2

    b    spc_loop

Spc9B:
    # DEC dp+X
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #1]
    add    r2, r2, SPC_YAPX
    and    r0, r2, #0xFF

    CPU_READ_DP

    sub    r1, r0, #1
    ands   r1, r1, #0xFF
    and    r0, r2, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

Spc9C:
    # DEC A
    AddCyclesCheckTime 2

    and    r0, SPC_YAPX, #0xFF0000
    subs   r0, r0, #0x010000
    and    r0, r0, #0xFF0000

    bic    SPC_YAPX, SPC_YAPX, #0xFF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 1;
    IncrementPC 1

    b    spc_loop

Spc9D:
    # MOV X,SP
    AddCyclesCheckTime 2

    ## X = S;

    movs   r0, SPC_S, lsl #24

    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, SPC_S

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

Spc9E:
    # DIV YA,X
    AddCyclesCheckTime 12

    ## if ( (X & 0xf ) <= ( YA & 0x0f ) )
    and    r0, SPC_YAPX, #0x0F
    and    r1, SPC_YAPX, #0x0F000000
    cmp    r0, r1, lsr #24
    orrle  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    bicgt  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    mov    r0, SPC_YAPX, lsr #16    @ yva = YA
    and    r1, SPC_YAPX, #0xFF      @ x = X << 9;
    mov    r1, r1, lsl #9
    mov    r2, #9                   @ Loop 9 times

    Spc9E_Loop:
        mov    r0, r0, lsl #1
        tst    r0, #0x20000
        movne  r0, r0, lsl #15
        movne  r0, r0, lsr #15
        orrne  r0, r0, #1

        cmp    r0, r1
        eorge  r0, r0, #1

        tst    r0, #1
        subne  r0, r0, r1
        movne  r0, r0, lsl #15
        movne  r0, r0, lsr #15

        subs   r2, r2, #1
        bne    Spc9E_Loop

    tst    r0, #0x100
    orrne  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    biceq  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    mov    r1, r0, lsr #9
    and    r1, r1, #0xFF    @ Register Y

    ands   r0, r0, #0xFF    @ Register A

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r0, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    SPC_YAPX, SPC_YAPX, lsl #16
    mov    SPC_YAPX, SPC_YAPX, lsr #16

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16
    orr    SPC_YAPX, SPC_YAPX, r1, lsl #24

    IncrementPC 1

    b    spc_loop

Spc9F:
    # XCN A
    AddCyclesCheckTime 5

    and    r0, SPC_YAPX, #0x00F00000
    and    r1, SPC_YAPX, #0x000F0000
    mov    r0, r0, lsr #4
    orrs   r0, r0, r1, lsl #4

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

SpcA0:
    # EI
    AddCyclesCheckTime 3

    orr    SPC_YAPX, SPC_YAPX, #(Interrupt << 8)

    IncrementPC 1

    b    spc_loop

SpcA1:
    AddCyclesCheckTime 8
    TCALL 10
    b    spc_loop

SpcA2:
    AddCyclesCheckTime 4
    SET 5

SpcA3:
    BBS 5

SpcA4:
    # SBC A,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    SBC

    IncrementPC 2

    b    spc_loop

SpcA5:
    # SBC A, abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    SBC

    IncrementPC 3

    b    spc_loop

SpcA6:
    # SBC A, (X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    SBC

    IncrementPC 1

    b    spc_loop

SpcA7:
    # SBC A,(dp+X)
    AddCyclesCheckTime 6

    IndexedXIndirect

    CPU_READ

    SBC

    IncrementPC 2

    b    spc_loop

SpcA8:
    # SBC A,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)

    SBC

    IncrementPC 2

    b    spc_loop

SpcA9:
    # SBC dp(dest), dp(src)
    AddCyclesCheckTime 6

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    CPU_READ_DP
    mov    r2, r0

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)
    CPU_READ_DP

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too

    mov    r0, r0, lsl #24

    sbcs   r1, r0, r2, lsl #24

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    eor    r0, r0, SPC_YAPX, ror #8
    eor    r0, r0, r1
    tst    r0, #0x10000000
    orreq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    movs   r1, r1, lsr #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    ldrb   r0, [SPC_PC, #2]    @ *(pc + 2)

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

SpcAA:
    # MOV1 C,membit
    AddCyclesCheckTime 4

    MemBit

    IncrementPC 3

    ## if (CPU_READ (addr) & (1 << Bit))
    add    r2, r1, #1     @ Save
    CPU_READ

        movs   r0, r0, lsr r2
        orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)
        biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    b    spc_loop

SpcAB:
    # INC dp
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]    @ *(pc + 1)
    mov    r2, r0

    CPU_READ_DP

    add    r0, r0, #1
    ands   r1, r0, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2
    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcAC:
    # INC abs
    AddCyclesCheckTime 5

    Absolute

    mov   r2, r0

    CPU_READ

    add    r0, r0, #1
    ands   r1, r0, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r0, r2

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcAD:
    # CMP Y,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]

    mov    r1, SPC_YAPX, lsr #24    @ Register Y

    RCMP   r1, r0

    IncrementPC 2

    b    spc_loop

SpcAE:
    AddCyclesCheckTime 4

    ## Pop (YA);
    Pop

    bic    SPC_YAPX, SPC_YAPX, #0xFF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    IncrementPC 1

    b    spc_loop

SpcAF:
    # MOV (X)+, A
    AddCyclesCheckTime 4

    IncrementPC 1

    and    r0, SPC_YAPX, #0xFF

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF

    ## X++
    mov    SPC_YAPX, SPC_YAPX, ror #8
    add    SPC_YAPX, SPC_YAPX, #0x01000000
    mov    SPC_YAPX, SPC_YAPX, ror #24

    CPU_WRITE_DP

    b    spc_loop

SpcB0:
    # BCS
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Carry << 8)
    beq    SpcB0NotNegative

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    SpcB0NotNegative:

        IncrementPC 2

        SubCycles 2

        b    spc_loop

SpcB1:
    AddCyclesCheckTime 8
    TCALL 11
    b    spc_loop

SpcB2:
    AddCyclesCheckTime 4
    CLR 5
    b    spc_loop

SpcB3:
    BBC 5
    b    spc_loop

SpcB4:
    # SBC A, dp+X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    and    r1, SPC_YAPX, #0xFF
    add    r0, r0, r1
    and    r2, r0, #0xFF

    CPU_READ_DP

    SBC

    IncrementPC 2

    b    spc_loop

SpcB5:
    # SBC A,abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    SBC

    IncrementPC 3

    b    spc_loop

SpcB6:
    AddCyclesCheckTime 5

    AbsoluteY

    CPU_READ

    SBC

    IncrementPC 3

    b    spc_loop

SpcB7:
    # SBC A,(dp)+Y
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    SBC

    IncrementPC 2

    b    spc_loop

SpcB8:
    #  SBC dp,#00
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #2]
    ldrb   r2, [SPC_PC, #1]

    CPU_READ_DP

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too

    mov    r0, r0, lsl #24

    sbcs   r1, r0, r2, lsl #24

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    eor    r0, r0, r2, ror #8
    eor    r0, r0, r1
    tst    r0, #0x10000000
    orreq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    movs   r1, r1, lsr #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    ldrb   r0, [SPC_PC, #2]

    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

SpcB9:
    #  SBC (X),(Y)
    AddCyclesCheckTime 5

    mov    r0, SPC_YAPX, lsl #24
    CPU_READ_DP
    mov    r2, r0

    and    r0, SPC_YAPX, #0xFF    @ Register_X
    CPU_READ_DP

    movs   r1, SPC_YAPX, lsr #9   @ If carry flag is set then set it in ARM too

    mov    r0, r0, lsl #24

    sbcs   r1, r0, r2, lsl #24

    orrvs  SPC_YAPX, SPC_YAPX, #(Overflow << 8)
    bicvc  SPC_YAPX, SPC_YAPX, #(Overflow << 8)

    biccc  SPC_YAPX, SPC_YAPX, #(Carry << 8)
    orrcs  SPC_YAPX, SPC_YAPX, #(Carry << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    eor    r0, r0, r2, ror #8
    eor    r0, r0, r1
    tst    r0, #0x10000000
    orreq  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)
    bicne  SPC_YAPX, SPC_YAPX, #(HalfCarry << 8)

    movs   r1, r1, lsr #24

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    and    r0, SPC_YAPX, #0xFF    @ Register_X

    CPU_WRITE_DP

    IncrementPC 1

    b    spc_loop

SpcBA:
    # MOVW YA,dp
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    mov    r2, r0

    CPU_READ_DP

    add    r1, r2, #1
    mov    r2, r0
    and    r0, r1, #0xFF

    CPU_READ_DP

    mov    SPC_YAPX, SPC_YAPX, lsl #16
    mov    SPC_YAPX, SPC_YAPX, lsr #16

    orr    SPC_YAPX, SPC_YAPX, r0, lsl #24
    orr    SPC_YAPX, SPC_YAPX, r2, lsl #16

    movs   r2, SPC_YAPX, lsr #16

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x80000000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcBB:
    # INC dp+X
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #1]
    add    r2, r2, SPC_YAPX
    and    r0, r2, #0xFF

    CPU_READ_DP

    add    r1, r0, #1
    ands   r1, r1, #0xFF
    and    r0, r2, #0xFF

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r1, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcBC:
    # INC A
    AddCyclesCheckTime 2

    add    r0, SPC_YAPX, #0x010000
    ands   r0, r0, #0xFF0000
    bic    SPC_YAPX, SPC_YAPX, #0xFF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r0, #0x800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

SpcBD:
    # MOV SP,X
    AddCyclesCheckTime 2

    and    SPC_S, SPC_YAPX, #0xFF

    IncrementPC 1

    b    spc_loop

SpcBE:
    # DAS
    AddCyclesCheckTime 3

    mov   r0, SPC_YAPX, lsr #16
    and   r0, r0, #0xFF

    cmp    r0, #0x99
    ble    SpcBE_SetCarry
    tst    SPC_YAPX, #(Carry << 8)
    bne    SpcBE_SetCarry
        sub    r0, r0, #0x60
        bic    SPC_YAPX, SPC_YAPX, #(Carry << 8)
        b      SpcBE_End
    SpcBE_SetCarry:
        orr    SPC_YAPX, SPC_YAPX, #(Carry << 8)
    SpcBE_End:


    and    r1, SPC_YAPX, #0xF
    cmp    r1, #9
    ble    SpcBE_NoHalfCarry
    tst    SPC_YAPX, #(HalfCarry << 8)
        sub    r0, r0, #0x6
    SpcBE_NoHalfCarry:

    bic   SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr   SPC_YAPX, SPC_YAPX, r0, lsl #16

    IncrementPC 1

    b    spc_loop

SpcBF:
    # MOV A,(X)+
    AddCyclesCheckTime 4

    and   r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    mov   SPC_YAPX, SPC_YAPX, ror #8     @ X++
    adds  SPC_YAPX, SPC_YAPX, #0x01000000
    mov   SPC_YAPX, SPC_YAPX, ror #24

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    movs   r0, r0, lsl #16
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0

    IncrementPC 1

    b    spc_loop

SpcC0:
    # DI
    AddCyclesCheckTime 3

    bic    SPC_YAPX, SPC_YAPX, #(Interrupt << 8)

    IncrementPC 1

    b    spc_loop

SpcC1:
    AddCyclesCheckTime 8
    TCALL 12
    b    spc_loop

SpcC2:
    AddCyclesCheckTime 4
    SET 6

SpcC3:
    BBS 6

SpcC4:
    # MOV dp,A
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcC5:
    # MOV abs,A
    AddCyclesCheckTime 5

    Absolute

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF
    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcC6:
    # MOV (X), A
    AddCyclesCheckTime 4

    and   r0, SPC_YAPX, #0xFF
    mov   r1, SPC_YAPX, lsr #16
    and   r1, r1, #0xFF

    CPU_WRITE_DP

    IncrementPC 1

    b    spc_loop

SpcC7:
    # MOV (dp+X),A
    AddCyclesCheckTime 7

    IndexedXIndirect

    mov   r1, SPC_YAPX, lsr #16
    and   r1, r1, #0xFF
    CPU_WRITE

    IncrementPC 2

    b    spc_loop

SpcC8:
    # CMP X,#00
    AddCyclesCheckTime 2

    and   r0, SPC_YAPX, #0xFF
    ldrb  r1, [SPC_PC, #1]

    RCMP  r0, r1

    IncrementPC 2

    b    spc_loop

SpcC9:
    # MOV abs,X
    AddCyclesCheckTime 5

    Absolute

    ## CPU_WRITE (addr, X);

    and   r1, SPC_YAPX, #0xFF

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcCA:
    # MOV1 membit,C
    AddCyclesCheckTime 6

    ## MemBit
    ldrb   r2, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r2, r2, r1, lsl #8

    ## addr &= 0x1fff;
    bic    r0, r2, #0xE000


    ## CPU_WRITE (addr, CPU_READ (addr) | (1 << Bit));
    CPU_READ

    ## uint8 Bit = (int8) (addr >> 13);
    mov    r2, r2, ror #13

    mov    r1, #1

    tst    SPC_YAPX, #(Carry << 8)
    orrne    r1, r0, r1, lsl r2
    biceq    r1, r0, r1, lsl r2

    mov    r0, r2, lsr #19

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcCB:
    # MOV dp,Y
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    mov    r1, SPC_YAPX, lsr #24
    CPU_WRITE_DP

    IncrementPC 2
    b    spc_loop

SpcCC:
    # MOV abs,Y
    AddCyclesCheckTime 5

    Absolute

    mov    r1, SPC_YAPX, lsr #24
    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcCD:
    # MOV X,#00
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]
    movs   r0, r0

    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    SPC_YAPX, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcCE:
    # POP X
    AddCyclesCheckTime 4

    Pop

    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0

    IncrementPC 1

    b    spc_loop

SpcCF:
    # MUL YA
    AddCyclesCheckTime 9

    mov    r0, SPC_YAPX, lsr #24    @ Y
    mov    r1, SPC_YAPX, lsr #16    @ A
    and    r1, r1, #0xFF

    mul    r1, r0, r1
    ands   r0, r1, #0xFF00

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    tst    r0, #0x8000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    mov    r1, r1, lsl #16

    mov    SPC_YAPX, SPC_YAPX, lsl #16

    orr    SPC_YAPX, r1, SPC_YAPX, lsr #16

    IncrementPC 1

    b    spc_loop

SpcD0:
    # BNE
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Zero << 8)
    bne    SpcD0_Zero

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    SpcD0_Zero:
        SubCycles 2

        IncrementPC 2

        b    spc_loop
SpcD1:
    AddCyclesCheckTime 8
    TCALL 13
    b    spc_loop

SpcD2:
    AddCyclesCheckTime 4
    CLR 6
    b    spc_loop

SpcD3:
    BBC 6
    b    spc_loop

SpcD4:
    # MOV dp+X, A
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcD5:
    # MOV abs+X,A
    AddCyclesCheckTime 6

    AbsoluteX

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcD6:
    # MOV abs+Y,A
    AddCyclesCheckTime 6

    AbsoluteY

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF
    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcD7:
    # MOV (dp)+Y,A
    AddCyclesCheckTime 7

    IndirectIndexedY

    mov    r1, SPC_YAPX, lsr #16
    and    r1, r1, #0xFF
    CPU_WRITE

    IncrementPC 2

    b    spc_loop

SpcD8:
    # MOV dp,X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    and    r1, SPC_YAPX, #0xFF
    CPU_WRITE_DP

    IncrementPC 2
    b    spc_loop

SpcD9:
    # MOV dp+Y,X
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    mov    r1, SPC_YAPX, lsr #24
    add    r0, r0, r1
    and    r0, r0, #0xFF

    and    r1, SPC_YAPX, #0xFF

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcDA:
    # MOVW dp,YA
    AddCyclesCheckTime 5

    ldrb   r2, [SPC_PC, #1]
    mov    r0, r2

    and    r1, SPC_YAPX, #0xFF0000
    mov    r1, r1, lsr #16
    CPU_WRITE_DP


    add    r0, r2, #1

    mov    r1, SPC_YAPX, lsr #24

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcDB:
    # MOV dp+X,Y
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    mov    r1, SPC_YAPX, lsr #24

    CPU_WRITE_DP

    IncrementPC 2

    b    spc_loop

SpcDC:
    # DEC Y
    AddCyclesCheckTime 2

    ## Y--;

    subs   SPC_YAPX, SPC_YAPX, #0x01000000

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ands   r0, SPC_YAPX, #0xFF000000

    ## SET_PSW (Y);
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    IncrementPC 1

    b    spc_loop

SpcDD:
    # MOV A,Y
    AddCyclesCheckTime 2

    ands   r0, SPC_YAPX, #0xFF000000   @ Y

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsr #8

    IncrementPC 1

    b    spc_loop

SpcDE:
    # CBNE dp+X,rel
    AddCyclesCheckTime 8

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    and   r2, SPC_YAPX, #0x00FF0000

    cmp   r2, r0, lsl #16
    beq   SpcDE_Eequal

        ldrsb  r0, [SPC_PC, #2]
        add    SPC_PC, SPC_PC, #3
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    SpcDE_Eequal:
        SubCycles 2

        IncrementPC 3

    b    spc_loop

SpcDF:
    # DAA
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0x00FF0000
    cmp    r0, #0x00990000
    ble    SpcDFClearCarry
    tst    SPC_YAPX, #(Carry << 8)
    beq    SpcDFClearCarry

        add    r0, r0, #0x00600000

        orr    SPC_YAPX, SPC_YAPX, #(Carry << 8)

        b SpcDFCarryDone
    SpcDFClearCarry:
        bic    SPC_YAPX, SPC_YAPX, #(Carry << 8)
    SpcDFCarryDone:

    and    r1, r0, #0x000F0000
    cmp    r1, #0x00090000
    ble    SpcDFHalfCarryDone
    tst    SPC_YAPX, #(HalfCarry << 8)
    beq    SpcDFHalfCarryDone
        add    r0, r0, #0x00060000

    SpcDFHalfCarryDone:

    and    r0, r0, #0x00FF0000
    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, r0, r0

    IncrementPC 1

    b    spc_loop


SpcE0:
    # CLRV
    AddCyclesCheckTime 2

    bic    SPC_YAPX, SPC_YAPX, #((Overflow | HalfCarry) << 8)

    IncrementPC 1

    b    spc_loop

SpcE1:
    AddCyclesCheckTime 8
    TCALL 14
    b    spc_loop

SpcE2:
    AddCyclesCheckTime 4
    SET 7

SpcE3:
    BBS 7

SpcE4:
    # MOV A, dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcE5:
    # MOV A,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

SpcE6:
    # MOV A,(X)
    AddCyclesCheckTime 3

    and    r0, SPC_YAPX, #0xFF
    CPU_READ_DP

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

SpcE7:
    # MOV A,(dp+X)
    AddCyclesCheckTime 6

    IndexedXIndirect
    CPU_READ

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcE8:
    AddCyclesCheckTime 2

    ldrb   r0, [SPC_PC, #1]
    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcE9:
    AddCyclesCheckTime 4

    Absolute

    ## X = CPU_READ (addr);

    CPU_READ

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0

    tst    SPC_YAPX, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

SpcEA:
    # NOT1 membit
    AddCyclesCheckTime 5

    ## MemBit
    ldrb   r2, [SPC_PC, #1]
    ldrb   r1, [SPC_PC, #2]
    orr    r2, r2, r1, lsl #8

    ## addr &= 0x1fff;
    bic    r0, r2, #0xE000

    ## CPU_WRITE (CPU_READ (addr) ^ (1 << Bit), addr);
    CPU_READ

    ## uint8 Bit = (int8) (addr >> 13);
    mov    r2, r2, ror #13   @ Rotate to get top three bits

    mov    r1, #1
    eor    r1, r0, r1, lsl r2  @ Upper r2 bits are ignored in shift

    mov    r0, r2, lsr #19  @ Put back in address form

    CPU_WRITE

    IncrementPC 3

    b    spc_loop

SpcEB:
    # MOV Y,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF000000
    orrs   SPC_YAPX, SPC_YAPX, r0, lsl #24

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcEC:
    # MOV Y,abs
    AddCyclesCheckTime 4

    Absolute

    CPU_READ

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF000000
    orrs   SPC_YAPX, SPC_YAPX, r0, lsl #24

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

SpcED:
    # NOTC
    AddCyclesCheckTime 3

    eor    SPC_YAPX, SPC_YAPX, #(Carry << 8)

    IncrementPC 1

    b    spc_loop

SpcEE:
    # POP Y
    AddCyclesCheckTime 4

    Pop

    bic    SPC_YAPX, SPC_YAPX, #0xFF000000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #24

    IncrementPC 1

    b    spc_loop

SpcEF:
    # SLEEP
    mov    SPC_Cycles, #0
    b      out_of_time

SpcF0:
    # BEQ: 89% time opcode
    AddCyclesCheckTime 4

    tst    SPC_YAPX, #(Zero << 8)
    bne    SpcF0_ZeroFlagSet

        SubCycles 2

        IncrementPC 2

        b    spc_loop

    SpcF0_ZeroFlagSet:

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

SpcF1:
    AddCyclesCheckTime 8
    TCALL 15
    b    spc_loop

SpcF2:
    AddCyclesCheckTime 4
    CLR 7
    b    spc_loop

SpcF3:
    BBC 7
    b    spc_loop

SpcF4:
    # MOV A, dp+X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    movs   r0, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcF5:
    # MOV A, abs+X
    AddCyclesCheckTime 5

    AbsoluteX

    CPU_READ

    movs   r0, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

SpcF6:
    # MOV A, abs+Y
    AddCyclesCheckTime 5

    AbsoluteY

    CPU_READ

    movs   r0, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 3

    b    spc_loop

SpcF7:
    # MOV A, (dp)+Y
    AddCyclesCheckTime 6

    IndirectIndexedY

    CPU_READ

    movs   r0, r0

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0x00FF0000
    orr    SPC_YAPX, SPC_YAPX, r0, lsl #16

    tst    SPC_YAPX, #0x00800000
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcF8:
    # MOV X,dp
    AddCyclesCheckTime 3

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0

    tst    SPC_YAPX, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcF9:
    # MOV X,dp+Y
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX, lsr #24
    and    r0, r0, #0xFF

    CPU_READ_DP

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF
    orr    SPC_YAPX, SPC_YAPX, r0

    tst    SPC_YAPX, #0x80
    biceq  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrne  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcFA:
    # MOV dp(dest),dp(src)
    AddCyclesCheckTime 5

    ldrb   r0, [SPC_PC, #1]
    CPU_READ_DP
    mov    r1, r0

    ldrb   r0, [SPC_PC, #2]
    CPU_WRITE_DP

    IncrementPC 3

    b    spc_loop

SpcFB:
    # MOV Y,dp+X
    AddCyclesCheckTime 4

    ldrb   r0, [SPC_PC, #1]
    add    r0, r0, SPC_YAPX
    and    r0, r0, #0xFF

    CPU_READ_DP

    movs   r0, r0
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF000000
    orrs   SPC_YAPX, SPC_YAPX, r0, lsl #24

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 2

    b    spc_loop

SpcFC:
    # INC Y
    AddCyclesCheckTime 2

    ## Y++;
    add    SPC_YAPX, SPC_YAPX, #0x01000000
    ands   r0, SPC_YAPX, #0xFF000000

    ## SET_PSW (Y);
    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    ## pc += 1
    IncrementPC 1
    b    spc_loop

SpcFD:
    # MOV Y,A
    AddCyclesCheckTime 2

    ands   r0, SPC_YAPX, #0x00FF0000   @ A

    bicne  SPC_YAPX, SPC_YAPX, #(Zero << 8)
    orreq  SPC_YAPX, SPC_YAPX, #(Zero << 8)

    bic    SPC_YAPX, SPC_YAPX, #0xFF000000
    orrs   SPC_YAPX, SPC_YAPX, r0, lsl #8

    bicpl  SPC_YAPX, SPC_YAPX, #(Negative << 8)
    orrmi  SPC_YAPX, SPC_YAPX, #(Negative << 8)

    IncrementPC 1

    b    spc_loop

SpcFE:
    # DBNZ Y,rel
    AddCyclesCheckTime 6

    add   SPC_YAPX, SPC_YAPX, #0xFF000000
    tst   SPC_YAPX, #0xFF000000

    beq    SpcFE_NotZero

        ldrsb  r0, [SPC_PC, #1]
        add    SPC_PC, SPC_PC, #2
        add    SPC_PC, SPC_PC, r0

        b    spc_loop

    SpcFE_NotZero:

        SubCycles 2

        IncrementPC 2

        b    spc_loop

SpcFF:
    # STOP
    mov    SPC_Cycles, #0
    b      out_of_time

.macro write_smp_reg

    LOCAL TimerTarget
    LOCAL RegSetControl
    LOCAL RegSetDSP

    and   r0, r0, #0xF
    # Jump to the wrapping mode. Each case code size is 4 operations
    ## switch (addr)
    add    pc, pc, r0, lsl #4
    nop

        ## case 0xf0:  // -w TEST
        strb   r1, [SPCAddr, #(SPC_smp_regs + 0)]
        ldmfd   sp!, {pc}
        nop
        nop

        ## case 0xf1:  // -w CONTROL
        b    SetControl
        nop
        nop
        nop

        ## case 0xf2:  // rw DSPADDR
        strb   r1, [SPCAddr, #(SPC_smp_regs + 2)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf3:  // rw DSPDATA
        b      DspWrite
        nop
        nop
        nop

        ## case 0xf4:  // -w CPUO0
        strb   r1, [SPCAddr, #(SPC_smp_regs + 4)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf5:  // -w CPUO1
        strb   r1, [SPCAddr, #(SPC_smp_regs + 5)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf6:  // -w CPUO2
        strb   r1, [SPCAddr, #(SPC_smp_regs + 6)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf7:  // -w CPUO3
        strb   r1, [SPCAddr, #(SPC_smp_regs + 7)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf8:
        strb   r1, [SPCAddr, #(SPC_smp_regs + 8)]
        strb   r1, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 8)]
        ldmfd  sp!, {pc}
        nop

        ##case 0xf9:
        strb   r1, [SPCAddr, #(SPC_smp_regs + 9)]
        strb   r1, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 9)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xfa:  // -w T0TARGET
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 0))
        b      TimerTarget
        nop
        nop

        ## case 0xfb:  // -w T1TARGET
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 1))
        b      TimerTarget
        nop
        nop

        ## case 0xfc:  // -w T2TARGET
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 2))
        b      TimerTarget
        nop
        nop

        ## case 0xfd:  // r- T0OUT
        add    r1, SPCAddr, #(SPC_timers + (Timer_size * 0))
        b      TimerOut
        nop
        nop
        nop

        ## case 0xfe:  // r- T1OUT
        add    r1, SPCAddr, #(SPC_timers + (Timer_size * 1))
        b      TimerOut
        nop
        nop

        ## case 0xff:  // r- T2OUT
        add    r1, SPCAddr, #(SPC_timers + (Timer_size * 2))
        b      TimerOut
        nop
        nop

    TimerOut:

        ## if ( time >= t->next_time )
        ldr    r0, [r1, #Timer_next_time]
        cmp    SPC_Cycles, r0
        blt    TimerOutZero
            ## t = run_timer_( t, time - 1);
            stmfd  sp!, {r2, r3, r12, lr}
            mov    r0, SPCAddr
            sub    r2, SPC_Cycles, #1
            bl     _ZN8SNES_SPC10run_timer_EPNS_5TimerEi
            ldmfd  sp!, {r2, r3, r12, lr}
            mov    r1, r0

        TimerOutZero:
        ## t->counter = 0
        mov    r0, #0
        str    r0, [r1, #Timer_counter]
  
        ldmfd  sp!, {pc}

    DspWrite:

        stmfd  sp!, {r2, r3, r12, lr}
        mov    r0, SPCAddr
        mov    r2, SPC_Cycles
        bl     _ZN8SNES_SPC9dsp_writeEii
        ldmfd  sp!, {r2, r3, r12, lr}
        ldmfd  sp!, {pc}

    TimerTarget:

        stmfd  sp!, {r2, r3, r4, r12, lr}

        mov    r4, r1 
        ## if (data == 0) data = 0x100;
        cmp    r4, #0
        moveq  r4, #0x100
      
        ##  if ( t->period != period ) 
        ldr    r2, [r0, #Timer_period]
        cmp    r2, r4
        beq    TimerTargetDone

            ## if ( time >= t->next_time )
            ldr    r3, [r0, #Timer_next_time]
            cmp    SPC_Cycles, r3 
            blt    TimerTargetPeriod
                ## t = run_timer_( t, time );
                mov    r1, r0
                mov    r0, SPCAddr
                mov    r2, SPC_Cycles
                bl   _ZN8SNES_SPC10run_timer_EPNS_5TimerEi

            TimerTargetPeriod: 
            ##  t->period = period; 
            str    r4, [r0, #Timer_period]

        TimerTargetDone:
        ldmfd  sp!, {r2, r3, r4, r12, lr}
        ldmfd  sp!, {pc}

    SetControl:

        stmfd  sp!, {r2, r3, r4, r12, lr}

        mov    r4, r1
        mov    r0, #0
	
        tst    r4, #0x10
        strneb r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 4)]
        strneb r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 5)]

        tst    r4, #0x20
        strneb r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 6)]
        strneb r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 7)]

        ## Timer* t = &m.timers [0]; 
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 0))
        and    r1, r4, #1
        ldr    r2, [r0, #Timer_enabled]

        ## if ( t->enabled != enabled )
        cmp    r2, r1
        beq    SkipTimer0

            ## if ( time >= t->next_time )
            ldr    r3, [r0, #Timer_next_time]
            cmp    SPC_Cycles, r3 
                ## t = run_timer_( t, time );
                movge  r1, r0
                movge  r0, SPCAddr
                movge  r2, SPC_Cycles
                blge    _ZN8SNES_SPC10run_timer_EPNS_5TimerEi
                ldrge  SPCAddr, =spc

            ands   r1, r4, #1
            str    r1, [r0, #Timer_enabled]

            ## if ( enabled )
            movne  r1, #0
            strne  r1, [r0, #Timer_divider]
            strne  r1, [r0, #Timer_counter]

	SkipTimer0:

        ## Timer* t = &m.timers [1]; 
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 1))
        and    r1, r4, #2
        ldr    r2, [r0, #Timer_enabled]

        ## if ( t->enabled != enabled )
        cmp    r2, r1
        beq    SkipTimer1

            ## if ( time >= t->next_time )
            ldr    r3, [r0, #Timer_next_time]
            cmp    SPC_Cycles, r3
                ## t = run_timer_( t, time );
                movge  r1, r0
                movge  r0, SPCAddr
                movge  r2, SPC_Cycles
                blge   _ZN8SNES_SPC10run_timer_EPNS_5TimerEi
                ldrge  SPCAddr, =spc

            ands   r1, r4, #2
            str    r1, [r0, #Timer_enabled]

            ## if ( enabled )
            movne  r1, #0
            strne  r1, [r0, #Timer_divider]
            strne  r1, [r0, #Timer_counter]

	SkipTimer1:

        ## Timer* t = &m.timers [2]; 
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 2))
        and    r1, r4, #4
        ldr    r2, [r0, #Timer_enabled]

        ## if ( t->enabled != enabled )
        cmp    r2, r1
        beq    SkipTimer2

            ## if ( time >= t->next_time )
            ldr    r3, [r0, #Timer_next_time]
            cmp    SPC_Cycles, r3 
                ## t = run_timer_( t, time );
                movge  r1, r0
                movge  r0, SPCAddr
                movge  r2, SPC_Cycles
                blge   _ZN8SNES_SPC10run_timer_EPNS_5TimerEi
                ldrge  SPCAddr, =spc

            ands   r1, r4, #4
            str    r1, [r0, #Timer_enabled]

            ## if ( enabled )
            movne  r1, #0
            strne  r1, [r0, #Timer_divider]
            strne  r1, [r0, #Timer_counter]

	SkipTimer2:

        ## enable_rom( data & 0x80 );
        and    r1, r4, #0x80
        mov    r0, SPCAddr
        bl     _ZN8SNES_SPC10enable_romEi

        ldmfd  sp!, {r2, r3, r4, r12, lr}
        ldmfd  sp!, {pc}
.endm

read_smp_reg:

    and   r1, r0, #0xF
    # Jump to the wrapping mode. Each case code size is 4 operations
    ## switch (addr)
    add    pc, pc, r1, lsl #4
    nop
        ## case 0xf0:  // -w TEST
        mov r0, #0
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf1: // w CONTROL
        mov r0, #0
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf2:  // rw DSPADDR
        ## return m.smp_regs[0][r_dspaddr]
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + 2)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf3:  // rw DSPDATA
        ## return dsp_read
        b DspRead
	nop
	nop
	nop

        ## case 0xf4:  // r- CPUI0
        ## return m.smp_regs [1][4]
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 4)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf5:  // r- CPUI1
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 5)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf6:  // r- CPUI2
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 6)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf7:  // r- CPUI3
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 7)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf8:  // rw - Normal RAM
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 8)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xf9:  // rw - Normal RAM
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 9)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xfa:  // -w T0TARGET
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 10)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xfb:  // -w T1TARGET
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 11)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xfc:  // -w T2TARGET
        ldrb   r0, [SPCAddr, #(SPC_smp_regs + SPC_smp_regs_count + 12)]
        ldmfd  sp!, {pc}
        nop
        nop

        ## case 0xfd:  // r- T0OUT
        ##  Timer* t = &m.timers[0]; 
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 0))
        b      GetAndZeroTimer
        nop
        nop

        ## case 0xfe:  // r- T1OUT
        ##  Timer* t = &m.timers[1]; 
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 1))
        b    GetAndZeroTimer
        nop
        nop

        ## case 0xff:  // r- T2OUT
        ##  Timer* t = &m.timers[2]; 
        add    r0, SPCAddr, #(SPC_timers + (Timer_size * 2))
        b    GetAndZeroTimer
        nop
        nop

        GetAndZeroTimer:
        ## if ( time >= t->next_time )
	ldr    r1, [r0, #Timer_next_time]
        cmp    SPC_Cycles, r1
        blt    TimerOutRun
            ## t = run_timer_( t, time );
            stmfd  sp!, {r2, r3, r12, lr}
            mov    r1, r0
            mov    r0, SPCAddr
            mov    r2, SPC_Cycles
            bl     _ZN8SNES_SPC10run_timer_EPNS_5TimerEi
            ldmfd  sp!, {r2, r3, r12, lr}

        TimerOutRun:

        ## result = t->counter;
        ## t->counter = 0;
        add    r0, r0, #Timer_counter
        mov    r1, #0
	swp    r1, r1, [r0]
	mov    r0, r1

        ## return
        ldmfd  sp!, {pc}

        ## Call SNES_SPC::dsp_read
        DspRead:

        stmfd   sp!, {r2, r3, r12, lr}
        mov     r0, SPCAddr
        mov     r1, SPC_Cycles
        bl      _ZN8SNES_SPC8dsp_readEi
        ldmfd   sp!, {r2, r3, r12, lr}
        ldmfd   sp!, {pc}


# IN : r0 - address, r1 - byte
# DESTROYED - r0, r1
cpu_write:

    ## m.ram.ram[addr] = data;
    strb   r1, [SPC_RAM, r0]

    ## if ( addr >= 0xf0 && addr <= 0xff )
    sub    r0, r0, #0xF0
    cmp    r0, #0x0F
        bls    CPU_WRITE_REGS

    ## else if (addr > 0xfe00)
    sub    r0, r0, #0xfe00
    subs   r0, #0xd0
        ldmltfd   sp!, {pc}

	##  m.hi_ram[reg] = data;
        add    SPC_RAM, SPCAddr, #SPC_hi_ram
        strb   r1, [SPC_RAM, r0]
        add    SPC_RAM, SPCAddr, #SPC_Ram

	## if ( m.rom_enabled )
        ldr    r1, [SPCAddr, #(SPC_rom_enabled)]
	cmp    r1, #0
        ldmeqfd   sp!, {pc}

        ## (m.ram.ram) [reg + rom_addr] = m.rom [reg];       
        add    r1, SPCAddr, #SPC_rom 
        ldrb   r1, [r1, r0]

        add    r0, #0xff00
        add    r0, r0, #0xc0
        strb   r1, [SPC_RAM, r0]

        ldmfd  sp!, {pc}

    ## else
    CPU_WRITE_REGS:
    ## return (write_smp_reg(addr & 0xff));
        write_smp_reg


# IN : r0 - address, r1 - byte
# DESTROYED - r0, r1
cpu_write_dp:

    and    r0, r0, #0xff

    tst    SPC_YAPX, #(DirectPage << 8)
    addne  r0, r0, #0x100

    ## m.ram.ram[addr] = data;
    strb   r1, [SPC_RAM, r0]

    ## if ( addr >= 0xf0 && addr <= 0xff )
    sub    r0, r0, #0xF0
    cmp    r0, #0x0F
        bls    CPU_WRITE_REGS
    ldmfd  sp!, {pc}
