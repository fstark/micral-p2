; z80dasm 1.2.0
; command line: z80dasm -a -l -t -g 0xF800 -b blocks.def -o main_raw.asm main.bin

	org 0f800h

	ld a,0c0h		;f800	3e c0		> .
sim_opcode_last:

; BLOCK 'sim_opcode' (start 0xf802 end 0xf803)
sim_opcode_start:
	defb 030h		;f802	30		0
	ld sp,lfd5dh		;f803	31 5d fd	1 ] .
	xor a			;f806	af		.
	out (011h),a		;f807	d3 11		. .
	ld hl,0f7f8h		;f809	21 f8 f7	! . .
	ld (hl),0c3h		;f80c	36 c3		6 .
	inc hl			;f80e	23		#
	ld (hl),07ah		;f80f	36 7a		6 z
	inc hl			;f811	23		#
	ld (hl),0fah		;f812	36 fa		6 .
	ld a,0f6h		;f814	3e f6		> .
	out (060h),a		;f816	d3 60		. `
	ld a,0f7h		;f818	3e f7		> .
	out (061h),a		;f81a	d3 61		. a
	ld a,0bfh		;f81c	3e bf		> .
	out (061h),a		;f81e	d3 61		. a
	xor a			;f820	af		.
	ld (lfc34h),a		;f821	32 34 fc	2 4 .
lf824h:
	ld sp,lfd5dh		;f824	31 5d fd	1 ] .
	call sub_fbe7h		;f827	cd e7 fb	. . .
	ld hl,str_portal_start	;f82a	21 8c fb	! . .
	call sub_fc0ch		;f82d	cd 0c fc	. . .
	ld hl,00110h		;f830	21 10 01	! . .
	ld (lfc3dh),hl		;f833	22 3d fc	" = .
	ld de,00080h		;f836	11 80 00	. . .
lf839h:
	ld b,000h		;f839	06 00		. .
	call sub_fb97h		;f83b	cd 97 fb	. . .
	ld a,c			;f83e	79		y
	cp 026h			;f83f	fe 26		. &
	jp z,lfb6dh		;f841	ca 6d fb	. m .
	cp 00dh			;f844	fe 0d		. .
	ex de,hl		;f846	eb		.
	jp z,lf879h		;f847	ca 79 f8	. y .
	cp 02ah			;f84a	fe 2a		. *
	jp z,lfb3eh		;f84c	ca 3e fb	. > .
	ld b,a			;f84f	47		G
	ld c,03ah		;f850	0e 3a		. :
	call sub_fb9bh		;f852	cd 9b fb	. . .
	ld a,047h		;f855	3e 47		> G
	cp b			;f857	b8		.
	jp z,lfb66h		;f858	ca 66 fb	. f .
	ld a,042h		;f85b	3e 42		> B
	cp b			;f85d	b8		.
	jp nz,lfb79h		;f85e	c2 79 fb	. y .
	call 0fb05h		;f861	cd 05 fb	. . .
	jp nc,lfb79h		;f864	d2 79 fb	. y .
	ld a,h			;f867	7c		|
	or a			;f868	b7		.
	jp nz,lfb79h		;f869	c2 79 fb	. y .
	ld a,l			;f86c	7d		}
	cp 004h			;f86d	fe 04		. .
	jp nc,lfb79h		;f86f	d2 79 fb	. y .
	ld b,l			;f872	45		E
	call 0fb05h		;f873	cd 05 fb	. . .
	jp nc,lfb79h		;f876	d2 79 fb	. y .
lf879h:
	ld a,001h		;f879	3e 01		> .
	ld (lfc34h),a		;f87b	32 34 fc	2 4 .
	ld a,030h		;f87e	3e 30		> 0
	out (011h),a		;f880	d3 11		. .
	ld de,084c6h		;f882	11 c6 84	. . .
	ei			;f885	fb		.
lf886h:
	ex (sp),hl		;f886	e3		.
	ex (sp),hl		;f887	e3		.
	dec de			;f888	1b		.
	ld a,e			;f889	7b		{
	or d			;f88a	b2		.
	jp nz,lf886h		;f88b	c2 86 f8	. . .
	di			;f88e	f3		.
	xor a			;f88f	af		.
	ld (lfc34h),a		;f890	32 34 fc	2 4 .
	ld (lfc35h),hl		;f893	22 35 fc	" 5 .
	ld a,b			;f896	78		x
	ld (lfc23h),a		;f897	32 23 fc	2 # .
	ld hl,str_floppy_params_start	;f89a	21 fd fa	! . .
	ld de,lfc1fh		;f89d	11 1f fc	. . .
	ld a,003h		;f8a0	3e 03		> .
	ld (de),a		;f8a2	12		.
	inc de			;f8a3	13		.
	ld c,002h		;f8a4	0e 02		. .
	call sub_fa1eh		;f8a6	cd 1e fa	. . .
	ld c,003h		;f8a9	0e 03		. .
	ld hl,lfc1fh		;f8ab	21 1f fc	! . .
	call sub_fadah		;f8ae	cd da fa	. . .
	ld hl,0ffffh		;f8b1	21 ff ff	! . .
	ld (lfc1bh),hl		;f8b4	22 1b fc	" . .
	ld (lfc1dh),hl		;f8b7	22 1d fc	" . .
	ld hl,lfc22h		;f8ba	21 22 fc	! " .
	ld (hl),004h		;f8bd	36 04		6 .
	ld c,002h		;f8bf	0e 02		. .
	call sub_fadah		;f8c1	cd da fa	. . .
	call sub_fab7h		;f8c4	cd b7 fa	. . .
	ld a,(hl)		;f8c7	7e		~
	and 008h		;f8c8	e6 08		. .
	rlca			;f8ca	07		.
	rlca			;f8cb	07		.
	rlca			;f8cc	07		.
	rlca			;f8cd	07		.
	ld a,040h		;f8ce	3e 40		> @
	or 006h			;f8d0	f6 06		. .
	ld (lfc22h),a		;f8d2	32 22 fc	2 " .
	ld hl,lfaffh		;f8d5	21 ff fa	! . .
	rlca			;f8d8	07		.
	ld a,(hl)		;f8d9	7e		~
	jp nc,lf8deh		;f8da	d2 de f8	. . .
	rlca			;f8dd	07		.
lf8deh:
	inc hl			;f8de	23		#
	inc hl			;f8df	23		#
	ld l,(hl)		;f8e0	6e		n
	ld h,a			;f8e1	67		g
	ld (lfc37h),hl		;f8e2	22 37 fc	" 7 .
	ld hl,(lfc3dh)		;f8e5	2a 3d fc	* = .
	ex de,hl		;f8e8	eb		.
	ld hl,00000h		;f8e9	21 00 00	! . .
	ld (lfc3bh),hl		;f8ec	22 3b fc	" ; .
lf8efh:
	call sub_f95eh		;f8ef	cd 5e f9	. ^ .
	and a			;f8f2	a7		.
	jp z,lfb79h		;f8f3	ca 79 fb	. y .
	ld c,a			;f8f6	4f		O
	call sub_f95eh		;f8f7	cd 5e f9	. ^ .
	ld b,a			;f8fa	47		G
	ld a,c			;f8fb	79		y
	cp 003h			;f8fc	fe 03		. .
	jp c,lf912h		;f8fe	da 12 f9	. . .
	call sub_f95eh		;f901	cd 5e f9	. ^ .
	ld h,a			;f904	67		g
	call sub_f95eh		;f905	cd 5e f9	. ^ .
	ld l,a			;f908	6f		o
	call sub_f95eh		;f909	cd 5e f9	. ^ .
	and 001h		;f90c	e6 01		. .
	jp z,lf912h		;f90e	ca 12 f9	. . .
	add hl,de		;f911	19		.
lf912h:
	ld a,b			;f912	78		x
	cp 0c2h			;f913	fe c2		. .
	jp z,lf932h		;f915	ca 32 f9	. 2 .
	cp 0d2h			;f918	fe d2		. .
	jp z,lf93eh		;f91a	ca 3e f9	. > .
	cp 0c6h			;f91d	fe c6		. .
	jp z,lf95dh		;f91f	ca 5d f9	. ] .
	cp 0c1h			;f922	fe c1		. .
	jp c,lfb79h		;f924	da 79 fb	. y .
	cp 0dbh			;f927	fe db		. .
	jp nc,lfb79h		;f929	d2 79 fb	. y .
lf92ch:
	call sub_f95eh		;f92c	cd 5e f9	. ^ .
	jp lf92ch		;f92f	c3 2c f9	. , .
lf932h:
	call sub_f95eh		;f932	cd 5e f9	. ^ .
	ld (hl),a		;f935	77		w
	cp (hl)			;f936	be		.
	jp nz,lfb79h		;f937	c2 79 fb	. y .
	inc hl			;f93a	23		#
	jp lf932h		;f93b	c3 32 f9	. 2 .
lf93eh:
	call sub_f95eh		;f93e	cd 5e f9	. ^ .
	ld b,004h		;f941	06 04		. .
lf943h:
	rlca			;f943	07		.
	jp c,lfb79h		;f944	da 79 fb	. y .
	rlca			;f947	07		.
	jp nc,lf955h		;f948	d2 55 f9	. U .
	push af			;f94b	f5		.
	ld a,(hl)		;f94c	7e		~
	add a,e			;f94d	83		.
	ld (hl),a		;f94e	77		w
	inc hl			;f94f	23		#
	ld a,(hl)		;f950	7e		~
	adc a,d			;f951	8a		.
	ld (hl),a		;f952	77		w
	dec hl			;f953	2b		+
	pop af			;f954	f1		.
lf955h:
	inc hl			;f955	23		#
	dec b			;f956	05		.
	jp nz,lf943h		;f957	c2 43 f9	. C .
	jp lf93eh		;f95a	c3 3e f9	. > .
lf95dh:
	jp (hl)			;f95d	e9		.
sub_f95eh:
	inc c			;f95e	0c		.
	dec c			;f95f	0d		.
	jp nz,lf968h		;f960	c2 68 f9	. h .
	pop af			;f963	f1		.
	inc c			;f964	0c		.
	jp lf8efh		;f965	c3 ef f8	. . .
lf968h:
	push hl			;f968	e5		.
	ld hl,(lfc3bh)		;f969	2a 3b fc	* ; .
	ld a,h			;f96c	7c		|
	or l			;f96d	b5		.
	jp nz,lf990h		;f96e	c2 90 f9	. . .
	push hl			;f971	e5		.
	push de			;f972	d5		.
	push bc			;f973	c5		.
	ld hl,(lfc37h)		;f974	2a 37 fc	* 7 .
	ex de,hl		;f977	eb		.
	ld hl,(lfc35h)		;f978	2a 35 fc	* 5 .
	call sub_f99fh		;f97b	cd 9f f9	. . .
	ld (lfc35h),hl		;f97e	22 35 fc	" 5 .
	pop bc			;f981	c1		.
	pop de			;f982	d1		.
	pop hl			;f983	e1		.
	ld hl,000ffh		;f984	21 ff 00	! . .
	ld (lfc3bh),hl		;f987	22 3b fc	" ; .
	ld hl,lfc3fh		;f98a	21 3f fc	! ? .
	jp lf997h		;f98d	c3 97 f9	. . .
lf990h:
	dec hl			;f990	2b		+
	ld (lfc3bh),hl		;f991	22 3b fc	" ; .
	ld hl,(lfc39h)		;f994	2a 39 fc	* 9 .
lf997h:
	ld a,(hl)		;f997	7e		~
	inc hl			;f998	23		#
	ld (lfc39h),hl		;f999	22 39 fc	" 9 .
	pop hl			;f99c	e1		.
	dec c			;f99d	0d		.
	ret			;f99e	c9		.
sub_f99fh:
	push hl			;f99f	e5		.
	push de			;f9a0	d5		.
	xor a			;f9a1	af		.
	ld d,010h		;f9a2	16 10		. .
lf9a4h:
	add hl,hl		;f9a4	29		)
	rla			;f9a5	17		.
	jp c,lf9adh		;f9a6	da ad f9	. . .
	cp e			;f9a9	bb		.
	jp c,lf9afh		;f9aa	da af f9	. . .
lf9adh:
	inc l			;f9ad	2c		,
	sub e			;f9ae	93		.
lf9afh:
	dec d			;f9af	15		.
	jp nz,lf9a4h		;f9b0	c2 a4 f9	. . .
	inc a			;f9b3	3c		<
	ld (lfc26h),a		;f9b4	32 26 fc	2 & .
	ld a,l			;f9b7	7d		}
	pop de			;f9b8	d1		.
	cp d			;f9b9	ba		.
	jp nc,lfb79h		;f9ba	d2 79 fb	. y .
	ld a,(lfc22h)		;f9bd	3a 22 fc	: " .
	rlca			;f9c0	07		.
	ld b,000h		;f9c1	06 00		. .
	ld a,l			;f9c3	7d		}
	jp nc,lf9ceh		;f9c4	d2 ce f9	. . .
	or a			;f9c7	b7		.
	rra			;f9c8	1f		.
	jp nc,lf9ceh		;f9c9	d2 ce f9	. . .
	ld b,004h		;f9cc	06 04		. .
lf9ceh:
	ld (lfc24h),a		;f9ce	32 24 fc	2 $ .
	ld hl,lfc23h		;f9d1	21 23 fc	! # .
	ld a,b			;f9d4	78		x
	or (hl)			;f9d5	b6		.
	ld (hl),a		;f9d6	77		w
	ld a,b			;f9d7	78		x
	rrca			;f9d8	0f		.
	rrca			;f9d9	0f		.
	ld (lfc25h),a		;f9da	32 25 fc	2 % .
	ld hl,lfb00h		;f9dd	21 00 fb	! . .
	ld c,004h		;f9e0	0e 04		. .
	ld de,lfc27h		;f9e2	11 27 fc	. ' .
	call sub_fa1eh		;f9e5	cd 1e fa	. . .
lf9e8h:
	ld a,03fh		;f9e8	3e 3f		> ?
	out (040h),a		;f9ea	d3 40		. @
	ld a,0fch		;f9ec	3e fc		> .
	out (040h),a		;f9ee	d3 40		. @
	ld a,0ffh		;f9f0	3e ff		> .
	out (041h),a		;f9f2	d3 41		. A
	ld a,040h		;f9f4	3e 40		> @
	out (041h),a		;f9f6	d3 41		. A
	ld a,0e5h		;f9f8	3e e5		> .
	out (048h),a		;f9fa	d3 48		. H
	call sub_fa34h		;f9fc	cd 34 fa	. 4 .
	ld c,009h		;f9ff	0e 09		. .
	ld hl,lfc22h		;fa01	21 22 fc	! " .
	call sub_faedh		;fa04	cd ed fa	. . .
	dec a			;fa07	3d		=
	jp nz,lfa0eh		;fa08	c2 0e fa	. . .
	pop hl			;fa0b	e1		.
	inc hl			;fa0c	23		#
	ret			;fa0d	c9		.
lfa0eh:
	ld a,(lfc2ch)		;fa0e	3a 2c fc	: , .
	and 084h		;fa11	e6 84		. .
	jp z,lf9e8h		;fa13	ca e8 f9	. . .
	call sub_fa27h		;fa16	cd 27 fa	. ' .
	ld (hl),0ffh		;fa19	36 ff		6 .
	jp lf9e8h		;fa1b	c3 e8 f9	. . .
sub_fa1eh:
	ld a,(hl)		;fa1e	7e		~
	ld (de),a		;fa1f	12		.
	inc hl			;fa20	23		#
	inc de			;fa21	13		.
	dec c			;fa22	0d		.
	jp nz,sub_fa1eh		;fa23	c2 1e fa	. . .
	ret			;fa26	c9		.
sub_fa27h:
	ld a,(lfc23h)		;fa27	3a 23 fc	: # .
	and 003h		;fa2a	e6 03		. .
	ld hl,lfc1bh		;fa2c	21 1b fc	! . .
	add a,l			;fa2f	85		.
	ld l,a			;fa30	6f		o
	ret nc			;fa31	d0		.
	inc h			;fa32	24		$
	ret			;fa33	c9		.
sub_fa34h:
	call sub_fa27h		;fa34	cd 27 fa	. ' .
	ld a,(hl)		;fa37	7e		~
	inc a			;fa38	3c		<
	jp z,lfa5fh		;fa39	ca 5f fa	. _ .
lfa3ch:
	ld a,(lfc24h)		;fa3c	3a 24 fc	: $ .
	cp (hl)			;fa3f	be		.
	ret z			;fa40	c8		.
	or a			;fa41	b7		.
	ex de,hl		;fa42	eb		.
	jp z,lfa69h		;fa43	ca 69 fa	. i .
	ld hl,lfc21h		;fa46	21 21 fc	! ! .
	ld (hl),a		;fa49	77		w
	ld b,00fh		;fa4a	06 0f		. .
	ld c,003h		;fa4c	0e 03		. .
sub_fa4eh:
	ld hl,lfc20h		;fa4e	21 20 fc	!   .
	ld a,(lfc23h)		;fa51	3a 23 fc	: # .
	ld (hl),a		;fa54	77		w
	dec hl			;fa55	2b		+
	ld (hl),b		;fa56	70		p
	call sub_faedh		;fa57	cd ed fa	. . .
	ld a,(lfc24h)		;fa5a	3a 24 fc	: $ .
	ld (de),a		;fa5d	12		.
	ret			;fa5e	c9		.
lfa5fh:
	ex de,hl		;fa5f	eb		.
	call lfa69h		;fa60	cd 69 fa	. i .
	ex de,hl		;fa63	eb		.
	ld (hl),000h		;fa64	36 00		6 .
	jp lfa3ch		;fa66	c3 3c fa	. < .
lfa69h:
	ld b,007h		;fa69	06 07		. .
	ld c,002h		;fa6b	0e 02		. .
	call sub_fa4eh		;fa6d	cd 4e fa	. N .
	ld a,(lfc33h)		;fa70	3a 33 fc	: 3 .
	dec a			;fa73	3d		=
	ld a,000h		;fa74	3e 00		> .
	ret z			;fa76	c8		.
	jp lfa69h		;fa77	c3 69 fa	. i .
	push af			;fa7a	f5		.
	push bc			;fa7b	c5		.
	push hl			;fa7c	e5		.
	ld a,(lfc34h)		;fa7d	3a 34 fc	: 4 .
	and a			;fa80	a7		.
	jp nz,lfa9dh		;fa81	c2 9d fa	. . .
lfa84h:
	call sub_fab7h		;fa84	cd b7 fa	. . .
	ld a,b			;fa87	78		x
	and a			;fa88	a7		.
	jp z,lfaaah		;fa89	ca aa fa	. . .
	ld hl,lfc2bh		;fa8c	21 2b fc	! + .
	ld a,(hl)		;fa8f	7e		~
	rlca			;fa90	07		.
	jp c,lfaa5h		;fa91	da a5 fa	. . .
	rlca			;fa94	07		.
	jp c,lfaa5h		;fa95	da a5 fa	. . .
	ld a,001h		;fa98	3e 01		> .
lfa9ah:
	ld (lfc33h),a		;fa9a	32 33 fc	2 3 .
lfa9dh:
	ld a,066h		;fa9d	3e 66		> f
	out (060h),a		;fa9f	d3 60		. `
	pop hl			;faa1	e1		.
	pop bc			;faa2	c1		.
	pop af			;faa3	f1		.
	ret			;faa4	c9		.
lfaa5h:
	ld a,07fh		;faa5	3e 7f		> .
	jp lfa9ah		;faa7	c3 9a fa	. . .
lfaaah:
	ld hl,lfc1fh		;faaa	21 1f fc	! . .
	ld (hl),008h		;faad	36 08		6 .
	ld c,001h		;faaf	0e 01		. .
	call sub_fad3h		;fab1	cd d3 fa	. . .
	jp lfa84h		;fab4	c3 84 fa	. . .
sub_fab7h:
	ld hl,lfc2ah		;fab7	21 2a fc	! * .
	ld b,000h		;faba	06 00		. .
lfabch:
	in a,(050h)		;fabc	db 50		. P
	rlca			;fabe	07		.
	jp nc,lfabch		;fabf	d2 bc fa	. . .
	ld c,a			;fac2	4f		O
	and 020h		;fac3	e6 20		.  
	ret z			;fac5	c8		.
	ld a,c			;fac6	79		y
	rlca			;fac7	07		.
	jp nc,lfabch		;fac8	d2 bc fa	. . .
	in a,(051h)		;facb	db 51		. Q
	inc hl			;facd	23		#
	inc b			;face	04		.
	ld (hl),a		;facf	77		w
	jp lfabch		;fad0	c3 bc fa	. . .
sub_fad3h:
	in a,(050h)		;fad3	db 50		. P
	and 010h		;fad5	e6 10		. .
	jp nz,sub_fad3h		;fad7	c2 d3 fa	. . .
sub_fadah:
	in a,(050h)		;fada	db 50		. P
	rlca			;fadc	07		.
	jp nc,sub_fadah		;fadd	d2 da fa	. . .
	rlca			;fae0	07		.
	jp c,sub_fadah		;fae1	da da fa	. . .
	ld a,(hl)		;fae4	7e		~
	out (051h),a		;fae5	d3 51		. Q
	inc hl			;fae7	23		#
	dec c			;fae8	0d		.
	jp nz,sub_fadah		;fae9	c2 da fa	. . .
	ret			;faec	c9		.
sub_faedh:
	call sub_fad3h		;faed	cd d3 fa	. . .
	xor a			;faf0	af		.
	ld (lfc33h),a		;faf1	32 33 fc	2 3 .
	ei			;faf4	fb		.
lfaf5h:
	ld a,(lfc33h)		;faf5	3a 33 fc	: 3 .
	or a			;faf8	b7		.
	jp z,lfaf5h		;faf9	ca f5 fa	. . .
	ret			;fafc	c9		.

; BLOCK 'str_floppy_params' (start 0xfafd end 0xfb04)
str_floppy_params_start:
	defb 053h		;fafd	53		S
	defb 030h		;fafe	30		0
lfaffh:
	defb 028h		;faff	28		(
lfb00h:
	defb 001h		;fb00	01		.
	defb 010h		;fb01	10		.
	defb 020h		;fb02	20		 
str_floppy_params_last:
	defb 000h		;fb03	00		.
	ld (021c5h),a		;fb04	32 c5 21	2 . !
	nop			;fb07	00		.
	nop			;fb08	00		.
	ld b,009h		;fb09	06 09		. .
lfb0bh:
	call sub_fb97h		;fb0b	cd 97 fb	. . .
	ld a,c			;fb0e	79		y
	sub 030h		;fb0f	d6 30		. 0
	jp c,lfb33h		;fb11	da 33 fb	. 3 .
	add a,0e9h		;fb14	c6 e9		. .
	jp c,lfb33h		;fb16	da 33 fb	. 3 .
	add a,006h		;fb19	c6 06		. .
	jp p,lfb23h		;fb1b	f2 23 fb	. # .
	add a,007h		;fb1e	c6 07		. .
	jp c,lfb33h		;fb20	da 33 fb	. 3 .
lfb23h:
	add a,00ah		;fb23	c6 0a		. .
	or a			;fb25	b7		.
	dec b			;fb26	05		.
	jp z,lfb3ch		;fb27	ca 3c fb	. < .
	add hl,hl		;fb2a	29		)
	add hl,hl		;fb2b	29		)
	add hl,hl		;fb2c	29		)
	add hl,hl		;fb2d	29		)
	or l			;fb2e	b5		.
	ld l,a			;fb2f	6f		o
	jp lfb0bh		;fb30	c3 0b fb	. . .
lfb33h:
	ld a,c			;fb33	79		y
	cp 01bh			;fb34	fe 1b		. .
	pop bc			;fb36	c1		.
	jp z,lfb3ch		;fb37	ca 3c fb	. < .
	scf			;fb3a	37		7
	ret			;fb3b	c9		.
lfb3ch:
	or a			;fb3c	b7		.
	ret			;fb3d	c9		.
lfb3eh:
	ld b,009h		;fb3e	06 09		. .
lfb40h:
	call sub_fb81h		;fb40	cd 81 fb	. . .
	ld c,a			;fb43	4f		O
	cp 00dh			;fb44	fe 0d		. .
	jp z,lfb58h		;fb46	ca 58 fb	. X .
	cp 00ah			;fb49	fe 0a		. .
	jp z,lfb58h		;fb4b	ca 58 fb	. X .
	inc b			;fb4e	04		.
	ld a,b			;fb4f	78		x
	cp 020h			;fb50	fe 20		.  
	jp nz,lfb60h		;fb52	c2 60 fb	. ` .
	call sub_fbe7h		;fb55	cd e7 fb	. . .
lfb58h:
	ld b,000h		;fb58	06 00		. .
	call sub_fb9bh		;fb5a	cd 9b fb	. . .
	jp lfb40h		;fb5d	c3 40 fb	. @ .
lfb60h:
	call sub_fb9bh		;fb60	cd 9b fb	. . .
	jp lfb40h		;fb63	c3 40 fb	. @ .
lfb66h:
	call 0fb05h		;fb66	cd 05 fb	. . .
	jp nc,lfb79h		;fb69	d2 79 fb	. y .
	jp (hl)			;fb6c	e9		.
lfb6dh:
	call 0fb05h		;fb6d	cd 05 fb	. . .
	jp nc,lfb79h		;fb70	d2 79 fb	. y .
	ld (lfc3dh),hl		;fb73	22 3d fc	" = .
	jp lf839h		;fb76	c3 39 f8	. 9 .
lfb79h:
	ld c,023h		;fb79	0e 23		. #
	call sub_fb9bh		;fb7b	cd 9b fb	. . .
	jp lf824h		;fb7e	c3 24 f8	. $ .
sub_fb81h:
	in a,(010h)		;fb81	db 10		. .
	rrca			;fb83	0f		.
	jp nc,sub_fb81h		;fb84	d2 81 fb	. . .
	in a,(011h)		;fb87	db 11		. .
	and 07fh		;fb89	e6 7f		. .
	ret			;fb8b	c9		.

; BLOCK 'str_portal' (start 0xfb8c end 0xfb97)
str_portal_start:
	defb 009h		;fb8c	09		.
	defb 020h		;fb8d	20		 
	defb 050h		;fb8e	50		P
	defb 04fh		;fb8f	4f		O
	defb 052h		;fb90	52		R
	defb 054h		;fb91	54		T
	defb 041h		;fb92	41		A
	defb 04ch		;fb93	4c		L
	defb 02eh		;fb94	2e		.
	defb 02eh		;fb95	2e		.
str_portal_last:
	defb 000h		;fb96	00		.
sub_fb97h:
	call sub_fb81h		;fb97	cd 81 fb	. . .
	ld c,a			;fb9a	4f		O
sub_fb9bh:
	ld a,c			;fb9b	79		y
	cp 00dh			;fb9c	fe 0d		. .
	jp z,lfbb7h		;fb9e	ca b7 fb	. . .
	cp 00ah			;fba1	fe 0a		. .
	jp z,sub_fbe7h		;fba3	ca e7 fb	. . .
	push hl			;fba6	e5		.
	ld hl,(lfd5dh)		;fba7	2a 5d fd	* ] .
	ld (hl),c		;fbaa	71		q
	inc hl			;fbab	23		#
	ld (lfd5dh),hl		;fbac	22 5d fd	" ] .
	ld a,05fh		;fbaf	3e 5f		> _
	ld (hl),a		;fbb1	77		w
	call sub_fbcch		;fbb2	cd cc fb	. . .
	pop hl			;fbb5	e1		.
	ret			;fbb6	c9		.
lfbb7h:
	push hl			;fbb7	e5		.
	ld hl,(lfd5dh)		;fbb8	2a 5d fd	* ] .
	ld a,020h		;fbbb	3e 20		>  
	ld (hl),a		;fbbd	77		w
	ld hl,lfd5fh		;fbbe	21 5f fd	! _ .
	ld (lfd5dh),hl		;fbc1	22 5d fd	" ] .
	ld a,05fh		;fbc4	3e 5f		> _
	ld (hl),a		;fbc6	77		w
	call sub_fbcch		;fbc7	cd cc fb	. . .
	pop hl			;fbca	e1		.
	ret			;fbcb	c9		.
sub_fbcch:
	push hl			;fbcc	e5		.
	push bc			;fbcd	c5		.
	ld hl,lfd5fh		;fbce	21 5f fd	! _ .
	ld b,09fh		;fbd1	06 9f		. .
lfbd3h:
	push hl			;fbd3	e5		.
	ld hl,0fbdbh		;fbd4	21 db fb	! . .
	ld (hl),b		;fbd7	70		p
	pop hl			;fbd8	e1		.
	ld a,(hl)		;fbd9	7e		~
	out (09fh),a		;fbda	d3 9f		. .
	inc hl			;fbdc	23		#
	dec b			;fbdd	05		.
	ld a,b			;fbde	78		x
	cp 07fh			;fbdf	fe 7f		. .
	jp nz,lfbd3h		;fbe1	c2 d3 fb	. . .
	pop bc			;fbe4	c1		.
	pop hl			;fbe5	e1		.
	ret			;fbe6	c9		.
sub_fbe7h:
	push af			;fbe7	f5		.
	push bc			;fbe8	c5		.
	push de			;fbe9	d5		.
	push hl			;fbea	e5		.
	ld a,020h		;fbeb	3e 20		>  
	ld hl,lfd5fh		;fbed	21 5f fd	! _ .
	ld c,020h		;fbf0	0e 20		.  
lfbf2h:
	ld (hl),a		;fbf2	77		w
	inc hl			;fbf3	23		#
	dec c			;fbf4	0d		.
	jp nz,lfbf2h		;fbf5	c2 f2 fb	. . .
	ld hl,lfd5fh		;fbf8	21 5f fd	! _ .
	ld a,05fh		;fbfb	3e 5f		> _
	ld (hl),a		;fbfd	77		w
	call sub_fbcch		;fbfe	cd cc fb	. . .
	ld hl,lfd5fh		;fc01	21 5f fd	! _ .
	ld (lfd5dh),hl		;fc04	22 5d fd	" ] .
	pop hl			;fc07	e1		.
	pop de			;fc08	d1		.
	pop bc			;fc09	c1		.
	pop af			;fc0a	f1		.
	ret			;fc0b	c9		.
sub_fc0ch:
	push bc			;fc0c	c5		.
	push hl			;fc0d	e5		.
	ld b,(hl)		;fc0e	46		F
lfc0fh:
	inc hl			;fc0f	23		#
	ld c,(hl)		;fc10	4e		N
	call sub_fb9bh		;fc11	cd 9b fb	. . .
	dec b			;fc14	05		.
	jp nz,lfc0fh		;fc15	c2 0f fc	. . .
	pop hl			;fc18	e1		.
	pop bc			;fc19	c1		.
	ret			;fc1a	c9		.
lfc1bh:
	nop			;fc1b	00		.
	nop			;fc1c	00		.
lfc1dh:
	nop			;fc1d	00		.
	nop			;fc1e	00		.
lfc1fh:
	nop			;fc1f	00		.
lfc20h:
	nop			;fc20	00		.
lfc21h:
	nop			;fc21	00		.
lfc22h:
	nop			;fc22	00		.
lfc23h:
	nop			;fc23	00		.
lfc24h:
	nop			;fc24	00		.
lfc25h:
	nop			;fc25	00		.
lfc26h:
	nop			;fc26	00		.
lfc27h:
	nop			;fc27	00		.
	nop			;fc28	00		.
	nop			;fc29	00		.
lfc2ah:
	nop			;fc2a	00		.
lfc2bh:
	nop			;fc2b	00		.
lfc2ch:
	nop			;fc2c	00		.
	nop			;fc2d	00		.
	nop			;fc2e	00		.
	nop			;fc2f	00		.
	nop			;fc30	00		.
	nop			;fc31	00		.
	nop			;fc32	00		.
lfc33h:
	nop			;fc33	00		.
lfc34h:
	nop			;fc34	00		.
lfc35h:
	nop			;fc35	00		.
	nop			;fc36	00		.
lfc37h:
	nop			;fc37	00		.
	nop			;fc38	00		.
lfc39h:
	nop			;fc39	00		.
	nop			;fc3a	00		.
lfc3bh:
	nop			;fc3b	00		.
	nop			;fc3c	00		.
lfc3dh:
	nop			;fc3d	00		.
	nop			;fc3e	00		.
lfc3fh:
	nop			;fc3f	00		.
	nop			;fc40	00		.
	nop			;fc41	00		.
	nop			;fc42	00		.
	nop			;fc43	00		.
	nop			;fc44	00		.
	nop			;fc45	00		.
	nop			;fc46	00		.
	nop			;fc47	00		.
	nop			;fc48	00		.
	nop			;fc49	00		.
	nop			;fc4a	00		.
	nop			;fc4b	00		.
	nop			;fc4c	00		.
	nop			;fc4d	00		.
	nop			;fc4e	00		.
	nop			;fc4f	00		.
	nop			;fc50	00		.
	nop			;fc51	00		.
	nop			;fc52	00		.
	nop			;fc53	00		.
	nop			;fc54	00		.
	nop			;fc55	00		.
	nop			;fc56	00		.
	nop			;fc57	00		.
	nop			;fc58	00		.
	nop			;fc59	00		.
	nop			;fc5a	00		.
	nop			;fc5b	00		.
	nop			;fc5c	00		.
	nop			;fc5d	00		.
	nop			;fc5e	00		.
	nop			;fc5f	00		.
	nop			;fc60	00		.
	nop			;fc61	00		.
	nop			;fc62	00		.
	nop			;fc63	00		.
	nop			;fc64	00		.
	nop			;fc65	00		.
	nop			;fc66	00		.
	nop			;fc67	00		.
	nop			;fc68	00		.
	nop			;fc69	00		.
	nop			;fc6a	00		.
	nop			;fc6b	00		.
	nop			;fc6c	00		.
	nop			;fc6d	00		.
	nop			;fc6e	00		.
	nop			;fc6f	00		.
	nop			;fc70	00		.
	nop			;fc71	00		.
	nop			;fc72	00		.
	nop			;fc73	00		.
	nop			;fc74	00		.
	nop			;fc75	00		.
	nop			;fc76	00		.
	nop			;fc77	00		.
	nop			;fc78	00		.
	nop			;fc79	00		.
	nop			;fc7a	00		.
	nop			;fc7b	00		.
	nop			;fc7c	00		.
	nop			;fc7d	00		.
	nop			;fc7e	00		.
	nop			;fc7f	00		.
	nop			;fc80	00		.
	nop			;fc81	00		.
	nop			;fc82	00		.
	nop			;fc83	00		.
	nop			;fc84	00		.
	nop			;fc85	00		.
	nop			;fc86	00		.
	nop			;fc87	00		.
	nop			;fc88	00		.
	nop			;fc89	00		.
	nop			;fc8a	00		.
	nop			;fc8b	00		.
	nop			;fc8c	00		.
	nop			;fc8d	00		.
	nop			;fc8e	00		.
	nop			;fc8f	00		.
	nop			;fc90	00		.
	nop			;fc91	00		.
	nop			;fc92	00		.
	nop			;fc93	00		.
	nop			;fc94	00		.
	nop			;fc95	00		.
	nop			;fc96	00		.
	nop			;fc97	00		.
	nop			;fc98	00		.
	nop			;fc99	00		.
	nop			;fc9a	00		.
	nop			;fc9b	00		.
	nop			;fc9c	00		.
	nop			;fc9d	00		.
	nop			;fc9e	00		.
	nop			;fc9f	00		.
	nop			;fca0	00		.
	nop			;fca1	00		.
	nop			;fca2	00		.
	nop			;fca3	00		.
	nop			;fca4	00		.
	nop			;fca5	00		.
	nop			;fca6	00		.
	nop			;fca7	00		.
	nop			;fca8	00		.
	nop			;fca9	00		.
	nop			;fcaa	00		.
	nop			;fcab	00		.
	nop			;fcac	00		.
	nop			;fcad	00		.
	nop			;fcae	00		.
	nop			;fcaf	00		.
	nop			;fcb0	00		.
	nop			;fcb1	00		.
	nop			;fcb2	00		.
	nop			;fcb3	00		.
	nop			;fcb4	00		.
	nop			;fcb5	00		.
	nop			;fcb6	00		.
	nop			;fcb7	00		.
	nop			;fcb8	00		.
	nop			;fcb9	00		.
	nop			;fcba	00		.
	nop			;fcbb	00		.
	nop			;fcbc	00		.
	nop			;fcbd	00		.
	nop			;fcbe	00		.
	nop			;fcbf	00		.
	nop			;fcc0	00		.
	nop			;fcc1	00		.
	nop			;fcc2	00		.
	nop			;fcc3	00		.
	nop			;fcc4	00		.
	nop			;fcc5	00		.
	nop			;fcc6	00		.
	nop			;fcc7	00		.
	nop			;fcc8	00		.
	nop			;fcc9	00		.
	nop			;fcca	00		.
	nop			;fccb	00		.
	nop			;fccc	00		.
	nop			;fccd	00		.
	nop			;fcce	00		.
	nop			;fccf	00		.
	nop			;fcd0	00		.
	nop			;fcd1	00		.
	nop			;fcd2	00		.
	nop			;fcd3	00		.
	nop			;fcd4	00		.
	nop			;fcd5	00		.
	nop			;fcd6	00		.
	nop			;fcd7	00		.
	nop			;fcd8	00		.
	nop			;fcd9	00		.
	nop			;fcda	00		.
	nop			;fcdb	00		.
	nop			;fcdc	00		.
	nop			;fcdd	00		.
	nop			;fcde	00		.
	nop			;fcdf	00		.
	nop			;fce0	00		.
	nop			;fce1	00		.
	nop			;fce2	00		.
	nop			;fce3	00		.
	nop			;fce4	00		.
	nop			;fce5	00		.
	nop			;fce6	00		.
	nop			;fce7	00		.
	nop			;fce8	00		.
	nop			;fce9	00		.
	nop			;fcea	00		.
	nop			;fceb	00		.
	nop			;fcec	00		.
	nop			;fced	00		.
	nop			;fcee	00		.
	nop			;fcef	00		.
	nop			;fcf0	00		.
	nop			;fcf1	00		.
	nop			;fcf2	00		.
	nop			;fcf3	00		.
	nop			;fcf4	00		.
	nop			;fcf5	00		.
	nop			;fcf6	00		.
	nop			;fcf7	00		.
	nop			;fcf8	00		.
	nop			;fcf9	00		.
	nop			;fcfa	00		.
	nop			;fcfb	00		.
	nop			;fcfc	00		.
	nop			;fcfd	00		.
	nop			;fcfe	00		.
	nop			;fcff	00		.
	nop			;fd00	00		.
	nop			;fd01	00		.
	nop			;fd02	00		.
	nop			;fd03	00		.
	nop			;fd04	00		.
	nop			;fd05	00		.
	nop			;fd06	00		.
	nop			;fd07	00		.
	nop			;fd08	00		.
	nop			;fd09	00		.
	nop			;fd0a	00		.
	nop			;fd0b	00		.
	nop			;fd0c	00		.
	nop			;fd0d	00		.
	nop			;fd0e	00		.
	nop			;fd0f	00		.
	nop			;fd10	00		.
	nop			;fd11	00		.
	nop			;fd12	00		.
	nop			;fd13	00		.
	nop			;fd14	00		.
	nop			;fd15	00		.
	nop			;fd16	00		.
	nop			;fd17	00		.
	nop			;fd18	00		.
	nop			;fd19	00		.
	nop			;fd1a	00		.
	nop			;fd1b	00		.
	nop			;fd1c	00		.
	nop			;fd1d	00		.
	nop			;fd1e	00		.
	nop			;fd1f	00		.
	nop			;fd20	00		.
	nop			;fd21	00		.
	nop			;fd22	00		.
	nop			;fd23	00		.
	nop			;fd24	00		.
	nop			;fd25	00		.
	nop			;fd26	00		.
	nop			;fd27	00		.
	nop			;fd28	00		.
	nop			;fd29	00		.
	nop			;fd2a	00		.
	nop			;fd2b	00		.
	nop			;fd2c	00		.
	nop			;fd2d	00		.
	nop			;fd2e	00		.
	nop			;fd2f	00		.
	nop			;fd30	00		.
	nop			;fd31	00		.
	nop			;fd32	00		.
	nop			;fd33	00		.
	nop			;fd34	00		.
	nop			;fd35	00		.
	nop			;fd36	00		.
	nop			;fd37	00		.
	nop			;fd38	00		.
	nop			;fd39	00		.
	nop			;fd3a	00		.
	nop			;fd3b	00		.
	nop			;fd3c	00		.
	nop			;fd3d	00		.
	nop			;fd3e	00		.
	nop			;fd3f	00		.
	nop			;fd40	00		.
	nop			;fd41	00		.
	nop			;fd42	00		.
	nop			;fd43	00		.
	nop			;fd44	00		.
	nop			;fd45	00		.
	nop			;fd46	00		.
	nop			;fd47	00		.
	nop			;fd48	00		.
	nop			;fd49	00		.
	nop			;fd4a	00		.
	nop			;fd4b	00		.
	nop			;fd4c	00		.
	nop			;fd4d	00		.
	nop			;fd4e	00		.
	nop			;fd4f	00		.
	nop			;fd50	00		.
	nop			;fd51	00		.
	nop			;fd52	00		.
	nop			;fd53	00		.
	nop			;fd54	00		.
	nop			;fd55	00		.
	nop			;fd56	00		.
	nop			;fd57	00		.
	nop			;fd58	00		.
	nop			;fd59	00		.
	nop			;fd5a	00		.
	nop			;fd5b	00		.
	nop			;fd5c	00		.
lfd5dh:
	nop			;fd5d	00		.
	nop			;fd5e	00		.
lfd5fh:
	nop			;fd5f	00		.
	nop			;fd60	00		.
	nop			;fd61	00		.
	nop			;fd62	00		.
	nop			;fd63	00		.
	nop			;fd64	00		.
	nop			;fd65	00		.
	nop			;fd66	00		.
	nop			;fd67	00		.
	nop			;fd68	00		.
	nop			;fd69	00		.
	nop			;fd6a	00		.
	nop			;fd6b	00		.
	nop			;fd6c	00		.
	nop			;fd6d	00		.
	nop			;fd6e	00		.
	nop			;fd6f	00		.
	nop			;fd70	00		.
	nop			;fd71	00		.
	nop			;fd72	00		.
	nop			;fd73	00		.
	nop			;fd74	00		.
	nop			;fd75	00		.
	nop			;fd76	00		.
	nop			;fd77	00		.
	nop			;fd78	00		.
	nop			;fd79	00		.
	nop			;fd7a	00		.
	nop			;fd7b	00		.
	nop			;fd7c	00		.
	nop			;fd7d	00		.
	nop			;fd7e	00		.
	nop			;fd7f	00		.
	nop			;fd80	00		.
	nop			;fd81	00		.
	nop			;fd82	00		.
	nop			;fd83	00		.
	nop			;fd84	00		.
	nop			;fd85	00		.
	nop			;fd86	00		.
	nop			;fd87	00		.
	nop			;fd88	00		.
	nop			;fd89	00		.
	nop			;fd8a	00		.
	nop			;fd8b	00		.
	nop			;fd8c	00		.
	nop			;fd8d	00		.
	nop			;fd8e	00		.
	nop			;fd8f	00		.
	nop			;fd90	00		.
	nop			;fd91	00		.
	nop			;fd92	00		.
	nop			;fd93	00		.
	nop			;fd94	00		.
	nop			;fd95	00		.
	nop			;fd96	00		.
	nop			;fd97	00		.
	nop			;fd98	00		.
	nop			;fd99	00		.
	nop			;fd9a	00		.
	nop			;fd9b	00		.
	nop			;fd9c	00		.
	nop			;fd9d	00		.
	nop			;fd9e	00		.
	nop			;fd9f	00		.
	nop			;fda0	00		.
	nop			;fda1	00		.
	nop			;fda2	00		.
	nop			;fda3	00		.
	nop			;fda4	00		.
	nop			;fda5	00		.
	nop			;fda6	00		.
	nop			;fda7	00		.
	nop			;fda8	00		.
	nop			;fda9	00		.
	nop			;fdaa	00		.
	nop			;fdab	00		.
	nop			;fdac	00		.
	nop			;fdad	00		.
	nop			;fdae	00		.
	nop			;fdaf	00		.
	nop			;fdb0	00		.
	nop			;fdb1	00		.
	nop			;fdb2	00		.
	nop			;fdb3	00		.
	nop			;fdb4	00		.
	nop			;fdb5	00		.
	nop			;fdb6	00		.
	nop			;fdb7	00		.
	nop			;fdb8	00		.
	nop			;fdb9	00		.
	nop			;fdba	00		.
	nop			;fdbb	00		.
	nop			;fdbc	00		.
	nop			;fdbd	00		.
	nop			;fdbe	00		.
	nop			;fdbf	00		.
	nop			;fdc0	00		.
	nop			;fdc1	00		.
	nop			;fdc2	00		.
	nop			;fdc3	00		.
	nop			;fdc4	00		.
	nop			;fdc5	00		.
	nop			;fdc6	00		.
	nop			;fdc7	00		.
	nop			;fdc8	00		.
	nop			;fdc9	00		.
	nop			;fdca	00		.
	nop			;fdcb	00		.
	nop			;fdcc	00		.
	nop			;fdcd	00		.
	nop			;fdce	00		.
	nop			;fdcf	00		.
	nop			;fdd0	00		.
	nop			;fdd1	00		.
	nop			;fdd2	00		.
	nop			;fdd3	00		.
	nop			;fdd4	00		.
	nop			;fdd5	00		.
	nop			;fdd6	00		.
	nop			;fdd7	00		.
	nop			;fdd8	00		.
	nop			;fdd9	00		.
	nop			;fdda	00		.
	nop			;fddb	00		.
	nop			;fddc	00		.
	nop			;fddd	00		.
	nop			;fdde	00		.
	nop			;fddf	00		.
	nop			;fde0	00		.
	nop			;fde1	00		.
	nop			;fde2	00		.
	nop			;fde3	00		.
	nop			;fde4	00		.
	nop			;fde5	00		.
	nop			;fde6	00		.
	nop			;fde7	00		.
	nop			;fde8	00		.
	nop			;fde9	00		.
	nop			;fdea	00		.
	nop			;fdeb	00		.
	nop			;fdec	00		.
	nop			;fded	00		.
	nop			;fdee	00		.
	nop			;fdef	00		.
	nop			;fdf0	00		.
	nop			;fdf1	00		.
	nop			;fdf2	00		.
	nop			;fdf3	00		.
	nop			;fdf4	00		.
	nop			;fdf5	00		.
	nop			;fdf6	00		.
	nop			;fdf7	00		.
	nop			;fdf8	00		.
	nop			;fdf9	00		.
	nop			;fdfa	00		.
	nop			;fdfb	00		.
	nop			;fdfc	00		.
	nop			;fdfd	00		.
	nop			;fdfe	00		.
	nop			;fdff	00		.
	nop			;fe00	00		.
	nop			;fe01	00		.
	nop			;fe02	00		.
	nop			;fe03	00		.
	nop			;fe04	00		.
	nop			;fe05	00		.
	nop			;fe06	00		.
	nop			;fe07	00		.
	nop			;fe08	00		.
	nop			;fe09	00		.
	nop			;fe0a	00		.
	nop			;fe0b	00		.
	nop			;fe0c	00		.
	nop			;fe0d	00		.
	nop			;fe0e	00		.
	nop			;fe0f	00		.
	nop			;fe10	00		.
	nop			;fe11	00		.
	nop			;fe12	00		.
	nop			;fe13	00		.
	nop			;fe14	00		.
	nop			;fe15	00		.
	nop			;fe16	00		.
	nop			;fe17	00		.
	nop			;fe18	00		.
	nop			;fe19	00		.
	nop			;fe1a	00		.
	nop			;fe1b	00		.
	nop			;fe1c	00		.
	nop			;fe1d	00		.
	nop			;fe1e	00		.
	nop			;fe1f	00		.
	nop			;fe20	00		.
	nop			;fe21	00		.
	nop			;fe22	00		.
	nop			;fe23	00		.
	nop			;fe24	00		.
	nop			;fe25	00		.
	nop			;fe26	00		.
	nop			;fe27	00		.
	nop			;fe28	00		.
	nop			;fe29	00		.
	nop			;fe2a	00		.
	nop			;fe2b	00		.
	nop			;fe2c	00		.
	nop			;fe2d	00		.
	nop			;fe2e	00		.
	nop			;fe2f	00		.
	nop			;fe30	00		.
	nop			;fe31	00		.
	nop			;fe32	00		.
	nop			;fe33	00		.
	nop			;fe34	00		.
	nop			;fe35	00		.
	nop			;fe36	00		.
	nop			;fe37	00		.
	nop			;fe38	00		.
	nop			;fe39	00		.
	nop			;fe3a	00		.
	nop			;fe3b	00		.
	nop			;fe3c	00		.
	nop			;fe3d	00		.
	nop			;fe3e	00		.
	nop			;fe3f	00		.
	nop			;fe40	00		.
	nop			;fe41	00		.
	nop			;fe42	00		.
	nop			;fe43	00		.
	nop			;fe44	00		.
	nop			;fe45	00		.
	nop			;fe46	00		.
	nop			;fe47	00		.
	nop			;fe48	00		.
	nop			;fe49	00		.
	nop			;fe4a	00		.
	nop			;fe4b	00		.
	nop			;fe4c	00		.
	nop			;fe4d	00		.
	nop			;fe4e	00		.
	nop			;fe4f	00		.
	nop			;fe50	00		.
	nop			;fe51	00		.
	nop			;fe52	00		.
	nop			;fe53	00		.
	nop			;fe54	00		.
	nop			;fe55	00		.
	nop			;fe56	00		.
	nop			;fe57	00		.
	nop			;fe58	00		.
	nop			;fe59	00		.
	nop			;fe5a	00		.
	nop			;fe5b	00		.
	nop			;fe5c	00		.
	nop			;fe5d	00		.
	nop			;fe5e	00		.
	nop			;fe5f	00		.
	nop			;fe60	00		.
	nop			;fe61	00		.
	nop			;fe62	00		.
	nop			;fe63	00		.
	nop			;fe64	00		.
	nop			;fe65	00		.
	nop			;fe66	00		.
	nop			;fe67	00		.
	nop			;fe68	00		.
	nop			;fe69	00		.
	nop			;fe6a	00		.
	nop			;fe6b	00		.
	nop			;fe6c	00		.
	nop			;fe6d	00		.
	nop			;fe6e	00		.
	nop			;fe6f	00		.
	nop			;fe70	00		.
	nop			;fe71	00		.
	nop			;fe72	00		.
	nop			;fe73	00		.
	nop			;fe74	00		.
	nop			;fe75	00		.
	nop			;fe76	00		.
	nop			;fe77	00		.
	nop			;fe78	00		.
	nop			;fe79	00		.
	nop			;fe7a	00		.
	nop			;fe7b	00		.
	nop			;fe7c	00		.
	nop			;fe7d	00		.
	nop			;fe7e	00		.
	nop			;fe7f	00		.
	nop			;fe80	00		.
	nop			;fe81	00		.
	nop			;fe82	00		.
	nop			;fe83	00		.
	nop			;fe84	00		.
	nop			;fe85	00		.
	nop			;fe86	00		.
	nop			;fe87	00		.
	nop			;fe88	00		.
	nop			;fe89	00		.
	nop			;fe8a	00		.
	nop			;fe8b	00		.
	nop			;fe8c	00		.
	nop			;fe8d	00		.
	nop			;fe8e	00		.
	nop			;fe8f	00		.
	nop			;fe90	00		.
	nop			;fe91	00		.
	nop			;fe92	00		.
	nop			;fe93	00		.
	nop			;fe94	00		.
	nop			;fe95	00		.
	nop			;fe96	00		.
	nop			;fe97	00		.
	nop			;fe98	00		.
	nop			;fe99	00		.
	nop			;fe9a	00		.
	nop			;fe9b	00		.
	nop			;fe9c	00		.
	nop			;fe9d	00		.
	nop			;fe9e	00		.
	nop			;fe9f	00		.
	nop			;fea0	00		.
	nop			;fea1	00		.
	nop			;fea2	00		.
	nop			;fea3	00		.
	nop			;fea4	00		.
	nop			;fea5	00		.
	nop			;fea6	00		.
	nop			;fea7	00		.
	nop			;fea8	00		.
	nop			;fea9	00		.
	nop			;feaa	00		.
	nop			;feab	00		.
	nop			;feac	00		.
	nop			;fead	00		.
	nop			;feae	00		.
	nop			;feaf	00		.
	nop			;feb0	00		.
	nop			;feb1	00		.
	nop			;feb2	00		.
	nop			;feb3	00		.
	nop			;feb4	00		.
	nop			;feb5	00		.
	nop			;feb6	00		.
	nop			;feb7	00		.
	nop			;feb8	00		.
	nop			;feb9	00		.
	nop			;feba	00		.
	nop			;febb	00		.
	nop			;febc	00		.
	nop			;febd	00		.
	nop			;febe	00		.
	nop			;febf	00		.
	nop			;fec0	00		.
	nop			;fec1	00		.
	nop			;fec2	00		.
	nop			;fec3	00		.
	nop			;fec4	00		.
	nop			;fec5	00		.
	nop			;fec6	00		.
	nop			;fec7	00		.
	nop			;fec8	00		.
	nop			;fec9	00		.
	nop			;feca	00		.
	nop			;fecb	00		.
	nop			;fecc	00		.
	nop			;fecd	00		.
	nop			;fece	00		.
	nop			;fecf	00		.
	nop			;fed0	00		.
	nop			;fed1	00		.
	nop			;fed2	00		.
	nop			;fed3	00		.
	nop			;fed4	00		.
	nop			;fed5	00		.
	nop			;fed6	00		.
	nop			;fed7	00		.
	nop			;fed8	00		.
	nop			;fed9	00		.
	nop			;feda	00		.
	nop			;fedb	00		.
	nop			;fedc	00		.
	nop			;fedd	00		.
	nop			;fede	00		.
	nop			;fedf	00		.
	nop			;fee0	00		.
	nop			;fee1	00		.
	nop			;fee2	00		.
	nop			;fee3	00		.
	nop			;fee4	00		.
	nop			;fee5	00		.
	nop			;fee6	00		.
	nop			;fee7	00		.
	nop			;fee8	00		.
	nop			;fee9	00		.
	nop			;feea	00		.
	nop			;feeb	00		.
	nop			;feec	00		.
	nop			;feed	00		.
	nop			;feee	00		.
	nop			;feef	00		.
	nop			;fef0	00		.
	nop			;fef1	00		.
	nop			;fef2	00		.
	nop			;fef3	00		.
	nop			;fef4	00		.
	nop			;fef5	00		.
	nop			;fef6	00		.
	nop			;fef7	00		.
	nop			;fef8	00		.
	nop			;fef9	00		.
	nop			;fefa	00		.
	nop			;fefb	00		.
	nop			;fefc	00		.
	nop			;fefd	00		.
	nop			;fefe	00		.
	nop			;feff	00		.
	nop			;ff00	00		.
	nop			;ff01	00		.
	nop			;ff02	00		.
	nop			;ff03	00		.
	nop			;ff04	00		.
	nop			;ff05	00		.
	nop			;ff06	00		.
	nop			;ff07	00		.
	nop			;ff08	00		.
	nop			;ff09	00		.
	nop			;ff0a	00		.
	nop			;ff0b	00		.
	nop			;ff0c	00		.
	nop			;ff0d	00		.
	nop			;ff0e	00		.
	nop			;ff0f	00		.
	nop			;ff10	00		.
	nop			;ff11	00		.
	nop			;ff12	00		.
	nop			;ff13	00		.
	nop			;ff14	00		.
	nop			;ff15	00		.
	nop			;ff16	00		.
	nop			;ff17	00		.
	nop			;ff18	00		.
	nop			;ff19	00		.
	nop			;ff1a	00		.
	nop			;ff1b	00		.
	nop			;ff1c	00		.
	nop			;ff1d	00		.
	nop			;ff1e	00		.
	nop			;ff1f	00		.
	nop			;ff20	00		.
	nop			;ff21	00		.
	nop			;ff22	00		.
	nop			;ff23	00		.
	nop			;ff24	00		.
	nop			;ff25	00		.
	nop			;ff26	00		.
	nop			;ff27	00		.
	nop			;ff28	00		.
	nop			;ff29	00		.
	nop			;ff2a	00		.
	nop			;ff2b	00		.
	nop			;ff2c	00		.
	nop			;ff2d	00		.
	nop			;ff2e	00		.
	nop			;ff2f	00		.
	nop			;ff30	00		.
	nop			;ff31	00		.
	nop			;ff32	00		.
	nop			;ff33	00		.
	nop			;ff34	00		.
	nop			;ff35	00		.
	nop			;ff36	00		.
	nop			;ff37	00		.
	nop			;ff38	00		.
	nop			;ff39	00		.
	nop			;ff3a	00		.
	nop			;ff3b	00		.
	nop			;ff3c	00		.
	nop			;ff3d	00		.
	nop			;ff3e	00		.
	nop			;ff3f	00		.
	nop			;ff40	00		.
	nop			;ff41	00		.
	nop			;ff42	00		.
	nop			;ff43	00		.
	nop			;ff44	00		.
	nop			;ff45	00		.
	nop			;ff46	00		.
	nop			;ff47	00		.
	nop			;ff48	00		.
	nop			;ff49	00		.
	nop			;ff4a	00		.
	nop			;ff4b	00		.
	nop			;ff4c	00		.
	nop			;ff4d	00		.
	nop			;ff4e	00		.
	nop			;ff4f	00		.
	nop			;ff50	00		.
	nop			;ff51	00		.
	nop			;ff52	00		.
	nop			;ff53	00		.
	nop			;ff54	00		.
	nop			;ff55	00		.
	nop			;ff56	00		.
	nop			;ff57	00		.
	nop			;ff58	00		.
	nop			;ff59	00		.
	nop			;ff5a	00		.
	nop			;ff5b	00		.
	nop			;ff5c	00		.
	nop			;ff5d	00		.
	nop			;ff5e	00		.
	nop			;ff5f	00		.
	nop			;ff60	00		.
	nop			;ff61	00		.
	nop			;ff62	00		.
	nop			;ff63	00		.
	nop			;ff64	00		.
	nop			;ff65	00		.
	nop			;ff66	00		.
	nop			;ff67	00		.
	nop			;ff68	00		.
	nop			;ff69	00		.
	nop			;ff6a	00		.
	nop			;ff6b	00		.
	nop			;ff6c	00		.
	nop			;ff6d	00		.
	nop			;ff6e	00		.
	nop			;ff6f	00		.
	nop			;ff70	00		.
	nop			;ff71	00		.
	nop			;ff72	00		.
	nop			;ff73	00		.
	nop			;ff74	00		.
	nop			;ff75	00		.
	nop			;ff76	00		.
	nop			;ff77	00		.
	nop			;ff78	00		.
	nop			;ff79	00		.
	nop			;ff7a	00		.
	nop			;ff7b	00		.
	nop			;ff7c	00		.
	nop			;ff7d	00		.
	nop			;ff7e	00		.
	nop			;ff7f	00		.
	nop			;ff80	00		.
	nop			;ff81	00		.
	nop			;ff82	00		.
	nop			;ff83	00		.
	nop			;ff84	00		.
	nop			;ff85	00		.
	nop			;ff86	00		.
	nop			;ff87	00		.
	nop			;ff88	00		.
	nop			;ff89	00		.
	nop			;ff8a	00		.
	nop			;ff8b	00		.
	nop			;ff8c	00		.
	nop			;ff8d	00		.
	nop			;ff8e	00		.
	nop			;ff8f	00		.
	nop			;ff90	00		.
	nop			;ff91	00		.
	nop			;ff92	00		.
	nop			;ff93	00		.
	nop			;ff94	00		.
	nop			;ff95	00		.
	nop			;ff96	00		.
	nop			;ff97	00		.
	nop			;ff98	00		.
	nop			;ff99	00		.
	nop			;ff9a	00		.
	nop			;ff9b	00		.
	nop			;ff9c	00		.
	nop			;ff9d	00		.
	nop			;ff9e	00		.
	nop			;ff9f	00		.
	nop			;ffa0	00		.
	nop			;ffa1	00		.
	nop			;ffa2	00		.
	nop			;ffa3	00		.
	nop			;ffa4	00		.
	nop			;ffa5	00		.
	nop			;ffa6	00		.
	nop			;ffa7	00		.
	nop			;ffa8	00		.
	nop			;ffa9	00		.
	nop			;ffaa	00		.
	nop			;ffab	00		.
	nop			;ffac	00		.
	nop			;ffad	00		.
	nop			;ffae	00		.
	nop			;ffaf	00		.
	nop			;ffb0	00		.
	nop			;ffb1	00		.
	nop			;ffb2	00		.
	nop			;ffb3	00		.
	nop			;ffb4	00		.
	nop			;ffb5	00		.
	nop			;ffb6	00		.
	nop			;ffb7	00		.
	nop			;ffb8	00		.
	nop			;ffb9	00		.
	nop			;ffba	00		.
	nop			;ffbb	00		.
	nop			;ffbc	00		.
	nop			;ffbd	00		.
	nop			;ffbe	00		.
	nop			;ffbf	00		.
	nop			;ffc0	00		.
	nop			;ffc1	00		.
	nop			;ffc2	00		.
	nop			;ffc3	00		.
	nop			;ffc4	00		.
	nop			;ffc5	00		.
	nop			;ffc6	00		.
	nop			;ffc7	00		.
	nop			;ffc8	00		.
	nop			;ffc9	00		.
	nop			;ffca	00		.
	nop			;ffcb	00		.
	nop			;ffcc	00		.
	nop			;ffcd	00		.
	nop			;ffce	00		.
	nop			;ffcf	00		.
	nop			;ffd0	00		.
	nop			;ffd1	00		.
	nop			;ffd2	00		.
	nop			;ffd3	00		.
	nop			;ffd4	00		.
	nop			;ffd5	00		.
	nop			;ffd6	00		.
	nop			;ffd7	00		.
	nop			;ffd8	00		.
	nop			;ffd9	00		.
	nop			;ffda	00		.
	nop			;ffdb	00		.
	nop			;ffdc	00		.
	nop			;ffdd	00		.
	nop			;ffde	00		.
	nop			;ffdf	00		.
	nop			;ffe0	00		.
	nop			;ffe1	00		.
	nop			;ffe2	00		.
	nop			;ffe3	00		.
	nop			;ffe4	00		.
	nop			;ffe5	00		.
	nop			;ffe6	00		.
	nop			;ffe7	00		.
	nop			;ffe8	00		.
