<?php

class ProgramDataController extends GenericController {

	public function __construct($model) {

		$this->model = $model;

		// check for program id else we get actual program
		$programId = Request::Attr('program', null);

		($programId === '' ||  !Validate::IsProgramId($programId))
			&& $programId = null;

		$day = Request::Attr('day', null);

		($day === '' ||  !Validate::IsDayOfWeek($day))
			&& $day = null;

		$this->setProgramId($programId, $day);
	}

	public function setProgramId($programId, $day = null) {
		$this->model->setProgramId($programId, $day);
		//$this->model->setProgramId(1, $day);
	}

}