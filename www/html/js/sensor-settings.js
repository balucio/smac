/** Js functions for sensor settings */

$(function () {

	var setupValidation = function(form) {

		return form.parsley({

			successClass: "has-success",
			errorClass: "has-error",
			classHandler: function (el) {
				return el.$element.closest(".form-group");
			},
			errorsContainer: function (el) {
				return el.$element.closest(".form-group");
			},
			errorsWrapper: '<span class="help-block"></span>',
			errorTemplate: '<div class="col-sm-9 col-md-offset-3"></div>'
		});
	}

	var createDriverList = function(did, select) {

		$.post('/sensor/getdriverlist',
			{ driver : did },
			function(data) {
				if (data.driverlist) {
					var s = data.driverlist;
					for (var i = 0; i < s.length	; i++)
						select.append(
							$("<option></option>")
								.attr("value", s[i].id)
								.text(s[i].nome)
						);
				}
				select.val(did);
				select.selectpicker('refresh');
		});
	}

	var showSensorModal = function(data) {

		// Init raw modal html
		$('div#sensor-modal').find('.modal-title').addClass('hidden');

		var did = 1;

		if (data) {
			$('#title-new').removeClass('hidden');
			$('#id_sensore').val(data.hasOwnProperty("id") ? data.id : '');
			$('#nome_sensore').val(data.hasOwnProperty("nome") ? data.nome : '');
			$('#descrizione_sensore').val(data.hasOwnProperty("descrizione") ? data.descrizione : '');
			$('#parametri_sensore').val(data.hasOwnProperty("parametri") ? data.parametri : '');
			var did = data.hasOwnProperty("id_driver") ? data.id_driver : 1;
			$('#incluso_in_media').prop('checked', data.hasOwnProperty("incluso_in_media") && data.incluso_in_media);
			$('#abilitato').prop('checked', data.hasOwnProperty("abilitato") && data.abilitato);
		} else {
			$('#title-alter').removeClass('hidden');
			$('#id_sensore').val('');
			$('#nome_sensore').val('');
			$('#descrizione_sensore').val('');
			$('#parametri_sensore').val('');
		}

		var form = $("#sensor-modal").find('form');

		var validation = setupValidation(form);

		var modal = $('#sensor-modal').modal();

		$("#sensor-save").click(function(e){
			e.preventDefault();
			if (!validation.validate())
				return false;
			sendSensorData(form);
		});

		modal.on('hidden.bs.modal', function () {
			validation.destroy();
			$("#sensor-save").unbind();
			$('#sensor-message').empty();
			$('#sensor-message').addClass('hidden');
			$(this).data('bs.modal', null);
		});

		createDriverList( did, $('#driver_sensore') );
	}

	var sendSensorData = function(form) {

		var showMessage = function(msgid) {
			var msg = $('#sensor-message');
			msg.append($('#' + msgid).clone());
			msg.removeClass('hidden');
		}

		var removeMessage = function() {
			var msg = $('#sensor-message');
			msg.empty();
			msg.addClass('hidden');
		}

		removeMessage();

		$.ajax({
			type: "POST",
			url: "/sensor/createOrUpdate",
			data: form.serialize(),
			success: function(data) {

				var msgid = 'message-err-comm';

				if (!data || !data.hasOwnProperty("status")) {
					showMessage(msgid);
					return;
				}

				if (data.status == true) {
					$('#sensor-modal').modal('hide');
					location.reload();
					return;
				}

				if (data.hasOwnProperty("msgid") && $('#' + data.msgid).length)
					msgid = data.msgid;

				showMessage(msgid);
			},

			error: function() { showMessage('message-err-comm'); }

		});
	}

	$("#new-sensor").click(function(){
		showSensorModal();
	});

	$(".sensor-edit").click(function(){
		var sid = $(this).data('id');
		$.post(
			'/sensor/getData',
			{ sensor : sid },
			function(data) {
				showSensorModal(data);
			}
		);
	});

	// Elimina programma
	$('button.sensor-delete').click(function(e) {

		e.preventDefault();
		var sid = $(this).data('id');

		// Inizializzo il modale
		$('#confirm-delete').showDeleteConfirm(
			'confirm-delete-sensor-header',
			'confirm-delete-sensor-body',
			function() {
				$.post(
					"/sensor/delete",
					{ sensor : sid },
						function(data) {
							location.reload();
							return;
						}
				);
			}
		);
	});

});


