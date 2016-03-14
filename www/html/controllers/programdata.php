<?php

class ProgramDataController extends BaseController {

	const MIN_TEMP = 3.0;
	const MAX_TEMP = 30.0;

	private
		$pid = null,
		$name = null,
		$descr = null,
		$sensor = null,
		$temps = [],
		$day = null
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('setProgramId');
	}

	public function setProgramId() {

		if ($this->pid !== null && !Validate::IsInteger($this->pid))
			$this->pid = null;

		$this->model->setPid($this->pid, $this->day);
	}

	public function getProgramData() { $this->setProgramId(); }

	public function getList() {

		$this->model->enumerate($this->pid, ProgramListModel::NONE);

 	}

 	public function delete() {

 		if (!Validate::IsPositiveInt( $this->pid ))
 			return;

 		$this->model->delete($this->pid);

 	}

	public function createOrUpdate() {

		$pid = Request::Attr('program', null);

			// Verifico che il pid originario sia comunque corretto
		if ($pid != $this->pid)
			return;

			// Verifico sensore
		if (!Validate::IsInteger($this->sensor))
			return;

			// Verifico presenza di
		foreach (['name', 'descr', 'temps'] as $k)
			if (empty($this->$k))
				return;


		foreach ($this->temps as &$t)
			if (!Validate::IsFloatInRange($t, self::MIN_TEMP, self::MAX_TEMP ))
				return;
			else
				$t = (float)$t;

		sort( $this->temps, SORT_NUMERIC );
		$this->temps = array_unique( $this->temps, SORT_NUMERIC );

		$this->model->updateProgram(
			$this->pid,
			$this->name,
			$this->descr,
			$this->temps,
			$this->sensor
		);
	}

	public function saveDefault() {

		if ($this->pid !== null && !Validate::IsInteger($this->pid))
			$this->pid = null;

		if ($this->pid !== null)
			$this->model->setDefault($this->pid);
	}

	protected function initFromRequest() {

		// check for program id
		$this->pid = Request::Attr('program', null);

		!Validate::IsInteger($this->pid)
			&& $this->pid = null;

		$this->day = Request::Attr('day', null);

		($this->day === '' ||  !Validate::IsDayOfWeek($this->day))
			&& $this->day = date('N');

		$this->name = Request::Attr('name', null);
		$this->descr = Request::Attr('description', null);
		$this->sensor = Request::Attr('sensor', null);

		$temps = Request::Attr('temperature', null);

		if (is_array($temps))
			foreach ($temps as $t)
				$this->temps[] = $t;
	}

}