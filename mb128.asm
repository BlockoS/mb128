;;---------------------------------------------------------------------
; Constants.
;;---------------------------------------------------------------------
; Number of bytes per sector.
MB128_SECTOR_SIZE=$200

; Maximum number of sectors.
MB128_SECTOR_COUNT=$100

; Number of bytes per entry.
MB128_ENTRY_SIZE=$10

; Maximum number of entries.
MB128_ENTRY_COUNT=$40

; Detection retry count at boot (0 = 256) 
MB128_BOOT_RETRY_COUNT=8

;;---------------------------------------------------------------------
; Default header.
;;---------------------------------------------------------------------
mb128_default_header:
	.db $30,$06,$00,$00
;;---------------------------------------------------------------------
; Header string.
;;---------------------------------------------------------------------
mb128_string:
	.db $d2,$d3,$d8,$cd,$de,$b0,$bd,$31,$32,$38,$00,$00

;;---------------------------------------------------------------------
; Entry offsets.
;;---------------------------------------------------------------------
mb128_entry_off.lo:
	.dwl $0000, $0010, $0020, $0030, $0040, $0050, $0060, $0070
	.dwl $0080, $0090, $00A0, $00B0, $00C0, $00D0, $00E0, $00F0
	.dwl $0100, $0110, $0120, $0130, $0140, $0150, $0160, $0170
	.dwl $0180, $0190, $01A0, $01B0, $01C0, $01D0, $01E0, $01F0
	.dwl $0200, $0210, $0220, $0230, $0240, $0250, $0260, $0270
	.dwl $0280, $0290, $02A0, $02B0, $02C0, $02D0, $02E0, $02F0
	.dwl $0300, $0310, $0320, $0330, $0340, $0350, $0360, $0370
	.dwl $0380, $0390, $03A0, $03B0, $03C0, $03D0, $03E0, $03F0
mb128_entry_off.hi:
	.dwh $0000, $0010, $0020, $0030, $0040, $0050, $0060, $0070
	.dwh $0080, $0090, $00A0, $00B0, $00C0, $00D0, $00E0, $00F0
	.dwh $0100, $0110, $0120, $0130, $0140, $0150, $0160, $0170
	.dwh $0180, $0190, $01A0, $01B0, $01C0, $01D0, $01E0, $01F0
	.dwh $0200, $0210, $0220, $0230, $0240, $0250, $0260, $0270
	.dwh $0280, $0290, $02A0, $02B0, $02C0, $02D0, $02E0, $02F0
	.dwh $0300, $0310, $0320, $0330, $0340, $0350, $0360, $0370
	.dwh $0380, $0390, $03A0, $03B0, $03C0, $03D0, $03E0, $03F0

;;---------------------------------------------------------------------
; Error values.
;;---------------------------------------------------------------------
; [todo]

;;---------------------------------------------------------------------
; Write a single bit to memory base 128.
; in  : A Bit to send.
; out :
;;---------------------------------------------------------------------
mb128_send_bit:
	and #$01
	sta joyport
	pha
	pla
	nop
	ora #$02
	sta joyport
	pha
	pla
	pha
	pla
	pha
	pla
	and #$01
	sta joyport
	pha
	pla
	nop
	rts
;;---------------------------------------------------------------------
; Write a single byte to memory base 128.
; in  : A Byte to send.
; out :
; use : _al
;;---------------------------------------------------------------------
mb128_send_byte:
	phx
	ldx #$08
	sta <_al
.loop:
	lsr <_al
	cla
	rol A
	sta joyport
	pha
	pla
	nop
	ora #$02
	sta joyport
	pha
	pla
	pha
	pla
	pha
	pla
	and #$01
	sta joyport
	pha
	pla
	nop
	dex
	bne .loop
	plx
	rts
;;---------------------------------------------------------------------
; Read a single bit from memory base 128.
; in  :
; out : A bit read.
;;---------------------------------------------------------------------
mb128_read_bit:
	stz joyport
	pha
	pla
	nop
	lda #$02
	sta joyport
	pha
	pla
	nop
	lda joyport
	stz joyport
	pha
	pla
	and #$01
	rts
;;---------------------------------------------------------------------
; Read a single byte from memory base 128.
; in  :
; out : A Byte read.
; use : _al
;;---------------------------------------------------------------------
mb128_read_byte:
	phx
	stz <_al
	ldx #$08
.loop:
	stz joyport
	pha
	pla
	nop
	lda #$02
	sta joyport
	pha
	pla
	nop
	lda joyport
	lsr A
	ror <_al
	sta joyport
	pha
	pla
	nop
	dex
	bne .loop
	plx
	lda <_al
	rts
;;---------------------------------------------------------------------
; Detect if a memory base 128 is present.
; in  :
; out : A $ff if detection failed, $00 if a memory base 128 was 
;         succesfully detected.
; use : _dl, _al
;;---------------------------------------------------------------------
mb128_detect:
	phx
	ldx #$03
.loop:
	lda #$a8
	jsr mb128_send_byte
	cla
	jsr mb128_send_bit
	lda joyport
	asl A
	asl A
	asl A
	asl A
	sta <_dl
	lda #$01
	jsr mb128_send_bit
	lda joyport
	and #$0f
	ora <_dl
	cmp #$04
	beq .found
	dex
	bne .loop
.not_found:
	lda #$ff
	plx
	rts	
.found:
	cla
	plx
	rts
;;---------------------------------------------------------------------
; Detect and reset Memory Base 128 states.
; in  :
; out : A $ff if detection failed, $00 if a memory base 128 was 
;         succesfully detected.
; use : _al, _dl
;;---------------------------------------------------------------------
mb128_boot:
	phx
	phy
	ldx #MB128_BOOT_RETRY_COUNT
.retry:
		jsr mb128_detect
		cmp #$00
		beq .init
		dex
		bne .retry
.fail:
	lda #$ff
	ply
	plx
	rts
.init:
	lda #$01
	jsr mb128_send_bit

	cla
	jsr mb128_send_bit
	jsr mb128_send_bit
	jsr mb128_send_byte

	lda #$01
	jsr mb128_send_byte
	cla
	jsr mb128_send_byte

	cla
	jsr mb128_send_bit
	jsr mb128_send_bit
	jsr mb128_send_bit
	jsr mb128_send_bit
	
	jsr mb128_read_bit

	cla
	jsr mb128_send_bit
	jsr mb128_send_bit
	jsr mb128_send_bit
.success:
	cla
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Set internal memory base 128 address to the specified sector.
; in  : _bl Sector number
;         A 1 for read and 0 write
; out :
; use : _al
;;---------------------------------------------------------------------
mb128_sector_addr:
	jsr mb128_send_bit

	cla
	jsr mb128_send_bit
	jsr mb128_send_bit
	lda <_bl
	jsr mb128_send_byte

	cla
	jsr mb128_send_byte
	lda #$10
	jsr mb128_send_byte

	cla
	jsr mb128_send_bit
	jsr mb128_send_bit
	jsr mb128_send_bit
	jsr mb128_send_bit
	rts
;;---------------------------------------------------------------------
; Write data from source buffer to the specified memory base 128 
; sectors.
; in  : _bl Sector number
;       _bh Sector count
;       _si Source pointer
; out : _cx CRC   
;         A $ff if an error occured, $00 upon success.
; use : _al, _dl
;;---------------------------------------------------------------------
mb128_write_sectors:
	phx
	phy
	stz <_cx
	stz <_cx+1
.write_next_sector:
		; Write a sector
		jsr mb128_detect
		cmp #$00
		bne .error
        cla
		jsr mb128_sector_addr	
		ldx #$02
.write_next_256:
			cly
.write_next_byte:
				lda [_si], Y
				jsr mb128_send_byte
				iny
				bne .write_next_byte
			inc <_si+1
			dex
			bne .write_next_256
		
		; Rewind source buffer	
		dec <_si+1
		dec <_si+1
		
		; Compare read data with source
		jsr mb128_detect
		cmp #$00
		bne .error
        lda #$01
		jsr mb128_sector_addr
		ldx #$02
.check_next_256:
			cly
.check_next_byte:
				jsr mb128_read_byte
				cmp [_si], Y
				bne .error
				clc
				adc <_cl
				sta <_cl
				bcc .inc0
				inc <_ch
.inc0:
				iny
				bne .check_next_byte
			inc <_si+1
			dex
			bne .check_next_256	
	inc <_bl
	dec <_bh
	bne .write_next_sector
.ok:
	cla
	ply
	plx
	rts
.error:
	lda #$ff
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Fill specified memory base 128 sectors with 0 (untested).
; in  : _bl Sector id
;       _bh Sector count
; out :   A $ff if an error occured, $00 upon success.
; use : _al, _dl
;;---------------------------------------------------------------------
mb128_clear_sectors:
	phx
	phy
.clear_next_sector:
		; Write a sector
		jsr mb128_detect
		cmp #$00
		bne .error
        cla
		jsr mb128_sector_addr	
		ldx #$02
.clear_next_256:
			cly
.clear_next_byte:
				cla
				jsr mb128_send_byte
				iny
				bne .clear_next_byte
			inc <_si+1
			dex
			bne .clear_next_256
		
		; Check data
		jsr mb128_detect
		cmp #$00
		bne .error
        lda #$01
		jsr mb128_sector_addr
		ldx #$02
.check_next_256:
			cly
.check_next_byte:
				jsr mb128_read_byte
				cmp #$00
				bne .error
				iny
				bne .check_next_byte
			inc <_si+1
			dex
			bne .check_next_256	
	inc <_bl
	dec <_bh
	bne .clear_next_sector
.ok:
	cla
	ply
	plx
	rts
.error:
	lda #$ff
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Read data from specified memory base 128 sectors and store it to the
; destination buffer.
; in  : _bl Sector id
;       _bh Sector count
;       _di Destination pointer
; out : _cx CRC   
;         A $ff if an error occured, $00 upon success.
; use : _al, _dl
;;---------------------------------------------------------------------
mb128_read_sectors:
	phx
	phy
	stz <_cl
	stz <_ch
.read_next_sector:
		jsr mb128_detect
		cmp #$00
		bne .error
        lda #$01
		jsr mb128_sector_addr	
		ldx #$02
.read_next_256:
			cly
.read_next_byte:
				jsr mb128_read_byte
				sta [_di], Y
				; CRC is just the sum of all bytes
				clc
				adc <_cl
				sta <_cl
				bcc .l0
				inc <_ch
.l0:
				iny
				bne .read_next_byte
			inc <_di+1
			dex
			bne .read_next_256
		inc <_bl
		dec <_bh
		bne .read_next_sector
.ok:
	cla
	ply
	plx
	rts
.error:
	lda #$ff
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Read memory base 128 first sector header.
; in  : _di Pointer to destination buffer containing the first sector.
; out :   A $ff if an error occured. $00 upon success.
; use : _ax, _bx, _cx, _dl, _si
;;---------------------------------------------------------------------
mb128_read_header:
	phx
	phy

	stz <_bl
	lda #$02
	sta <_bh
	jsr mb128_read_sectors
	cmp #$00
	bne .error
	; The first 2 bytes of the sectors is the sum of all sector bytes
	; minus the first 2 bytes.
	; In order to perform a valid check we must first substract them
	; from the CRC computed by mb128_read_sectors.
	lda [_di]
	sta <_al
	ldy #$01
	lda [_di],Y
	sta <_ah
	; Substract first byte.
	sec
	lda <_cl
	sbc <_al
	sta <_cl
	bcs .l0
	dec <_ch
.l0:
	; Substract second byte.
	sec
	lda <_cl
	sbc <_ah
	sta <_cl
	bcs .l1
	dec <_ch
.l1:
	; Now compare with the first 2 bytes.
	cmp <_al
	bne .error
	cmp <_ah
	bne .error
	; Check header string.
	clc
	lda <_di
	adc #$04
	sta <_di
	bcc .l2	
		inc <_di+1
.l2:
	lda #low(mb128_string)
	sta <_si
	lda #high(mb128_string)
	sta <_si+1
	cly
.l3:
		lda [_si], Y
		cmp [_di], Y
		bne .error
		iny
		cpy #$0a
		bne .l3
	cla
	ply
	plx
	rts
.error:
	lda #$ff
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Compute header CRC (untested).
; in  : _si Address of the first sector buffer.
; out : _cx CRC
;;---------------------------------------------------------------------
mb128_compute_header_CRC:
	phx
	phy
	
	ldx #$02
	ldy #$02
	stz <_cx
	stz <_cx+1
.update256:
.update:
			lda [_si], Y
			clc
			adc <_cx
			sta <_cx
			bcc .inc0
			inc <_cx+1
.inc0:
			iny
			bne .update
		inc <_si+1
		dex
		bne .update256
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Find the entry matching the specified entry name (untested).
; in  : _si Address of the first sector buffer
;       _ax Entry name
; out :   A $ff if the entry was not found or $00 upon success.
;       _bl Id of the last visited entry.
;       _si Address of the entry in sector buffer (if found)
;           or the address of the first empty entry (if not found)
; use : _cx 
;;---------------------------------------------------------------------
mb128_find_entry:
	phx
	phy
	clx
.loop:
		inx
		cpx #MB128_ENTRY_COUNT
		beq .not_found
		clc
		lda <_si
		adc #MB128_ENTRY_SIZE
		sta <_si
		bcc .l0
		inc <_si+1
.l0:
		lda [_si]
		beq .not_found
.check:
		clc
		; Jump to entry name
		lda <_si
		adc #$08
		sta <_cx
		lda <_si+1
		adc #$00
		sta <_cx+1
		cly
.check_loop:
		lda [_ax],Y
		cmp [_cx],Y
		; Check next entry if the name does not match
		bne .loop
		iny
		cpy #$08
		bne .check_loop
		; We found the entry
.found:
	cla
	stx <_bl
	ply
	plx
	rts
.not_found:
	stx <_bl
	lda #$ff
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Update/Create a new entry (unstested).
; in  : _si Address of the first sector buffer.
;       _di Address of the data buffer.
;       _ax Entry name.
;       _bh Number of sectors to allocate.
; out :   A $ff if an error occured. $00 upon success.
;       _bl Sector id.
; use : ?
;;---------------------------------------------------------------------
mb128_write_entry:
	phx
	phy
	
	; Save sector address.
	lda <_si
	sta <_bp
	lda <_si+1
	sta <_bp+1
	
	ldy #$01

	jsr mb128_find_entry
	cmp #$00
	bne .new_entry
.existing_entry:
		; Check if entry size matches requested size.
		lda [_si], Y
		cmp <_bh
		beq .ok
.size_mismatch:
			; [todo] error code
			lda #$ff
			ply
			plx
			rts
.ok:
		lda [_si]
		sta <_bl
		bra .copy_data 
.new_entry:
		lda <_bl
		cmp #MB128_ENTRY_COUNT
		beq .no_entry_left
		tax
		; Compute sector id
		ldy #$02
		lda [_bp], Y
		sta <_bl
		; Set entry sector id
		sta [_si]
		; Update total sector count
		clc
		adc <_bh
		sta [_bp], Y
		bcc .inc0
			iny
			lda [_bp], Y
			inc A
			sta [_bp], Y
.inc0:
		; Set entry sector count
		ldy #$01
		lda <_bh
		sta [_si], Y
		iny
		; Set dummy bytes
		cla
		sta [_si], Y
		iny
		lda #$02
		sta [_si], Y
		iny
		; Set entry name
		lda <_si
		clc
		adc #$08
		sta <_si
		lda <_si+1
		adc #$00
		sta <_si+1
		cly
.name:
			lda [_ax], Y
			sta [_si], Y
			iny
			cpy #$08
			bne .name
.copy_data:
		lda <_di
		sta <_si
		lda <_di+1
		sta <_si+1
		jsr mb128_write_sectors
		cmp #$00
		bne .write_error
		; Update entry CRC
		lda mb128_entry_off.lo, X
		clc
		adc <_bp
		sta <_si
		lda mb128_entry_off.hi, X
		adc <_bp+1
		sta <_si
		ldy #4
		lda <_cx
		sta [_si], Y
		iny
		lda <_cx+1
		sta [_si], Y
		; Update header CRC
		lda <_bp
		sta <_si
		lda <_bp+1
		sta <_si+1
		jsr mb128_compute_header_CRC
		lda <_cx
		sta [_bp]
		ldy #$01
		sta [_bp], Y
		ply
		plx
		rts
.error:
.write_error:
	; [todo] error code
.no_entry_left:
	; [todo] error code
	lda #$ff
	ply
	plx
	rts

;;---------------------------------------------------------------------
; Read entry (untested).
; in  : <_al Entry id.
;       <_si Address of the first sector buffer.
;       <_di Output buffer address.
; out :    A $ff if an error occured. $00 upon success.
;            (todo) empty entry, (todo) invalid CRC.
;       <_bl Sector id.
;       <_bh Sector count.
;;---------------------------------------------------------------------
mb128_read_entry:
	phx
	phy

	; Compute address
	ldx <_al
	lda <_si
	pha
	adc mb128_entry_off.lo, X 
	sta <_dx
	lda <_si+1
	pha
	adc mb128_entry_off.hi, X
	sta <_dx+1

	; Sector id.
	lda [_dx]
	beq .err
	sta <_bl
	; Sector count.
	ldy #$01
	lda [_dx], Y
	sta <_bh

	; Read data and compute CRC.
	jsr mb128_read_sectors
	cmp #$00
	beq .err

	; Check CRC against the one stored in entry info.
	ldy #$04
	lda [_dx], Y
	cmp <_cx
	bne .err
	iny
	lda [_dx], Y
	cmp <_cx+1
	bne .err
.ok:
	cla
	ply
	plx
	rts
.err:
	lda #$ff
	ply
	plx
	rts
;;---------------------------------------------------------------------
; Format header.
; in  : _si Address of the first sector buffer
; out :
; use : _di
;;---------------------------------------------------------------------
mb128_format:
	phx
	phy

	; Compute destination
	lda <_si
	clc
	adc #$01
	sta <_di
	lda <_si+1
	adc #$00
	sta <_di+1

	cla
	sta [_si]

	; Clear 
	tsx
	sxy
	lda #$60			; rts
	pha
	lda #high($400)		; length (hi)
	pha
	lda #low($400)		; length (lo)
	pha
	lda <_di+1			; destination (hi)
	pha
	lda <_di			; desination (lo)
	pha
	lda <_si+1			; source (hi)
	pha
	lda <_si			; source (lo)
	pha	
	lda #$73			; tii
	pha

	; Compute jump address
	tsx
	txa
	clc
	adc #low($2100)		; Stack address
	sta <_di
	lda #high($2100)
	adc #$00
	sta <_di+1
	jsr .format

	; Restore stack pointer
	sxy
	txs

	cly
.copy:
	lda mb128_default_header, Y
	sta [_si], Y
	iny
	cpy #MB128_ENTRY_SIZE
	bne .copy

	ply
	plx	
	rts
.format:
	jmp [_di]

; [todo] mb128_delete_entry

