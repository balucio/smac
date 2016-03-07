<div class="col-xs-12 col-sm-4 col-md-4">
	<div class="panel-group" id="menu-programmi">
		<div class="panel panel-default">
			<div class="panel-heading">
				<h4 class="panel-title">
					<button class="btn btn-xs btn-link pull-left" data-toggle="collapse" data-parent="#menu-programmi" href="#elenco-programmi">
						<span class="glyphicon glyphicon-align-justify"></span>
					</button>
					<button title="Aggiungi programma" class="btn btn-xs btn-link pull-right"><span class="glyphicon glyphicon-plus"></span></button>
					<div class="clearfix"></div>
				</h4>

			</div>
			<div id="elenco-programmi" class="panel-collapse collapse in">
				<div class="list-group">
					{% for p in programmi %}
						{% set active = p.selected == 'selected' ? 'active' : '' %}
						<a href="program/select?program={{p.id_programma}}" class="list-group-item {{active}}">
							<h6 class="list-group-item-heading">{{p.nome_programma}}</h6>
							<small class="list-group-item-text">{{p.descrizione_programma}}</small>
						</a>
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
</div>