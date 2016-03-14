<div class="panel panel-default" id="elenco-programmi">
	<div class="panel-heading">
		<h6 class="panel-title">
		    <span>Elenco</span>
			<button id="new-program" title="Aggiungi programma" class="btn btn-xs btn-link pull-right">
				<span class="glyphicon glyphicon-plus"></span>
			</button>
		</h6>
	</div>
	<div class="panel-body">
		<ul class="list-group">
			{% for p in programmi|default([]) %}
				{% set active = p.selected == 'selected' ? 'active' : '' %}
				{% set hidden = p.selected == 'selected' ? '' : 'hidden' %}
				<li class="list-group-item {{active}} seleziona-programma" data-id="{{p.id_programma}}">
					<h4 class="list-group-item-heading">
						{{p.nome_programma}}
						<span class="pull-right program-action {{hidden}}">
							<a href="#" title="Modifica programma" class="bg-primary modifica-programma" data-id="{{p.id_programma}}">
								<i class="fa fa-pencil-square-o" aria-hidden="true"></i>
							</a>
							<a href="#" title="Elimina programma" class="bg-primary elimina-programma" data-id="{{p.id_programma}}">
								<i class="fa fa-trash-o" aria-hidden="true"></i>
							</a>
						</span>
					</h4>
					<div class="clearfix"></div>
					<small class="list-group-item-text">{{p.descrizione_programma}}</small>
				</li>
			{% else %}
				<li class="list-group-item">
					<div class="list-group-item">
						<h4 class="list-group-item-heading">Nessun programma</h4>
						<p class="list-group-item-text">Non è stato definito alcun programa</p>
					</div>
				</li>
			{% endfor %}
		</ul>
	</div>
</div>
<div class="clearfix"></div>