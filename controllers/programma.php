<?php

class ProgrammaController extends GenericController {

	public
		$action = null,
		$status = true
	;

	private
		$programId = null
	;

	public function __construct($model) {

		$this->model = $model;

		// check for program id else we get actual program
		$this->programId = Request::Attr('program', null);
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
    	$this->model->programList($this->programId);
    }
}