   <?php

class SituazioneController extends BaseController {

	public function __construct($model) {

		parent::__construct($model, false);

		$this->setDefaultAction('get');
	}

	public function get() {

		$this->model->init();
	}
}