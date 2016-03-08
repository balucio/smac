{% include 'header.tpl' %}
	<div class="col-xs-12 col-md-12">
		<div class="panel panel-default">
			<div class="panel-heading">Programmi</div>
			<div class="panel-body">
				<div class="col-xs-12 col-sm-12 col-md-12">
					{% include 'programdetailssettings.tpl' %}
					{% include 'programschedulesettings.tpl' %}
				</div>
			</div>
		</div>
	</div>
	{% include 'program_modal.tpl' %}
{% include 'footer.tpl' %}