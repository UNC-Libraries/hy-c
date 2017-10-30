$(function() {
    $('input[id*="date"]').datepicker({
        maxDate: '+0D',
        dateFormat: 'yy-mm-dd'
    });
});