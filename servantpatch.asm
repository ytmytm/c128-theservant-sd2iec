
// Patch The Servant 4.83 to walk through SD2IEC folders
// by Maciej 'YTM/Elysium' Witkowiak <ytm@elysium.pl>, 2024-02-12

// INFO
//
// 0. Quickstart: flash provided SERVANT.BIN - this is patched provided SERVANT.MOD
//
// 1. Configure Servant (colors, keyboard shortcuts etc.) using original Servant release disks (provided) or from your ROM dump
//
// 2. Save it as SERVANT.MOD (it must have exactly 32768 bytes, no load address) to replace the file provided here.
//
// 3. Then run patch code with KickAss to patch SERVANT.MOD and get SERVANT.BIN
//    java -jar KickAss.jar servantpatch.asm
//
// 4. Flash SERVANT.BIN to a 32K EEPROM and put it into U36 socket
//
// 4. Test if everything works with new chip - can you enter (<RETURN>) and exit (/) directories on SD2IEC?
//
// 5. Make D64/D71/D81 files appear as directories on SD2IEC: run command XI1 or XI2 and save config with XW - this way you will be able to enter also disk images.
//
// Patch uses area used to save configured SERVANT.MOD (CTRL+'+' when Servant runs from RAM).

// IDEA
// Patch changes behavior of option '4' - directory listing - to enter/exit subfolders also on SD2IEC ('DIR' files)
//
// Originally Servant recognized filetype by its first letter: 'C' for CBM (1581 partitions) or 'P' for PRG (load and run).
//
// Patch 1 makes Servant copy one letter more, so that we can determine filetype by second letter: 'B' for 1581 partition, 'R' for PRG and 'I for new DIR option
//         then it jumps to the new code (put into place where SERVANT.MOD was) to mimic original code, check for letter 'I' and issue command 'CD<name>' if it was 'DIR'
//
// Patch 2 changes the second letter values compared in the original code, from 'C' to 'B' and from 'P' to 'R'
//
// Patch 3 casues Servant to run command 'CD<leftarrow>' every time '/' is pressed to go up one level. It has no effect on 1541/71/81.
//         Then it jumps back to the original code.
// 

.print "Assembling SERVANT.BIN"
.print "Load into VICE with bank ram; l 'servant.bin' 0 8002; a 8000 nop nop"
.segmentdef Combined  [outBin="servant.bin", segments="Base,Patch1,Patch2,Patch3,MainPatch", allowOverlap]

.segment Base [start = $8000, max=$ffff]
// load binary image of ROM, created and configured by Servant, saved with CTRL+'+' combination OR dumped from an EPROM (32768 bytes)
	.var data = LoadBinary("servant.mod")
// ucomment this to load ROM image saved with loadaddress (32770 bytes)
//	.var data = LoadBinary("servant.prg", BF_C64FILE)
	.fill data.getSize(), data.get(i)

/////////////////////////////////////

.segment Patch1 []
		.pc = $8D7A "Patch to copy one character more"
		cpx #$16		// originally $15
		bne $8d69
		jmp CheckFileType	// 8d7e/7f/80
Patch1Back:				// 8d81

.segment Patch2 []
		.pc = $8D88 "Patch to check for P(R)G or C(B)M, D(I)R already checked"
Patch2Cont:
		cmp #'R'		// P'R'G
		beq $8daf
		cmp #'B'		// C'B'M

.segment Patch3 []
		.pc = $99E5 "Patch to go up/root dir"
		jsr GoToRoot

/////////////////////////////////////

.segment MainPatch [min=$8453,max=$84b6]

		.pc = $8453 "Patch saving SERVANT.MOD"

		jmp $818D		// someone pressed CTRL++, but skip over this code

CheckFileType:
		plp
		bcc @cont
		lda $0201+$14		// original filetype 1st byte in case this routine was called with C=1 (don't know when/why)
		jmp Patch1Back		// 8d81
@cont:		cmp #'I'		// D'I'R
		beq @havedir
		jmp Patch2Cont		// 8d88, continue checking for PRG/CBM
@havedir:
		jsr $817b		// 8d90, copy that
		jsr $9a0d		// 8d93, copy that
		lda #'D'
		sta $0202
		lda #'C'		// CD<name>, name already is in $0203
		jmp $8d98		// continue: sta $0201 + send command

GoToRoot:
		lda #3			// CD<-
		ldx #<cmd_cdup
		ldy #>cmd_cdup
		jsr $9829		// send command
		jsr $98da		// close all files
		jmp $9fb1		// original code from 99E5: detect drive type, return with Y=6 for 1581

cmd_cdup:	.byte 'C','D',$5F
