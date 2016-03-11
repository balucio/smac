<div id="program-modal" class="modal fade" tabindex="-1" role="dialog">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				<h4 class="modal-title">Nuovo programma</h4>
				<h4 class="modal-title hidden">Modifica programma</h4>
			</div>
			<div class="modal-body">
				<form class="form-horizontal">
					<div class="form-group">
						<label for="nome_programma" class="col-sm-3 control-label">Nome</label>
						<div class="col-sm-9">
							<input type="hidden" id="id_programma">
							<input type="text" class="form-control" id="nome_programma" placeholder="Nome programma">
						</div>
					</div>
					<div class="form-group">
						<label for="descrizione_programma" class="col-sm-3 control-label">Descrizione</label>
						<div class="col-sm-9">
							<textarea class="form-control" rows="3" id="descrizione_programma" placeholder="Descrizione programma"></textarea>
						</div>
					</div>
					<div class="form-group">
						<label for="sensore_riferimento" class="col-sm-3 control-label">
							<abbr title="Sensore di riferimento">S. Rif.</abbr></label>
						<div class="col-sm-9">
							<select id="elenco-sensori" class="form-control">
							</select>
						</div>
					</div>
						<label for="temperature" class="col-sm-3 control-label">Temperature</label>
						<div id="programma-temperature" class="col-sm-9">
							<div class="input-group col-sm-4 hidden">
								<span class="input-group-btn">
									<button class="btn btn-default temperature-del hidden"
											type="button" title="Rimuovi temperatura">-</button>
								</span>
								<input type="number" class="form-control" pattern="00.0"
											placeholder="T°" min="3" max="30" maxlength="4" step="0.5" value="20">
								<span class="input-group-btn">
									<button class="btn btn-default temperature-add hidden"
											type="button" title="Aggiungi temperatura">+</button>
								</span>
							</div>
						</div>
					<div class="clearfix"></div>
				</form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Anulla</button>
				<button type="button" class="btn btn-primary">Salva</button>
			</div>
		</div>
	</div>
</div>