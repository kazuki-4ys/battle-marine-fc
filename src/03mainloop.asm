;------------------------------------------
; メインループ
;------------------------------------------
mainloop:
    ; タイトルへの復帰判定
    ldx v_return_timer
    beq mainloop_notReturn
    dex
    stx v_return_timer
    bne mainloop_notReturn
    jmp title
mainloop_notReturn:

    ; メダル数の変化値をメダル数に合わせておく
    lda v_medal
    sta v_medal_cnt

    ; ジョイパットの入力値の取得開始
    lda #$01
    sta $4016
    lda #$00
    sta $4016

    ; カウンタをインクリメント
    ldx v_counter
    inx
    stx v_counter

    ; 16フレームに1回敵を出す (ただし ready timer がセットされている間は抑止)
    ldy v_ready_timer
    beq mainloop_ready
    dey
    sty v_ready_timer
    bne mainloop_addNewEnemy_end
mainloop_ready:
    txa
    and #$0f
    bne mainloop_addNewEnemy_end
    jsr sub_newEnemy
mainloop_addNewEnemy_end:

    ; ゲームオーバー演出
    lda v_gameOver
    beq mainloop_endGameOver
    cmp #$01
    beq mainloop_playerBomb
    bne mainloop_endGameOver ; TODO: プレイヤ爆破後にGAME OVERを表示して一定時間でタイトルに戻る
mainloop_playerBomb:
    ; プレイヤの爆破アニメーション
    ldx v_dest_player
    inx
    stx v_dest_player
    txa
    and #$1f
    beq mainloop_playerBombEnd
    and #%00011100
    lsr
    clc
    adc #$40
    sta sp_playerT
    adc #$10
    sta sp_playerT + 4
    jmp mainloop_endGameOver
mainloop_playerBombEnd:
    lda #$02
    sta v_gameOver
    sta v_gameOverD
    lda #$00
    sta sp_playerT
    sta sp_playerT + 4
mainloop_endGameOver:

    ; 波座標を求める
    lda v_counter
    and #$1f
    tax
    lda wave_table, x
    sta v_wave

    ; 粉塵のアニメーション
mainloop_dust:
    lda v_dust
    beq mainloop_dustEnd
    clc
    adc #$01
    and #%00011111
    sta v_dust
    beq mainloop_dustErase
    and #%00011000
    ror
    adc #$10
    sta sp_dustT
    adc #$02
    sta sp_dustT + 4
    bne mainloop_dustE
mainloop_dustErase:
    sta sp_dustT
    sta sp_dustT + 4
mainloop_dustEnd:

    ; ノイズ効果音 (水しぶき)
    ldx v_noise
    beq mainloop_noNoise
    ;     --cevvvv (c=再生時間カウンタ, e=effect, v=volume)
    lda #%00011111
    sta $400C
    ;     r---ssss (r=乱数種別, s=サンプリングレート)
    lda noise_table, x
    sta $400E
    ;     ttttt--- (t=再生時間)
    lda #%01111111
    sta $400F
    ; テーブルインデックスを進める
    inx
    txa
    and #$0f
    sta v_noise
mainloop_noNoise:

    ; 水しぶきのアニメーション
mainloop_dustE:
    lda v_dustE
    beq v_dustEEnd
    clc
    adc #$01
    and #%00011111
    sta v_dustE
    beq mainloop_dustEErase
    and #%00011000
    ror
    adc #$60
    sta sp_dustET
    adc #$02
    sta sp_dustET + 4
    bne mainloop_shot
mainloop_dustEErase:
    sta sp_dustET
    sta sp_dustEY
    sta sp_dustET + 4
    sta sp_dustEY + 4
v_dustEEnd:

    ; プレイヤのショットを動かす
mainloop_shot:
    lda v_shotF
    beq mainloop_movePlayer
    lda v_shotY
    clc
    adc #$04
    cmp #$d8
    bcs mainloop_eraseShot
    sta v_shotY
    sta sp_shotY
    bcc mainloop_movePlayer
mainloop_eraseShot:
    lda #$00
    sta v_shotF
    sta sp_shotT
    lda #$01
    sta v_dust
    lda v_shotX
    clc
    sbc #$04
    sta sp_dustX
    adc #$08
    sta sp_dustX + 4
    lda #$d0
    sta sp_dustY
    sta sp_dustY + 4
    lda #$10
    sta sp_dustT
    lda #$12
    sta sp_dustT + 4
    ;     VHP---CC
    lda #%00000001
    sta sp_dustA
    sta sp_dustA + 4
    ; play SE1 (ノイズを使う)
    ;     --cevvvv (c=再生時間カウンタ, e=effect, v=volume)
    lda #%00011111
    sta $400C
    ;     r---ssss (r=乱数種別, s=サンプリングレート)
    lda #%00001101
    sta $400E
    ;     ttttt--- (t=再生時間)
    lda #%11111000
    sta $400F
    ; メダルを半減させる
    lda v_medal_cnt
    and #$fe
    lsr
    sta v_medal_cnt

    ; ゲームオーバー中でなければプレイヤの移動処理を実行
mainloop_movePlayer:
    lda v_gameOver
    bne mainloop_skipPlayer
    jsr sub_movePlayer
mainloop_skipPlayer:

    ; 敵を動かす
    jsr sub_moveEnemy

    ; メダル数の変化値を15以下に丸める
    lda v_medal_cnt
    and #$0f

mainloop_wait_vBlank:
    lda $2002
    bpl mainloop_wait_vBlank ; wait for vBlank
    lda #$3
    sta $4014

    ; メダル数が変化した場合は描画
    lda v_medal_cnt
    cmp v_medal
    beq mainloop_medalNotChanged
    sta v_medal
    tay
    lda #$20
    sta $2006
    lda #$43
    sta $2006
    ldx #$0f
    lda v_medal
    beq mainloop_drawNoMedal
    lda #$01
mainloop_drawMedal:
    sta $2007
    dex
    beq mainloop_drawMedalEnd
    dey
    bne mainloop_drawMedal
mainloop_drawNoMedal:
    lda #$00
mainloop_drawMedal2:
    sta $2007
    dex
    bne mainloop_drawMedal2
mainloop_drawMedalEnd:
    ; scroll setting
    lda #$00
    sta $2005
    sta $2005
    jmp mainloop
mainloop_medalNotChanged:

    ; スコア更新
    lda v_gameOver
    bne mainloop_scoreNotAdded
    ldx v_sc_plus
    beq mainloop_scoreNotAdded
    dex
    stx v_sc_plus
    jsr sub_addScore10
    ; scroll setting
    lda #$00
    sta $2005
    sta $2005
    jmp mainloop
mainloop_scoreNotAdded:

    ; GET READY
    lda v_ready_timer
    beq mainloop_notGetReady
    cmp #$5f
    beq mainloop_drawGetReady
    cmp #$01
    beq mainloop_clearGetReady
    beq mainloop_notGetReady
mainloop_drawGetReady:
    ; GET READYを表示
    lda #$20
    sta $2006
    lda #$cb
    sta $2006
    ldy #$00
    ldx #$0a
mainloop_drawGetReadyLoop:
    lda string_get_ready, y
    sta $2007
    iny
    dex
    bne mainloop_drawGetReadyLoop
    ; scroll setting
    lda #$00
    sta $2005
    sta $2005
    jmp mainloop
mainloop_clearGetReady:
    ; GET READYを消す
    lda #$20
    sta $2006
    lda #$cb
    sta $2006
    ldx #$0a
    lda #$00
mainloop_clearGetReadyLoop:
    sta $2007
    dex
    bne mainloop_clearGetReadyLoop
    ; scroll setting
    lda #$00
    sta $2005
    sta $2005
    jmp mainloop
mainloop_notGetReady:

    ; GAME OVER
    lda v_gameOverD
    beq mainloop_notGameOverDraw
    lda #$00
    sta v_gameOverD
    lda #$20
    sta $2006
    lda #$cb
    sta $2006
    ldy #$00
    ldx #$0a
mainloop_drawGameOver:
    lda string_game_over, y
    sta $2007
    iny
    dex
    bne mainloop_drawGameOver
    ; 復帰タイマーを設定
    ;lda #$60
    lda #$3 ;3Fでタイトルに戻るように変更
    sta v_return_timer
    ; scroll setting
    lda #$00
    sta $2005
    sta $2005
    jmp mainloop
mainloop_notGameOverDraw:

    jmp mainloop

;------------------------------------------------------------
; ゲームオーバーを開始するサブルーチン (レジスタAのみ使う)
;------------------------------------------------------------
start_gameOver:
    lda #$01
    sta v_gameOver
    ; スプライト2を消す
    lda #$00
    sta v_dest_player
    sta sp_playerY + 8
    sta sp_playerT + 8
    ; スプライト0~1を右に4pxズラす
    lda v_playerX
    clc
    adc #4
    sta sp_playerX
    adc #8
    sta sp_playerX + 4
    ; スプライト0~1を爆破パターンに変更
    lda #%00000001
    sta sp_playerA
    sta sp_playerA + 4
    lda #$40
    sta sp_playerT
    lda #$50
    sta sp_playerT + 4

    ; play SE1 (ノイズを使う)
    ;     --cevvvv (c=再生時間カウンタ, e=effect, v=volume)
    lda #%00011111
    sta $400C
    ;     r---ssss (r=乱数種別, s=サンプリングレート)
    lda #%10001101
    sta $400E
    ;     ttttt--- (t=再生時間)
    lda #%11111000
    sta $400F

    ; play SE2 (矩形波1を使う)
    ;     ddcevvvv (d=duty, c=再生時間カウンタ, e=effect, v=volume)
    lda #%11111111
    sta $4000
    ;     csssmrrr (c=周波数変化, s=speed, m=method, r=range)
    lda #%11110011
    sta $4001
    ;     kkkkkkkk (k=音程周波数の下位8bit)
    lda #%01101000
    sta $4002
    ;     tttttkkk (t=再生時間, k=音程周波数の上位3bit)
    lda #%11111001
    sta $4003

    rts
