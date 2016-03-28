<div id="sensor-modal" class="modal fade" tabindex="-1" role="dialog">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title hidden" id="title-new">Nuovo Sensore</h4>
				<h4 class="modal-title hidden" id="title-alter">Modifica sensore</h4>
			</div>
			<div class="modal-body">
				<form class="form-horizontal">
					<div class="form-group">
						<label for="nome_sensore" class="col-sm-3 control-label">Nome</label>
						<div class="col-sm-9">
							<input type="hidden" id="id_sensore" name="sensor" />
							<input type="text" class="form-control" id="nome_sensore" required=""
								maxlength="64" placeholder="Nome sensore" name="name"
								data-parsley-trigger="change" />
						</div>
					</div>
					<div class="form-group">
						<label for="descrizione_sensore" class="col-sm-3 control-label">Descrizione</label>
						<div class="col-sm-9">
							<textarea class="form-control" rows="3" data-parsley-trigger="change"
								id="descrizione_sensore" placeholder="Descrizione sensore" name="description"
								required=""></textarea>
						</div>
					</div>
					<div class="form-group">
						<label for="driver_sensore" class="col-sm-3 control-label">
							<abbr title="Driver utilizzato per gestire il sensore">Driver</abbr></label>
						<div class="col-sm-9">
							<select id="driver_sensore" class="form-control selectpicker" name="driver"></select>
						</div>
					</div>
					<div class="form-group">
						<label for="parametri_sensore" class="col-sm-3 control-label">Parametri</label>
						<div class="col-sm-9">
							<input type="text" class="form-control" id="parametri_sensore" required=""
								maxlength="64" placeholder="Parametri inizializzazione" name="parameters"
								data-parsley-trigger="change" />
						</div>
					</div>
					<div class="form-group">
						<div class="col-sm-9 col-sm-offset-3">
							<div class="checkbox">
								<label>
									<input id="incluso_in_media" name="inaverage" type="checkbox" value="t" checked="">
							    	includi i dati del sensore nel calcolo dei valori medi
								</label>
							</div>
						</div>
					</div>
					<div class="form-group">
						<div class="col-sm-9 col-sm-offset-3">
							<div class="checkbox">
								<label>
									<input id="abilitato" name="enabled" type="checkbox" value="t" checked="checked">
							    	abilita il sensore
								</label>
							</div>
						</div>
					</div>

					<div id="sensor-message" class="alert alert-danger hidden" role="alert"></div>
				</form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Anulla</button>
				<button type="button" class="btn btn-primary" id="sensor-save">Salva</button>
			</div>
		</div>
	</div>
</div>