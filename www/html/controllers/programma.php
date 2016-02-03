<?php

class ProgrammaController extends GenericController {

	private
		$pid,
		$day
	;

	public function __construct($model, $init = true) {

		$this->model = $model;

		if ($init)
			$this->initFromRequest();

	}

	public function setPid($v) {

		$this->pid = $v;

		($this->pid === '' ||  !Validate::IsProgramId($this->pid))
			&& $this->pid = null;

		return $this;
	}

	public function setDay($v) {

		$this->day = $v;

		($this->day === '' || $this->day != 0 ||  !Validate::IsDayOfWeek($this->day))
			&& $this->day = null;

		return $this;
	}

	public function salvaattuale() {

		$this->action = __FUNCTION__;

		try {
			if (!Validate::IsProgramId($this->programId))
				throw new Exception('Id programma non valido');

			$this->model->saveDefault($this->programId);

		} catch (Exception $e) {

			error_log('Errore: ' .  $e->getMessage());
			$this->status = false;
		}
	}

	public function elenco() {

		$this->action = __FUNCTION__;
		$this->model->programList($this->pid);
	}

	public function dati() {
		$this->action = __FUNCTION__;
		$this->model->programData($this->pid, $this->day);

	}

	private function initFromRequest() {

		// check for program id else we get actual program
		$this->setPid(Request::Attr('program', null));
		$this->setDay(Request::Attr('day', null));

		return $this;
	}
}