<div class="panel-group" id="dati-sensore">
	<div class="panel panel-primary">
		<div class="panel-heading">
			<h4 class="panel-title">
				Sensore <b>{{sensore.nome}}</b>
			</h4>
		</div>
		<div class="panel-body">
		<form class="form-horizontal">
			<div class="form-group">
				<label class="col-sm-3 control-label">Nome</label>
				<div class="col-sm-9">
				  <p class="form-control-static">{{sensore.nome}}</p>
				</div>
			</div>
			<div class="form-group">
				<label class="col-sm-3 control-label">Descrizione</label>
				<div class="col-sm-9">
				  <p class="form-control-static" data-input-type="textarea">{{sensore.descrizione}}</p>
				</div>
			</div>
			<div class="form-group">
				<label class="col-sm-3 control-label">Driver</label>
				<div class="col-sm-9">
				  <p class="form-control-static" data-input-type="select-driver">{{sensore.nome_driver}}</p>
				</div>
			</div>
			<div class="form-group">
				<label class="col-sm-3 control-label">Parametri driver</label>
				<div class="col-sm-9">
				  <p class="form-control-static" data-input-type="text">{{sensore.parametri_driver|default('---')}}</p>
				</div>
			</div>
			<div class="checkbox">
				<label class="col-sm-9 col-md-offset-3">
					<input disabled="disabled" name="incluso_in_media" type="checkbox" checked="{{ sensore.incluso_in_media ? 'checked' : '' }}"> Includi in calcolo media
				</label>
			</div>
			<div class="checkbox">
				<label class="col-sm-9 col-md-offset-3">
					<input disabled="disabled" name="abilitato" type="checkbox" checked="{{ sensore.abilitato ? 'checked' : '' }}"> Abilitato
				</label>
			</div>
		</form>
		</div>
	</div>
</div>