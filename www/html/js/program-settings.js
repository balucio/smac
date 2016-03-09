/** Some custom js functions */

$(function () {

	$( document ).ready(function() {
		$('button.seleziona-programma').click(function(event){

			var progr = $(this);

			$.post(
				'/program/getschedule',
				{ program: progr.data('id'), day : 0 },
				function(data) {
					if (data.schedule) {
						$('#orari-programma').html(data.schedule);
						$('button.seleziona-programma').removeClass('active');
						progr.addClass('active');
					}
				}
			);

		});
	});
});


