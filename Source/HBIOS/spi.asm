; 
; spi abstraction - this is a little more complex than it needs to be, because
; I want to avoid too many buffer copies
; central to SPI is the idea that send and receive are done at the same time, and
; that we shift out commands and data, and shift in data and status, and these
; regions in the 2 data streams are defined by the specific command.  further, it
; isn't something that the protocol codifies, but it is codified by the device.
;
; SPI is byte-oriented, so all of the counts are bytes.
;
; so, I define an spi transfer descriptor which says what regions of MOSI and MISO
; go where, and the low level bit shifter will put the right bytes where I want them.
; there are 2 descriptors for each SPI transfer, which are an array terminated by a SP_F_END
;
; we clock data with the CS on until the output descriptor is exhausted. 
;
; struct spi_segment {
;     unsigned short length;
;     unsigned short address;
;     unsigned char flags;
; #define SPI_F_DELAY	0x01	// wait length microseconds (output only)
; #define SPI_F_DATA	0x02	// actually transfer data
; #define SPI_F_END     0x04    // end segment
; }
;
; in particular, the SD card SPI protocol has all kinds of sillyness like status and CRC
; in strange places in time, so we need to have a means for skipping noise regions in MISO and null
; regions in MOSI
; 
; this architecture can be implemented in a smart controller like the propeller by using the length
; fields as passed, and swizzling the address fields to point to local memory.  then, the only thing
; that actually passes over the wire is the payloads (length for segments where SPI_F_DATA is set)
;
; SPI_XFER
; B = 0x50
; C = device id
; DE = data in segment list
; HL = data out segment list

SPI_XFER:
#if (SPI_PPP)
	call PPP_SPI
	ret
#endif
#if (SPI_LOCAL)
	exx				; save alternate register set
	push	bc
	push	de
	push	hl
	exx
	push ix			; save ix, iy
	push iy

	push de
	pop	 ix			; ix = data in descriptor
	push hl
	pop  iy			; iy = data out descriptor

	;
	; read descriptors into register pairs
	;
	call load_out
	exx
	call load_in
	exx

	call	spi_select

;
; register usage:
; ix is data in descriptor
; iy is data out descriptor
; de is send count,  de' is recv count
; hl is send buffer, hl' is recv buffer
;
spi_next:

	;
	; implement delay operator
	;
	bit  0, (iy+4)  ; delay?
    jr   z, notdelay
	ld	c, (iy+0)	; get count low
doloop:
	ld	b,255
dloop:
	djnz	dloop
	dec	c
	jr nz, doloop
	jr nextout

notdelay:

	ld	a,0
	bit 1, (iy+4)	; have out data
	jr	z,no_out
	ld	a,(hl)
	inc hl
no_out:

	call spi_shift

	exx
	bit	 1, (ix+4)	; store in?
	jr	z,no_in
	ld	(hl),a
	inc	hl
no_in:
	dec de
	ld  a,d
	or  e
	call z,next_in
	exx

	dec	de
	ld  a,d
	or  e
	jr	nz, spi_next

	call next_out
	jr	z, spi_next

done:
	call	spi_deselect

	pop iy			; restore trashed registers
	pop ix
	exx
	pop		hl
	pop		de
	pop		bc
	exx
	ret

;
; go to the next output descriptor - this is called when de is 0.
; return nz if end of list and done
;
next_out:
	bit 2,(iy+4)	; if end marker, don't bump
	ret nz

	ld bc,5
	add iy,bc
load_out:
	ld	e,(iy+0)
	ld	d,(iy+1)
	ld	l,(iy+2)
	ld	h,(iy+3)
	xor	a
	ret
;
; go to the next input descriptor - this is called when de' is 0.
; called with alternate set selected
;
next_in:
	bit 2,(ix+4)	; if end marker, don't bump
	ret nz

	ld bc,5
	add ix,bc
load_in:
	ld	e,(ix+0)
	ld	d,(ix+1)
	ld	l,(ix+2)
	ld	h,(ix+3)
	ret

;
; select device in C
;
spi_select:
	ret

;
; deselect device in C
;
spi_deselect:
	ret

;
; bit banger shift 1 byte to SPI
; send byte in A, get byte to A
; destroys c
;
spi_shift:
	ld	b,8
	ld	c,a
ssl:
	ld  a,c		; shift out low bit of c
	and 1		;
	out a,(SPI_DATA)
	out a,(SPI_CLOCK_SET)
	in  a,(SPI_DATA)
	and 1		;
	out a,(SPI_CLOCK_CLEAR)
	rrc	c
	djnz ssl
	ld	a,c
	ret
#endif

