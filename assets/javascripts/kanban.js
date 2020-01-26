$(function() {
    // サイドバーを表示
    $('#main').removeClass('nosidebar');

    // 元のCSSのマージンをオーバーライド
    $('#sidebar').css({"cssText" : "padding : 0 8px 0px 8px !important"});

    // 初期表示
    var initial_string = "<table class=\"my-journal-table\"><tr><td>履歴が表示されます。</td></tr></table>"
    $('#sidebar').html(initial_string);

    // マウスを乗せたら発動
    $('[id^=issue-]').hover(function() {
        var card = $(this);
        // 500ミリ秒後に発火する
        timeout = setTimeout(function() {
            // カードID
            var card_id = card.attr('id');
            // ジャーナル取得
            getJournal(card_id);
        }, 500)
    // ここにはマウスを離したときの動作を記述
    }, function() {
        // 発火する前にキャンセル
        clearTimeout(timeout)
    });

    // windowがスクロールされた時に実行する処理
    $(window).scroll(function() {
        var top = $(this).scrollTop();
        var content = $('#content').offset();
        // サイドバーをスクロールに追従させる
        if (content.top < top) {
            $('#sidebar').offset({ top: top + 10 });
        } else {
            $('#sidebar').offset({ top: content.top });
        }
    });

    // コメント投稿ダイアログを定義
    $("#comment-dialog").dialog({
        title: 'コメント投稿',
        width: 400,
        autoOpen: false,
        modal: true,
        buttons: {
            "OK": function() {
            // 閉じる
            $(this).dialog("close");
            // 保存する
            saveTicket(
                $('#save_card_id').val(),
                $('#save_from_field_id').val(),
                $('#save_to_field_id').val(),
                $('#comment-of-dialog').val()
                );
            // コメント削除
            $('#comment-of-dialog').val('');
            },
            "Cancel": function() {
                // 閉じる
                $(this).dialog("close");
                // 画面再描画
                $('#form1').submit();
            }
          }
    });

    // カードをdrag可能に
    $("[id^=issue-]").draggable({ stack: "[id^=issue-]", drag: function( event, ui ) {ui.helper.addClass("dragged-issue-card")}});
    
    // カードをdrop可能に
    $("[id^=field-]").droppable({
        // 受け入れる要素
		accept : "[id^=issue]" ,
        // ドロップされた時
        drop : function(event , ui){
            // まっすぐに直す
            ui.helper.removeClass("dragged-issue-card");
            // ドラッグ元ID
            $('#save_card_id').val(ui.draggable.attr('id'));
            $('#save_from_field_id').val(ui.draggable.parent().attr('id'));
            // ドロップ先ID
            $('#save_to_field_id').val($(this).attr('id'));
            // カードをTDに挿入
            if (ui.position.top < 0) {
                // 先頭へ
                $(this).prepend(ui.draggable.css('left','').css('top',''));
            } else {
                // 最後へ
                $(this).append(ui.draggable.css('left','').css('top',''));
            }
            // コメント入力ダイアログ表示
            $("#comment-dialog").dialog("open");
		} 
    });
});

//
// チケット保存
//
function saveTicket(card_id, from_field_id, to_field_id, comment) {
    // AJAX
    $.ajax({
        url:'/update_status',
        type:'POST',
        data:{
            'card_id'  :card_id, 
            'field_id' :to_field_id,
            'comment'  :comment
        },
        dataType: 'json',
        async: true
    })
    // Ajaxリクエストが成功した時発動
    .done( (data) => {
        console.log(data.result);
        if (data.result == "OK") {
            // カウンタの更新(アップ)
            var tmp1 = to_field_id.split('-');
            var to_counter_id = 'counter-' + tmp1[1];
            var to_value = Number($('#' + to_counter_id).html()) + 1;
            $('#'+to_counter_id).html(to_value);
            // カウンタの更新(ダウン)
            var tmp2 = from_field_id.split('-');
            var from_counter_id = 'counter-' + tmp2[1];
            var from_value = Number($('#' + from_counter_id).html()) - 1;
            $('#'+from_counter_id).html(from_value);
            // WIP制限
            var wip_field = Number($('#wip-field').html());
            var wip_limit = $('#wip_max option:selected').val();
            // WIP制限エラー（アップ）
            if (tmp1[1] == wip_field) {
                if (tmp1[2] == tmp2[2]) { // 同じ人
                    var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                    $('#wip-' + tmp1[2]).html(wip_next1);
                } else { // 違う人
                    if (tmp1[2] == tmp2[2]) { // 同じステータス
                        if (data.user_id != null) {
                            var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                            $('#wip-' + tmp1[2]).html(wip_next1);
                        }
                        var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                        $('#wip-' + tmp2[2]).html(wip_next2);
                    } else { // 違うステータス
                        var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                        $('#wip-' + tmp1[2]).html(wip_next1);
                    }
                }
                if (wip_next1 > Number(wip_limit)) {
                    $('#' + to_field_id).prepend($('#wip_error-' + tmp1[2]));
                    $('#wip_error-' + tmp1[2]).show();
                } else {
                    $('#wip_error-' + tmp1[2]).hide();
                }
            }
            // WIP制限エラー（ダウン）
            if (tmp2[1] == wip_field) {
                if (tmp1[2] == tmp2[2]) { // 同じ人
                    var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                    $('#wip-' + tmp2[2]).html(wip_next2);
                } else { // 違う人
                    if (tmp1[2] == tmp2[2]) { // 同じステータス
                        if (data.user_id != null) {
                            var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                            $('#wip-' + tmp1[2]).html(wip_next1);
                        }
                        var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                        $('#wip-' + tmp2[2]).html(wip_next2);
                    } else { // 違うステータス
                        var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                        $('#wip-' + tmp2[2]).html(wip_next2);
                    }
                }
                if (wip_next2 > Number(wip_limit)) {
                    $('#' + from_field_id).prepend($('#wip_error-' + tmp2[2]));
                    $('#wip_error-' + tmp2[2]).show();
                } else {
                    $('#wip_error-' + tmp2[2]).hide();
                }
            }
            // カードの担当名を更新
            if (data.user_id != null) {
                $('#user_name_' + card_id).html($('#user_name_user_id-' + data.user_id).html());
            } else {
                $('#user_name_' + card_id).html("<p>Not assigned</p>");
            }
        }
        if (data.result == "NG") {
            // 画面再描画
            $('#form1').submit();
        }
    })
    // Ajaxリクエストが失敗した時発動
    .fail( (data) => {
        console.log("AJAX FAILED.");
        // 画面再描画
        $('#form1').submit();
    });
}

//
// ジャーナル取得
//
function getJournal(card_id) {
    // AJAX
    $.ajax({
        url:'/get_journal',
        type:'POST',
        data:{
            'card_id' :card_id ,
        },
        dataType: 'json',
        async: true,
        global: false
    })
    // Ajaxリクエストが成功した時発動
    .done( (data) => {
        console.log(data.result);
        if (data.result == "OK") {
            // サイドバーに表示
            $('#sidebar').html(data.notes);
            // クリックイベントを登録
            $('#submit-journal-button').on('click',function(){
                putJournal(card_id);
            });
        }
    })
    // Ajaxリクエストが失敗した時発動
    .fail( (data) => {
        console.log("AJAX FAILED.");
    })
}

//
// ジャーナル追加
//
function putJournal(card_id) {
    var note = $('#comment_area').val();
    // AJAX
    $.ajax({
        url:'/put_journal',
        type:'POST',
        data:{
            'card_id' :card_id ,
            'note' : note
        },
        dataType: 'json',
        async: true,
    })
    // Ajaxリクエストが成功した時発動
    .done( (data) => {
        console.log(data.result);
        if (data.result == "OK") {
            // ジャーナル更新
            getJournal(card_id);
        }
    })
    // Ajaxリクエストが失敗した時発動
    .fail( (data) => {
        console.log("AJAX FAILED.");
    })
}

//「このサイトを離れますか」を非表示
Object.defineProperty(window, 'onbeforeunload', {
    set(newValue) {
        if (typeof newValue === 'function') window.onbeforeunload = null;
    }
});
