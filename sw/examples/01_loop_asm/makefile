##################################################################################################
# MaRVin - RISC-V SoC                                                                             
# loop_asm Makefile                                                                               
#                                                                                                
# riscv-gcc for windows from:
# https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/tag/v14.2.0-3
#
# gnu tools for windows from:
# https://github.com/skeeto/w64devkit/releases/tag/v2.1.0          
# 
##################################################################################################

APP_NAME = loop_asm
RISCV_PREFIX = riscv-none-elf-
MARVIN_PATH = ../../..
LSCRIPT = marvin.ld
LSCRIPT_PATH = $(MARVIN_PATH)/sw/linkers/$(LSCRIPT)
BIN2HEX = python $(MARVIN_PATH)/sw/tools/bin2hex.py

APP_ELF  = $(APP_NAME).elf
APP_BIN  = $(APP_NAME).bin
APP_HEX  = $(APP_NAME).hex
SOURCES = $(wildcard ./*.c) $(wildcard ./*.s) $(wildcard ./*.cpp) $(wildcard ./*.S)
# Generates object list based on the sources
OBJS = $(SOURCES:%=%.o)	

# RISC-V utils
CC = $(RISCV_PREFIX)gcc
SIZE    = $(RISCV_PREFIX)size
OBJDUMP = $(RISCV_PREFIX)objdump 
OBJCOPY = $(RISCV_PREFIX)objcopy

# Assembler Flags
ASFLAGS  = -march=rv32i
ASFLAGS += -mabi=ilp32
ASFLAGS += -mstrict-align
ASFLAGS += -g

# C Flags
CFLAGS  = -march=rv32i
CFLAGS += -mabi=ilp32
CFLAGS += -Wall -g
CFLAGS += -Os				   # Optimize for smaller size
CFLAGS += -mstrict-align
CFLAGS +=  -mbranch-cost=10
CFLAGS += -ffunction-sections  # each function goes into its own section in the object file
CFLAGS += -fdata-sections      # applies the same logic to data, placing each global variable in its own section
CFLAGS += -Wl,--gc-sections    # removes unreferenced sections
CFLAGS += -nostartfiles        # do not include the default startup files (default crt0)
CFLAGS += -mno-fdiv  		   # do not use hardware floating-point division instructions
LDFLAGS = -nostdlib 	       # do not load the standard library (do not automatically link standard libraries)
#LDLIBS  = -lc				   # C standard library (libc), containing essential C functions such as printf(), malloc(), exit(), etc.
#LDLIBS  += -lm 			   # libm: sin(), cos(), sqrt() and others
#LDLIBS  += -lgcc			   # GCC support library (libgcc)

.PHONY: all hex clean

all: hex

hex: $(APP_HEX)

clean:
	@rm -rf *.elf *.o *.bin *.out *.hex .gdb_history

# Assembles all assembly source files
%.S.o: %.S
	$(CC) -c $(ASFLAGS) $< -o $@

# % = file name, $< : first prerequisite of the rule (the .s file), $@ : target name (includes .s.o)
%.s.o: %.s
	$(CC) -c $(ASFLAGS) $< -o $@

# Links the object files into an ELF binary and generates a disassembly dump
$(APP_ELF): $(OBJS)
	$(CC) -T $(LSCRIPT_PATH) $(LDFLAGS) $(OBJS) $(LDLIBS) -o $@ 
	$(OBJDUMP) -d -S -z  $(APP_ELF) 
	@echo "Memory utilization:"
	@$(SIZE) $(APP_ELF)

# Generates a raw binary from the ELF
# -j .text   : executable code
# -j .rodata : read-only data (constants, string literals)
# -j .data   : initialized global/static variables (non-zero at reset)
# objcopy concatenates the selected sections in address (LMA) order, as laid out by the linker script
$(APP_BIN): $(APP_ELF)
	@$(OBJCOPY) -I elf32-little -O binary -j .text -j .rodata -j .data $< $@

# Generates an ASCII Hex file from the binary ($< with .bin swapped for .hex)
$(APP_HEX): $(APP_BIN)
	@$(BIN2HEX) $<