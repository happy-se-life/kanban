$(function() {
    // Floating table header
    $('#kanban_table').floatThead({zIndex: 39});

    // Redraw table header
    $('#upper_filters').on('click',function(){
        $('#kanban_table').floatThead('reflow')
    });

    // Redraw table header
    $('#lower_filters').on('click',function(){
        $('#kanban_table').floatThead('reflow')
    });

    // Show sidebar
    $('#main').removeClass('nosidebar');

    // Override sidebar style
    $('#sidebar').css({"cssText" : "padding : 0 8px 0px 8px !important"});

    // Initial message when no note
    var initial_string = "<table class=\"my-journal-table\"><tr><td>" + label_recent_history_is_here + "</td></tr></table>"
    $('#sidebar').html(initial_string);

    // When mouse over
    $('[id^=issue-]').hover(function() {
        var card = $(this);
        // Exec. after 500ms
        timeout = setTimeout(function() {
            var card_id = card.attr('id');
            // Get journal
            getJournal(card_id);
        }, 500)
    }, function() {
        // Cancel before exec.
        clearTimeout(timeout)
    });

    // When window scrolled
    $(window).scroll(function() {
        var top = $(this).scrollTop();
        var content = $('#content').offset();
        // Make sidebar follow the scroll
        if (content.top < top) {
            $('#sidebar').offset({ top: top + 10 });
        } else {
            $('#sidebar').offset({ top: content.top });
        }
        // Save hidden
        $("#scroll_top").val(top);
    });

    // Definition of dialog when card dropped
    $("#comment-dialog").dialog({
        title: label_add_notes,
        width: 400,
        autoOpen: false,
        modal: true,
        buttons: {
            "OK": function() {
                $(this).dialog("close");
                // Save ticket (change status and assignee)
                saveTicket(
                    $('#save_card_id').val(),
                    $('#save_from_field_id').val(),
                    $('#save_to_field_id').val(),
                    $('#comment-of-dialog').val()
                    );
                // Clear inputs
                $('#comment-of-dialog').val('');
            },
            "Cancel": function() {
                $(this).dialog("close");
                // Reload page
                $('#form1').submit();
            }
        }
    });

    // Card can be draggable
    $("[id^=issue-]").draggable({ stack: "[id^=issue-]", drag: function( event, ui ) {ui.helper.addClass("dragged-issue-card")}});
    
    // Card can be droppable
    $("[id^=field-]").droppable({
		accept : "[id^=issue]" ,
        drop : function(event , ui){
            // Level the card
            ui.helper.removeClass("dragged-issue-card");
            // Field ID when drag
            $('#save_card_id').val(ui.draggable.attr('id'));
            $('#save_from_field_id').val(ui.draggable.parent().attr('id'));
            // Field ID when drop
            $('#save_to_field_id').val($(this).attr('id'));
            // Insert card to <TD>
            if (ui.position.top < 0) {
                // Insert to top
                $(this).prepend(ui.draggable.css('left','').css('top',''));
            } else {
                // Insert to bottom
                $(this).append(ui.draggable.css('left','').css('top',''));
            }
            // Display comment dialog when drop
            if (option_display_comment_dialog_when_drop == "1") {
                $("#comment-dialog").dialog("open");
            } else {
                // Save ticket (change status and assignee)
                saveTicket(
                    $('#save_card_id').val(),
                    $('#save_from_field_id').val(),
                    $('#save_to_field_id').val(),
                    ""
                    );
            }
		} 
    });
});

//
// Save ticket (change status and assignee, save comment)
//
function saveTicket(card_id, from_field_id, to_field_id, comment) {
    // AJAX
    $.ajax({
        url:'./update_status',
        type:'POST',
        data:{
            'card_id'  :card_id, 
            'field_id' :to_field_id,
            'comment'  :comment
        },
        dataType: 'json',
        async: true
    })
    // Case ajax succeed
    .done( (data) => {
        console.log(data.result);
        if (data.result == "OK") {
            // Count up counter on <th>
            var tmp1 = to_field_id.split('-');
            var to_counter_id = 'counter-' + tmp1[1];
            var to_value = Number($('#' + to_counter_id).html()) + 1;
            $('#'+to_counter_id).html(to_value);
            // Count down counter on <th>
            var tmp2 = from_field_id.split('-');
            var from_counter_id = 'counter-' + tmp2[1];
            var from_value = Number($('#' + from_counter_id).html()) - 1;
            $('#'+from_counter_id).html(from_value);
            // Get WIP limit value
            var wip_field = Number($('#wip-field').html());
            var wip_limit = $('#wip_max option:selected').val();
            // Case card move to WIP field (count up)
            if (tmp1[1] == wip_field) {
                if (tmp1[2] == tmp2[2]) { // Case same user
                    var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                    $('#wip-' + tmp1[2]).html(wip_next1);
                } else { // Case different user
                    if (tmp1[2] == tmp2[2]) { // Case same status
                        if (data.user_id != null) {
                            var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                            $('#wip-' + tmp1[2]).html(wip_next1);
                        }
                        var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                        $('#wip-' + tmp2[2]).html(wip_next2);
                    } else { // Case different status
                        var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                        $('#wip-' + tmp1[2]).html(wip_next1);
                    }
                }
                // Show or hide WIP warning
                if (wip_next1 > Number(wip_limit)) {
                    $('#' + to_field_id).prepend($('#wip_error-' + tmp1[2]));
                    $('#wip_error-' + tmp1[2]).show();
                } else {
                    $('#wip_error-' + tmp1[2]).hide();
                }
            }
            // Case card move from WIP field (count down)
            if (tmp2[1] == wip_field) {
                if (tmp1[2] == tmp2[2]) { // Case same user
                    var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                    $('#wip-' + tmp2[2]).html(wip_next2);
                } else { // Case different user
                    if (tmp1[2] == tmp2[2]) { // Case same status
                        if (data.user_id != null) {
                            var wip_next1 = Number($('#wip-' + tmp1[2]).html()) + 1;
                            $('#wip-' + tmp1[2]).html(wip_next1);
                        }
                        var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                        $('#wip-' + tmp2[2]).html(wip_next2);
                    } else { // Case different status
                        var wip_next2 = Number($('#wip-' + tmp2[2]).html()) - 1;
                        $('#wip-' + tmp2[2]).html(wip_next2);
                    }
                }
                // Show or hide WIP warning
                if (wip_next2 > Number(wip_limit)) {
                    $('#' + from_field_id).prepend($('#wip_error-' + tmp2[2]));
                    $('#wip_error-' + tmp2[2]).show();
                } else {
                    $('#wip_error-' + tmp2[2]).hide();
                }
            }
            // Write user name on card
            if (data.user_id != null) {
                $('#user_name_' + card_id).html($('#user_name_user_id-' + data.user_id).html());
            } else {
                $('#user_name_' + card_id).html("<p>Not assigned</p>");
            }
        }
        if (data.result == "NG") {
            alert("Operation not permitted")
            // Reload page
            $('#form1').submit();
        }
    })
    // Case ajax failed
    .fail( (data) => {
        console.log("AJAX FAILED.");
        // Reload page
        $('#form1').submit();
    });
}

//
// Get journal
//
function getJournal(card_id) {
    // AJAX
    $.ajax({
        url:'./get_journal',
        type:'POST',
        data:{
            'card_id' :card_id ,
        },
        dataType: 'json',
        async: true,
        global: false
    })
    // Case ajax succeed
    .done( (data) => {
        console.log(data.result);
        if (data.result == "OK") {
            // Display on sidebar
            $('#sidebar').html(data.notes);
            // Register click event
            $('#submit-journal-button').on('click',function(){
                putJournal(card_id);
            });
        }
    })
    // Case ajax failed
    .fail( (data) => {
        console.log("AJAX FAILED.");
    })
}

//
// Add new journal
//
function putJournal(card_id) {
    var note = $('#comment_area').val();
    // AJAX
    $.ajax({
        url:'./put_journal',
        type:'POST',
        data:{
            'card_id' :card_id ,
            'note' : note
        },
        dataType: 'json',
        async: true,
    })
    // Case ajax succeed
    .done( (data) => {
        console.log(data.result);
        if (data.result == "OK") {
            // Reread journal
            getJournal(card_id);
        }
    })
    // Case ajax failed
    .fail( (data) => {
        console.log("AJAX FAILED.");
    })
}

// Suppress messages "Leave this site?"
Object.defineProperty(window, 'onbeforeunload', {
    set(newValue) {
        if (typeof newValue === 'function') window.onbeforeunload = null;
    }
});
