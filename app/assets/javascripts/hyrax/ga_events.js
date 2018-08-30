// [hyc-override] Overriding// overwrite to disable the file download event tracking which is handled by the DownloadsController
// Callbacks for tracking events using Google Analytics
/*$(document).on('click', '#file_download', function(e) {
  _gaq.push(['_trackEvent', 'Files', 'Downloaded', $(this).data('label')]);
});*/