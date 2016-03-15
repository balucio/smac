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
							<div class="input-group bootstrap-timepicker timepicker">
								<input type="time" data-format="hh:mm" class="form-control" aria-describedby="time-addon"
										id="schedule-time" required="" maxlength="6" placeholder="hh:mm"
										name="schedule-time[]" data-parsley-trigger="change" data-provide="timepicker"
										data-minute-step="1" data-show-inputs="false" data-show-seconds="false"
										data-show-meridian="false" data-default-time="false" />
								<span class="input-group-addon"><i class="glyphicon glyphicon-time"></i></span>
							</div>
						</div>
					</div>
					<div class="form-group">
						<label for="schedule-temp" class="col-sm-3 control-label">Temperatura</label>
						<div class="col-sm-9">
							<select id="schedule-temp" class="form-control" name="schedule-temp[]"></select>
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