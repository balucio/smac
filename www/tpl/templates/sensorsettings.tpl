{% include 'header.tpl' %}
	<div class="col-xs-12 col-md-12">
		<div class="panel panel-warning">
			<div class="panel-heading"><h3 class="panel-title">Sensori</h3></div>
			<div class="panel-body">
				<div class="col-xs-12 col-sm-12 col-md-12">
					<div class="col-xs-12 col-sm-4 col-md-4 col-lg-4">
						{% include 'sensorslistsettings.tpl' %}
					</div>
					<div class="col-xs-12 col-sm-8 col-md-8 col-lg-8">
						{% include 'sensordetailssettings.tpl' %}
					</div>
				</div>
				<div class="clearfix"></div>
			</div>
		</div>
	</div>
	{% include 'confirm_delete.tpl' %}
	{% include 'messages.tpl' %}
{% include 'footer.tpl' %}