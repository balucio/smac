<?php

class ProgramDataController extends BaseController {

	private
		$pid = null,
		$day = null
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('setProgramId');
	}

	public function setProgramId() { $this->model->setPid($this->pid, $this->day); }

	public function getProgramData() { $this->setProgramId();}

	public function saveDefault() {

		if ($this->pid !== null)
			$this->model->setDefault($this->pid);
	}

	protected function initFromRequest() {

		// check for program id else we get actual program
		$this->pid = Request::Attr('program', null);

		( !Validate::IsInteger($this->pid)
			|| !$this->model->exists($this->pid)
		) && $this->pid = null;

		$this->day = Request::Attr('day', null);

		($this->day === '' ||  !Validate::IsDayOfWeek($this->day))
			&& $this->day = date('N');
	}

}