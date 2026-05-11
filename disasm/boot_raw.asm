; z80dasm 1.2.0
; command line: z80dasm -a -l -g 0x0000 -t -o disasm/boot_raw.asm ROMs/MICRAL_P2_CHARGEUR.BIN

	org 00000h

l0000h:
	ld sp,0bee8h		;0000	31 e8 be	1 . .
	ld a,022h		;0003	3e 22		> "
	out (020h),a		;0005	d3 20		.  
	ld b,030h		;0007	06 30		. 0
l0009h:
	djnz l0009h		;0009	10 fe		. .
	xor a			;000b	af		.
	out (020h),a		;000c	d3 20		.  
	ld a,003h		;000e	3e 03		> .
	out (060h),a		;0010	d3 60		. `
	ld a,020h		;0012	3e 20		>  
	out (070h),a		;0014	d3 70		. p
l0016h:
	ld a,003h		;0016	3e 03		> .
	out (060h),a		;0018	d3 60		. `
	in a,(070h)		;001a	db 70		. p
	and 020h		;001c	e6 20		.  
	jr nz,l0016h		;001e	20 f6		  .
	ld a,006h		;0020	3e 06		> .
	out (060h),a		;0022	d3 60		. `
	ld a,0ffh		;0024	3e ff		> .
	out (070h),a		;0026	d3 70		. p
	ld a,007h		;0028	3e 07		> .
	out (060h),a		;002a	d3 60		. `
	ld a,0ffh		;002c	3e ff		> .
	out (070h),a		;002e	d3 70		. p
	jp l05fah		;0030	c3 fa 05	. . .
	nop			;0033	00		.
	nop			;0034	00		.
	nop			;0035	00		.
	nop			;0036	00		.
	nop			;0037	00		.
	inc d			;0038	14		.
	out (007h),a		;0039	d3 07		. .
	ei			;003b	fb		.
l003ch:
	ret			;003c	c9		.
	nop			;003d	00		.
	nop			;003e	00		.
	nop			;003f	00		.
	nop			;0040	00		.
	nop			;0041	00		.
	nop			;0042	00		.
	nop			;0043	00		.
	nop			;0044	00		.
	nop			;0045	00		.
	nop			;0046	00		.
	nop			;0047	00		.
	nop			;0048	00		.
	nop			;0049	00		.
	nop			;004a	00		.
	nop			;004b	00		.
	nop			;004c	00		.
	nop			;004d	00		.
	nop			;004e	00		.
	nop			;004f	00		.
	nop			;0050	00		.
	nop			;0051	00		.
	nop			;0052	00		.
	nop			;0053	00		.
	nop			;0054	00		.
	nop			;0055	00		.
	nop			;0056	00		.
	nop			;0057	00		.
	nop			;0058	00		.
	nop			;0059	00		.
	nop			;005a	00		.
	nop			;005b	00		.
	nop			;005c	00		.
	nop			;005d	00		.
	nop			;005e	00		.
	nop			;005f	00		.
	nop			;0060	00		.
	nop			;0061	00		.
	nop			;0062	00		.
	nop			;0063	00		.
	nop			;0064	00		.
	nop			;0065	00		.
	ex af,af'		;0066	08		.
	in a,(013h)		;0067	db 13		. .
	ld (hl),a		;0069	77		w
	inc hl			;006a	23		#
	ex af,af'		;006b	08		.
	retn			;006c	ed 45		. E
sub_006eh:
	ld a,019h		;006e	3e 19		> .
	ld (0bff7h),a		;0070	32 f7 bf	2 . .
	xor a			;0073	af		.
	ld (0bff3h),a		;0074	32 f3 bf	2 . .
	ld (0bff8h),a		;0077	32 f8 bf	2 . .
	ld a,001h		;007a	3e 01		> .
	ld (0bffah),a		;007c	32 fa bf	2 . .
	ld a,02eh		;007f	3e 2e		> .
	ld (0bff9h),a		;0081	32 f9 bf	2 . .
	call sub_05a5h		;0084	cd a5 05	. . .
	ld a,080h		;0087	3e 80		> .
	ld (0bff8h),a		;0089	32 f8 bf	2 . .
	call sub_05a5h		;008c	cd a5 05	. . .
	call sub_055dh		;008f	cd 5d 05	. ] .
	ret			;0092	c9		.
l0093h:
	ld sp,0bee8h		;0093	31 e8 be	1 . .
	xor a			;0096	af		.
	ld (0bff3h),a		;0097	32 f3 bf	2 . .
	ld hl,l078ah		;009a	21 8a 07	! . .
l009dh:
	ld c,(hl)		;009d	4e		N
	call sub_04cdh		;009e	cd cd 04	. . .
	inc hl			;00a1	23		#
	ld a,(hl)		;00a2	7e		~
	or a			;00a3	b7		.
	jr nz,l009dh		;00a4	20 f7		  .
	ld b,000h		;00a6	06 00		. .
	call sub_04c9h		;00a8	cd c9 04	. . .
	ld a,c			;00ab	79		y
	cp 00dh			;00ac	fe 0d		. .
	jp z,l0326h		;00ae	ca 26 03	. & .
	ex af,af'		;00b1	08		.
	ld c,03ah		;00b2	0e 3a		. :
	call sub_04cdh		;00b4	cd cd 04	. . .
	ex af,af'		;00b7	08		.
	cp 02ah			;00b8	fe 2a		. *
	jp z,l0318h		;00ba	ca 18 03	. . .
	cp 04dh			;00bd	fe 4d		. M
	jp z,l034fh		;00bf	ca 4f 03	. O .
	cp 042h			;00c2	fe 42		. B
	jr z,l00d2h		;00c4	28 0c		( .
	cp 047h			;00c6	fe 47		. G
	jp z,l033eh		;00c8	ca 3e 03	. > .
l00cbh:
	ld c,006h		;00cb	0e 06		. .
	call sub_04cdh		;00cd	cd cd 04	. . .
	jr l0093h		;00d0	18 c1		. .
l00d2h:
	ex af,af'		;00d2	08		.
	call sub_02f1h		;00d3	cd f1 02	. . .
	dec b			;00d6	05		.
	jp m,l0330h		;00d7	fa 30 03	. 0 .
	ld a,c			;00da	79		y
	cp 02ch			;00db	fe 2c		. ,
	jr nz,l00cbh		;00dd	20 ec		  .
	ld a,d			;00df	7a		z
	or a			;00e0	b7		.
	jr nz,l00cbh		;00e1	20 e8		  .
	or e			;00e3	b3		.
	cp 002h			;00e4	fe 02		. .
	jr nc,l00cbh		;00e6	30 e3		0 .
	push af			;00e8	f5		.
	call sub_02f1h		;00e9	cd f1 02	. . .
	dec b			;00ec	05		.
	ld a,c			;00ed	79		y
	pop bc			;00ee	c1		.
	jp m,l00cbh		;00ef	fa cb 00	. . .
	cp 00dh			;00f2	fe 0d		. .
	jr nz,l00cbh		;00f4	20 d5		  .
l00f6h:
	di			;00f6	f3		.
	ld (0bfedh),de		;00f7	ed 53 ed bf	. S . .
	ex af,af'		;00fb	08		.
	ld (0bee8h),a		;00fc	32 e8 be	2 . .
l00ffh:
	ld hl,0bff3h		;00ff	21 f3 bf	! . .
	dec b			;0102	05		.
	jr z,l0109h		;0103	28 04		( .
	set 2,(hl)		;0105	cb d6		. .
	jr l010bh		;0107	18 02		. .
l0109h:
	set 3,(hl)		;0109	cb de		. .
l010bh:
	set 4,(hl)		;010b	cb e6		. .
	ld a,(hl)		;010d	7e		~
	out (020h),a		;010e	d3 20		.  
	ld hl,l07a8h		;0110	21 a8 07	! . .
	ld (0bff5h),hl		;0113	22 f5 bf	" . .
l0116h:
	in a,(010h)		;0116	db 10		. .
	bit 7,a			;0118	cb 7f		. .
	jr nz,l0116h		;011a	20 fa		  .
	ld de,0c000h		;011c	11 00 c0	. . .
l011fh:
	ex (sp),hl		;011f	e3		.
	ex (sp),hl		;0120	e3		.
	dec de			;0121	1b		.
	ld a,e			;0122	7b		{
	or d			;0123	b2		.
	jr nz,l011fh		;0124	20 f9		  .
l0126h:
	call sub_0251h		;0126	cd 51 02	. Q .
	ld hl,(0bff5h)		;0129	2a f5 bf	* . .
	ld a,(hl)		;012c	7e		~
	rlca			;012d	07		.
	inc hl			;012e	23		#
	ld l,(hl)		;012f	6e		n
	ld h,a			;0130	67		g
	ld (0bff1h),hl		;0131	22 f1 bf	" . .
	ld a,000h		;0134	3e 00		> .
	ld (0bff4h),a		;0136	32 f4 bf	2 . .
	inc a			;0139	3c		<
	ld (0bfefh),a		;013a	32 ef bf	2 . .
	call sub_02d2h		;013d	cd d2 02	. . .
	dec a			;0140	3d		=
	jr nz,l0126h		;0141	20 e3		  .
	ld a,(0beebh)		;0143	3a eb be	: . .
	ld hl,0fffdh		;0146	21 fd ff	! . .
	ld (hl),000h		;0149	36 00		6 .
	bit 7,a			;014b	cb 7f		. .
	jr z,l0151h		;014d	28 02		( .
	set 1,(hl)		;014f	cb ce		. .
l0151h:
	bit 6,a			;0151	cb 77		. w
	jr z,l0157h		;0153	28 02		( .
	set 2,(hl)		;0155	cb d6		. .
l0157h:
	ld hl,l0000h		;0157	21 00 00	! . .
	ld (0bfebh),hl		;015a	22 eb bf	" . .
l015dh:
	call sub_01bdh		;015d	cd bd 01	. . .
	and a			;0160	a7		.
	jp z,l00cbh		;0161	ca cb 00	. . .
	ld c,a			;0164	4f		O
	call sub_01bdh		;0165	cd bd 01	. . .
	ld b,a			;0168	47		G
	ld a,c			;0169	79		y
	cp 003h			;016a	fe 03		. .
	jr c,l0179h		;016c	38 0b		8 .
	call sub_01bdh		;016e	cd bd 01	. . .
	ld h,a			;0171	67		g
	call sub_01bdh		;0172	cd bd 01	. . .
	ld l,a			;0175	6f		o
	call sub_01bdh		;0176	cd bd 01	. . .
l0179h:
	ld a,b			;0179	78		x
	cp 0c2h			;017a	fe c2		. .
	jr z,l0196h		;017c	28 18		( .
	cp 0d2h			;017e	fe d2		. .
	jp z,l00cbh		;0180	ca cb 00	. . .
	cp 0c6h			;0183	fe c6		. .
	jr z,l019dh		;0185	28 16		( .
	cp 0c1h			;0187	fe c1		. .
	jp c,l00cbh		;0189	da cb 00	. . .
	cp 0dbh			;018c	fe db		. .
	jp nc,l00cbh		;018e	d2 cb 00	. . .
l0191h:
	call sub_01bdh		;0191	cd bd 01	. . .
	jr l0191h		;0194	18 fb		. .
l0196h:
	call sub_01bdh		;0196	cd bd 01	. . .
	ld (hl),a		;0199	77		w
	inc hl			;019a	23		#
	jr l0196h		;019b	18 f9		. .
l019dh:
	di			;019d	f3		.
	push hl			;019e	e5		.
	push de			;019f	d5		.
	ld hl,l01b0h		;01a0	21 b0 01	! . .
	ld de,0bee9h		;01a3	11 e9 be	. . .
	ld bc,0000dh		;01a6	01 0d 00	. . .
	ldir			;01a9	ed b0		. .
	pop de			;01ab	d1		.
	pop hl			;01ac	e1		.
	jp 0bee9h		;01ad	c3 e9 be	. . .
l01b0h:
	ld a,(0bff3h)		;01b0	3a f3 bf	: . .
	or 040h			;01b3	f6 40		. @
	ld (0ffffh),a		;01b5	32 ff ff	2 . .
	ld a,040h		;01b8	3e 40		> @
	out (020h),a		;01ba	d3 20		.  
	jp (hl)			;01bc	e9		.
sub_01bdh:
	inc c			;01bd	0c		.
	dec c			;01be	0d		.
	jr nz,l01c5h		;01bf	20 04		  .
	pop af			;01c1	f1		.
	inc c			;01c2	0c		.
	jr l015dh		;01c3	18 98		. .
l01c5h:
	push hl			;01c5	e5		.
	ld hl,(0bfebh)		;01c6	2a eb bf	* . .
	ld a,h			;01c9	7c		|
	or l			;01ca	b5		.
	jr nz,l01ebh		;01cb	20 1e		  .
	push hl			;01cd	e5		.
	push de			;01ce	d5		.
	push bc			;01cf	c5		.
	ld hl,(0bff1h)		;01d0	2a f1 bf	* . .
	ex de,hl		;01d3	eb		.
	ld hl,(0bfedh)		;01d4	2a ed bf	* . .
	call sub_01fah		;01d7	cd fa 01	. . .
	ld (0bfedh),hl		;01da	22 ed bf	" . .
	pop bc			;01dd	c1		.
	pop de			;01de	d1		.
	pop hl			;01df	e1		.
	ld hl,l00ffh		;01e0	21 ff 00	! . .
	ld (0bfebh),hl		;01e3	22 eb bf	" . .
	ld hl,0bee9h		;01e6	21 e9 be	! . .
	jr l01f2h		;01e9	18 07		. .
l01ebh:
	dec hl			;01eb	2b		+
	ld (0bfebh),hl		;01ec	22 eb bf	" . .
	ld hl,(0bfe9h)		;01ef	2a e9 bf	* . .
l01f2h:
	ld a,(hl)		;01f2	7e		~
	inc hl			;01f3	23		#
	ld (0bfe9h),hl		;01f4	22 e9 bf	" . .
	pop hl			;01f7	e1		.
	dec c			;01f8	0d		.
	ret			;01f9	c9		.
sub_01fah:
	push hl			;01fa	e5		.
	push de			;01fb	d5		.
	call sub_0240h		;01fc	cd 40 02	. @ .
	ld a,b			;01ff	78		x
	inc a			;0200	3c		<
	ld (0bfefh),a		;0201	32 ef bf	2 . .
	ld a,l			;0204	7d		}
	pop de			;0205	d1		.
	cp d			;0206	ba		.
	jp nc,l00cbh		;0207	d2 cb 00	. . .
	ld b,000h		;020a	06 00		. .
	ld a,l			;020c	7d		}
	or a			;020d	b7		.
	rra			;020e	1f		.
	jr nc,l0213h		;020f	30 02		0 .
	ld b,002h		;0211	06 02		. .
l0213h:
	ld (0bff0h),a		;0213	32 f0 bf	2 . .
	ld a,b			;0216	78		x
	ld (0bff4h),a		;0217	32 f4 bf	2 . .
l021ah:
	call sub_0274h		;021a	cd 74 02	. t .
	jr nz,l023bh		;021d	20 1c		  .
	ld hl,0bff3h		;021f	21 f3 bf	! . .
	ld a,(0bff0h)		;0222	3a f0 bf	: . .
	cp 016h			;0225	fe 16		. .
	jr c,l022dh		;0227	38 04		8 .
	set 7,(hl)		;0229	cb fe		. .
	jr l022fh		;022b	18 02		. .
l022dh:
	res 7,(hl)		;022d	cb be		. .
l022fh:
	ld a,(hl)		;022f	7e		~
	out (020h),a		;0230	d3 20		.  
	call sub_02d2h		;0232	cd d2 02	. . .
	dec a			;0235	3d		=
	jr nz,l023bh		;0236	20 03		  .
	pop hl			;0238	e1		.
	inc hl			;0239	23		#
	ret			;023a	c9		.
l023bh:
	call sub_0251h		;023b	cd 51 02	. Q .
	jr l021ah		;023e	18 da		. .
sub_0240h:
	xor a			;0240	af		.
	ld d,010h		;0241	16 10		. .
l0243h:
	add hl,hl		;0243	29		)
	rla			;0244	17		.
	jr c,l024ah		;0245	38 03		8 .
	cp e			;0247	bb		.
	jr c,l024ch		;0248	38 02		8 .
l024ah:
	inc l			;024a	2c		,
	sub e			;024b	93		.
l024ch:
	dec d			;024c	15		.
	jr nz,l0243h		;024d	20 f4		  .
	ld b,a			;024f	47		G
	ret			;0250	c9		.
sub_0251h:
	ld a,0d0h		;0251	3e d0		> .
	call sub_02cah		;0253	cd ca 02	. . .
	ld a,00fh		;0256	3e 0f		> .
	call sub_02cah		;0258	cd ca 02	. . .
l025bh:
	in a,(010h)		;025b	db 10		. .
	bit 0,a			;025d	cb 47		. G
	jr nz,l025bh		;025f	20 fa		  .
	bit 2,a			;0261	cb 57		. W
	jr nz,l0267h		;0263	20 02		  .
	ld a,0ffh		;0265	3e ff		> .
l0267h:
	push af			;0267	f5		.
	push hl			;0268	e5		.
	ld hl,003e8h		;0269	21 e8 03	! . .
l026ch:
	dec hl			;026c	2b		+
	ld a,h			;026d	7c		|
	or l			;026e	b5		.
	jr nz,l026ch		;026f	20 fb		  .
	pop hl			;0271	e1		.
	pop af			;0272	f1		.
	ret			;0273	c9		.
sub_0274h:
	ld a,0d0h		;0274	3e d0		> .
	call sub_02cah		;0276	cd ca 02	. . .
l0279h:
	in a,(010h)		;0279	db 10		. .
	bit 0,a			;027b	cb 47		. G
	jr nz,l0279h		;027d	20 fa		  .
	push bc			;027f	c5		.
	ld b,002h		;0280	06 02		. .
l0282h:
	ld a,0c4h		;0282	3e c4		> .
	call sub_02cah		;0284	cd ca 02	. . .
l0287h:
	in a,(010h)		;0287	db 10		. .
	bit 0,a			;0289	cb 47		. G
	jr z,l02a8h		;028b	28 1b		( .
	jr l0287h		;028d	18 f8		. .
l028fh:
	ld a,0d0h		;028f	3e d0		> .
	call sub_02cah		;0291	cd ca 02	. . .
	ld a,05fh		;0294	3e 5f		> _
	call sub_02cah		;0296	cd ca 02	. . .
l0299h:
	in a,(010h)		;0299	db 10		. .
	bit 0,a			;029b	cb 47		. G
	jr nz,l0299h		;029d	20 fa		  .
	dec b			;029f	05		.
	jr nz,l0282h		;02a0	20 e0		  .
	call sub_0251h		;02a2	cd 51 02	. Q .
	pop bc			;02a5	c1		.
	jr sub_0274h		;02a6	18 cc		. .
l02a8h:
	bit 4,a			;02a8	cb 67		. g
	jr nz,l028fh		;02aa	20 e3		  .
	bit 3,a			;02ac	cb 5f		. _
	jr nz,l028fh		;02ae	20 df		  .
	pop bc			;02b0	c1		.
	in a,(012h)		;02b1	db 12		. .
	out (011h),a		;02b3	d3 11		. .
	ld a,(0bff0h)		;02b5	3a f0 bf	: . .
	out (013h),a		;02b8	d3 13		. .
	ld a,01fh		;02ba	3e 1f		> .
	call sub_02cah		;02bc	cd ca 02	. . .
l02bfh:
	in a,(010h)		;02bf	db 10		. .
	bit 0,a			;02c1	cb 47		. G
	jr nz,l02bfh		;02c3	20 fa		  .
	and 018h		;02c5	e6 18		. .
	jr nz,sub_0274h		;02c7	20 ab		  .
	ret			;02c9	c9		.
sub_02cah:
	out (010h),a		;02ca	d3 10		. .
	ld a,040h		;02cc	3e 40		> @
l02ceh:
	dec a			;02ce	3d		=
	ret z			;02cf	c8		.
	jr l02ceh		;02d0	18 fc		. .
sub_02d2h:
	ld a,(0bfefh)		;02d2	3a ef bf	: . .
	out (012h),a		;02d5	d3 12		. .
	ld hl,0bee9h		;02d7	21 e9 be	! . .
	ld b,088h		;02da	06 88		. .
	ld a,(0bff4h)		;02dc	3a f4 bf	: . .
	or b			;02df	b0		.
	call sub_02cah		;02e0	cd ca 02	. . .
l02e3h:
	in a,(010h)		;02e3	db 10		. .
	bit 0,a			;02e5	cb 47		. G
	jr nz,l02e3h		;02e7	20 fa		  .
	and 03ch		;02e9	e6 3c		. <
	ld a,000h		;02eb	3e 00		> .
	ret nz			;02ed	c0		.
	ld a,001h		;02ee	3e 01		> .
	ret			;02f0	c9		.
sub_02f1h:
	ld de,l0000h		;02f1	11 00 00	. . .
	ld b,e			;02f4	43		C
l02f5h:
	call sub_04c9h		;02f5	cd c9 04	. . .
	ld a,c			;02f8	79		y
	sub 030h		;02f9	d6 30		. 0
	cp 00ah			;02fb	fe 0a		. .
	jr c,l0304h		;02fd	38 05		8 .
	cp 011h			;02ff	fe 11		. .
	ret c			;0301	d8		.
	sub 007h		;0302	d6 07		. .
l0304h:
	cp 010h			;0304	fe 10		. .
	ccf			;0306	3f		?
	ret c			;0307	d8		.
	inc b			;0308	04		.
	ld l,a			;0309	6f		o
	ld h,000h		;030a	26 00		& .
	ld a,010h		;030c	3e 10		> .
l030eh:
	add hl,de		;030e	19		.
	jp c,l00cbh		;030f	da cb 00	. . .
	dec a			;0312	3d		=
	jr nz,l030eh		;0313	20 f9		  .
	ex de,hl		;0315	eb		.
	jr l02f5h		;0316	18 dd		. .
l0318h:
	call sub_0477h		;0318	cd 77 04	. w .
	cp 01bh			;031b	fe 1b		. .
	jp z,l0093h		;031d	ca 93 00	. . .
	ld c,a			;0320	4f		O
	call sub_04cdh		;0321	cd cd 04	. . .
	jr l0318h		;0324	18 f2		. .
l0326h:
	ld hl,00080h		;0326	21 80 00	! . .
	ld a,042h		;0329	3e 42		> B
	ex de,hl		;032b	eb		.
	ex af,af'		;032c	08		.
	jp l00f6h		;032d	c3 f6 00	. . .
l0330h:
	ld a,c			;0330	79		y
	cp 00dh			;0331	fe 0d		. .
	jp nz,l00cbh		;0333	c2 cb 00	. . .
	ld b,000h		;0336	06 00		. .
	ld de,l0000h+1		;0338	11 01 00	. . .
	jp l00f6h		;033b	c3 f6 00	. . .
l033eh:
	call sub_02f1h		;033e	cd f1 02	. . .
	dec b			;0341	05		.
	jp m,l00cbh		;0342	fa cb 00	. . .
	ld a,c			;0345	79		y
	cp 00dh			;0346	fe 0d		. .
	jp nz,l00cbh		;0348	c2 cb 00	. . .
	ex de,hl		;034b	eb		.
	jp l019dh		;034c	c3 9d 01	. . .
l034fh:
	call sub_044dh		;034f	cd 4d 04	. M .
	ld c,004h		;0352	0e 04		. .
	call sub_04cdh		;0354	cd cd 04	. . .
	call sub_04c9h		;0357	cd c9 04	. . .
	push bc			;035a	c5		.
	ld c,03ah		;035b	0e 3a		. :
	call sub_04cdh		;035d	cd cd 04	. . .
	pop bc			;0360	c1		.
	ld a,c			;0361	79		y
	cp 052h			;0362	fe 52		. R
	jp z,l0093h		;0364	ca 93 00	. . .
	cp 047h			;0367	fe 47		. G
	jr z,l033eh		;0369	28 d3		( .
	cp 044h			;036b	fe 44		. D
	jr z,l0382h		;036d	28 13		( .
	cp 04dh			;036f	fe 4d		. M
	jr z,l0382h		;0371	28 0f		( .
	cp 049h			;0373	fe 49		. I
	jr z,l0382h		;0375	28 0b		( .
	cp 04fh			;0377	fe 4f		. O
	jr z,l0382h		;0379	28 07		( .
l037bh:
	ld c,006h		;037b	0e 06		. .
	call sub_04cdh		;037d	cd cd 04	. . .
	jr l034fh		;0380	18 cd		. .
l0382h:
	ex af,af'		;0382	08		.
	call sub_02f1h		;0383	cd f1 02	. . .
	dec b			;0386	05		.
	jp m,l034fh		;0387	fa 4f 03	. O .
	ex af,af'		;038a	08		.
	cp 04dh			;038b	fe 4d		. M
	jr z,l0400h		;038d	28 71		( q
	cp 049h			;038f	fe 49		. I
	jr z,l03e0h		;0391	28 4d		( M
	ex af,af'		;0393	08		.
	ld a,c			;0394	79		y
	cp 02ch			;0395	fe 2c		. ,
	jr nz,l037bh		;0397	20 e2		  .
	push de			;0399	d5		.
	call sub_02f1h		;039a	cd f1 02	. . .
	pop hl			;039d	e1		.
	dec b			;039e	05		.
	jp m,l037bh		;039f	fa 7b 03	. { .
	ld a,c			;03a2	79		y
	cp 00dh			;03a3	fe 0d		. .
	jr nz,l037bh		;03a5	20 d4		  .
	ex af,af'		;03a7	08		.
	cp 04fh			;03a8	fe 4f		. O
	jr z,l03f4h		;03aa	28 48		( H
	call sub_0447h		;03ac	cd 47 04	. G .
	jr nc,l037bh		;03af	30 ca		0 .
	ex de,hl		;03b1	eb		.
	push hl			;03b2	e5		.
l03b3h:
	call sub_044dh		;03b3	cd 4d 04	. M .
l03b6h:
	call sub_0465h		;03b6	cd 65 04	. e .
	ld a,004h		;03b9	3e 04		> .
	ex af,af'		;03bb	08		.
l03bch:
	ld b,004h		;03bc	06 04		. .
l03beh:
	ld a,(de)		;03be	1a		.
	call sub_0451h		;03bf	cd 51 04	. Q .
	inc de			;03c2	13		.
	pop hl			;03c3	e1		.
	call sub_0447h		;03c4	cd 47 04	. G .
	jp z,l034fh		;03c7	ca 4f 03	. O .
	push hl			;03ca	e5		.
	ld a,e			;03cb	7b		{
	or a			;03cc	b7		.
	jr z,l03b3h		;03cd	28 e4		( .
	ld c,020h		;03cf	0e 20		.  
	call sub_04cdh		;03d1	cd cd 04	. . .
	djnz l03beh		;03d4	10 e8		. .
	call sub_04cdh		;03d6	cd cd 04	. . .
	ex af,af'		;03d9	08		.
	dec a			;03da	3d		=
	jr z,l03b6h		;03db	28 d9		( .
	ex af,af'		;03dd	08		.
	jr l03bch		;03de	18 dc		. .
l03e0h:
	ld a,c			;03e0	79		y
	cp 00dh			;03e1	fe 0d		. .
	jp nz,l037bh		;03e3	c2 7b 03	. { .
	call sub_0465h		;03e6	cd 65 04	. e .
	ld b,d			;03e9	42		B
	ld c,e			;03ea	4b		K
	in d,(c)		;03eb	ed 50		. P
	ld a,d			;03ed	7a		z
	call sub_0451h		;03ee	cd 51 04	. Q .
	jp l034fh		;03f1	c3 4f 03	. O .
l03f4h:
	ld a,d			;03f4	7a		z
	or a			;03f5	b7		.
	jp nz,l037bh		;03f6	c2 7b 03	. { .
	ld b,h			;03f9	44		D
	ld c,l			;03fa	4d		M
	out (c),e		;03fb	ed 59		. Y
	jp l034fh		;03fd	c3 4f 03	. O .
l0400h:
	ld a,c			;0400	79		y
	cp 00dh			;0401	fe 0d		. .
	jp nz,l037bh		;0403	c2 7b 03	. { .
l0406h:
	call sub_0465h		;0406	cd 65 04	. e .
	ex de,hl		;0409	eb		.
	push hl			;040a	e5		.
	ld a,(hl)		;040b	7e		~
	call sub_0451h		;040c	cd 51 04	. Q .
	ld c,020h		;040f	0e 20		.  
	call sub_04cdh		;0411	cd cd 04	. . .
	call sub_02f1h		;0414	cd f1 02	. . .
	pop hl			;0417	e1		.
	ld a,c			;0418	79		y
	cp 02eh			;0419	fe 2e		. .
	jp z,l034fh		;041b	ca 4f 03	. O .
	cp 00dh			;041e	fe 0d		. .
	jp nz,l037bh		;0420	c2 7b 03	. { .
	dec b			;0423	05		.
	jp m,l0428h		;0424	fa 28 04	. ( .
	ld (hl),e		;0427	73		s
l0428h:
	inc hl			;0428	23		#
	ex de,hl		;0429	eb		.
	jr l0406h		;042a	18 da		. .
sub_042ch:
	and 00fh		;042c	e6 0f		. .
	add a,090h		;042e	c6 90		. .
	daa			;0430	27		'
	adc a,040h		;0431	ce 40		. @
	daa			;0433	27		'
	ret			;0434	c9		.
	ld a,l			;0435	7d		}
	cpl			;0436	2f		/
	ld l,a			;0437	6f		o
	ld a,h			;0438	7c		|
	cpl			;0439	2f		/
	ld h,a			;043a	67		g
	inc hl			;043b	23		#
	add hl,de		;043c	19		.
	ret			;043d	c9		.
	push bc			;043e	c5		.
	ld b,a			;043f	47		G
	ld a,l			;0440	7d		}
	sub b			;0441	90		.
	ld l,a			;0442	6f		o
	pop bc			;0443	c1		.
	ret nc			;0444	d0		.
	dec h			;0445	25		%
	ret			;0446	c9		.
sub_0447h:
	ld a,h			;0447	7c		|
	cp d			;0448	ba		.
	ret nz			;0449	c0		.
	ld a,l			;044a	7d		}
	cp e			;044b	bb		.
	ret			;044c	c9		.
sub_044dh:
	ld c,00dh		;044d	0e 0d		. .
	jr sub_04cdh		;044f	18 7c		. |
sub_0451h:
	push af			;0451	f5		.
	call sub_042ch		;0452	cd 2c 04	. , .
	ld h,a			;0455	67		g
	pop af			;0456	f1		.
	rra			;0457	1f		.
	rra			;0458	1f		.
	rra			;0459	1f		.
	rra			;045a	1f		.
	call sub_042ch		;045b	cd 2c 04	. , .
	ld c,a			;045e	4f		O
	call sub_04cdh		;045f	cd cd 04	. . .
	ld c,h			;0462	4c		L
	jr sub_04cdh		;0463	18 68		. h
sub_0465h:
	call sub_044dh		;0465	cd 4d 04	. M .
	ld a,d			;0468	7a		z
	call sub_0451h		;0469	cd 51 04	. Q .
	ld a,e			;046c	7b		{
	call sub_0451h		;046d	cd 51 04	. Q .
	ld c,020h		;0470	0e 20		.  
	call sub_04cdh		;0472	cd cd 04	. . .
	jr sub_04cdh		;0475	18 56		. V
sub_0477h:
	ld a,007h		;0477	3e 07		> .
	out (060h),a		;0479	d3 60		. `
	in a,(070h)		;047b	db 70		. p
	bit 1,a			;047d	cb 4f		. O
	jr z,l0493h		;047f	28 12		( .
	push af			;0481	f5		.
	xor a			;0482	af		.
	ld (0bffch),a		;0483	32 fc bf	2 . .
	pop af			;0486	f1		.
	bit 0,a			;0487	cb 47		. G
	jr z,sub_0477h		;0489	28 ec		( .
l048bh:
	in a,(030h)		;048b	db 30		. 0
	and 07fh		;048d	e6 7f		. .
	ld (0bffdh),a		;048f	32 fd bf	2 . .
	ret			;0492	c9		.
l0493h:
	ld a,(0bffch)		;0493	3a fc bf	: . .
	or a			;0496	b7		.
	jr z,l04adh		;0497	28 14		( .
	in a,(070h)		;0499	db 70		. p
	bit 0,a			;049b	cb 47		. G
	jr nz,l048bh		;049d	20 ec		  .
	push bc			;049f	c5		.
	ld bc,00a00h		;04a0	01 00 0a	. . .
l04a3h:
	dec bc			;04a3	0b		.
	ld a,b			;04a4	78		x
	or c			;04a5	b1		.
	jr nz,l04a3h		;04a6	20 fb		  .
	pop bc			;04a8	c1		.
l04a9h:
	ld a,(0bffdh)		;04a9	3a fd bf	: . .
	ret			;04ac	c9		.
l04adh:
	ld a,001h		;04ad	3e 01		> .
	ld (0bffch),a		;04af	32 fc bf	2 . .
l04b2h:
	in a,(070h)		;04b2	db 70		. p
	bit 0,a			;04b4	cb 47		. G
	jr z,l04b2h		;04b6	28 fa		( .
	in a,(030h)		;04b8	db 30		. 0
	ld (0bffdh),a		;04ba	32 fd bf	2 . .
	in a,(070h)		;04bd	db 70		. p
	bit 1,a			;04bf	cb 4f		. O
	jr z,l04a9h		;04c1	28 e6		( .
	xor a			;04c3	af		.
	ld (0bffch),a		;04c4	32 fc bf	2 . .
	jr l04a9h		;04c7	18 e0		. .
sub_04c9h:
	call sub_0477h		;04c9	cd 77 04	. w .
	ld c,a			;04cc	4f		O
sub_04cdh:
	push bc			;04cd	c5		.
	push de			;04ce	d5		.
	push hl			;04cf	e5		.
	ld a,c			;04d0	79		y
	cp 00dh			;04d1	fe 0d		. .
	jr z,l04eeh		;04d3	28 19		( .
	cp 00ah			;04d5	fe 0a		. .
	jr z,l04feh		;04d7	28 25		( %
	ld (0bff9h),a		;04d9	32 f9 bf	2 . .
	ld a,00eh		;04dc	3e 0e		> .
	ld (0bffah),a		;04de	32 fa bf	2 . .
	call sub_05a5h		;04e1	cd a5 05	. . .
	call sub_0506h		;04e4	cd 06 05	. . .
l04e7h:
	call sub_05dch		;04e7	cd dc 05	. . .
	pop hl			;04ea	e1		.
	pop de			;04eb	d1		.
	pop bc			;04ec	c1		.
	ret			;04ed	c9		.
l04eeh:
	call sub_05ech		;04ee	cd ec 05	. . .
	call sub_051fh		;04f1	cd 1f 05	. . .
	call sub_04f9h		;04f4	cd f9 04	. . .
	jr l04e7h		;04f7	18 ee		. .
sub_04f9h:
	xor a			;04f9	af		.
	ld (0bff8h),a		;04fa	32 f8 bf	2 . .
	ret			;04fd	c9		.
l04feh:
	call sub_05ech		;04fe	cd ec 05	. . .
	call sub_051fh		;0501	cd 1f 05	. . .
	jr l04e7h		;0504	18 e1		. .
sub_0506h:
	ld a,(0bff8h)		;0506	3a f8 bf	: . .
	cp 0a7h			;0509	fe a7		. .
	jr z,l0518h		;050b	28 0b		( .
	bit 7,a			;050d	cb 7f		. .
	jr z,l0512h		;050f	28 01		( .
	inc a			;0511	3c		<
l0512h:
	xor 080h		;0512	ee 80		. .
	ld (0bff8h),a		;0514	32 f8 bf	2 . .
	ret			;0517	c9		.
l0518h:
	call sub_04f9h		;0518	cd f9 04	. . .
	call sub_051fh		;051b	cd 1f 05	. . .
	ret			;051e	c9		.
sub_051fh:
	ld a,(0bff7h)		;051f	3a f7 bf	: . .
	cp 018h			;0522	fe 18		. .
	jr z,l052eh		;0524	28 08		( .
	ld a,(0bff7h)		;0526	3a f7 bf	: . .
	inc a			;0529	3c		<
	ld (0bff7h),a		;052a	32 f7 bf	2 . .
	ret			;052d	c9		.
l052eh:
	ld a,(0bff8h)		;052e	3a f8 bf	: . .
	push af			;0531	f5		.
	ld a,(0bffbh)		;0532	3a fb bf	: . .
	inc a			;0535	3c		<
	ld (0bffbh),a		;0536	32 fb bf	2 . .
	cp 019h			;0539	fe 19		. .
	jr z,l0555h		;053b	28 18		( .
	out (004h),a		;053d	d3 04		. .
l053fh:
	xor a			;053f	af		.
	ld (0bff8h),a		;0540	32 f8 bf	2 . .
	ld a,020h		;0543	3e 20		>  
	ld (0bff9h),a		;0545	32 f9 bf	2 . .
	ld a,00eh		;0548	3e 0e		> .
	ld (0bffah),a		;054a	32 fa bf	2 . .
	call sub_0587h		;054d	cd 87 05	. . .
	pop af			;0550	f1		.
	ld (0bff8h),a		;0551	32 f8 bf	2 . .
	ret			;0554	c9		.
l0555h:
	xor a			;0555	af		.
	ld (0bffbh),a		;0556	32 fb bf	2 . .
	out (003h),a		;0559	d3 03		. .
	jr l053fh		;055b	18 e2		. .
sub_055dh:
	xor a			;055d	af		.
l055eh:
	ld (0bff7h),a		;055e	32 f7 bf	2 . .
	xor a			;0561	af		.
	ld (0bff8h),a		;0562	32 f8 bf	2 . .
	ld a,020h		;0565	3e 20		>  
	ld (0bff9h),a		;0567	32 f9 bf	2 . .
	ld a,00eh		;056a	3e 0e		> .
	ld (0bffah),a		;056c	32 fa bf	2 . .
	call sub_0587h		;056f	cd 87 05	. . .
	ld a,(0bff7h)		;0572	3a f7 bf	: . .
	inc a			;0575	3c		<
	cp 019h			;0576	fe 19		. .
	jr nz,l055eh		;0578	20 e4		  .
	xor a			;057a	af		.
	ld (0bff8h),a		;057b	32 f8 bf	2 . .
	out (003h),a		;057e	d3 03		. .
	ld (0bffbh),a		;0580	32 fb bf	2 . .
	call sub_05dch		;0583	cd dc 05	. . .
	ret			;0586	c9		.
sub_0587h:
	call sub_05a5h		;0587	cd a5 05	. . .
	ld a,(0bff8h)		;058a	3a f8 bf	: . .
	inc a			;058d	3c		<
	ld (0bff8h),a		;058e	32 f8 bf	2 . .
	bit 7,a			;0591	cb 7f		. .
	jr nz,l05a0h		;0593	20 0b		  .
	cp 028h			;0595	fe 28		. (
	jr nz,sub_0587h		;0597	20 ee		  .
	ld a,080h		;0599	3e 80		> .
	ld (0bff8h),a		;059b	32 f8 bf	2 . .
	jr sub_0587h		;059e	18 e7		. .
l05a0h:
	cp 0a8h			;05a0	fe a8		. .
	jr nz,sub_0587h		;05a2	20 e3		  .
	ret			;05a4	c9		.
sub_05a5h:
	ld hl,0bff7h		;05a5	21 f7 bf	! . .
	ld a,(hl)		;05a8	7e		~
	out (000h),a		;05a9	d3 00		. .
	inc hl			;05ab	23		#
	ld d,(hl)		;05ac	56		V
	ld a,(hl)		;05ad	7e		~
	or 040h			;05ae	f6 40		. @
	ld b,a			;05b0	47		G
	inc hl			;05b1	23		#
	ld c,(hl)		;05b2	4e		N
	inc hl			;05b3	23		#
	ld e,(hl)		;05b4	5e		^
	ld hl,0bff3h		;05b5	21 f3 bf	! . .
	set 5,(hl)		;05b8	cb ee		. .
	ld a,006h		;05ba	3e 06		> .
	out (060h),a		;05bc	d3 60		. `
l05beh:
	in a,(070h)		;05be	db 70		. p
	bit 0,a			;05c0	cb 47		. G
	jr z,l05beh		;05c2	28 fa		( .
	ld a,(hl)		;05c4	7e		~
	res 5,(hl)		;05c5	cb ae		. .
	ld h,(hl)		;05c7	66		f
	push hl			;05c8	e5		.
	pop hl			;05c9	e1		.
	out (020h),a		;05ca	d3 20		.  
	ld a,b			;05cc	78		x
	out (001h),a		;05cd	d3 01		. .
	ld a,c			;05cf	79		y
	out (002h),a		;05d0	d3 02		. .
	ld a,d			;05d2	7a		z
	out (001h),a		;05d3	d3 01		. .
	ld a,e			;05d5	7b		{
	out (002h),a		;05d6	d3 02		. .
	ld a,h			;05d8	7c		|
	out (020h),a		;05d9	d3 20		.  
	ret			;05db	c9		.
sub_05dch:
	ld a,020h		;05dc	3e 20		>  
	ld (0bff9h),a		;05de	32 f9 bf	2 . .
	ld a,00eh		;05e1	3e 0e		> .
	xor 0c0h		;05e3	ee c0		. .
	ld (0bffah),a		;05e5	32 fa bf	2 . .
	call sub_05a5h		;05e8	cd a5 05	. . .
	ret			;05eb	c9		.
sub_05ech:
	ld a,020h		;05ec	3e 20		>  
	ld (0bff9h),a		;05ee	32 f9 bf	2 . .
	ld a,00eh		;05f1	3e 0e		> .
	ld (0bffah),a		;05f3	32 fa bf	2 . .
	call sub_05a5h		;05f6	cd a5 05	. . .
	ret			;05f9	c9		.
l05fah:
	ex af,af'		;05fa	08		.
	xor a			;05fb	af		.
	ex af,af'		;05fc	08		.
	ld a,020h		;05fd	3e 20		>  
	out (020h),a		;05ff	d3 20		.  
	xor a			;0601	af		.
	ld c,000h		;0602	0e 00		. .
l0604h:
	ld d,000h		;0604	16 00		. .
	out (000h),a		;0606	d3 00		. .
	ld h,a			;0608	67		g
	ld a,d			;0609	7a		z
l060ah:
	rrca			;060a	0f		.
	ld b,a			;060b	47		G
	or 040h			;060c	f6 40		. @
	out (001h),a		;060e	d3 01		. .
	ld a,c			;0610	79		y
	out (002h),a		;0611	d3 02		. .
	add a,055h		;0613	c6 55		. U
	ld c,a			;0615	4f		O
	ld a,b			;0616	78		x
	out (001h),a		;0617	d3 01		. .
	ld a,c			;0619	79		y
	out (002h),a		;061a	d3 02		. .
	add a,055h		;061c	c6 55		. U
	ld c,a			;061e	4f		O
	inc d			;061f	14		.
	ld a,d			;0620	7a		z
	cp 050h			;0621	fe 50		. P
	jr nz,l060ah		;0623	20 e5		  .
	ld a,h			;0625	7c		|
	inc a			;0626	3c		<
	cp 019h			;0627	fe 19		. .
	jr nz,l0604h		;0629	20 d9		  .
	xor a			;062b	af		.
	ld c,000h		;062c	0e 00		. .
l062eh:
	ld d,000h		;062e	16 00		. .
	out (000h),a		;0630	d3 00		. .
	ld h,a			;0632	67		g
	ld a,d			;0633	7a		z
l0634h:
	rrca			;0634	0f		.
	ld b,a			;0635	47		G
	or 040h			;0636	f6 40		. @
	out (001h),a		;0638	d3 01		. .
	in a,(002h)		;063a	db 02		. .
	cp c			;063c	b9		.
	jr nz,l0661h		;063d	20 22		  "
	add a,055h		;063f	c6 55		. U
	ld c,a			;0641	4f		O
	xor a			;0642	af		.
	out (002h),a		;0643	d3 02		. .
	ld a,b			;0645	78		x
	out (001h),a		;0646	d3 01		. .
	in a,(002h)		;0648	db 02		. .
	cp c			;064a	b9		.
	jr nz,l0661h		;064b	20 14		  .
	add a,055h		;064d	c6 55		. U
	ld c,a			;064f	4f		O
	xor a			;0650	af		.
	out (002h),a		;0651	d3 02		. .
	inc d			;0653	14		.
	ld a,d			;0654	7a		z
	cp 050h			;0655	fe 50		. P
	jr nz,l0634h		;0657	20 db		  .
	ld a,h			;0659	7c		|
	inc a			;065a	3c		<
	cp 019h			;065b	fe 19		. .
	jr nz,l062eh		;065d	20 cf		  .
	jr l0665h		;065f	18 04		. .
l0661h:
	ex af,af'		;0661	08		.
	set 0,a			;0662	cb c7		. .
	ex af,af'		;0664	08		.
l0665h:
	ld hl,08000h		;0665	21 00 80	! . .
	ld de,08000h		;0668	11 00 80	. . .
	jr l0671h		;066b	18 04		. .
l066dh:
	ld a,060h		;066d	3e 60		> `
	out (020h),a		;066f	d3 20		.  
l0671h:
	ld c,080h		;0671	0e 80		. .
	ld a,000h		;0673	3e 00		> .
l0675h:
	ld b,000h		;0675	06 00		. .
l0677h:
	ld (hl),a		;0677	77		w
	inc hl			;0678	23		#
	add a,055h		;0679	c6 55		. U
	djnz l0677h		;067b	10 fa		. .
	dec c			;067d	0d		.
	jr nz,l0675h		;067e	20 f5		  .
	ld hl,l0000h		;0680	21 00 00	! . .
	add hl,de		;0683	19		.
	ld c,080h		;0684	0e 80		. .
	ld a,000h		;0686	3e 00		> .
l0688h:
	ld b,000h		;0688	06 00		. .
l068ah:
	cp (hl)			;068a	be		.
	jr nz,l069ah		;068b	20 0d		  .
	inc hl			;068d	23		#
	add a,055h		;068e	c6 55		. U
	djnz l068ah		;0690	10 f8		. .
	dec c			;0692	0d		.
	jr nz,l0688h		;0693	20 f3		  .
	ld hl,l0000h		;0695	21 00 00	! . .
	jr l06a9h		;0698	18 0f		. .
l069ah:
	ld a,h			;069a	7c		|
	or l			;069b	b5		.
	jr z,l06a2h		;069c	28 04		( .
	ex af,af'		;069e	08		.
	set 1,a			;069f	cb cf		. .
	ex af,af'		;06a1	08		.
l06a2h:
	ld a,020h		;06a2	3e 20		>  
	out (020h),a		;06a4	d3 20		.  
	jp l06c0h		;06a6	c3 c0 06	. . .
l06a9h:
	ld hl,l066dh		;06a9	21 6d 06	! m .
	ld de,0866dh		;06ac	11 6d 86	. m .
	ld bc,l003ch		;06af	01 3c 00	. < .
	ldir			;06b2	ed b0		. .
	ld hl,l0000h		;06b4	21 00 00	! . .
	ld de,l0000h		;06b7	11 00 00	. . .
	ld (08698h),hl		;06ba	22 98 86	" . .
	jp 0866dh		;06bd	c3 6d 86	. m .
l06c0h:
	ld a,0d0h		;06c0	3e d0		> .
	out (010h),a		;06c2	d3 10		. .
	xor a			;06c4	af		.
l06c5h:
	ld c,a			;06c5	4f		O
	out (011h),a		;06c6	d3 11		. .
	add a,055h		;06c8	c6 55		. U
	out (012h),a		;06ca	d3 12		. .
	add a,055h		;06cc	c6 55		. U
	out (013h),a		;06ce	d3 13		. .
	ld b,050h		;06d0	06 50		. P
l06d2h:
	djnz l06d2h		;06d2	10 fe		. .
	in a,(011h)		;06d4	db 11		. .
	cp c			;06d6	b9		.
	jr nz,l06f4h		;06d7	20 1b		  .
	add a,055h		;06d9	c6 55		. U
	ld c,a			;06db	4f		O
	in a,(012h)		;06dc	db 12		. .
	cp c			;06de	b9		.
	jr nz,l06f4h		;06df	20 13		  .
	add a,055h		;06e1	c6 55		. U
	ld c,a			;06e3	4f		O
	in a,(013h)		;06e4	db 13		. .
	cp c			;06e6	b9		.
	jr nz,l06f4h		;06e7	20 0b		  .
	add a,055h		;06e9	c6 55		. U
	or a			;06eb	b7		.
	jr z,l06fch		;06ec	28 0e		( .
	ld b,050h		;06ee	06 50		. P
l06f0h:
	djnz l06f0h		;06f0	10 fe		. .
	jr l06c5h		;06f2	18 d1		. .
l06f4h:
	ex af,af'		;06f4	08		.
	set 2,a			;06f5	cb d7		. .
	ex af,af'		;06f7	08		.
	ld a,0d0h		;06f8	3e d0		> .
	out (010h),a		;06fa	d3 10		. .
l06fch:
	ld a,020h		;06fc	3e 20		>  
	out (020h),a		;06fe	d3 20		.  
	ld a,04eh		;0700	3e 4e		> N
	out (052h),a		;0702	d3 52		. R
	ld a,03eh		;0704	3e 3e		> >
	out (052h),a		;0706	d3 52		. R
	ld a,0a7h		;0708	3e a7		> .
	out (053h),a		;070a	d3 53		. S
	ld c,000h		;070c	0e 00		. .
l070eh:
	ld d,0ffh		;070e	16 ff		. .
l0710h:
	dec d			;0710	15		.
	jr z,l0730h		;0711	28 1d		( .
	in a,(051h)		;0713	db 51		. Q
	and 001h		;0715	e6 01		. .
	jr z,l0710h		;0717	28 f7		( .
	ld a,c			;0719	79		y
	out (050h),a		;071a	d3 50		. P
	xor a			;071c	af		.
l071dh:
	dec ix			;071d	dd 2b		. +
	dec a			;071f	3d		=
	jr nz,l071dh		;0720	20 fb		  .
	in a,(050h)		;0722	db 50		. P
	cp c			;0724	b9		.
	jr nz,l0730h		;0725	20 09		  .
	add a,055h		;0727	c6 55		. U
	ld c,a			;0729	4f		O
	or a			;072a	b7		.
	jr nz,l070eh		;072b	20 e1		  .
	jp l0734h		;072d	c3 34 07	. 4 .
l0730h:
	ex af,af'		;0730	08		.
	set 3,a			;0731	cb df		. .
	ex af,af'		;0733	08		.
l0734h:
	ld hl,l0000h		;0734	21 00 00	! . .
	ld d,000h		;0737	16 00		. .
	im 1			;0739	ed 56		. V
	ei			;073b	fb		.
l073ch:
	dec hl			;073c	2b		+
	ld a,h			;073d	7c		|
	or l			;073e	b5		.
	jr nz,l073ch		;073f	20 fb		  .
	di			;0741	f3		.
	ld a,d			;0742	7a		z
	cp 023h			;0743	fe 23		. #
	jr c,l074bh		;0745	38 04		8 .
	cp 025h			;0747	fe 25		. %
	jr c,l074fh		;0749	38 04		8 .
l074bh:
	ex af,af'		;074b	08		.
	set 4,a			;074c	cb e7		. .
	ex af,af'		;074e	08		.
l074fh:
	di			;074f	f3		.
	call sub_006eh		;0750	cd 6e 00	. n .
	ld hl,l0798h		;0753	21 98 07	! . .
l0756h:
	ld c,(hl)		;0756	4e		N
	call sub_04cdh		;0757	cd cd 04	. . .
	inc hl			;075a	23		#
	ld a,(hl)		;075b	7e		~
	or a			;075c	b7		.
	jr nz,l0756h		;075d	20 f7		  .
	ex af,af'		;075f	08		.
	or a			;0760	b7		.
	jr nz,l0770h		;0761	20 0d		  .
	ld c,04fh		;0763	0e 4f		. O
	call sub_04cdh		;0765	cd cd 04	. . .
	ld c,04bh		;0768	0e 4b		. K
	call sub_04cdh		;076a	cd cd 04	. . .
	jp l0093h		;076d	c3 93 00	. . .
l0770h:
	ld b,008h		;0770	06 08		. .
	ld e,a			;0772	5f		_
	ld d,030h		;0773	16 30		. 0
l0775h:
	srl e			;0775	cb 3b		. ;
	jr c,l077fh		;0777	38 06		8 .
l0779h:
	inc d			;0779	14		.
	djnz l0775h		;077a	10 f9		. .
	jp l0093h		;077c	c3 93 00	. . .
l077fh:
	ld c,00dh		;077f	0e 0d		. .
	call sub_04cdh		;0781	cd cd 04	. . .
	ld c,d			;0784	4a		J
	call sub_04cdh		;0785	cd cd 04	. . .
	jr l0779h		;0788	18 ef		. .
l078ah:
	dec c			;078a	0d		.
	ld a,(bc)		;078b	0a		.
	jr nz,l07dbh		;078c	20 4d		  M
	jr nz,l07e0h		;078e	20 50		  P
	jr nz,l07c4h		;0790	20 32		  2
	jr nz,l07c2h		;0792	20 2e		  .
	ld l,02eh		;0794	2e 2e		. .
	jr nz,l0798h		;0796	20 00		  .
l0798h:
	dec c			;0798	0d		.
	ld a,(bc)		;0799	0a		.
	jr nz,l07ddh		;079a	20 41		  A
	ld d,l			;079c	55		U
	ld d,h			;079d	54		T
	ld c,a			;079e	4f		O
	dec l			;079f	2d		-
	ld d,h			;07a0	54		T
	ld b,l			;07a1	45		E
	ld d,e			;07a2	53		S
	ld d,h			;07a3	54		T
	jr nz,l07e0h		;07a4	20 3a		  :
	jr nz,l07a8h		;07a6	20 00		  .
l07a8h:
	jr nz,l07bah		;07a8	20 10		  .
	nop			;07aa	00		.
	nop			;07ab	00		.
	nop			;07ac	00		.
	nop			;07ad	00		.
	nop			;07ae	00		.
	nop			;07af	00		.
	nop			;07b0	00		.
	nop			;07b1	00		.
	nop			;07b2	00		.
	nop			;07b3	00		.
	nop			;07b4	00		.
	nop			;07b5	00		.
	nop			;07b6	00		.
	nop			;07b7	00		.
	nop			;07b8	00		.
	nop			;07b9	00		.
l07bah:
	nop			;07ba	00		.
	nop			;07bb	00		.
	nop			;07bc	00		.
	nop			;07bd	00		.
	nop			;07be	00		.
	nop			;07bf	00		.
	nop			;07c0	00		.
	nop			;07c1	00		.
l07c2h:
	nop			;07c2	00		.
	nop			;07c3	00		.
l07c4h:
	nop			;07c4	00		.
	nop			;07c5	00		.
	nop			;07c6	00		.
	nop			;07c7	00		.
	nop			;07c8	00		.
	nop			;07c9	00		.
	nop			;07ca	00		.
	nop			;07cb	00		.
	nop			;07cc	00		.
	nop			;07cd	00		.
	nop			;07ce	00		.
	nop			;07cf	00		.
	nop			;07d0	00		.
	nop			;07d1	00		.
	nop			;07d2	00		.
	nop			;07d3	00		.
	nop			;07d4	00		.
	nop			;07d5	00		.
	nop			;07d6	00		.
	nop			;07d7	00		.
	nop			;07d8	00		.
	nop			;07d9	00		.
	nop			;07da	00		.
l07dbh:
	nop			;07db	00		.
	nop			;07dc	00		.
l07ddh:
	nop			;07dd	00		.
	nop			;07de	00		.
	nop			;07df	00		.
l07e0h:
	nop			;07e0	00		.
	nop			;07e1	00		.
	nop			;07e2	00		.
	nop			;07e3	00		.
	nop			;07e4	00		.
	nop			;07e5	00		.
	nop			;07e6	00		.
	nop			;07e7	00		.
	nop			;07e8	00		.
	nop			;07e9	00		.
	nop			;07ea	00		.
	nop			;07eb	00		.
	nop			;07ec	00		.
	nop			;07ed	00		.
	nop			;07ee	00		.
	nop			;07ef	00		.
	nop			;07f0	00		.
	nop			;07f1	00		.
	nop			;07f2	00		.
	nop			;07f3	00		.
	nop			;07f4	00		.
	nop			;07f5	00		.
	nop			;07f6	00		.
	nop			;07f7	00		.
	nop			;07f8	00		.
	nop			;07f9	00		.
	nop			;07fa	00		.
	nop			;07fb	00		.
	nop			;07fc	00		.
	nop			;07fd	00		.
	nop			;07fe	00		.
	nop			;07ff	00		.
