<?php

class ProgramDataController extends BaseController {

	private
		$pid = null,
		$name = null,
		$descr = null,
		$sensor = null,
		$temps = [],
		$day = null,
		$schedule = null
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

			// Verifico presenza di nome programma, descrizione e temperature
		foreach (['name', 'descr', 'temps'] as $k)
			if (empty($this->$k))
				return;

		foreach ($this->temps as &$t)
			if (!Validate::IsFloatInRange($t, Validate::MIN_TEMP, Validate::MAX_TEMP ))
				return;
			else
				$t = number_format($t, 2, ".","");

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

	public function deleteschedule() {

			// Verifico che il pid originario sia corretto
		if ( $this->pid != Request::Attr('program', null))
			return;

			// Verifico che il giorno sia corretto
		if ($this->day != Request::Attr('day', null))
			return;


		// Verifico che il programma esista
		$this->model->setPid($this->pid, $this->day);

		if (!isset($this->model->id) || $this->model->id != $this->pid )
			return;

		if (!count($this->schedule))
			return;

		$schedule = array_keys($this->schedule);

			// normalizzo e verifico orari e temperature
		foreach ($schedule as $time)
			if (!Validate::IsTime( $time ))
				return;

		// Optimizing time
		ksort($schedule);

		$this->model->deleteschedule($this->day, $schedule);
	}

	public function createOrUpdateSchedule() {

			// Verifico che il pid originario sia corretto
		if ( $this->pid != Request::Attr('program', null))
			return;

			// Verifico che il giorno sia corretto
		if ($this->day != Request::Attr('day', null))
			return;

		// Verifico che il programma esista
		$this->model->setPid($this->pid, $this->day);

		if (!isset($this->model->id) || $this->model->id != $this->pid )
			return;
		if (!count($this->schedule))
			return;

		$ct = count($this->model->temperature);

		$schedule = [];

			// normalizzo e verifico orari e temperature
		foreach ($this->schedule as $time => $tid) {
			if (
				!Validate::IsTime( $time )
				|| !Validate::IsInteger( $tid )
				|| $tid > $ct
				|| $tid < 0
			) return;
			unset($this->schedule[$time]);
			$k = (new DateTime($time))->format('H:i');

			$schedule[$k] = $tid;
		}

		// Optimizing time
		ksort($schedule);

		$this->schedule = [];
		$curr = null;

		foreach ($schedule as $k => $v) {
			if ($v !== $curr) {
				$this->schedule[$k] = $v;
				$curr = $v;
			}
		}

		$this->model->updateSchedule($this->day, $this->schedule);
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

		$schedule = Request::Attr('schedule', null);

		if (is_array($schedule))
			foreach ($schedule as $sh)
				if (isset($sh['time']))
					$this->schedule[$sh['time']] = isset($sh['temp'])
						? $sh['temp']
						: null;
	}

}