; z80dasm 1.2.0
; command line: z80dasm -a -l -g 0 -b blocks.def ../ROMs/olympia_boss_system_251-462.bin

	org 00000h


; BLOCK 'code' (start 0x0000 end 0x0697)
code_start:
	jp l0007h		;0000
	di			;0003
l0004h:
	jp l0043h		;0004
l0007h:
	ld sp,0bed2h		;0007
	ld a,0bch		;000a
	out (043h),a		;000c
	ld a,005h		;000e
	out (043h),a		;0010
	ld a,009h		;0012
	out (043h),a		;0014
	xor a			;0016
	ld (0bffeh),a		;0017
	call sub_05fdh		;001a
	call sub_0635h		;001d
	xor a			;0020
	ld (0ffeeh),a		;0021
	ld a,01bh		;0024
	ld (0ffefh),a		;0026
	xor a			;0029
	out (081h),a		;002a
	ld hl,crt_init_data_start	;002c
	ld b,005h		;002f
l0031h:
	ld a,(hl)		;0031
	out (080h),a		;0032
	inc hl			;0034
	djnz l0031h		;0035
	ld a,0a0h		;0037
	out (081h),a		;0039
	ld a,042h		;003b
	out (081h),a		;003d
	ld a,0c0h		;003f
	out (081h),a		;0041
l0043h:
	ld sp,0bed2h		;0043
	call sub_05cfh		;0046
	ld a,020h		;0049
	out (081h),a		;004b
	xor a			;004d
	out (031h),a		;004e
	ld hl,sio_init_data_start	;0050
	ld b,00ah		;0053
l0055h:
	ld a,(hl)		;0055
	out (031h),a		;0056
	inc hl			;0058
	ld a,(hl)		;0059
	out (030h),a		;005a
	inc hl			;005c
	djnz l0055h		;005d
	ld a,040h		;005f
	out (031h),a		;0061
	ld a,0a1h		;0063
	out (031h),a		;0065
	ld a,007h		;0067
	ld i,a			;0069
	im 2			;006b
	ld a,02fh		;006d
	out (031h),a		;006f
	ld a,02ch		;0071
	out (031h),a		;0073
	ld a,020h		;0075
	out (031h),a		;0077
	ei			;0079
l007ah:
	ld sp,0bed2h		;007a
	ld hl,prompt_str_start	;007d
l0080h:
	ld c,(hl)		;0080
	call sub_0552h		;0081
	inc hl			;0084
	ld a,(hl)		;0085
	or a			;0086
	jp nz,l0080h		;0087
	ld b,000h		;008a
	call sub_054eh		;008c
	ld a,c			;008f
	cp 00dh			;0090
	jp z,l04f4h		;0092
	ex af,af'		;0095
	ld c,03ah		;0096
	call sub_0552h		;0098
	ex af,af'		;009b
	cp 02ah			;009c
	jp z,l04e5h		;009e
	cp 042h			;00a1
	jp z,l00b8h		;00a3
	cp 04ch			;00a6
	jp z,l00b8h		;00a8
	cp 047h			;00ab
	jp z,l0516h		;00ad
l00b0h:
	ld c,023h		;00b0
	call sub_0552h		;00b2
	jp l007ah		;00b5
l00b8h:
	ex af,af'		;00b8
	call sub_03aeh		;00b9
	dec b			;00bc
	jp m,l0508h		;00bd
	ld a,c			;00c0
	cp 02ch			;00c1
	jp nz,l00b0h		;00c3
	ld a,d			;00c6
	or a			;00c7
	jp nz,l00b0h		;00c8
	or e			;00cb
	cp 004h			;00cc
	jp nc,l00b0h		;00ce
	push af			;00d1
	call sub_03aeh		;00d2
	dec b			;00d5
	ld a,c			;00d6
	pop bc			;00d7
	jp m,l00b0h		;00d8
	cp 00dh			;00db
	jp nz,l00b0h		;00dd
l00e0h:
	ld (0bfd7h),de		;00e0
	ex af,af'		;00e4
	ld (0bed2h),a		;00e5
	cp 04ch			;00e8
	jp z,l03e2h		;00ea
	ld a,002h		;00ed
	out (060h),a		;00ef
	ld de,084c6h		;00f1
l00f4h:
	ex (sp),hl		;00f4
	ex (sp),hl		;00f5
	dec de			;00f6
	ld a,e			;00f7
	or d			;00f8
	jp nz,l00f4h		;00f9
	ld a,b			;00fc
	ld (0bfe9h),a		;00fd
	in a,(060h)		;0100
	ld c,a			;0102
	and 080h		;0103
	rrca			;0105
	ld (0bff8h),a		;0106
	ld a,c			;0109
	rlca			;010a
	rlca			;010b
	and 003h		;010c
	ld hl,floppy_params1_start	;010e
	jp nz,l011ch		;0111
	ld a,040h		;0114
	ld (0bff8h),a		;0116
	jp l012dh		;0119
l011ch:
	ld hl,floppy_params3_start	;011c
	dec a			;011f
	jp z,l012dh		;0120
	ld hl,floppy_params1_start	;0123
	dec a			;0126
	jp z,l012dh		;0127
	ld hl,floppy_params2_start	;012a
l012dh:
	ld (0bff9h),hl		;012d
	ld de,0bfe5h		;0130
	ld a,003h		;0133
	ld (de),a		;0135
	inc de			;0136
	ld c,002h		;0137
	call sub_02bch		;0139
	ld c,003h		;013c
	ld hl,0bfe5h		;013e
	call sub_0386h		;0141
	ld hl,0ffffh		;0144
	ld (0bfe1h),hl		;0147
	ld (0bfe3h),hl		;014a
	ld hl,0bfe8h		;014d
	ld (hl),004h		;0150
	ld c,002h		;0152
	call sub_0386h		;0154
	call sub_0363h		;0157
	ld a,(hl)		;015a
	and 008h		;015b
	rlca			;015d
	rlca			;015e
	rlca			;015f
	rlca			;0160
	ld hl,0bff8h		;0161
	or (hl)			;0164
	or 006h			;0165
	ld (0bfe8h),a		;0167
	ld hl,(0bff9h)		;016a
	inc hl			;016d
	inc hl			;016e
	rlca			;016f
	ld a,(hl)		;0170
	jp nc,l0175h		;0171
	rlca			;0174
l0175h:
	ld b,a			;0175
	in a,(060h)		;0176
	and 020h		;0178
	ld a,b			;017a
	jp z,l017fh		;017b
	rlca			;017e
l017fh:
	ld b,a			;017f
	inc hl			;0180
	inc hl			;0181
	ld a,(0bff8h)		;0182
	or a			;0185
	ld a,(hl)		;0186
	jp nz,l018bh		;0187
	rrca			;018a
l018bh:
	ld l,a			;018b
	ld h,b			;018c
	ld (0bffch),hl		;018d
l0190h:
	ld hl,code_start	;0190
	ld (0bfd5h),hl		;0193
l0196h:
	call sub_01f3h		;0196
	and a			;0199
	jp z,l00b0h		;019a
	ld c,a			;019d
	call sub_01f3h		;019e
	ld b,a			;01a1
	ld a,c			;01a2
	cp 003h			;01a3
	jp c,l01b3h		;01a5
	call sub_01f3h		;01a8
	ld h,a			;01ab
	call sub_01f3h		;01ac
	ld l,a			;01af
	call sub_01f3h		;01b0
l01b3h:
	ld a,b			;01b3
	cp 0c2h			;01b4
	jp z,l01d3h		;01b6
	cp 0d2h			;01b9
	jp z,l00b0h		;01bb
	cp 0c6h			;01be
	jp z,l01dbh		;01c0
	cp 0c1h			;01c3
	jp c,l00b0h		;01c5
	cp 0dbh			;01c8
	jp nc,l00b0h		;01ca
l01cdh:
	call sub_01f3h		;01cd
	jp l01cdh		;01d0
l01d3h:
	call sub_01f3h		;01d3
	ld (hl),a		;01d6
	inc hl			;01d7
	jp l01d3h		;01d8
l01dbh:
	di			;01db
	push hl			;01dc
	push de			;01dd
	ld hl,l01eeh		;01de
	ld de,0bed3h		;01e1
	ld bc,l0004h+1		;01e4
	ldir			;01e7
	pop de			;01e9
	pop hl			;01ea
	jp 0bed3h		;01eb
l01eeh:
	ld a,001h		;01ee
	out (060h),a		;01f0
	jp (hl)			;01f2
sub_01f3h:
	inc c			;01f3
	dec c			;01f4
	jp nz,l01fdh		;01f5
	pop af			;01f8
	inc c			;01f9
	jp l0196h		;01fa
l01fdh:
	push hl			;01fd
	ld hl,(0bfd5h)		;01fe
	ld a,h			;0201
	or l			;0202
	jp nz,l0225h		;0203
	push hl			;0206
	push de			;0207
	push bc			;0208
	ld hl,(0bffch)		;0209
	ex de,hl		;020c
	ld hl,(0bfd7h)		;020d
	call sub_0234h		;0210
	ld (0bfd7h),hl		;0213
	pop bc			;0216
	pop de			;0217
	pop hl			;0218
	ld hl,000ffh		;0219
	ld (0bfd5h),hl		;021c
	ld hl,0bed3h		;021f
	jp l022ch		;0222
l0225h:
	dec hl			;0225
	ld (0bfd5h),hl		;0226
	ld hl,(0bfd3h)		;0229
l022ch:
	ld a,(hl)		;022c
	inc hl			;022d
	ld (0bfd3h),hl		;022e
	pop hl			;0231
	dec c			;0232
	ret			;0233
sub_0234h:
	ld a,(0bed2h)		;0234
	cp 04ch			;0237
	jp z,l0447h		;0239
	push hl			;023c
	push de			;023d
	call sub_02d2h		;023e
	ld a,(0bff8h)		;0241
	or a			;0244
	ld a,b			;0245
	jp nz,l024ah		;0246
	add a,a			;0249
l024ah:
	inc a			;024a
	ld (0bfech),a		;024b
	ld a,l			;024e
	pop de			;024f
	cp d			;0250
	jp nc,l00b0h		;0251
	ld a,(0bfe8h)		;0254
	rlca			;0257
	ld b,000h		;0258
	ld a,l			;025a
	jp nc,l0265h		;025b
	or a			;025e
	rra			;025f
	jp nc,l0265h		;0260
	ld b,004h		;0263
l0265h:
	ld (0bfeah),a		;0265
	ld hl,0bfe9h		;0268
	ld a,(hl)		;026b
	and 0fbh		;026c
	or b			;026e
	ld (hl),a		;026f
	ld a,b			;0270
	rrca			;0271
	rrca			;0272
	ld (0bfebh),a		;0273
	ld hl,(0bff9h)		;0276
	inc hl			;0279
	inc hl			;027a
	inc hl			;027b
	ld c,004h		;027c
	ld de,0bfedh		;027e
	call sub_02bch		;0281
l0284h:
	ld a,0d3h		;0284
	di			;0286
	out (000h),a		;0287
	ld a,0beh		;0289
	out (000h),a		;028b
	ld a,0ffh		;028d
	out (001h),a		;028f
	ld a,040h		;0291
	out (001h),a		;0293
	ei			;0295
	ld a,0c5h		;0296
	out (008h),a		;0298
	call sub_02e6h		;029a
	ld c,009h		;029d
	ld hl,0bfe8h		;029f
	call sub_0399h		;02a2
	dec a			;02a5
	jp nz,l02ach		;02a6
	pop hl			;02a9
	inc hl			;02aa
	ret			;02ab
l02ach:
	ld a,(0bff2h)		;02ac
	and 084h		;02af
	jp z,l0284h		;02b1
	call sub_02c5h		;02b4
	ld (hl),0ffh		;02b7
	jp l0284h		;02b9
sub_02bch:
	ld a,(hl)		;02bc
	ld (de),a		;02bd
	inc hl			;02be
	inc de			;02bf
	dec c			;02c0
	jp nz,sub_02bch		;02c1
	ret			;02c4
sub_02c5h:
	ld a,(0bfe9h)		;02c5
	and 003h		;02c8
	ld hl,0bfe1h		;02ca
sub_02cdh:
	add a,l			;02cd
	ld l,a			;02ce
	ret nc			;02cf
	inc h			;02d0
	ret			;02d1
sub_02d2h:
	xor a			;02d2
	ld d,010h		;02d3
l02d5h:
	add hl,hl		;02d5
	rla			;02d6
	jp c,l02deh		;02d7
	cp e			;02da
	jp c,l02e0h		;02db
l02deh:
	inc l			;02de
	sub e			;02df
l02e0h:
	dec d			;02e0
	jp nz,l02d5h		;02e1
	ld b,a			;02e4
	ret			;02e5
sub_02e6h:
	call sub_02c5h		;02e6
	ld a,(hl)		;02e9
	inc a			;02ea
	jp z,l0311h		;02eb
l02eeh:
	ld a,(0bfeah)		;02ee
	cp (hl)			;02f1
	ret z			;02f2
	or a			;02f3
	ex de,hl		;02f4
	jp z,l031bh		;02f5
	ld hl,0bfe7h		;02f8
	ld (hl),a		;02fb
	ld b,00fh		;02fc
	ld c,003h		;02fe
sub_0300h:
	ld hl,0bfe6h		;0300
	ld a,(0bfe9h)		;0303
	ld (hl),a		;0306
	dec hl			;0307
	ld (hl),b		;0308
	call sub_0399h		;0309
	ld a,(0bfeah)		;030c
	ld (de),a		;030f
	ret			;0310
l0311h:
	ex de,hl		;0311
	call l031bh		;0312
	ex de,hl		;0315
	ld (hl),000h		;0316
	jp l02eeh		;0318
l031bh:
	ld b,007h		;031b
	ld c,002h		;031d
	call sub_0300h		;031f
	ld a,(0bffbh)		;0322
	dec a			;0325
	ld a,000h		;0326
	ret z			;0328
	jp l031bh		;0329
	push af			;032c
	ld a,03ah		;032d
	out (031h),a		;032f
	ei			;0331
	push bc			;0332
	push hl			;0333
l0334h:
	call sub_0363h		;0334
	ld a,b			;0337
	and a			;0338
	jp z,l0356h		;0339
	ld hl,0bff1h		;033c
	ld a,(hl)		;033f
	rlca			;0340
	jp c,l0351h		;0341
	rlca			;0344
	jp c,l0351h		;0345
	ld a,001h		;0348
l034ah:
	ld (0bffbh),a		;034a
	pop hl			;034d
	pop bc			;034e
	pop af			;034f
	ret			;0350
l0351h:
	ld a,07fh		;0351
	jp l034ah		;0353
l0356h:
	ld hl,0bfe5h		;0356
	ld (hl),008h		;0359
	ld c,001h		;035b
	call sub_037fh		;035d
	jp l0334h		;0360
sub_0363h:
	ld hl,0bff0h		;0363
	ld b,000h		;0366
l0368h:
	in a,(010h)		;0368
	rlca			;036a
	jp nc,l0368h		;036b
	ld c,a			;036e
	and 020h		;036f
	ret z			;0371
	ld a,c			;0372
	rlca			;0373
	jp nc,l0368h		;0374
	in a,(011h)		;0377
	inc hl			;0379
	inc b			;037a
	ld (hl),a		;037b
	jp l0368h		;037c
sub_037fh:
	in a,(010h)		;037f
	and 010h		;0381
	jp nz,sub_037fh		;0383
sub_0386h:
	in a,(010h)		;0386
	rlca			;0388
	jp nc,sub_0386h		;0389
	rlca			;038c
	jp c,sub_0386h		;038d
	ld a,(hl)		;0390
	out (011h),a		;0391
	inc hl			;0393
	dec c			;0394
	jp nz,sub_0386h		;0395
	ret			;0398
sub_0399h:
	call sub_037fh		;0399
	xor a			;039c
	ld (0bffbh),a		;039d
	di			;03a0
	ld a,02ah		;03a1
	out (031h),a		;03a3
	ei			;03a5
l03a6h:
	ld a,(0bffbh)		;03a6
	or a			;03a9
	jp z,l03a6h		;03aa
	ret			;03ad
sub_03aeh:
	ld de,code_start	;03ae
	ld b,e			;03b1
l03b2h:
	call sub_054eh		;03b2
	ld a,c			;03b5
	sub 030h		;03b6
	cp 00ah			;03b8
	jp c,l03c2h		;03ba
	cp 011h			;03bd
	ret c			;03bf
	sub 007h		;03c0
l03c2h:
	cp 010h			;03c2
	ccf			;03c4
	ret c			;03c5
	inc b			;03c6
	ld l,a			;03c7
	ld h,000h		;03c8
	ld a,010h		;03ca
l03cch:
	add hl,de		;03cc
	jp c,l00b0h		;03cd
	dec a			;03d0
	jp nz,l03cch		;03d1
	ex de,hl		;03d4
	jp l03b2h		;03d5
	ei			;03d8
	ret			;03d9
	ei			;03da
	push af			;03db
	ld a,07fh		;03dc
	out (031h),a		;03de
	pop af			;03e0
	ret			;03e1
l03e2h:
	dec b			;03e2
	jp p,l00b0h		;03e3
	out (071h),a		;03e6
	ld hl,0bfd9h		;03e8
	ld (hl),001h		;03eb
	inc hl			;03ed
	ld (hl),001h		;03ee
	inc hl			;03f0
	xor a			;03f1
	ld (hl),a		;03f2
	ld hl,0bfdfh		;03f3
	ld (hl),a		;03f6
	inc hl			;03f7
	ld (hl),a		;03f8
	ex de,hl		;03f9
	ld de,l0080h		;03fa
	add hl,de		;03fd
	ld e,020h		;03fe
	call sub_02d2h		;0400
	ex de,hl		;0403
	ld hl,0bfddh		;0404
	ld (hl),b		;0407
	inc hl			;0408
	ld a,e			;0409
	and 003h		;040a
	ld (hl),a		;040c
	ex de,hl		;040d
	ld de,l0004h		;040e
	call sub_02d2h		;0411
	ld a,h			;0414
	or a			;0415
	jp nz,l00b0h		;0416
	or l			;0419
	ld (0bfdch),a		;041a
	call sub_04a3h		;041d
	jp nz,l00b0h		;0420
	call sub_04c9h		;0423
	ld hl,fdc_cmds_start	;0426
	call sub_04dbh		;0429
	ld c,042h		;042c
	call sub_04d3h		;042e
	and 002h		;0431
	jp nz,l043eh		;0433
	ld hl,lookup_table_start	;0436
	ld b,020h		;0439
	call sub_04ddh		;043b
l043eh:
	call sub_04b1h		;043e
	jp nz,l00b0h		;0441
	jp l0190h		;0444
l0447h:
	push hl			;0447
l0448h:
	call sub_0469h		;0448
	jp nz,l0448h		;044b
	ld hl,0bfdeh		;044e
	inc (hl)		;0451
	ld a,01fh		;0452
	cp (hl)			;0454
	jp nc,l0466h		;0455
	ld (hl),000h		;0458
	dec hl			;045a
	inc (hl)		;045b
	ld a,003h		;045c
	cp (hl)			;045e
	jp nc,l0466h		;045f
	ld (hl),000h		;0462
	dec hl			;0464
	inc (hl)		;0465
l0466h:
	pop hl			;0466
	inc hl			;0467
	ret			;0468
sub_0469h:
	call sub_04c9h		;0469
	ld hl,0bfd9h		;046c
	call sub_04dbh		;046f
l0472h:
	ld c,082h		;0472
	call sub_04d3h		;0474
	and 002h		;0477
	jp nz,l0472h		;0479
	ld hl,0bed3h		;047c
	ld b,000h		;047f
l0481h:
	in a,(073h)		;0481
	cpl			;0483
	ld (hl),a		;0484
	inc hl			;0485
	djnz l0481h		;0486
	call sub_04b1h		;0488
	ret z			;048b
	push af			;048c
	cp 008h			;048d
	jp z,l049eh		;048f
	cp 003h			;0492
	jp nc,l0499h		;0494
l0497h:
	pop af			;0497
	ret			;0498
l0499h:
	cp 006h			;0499
	jp nc,l0497h		;049b
l049eh:
	call sub_04a3h		;049e
	pop af			;04a1
	ret			;04a2
sub_04a3h:
	call sub_04c9h		;04a3
	ld hl,l06eeh		;04a6
	call sub_04dbh		;04a9
	ld c,002h		;04ac
	call sub_04d3h		;04ae
sub_04b1h:
	call sub_04c9h		;04b1
	ld hl,l06edh		;04b4
	call sub_04dbh		;04b7
	ld c,082h		;04ba
	call sub_04d3h		;04bc
	and 002h		;04bf
	jp nz,l00b0h		;04c1
	in a,(073h)		;04c4
	cpl			;04c6
	or a			;04c7
	ret			;04c8
sub_04c9h:
	ld c,002h		;04c9
	call sub_04d3h		;04cb
	cpl			;04ce
	out (072h),a		;04cf
	ld c,040h		;04d1
sub_04d3h:
	in a,(072h)		;04d3
	cpl			;04d5
	and c			;04d6
	ret nz			;04d7
	jp sub_04d3h		;04d8
sub_04dbh:
	ld b,008h		;04db
sub_04ddh:
	ld a,(hl)		;04dd
	cpl			;04de
	out (073h),a		;04df
	inc hl			;04e1
	djnz sub_04ddh		;04e2
	ret			;04e4
l04e5h:
	call sub_052eh		;04e5
	cp 01bh			;04e8
	jp z,l007ah		;04ea
	ld c,a			;04ed
	call sub_0552h		;04ee
	jp l04e5h		;04f1
l04f4h:
	ld hl,l0080h		;04f4
	in a,(060h)		;04f7
	and 0c0h		;04f9
	ld a,042h		;04fb
	jp nz,l0503h		;04fd
	ld a,04ch		;0500
	add hl,hl		;0502
l0503h:
	ex de,hl		;0503
	ex af,af'		;0504
	jp l00e0h		;0505
l0508h:
	ld a,c			;0508
	cp 00dh			;0509
	jp nz,l00b0h		;050b
	ld b,000h		;050e
	ld de,code_start+1	;0510
	jp l00e0h		;0513
l0516h:
	call sub_03aeh		;0516
	dec b			;0519
	jp m,l00b0h		;051a
	ld a,c			;051d
	cp 00dh			;051e
	jp nz,l00b0h		;0520
	ex de,hl		;0523
	di			;0524
	ld a,0ffh		;0525
	ld i,a			;0527
	im 2			;0529
	jp l01dbh		;052b
sub_052eh:
	ld a,(0bffeh)		;052e
	or a			;0531
	jp z,sub_052eh		;0532
	xor a			;0535
	ld (0bffeh),a		;0536
	ld a,(0bfffh)		;0539
	and 07fh		;053c
	ret			;053e
	ei			;053f
	push af			;0540
	in a,(040h)		;0541
	cpl			;0543
	ld (0bfffh),a		;0544
	ld a,001h		;0547
	ld (0bffeh),a		;0549
	pop af			;054c
	ret			;054d
sub_054eh:
	call sub_052eh		;054e
	ld c,a			;0551
sub_0552h:
	push bc			;0552
	push de			;0553
	push hl			;0554
	ld a,c			;0555
	cp 00dh			;0556
	jp z,l0571h		;0558
	cp 00ah			;055b
	jp z,l056bh		;055d
	ld hl,(0ffech)		;0560
	ld (hl),c		;0563
	call sub_058bh		;0564
l0567h:
	pop hl			;0567
	pop de			;0568
	pop bc			;0569
	ret			;056a
l056bh:
	call sub_05a5h		;056b
	jp l0567h		;056e
l0571h:
	call sub_057dh		;0571
	ld (0ffech),hl		;0574
	call sub_05cfh		;0577
	jp l0567h		;057a
sub_057dh:
	ld hl,(0ffech)		;057d
	ld a,(0ffeeh)		;0580
	call sub_0688h		;0583
	xor a			;0586
	ld (0ffeeh),a		;0587
	ret			;058a
sub_058bh:
	ld hl,(0ffeeh)		;058b
	ld a,04fh		;058e
	cp l			;0590
	jp z,l059fh		;0591
	inc l			;0594
	ld (0ffeeh),hl		;0595
	ld hl,(0ffech)		;0598
	inc hl			;059b
	jp l05cch		;059c
l059fh:
	call sub_057dh		;059f
	ld (0ffech),hl		;05a2
sub_05a5h:
	ld hl,0ffefh		;05a5
	inc (hl)		;05a8
	ld a,01ch		;05a9
	cp (hl)			;05ab
	jp z,l05ddh		;05ac
	ld hl,(0ffech)		;05af
	ld de,00078h		;05b2
	add hl,de		;05b5
	jp c,l05c3h		;05b6
	ld de,(0ffeah)		;05b9
	call sub_0691h		;05bd
	jp c,l05cch		;05c0
l05c3h:
	ld hl,0f2c6h		;05c3
l05c6h:
	ld a,(0ffeeh)		;05c6
	call sub_02cdh		;05c9
l05cch:
	ld (0ffech),hl		;05cc
sub_05cfh:
	ld a,081h		;05cf
	out (081h),a		;05d1
	ld hl,(0ffeeh)		;05d3
	ld a,l			;05d6
	out (080h),a		;05d7
	ld a,h			;05d9
	out (080h),a		;05da
	ret			;05dc
l05ddh:
	dec (hl)		;05dd
	ld hl,(0ffe8h)		;05de
	ld (0ffech),hl		;05e1
	call sub_0617h		;05e4
	ld de,(0ffeah)		;05e7
	call sub_0691h		;05eb
	jp c,l05f4h		;05ee
	ld hl,0f2c6h		;05f1
l05f4h:
	ld (0ffe8h),hl		;05f4
	ld hl,(0ffech)		;05f7
	jp l05c6h		;05fa
sub_05fdh:
	ld hl,0f2c6h		;05fd
	ld (0ffe8h),hl		;0600
	ld b,01bh		;0603
l0605h:
	call sub_0617h		;0605
	djnz l0605h		;0608
	ld (0ffe6h),hl		;060a
	ld (0ffech),hl		;060d
	call sub_0617h		;0610
	ld (0ffeah),hl		;0613
	ret			;0616
sub_0617h:
	push de			;0617
	ld a,050h		;0618
	ld e,020h		;061a
	call sub_062eh		;061c
	ld a,026h		;061f
	ld e,000h		;0621
	call sub_062eh		;0623
	ld (hl),0ffh		;0626
	inc hl			;0628
	ld (hl),000h		;0629
	inc hl			;062b
	pop de			;062c
	ret			;062d
sub_062eh:
	ld (hl),e		;062e
	inc hl			;062f
	dec a			;0630
	ret z			;0631
	jp sub_062eh		;0632
sub_0635h:
	ld a,041h		;0635
	out (008h),a		;0637
	ld hl,(0ffe8h)		;0639
	ld a,l			;063c
	out (004h),a		;063d
	ld a,h			;063f
	out (004h),a		;0640
	ld de,(0ffeah)		;0642
	call sub_067fh		;0646
	dec hl			;0649
	ld a,l			;064a
	out (005h),a		;064b
	ld a,h			;064d
	or 080h			;064e
	out (005h),a		;0650
	ld hl,0f2c6h		;0652
	ld a,l			;0655
	out (006h),a		;0656
	ld a,h			;0658
	out (006h),a		;0659
	ld de,(0ffe8h)		;065b
	call sub_067fh		;065f
	dec hl			;0662
	ld a,l			;0663
	out (007h),a		;0664
	ld a,h			;0666
	or 080h			;0667
	out (007h),a		;0669
	ld a,0c5h		;066b
	out (008h),a		;066d
	ret			;066f
	push af			;0670
	push de			;0671
	push hl			;0672
	call sub_0635h		;0673
	ld a,0a0h		;0676
	out (081h),a		;0678
	pop hl			;067a
	pop de			;067b
	pop af			;067c
	ei			;067d
	ret			;067e
sub_067fh:
	ld a,l			;067f
	cpl			;0680
	ld l,a			;0681
	ld a,h			;0682
	cpl			;0683
	ld h,a			;0684
	inc hl			;0685
	add hl,de		;0686
	ret			;0687
sub_0688h:
	push bc			;0688
	ld b,a			;0689
	ld a,l			;068a
	sub b			;068b
	ld l,a			;068c
	pop bc			;068d
	ret nc			;068e
	dec h			;068f
	ret			;0690
sub_0691h:
	ld a,h			;0691
	cp d			;0692
	ret nz			;0693
	ld a,l			;0694
	cp e			;0695
code_last:
	ret			;0696

; BLOCK 'prompt_str' (start 0x0697 end 0x06a3)
prompt_str_start:
	defb 00dh		;0697
	defb 00ah		;0698
	defb 020h		;0699
	defb 042h		;069a
	defb 04fh		;069b
	defb 053h		;069c
	defb 053h		;069d
	defb 020h		;069e
	defb 02eh		;069f
	defb 02eh		;06a0
	defb 020h		;06a1
prompt_str_last:
	defb 000h		;06a2

; BLOCK 'floppy_params1' (start 0x06a3 end 0x06aa)
floppy_params1_start:
	defb 053h		;06a3
	defb 030h		;06a4
	defb 028h		;06a5
	defb 001h		;06a6
	defb 010h		;06a7
	defb 020h		;06a8
floppy_params1_last:
	defb 000h		;06a9

; BLOCK 'floppy_params2' (start 0x06aa end 0x06b1)
floppy_params2_start:
	defb 053h		;06aa
	defb 030h		;06ab
	defb 04ch		;06ac
	defb 001h		;06ad
	defb 01ah		;06ae
	defb 00eh		;06af
floppy_params2_last:
	defb 000h		;06b0

; BLOCK 'floppy_params3' (start 0x06b1 end 0x06b8)
floppy_params3_start:
	defb 053h		;06b1
	defb 030h		;06b2
	defb 04ch		;06b3
	defb 000h		;06b4
	defb 01ah		;06b5
	defb 007h		;06b6
floppy_params3_last:
	defb 080h		;06b7

; BLOCK 'sio_init_data' (start 0x06b8 end 0x06cc)
sio_init_data_start:
	defb 0e0h		;06b8
	defb 0f0h		;06b9
	defb 0e1h		;06ba
	defb 0f2h		;06bb
	defb 0e2h		;06bc
	defb 0f4h		;06bd
	defb 0e3h		;06be
	defb 0f6h		;06bf
	defb 0e4h		;06c0
	defb 0f8h		;06c1
	defb 0e5h		;06c2
	defb 0fah		;06c3
	defb 0e6h		;06c4
	defb 0fch		;06c5
	defb 0e7h		;06c6
	defb 0feh		;06c7
	defb 0c0h		;06c8
	defb 07fh		;06c9
	defb 0b0h		;06ca
sio_init_data_last:
	defb 0ffh		;06cb

; BLOCK 'lookup_table' (start 0x06cc end 0x06ec)
lookup_table_start:
	defb 000h		;06cc
	defb 001h		;06cd
	defb 002h		;06ce
	defb 003h		;06cf
	defb 004h		;06d0
	defb 005h		;06d1
	defb 006h		;06d2
	defb 007h		;06d3
	defb 008h		;06d4
	defb 009h		;06d5
	defb 00ah		;06d6
	defb 00bh		;06d7
	defb 00ch		;06d8
	defb 00dh		;06d9
	defb 00eh		;06da
	defb 00fh		;06db
	defb 010h		;06dc
	defb 011h		;06dd
	defb 012h		;06de
	defb 013h		;06df
	defb 014h		;06e0
	defb 015h		;06e1
	defb 016h		;06e2
	defb 017h		;06e3
	defb 018h		;06e4
	defb 019h		;06e5
	defb 01ah		;06e6
	defb 01bh		;06e7
	defb 01ch		;06e8
	defb 01dh		;06e9
	defb 01eh		;06ea
lookup_table_last:
	defb 01fh		;06eb

; BLOCK 'fdc_cmds' (start 0x06ec end 0x06f6)
fdc_cmds_start:
	defb 009h		;06ec
l06edh:
	defb 005h		;06ed
l06eeh:
	defb 004h		;06ee
	defb 001h		;06ef
	defb 000h		;06f0
	defb 000h		;06f1
	defb 000h		;06f2
	defb 000h		;06f3
	defb 000h		;06f4
fdc_cmds_last:
	defb 000h		;06f5

; BLOCK 'crt_init_data' (start 0x06f6 end 0x0700)
crt_init_data_start:
	defb 0ceh		;06f6
	defb 05bh		;06f7
	defb 06bh		;06f8
	defb 056h		;06f9
	defb 013h		;06fa
	defb 000h		;06fb
	defb 000h		;06fc
	defb 000h		;06fd
	defb 000h		;06fe
crt_init_data_last:
	defb 000h		;06ff

; BLOCK 'unused' (start 0x0700 end 0x07f0)
unused_start:
	defb 000h		;0700
	defb 000h		;0701
	defb 000h		;0702
	defb 000h		;0703
	defb 000h		;0704
	defb 000h		;0705
	defb 000h		;0706
	defb 000h		;0707
	defb 000h		;0708
	defb 000h		;0709
	defb 000h		;070a
	defb 000h		;070b
	defb 000h		;070c
	defb 000h		;070d
	defb 000h		;070e
	defb 000h		;070f
	defb 000h		;0710
	defb 000h		;0711
	defb 000h		;0712
	defb 000h		;0713
	defb 000h		;0714
	defb 000h		;0715
	defb 000h		;0716
	defb 000h		;0717
	defb 000h		;0718
	defb 000h		;0719
	defb 000h		;071a
	defb 000h		;071b
	defb 000h		;071c
	defb 000h		;071d
	defb 000h		;071e
	defb 000h		;071f
	defb 000h		;0720
	defb 000h		;0721
	defb 000h		;0722
	defb 000h		;0723
	defb 000h		;0724
	defb 000h		;0725
	defb 000h		;0726
	defb 000h		;0727
	defb 000h		;0728
	defb 000h		;0729
	defb 000h		;072a
	defb 000h		;072b
	defb 000h		;072c
	defb 000h		;072d
	defb 000h		;072e
	defb 000h		;072f
	defb 000h		;0730
	defb 000h		;0731
	defb 000h		;0732
	defb 000h		;0733
	defb 000h		;0734
	defb 000h		;0735
	defb 000h		;0736
	defb 000h		;0737
	defb 000h		;0738
	defb 000h		;0739
	defb 000h		;073a
	defb 000h		;073b
	defb 000h		;073c
	defb 000h		;073d
	defb 000h		;073e
	defb 000h		;073f
	defb 000h		;0740
	defb 000h		;0741
	defb 000h		;0742
	defb 000h		;0743
	defb 000h		;0744
	defb 000h		;0745
	defb 000h		;0746
	defb 000h		;0747
	defb 000h		;0748
	defb 000h		;0749
	defb 000h		;074a
	defb 000h		;074b
	defb 000h		;074c
	defb 000h		;074d
	defb 000h		;074e
	defb 000h		;074f
	defb 000h		;0750
	defb 000h		;0751
	defb 000h		;0752
	defb 000h		;0753
	defb 000h		;0754
	defb 000h		;0755
	defb 000h		;0756
	defb 000h		;0757
	defb 000h		;0758
	defb 000h		;0759
	defb 000h		;075a
	defb 000h		;075b
	defb 000h		;075c
	defb 000h		;075d
	defb 000h		;075e
	defb 000h		;075f
	defb 000h		;0760
	defb 000h		;0761
	defb 000h		;0762
	defb 000h		;0763
	defb 000h		;0764
	defb 000h		;0765
	defb 000h		;0766
	defb 000h		;0767
	defb 000h		;0768
	defb 000h		;0769
	defb 000h		;076a
	defb 000h		;076b
	defb 000h		;076c
	defb 000h		;076d
	defb 000h		;076e
	defb 000h		;076f
	defb 000h		;0770
	defb 000h		;0771
	defb 000h		;0772
	defb 000h		;0773
	defb 000h		;0774
	defb 000h		;0775
	defb 000h		;0776
	defb 000h		;0777
	defb 000h		;0778
	defb 000h		;0779
	defb 000h		;077a
	defb 000h		;077b
	defb 000h		;077c
	defb 000h		;077d
	defb 000h		;077e
	defb 000h		;077f
	defb 000h		;0780
	defb 000h		;0781
	defb 000h		;0782
	defb 000h		;0783
	defb 000h		;0784
	defb 000h		;0785
	defb 000h		;0786
	defb 000h		;0787
	defb 000h		;0788
	defb 000h		;0789
	defb 000h		;078a
	defb 000h		;078b
	defb 000h		;078c
	defb 000h		;078d
	defb 000h		;078e
	defb 000h		;078f
	defb 000h		;0790
	defb 000h		;0791
	defb 000h		;0792
	defb 000h		;0793
	defb 000h		;0794
	defb 000h		;0795
	defb 000h		;0796
	defb 000h		;0797
	defb 000h		;0798
	defb 000h		;0799
	defb 000h		;079a
	defb 000h		;079b
	defb 000h		;079c
	defb 000h		;079d
	defb 000h		;079e
	defb 000h		;079f
	defb 000h		;07a0
	defb 000h		;07a1
	defb 000h		;07a2
	defb 000h		;07a3
	defb 000h		;07a4
	defb 000h		;07a5
	defb 000h		;07a6
	defb 000h		;07a7
	defb 000h		;07a8
	defb 000h		;07a9
	defb 000h		;07aa
	defb 000h		;07ab
	defb 000h		;07ac
	defb 000h		;07ad
	defb 000h		;07ae
	defb 000h		;07af
	defb 000h		;07b0
	defb 000h		;07b1
	defb 000h		;07b2
	defb 000h		;07b3
	defb 000h		;07b4
	defb 000h		;07b5
	defb 000h		;07b6
	defb 000h		;07b7
	defb 000h		;07b8
	defb 000h		;07b9
	defb 000h		;07ba
	defb 000h		;07bb
	defb 000h		;07bc
	defb 000h		;07bd
	defb 000h		;07be
	defb 000h		;07bf
	defb 000h		;07c0
	defb 000h		;07c1
	defb 000h		;07c2
	defb 000h		;07c3
	defb 000h		;07c4
	defb 000h		;07c5
	defb 000h		;07c6
	defb 000h		;07c7
	defb 000h		;07c8
	defb 000h		;07c9
	defb 000h		;07ca
	defb 000h		;07cb
	defb 000h		;07cc
	defb 000h		;07cd
	defb 000h		;07ce
	defb 000h		;07cf
	defb 000h		;07d0
	defb 000h		;07d1
	defb 000h		;07d2
	defb 000h		;07d3
	defb 000h		;07d4
	defb 000h		;07d5
	defb 000h		;07d6
	defb 000h		;07d7
	defb 000h		;07d8
	defb 000h		;07d9
	defb 000h		;07da
	defb 000h		;07db
	defb 000h		;07dc
	defb 000h		;07dd
	defb 000h		;07de
	defb 000h		;07df
	defb 000h		;07e0
	defb 000h		;07e1
	defb 000h		;07e2
	defb 000h		;07e3
	defb 000h		;07e4
	defb 000h		;07e5
	defb 000h		;07e6
	defb 000h		;07e7
	defb 000h		;07e8
	defb 000h		;07e9
	defb 000h		;07ea
	defb 000h		;07eb
	defb 000h		;07ec
	defb 000h		;07ed
	defb 000h		;07ee
unused_last:
	defb 000h		;07ef

; BLOCK 'int_vectors' (start 0x07f0 end 0x0800)
int_vectors_start:
	defw 00670h		;07f0
	defw 003d8h		;07f2
	defw 0032ch		;07f4
	defw 003d8h		;07f6
	defw 0053fh		;07f8
	defw 003d8h		;07fa
	defw 003d8h		;07fc
	defw 003dah		;07fe
