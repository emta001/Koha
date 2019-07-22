[% USE Koha %]
<table id="itemholds_table">
    <tr>

        [% IF ( CAN_user_reserveforothers_modify_holds_priority ) %]
            <th>Priority</th>
            <th>&nbsp;</th>
        [% ELSE %]
            <th>Delete?</th>
        [% END %]

        <th>Patron</th>
        <th>Notes</th>
        <th>Date</th>
        <th>Expiration</th>
        <th>Pickup library</th>
        <th>Details</th>

        [% IF ( CAN_user_reserveforothers_modify_holds_priority ) %]
            <th><img src="[% interface | html %]/[% theme | html %]/img/go-bottom.png" alt="Toggle set to lowest priority" /></th>
        [% END %]

        <th>&nbsp;</th>
        [% IF SuspendHoldsIntranet %]<th>&nbsp;</th><!-- Suspend Holds Column Header -->[% END %]

    </tr>
</table>

<input type="button" value="previous" id="prev_button">
<input type="button" value="next" id="next_button">
