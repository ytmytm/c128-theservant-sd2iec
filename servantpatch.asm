
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
// Patch changes behavior of QBB functions to use bank 3 as 64K QBB
// Patch changes behavior of option '9' - go 64 mode, Servant asks for confirmation: RETURN uses bank 1 (default), C=+RETURN uses bank 2
//
// Originally Servant recognized filetype by its first letter: 'C' for CBM (1581 partitions) or 'P' for PRG (load and run).
//
// Patch 1 makes Servant copy one letter more, so that we can determine filetype by second letter: 'B' for 1581 partition, 'R' for PRG and 'I for new DIR option
//         then it jumps to the new code (put into place where SERVANT.MOD was) to mimic original code, check for letter 'I' and issue command 'CD<name>' if it was 'DIR'
//
// Patch 2 changes the second letter values compared in the original code, from 'C' to 'B' and from 'P' to 'R'
//
// Patch 3 causes Servant to run command 'CD<leftarrow>' every time '/' is pressed to go up one level. It has no effect on 1541/71/81.
//         Then it jumps back to the original code.
// 
// Patches 4/5 replace QBB code by fake QBB that uses system RAM bank 3 (bank 1 on unexpanded C128)
// Patch 6 corrects bug in code that reads programs from genuine/fake QBB, it was there, unnoticed for 22 years
//
// Patch 7 allows to press RETURN ($0D) or C=+RETURN ($8D) after message for confirmation after choosing option '9' from menu; actual status saved in patch 11
//         it can't be CTRL+RETURN because that is mapped to keycode $00
//
// Patch 8 plugs into function that copies trampoline code into $0400 to choose correct bank itself (X register) and patch bytes $01 and $33 to correct control register values
// Patch 9 disables SHIFT+ and CTRL+ handler, leaves only '+' to reset prefs; this disables 'reset to default' function at $8440 so we have more space
//
// Patch 10 takes bank number for JSRFAR ($FF6E) from precomputed value in $06 (depends on status of CTRL)
//
// Patch 11 called at the common beginning of GO64 routine - check for C= key status (C= not CTRL because of patch 7) and set bank in $06 properly
//          choose bank 1 ($05==0, $06==1) when C= is released and bank 2 ($05==1, $06==2) when C= is pressed
//
// PatchConfig allows to reconfigure Servant settings (except strings assigned to function keys)


.print "Assembling SERVANT.BIN"
.print "Load into VICE with bank ram; l 'servant.bin' 0 8002; a 8000 nop nop"
.segmentdef Combined  [outBin="servant.bin", segments="Base,Patch1,Patch2,Patch3,Patch4,Patch5,Patch6,Patch7,Patch8,Patch9,Patch10,Patch11,MainPatch,PatchConfig,PatchVersion", allowOverlap]

.segment Base [start = $8000, max=$ffff]
// load binary image of ROM, created and configured by Servant, saved with CTRL+'+' combination OR dumped from an EPROM (32768 bytes)
	.var data = LoadBinary("servant.mod")
// ucomment this to load ROM image saved with loadaddress (32770 bytes)
//	.var data = LoadBinary("servant.prg", BF_C64FILE)
	.fill data.getSize(), data.get(i)

///////////////////////////////////// CONFIGURATION

.segment PatchConfig [min=$811b, max=$8122]
		.pc = $811b "Patch some configuration bytes"
		.byte $0d		// 40 col text color, default Kernal $0d, default Servant $00
		.byte $0b		// 40 col background color, default Kernal $0b, default Servant $07
		.byte $0b		// 40 col border, default Kernal $0d, default Servant $07
		.byte $0f		// 80 col text color, default $07 (light cyan)
		.byte $02		// 80 col background, default $00 (black)

		.byte 14		// 14=lowercase upon exit, 142=uppercase upon exit, default Servant 14

		.byte 10		// Servant key: 1-8=Fx key, 9=SHIFT+RUN/STOP, 10=HELP, default Servant 9

.segment PatchVersion [min=$ddef,max=$ddf3]
		.pc = $ddef "Patch version number"
		.text "4.85"

///////////////////////////////////// SD2IEC DIRECTORY BROWSING

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

///////////////////////////////////// BANK 3 AS QBB

.segment Patch4 [min=$8355, max=$837b]
		.pc = $8355 "Patch to read/write QBB as remapped stack from bank 3 (1/2)"
		// in X/Y - address in QBB (64K), $CE=X (lobyte) top of stack: A(store), above it Cflag
		sta $cf
		plp			// restore C
		php			// but keep I
		sei
		lda $ff00
		pha
		and #%11111110		// enable I/O
		sta $ff00
		lda $d506
		sta $ce
		and #%11110000		// disable bottom sharing
		sta $d506
		jmp QBB_2		// jump to the second part

.segment Patch5 [min=$87a7, max=$87c8]
		.pc = $87a7 "Patch to read/write QBB as remapped stack from bank 3 (2/2)"
QBB_2:

		lda $d509		// store p1l
		sta $05
		lda $d50a		// store p1h
		sta $06
		lda #%00000011		// p1h first, bank 3 (or 1 on stock)
		sta $d50a
		sty $d509		// p1l second

		bcs @load
		lda $cf
		sta $0100,x
@load:		lda $0100,x
		tax
		lda $ce
		jmp QBB_3

.segment Patch6 [min=$8f7e, max=$8f86]
		.pc = $8f7e "Patch to fix a bug in loading data from QBB (compare end to C1/C2, not BF/C0)"
		cmp $c2
		bcc $8f6A
		lda $c3
		cmp $c1

///////////////////////////////////// BANK 2 AS OPTIONAL Go64 TARGET

.segment Patch7 [min=$816e, max=$8170]
		.pc = $816e "Patch to accept <RETURN> ($0D) as well as C=+<RETURN) ($8D)"
		jsr WaitForReturn

.segment Patch8 [min=$854d, max=$8551]
		.pc = $854d "Patch to choose bank for GO64"
		ldx $06
		jsr GO64GetByte

.segment Patch9 [min=$83f1, max=$83ff]
		.pc = $83f1 "Patch + handler, drop default colors, only reset prefs"
		jsr $8400	// setup screen colors
		jmp $818d	// return to loop
		// $8453 is never called
		// $8440 is never called

GO64StoreFlags2:
		sta $05		// C= flag: =0 (bank 1) / <>0 (bank 2) flag
		sta $06
		inc $06		// bank number: 1 or 2
		rts

.segment Patch10 [min=$855f, max=$8560]
		.pc = $855f "Patch to take bank number from C= flag status before GO64"
		lda $06		// we could keep it in $02 already, but there is no space saving in that anyway

.segment Patch11 [min=$853e, max=$8541]
		.pc = $853e "Patch to set bank number in $06 to 1 or 2"
		jsr GO64StoreFlags
		nop

///////////////////////////////////// COMMON PATCH AREA REPLACES DEFAULT COLOR SET AND SERVANT.MOD SAVER

.segment MainPatch [min=$8440,max=$84b6]

		.pc = $8440 "Patch saving SERVANT.MOD"

// 8440 = set default colors
// 8453 = save servant.mod

WaitForReturn:
		jsr $a2fa
		and #%01111111
		rts

GO64GetByte:
		cpy #$01		// is this byte $01 LDA #$7E <- memconfig $FF00
		beq @ff00
		cpy #$33		// is this byte $33 LDA #$40 <- bank for VIC
		bne @ret		// not, return original byte
		lda vicBankNumbers-1,x
		rts
@ff00:		lda bankNumbers-1,x
		rts
@ret:		lda $88df,y
		rts

bankNumbers:	.byte %01111110		// bank 1
		.byte %10111110		// bank 2
vicBankNumbers:	.byte %01000000		// bank 1
		.byte %10000000		// bank 2

GO64StoreFlags:
		lda $d3			// preserve C=/CTRL/ALT flags in $05
		and #%00000010		// keep only C= flag to choose bank 2 instead of 1
		lsr
		jsr GO64StoreFlags2
		lda #$00		// original code from $853e
		sta $24
		rts

QBB_3:

		sta $d506
		lda $06
		sta $d50a		// p1h first
		lda $05
		sta $d509		// p1l second
		pla
		sta $ff00
		plp			// restore I
		txa
		clc			// original routine clears C
		rts



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
