{% include 'header.tpl' %}
	<div class="col-xs-12 col-md-12">
		<div class="panel panel-warning">
			<div class="panel-heading"><h3 class="panel-title">Programmi</h3></div>
			<div class="panel-body">
				<div class="col-xs-12 col-sm-12 col-md-12">
					<div class="col-xs-12 col-sm-4 col-md-4 col-lg-4">
						{% include 'programdetailssettings.tpl' %}
					</div>
					<div class="col-xs-12 col-sm-8 col-md-8 col-lg-8">
						{% include 'programschedulesettings.tpl' %}
					</div>
				</div>
				<div class="clearfix"></div>
			</div>
		</div>
	</div>
	{% include 'program_modal.tpl' %}
	{% include 'schedule_modal.tpl' %}
	{% include 'confirm_delete.tpl' %}

	<div id="messages" class="hidden">
		<span id="message-err-data">
			I dati ricevuti dal server non sono corretti
		</span>
		<span id="message-err-duplicate">
			Impossibile creare il programma, nome già esistente
		</span>
		<span id="message-err-db">
			Si è verificato un errore di scrittura sul database
		</span>
		<span id="message-err-comm">
			Si è verificato un errore di comunicazione con il server
		</span>
		<span id="confirm-delete-program-header">Elimina programma</span>
		<span id="confirm-delete-program-body">
			<p>Procedendo verrà eliminato il programma e la relativa pianificazione settimanale.</p>
			<small><b>NB</b>: se il programma è quello attualmente in uso nel sistema, questo passerà in modalità anticongelamento.</small>
		</span>
	</div>

{% include 'footer.tpl' %}