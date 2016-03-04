<?php

class ProgramDataController extends GenericController {

	public function setProgramId($pid, $day = null) {

		$this->model->setProgramId($pid, $day);
	}

	public function getProgramData() {

	}

	protected function initFromRequest() {

		// check for program id else we get actual program
		$pid = Request::Attr('program', null);

		(!Validate::IsInteger($pid) || !$this->model->programExists($pid))
			&& $pid = null;

		$day = Request::Attr('day', null);

		($day === '' ||  !Validate::IsDayOfWeek($day))
			&& $day = null;

		$this->setProgramId($pid, $day);

	}

}