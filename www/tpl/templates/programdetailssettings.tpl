<div class="panel-group" id="elenco-programmi">
	<div class="panel panel-default">
		<div class="panel-heading">
			<h4 class="panel-title">
				<button class="btn btn-xs btn-link pull-left" data-toggle="collapse" data-parent="#elenco-programmi" href="#elenco-programmi">
					<span class="glyphicon glyphicon-align-justify"></span>
				</button>
				<button id="new-program" title="Aggiungi programma" class="btn btn-xs btn-link pull-right"><span class="glyphicon glyphicon-plus"></span></button>
				<div class="clearfix"></div>
			</h4>
		</div>
		<div id="elenco-programmi" class="panel-collapse collapse in">
			<div class="list-group">
				{% for p in programmi %}
					{% set active = p.selected == 'selected' ? 'active' : '' %}
					{% set hidden = p.selected == 'selected' ? '' : 'hidden' %}
					<button type="button" class="list-group-item {{active}} seleziona-programma" data-id="{{p.id_programma}}">
						<h4 class="list-group-item-heading">
							{{p.nome_programma}}
							<span class="pull-right {{hidden}}">
								<a href="#" title="Modfica programma" class="bg-primary modifica-programma" data-id="{{p.id_programma}}">
									<i class="fa fa-pencil-square-o" aria-hidden="true"></i>
								</a>
								<a href="#" title="Elimina programma" class="bg-primary elimina-programma" data-id="{{p.id_programma}}">
									<i class="fa fa-trash-o" aria-hidden="true"></i>
								</a>
							</span>
						</h4>
						<div class="clearfix"></div>
						<small class="list-group-item-text">{{p.descrizione_programma}}</small>
					</button>
				{% else %}
					<a href="#" class="list-group-item">
						<h4 class="list-group-item-heading">Nessun programma</h4>
						<p class="list-group-item-text">Non è stato definito alcun programa</p>
					</a>
				{% endfor %}
			</div>
		</div>
	</div>
</div>