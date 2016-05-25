{% include 'header.tpl' %}
<div class="col-xs-12 col-md-12">
	<div class="panel panel-primary">
		<div class="panel-heading">
			<span class="panel-title">Ultime 24 ore</span>
		</div>
		<div class="panel-body">
			<div id="elenco-commutazioni">
				{% include 'lista-commutazioni.tpl' %}
			</div>

		</div>
		<div class="panel-footer text-center">
			<small class="text-muted">
				Ultimo aggiornamento <span id="last-update"></span>
			</small>
		</div>
	</div>
</div>
{% include 'footer.tpl' %}