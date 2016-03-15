<div class="modal fade" id="schedule-modal" tabindex="-1" role="dialog" aria-labelledby="ScheduleModalLabel" aria-hidden="true">
	<div class="modal-dialog">
		<div class="modal-content">
			<div class="modal-header">
				Programmazione oraria
			</div>
			<div class="modal-body">
				<form class="form-horizontal">
					<div class="form-group">
						<label for="schedule-time" class="col-sm-3 control-label">Orario</label>
						<div class="col-sm-9">
							<input type="hidden" id="schedule-program" name="program" />
							<input type="hidden" id="schedule-day" name="day" />
							<input type="time" class="form-control" id="schedule-time" required=""
								maxlength="5" placeholder="Orario" name="schedule-time[]"
								data-parsley-trigger="change" />
						</div>
					</div>
					<div class="form-group">
						<label for="schedule-temp" class="col-sm-3 control-label">Temperatura</label>
						<div class="col-sm-9">
							<input type="numeric" class="form-control" id="schedule-temp" required=""
								maxlength="4" placeholder="T°" name="schedule-temp[]"
								data-parsley-trigger="change" />
						</div>
					</div>
					<div id="schedule-message" class="alert alert-danger hidden" role="alert">
					</div>
				</form>
			</div>
			<div class="modal-footer">
				<button type="button" class="btn btn-default" data-dismiss="modal">Anulla</button>
				<button type="button" class="btn btn-primary" id="schedule-save">Salva</button>
			</div>
		</div>
	</div>
</div>