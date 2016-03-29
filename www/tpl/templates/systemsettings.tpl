{% include 'header.tpl' %}
	<div class="col-xs-12 col-md-12">
		<div class="panel panel-primary">
			<div class="panel-heading"><h3 class="panel-title">Impostazioni Generali</h3></div>
			<div class="panel-body">
				<div class="col-xs-12 col-sm-12 col-md-12">
					<form class="form-horizontal">
						<fieldset>
							<div class="form-group">
								<label for="sensore_antigelo" class="col-sm-4 control-label">
									<abbr title="Sensore riferimento per la temperatura di anticongelamento">Sensore anticongelamento</abbr>
								</label>
								<div class="col-sm-8">
									<select name="sensore_antigelo" id="sensore_antigelo">
									{% for s in sensori %}
									<option value="{{s.id}}">{{s.nome}}</option>
									{% endfor %}
									</select>
								</div>
							</div>
							<div class="form-group">
								<label for="temperatura_antigelo" class="col-sm-4 control-label">
									<abbr title="Temperatura protezione anticongelamento">Temperatura anticongelamento</abbr>
								</label>
								<div class="col-sm-8">
									<input name="temperatura_antigelo" id="temperatura_antigelo" type="number"
										class="form-control" data-parsley-trigger="change"
									 	pattern="\d?\d([,.]\d)?" step="0.5" min="2" max="10" maxlength="4"
										placeholder="T°" value="{{antigelo}}" required="" />
								</div>
							</div>
						</fieldset>
						<fieldset>
							<div class="form-group">
								<label for="sensore_manuale" class="col-sm-4 control-label">
									<abbr title="Sensore di riferimento per il funzionamento manuale">Sensore funzionamento manuale</abbr>
								</label>
								<div class="col-sm-8">
									<select name="sensore_manuale" id="sensore_manuale">
									{% for s in sensori %}
									<option value="{{s.id}}">{{s.nome}}</option>
									{% endfor %}
									</select>
								</div>
							</div>
							<div class="form-group">
								<label for="temperatura_manuale" class="col-sm-4 control-label">
									<abbr title="Temperatura per funzionamento manuale">Temperatura Manuale</abbr>
								</label>
								<div class="col-sm-8">
									<input name="temperatura_manuale" id="temperatura_manuale" type="number"
										class="form-control" data-parsley-trigger="change"
									 	pattern="\d?\d([,.]\d)?" step="0.5" min="10" max="25" maxlength="4"
										placeholder="T°" value="{{manuale}}" required="" />
								</div>
							</div>
						</fieldset>
						<button type="submit" class="btn btn-default">Applica</button>
						<div id="sensor-message" class="alert alert-danger hidden" role="alert"></div>
					</form>
				</div>
				<div class="clearfix"></div>
			</div>
		</div>
	</div>
{% include 'footer.tpl' %}