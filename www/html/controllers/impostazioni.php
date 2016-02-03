   <?php

class ImpostazioniController extends GenericController {

	public function __construct($model) {

		$this->model = $model;

		$this->dettaglioCompleto();
	}


	function dettaglioCompleto() {

		$this->action = __FUNCTION__;

		// get program id default current program
		$pid = Request::Attr('program', null);

		($pid === '' ||  !Validate::IsProgramId($pid))
			&& $pid = null;

		$this->model->dettaglioCompleto->setDay($day)->dati();
	}

}