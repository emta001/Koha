$(document).ready(function(){

    /*Don't make unnecessary AJAX-calls*/
    if(pagination_on){
        var url = "/api/v1/holds";
        var page = 1;
        var per_page = 10;
        var reserveValues = {biblio_id: biblionumber, _order_by: "priority", _page : page, _per_page : per_page};
    
        getJson(url, reserveValues);
    }

    $( ".datepicker" ).datepicker({
        onClose: function(dateText, inst) {
            validate_date(dateText, inst);
        },
        minDate: 1,
    }).on("change", function(e, value) {
        if ( ! is_valid_date( $(this).val() ) ) {$(this).val("");}
    });

});

function getJson(url, reserveValues){
    $.ajax({
        url: url,
        data: reserveValues,
        type: "GET",
        async: false,
        cache: true,
        success: function(data, textStatus, request){
            var links = request.getResponseHeader('Link');
            console.log(data);
            holdRow(data);
        },
        error: function(jqXHR, textStatus, errorThrown){
            console.log(JSON.stringify(errorThrown));
        }
    });
}

function updateData(url, update_data){
    $.ajax({
        url: url,
        data: update_data,
        method: "PUT",
        success: console.log("tähän sitten rivin vaihtofunktio tai muu päivitysjuttu tai joku palautus arvo jota voi käyttää"), //mikä hitto tää on
        error: function( jqXHR, textStatus, errorThrown) {
            console.log(jqXHR, textStatus, errorThrown);
        },
    });
}

function holdRow(result){
    
    var row;
    var priority_options = [];
    //var patrons = getPatrons();
    for(var i in result){
        if(result[i].priority != 0){
            priority_options.push(result[i].priority);
        }
    }

    result.forEach(data_row => {

        //näitä voisi kai jotenkin venkslata
        var first_priority = priority_options[0];
        var last_priority = priority_options[priority_options.length - 1];
        var prev_priority = data_row.priority - 1;
        var next_priority = data_row.priority + 1;

        var priority_select;
        if(!data_row.status){
            priority_select = '<select name="rank-request">';
        }else{
            priority_select = '<input type="hidden" name="rank-request" value="'+data_row.priority+'">';
            priority_select += '<select name="rank-request" disabled="disabled">';
        }

        if(data_row.status){
            if(data_row.status == "T"){
                priority_select += '<option value="T" selected="selected">In transit</option>';
            }else if(data_row.status == "W"){
                priority_select += '<option value="W" selected="selected">Waiting</option>';
            }
        }else{
            for(var i = 0; i < priority_options.length; i++){

                var priority = priority_options[i];

                if(priority == data_row.priority){
                    priority_select += '<option value= "'+ priority +'" selected="selected">' + priority + '</option>';
                }else{
                    priority_select += '<option value= "'+ priority +'">' + priority + '</option>';
                }

            }
            priority_select += '<option value="del">del</option>';
            priority_select += '</select>';
        }

        var move_up_img = '<img src="'+ interface +'/'+ theme +'/img/go-up.png" alt="Go up" />';
        var move_top_img = '<img src="'+ interface +'/'+ theme +'/img/go-top.png" alt="Go top" />';
        var move_bottom_img = '<img src="'+ interface +'/'+ theme +'/img/go-bottom.png" alt="Go bottom" />';
        var move_down_img = '<img src="'+ interface +'/'+ theme +'/img/go-down.png" alt="Go down" />';

        //patron
        var patron_title = data_row.patron_id;
        /*for(var i = 0; i < patrons.length; i++){
            if(patrons[i].patron_id == data_row.patron_id){
                patron_title = getPatronTitle(patrons[i]);
            }
        }*/

        if(data_row.notes === null){
            data_row.notes = "";
        }

        var date = formatDates(data_row.hold_date);
        var reserve_date;
        if(holddate_infuture){
            reserve_date = '<input type="text" class="datepicker" value="'+ date +'" required="required" size="10" name="reservedate" />';
        } else {
            reserve_date = date;
        }

        var e_date = formatDates(data_row.expiration_date);
        var expiration_date;
        if(data_row.expiration_date === null){
            expiration_date = '<input type="text" class="datepicker" value="" size="10" name="expirationdate"/>';
        }else{
            expiration_date = '<input type="text" class="datepicker" value="'+ e_date +'" size="10" name="expirationdate"/>';
        }

        var pickup_select;
        var wbrname;
        var waiting_date = formatDates(data_row.waiting_date);
        for(var i = 0; i < pickup_options.length; i++){
            if(pickup_options[i].branchcode == data_row.pickup_library_id){
                wbrname = pickup_options[i].branchname;
            }
        }

        var barcode;
        var atdestination = false;
        for(var i = 0; i < holds_iteminfo.length; i++){
            if(holds_iteminfo[i].itemnumber == data_row.item_id){
                barcode = holds_iteminfo[i].barcode;
            }
            if(holds_iteminfo[i].holdingbranch == data_row.pickup_library_id){
                //Tähän väliin lisäehdot
                atdestination = true;
            }
        }
        if(data_row.status){
            if(atdestination){
                if(data_row.status){
                    pickup_select = 'Item waiting at <b>'+ wbrname +'</b> <input type="hidden" name="pickup" value="'+data_row.pickup_library_id+'" /> since ' + waiting_date;
                }else{
                    pickup_select = 'Waiting to be pulled <input type="hidden" name="pickup" value="'+data_row.pickup_library_id+'" />';
                }
            }else{
                pickup_select = 'Item being transferred to <b>'+ wbrname +'</b> <input type="hidden" name="pickup" value="'+data_row.pickup_library_id+'" />';
            }
        }else{
            pickup_select = '<select name="pickup" priority='+ data_row.priority +'>';
            for(var i = 0; i < pickup_options.length; i++){
                if(pickup_options[i].branchcode == data_row.pickup_library_id){
                    pickup_select += '<option value= "'+ pickup_options[i].branchcode +'" selected="selected">' + pickup_options[i].branchname + '</option>';
                }else{
                    pickup_select += '<option value= "'+ pickup_options[i].branchcode +'">' + pickup_options[i].branchname + '</option>';
                }
            }
            pickup_select += '</select>';
        }

        var details;
        var details_link = '<a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber='+ data_row.biblio_id +'&amp;itemnumber='+ data_row.item_id +'#item'+ data_row.item_id +'">';
        if(data_row.status){
            if( barcode ){
                details = details_link + ''+barcode+'<input type="hidden" name="itemnumber" value="'+ data_row.item_id +'" /></a>';

            }else{
                details = details_link + 'No barcode</a>';
            }
        }else{
            if(data_row.item_level){
                if(barcode){
                    details = '<i>Only item '+ details_link +''+barcode+'<input type="hidden" name="itemnumber" value="'+ data_row.item_id +'" /></a></i>';
                }else{
                    details = '<i>Only item '+ details_link +'No barcode</a></i>';
                }
            }else{
                if(data_row.item_type){
                    details = '<i>Next available '+ data_row.item_type +' item</i><input type="hidden" name="itemnumber" value="" />';
                }else{
                    details = '<i>Next available</i><input type="hidden" name="itemnumber" value="" />';
                }
            }
        }

        var lowest_priority_img = (data_row.lowest_priority) ? '<img src="'+ interface +'/'+ theme +'/img/go-bottom.png" alt="Unset lowest priority" />' : '<img src="'+ interface +'/'+ theme +'/img/go-down.png" alt="Set to lowest priority"/>';

        var cancel_hold_img = '<img src="'+ interface +'/'+ theme +'/img/x.png" alt="Cancel" />';

        var suspend;
        var suspended_until = (data_row.suspended_until !== null) ? formatDates(data_row.suspended_until) : "";
        if(suspend_holds_intranet){
            if(!data_row.status){
                var text = (data_row.suspended) ? "Unsuspend" : "Suspend";
                var label_text = (data_row.suspended) ? "on" : "until";
                suspend = '<input type="button" name="suspend_hold" value="'+ text +'" date = '+ data_row.hold_date +'/>';
                if(autoresume_suspend){
                    suspend += '<label for="suspend_until_'+ data_row.hold_id +'">'+ label_text +'</label>';
                    suspend += '<input type="text" name="suspend_until" id="suspend_until_'+ data_row.hold_id +'"size="10" value="'+ suspended_until +'" class="datepicker"/>';
                    suspend += '<a name="clear_date" href="#">Clear date</a>';
                }else{
                    suspend += '<input type="hidden" name="suspend_until" id="suspend_until_'+ data_row.hold_id +'" value=""/>';
                }

            }else{
                var in_transit = ( data_row.status == "T" ) ? "Revert transit status" : "Revert waiting status";
                suspend = '<input type="button" class="move_hold" id="revert_hold_'+ data_row.hold_id +'" value="'+ in_transit +'" where=down first_priority = '+ first_priority +' last_priority = '+ last_priority +' prev_priority = '+ prev_priority +' next_priority = '+ next_priority +' date = '+ data_row.hold_date +'/>';
            }
        }

        row +='<tr>';
        if(modify_priority){
            row +='<input type="hidden" name="reserve_id" value="'+ data_row.hold_id +'"/>'
                +'<input type="hidden" name="borrowernumber" value="'+ data_row.patron_id +'"/>'
                +'<input type="hidden" name="biblionumber" value="'+ data_row.biblio_id +'"/>'
                +'<td>' + priority_select + '</td>'
                +'<td style="white-space:nowrap;"><a class="move_hold" title="Move hold up" where=up first_priority = '+ first_priority +' last_priority = '+ last_priority +' prev_priority = '+ prev_priority +' next_priority = '+ next_priority +' date = '+ data_row.hold_date +' href="#">'+ move_up_img +'</a>'
                +'<a class="move_hold" title="Move hold to top" where=top first_priority = '+ first_priority +' last_priority = '+ last_priority +' prev_priority = '+ prev_priority +' next_priority = '+ next_priority +' date = '+ data_row.hold_date +' href="#">'+ move_top_img +'</a>'
                +'<a class="move_hold" title="Move hold to bottom" where=bottom first_priority = '+ first_priority +' last_priority = '+ last_priority +' prev_priority = '+ prev_priority +' next_priority = '+ next_priority +' date = '+ data_row.hold_date +' href="#">'+ move_bottom_img +'</a>'
                +'<a class="move_hold" title="Move hold down" where=down first_priority = '+ first_priority +' last_priority = '+ last_priority +' prev_priority = '+ prev_priority +' next_priority = '+ next_priority +' date = '+ data_row.hold_date +' href="#">'+ move_down_img +'</a></td>';
        }else{
            row +='<td>Delete</td>';
        }
            row +='<td>'+ patron_title +'</td>'
                +'<td>'+ data_row.notes +'</td>'
                +'<td>'+ reserve_date +'</td>'
                +'<td>'+ expiration_date +'</td>'
                +'<td>'+ pickup_select +'</td>'
                +'<td>'+ details +'</td>'
                +'<td><a class="toggle_lowest" title="Toggle lowest priority" href="">'+ lowest_priority_img +'</a></td>'
                +'<td><a class="cancel-hold" title="Cancel hold" action=cancel href="#">'+ cancel_hold_img +'</a></td>'
                +'<td>'+ suspend +'</td></tr>';
    });

    $("table#itemholds_table").append(row);

    //Event handlers
    $('select[name="rank-request"]').on('change', function(){
        var hold_id = $(this).parents('tr:first').children('input[name="reserve_id"]').val();
        var url = '/api/v1/holds/'+hold_id;
        var update_data = JSON.stringify({ priority: parseInt($(this).val()) });
        updateData(url, update_data);
    });

    $("select[name='pickup']").on('change', function(){
        var hold_id = $(this).parents('tr:first').children('input[name="reserve_id"]').val();
        //$(this).after('<div id="updating_hold'+hold_id+'" class="waiting"><img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>');
        var url = '/api/v1/holds/'+hold_id;
        var update_data = JSON.stringify({ pickup_library_id: $(this).val(), priority: parseInt($(this).attr('priority'))});
        updateData(url, update_data);
    });

    $('.move_hold').on('click', function(e){
        e.preventDefault();
        var url = "/cgi-bin/koha/reserve/request.pl";
        var data = {
            action : 'move',
            where : $(this).attr('where'),
            first_priority : priority_options[0],
            last_priority : priority_options[priority_options.length - 1],
            prev_priority : $(this).attr('prev_priority'),
            next_priority : $(this).attr('next_priority'),
            borrowernumber : $(this).parents('tr:first').children('input[name="borrowernumber"]').val(),
            biblionumber : $(this).parents('tr:first').children('input[name="biblionumber"]').val(),
            reserve_id : $(this).parents('tr:first').children('input[name="reserve_id"]').val(),
            date : $(this).attr('date')
        }
        updateData(url, data);
    });

    $('.toggle_lowest').on('click', function(e){
        e.preventDefault();
        var url = "/cgi-bin/koha/reserve/request.pl";
        var data = {
            action : 'setLowestPriority',
            borrowernumber : $(this).parents('tr:first').children('input[name="borrowernumber"]').val(),
            biblionumber : $(this).parents('tr:first').children('input[name="biblionumber"]').val(),
            reserve_id : $(this).parents('tr:first').children('input[name="reserve_id"]').val(),
            date : $(this).attr('date')
        }
        updateData(url, data);
    });

    $('.cancel_hold').on('click', function(e){
        e.preventDefault();
        var url = "/cgi-bin/koha/reserve/request.pl";
        var data = {
            action : 'cancel',
            borrowernumber : $(this).parents('tr:first').children('input[name="borrowernumber"]').val(),
            biblionumber : $(this).parents('tr:first').children('input[name="biblionumber"]').val(),
            reserve_id : $(this).parents('tr:first').children('input[name="reserve_id"]').val(),
            date : $(this).attr('date')
        }
        updateData(url, data);
    });

    $('input[name="suspend_hold"]').on('click', function(){
        var hold_id = $(this).parents('tr:first').children('input[name="reserve_id"]').val();
        var url = "/cgi-bin/koha/reserve/request.pl";
        var data = {
            action : 'toggleSuspend',
            reserve_id : $(this).parents('tr:first').children('input[name="reserve_id"]').val(),
            borrowernumber : $(this).parents('tr:first').children('input[name="borrowernumber"]').val(),
            biblionumber : $(this).parents('tr:first').children('input[name="biblionumber"]').val(),
            date : $(this).attr('date'),
            suspend_until :  $('#suspend_until_'+ hold_id +'').val()
        }
        updateData(url, data);
    });

    $('a[name="clear_date"]').on('click', function(e){
        e.preventDefault();
        var hold_id = $(this).parents('tr:first').children('input[name="reserve_id"]').val();
        $('#suspend_until_'+ hold_id +'').val('');
    });

}

function formatDates(date){
    //since datepicker doesn't use 'yyyy' change it to 'yy'
    var dateformat_str;
    if ( dateformat == 'us' ) {
        dateformat_str = 'mm/dd/yy';
    } else if ( dateformat == 'metric' ) {
        dateformat_str = 'dd/mm/yy';
    } else if (dateformat == 'iso' ) {
        dateformat_str = 'yy-mm-dd';
    } else if ( dateformat == 'dmydot' ) {
        dateformat_str = 'dd.mm.yy';
    }
    var formattedDate = $.datepicker.formatDate(dateformat_str, new Date(date));
    return formattedDate;
}

/*function getPatrons(){
    var url = "/api/v1/patrons"
    var result;
    $.ajax({
        url: url,
        type: "GET",
        async: false,
        cache: true,
        success: function(data, textStatus, jqXHR){
            result = data;
        },
        error: function(jqXHR, textStatus, errorThrown){
            console.log(JSON.stringify(errorThrown));
            result = "";
        }
    });
    return result;
}*/
