<div class="modal fade" tabindex="-1" role="dialog">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title hidden">Nuovo programma</h4>
				<h4 class="modal-title hidden">Modifica programma</h4>
			</div>
			<div class="modal-body">
				<form class="form-horizontal">
					<div class="form-group">
						<label for="nome_programma" class="col-sm-2 control-label">Nome</label>
							<div class="col-sm-10">
								<input type="text" class="form-control" id="nome_programma" placeholder="Nome programma">
							</div>
					</div>
					<div class="form-group">
						<label for="descrizione_programma" class="col-sm-2 control-label">Descrizione</label>
						<div class="col-sm-10">
							<textarea class="form-control" rows="3" id="descrizione_programma" placeholder="Descrizione programma"></textarea>
						</div>
					</div>
					<div class="form-group">
						<label for="sensore_riferimento" class="col-sm-2 control-label">
							<abbr title="Sensore riferimento">S<sub>Rif</sub></abbr>
						</label>
						<div class="col-sm-10">
							<select class="form-control">
								<option>1</option>
								<option>2</option>
								<option>3</option>
								<option>4</option>
								<option>5</option>
							</select>
						</div>
					</div>
				</form>



	  </div>
	  <div class="modal-footer">
		<button type="button" class="btn btn-default" data-dismiss="modal">Anulla</button>
		<button type="button" class="btn btn-primary">Salva</button>
	  </div>
	</div><!-- /.modal-content -->
  </div><!-- /.modal-dialog -->
</div><!-- /.modal -->