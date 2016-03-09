{% include 'header.tpl' %}
	<div class="col-xs-12 col-md-12">
		<div class="panel panel-default">
			<div class="panel-heading">Programmi</div>
			<div class="panel-body">
				<div class="col-xs-12 col-sm-12 col-md-12">
					<div class="col-xs-12 col-sm-4 col-md-4 col-lg-4">
						{% include 'programdetailssettings.tpl' %}
					</div>
					<div class="col-xs-12 col-sm-8 col-md-8 col-lg-8">
						{% include 'programschedulesettings.tpl' %}
					</div>
				</div>
			</div>
		</div>
	</div>
	{% include 'program_modal.tpl' %}
{% include 'footer.tpl' %}