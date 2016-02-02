<?php

class ProgrammaController extends GenericController {

	private
		$pid,
        $day
	;

	public function __construct($model) {

		$this->model = $model;

		// check for program id else we get actual program
		$this->pid = Request::Attr('program', null);

        ($this->pid === '' ||  !Validate::IsProgramId($this->pid))
            && $this->pid = null;

        $this->day = Request::Attr('day', null);

        ($this->day === '' ||  !Validate::IsDayOfWeek($this->day))
            && $this->day = null;
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
    	$this->pid = $this->model->programList($this->pid);
    }

    public function dati() {
        $this->action = __FUNCTION__;
        $this->model->programData($this->pid, -1);

    }
}