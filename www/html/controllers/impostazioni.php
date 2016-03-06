<?php

class ImpostazioniController extends BaseController {

	public function __construct($model) {

		$this->model = $model;

		$this->dettaglioCompleto();
	}

	protected function dettaglioCompleto() {

		$this->action = __FUNCTION__;

		// get program id default current program
		$pid = Request::Attr('program', null);

		($pid === '' ||  !Validate::IsProgramId($pid))
			&& $pid = null;

		$this->model->dettaglioCompleto($pid);

	}

}