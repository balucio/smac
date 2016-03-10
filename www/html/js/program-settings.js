/** Some custom js functions */

$(function () {


	var showProgramModal = function(data) {

		var modal = $('#program-modal').modal();
		modal.show();

		var slist = $('#elenco-sensori');
		slist.find('option').remove();

		$('#id_programma').val(data.id_programma ? data.id_programma : '');
		$('#nome_programma').val(data.nome_programma ? data.nome_programma : '');
		$('#descrizione_programma').val(data.descrizione_programma ? data.descrizione_programma : '');
		var sid = data.id_sensore_riferimento ? data.id_sensore_riferimento : ''

		createSensorList(0, slist);
	}

	var createSensorList = function(sid, select) {
		$.post('/program/getsensorlist',
			{sensor: sid},
			function(data) {
				if (data.sensorlist) {
					var s = data.sensorlist;
					for (var i = 0; i < s.length	; i++)
						select.append(
							$("<option></option>")
								.attr("value", s[i].id_sensore)
								.text(s[i].nome_sensore)
						);
				}
		});
	}

	$( document ).ready(function() {
		// Selezione del programma da elenco
		$('li.seleziona-programma').click(function(event){

			var progr = $(this);

			$.post(
				'/program/getschedule',
				{ program: progr.data('id'), day : 0 },
				function(data) {
					if (data.schedule) {
						$('#orari-programma').parent().html(data.schedule);
						var exProgram = $('li.seleziona-programma.active');
						exProgram.find('span.program-action').addClass('hidden');
						exProgram.removeClass('active');
						progr.addClass('active');
						progr.find('span.program-action').removeClass('hidden');
					}
				}
			);
		});
		// Nuovo programma
		$('#new-program').click(function(event) {
			event.preventDefault()
			showProgramModal(null);
		});
		// Modifica programma
		$('a.modifica-programma').click(function(event) {
			// Ottengo i dati del programma
			$.post(
				'/program/getdata',
				{ program : $(this).data('id') },
				function(data) {
					showProgramModal(data);
				}
			);
			// Visualizzo e popolo il modale

		});
		// Elimina programma
		$('a.elimina-programma').click(function(event) {

		});

	});
});


